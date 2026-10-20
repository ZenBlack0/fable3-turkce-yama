r"""Yayın taraması: oyuncu paketi (exe + zip) ve depo klasörü. Hata varsa çıkış kodu 1.
  python tools/scan_release.py [--exe X] [--zip X] [--repo DIR] [--pack-dir DIR]
Denetimler:
  1) Oyun dosyası uzantıları (.babel .bft .orig ...) ve zip/depoda beklenmeyen dosya
  2) Orijinal (ve yamalı çıktı) dosya hash'leri: taranan hiçbir dosyanın SHA-256'sı bunlardan biri olamaz
  3) İngilizce kaynak satırlar (>=25 karakter): depo metin dosyalarında ve çeviri paketinde TAM tarama;
     exe/zip/ikili dosyalarda yalnızca örneklem (iç veriler sıkıştırıldığı için asıl denetim kurucuya GİREN dosyalardadır)
  4) Orijinal dosyalardan 32 baytlık pencereler: çeviri paketinde ve font farkında bulunamaz
  5) Beklenmeyen büyük/ikili dosyalar
tr.jsonl (İngilizce kaynak) yoksa 3. ve 4. denetim ATLANIR ve bu raporda AÇIKÇA yazılır (UYARI olarak).
"""
import argparse
import hashlib
import json
import lzma
import os
import re
import subprocess
import sys
import tempfile
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from init_translations import OUT, ROOT

MAN = json.load(open(os.path.join(ROOT, 'manifest.json'), encoding='utf-8'))
VER = MAN['version']
NAME = f'Fable3_Turkce_Yama_v{VER}'
DELTA = os.path.join(ROOT, 'tools', 'installer', 'delta')
BAD_EXT = {'.babel', '.bft', '.orig', '.tex', '.bix', '.nfs', '.fbrb', '.sub', '.hal', '.cat', '.vdf', '.big'}
ZIP_OK = {NAME + '.exe', 'OKUBENI.txt', 'SHA256SUMS.txt'}
REPO_TEXT_EXT = {'.tpl', '.bat', '.py', '.md', '.txt', '.csv', '.jsonl', '.json', '.iss', '.inc', '.bat', '.yml', '.yaml', '.toml', '.cfg', '.gitignore', '', '.ps1'}
REPO_BIG_OK = {'translations/tr_public.jsonl'}
DELTA_OK_TOP = {'book_pack.lzma', 'font.xdelta', 'xdelta3.exe', 'xdelta3_COPYING.txt', 'pyinstaller_COPYING.txt',
                'python_LICENSE.txt', 'nuitka_LICENSE.txt', 'NOTICE.txt', 'f3patch', 'placeholder'}
MAX_BIN = 64 << 20

res = {'err': [], 'warn': [], 'info': []}


def err(m):
    res['err'].append(m)


def warn(m):
    res['warn'].append(m)


def info(m):
    res['info'].append(m)


def sha_bytes(b):
    return hashlib.sha256(b).hexdigest()


