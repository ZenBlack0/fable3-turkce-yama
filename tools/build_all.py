r"""Tek komutla derleme: doğrulama -> book_pack + font delta -> f3patch -> kurucu -> paketler -> SHA256SUMS -> tarama.
  python tools/build_all.py [--skip-validate]
Sürüm ve hash'ler manifest.json'dan okunur. Çıktılar output\ klasöründe:
  Fable3_Turkce_Yama_vX.exe, Fable3_Turkce_Yama_vX.zip, SHA256SUMS.txt, scan_release.txt
Herhangi bir adım başarısız olursa derleme DURUR (çıkış kodu != 0).
Not: Bu betik orijinal oyun dosyalarına (backup\*.orig) yalnızca OKUR.
"""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, 'tools')
sys.path.insert(0, TOOLS)
MANIFEST = os.path.join(ROOT, 'manifest.json')


def sha(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for c in iter(lambda: f.read(1 << 20), b''):
            h.update(c)
    return h.hexdigest()


def step(n, title):
    print(f'\n=== [{n}] {title} ({time.strftime("%H:%M:%S")}) ===', flush=True)


def run(*args):
    r = subprocess.run([sys.executable, *args], cwd=ROOT)
    if r.returncode:
        sys.exit(f'ADIM BAŞARISIZ (çıkış {r.returncode}): {" ".join(os.path.basename(a) for a in args)}')


def crlf(text):
    return text.replace('\r\n', '\n').replace('\n', '\r\n')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--skip-validate', action='store_true')
    ap.add_argument('--no-repo', action='store_true', help='depo klasörünü yeniden üretme/taramaya katma')
    a = ap.parse_args()
    man = json.load(open(MANIFEST, encoding='utf-8'))
    ver = man['version']
    tag = man['tag']
    name = f'Fable3_Turkce_Yama_{tag}'
    out = os.path.join(ROOT, 'output')
    if os.path.isdir(out):
        assert os.path.basename(out) == 'output'
        for n in os.listdir(out):
            p = os.path.join(out, n)
            if os.path.isfile(p):
                os.remove(p)
    os.makedirs(out, exist_ok=True)

    step(1, 'Doğrulama (validate_all.py)')
    if a.skip_validate:
        print('ATLANDI (--skip-validate)')
    else:
        run(os.path.join(TOOLS, 'validate_all.py'))

    step(2, 'book_pack + font delta + f3patch + kurucu (build.py --exe)')
    run(os.path.join(TOOLS, 'build.py'), '--exe', tag)
    exe_src = os.path.join(ROOT, 'dist', tag, name + '.exe')
    if not os.path.exists(exe_src):
        sys.exit('kurucu üretilemedi: ' + exe_src)
    exe = os.path.join(out, name + '.exe')
    shutil.copyfile(exe_src, exe)

    step('2b', 'Kurucu selftest (/SELFTEST, test_selftest.ps1)')
    st = os.path.join(TOOLS, 'installer', 'test_selftest.ps1')
    if os.path.exists(st):
        r = subprocess.run(['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', st, '-Exe', exe,
                            '-Orig', os.path.join(ROOT, 'backup')], cwd=ROOT)
        if r.returncode:
            sys.exit('ADIM BAŞARISIZ: kurucu selftest')
    else:
        print('UYARI: test_selftest.ps1 bu klasörde yok (depo kopyası); selftest elle çalıştırılabilir: exe /SELFTEST=günlük.txt /ORIGDIR=klasör')

    step(3, 'Oyuncu paketi (zip)')
    import gen_docs
    okubeni_text = gen_docs.render_okubeni()
    sums_in_zip = f'{sha(exe)} *{name}.exe\r\n'
    zp = os.path.join(out, name + '.zip')
    fixed = (2026, 1, 1, 0, 0, 0)          # sabit zaman damgası: zip içeriği yeniden üretilebilir olsun

    def zadd(z, arcname, data):
        zi = zipfile.ZipInfo(arcname, fixed)
        zi.compress_type = zipfile.ZIP_DEFLATED
        zi.external_attr = 0o644 << 16
        z.writestr(zi, data, compresslevel=9)
    with zipfile.ZipFile(zp, 'w') as z:
        zadd(z, name + '.exe', open(exe, 'rb').read())
        zadd(z, 'OKUBENI.txt', ('\ufeff' + crlf(okubeni_text)).encode('utf-8'))
        zadd(z, 'SHA256SUMS.txt', sums_in_zip.encode('ascii'))
    print('zip:', zp, f'{os.path.getsize(zp):,} bayt')

    step(4, 'output\\SHA256SUMS.txt')
    sums = f'{sha(exe)} *{name}.exe\r\n{sha(zp)} *{name}.zip\r\n'
    open(os.path.join(out, 'SHA256SUMS.txt'), 'w', encoding='ascii', newline='').write(sums)
    print(sums)
    man['package'] = {
        'exe': {'name': name + '.exe', 'sha256': sha(exe), 'size': os.path.getsize(exe)},
        'zip': {'name': name + '.zip', 'sha256': sha(zp), 'size': os.path.getsize(zp)},
    }
    json.dump(man, open(os.path.join(out, 'manifest.built.json'), 'w', encoding='utf-8', newline='\n'), ensure_ascii=False, indent=2)

    if not a.no_repo and os.path.isdir(os.path.join(ROOT, '.git')):
        # GitHub deposunun kendisinden (klondan) çalışıyorsunuz: depo klasörü üretecek yerel çalışma alanı yok, depo = bu klasör
        print('\n(4b atlandı: bu klasör zaten bir git deposu (klon). Yayın öncesi `git status` ile eklenecek dosyaları gözden geçirin.)')
        a.no_repo = True
    if not a.no_repo:
        step('4b', 'Depo klasörü (make_github_repo.py)')
        run(os.path.join(TOOLS, 'make_github_repo.py'))

    step(5, 'Yayın taraması (scan_release.py)')
    run(os.path.join(TOOLS, 'scan_release.py'))
    print('\nTAMAM. Çıktılar:', out)


if __name__ == '__main__':
    main()
