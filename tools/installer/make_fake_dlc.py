r"""Test yardımcısı (BAKIMCI): work\fake_dlc\DLC altında SAHTE DLC klasörleri üretir (gerçek oyuna dokunmaz).
Gerçek DLC arşivlerinin yerine, yalnızca İngilizce DLC kitabını (backup\dlc_*_en.babel.orig) içeren küçük .bnk/.bnk.dat çiftleri yazılır;
yanına bir "yabancı" DLC (içinde kitap yok) konur. test_safe.ps1 bunu sahte oyun klasörüne kopyalar.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import dlc_package  # noqa: E402

OUT = os.path.join(ROOT, 'work', 'fake_dlc', 'DLC')
BOOK = 'language\\en-uk\\text\\book.babel'


def main():
    for rel, key, bank in (('understone_quest', 'understone', 'dlc_freeforall'), ('traitors_keep', 'traitors', 'dlc2free')):
        book = open(os.path.join(ROOT, 'backup', f'dlc_{key}_en.babel.orig'), 'rb').read()
        d = os.path.join(OUT, rel, 'Content')
        os.makedirs(d, exist_ok=True)
        bnk, dat = dlc_package.build_archive([('package_info.xml', b'<package/>'), (BOOK, book), ('scripts\\dummy.lua', b'-- dummy')])
        open(os.path.join(d, bank + '.bnk'), 'wb').write(bnk)
        open(os.path.join(d, bank + '.bnk.dat'), 'wb').write(dat)
        open(os.path.join(OUT, rel, 'content.xbx'), 'wb').write(b'SAHTE-' + rel.encode())
    d = os.path.join(OUT, '99_dlc2_fixes', 'Content')
    os.makedirs(d, exist_ok=True)
    bnk, dat = dlc_package.build_archive([('package_info.xml', b'<package/>')])
    open(os.path.join(d, 'dlc2_fixes.bnk'), 'wb').write(bnk)
    open(os.path.join(d, 'dlc2_fixes.bnk.dat'), 'wb').write(dat)
    print('sahte DLC klasörü:', OUT)


if __name__ == '__main__':
    main()
