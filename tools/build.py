r"""
Derleme: backup/ altındaki ORİJİNALLERDEN, tr.jsonl (ya da tr_public.jsonl) + overrides.csv ile book.babel (tam altyazı) ve
gui_normal.bft üretir; kurulum .exe'sini yapar.
  python tools/build.py --exe [vX.Y.Z]   -> dist/vX.Y.Z/Fable3_Turkce_Yama_vX.Y.Z.exe (build_all.py bunu çağırır)
  python tools/build.py --test NAME      -> work/tests/NAME/ (book.babel, gui_normal.bft, apply.bat, restore.bat) [oyun içi test]
  --max-block N  blok bölme (varsayılan 0 = kapalı)
  --force        QA hataları olsa da derle
Yama TEK sonuç üretir: tam altyazı (köylü konuşmaları dahil tüm konuşmalarda Türkçe altyazı). "Standart" mod YOKTUR.
DLC (Understone, Traitors Keep) metinleri kurulumda f3patch ile, kullanıcının kendi DLC kitabından üretilen ayrı bir DLC
paketi olarak eklenir (bkz. dlc_package.py). Oyun klasörüne hiçbir şey kopyalanmaz; yalnızca test apply.bat'ı kopyalar.
"""
import argparse
import contextlib
import hashlib
import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from init_translations import load_jsonl, OUT, ROOT
from repack import repack
from font_patch import patch_font
import flags
import qa

# Orijinal oyun dosyaları (SİZİN oyun kopyanızdan): varsayılan backup\*.orig; F3_ORIG_BABEL / F3_ORIG_FONT ile değiştirilebilir.
ORIG_BABEL = os.environ.get('F3_ORIG_BABEL') or os.path.join(ROOT, 'backup', 'book.babel.orig')
ORIG_FONT = os.environ.get('F3_ORIG_FONT') or os.path.join(ROOT, 'backup', 'gui_normal.bft.orig')
PUBLIC = os.path.join(ROOT, 'translations', 'tr_public.jsonl')   # paylaşılan çeviri: yalnızca kayıt ID'si + Türkçe
OVERRIDES = os.path.join(ROOT, 'translations', 'overrides.csv')
GAME = os.environ.get('F3_GAME', '')           # oyun klasörünüz; yalnızca --test apply.bat için (F3_GAME ortam değişkeni)

# Önceki sürümlerin çıktıları: kurucu bunları "kurulu (eski sürüm)" olarak TANIR (onarınca güncel sürüme geçirir; orijinal yedeğe dokunmaz).
LEGACY_BOOKS = {
    'cb177f4f59131d461b1881a6fa7d566e38dd0de7c5a7cd2be9bb062b2948eac4': 'v1.0-v1.1 Standart',
    '5dd31cf1c282daa72e4103eb3696304e25d805d632afd89ffce1bf879e77b9ae': 'v1.0-v1.0.2 Tam altyazı',
    '9a74253db94b115dc8b4dd093ec5ab88a8bf209b7dbdc8f018e2608fe2ff09d4': 'v0.9',
    'c60a703e3acd9061349751ce9eb154e07d9f4ac0bc983afcf64183a44668b5bb': 'v1.1.0 ara derleme',
    '3eba8894429ac5ffb35e750ae1edba59192e131724c005c128e5700bdcb66754': 'v1.1.0',
}
LEGACY_FONTS = {
    '0ba43fe00cb36458a2267e3cf1136895c070695364c7850bc1e600c319b6e5c1': 'v1.0-v1.0.2',
}


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for c in iter(lambda: f.read(1 << 20), b''):
            h.update(c)
    return h.hexdigest()


def write(path, text, enc, bom=False):
    with open(path, 'w', encoding='utf-8-sig' if bom else enc, newline='') as f:
        f.write(text.replace('\n', '\r\n'))