def sha_file(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for c in iter(lambda: f.read(1 << 20), b''):
            h.update(c)
    return h.hexdigest()


def forbidden_hashes():
    s = set(MAN['outputs'].values())
    for d in MAN.get('dlc', {}).values():
        s |= {d['src_sha'], d['out_sha']}
    for sup in MAN['supported']:
        s |= set(sup['files'].values())
    return s


def is_binary(b):
    return b'\x00' in b[:8192]


def load_src():
    if not os.path.exists(OUT):
        return None
    out = set()
    for l in open(OUT, encoding='utf-8'):
        if l.strip():
            s = json.loads(l)['src'].strip()
            if len(s) >= 25:
                out.add(s)
    return sorted(out)


def shingle_scan(text, srcs):
    low = text.lower()
    words = re.findall(r"[a-z0-9']+", low)
    sh = {' '.join(words[i:i + 4]) for i in range(len(words) - 3)}
    found = []
    for s in srcs:
        ws = re.findall(r"[a-z0-9']+", s.lower())
        if len(ws) < 4:
            if s.lower() in low:
                found.append(s)
        elif ' '.join(ws[:4]) in sh and s.lower() in low:
            found.append(s)
    return found


def direct_scan(blob, srcs):
    n = 0
    for s in srcs:
        a = s.encode('ascii', 'ignore')
        if s.encode('utf-16-be') in blob or (len(a) == len(s) and a in blob):
            n += 1
    return n


def windows(path, W=32):
    d = open(path, 'rb').read()
    ws = {d[i:i + W] for i in range(0, len(d) - W, 16)}
    return {w for w in ws if len(set(w)) > 4}


def window_hits(blob, ws, W=32):
    return sum(1 for i in range(len(blob) - W + 1) if blob[i:i + W] in ws)


def orig_paths():
    out = []
    for rel in MAN['supported'][0]['files']:
        n = os.path.basename(rel)
        env = os.environ.get('F3_ORIG_BABEL' if n.endswith('.babel') else 'F3_ORIG_FONT')
        out.append(env or os.path.join(ROOT, 'backup', n + '.orig'))
    for key in MAN.get('dlc', {}):
        out.append(os.environ.get('F3_DLC_' + key.upper()) or os.path.join(ROOT, 'backup', f'dlc_{key}_en.babel.orig'))
    return out


def check_hashes(label, files, bad):
    for p in files:
        try:
            h = sha_file(p)
        except OSError:
            continue
        if h in bad:
            err(f'{label}: orijinal/yamalı oyun dosyası hash\'i eşleşti: {p}')


def scan_repo(repo, srcs, bad):
    files = []
    for d, ds, fs in os.walk(repo):
        ds[:] = [x for x in ds if x != '.git']
        for f in fs:
            files.append(os.path.join(d, f))

    def rel(p):
        return os.path.relpath(p, repo).replace('\\', '/')
    info(f'Depo: {repo} ({len(files)} dosya)')
    texts = {}
    for p in files:
        r = rel(p)
        ext = os.path.splitext(p)[1].lower()
        if ext in BAD_EXT or p.endswith('.orig'):
            err(f'depo: oyun dosyası uzantısı: {r}')
        if ext not in REPO_TEXT_EXT and os.path.basename(p) != 'LICENSE' and not r.startswith('.github/'):
            err(f'depo: beklenmeyen dosya türü: {r}')
        size = os.path.getsize(p)
        b = open(p, 'rb').read()
        if is_binary(b):
            err(f'depo: ikili dosya: {r}')
        elif size > (1 << 20) and r not in REPO_BIG_OK:
            err(f'depo: beklenmeyen büyük dosya ({size:,} bayt): {r}')
        else:
            texts[r] = b.decode('utf-8', 'replace')
    check_hashes('depo', files, bad)
    if srcs is not None:
        allt = '\n'.join(texts.values())
        found = shingle_scan(allt, srcs)
        info(f'depo: {len(srcs):,} İngilizce kaynak satır (>=25 karakter) TAM tarandı: {len(found)} eşleşme')
        for s in found[:20]:
            err(f'depo: İngilizce oyun metni: "{s[:70]}"')
        pub = os.path.join(repo, 'translations', 'tr_public.jsonl')
        if os.path.exists(pub):
            n = sum(1 for l in open(pub, encoding='utf-8') if 'src' in json.loads(l))
            if n:
                err(f'depo: tr_public.jsonl içinde {n} satırda "src" alanı var')
    else:
        warn('depo: tr.jsonl yok, İngilizce kaynak taraması ATLANDI')


def scan_pack_dir(d, srcs, bad):
    if not os.path.isdir(d):
        warn(f'kurucuya giren klasör yok, atlandı: {d}')
        return
    top = set(os.listdir(d))
    for x in sorted(top - DELTA_OK_TOP):
        err(f'kurucu girdisi: beklenmeyen dosya: {x}')
    allf = [os.path.join(dd, f) for dd, _, fs in os.walk(d) for f in fs]
    for p in allf:
        if os.path.splitext(p)[1].lower() in BAD_EXT:
            err(f'kurucu girdisi: oyun dosyası uzantısı: {p}')
        if os.path.getsize(p) > MAX_BIN:
            err(f'kurucu girdisi: beklenmeyen çok büyük dosya: {p}')
    check_hashes('kurucu girdisi', allf, bad)
    # yer tutucu paketler: yalnızca bilinen dosya adları; arşivler küçük olmalı (kitap/metin İÇERMEZ)
    for p in allf:
        if os.sep + 'placeholder' + os.sep in p and p.lower().endswith('.dat') and os.path.getsize(p) > 5000:
            err(f'kurucu girdisi: yer tutucu arşivi beklenenden büyük (kitap içeriyor olabilir): {p}')
    info(f'Kurucuya giren klasör: {len(allf)} dosya, {sum(os.path.getsize(p) for p in allf):,} bayt')
    pk = os.path.join(d, 'book_pack.lzma')
    fx = os.path.join(d, 'font.xdelta')
    if not (os.path.exists(pk) and os.path.exists(fx)):
        err('kurucu girdisi: book_pack.lzma veya font.xdelta eksik')
        return
    raw = lzma.decompress(open(pk, 'rb').read())
    pack = json.loads(raw.decode('utf-8'))
    ids = {i for x, _ in pack['tr'] for i in x}
    info(f'çeviri paketi: {len(pack["tr"]):,} satır, {len(ids):,} kayıt ID; anahtarlar: {sorted(pack)}')
    if set(pack) - {'fmt', 'tr', 'dialog', 'dlc'}:
        err(f'çeviri paketinde beklenmeyen alan: {sorted(set(pack) - {"fmt", "tr", "dialog", "dlc"})}')
    fxb = open(fx, 'rb').read()
    xd = os.path.join(ROOT, 'tools', 'installer', 'xdelta3', 'xdelta3.exe')
    if os.path.exists(xd):
        o = os.path.join(tempfile.mkdtemp(), 'o.bin')
        r = subprocess.run([xd, '-A=', '-d', '-f', fx, o], capture_output=True, text=True, errors='replace')
        if r.returncode == 0:
            err('font.xdelta kaynak dosya olmadan çözüldü')
        else:
            info('font.xdelta kaynaksız çözülemiyor (doğru)')
    if srcs is None:
        warn('tr.jsonl yok: çeviri paketinde İngilizce satır ve pencere taraması ATLANDI (yalnızca yapısal denetimler yapıldı)')
        return
    found = shingle_scan(raw.decode('utf-8'), srcs)
    info(f'çeviri paketi: {len(srcs):,} İngilizce kaynak satır (>=25) TAM tarandı: {len(found)} eşleşme')
    for s in found[:20]:
        err(f'çeviri paketi: İngilizce oyun metni: "{s[:70]}"')
    rows = [json.loads(l) for l in open(OUT, encoding='utf-8') if l.strip()]
    keep_ids = {int(i, 16) for r in rows if r['status'] == 'keep' for i in r['ids']}
    if keep_ids & ids:
        err(f'çeviri paketinde {len(keep_ids & ids)} "keep" kaydı var')
    n = direct_scan(fxb, srcs)
    if n:
        err(f'font.xdelta içinde {n} İngilizce kaynak satır')
    tot = 0
    for p in orig_paths():
        if os.path.exists(p):
            ws = windows(p)
            tot += window_hits(raw, ws) + window_hits(fxb, ws)
    info(f'orijinal dosyalardan 32 baytlık pencere eşleşmesi (paket + font farkı): {tot}')
    if tot:
        err(f'çeviri paketi/font farkı orijinal dosyadan {tot} pencere içeriyor')


def scan_blob_sample(label, blob, srcs):
    if srcs is None:
        return
    sample = srcs[::max(1, len(srcs) // 3000)]
    n = direct_scan(blob, sample)
    info(f'{label}: ham baytlarda {len(sample):,} satırlık ÖRNEKLEM: {n} eşleşme (içerik sıkıştırılmış olduğundan zayıf denetim)')
    if n:
        err(f'{label}: ham baytlarda İngilizce oyun metni ({n} örnek)')


def scan_player(exe, zp, srcs, bad):
    if exe:
        if not os.path.exists(exe):
            err(f'exe yok: {exe}')
        else:
            sz = os.path.getsize(exe)
            info(f'exe: {exe} ({sz:,} bayt)')
            if sz > MAX_BIN:
                err('exe beklenmeyen büyüklükte')
            check_hashes('exe', [exe], bad)
            scan_blob_sample('exe', open(exe, 'rb').read(), srcs)
    if zp:
        if not os.path.exists(zp):
            err(f'zip yok: {zp}')
            return
        info(f'zip: {zp} ({os.path.getsize(zp):,} bayt)')
        with zipfile.ZipFile(zp) as z:
            names = z.namelist()
            info(f'zip içeriği: {names}')
            for n in names:
                if n not in ZIP_OK:
                    err(f'zip: beklenmeyen dosya: {n}')
                if os.path.splitext(n)[1].lower() in BAD_EXT:
                    err(f'zip: oyun dosyası uzantısı: {n}')
            for n in ZIP_OK - set(names):
                err(f'zip: eksik dosya: {n}')
            for n in names:
                b = z.read(n)
                if sha_bytes(b) in bad:
                    err(f'zip: orijinal/yamalı oyun dosyası hash\'i eşleşti: {n}')
                if n.endswith('.exe') and exe and os.path.exists(exe) and sha_bytes(b) != sha_file(exe):
                    err('zip içindeki exe, derlenen exe ile aynı değil')
                if n.endswith('.txt') and srcs is not None:
                    f = shingle_scan(b.decode('utf-8', 'replace'), srcs)
                    if f:
                        err(f'zip/{n}: İngilizce oyun metni: "{f[0][:60]}"')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--exe', default=os.path.join(ROOT, 'output', NAME + '.exe'))
    ap.add_argument('--zip', default=os.path.join(ROOT, 'output', NAME + '.zip'))
    ap.add_argument('--repo', default=os.path.join(ROOT, 'dist', 'github_repo'))
    ap.add_argument('--pack-dir', default=DELTA)
    ap.add_argument('--report', default=os.path.join(ROOT, 'output', 'scan_release.txt'))
    a = ap.parse_args()
    bad = forbidden_hashes()
    for p in orig_paths():
        if os.path.exists(p):
            bad.add(sha_file(p))
    srcs = load_src()
    if srcs is None:
        warn('translations/tr.jsonl yok: İngilizce kaynak taramaları atlanacak')
    scan_player(a.exe, a.zip, srcs, bad)
    scan_pack_dir(a.pack_dir, srcs, bad)
    if os.path.isdir(a.repo):
        scan_repo(a.repo, srcs, bad)
    else:
        warn(f'depo klasörü yok, atlandı: {a.repo}')
    lines = ['--- scan_release ---'] + res['info'] + [f'UYARI: {len(res["warn"])}'] + ['  ' + w for w in res['warn']] \
        + [f'HATA: {len(res["err"])}'] + ['  ' + e for e in res['err']] + ['SONUÇ: ' + ('GEÇTİ' if not res['err'] else 'BAŞARISIZ')]
    os.makedirs(os.path.dirname(a.report), exist_ok=True)
    open(a.report, 'w', encoding='utf-8').write('\n'.join(lines))
    print('\n'.join(lines))
    sys.exit(1 if res['err'] else 0)


if __name__ == '__main__':
    main()
