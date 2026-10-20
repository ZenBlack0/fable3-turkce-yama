r"""Test yardımcısı (test_safe.ps1): bir DLC\99_tr_yama paketini YALNIZCA OKUYARAK özetler; ya da v1.1.0 biçiminde sahte paket üretir.
  python check_pkg.py show <paket_klasörü>     -> anahtar=değer satırları
  python check_pkg.py make110 <hedef_klasör>   -> v1.1.0 gibi (bank içi isRequired=true, xmb 'false') iki paketlik sahte paket yazar
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import dlc_bnk  # noqa: E402
import dlc_package  # noqa: E402


def show(pkg):
    cont = os.path.join(pkg, 'Content')
    xmb = open(os.path.join(cont, 'package_collection_info.xmb'), 'rb').read().decode('latin1')
    print('xmb_isRequired=' + ','.join(re.findall(r'<isRequired>\s*(\w+)', xmb)))
    print('xmb_uids=' + ','.join(re.findall(r'<packageUniqueId>\s*(\d+)', xmb)))
    H_INFO = dlc_package.fnv1('package_info.xml')
    H_BOOK = dlc_package.fnv1('language\\en-uk\\text\\book.babel')
    for bnk in sorted(f for f in os.listdir(cont) if f.endswith('.bnk')):
        p = os.path.join(cont, bnk)
        idx = dlc_bnk.read_index(p)
        info = [dlc_bnk.read_blob(p + '.dat', o, s).decode('latin1') for h, o, s in idx if h == H_INFO][0]
        req = re.search(r'<isRequired>\s*(\w+)', info).group(1)
        uid = re.search(r'<packageUniqueId>\s*(\d+)', info).group(1)
        print(f'bank={bnk} uid={uid} isRequired={req} entries={len(idx)} book={any(h == H_BOOK for h, _, _ in idx)} dat={os.path.getsize(p + ".dat")}')


def make110(dest):
    banks = [{'bank': 'tr_yama_us', 'desc': 'Understone DLC Turkce metinleri', 'uid': 120, 'order': 10000, 'book': b'ESKI-KITAP' * 50},
             {'bank': 'tr_yama_tk', 'desc': 'Traitors Keep DLC Turkce metinleri', 'uid': 121, 'order': 10001, 'book': b'ESKI-KITAP' * 50}]
    dlc_package.write_collection(dest, banks, version='1.1.0')   # varsayılanlar = v1.1.0 davranışı (zorunlu)


if __name__ == '__main__':
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    {'show': show, 'make110': make110}[sys.argv[1]](sys.argv[2])
