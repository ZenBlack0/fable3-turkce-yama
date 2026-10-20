"""TEST.bat için sahte oyun + sahte kayıt klasörü üretir: python fake_savetest.py <kök> [orijinal_paket_var=1]"""
import os
import shutil
import sys

root = sys.argv[1]
with_pkg = (sys.argv[2] if len(sys.argv) > 2 else '1') == '1'
kit = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))     # tests\oyun_ici
shutil.rmtree(root, ignore_errors=True)
g = os.path.join(root, 'Fable 3')
s = os.path.join(root, 'Saved Games', 'Lionhead Studios', 'Fable 3')
os.makedirs(os.path.join(g, 'DLC', 'understone_quest', 'Content'))
os.makedirs(os.path.join(g, 'data', 'language', 'en-uk', 'text'))
os.makedirs(os.path.join(g, 'data', 'language', 'en-uk', 'fonts'))
open(os.path.join(g, 'data', 'language', 'en-uk', 'text', 'book.babel'), 'wb').write(b'BOOK' * 100)
open(os.path.join(g, 'data', 'language', 'en-uk', 'fonts', 'gui_normal.bft'), 'wb').write(b'FONT' * 100)
open(os.path.join(g, 'DLC', 'understone_quest', 'Content', 'x.bnk'), 'wb').write(b'U')
if with_pkg:
    shutil.copytree(os.path.join(kit, 'paketler', 'V0', '99_tr_yama'), os.path.join(g, 'DLC', '99_tr_yama'))
os.makedirs(os.path.join(s, '1122334400000000'))


def pk(tag, ids):
    return ''.join(f'\t\t<{tag}>\n\t\t\t<PackageId type="uint">{i}</PackageId>\n\t\t</{tag}>\n' for i in ids)


xml = ('<?xml version="1.0"?>\n<SaveInfo>\n\t<GameVersion>\n\t\t<CompiledVersion type="uint">4</CompiledVersion>\n'
       + pk('InstalledPackage', [98, 120, 121, 60, 61, 30]) + pk('PremiumPackage', [98, 120, 121]) + pk('RequiredPackage', [98, 120, 121, 60, 61, 30])
       + '\t</GameVersion>\n</SaveInfo>\n')
open(os.path.join(s, '1122334400000000', 'hero1autosave_chaptersave.bin'), 'wb').write(b'\x7a\x10\x00\x00' + xml.encode('utf-8') + b'\x00\x00\x00')
open(os.path.join(s, '1122334400000000', 'hero1autosave_mainsave.bin'), 'wb').write(os.urandom(5000))
print(g)
print(s)