def build(outdir, max_block=0, force=False, test_name=None):
    """outdir\\book.babel (tam altyazı) + gui_normal.bft"""
    # yerel tr.jsonl (İngilizce kaynak içerir, depoda YOKTUR) varsa onu kullan; yoksa paylaşılan tr_public.jsonl
    use_public = os.environ.get('F3_PUBLIC') == '1' or not os.path.exists(OUT)
    trans = PUBLIC if use_public else OUT
    if not os.path.exists(ORIG_BABEL) or not os.path.exists(ORIG_FONT):
        sys.exit('Orijinal oyun dosyaları bulunamadı:\n  ' + ORIG_BABEL + '\n  ' + ORIG_FONT + '\nKendi oyununuzdan kopyalayın (README).')
    rows = load_jsonl(trans)
    if use_public:
        print(f'Çeviri kaynağı: {os.path.basename(trans)} (kayıt ID eşleştirmesi; QA atlandı - İngilizce kaynak yok)')
    else:
        err, warn, stats = qa.run(rows)
        print(f'QA: {len(err)} hata, {len(warn)} uyarı | done {stats["done"]} review {stats["review"]} todo {stats["todo"]}')
        if err and not force:
            for e in err[:20]:
                print('  HATA', e)
            sys.exit('QA hataları var; build durduruldu (--force ile geçilebilir).')
    os.makedirs(outdir, exist_ok=True)
    babel_out = os.path.join(outdir, 'book.babel')
    font_out = os.path.join(outdir, 'gui_normal.bft')
    repack(ORIG_BABEL, trans, babel_out, max_block, OVERRIDES)
    main_rows = [r for r in rows if not r.get('dlc')]
    print('Tam altyazı: bayrak ayarlanan kayıt', flags.set_subtitle_flags(babel_out, flags.dialog_ids(main_rows)))
    with contextlib.redirect_stdout(io.StringIO()):
        patch_font(ORIG_FONT, font_out, 'full_patch')
    if test_name:
        write_test_bats(outdir, test_name)
    print('Çıktı:', outdir)


def write_test_bats(dest, name):
    """apply.bat önce mevcut dosyaları _onceki'ye saklar (ilk çalışmada), restore.bat onları geri yükler."""
    if not GAME:
        sys.exit('--test için oyun klasörünü F3_GAME ortam değişkeniyle verin (örn. $env:F3_GAME = "D:\\...\\Fable 3").')
    lang = GAME + '\\data\\language\\en-uk'
    apply =('@echo off\r\nsetlocal\r\nset "GAME=%s"\r\nset "T=%%~dp0"\r\n' % GAME
             + 'tasklist /FI "IMAGENAME eq Fable3.exe" 2>nul | find /I "Fable3.exe" >nul && (echo Once oyunu kapatin. & pause & exit /b 1)\r\n'
             + 'if not exist "%T%_onceki" (\r\n  mkdir "%T%_onceki"\r\n'
             + '  copy /Y "%GAME%\\data\\language\\en-uk\\text\\book.babel" "%T%_onceki\\book.babel" >nul\r\n'
             + '  copy /Y "%GAME%\\data\\language\\en-uk\\fonts\\gui_normal.bft" "%T%_onceki\\gui_normal.bft" >nul\r\n)\r\n'
             + 'copy /Y "%T%book.babel" "%GAME%\\data\\language\\en-uk\\text\\book.babel" >nul\r\n'
             + 'copy /Y "%T%gui_normal.bft" "%GAME%\\data\\language\\en-uk\\fonts\\gui_normal.bft" >nul\r\n'
             + 'echo [' + name + '] uygulandi. Geri donmek icin restore.bat.\r\npause\r\n')
    restore = ('@echo off\r\nsetlocal\r\nset "GAME=%s"\r\nset "T=%%~dp0"\r\n' % GAME
               + 'if not exist "%T%_onceki\\book.babel" (echo _onceki yok. & pause & exit /b 1)\r\n'
               + 'copy /Y "%T%_onceki\\book.babel" "%GAME%\\data\\language\\en-uk\\text\\book.babel" >nul\r\n'
               + 'copy /Y "%T%_onceki\\gui_normal.bft" "%GAME%\\data\\language\\en-uk\\fonts\\gui_normal.bft" >nul\r\n'
               + 'echo Geri yuklendi.\r\npause\r\n')
    del lang
    write(os.path.join(dest, 'apply.bat'), apply.replace('\r\n', '\n'), 'ascii')
    write(os.path.join(dest, 'restore.bat'), restore.replace('\r\n', '\n'), 'ascii')


