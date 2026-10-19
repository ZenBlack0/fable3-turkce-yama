"""
book.babel okuma/yazma çekirdeği (Fable III, Big-Endian, UTF-16BE, zlib blokları).

Yapı:  [8 bayt header][N * (id, block_tag, offset)][block_count]
       [block_count * (tag, comp_size, uncomp_size, zlib)][kuyruk (Table 2/3)]
Kuyruk yalnızca string ID'lerine başvurur (bkz. docs/FORMAT.md), bu yüzden
blok/ofset değişiklikleri sırasında olduğu gibi kopyalanır.
"""
import struct
import zlib


class Babel:
    def __init__(self, path):
        with open(path, 'rb') as f:
            d = f.read()
        self.header = d[:8]
        n = struct.unpack('>I', d[4:8])[0]
        self.entries = [struct.unpack('>3I', d[8 + i * 12: 20 + i * 12]) for i in range(n)]
        pos = 8 + n * 12
        nb = struct.unpack('>I', d[pos:pos + 4])[0]
        pos += 4
        self.blocks = []          # [(tag, uncompressed bytes)] dosya sırasıyla
        for _ in range(nb):
            tag, csz, usz = struct.unpack('>3I', d[pos:pos + 12])
            pos += 12
            raw = zlib.decompressobj().decompress(d[pos:pos + csz])
            assert len(raw) == usz, 'blok boyutu uyuşmuyor'
            self.blocks.append((tag, raw))
            pos += csz
        self.tail = d[pos:]
        self.tag_index = {t: i for i, (t, _) in enumerate(self.blocks)}

    def raw_text(self, entry):
        """Kaydın ham metni (sondaki null'lar dahil)."""
        _, tag, off = entry
        blk = self.blocks[self.tag_index[tag]][1]
        ln = struct.unpack('>I', blk[off:off + 4])[0]
        return blk[off + 4: off + 4 + ln * 2].decode('utf-16be', errors='replace')


def split_nulls(raw):
    """'abc\\x00' -> ('abc', 1)"""
    core = raw.rstrip('\x00')
    return core, len(raw) - len(core)


def keep_edges(orig_core, translation):
    """Orijinaldeki baş/son boşlukları çeviriye aynen uygula."""
    lead = orig_core[:len(orig_core) - len(orig_core.lstrip())]
    trail = orig_core[len(orig_core.rstrip()):]
    t = translation.strip()
    if not t:                      # orijinal yalnızca boşluksa dokunma
        return orig_core
    return lead + t + trail


def write_babel(babel, new_texts, out_path, max_block=0, extra=None):
    """
    new_texts: entry index -> yeni ham metin (null dahil). Eksik olanlar orijinal kalır.
    max_block: 0 = her orijinal bloğu tek blok olarak yaz.
               >0 = bir blok bu bayt sınırını aşacaksa kalan kayıtları yeni bloğa taşı
                    (sınır, tek bir kaydın tek başına aştığı durumlar hariç korunur).
    extra: None ya da [(kayıt_id, ham_metin_null_dahil, t2)] — ORİJİNAL kitapta OLMAYAN yeni kayıtlar (örn. DLC metinleri).
           Yeni kayıtlar yeni bloklara (<=16384 bayt) yazılır, Table 1 kimliğe göre sıralı tutulur, başlıktaki sayı güncellenir;
           t2 = (internal_key, b0, b1, b2) verilmişse Table 2'ye (kimliğe göre sıralı) 11 baytlık kayıt eklenir. Var olan kimlikler atlanır.
    Dönen: istatistik sözlüğü.
    """
    n = len(babel.entries)
    by_block = {}
    for i, (_, tag, off) in enumerate(babel.entries):
        by_block.setdefault(tag, []).append(i)

    used_tags = set(babel.tag_index)
    new_entries = [None] * n
    out_blocks = []               # (tag, bytes)
    shared = 0

    def fresh_tag(base):
        t = base
        while t in used_tags:
            t = (t + 0x100) & 0xFFFFFFFF
        used_tags.add(t)
        return t

    for tag, _ in babel.blocks:
        idxs = sorted(by_block.get(tag, []), key=lambda i: babel.entries[i][2])
        cur_tag, cur = tag, bytearray()
        seen = {}                 # orijinal ofset -> (blok_tag, yeni_ofset, metin)
        for i in idxs:
            eid, _, off = babel.entries[i]
            text = new_texts.get(i)
            if text is None:
                text = babel.raw_text(babel.entries[i])
            enc = text.encode('utf-16be')
            rec = struct.pack('>I', len(enc) // 2) + enc
            if max_block and cur and len(cur) + len(rec) > max_block:
                out_blocks.append((cur_tag, bytes(cur)))
                cur_tag, cur = fresh_tag(tag), bytearray()
            new_entries[i] = struct.pack('>3I', eid, cur_tag, len(cur))
            cur.extend(rec)
        out_blocks.append((cur_tag, bytes(cur)))

    extra_entries, t2_new, skipped = [], [], 0
    if extra:
        existing = {e[0] for e in babel.entries}
        items = sorted((x for x in extra if x[0] not in existing), key=lambda x: x[0])
        skipped = len(extra) - len(items)
        cur_tag, cur = None, bytearray()
        for eid, text, t2 in items:
            enc = text.encode('utf-16be')
            rec = struct.pack('>I', len(enc) // 2) + enc
            if cur_tag is None or (cur and len(cur) + len(rec) > 16384):
                if cur:
                    out_blocks.append((cur_tag, bytes(cur)))
                cur_tag, cur = fresh_tag(0x7A000000), bytearray()
            extra_entries.append((eid, struct.pack('>3I', eid, cur_tag, len(cur))))
            cur.extend(rec)
            if t2:
                t2_new.append((eid, t2))
        if cur:
            out_blocks.append((cur_tag, bytes(cur)))

    body = bytearray()
    for tag, raw in out_blocks:
        comp = zlib.compress(raw, 9)
        body += struct.pack('>3I', tag, len(comp), len(raw)) + comp

    header, tail = babel.header, babel.tail
    entries_bytes = b''.join(new_entries)
    if extra_entries:
        merged = sorted([(e[0], nb) for e, nb in zip(babel.entries, new_entries)] + extra_entries, key=lambda x: x[0])
        entries_bytes = b''.join(x[1] for x in merged)
        header = babel.header[:4] + struct.pack('>I', n + len(extra_entries))
    if t2_new:
        cnt = struct.unpack('>I', tail[4:8])[0]
        recs = {}
        for k in range(cnt):
            r = tail[8 + k * 11: 19 + k * 11]
            recs[struct.unpack('>I', r[:4])[0]] = r
        for eid, (key, b0_, b1_, b2_) in t2_new:
            recs.setdefault(eid, struct.pack('>IIBBB', eid, key, b0_, b1_, b2_))
        tail = tail[:4] + struct.pack('>I', len(recs)) + b''.join(recs[k] for k in sorted(recs)) + tail[8 + cnt * 11:]
    data = (header + entries_bytes + struct.pack('>I', len(out_blocks))
            + bytes(body) + tail)
    with open(out_path, 'wb') as f:
        f.write(data)
    sizes = [len(r) for _, r in out_blocks]
    return {'blocks': len(out_blocks), 'new_blocks': len(out_blocks) - len(babel.blocks),
            'max_block_bytes': max(sizes), 'over_16384': sum(1 for s in sizes if s > 16384),
            'file_bytes': len(data), 'extra_added': len(extra_entries), 'extra_skipped': skipped, 't2_added': len(t2_new)}
