r"""GitHub deposu klasörünü hazırlar: dist\github_repo  (BAKIMCI aracı; ASLA push yapmaz).
  python tools/make_github_repo.py [--commit "mesaj"]

- Klasör zaten varsa mevcut .git geçmişi KORUNUR; yalnızca çalışma dosyaları yeniden üretilir.
- --commit: değişiklikleri depo içinde normal bir commit olarak ekler (geçmiş yeniden yazılmaz, force yok).
  Commit kimliği yalnızca bu depoya yereldir (global git ayarlarına dokunulmaz).
- Belgeler (README, docs, LICENSE, ISSUE_TEMPLATE) gen_docs.py ile manifest.json / output\manifest.built.json / vt_report.json'dan üretilir.
Oyun verisi içermez: backup, extracted, work, dist, .orig/.babel/.bft, tr.jsonl (İngilizce kaynak), quest_names.csv hariç.
Ardından scan_release.py ile taranması gerekir (build_all.py bunu yapar).
"""
import argparse
import json
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import gen_docs  # noqa: E402

DST = os.path.join(ROOT, 'dist', 'github_repo')
GIT_NAME = 'ZenBlack0'
GIT_EMAIL = '163824246+ZenBlack0@users.noreply.github.com'
TOOLS = ['babel.py', 'extract.py', 'repack.py', 'font_patch.py', 'build.py', 'build_all.py', 'validate_all.py', 'scan_release.py',
         'gen_docs.py', 'make_github_repo.py', 'qa.py', 'flags.py', 'trtext.py', 'init_translations.py', 'import_public.py',
         'export_public.py', 'tr_tool.py', 'show.py', 'nuitka_helper.bat', 'init_dlc.py', 'dlc_bnk.py', 'dlc_build.py', 'dlc_package.py', 'verify_output.py', 'make_test_save.py']


def cp(src_rel, dst_rel=None):
    src = os.path.join(ROOT, *src_rel.split('/'))
    dst = os.path.join(DST, *(dst_rel or src_rel).split('/'))
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copyfile(src, dst)


def clean():
    assert os.path.basename(DST) == 'github_repo' and os.path.basename(os.path.dirname(DST)) == 'dist'
    os.makedirs(DST, exist_ok=True)
    for n in os.listdir(DST):
        if n == '.git':
            continue
        p = os.path.join(DST, n)
        shutil.rmtree(p) if os.path.isdir(p) else os.remove(p)


def git(*args, check=True):
    r = subprocess.run(['git', *args], cwd=DST, capture_output=True, text=True, encoding='utf-8', errors='replace')
    if check and r.returncode:
        sys.exit(f'git {" ".join(args)} başarısız:\n{r.stdout}\n{r.stderr}')
    return r


def build():
    clean()
    for t in TOOLS:
        cp('tools/' + t)
    for rel in ('tools/helper/f3patch.py', 'tools/installer/fable3_tr.iss', 'tools/installer/known_hashes.inc', 'tools/installer/xdelta3/COPYING.txt',
                'translations/tr_public.jsonl', 'translations/block_map.json', 'translations/overrides.csv',
                'glossary.csv', 'docs/FORMAT.md', 'docs/STYLE_VILLAGERS.md', 'docs/GELISTIRICI.md', 'docs/KURULUM_GELISTIRICI.md',
                'tools/installer/test_safe.ps1', 'tools/installer/test_exe.ps1', 'tools/installer/test_detect.ps1',
                'tools/installer/test_gui.ps1', 'tools/installer/test_selftest.ps1', 'tools/installer/shot_instpage.ps1',
                'tools/installer/make_fake_dlc.py', 'tools/installer/check_pkg.py', '.gitignore'):
        if rel == '.gitignore':
            cp('tools/repo_files/.gitignore', '.gitignore')
        else:
            cp(rel)
    cp('tools/repo_files/xdelta3_README.md', 'tools/installer/xdelta3/README.md')
    for n in ('LICENSE', 'LICENSE-TRANSLATION', 'xdelta3_README.md', '.gitignore'):
        cp('tools/repo_files/' + n)      # gen_docs.py (LICENSE şablonları) klondan da çalışsın
    for n in os.listdir(os.path.join(ROOT, 'tools', 'docs_src')):
        p = os.path.join(ROOT, 'tools', 'docs_src', n)
        if os.path.isfile(p):
            cp('tools/docs_src/' + n)
    for n in os.listdir(os.path.join(ROOT, 'tools', 'docs_src', 'ISSUE_TEMPLATE')):
        cp('tools/docs_src/ISSUE_TEMPLATE/' + n)
    # oyun içi test kitleri (tests/oyun_ici): üretilen/indirilen/yerel dosyalar hariç
    kit = os.path.join(ROOT, 'tests', 'oyun_ici')
    for d_, ds_, fs_ in os.walk(kit):
        ds_[:] = [x for x in ds_ if x not in ('paketler', '_cikarilan', '_indirilen', '__pycache__')]
        for f_ in fs_:
            if f_ == 'SONUC.txt':
                continue
            cp(os.path.relpath(os.path.join(d_, f_), ROOT).replace(os.sep, '/'))
    os.makedirs(os.path.join(DST, 'docs', 'ekran'), exist_ok=True)
    open(os.path.join(DST, 'docs', 'ekran', '.gitkeep'), 'w').close()
    # manifest: paket hash'leri dahil (derlenmiş sürüm)
    built = os.path.join(ROOT, 'output', 'manifest.built.json')
    src_man = built if os.path.exists(built) else os.path.join(ROOT, 'manifest.json')
    shutil.copyfile(src_man, os.path.join(DST, 'manifest.json'))
    gen_docs.write_repo_docs(DST)
    n = sum(len(f) for _, _, f in os.walk(DST) if '.git' not in _)
    print(f'Depo klasörü hazır: {DST} ({n} dosya, .git korundu: {os.path.isdir(os.path.join(DST, ".git"))})')


def commit(msg):
    if not os.path.isdir(os.path.join(DST, '.git')):
        git('init', '-b', 'main')
    git('config', 'user.name', GIT_NAME)
    git('config', 'user.email', GIT_EMAIL)
    git('add', '-A')
    if not git('status', '--porcelain').stdout.strip():
        print('Değişiklik yok, commit atlandı.')
        return
    man = json.load(open(os.path.join(ROOT, 'manifest.json'), encoding='utf-8'))
    git('commit', '-m', msg or f'{man["tag"]}: Fable III Türkçe Yama')
    print(git('log', '--oneline', '-5').stdout)


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--commit', nargs='?', const='')
    a = ap.parse_args()
    build()
    if a.commit is not None:
        commit(a.commit)
