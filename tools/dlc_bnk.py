"""DLC arşivi (.bnk + .bnk.dat) okuyucu — YALNIZCA OKUR (BAKIMCI aracı; DLC dosyalarına asla yazmaz).

Biçim (doğrulandı):
  .bnk  = [u32 toplam boyut][u32 4][1 bayt][parçalar]; her parça: [u32 sıkıştırılmış][u32 açık (64 KB)] + veri.
          Tüm parçalar TEK zlib akışının senkron parçalarıdır (ilk parça 0x11'de 78 da ile başlar).
          Açılınca: [u32 0][u32 N] + N * (u32 yol_özeti, u32 offset, u32 boyut)  (big-endian)
  .dat  = kayıtların ham verisi; (offset, boyut) ile okunur.
Kitaplar (language\\<dil>\\text\\book.babel) bu arşivlerin içindedir; İngilizce (en-uk) yol özeti 0x50B6B0BF.
"""
import os
import struct
import zlib

EN_UK_BOOK = 0x50B6B0BF


def read_index(bnk):
    d = open(bnk, 'rb').read()
    o = zlib.decompressobj()
    out = b''
    pos = 9
    while pos + 8 <= len(d):
        comp, _unc = struct.unpack('>II', d[pos:pos + 8])
        out += o.decompress(d[pos + 8:pos + 8 + comp])
        pos += 8 + comp
    _z, n = struct.unpack('>II', out[:8])
    return [struct.unpack('>3I', out[8 + i * 12:20 + i * 12]) for i in range(n)]


def read_blob(dat, off, size):
    with open(dat, 'rb') as f:
        f.seek(off)
        return f.read(size)


def find_en_book(bnk):
    """DLC arşivindeki İngilizce (en-uk) book.babel ham baytları ya da None."""
    dat = bnk + '.dat'
    for h, o, s in read_index(bnk):
        if h == EN_UK_BOOK:
            return read_blob(dat, o, s)
    return None


def packs(game_dir, skip_dirs=()):
    """Kurulu DLC paketleri: {ad: bnk yolu} (içinde İngilizce book.babel bulunanlar)."""
    out = {}
    root = os.path.join(game_dir, 'DLC')
    if not os.path.isdir(root):
        return out
    skip = {x.lower() for x in skip_dirs}
    for d, ds, fs in os.walk(root):
        ds[:] = [x for x in ds if x.lower() not in skip]
        for f in fs:
            if f.lower().endswith('.bnk'):
                p = os.path.join(d, f)
                try:
                    if any(h == EN_UK_BOOK for h, _, _ in read_index(p)):
                        out[os.path.splitext(f)[0]] = p
                except Exception:      # noqa: BLE001
                    pass
    return out


if __name__ == '__main__':
    # python tools/dlc_bnk.py "<oyun klasörü>"  -> backup\dlc_<ad>_en.babel.orig (manifest.json'daki SHA-256 ile eşleşen DLC kitapları)
    import hashlib
    import json
    import sys
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    man = json.load(open(os.path.join(root, 'manifest.json'), encoding='utf-8'))
    game = sys.argv[1] if len(sys.argv) > 1 else sys.exit('kullanım: python tools/dlc_bnk.py "<oyun klasörü>"')
    found = packs(game, skip_dirs=('99_tr_yama',))
    if not found:
        sys.exit('DLC kitabı bulunamadı: ' + game)
    for name, p in sorted(found.items()):
        raw = find_en_book(p)
        sha = hashlib.sha256(raw).hexdigest()
        key = next((k for k, d in man.get('dlc', {}).items() if d['src_sha'] == sha), None)
        if key is None:
            print(f'{name}: desteklenmeyen DLC kitabı sürümü ({sha[:12]}); atlandı')
            continue
        dst = os.path.join(root, 'backup', f'dlc_{key}_en.babel.orig')
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        open(dst, 'wb').write(raw)
        print(f'{name}: {key} -> {dst}')