XDELTA_DIR = os.path.join(ROOT, 'tools', 'installer', 'xdelta3')
DELTA_DIR = os.path.join(ROOT, 'tools', 'installer', 'delta')          # kurulum paketine girecek dosyalar (derleme çıktısı)
HELPER_SRC = os.path.join(ROOT, 'tools', 'helper', 'f3patch.py')
EXPECTED = os.path.join(ROOT, 'manifest.json')                  # tek kaynak: sürüm, orijinal ve çıktı hash'leri
PY_PIN = (3, 14)                                                        # zlib çıktısı Python/zlib sürümüne bağlıdır
NOTICE = """Üçüncü taraf bileşenler / Third-party components
=================================================
Bu kurulum programı oyun dosyası ya da oyun metni içermez. İçindekiler:
 - book_pack: yalnızca "kayıt ID'si -> Türkçe çeviri" (LZMA sıkıştırmalı); İngilizce kaynak ve değişmeyen satırlar YOKTUR.
 - f3patch: kullanıcının KENDİ book.babel ve (kuruluysa) DLC kitaplarından çeviriyi uygulayıp yeniden paketleyen yardımcı program
   (Python + Nuitka/MSVC ile derlenmiştir; kaynak kodu depoda: tools/helper/f3patch.py).
 - xdelta3 + font.xdelta: yazı tipi (gui_normal.bft) için küçük bir fark dosyası.

xdelta3 3.1.0 (Joshua MacDonald) - GNU GPL v2 - xdelta3_COPYING.txt
  Kaynak kodu: https://github.com/jmacd/xdelta-gpl/releases/tag/v3.1.0  (xdelta3-3.1.0.tar.gz)
  xdelta3 AYRI bir program olarak çalıştırılır.
Nuitka çalışma zamanı (derlenmiş f3patch içinde) - Apache License 2.0 - nuitka_LICENSE.txt   https://nuitka.net
Python çalışma zamanı (python314.dll ve modüller) - PSF License - python_LICENSE.txt   https://www.python.org
OpenSSL (libcrypto/libssl, Python ile gelir) - Apache License 2.0   https://www.openssl.org
Microsoft Visual C++ çalışma zamanı (vcruntime140*.dll) - Microsoft Visual C++ Redistributable

Bu yamanın kendi araçları MIT lisanslıdır; çeviri metinleri CC BY-NC-SA 4.0 lisanslıdır.
"""


def run_xdelta(*args):
    import subprocess
    xd = os.path.join(XDELTA_DIR, 'xdelta3.exe')
    r = subprocess.run([xd, *args], capture_output=True, text=True, errors='replace')
    if r.returncode:
        sys.exit('xdelta3 hata: ' + ' '.join(args) + '\n' + r.stderr[-300:])


def dlc_sources(man):
    """manifest'teki DLC tanımları + (varsa) yerel İngilizce DLC kitapları (backup\\dlc_<ad>_en.babel.orig)."""
    out = {}
    for key, d in man.get('dlc', {}).items():
        p = os.environ.get('F3_DLC_' + key.upper()) or os.path.join(ROOT, 'backup', f'dlc_{key}_en.babel.orig')
        out[key] = (d, p if os.path.exists(p) else None)
    return out


