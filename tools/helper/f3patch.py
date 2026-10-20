"""f3patch — Fable III Türkçe Yama yardımcı aracı (kurulum programı tarafından çağrılır).

  f3patch book --orig <book.babel> --pack <book_pack.lzma> --orig-sha <sha256> --expect <sha256> --out <cikis>
  f3patch dlc  --game <oyun klasörü> --pack <book_pack.lzma> --out <cikis klasörü> [--version X]

book: Kullanıcının KENDİ orijinal book.babel dosyasını okur, paketteki "kayıt ID'si -> Türkçe" çevirileri uygular,
      dosyayı yeniden paketler ve tam altyazı bayrağını (köylü konuşmaları dahil tüm diyaloglar) ayarlar.
dlc : Kullanıcıda kurulu DLC'lerin (Understone, Traitors Keep) KENDİ İngilizce kitaplarını OKUR (DLC dosyalarına yazmaz),
      Türkçe karşılıklarıyla yeni bir DLC paketi (99_tr_yama) üretir ve <cikis>\\rapor.txt yazar:
      OK|<göreli yol>|<sha256>  /  SKIP|<ad>|<neden>  /  INFO|<ileti>.  Bilinmeyen DLC sürümleri atlanır (hata değildir).
Pakette oyun metni/dosyası yoktur.
Çıkış kodları: 0 tamam | 3 girdi orijinal değil (HİÇBİR ŞEY yazılmaz) | 4 çıktı hash'i beklenenle uyuşmuyor (çıktı silinir)
                | 5 paket okunamadı | 2 hatalı kullanım
"""
import argparse
import hashlib
import json
import lzma
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from babel import Babel, write_babel          # noqa: E402
from repack import apply_translations         # noqa: E402
import flags                                  # noqa: E402
import dlc_bnk                                # noqa: E402
import dlc_build                              # noqa: E402
import dlc_package                            # noqa: E402


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def load_pack(path):
    return json.loads(lzma.decompress(open(path, 'rb').read()).decode('utf-8'))


def cmd_book(a):
    if sha(a.orig).lower() != a.orig_sha.lower():
        print('GIRDI_ORIJINAL_DEGIL', sha(a.orig))
        return 3
    try:
        pk = load_pack(a.pack)
        by_id = {}
        for ids, tr in pk['tr']:
            for i in ids:
                by_id[f'0x{i:08X}'] = tr
        dialog = set(pk['dialog'])
    except Exception as e:                                     # noqa: BLE001
        print('PAKET_OKUNAMADI', e)
        return 5
    tmp = a.out + '.partial'
    babel = Babel(a.orig)
    new_texts, st = apply_translations(babel, by_id, {}, {})
    write_babel(babel, new_texts, tmp, 0)
    flags.set_subtitle_flags(tmp, dialog)
    got = sha(tmp)
    if got.lower() != a.expect.lower():
        os.remove(tmp)
        print('CIKTI_HASH_UYUSMUYOR', got)
        return 4
    os.replace(tmp, a.out)
    print('TAMAM', st['applied'], got)
    return 0


def cmd_dlc(a):
    try:
        pk = load_pack(a.pack)
    except Exception as e:                                     # noqa: BLE001
        print('PAKET_OKUNAMADI', e)
        return 5
    defs = pk.get('dlc', {})
    os.makedirs(a.out, exist_ok=True)
    rep = []
    banks = []
    found = dlc_bnk.packs(a.game, skip_dirs=(dlc_package.FOLDER,))
    if not found:
        rep.append('INFO|kurulu DLC kitabi bulunamadi; DLC paketi eklenmeyecek')
    for name in sorted(found):
        try:
            raw = dlc_bnk.find_en_book(found[name])
        except Exception as e:                                 # noqa: BLE001
            rep.append(f'SKIP|{name}|DLC arsivi okunamadi: {e}')
            continue
        s = dlc_build.sha256(raw)
        key = next((k for k, v in defs.items() if v['src_sha'] == s), None)
        if key is None:
            rep.append(f'SKIP|{name}|desteklenmeyen DLC kitabi surumu (SHA256 {s[:12]})')
            continue
        v = defs[key]
        data, applied = dlc_build.build_dlc_book(raw, v['tr'], v['dialog'])
        if dlc_build.sha256(data) != v['out_sha']:
            rep.append(f'SKIP|{name}|uretilen DLC kitabinin SHA256 degeri beklenenle uyusmuyor')
            continue
        banks.append({'bank': v['bank'], 'desc': v['desc'], 'uid': v['uid'], 'order': v['order'], 'book': data,
                      'required': False, 'xmb_required': 'False'})   # v1.1.1: kayıtlar pakete bağlanmaz (isRequired=False)
        rep.append(f'INFO|{name}: {key} DLC kitabi Turkcelestirildi ({applied} kayit)')
    if banks:
        pkg = os.path.join(a.out, dlc_package.FOLDER)
        for rel, h in dlc_package.write_collection(pkg, banks, version=a.version):
            rep.append(f'OK|{rel}|{h}')
    with open(os.path.join(a.out, 'rapor.txt'), 'w', encoding='utf-8', newline='') as f:
        f.write('\r\n'.join(rep) + '\r\n')
    print('\n'.join(rep))
    return 0


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest='cmd', required=True)
    b = sub.add_parser('book')
    b.add_argument('--orig', required=True)
    b.add_argument('--pack', required=True)
    b.add_argument('--orig-sha', required=True)
    b.add_argument('--expect', required=True)
    b.add_argument('--out', required=True)
    d = sub.add_parser('dlc')
    d.add_argument('--game', required=True)
    d.add_argument('--pack', required=True)
    d.add_argument('--out', required=True)
    d.add_argument('--version', default='')
    a = ap.parse_args()
    sys.exit(cmd_book(a) if a.cmd == 'book' else cmd_dlc(a))


if __name__ == '__main__':
    main()
