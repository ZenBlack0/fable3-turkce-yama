"""
Fable III book.babel repack aracı.

Kullanım:
  python tools/repack.py <orijinal.babel> <ceviri.(csv|json|jsonl)> <cikis.babel> [--max-block N] [--overrides overrides.csv]

Eşleştirme: önce kayıt ID'si (0x........), sonra TAM orijinal metin (strip YOK).
Çeviriye orijinaldeki baş/son boşluklar aynen uygulanır, sondaki null sayısı korunur.
--max-block N : blok N baytı aşacaksa kalan kayıtlar yeni bloklara taşınır (0 = kapalı).
"""
import argparse
import csv
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from babel import Babel, split_nulls, keep_edges, write_babel
from trtext import missing_tokens

csv.field_size_limit(1 << 30)

def load_translations(path):
    """-> (by_id, by_text). by_text anahtarı: tam orijinal metin."""
    by_id, by_text = {}, {}
    ext = path.lower().rsplit('.', 1)[-1]
    if ext == 'jsonl':
        with open(path, encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                r = json.loads(line)
                tr = r.get('tr')
                if r.get('add') or r.get('dlc'):
                    continue            # orijinal kitapta olmayan (DLC) kayıtlar: load_adds ile alınır
                if tr and r.get('status', 'done') in ('done', 'review'):
                    if 'src' in r:
                        by_text[r['src']] = tr          # yerel çalışma dosyası (İngilizce kaynaklı)
                    # kayıt ID'si HER ZAMAN öncelikli: aynı İngilizce metin bağlama göre farklı çevrilebilir (örn. Vault: eylem / kasa);
                    # yalnızca src'ye bakılırsa bölünmüş satırların sonuncusu hepsini ezer.
                    for i in r.get('ids', []):
                        by_id[i.strip()] = tr
    elif ext == 'json':
        with open(path, encoding='utf-8') as f:
            for r in json.load(f):
                tr = r.get('ceviri') or r.get('translation')
                if not tr:
                    continue
                if r.get('id'):
                    by_id[r['id'].strip()] = tr
                src = r.get('orijinal_metin') or r.get('original_text')
                if src:
                    by_text[src] = tr
    else:
        with open(path, encoding='utf-8-sig', newline='') as f:
            rows = csv.reader(f)
            next(rows, None)
            for row in rows:
                if len(row) >= 4 and row[0].startswith('0x'):      # id,file,orijinal,ceviri,...
                    if row[3].strip():
                        by_id[row[0].strip()] = row[3]
                        by_text[row[2]] = row[3]
                elif len(row) >= 3 and row[2].strip():             # kategori,orijinal,ceviri,not
                    by_text[row[1]] = row[2]
                elif len(row) >= 2 and row[1].strip():             # orijinal,ceviri
                    by_text[row[0]] = row[1]
    return by_id, by_text


def load_adds(path):
    """jsonl satırlarındaki "add" alanı: orijinal kitapta OLMAYAN kayıtlar (DLC). -> [(id:int, tr, t2|None, dialog:bool)]
    Satır: {"ids": [...], "tr": "...", "status": "done", "cat": "...", "add": {"0xID": [internal_key, b0, b1, b2] | null}}"""
    out = []
    if not path.lower().endswith('.jsonl'):
        return out
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            r = json.loads(line)
            if r.get('add') and r.get('tr') and r.get('status', 'done') in ('done', 'review'):
                for i in r['ids']:
                    t2 = r['add'].get(i)
                    out.append((int(i, 16), r['tr'], tuple(t2) if t2 else None, r.get('cat') == 'dialog'))
    return out


def adds_to_extra(adds):
    return [(i, tr + '\x00', t2) for i, tr, t2, _ in adds]


def load_overrides(path):
    """overrides.csv: id,ceviri  (ID bazında çeviri)"""
    out = {}
    if path and os.path.exists(path):
        with open(path, encoding='utf-8-sig', newline='') as f:
            rows = csv.reader(f)
            next(rows, None)
            for row in rows:
                if len(row) >= 2 and row[0].startswith('0x') and row[1].strip():
                    out[row[0].strip()] = row[1]
    return out


def apply_translations(babel, by_id, by_text, overrides=None):
    """-> (new_texts, istatistik). new_texts: entry index -> yeni ham metin."""
    overrides = overrides or {}
    new_texts, applied, tag_warn = {}, 0, []
    for i, e in enumerate(babel.entries):
        eid = f'0x{e[0]:08X}'
        raw = babel.raw_text(e)
        core, nulls = split_nulls(raw)
        tr = overrides.get(eid)
        if tr is None:
            tr = by_id.get(eid)
        if tr is None:
            tr = by_text.get(core)
        if tr is None:
            continue
        final = keep_edges(core, tr)
        if any(missing_tokens(core, final)):
            tag_warn.append((eid, core[:40]))
        new_texts[i] = final + '\x00' * max(nulls, 1)
        applied += 1
    return new_texts, {'applied': applied, 'tag_warnings': tag_warn}


def repack(orig, trans, out, max_block=0, overrides_path=None, extra_adds=None):
    babel = Babel(orig)
    by_id, by_text = load_translations(trans)
    new_texts, st = apply_translations(babel, by_id, by_text, load_overrides(overrides_path))
    adds = load_adds(trans) + list(extra_adds or [])
    info = write_babel(babel, new_texts, out, max_block, adds_to_extra(adds) if adds else None)
    if adds:
        print(f"Yeni (orijinalde olmayan) kayıt: {info['extra_added']} eklendi, {info['extra_skipped']} atlandı, Table 2 kaydı {info['t2_added']}")
    repack.last_adds = adds
    print(f"Çeviri: {len(by_id)} ID + {len(by_text)} metin | uygulanan kayıt: {st['applied']}")
    for eid, t in st['tag_warnings'][:10]:
        print(f"  UYARI etiket eksik: {eid} '{t}'")
    if st['tag_warnings']:
        print(f"  toplam etiket uyarısı: {len(st['tag_warnings'])}")
    print(f"Blok: {info['blocks']} (yeni {info['new_blocks']}), en büyük {info['max_block_bytes']} bayt, "
          f">16384: {info['over_16384']} | dosya {info['file_bytes']:,} bayt -> {out}")
    return info


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('orig')
    ap.add_argument('trans')
    ap.add_argument('out')
    ap.add_argument('--max-block', type=int, default=0)
    ap.add_argument('--overrides')
    a = ap.parse_args()
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    repack(a.orig, a.trans, a.out, a.max_block, a.overrides)