def make_pack(dst, verify=True):
    """translations/tr_public.jsonl -> LZMA'lı 'ID -> Türkçe' paketi. Keep satırları ve İngilizce kaynak YOK;
    yalnızca diyalog kayıtlarının (altyazı bayrağı için) düz ID listesi vardır (metin içermez).
    DLC bölümü: {ad: {src_sha, out_sha, bank, uid, order, desc, tr, dialog}}. Yerel DLC kitabı varsa üretim burada DOĞRULANIR."""
    import lzma
    import dlc_build
    man = json.load(open(EXPECTED, encoding='utf-8'))
    rows = load_jsonl(PUBLIC)
    tr, dialog = [], []
    for r in rows:
        if r.get('dlc'):
            continue
        if r.get('cat') == 'dialog':
            dialog.extend(int(i, 16) for i in r['ids'])
        if r.get('status') in ('done', 'review') and r.get('tr'):
            tr.append([[int(i, 16) for i in r['ids']], r['tr']])
    pk = {'fmt': 3, 'tr': tr, 'dialog': sorted(set(dialog)), 'dlc': {}}
    for key, (d, src_path) in dlc_sources(man).items():
        trd, dlg = [], []
        for r in rows:
            if r.get('dlc') != key:
                continue
            if r.get('cat') == 'dialog':
                dlg.extend(int(i, 16) for i in r['ids'])
            if r.get('status') in ('done', 'review') and r.get('tr'):
                trd.append([[int(i, 16) for i in r['ids']], r['tr']])
        dlg = sorted(set(dlg))
        if src_path and verify:
            raw = open(src_path, 'rb').read()
            if dlc_build.sha256(raw) != d['src_sha']:
                sys.exit(f'DLC kaynağı manifest ile uyuşmuyor: {src_path}')
            data, applied = dlc_build.build_dlc_book(raw, trd, dlg)
            got = dlc_build.sha256(data)
            if d['out_sha'] == 'TBD':
                print(f'UYARI: manifest dlc.{key}.out_sha = TBD (ARA DERLEME); hesaplanan {got} pakete yazıldı. Çeviri bitince manifest.json dosyasına işleyin.')
                d = dict(d, out_sha=got)
            elif got != d['out_sha']:
                sys.exit(f'DLC "{key}" çıktı hash\'i manifest ile uyuşmuyor:\n  beklenen {d["out_sha"]}\n  üretilen {got}\n(manifest.json dlc.{key}.out_sha değerini güncelleyin)')
            print(f'DLC {key}: {applied} kayıt, çıktı {got[:12]} doğrulandı')
        elif not src_path:
            print(f'UYARI: DLC {key} İngilizce kitabı yok; çıktı hash\'i derlemede DOĞRULANMADI (kurulum sırasında doğrulanır)')
        pk['dlc'][key] = {'src_sha': d['src_sha'], 'out_sha': d['out_sha'], 'bank': d['bank'], 'uid': d['uid'], 'order': d['order'],
                          'desc': d['desc'], 'tr': trd, 'dialog': dlg}
    blob = json.dumps(pk, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
    with open(dst, 'wb') as f:
        f.write(lzma.compress(blob, preset=9 | lzma.PRESET_EXTREME))
    print(f'Çeviri paketi: {len(tr)} satır, {len(set(dialog))} diyalog ID, DLC: {sorted(pk["dlc"])} -> {os.path.getsize(dst):,} bayt')


def build_helper():
    """f3patch yardımcısını Nuitka --standalone (klasör çıktısı) + MSVC ile derler -> DELTA_DIR/f3patch/ (--onefile ve UPX YOK)"""
    import shutil
    import subprocess
    man = json.load(open(EXPECTED, encoding="utf-8"))
    work = os.path.join(ROOT, 'work', 'helper_build')
    if os.path.exists(work):
        assert os.path.basename(work) == 'helper_build'
        shutil.rmtree(work)
    os.makedirs(work)
    out = os.path.join(DELTA_DIR, 'f3patch')
    if os.path.exists(out):
        assert os.path.basename(DELTA_DIR) == 'delta'
        shutil.rmtree(out)
    bat = os.path.join(ROOT, 'tools', 'nuitka_helper.bat')
    r = subprocess.run(['cmd', '/c', bat, sys.executable, ROOT, work, man['version']], capture_output=True, text=True, errors='replace')
    open(os.path.join(ROOT, 'work', 'nuitka_build.log'), 'w', encoding='utf-8').write(r.stdout + chr(10) + r.stderr)
    dist = os.path.join(work, 'f3patch.dist')
    if r.returncode or not os.path.exists(os.path.join(dist, 'f3patch.exe')):
        sys.exit('Nuitka/MSVC derlemesi başarısız (work/nuitka_build.log): ' + (r.stdout + r.stderr)[-800:])
    shutil.copytree(dist, out)
    total = sum(os.path.getsize(os.path.join(d, f)) for d, _, fs in os.walk(out) for f in fs)
    print(f'Yardımcı program: {out} ({total:,} bayt, Nuitka standalone + MSVC)')
    return os.path.join(out, 'f3patch.exe')


def known_hashes_inc(exp):
    nl = chr(10)
    books = [exp['book']] + list(LEGACY_BOOKS)
    fonts = [exp['font']] + list(LEGACY_FONTS)

    def fn(name, lst):
        return (f'function {name}(const H: String): Boolean;' + nl + 'begin' + nl + '  Result := False;' + nl
                + ''.join(f"  if H = '{x}' then Result := True;" + nl for x in sorted(set(lst))) + 'end;' + nl + nl)
    return ('const' + nl + f"  EXP_BOOK = '{exp['book']}';" + nl + f"  EXP_FONT = '{exp['font']}';" + nl + nl
            + fn('IsKnownBook', books) + fn('IsKnownFont', fonts)
            + '{ 0 yok, 1 güncel sürüm, 2 eski sürüm (Standart ya da eski Tam altyazı) }' + nl
            + 'function BookModeOf(const H: String): Integer;' + nl + 'begin' + nl + '  Result := 0;' + nl
            + ''.join(f"  if H = '{x}' then Result := 2;" + nl for x in sorted(LEGACY_BOOKS))
            + f"  if H = '{exp['book']}' then Result := 1;" + nl + 'end;' + nl + nl)


def build_delta(version='v1.1.0'):
    """Kurulum .exe'si: oyun dosyası/metni İÇERMEZ. Kitap: 'ID->Türkçe' paketi + f3patch yardımcısı; font: küçük xdelta3 farkı."""
    import shutil
    import subprocess
    if sys.version_info[:2] != PY_PIN:
        print(f'UYARI: Python {sys.version_info[:2]} != {PY_PIN}; zlib çıktısı değişebilir (hash doğrulaması yapılacak).')
    import zlib
    print('Python', sys.version.split()[0], '| zlib', zlib.ZLIB_RUNTIME_VERSION)
    ver3 = version.lstrip('v')
    outdir = os.path.join(ROOT, 'dist', version)
    os.makedirs(outdir, exist_ok=True)
    kit = os.path.join(ROOT, 'work', 'delta_build')
    if os.path.exists(OUT):                         # bakımcı: yerel tr.jsonl -> paylaşılan tr_public.jsonl
        subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'export_public.py')], check=True)
    build(kit, 0, False, None)
    exp = json.load(open(EXPECTED, encoding='utf-8'))['outputs']
    got = {'book': sha(os.path.join(kit, 'book.babel')), 'font': sha(os.path.join(kit, 'gui_normal.bft'))}
    if got != {k: exp[k] for k in got}:
        sys.exit(f'Çıktı hash\'leri beklenenle (manifest.json) uyuşmuyor:\n  beklenen {exp}\n  üretilen {got}')
    xd = os.path.join(XDELTA_DIR, 'xdelta3.exe')
    if not os.path.exists(xd):
        sys.exit('xdelta3.exe yok: ' + xd + ' (bkz. tools/installer/xdelta3/README.md)')
    if os.path.exists(DELTA_DIR):
        assert os.path.basename(DELTA_DIR) == 'delta'
        shutil.rmtree(DELTA_DIR)
    os.makedirs(DELTA_DIR)
    # 1) çeviri paketi + yardımcı
    pack = os.path.join(DELTA_DIR, 'book_pack.lzma')
    make_pack(pack)
    helper = build_helper()
    # 2) yardımcı kendi kendine sınanır: orijinalden aynı hash'i vermeli; orijinal olmayan girdide yazmadan durmalı
    chk = os.path.join(kit, '_chk.bin')
    if os.path.exists(chk):
        os.remove(chk)
    r = subprocess.run([helper, 'book', '--orig', ORIG_BABEL, '--pack', pack, '--orig-sha', sha(ORIG_BABEL),
                        '--expect', exp['book'], '--out', chk], capture_output=True, text=True)
    assert r.returncode == 0 and sha(chk) == exp['book'], f'yardımcı hash uyuşmadı: {r.stdout} {r.stderr}'
    print(f'yardımcı: {sha(chk)[:12]} (manifest ile aynı)')
    os.remove(chk)
    bad = os.path.join(kit, '_notorig.bin')
    open(bad, 'wb').write(b'bu orijinal degil')
    r = subprocess.run([helper, 'book', '--orig', bad, '--pack', pack, '--orig-sha', sha(ORIG_BABEL),
                        '--expect', exp['book'], '--out', chk], capture_output=True, text=True)
    assert r.returncode == 3 and not os.path.exists(chk), 'orijinal olmayan girdi reddedilmedi'
    os.remove(bad)
    print('yardımcı: orijinal olmayan girdi reddedildi (çıkış 3, çıktı yazılmadı)')
    # 3) font: küçük xdelta3 farkı (-A= : uygulama başlığı/yerel yol gömülmez)
    run_xdelta('-A=', '-e', '-9', '-f', '-s', ORIG_FONT, os.path.join(kit, 'gui_normal.bft'), os.path.join(DELTA_DIR, 'font.xdelta'))
    run_xdelta('-A=', '-d', '-f', '-s', ORIG_FONT, os.path.join(DELTA_DIR, 'font.xdelta'), chk)
    assert sha(chk) == exp['font'], 'font delta doğrulaması başarısız'
    os.remove(chk)
    print(f'font.xdelta: {os.path.getsize(os.path.join(DELTA_DIR, "font.xdelta")):,} bayt, doğrulandı')
    # 4) lisanslar
    shutil.copyfile(xd, os.path.join(DELTA_DIR, 'xdelta3.exe'))
    shutil.copyfile(os.path.join(XDELTA_DIR, 'COPYING.txt'), os.path.join(DELTA_DIR, 'xdelta3_COPYING.txt'))
    import importlib.metadata as md
    nl_ = [f for f in md.distribution('nuitka').files if f.name == 'LICENSE-RUNTIME.txt'][0]
    shutil.copyfile(nl_.locate(), os.path.join(DELTA_DIR, 'nuitka_LICENSE.txt'))
    shutil.copyfile(os.path.join(sys.base_prefix, 'LICENSE.txt'), os.path.join(DELTA_DIR, 'python_LICENSE.txt'))
    write(os.path.join(DELTA_DIR, 'NOTICE.txt'), NOTICE, 'utf-8', bom=True)
    # 4b) yer tutucu DLC paketleri (kaldırıcı, v1.1.0 kayıtları açılabilsin diye gerektiğinde bunlardan birini bırakır;
    #     aynı kimlikler 120/121, yalnızca package_info.xml, isRequired=False, METİN YOK)
    import dlc_package
    man_dlc = json.load(open(EXPECTED, encoding='utf-8'))['dlc']
    for variant, keys in (('both', list(man_dlc)), ('us', ['understone']), ('tk', ['traitors'])):
        banks = [{'bank': man_dlc[k]['bank'], 'desc': man_dlc[k]['desc'] + ' (yer tutucu)', 'uid': man_dlc[k]['uid'], 'order': man_dlc[k]['order'],
                  'book': None, 'required': False, 'xmb_required': 'False'} for k in keys]
        dlc_package.write_collection(os.path.join(DELTA_DIR, 'placeholder', variant, dlc_package.FOLDER), banks, version='yer tutucu')
    ph_got = {}
    for variant in ('both', 'us', 'tk'):
        r_ = os.path.join(DELTA_DIR, 'placeholder', variant, dlc_package.FOLDER)
        ph_got[variant] = {}
        for dd_, _, fs_ in os.walk(r_):
            for f_ in fs_:
                p_ = os.path.join(dd_, f_)
                ph_got[variant][os.path.relpath(p_, r_).replace(os.sep, '/')] = sha(p_)
        ph_got[variant] = dict(sorted(ph_got[variant].items()))
    ph_exp = json.load(open(EXPECTED, encoding='utf-8')).get('placeholders')
    if ph_exp is not None and ph_exp != ph_got:
        sys.exit('Yer tutucu paketleri manifest.json ile uyuşmuyor (manifest.json "placeholders" değerlerini güncelleyin).')
    print('yer tutucu paketleri: both/us/tk' + (' (manifest ile aynı)' if ph_exp is not None else ' (manifest.json içinde placeholders yok)'))
    # 5) bilinen hash'ler + beklenen sabitler (Standart ve eski çıktılar YALNIZCA "eski sürüm" tanıması içindir)
    open(os.path.join(ROOT, 'tools', 'installer', 'known_hashes.inc'), 'w', encoding='utf-8').write(known_hashes_inc(exp))
    iscc = None
    for c in (os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Programs', 'Inno Setup 6', 'ISCC.exe'),
              r'C:\Program Files (x86)\Inno Setup 6\ISCC.exe', r'C:\Program Files\Inno Setup 6\ISCC.exe'):
        if os.path.exists(c):
            iscc = c
            break
    if not iscc:
        sys.exit('Inno Setup bulunamadı: winget install JRSoftware.InnoSetup')
    name = 'Fable3_Turkce_Yama_' + version
    cmd = [iscc, f'/DVersion={ver3}', f'/DSrcDir={DELTA_DIR}', f'/DOutDir={outdir}', f'/DOutName={name}',
           os.path.join(ROOT, 'tools', 'installer', 'fable3_tr.iss')]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='replace')
    print(r.stdout[-300:], r.stderr[-300:])
    if r.returncode:
        sys.exit('ISCC başarısız')
    exe = os.path.join(outdir, name + '.exe')
    print('EXE:', exe, f'{os.path.getsize(exe):,}', 'bayt')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--test')
    ap.add_argument('--max-block', type=int, default=0)
    ap.add_argument('--force', action='store_true')
    ap.add_argument('--exe', nargs='?', const='v1.1.0')
    a = ap.parse_args()
    if a.test:
        build(os.path.join(ROOT, 'work', 'tests', a.test), a.max_block, a.force, a.test)
    elif a.exe:
        build_delta(a.exe)
    else:
        ap.error('--exe ya da --test verin')
