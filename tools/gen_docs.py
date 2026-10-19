r"""Belge üretici: tüm sürüm, hash ve bağlantılar manifest.json, output\manifest.built.json (paket hash'leri) ve
vt_report.json (VirusTotal) dosyalarından üretilir; elle yazılmaz.
  python tools/gen_docs.py --repo dist/github_repo     # README.md, docs/antivirus.md, docs/RELEASE_NOTES.md, LICENSE*, ISSUE_TEMPLATE
build_all.py, zip içindeki OKUBENI.txt için render_okubeni() fonksiyonunu kullanır.

vt_report.json biçimi (Aşama 6'da doldurulur):
  {"date": "2026-10-16",
   "exe": {"sha256": "...", "url": "https://www.virustotal.com/gui/file/...", "detections": 0, "total": 71, "engines": []},
   "zip": {"sha256": "...", "url": "...", "detections": 0, "total": 68, "engines": ["Motor (etiket)"]}}
Rapordaki SHA-256 değerleri yerel dosyalarla uyuşmuyorsa belge ÜRETİLMEZ (hata verir).
"""
import argparse
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'tools', 'docs_src')
MANIFEST = os.path.join(ROOT, 'manifest.json')
BUILT = os.path.join(ROOT, 'output', 'manifest.built.json')
VT = os.path.join(ROOT, 'vt_report.json')
PUBLIC = os.path.join(ROOT, 'translations', 'tr_public.jsonl')


def _load(p):
    with open(p, encoding='utf-8') as f:
        return json.load(f)


def _fmt(n):
    return f'{n:,}'.replace(',', '.')


def vt_info(pkg):
    """(rapor | None); sha256 uyuşmazlığında SystemExit."""
    if not os.path.exists(VT):
        return None
    rep = _load(VT)
    for k in ('exe', 'zip'):
        if k not in rep:
            sys.exit(f'vt_report.json: "{k}" bölümü eksik')
        if pkg and rep[k]['sha256'].lower() != pkg[k]['sha256'].lower():
            sys.exit(f'vt_report.json: {k} SHA-256 değeri yerel dosyayla uyuşmuyor ({rep[k]["sha256"]} != {pkg[k]["sha256"]}); belge üretilmedi')
    return rep


def values(need_package=True):
    man = _load(MANIFEST)
    v = {}
    repo = man['repo']
    v['VERSION'] = man['version']
    v['TAG'] = man['tag']
    v['HOLDER'] = man['copyright_holder']
    v['COMPANY'] = man['company']
    v['REPO'] = repo
    v['OWNER'] = repo.split('/')[0]
    v['REPO_URL'] = f'https://github.com/{repo}'
    v['RELEASES_URL'] = f'https://github.com/{repo}/releases/latest'
    v['ISSUES_URL'] = f'https://github.com/{repo}/issues'
    v['ANTIVIRUS_URL'] = f'https://github.com/{repo}/blob/main/docs/antivirus.md'
    v['PY_PIN'] = man['build']['python']
    if man.get('dlc_translated'):
        v['DLC_NOTE_MD'] = v['DLC_NOTE_TXT'] = ''
    else:
        v['DLC_NOTE_MD'] = ("- **Understone ve Traitor's Keep DLC metinleri bu sürümde İngilizcedir.** Bu DLC'lerin metni ana kitapta değil, "
                            "DLC arşivlerinin içindeki ayrı kitaplarda durur; yama onlara dokunmaz.\n")
        v['DLC_NOTE_TXT'] = ("- Understone ve Traitor's Keep DLC metinleri (örn. Bay Boyle'un perili fabrika görevi) bu sürümde İngilizcedir;\n"
                             "  bu metinler DLC arşivlerinin içindeki ayrı kitaplarda durur ve yama onlara dokunmaz.\n")
    name = f'Fable3_Turkce_Yama_{man["tag"]}'
    v['EXE_NAME'] = name + '.exe'
    v['ZIP_NAME'] = name + '.zip'
    out = man['outputs']
    v['OUT_BOOK'], v['OUT_FONT'] = out['book'], out['font']
    v['OUT_BOOK_SHORT'], v['OUT_FONT_SHORT'] = out['book'][:8], out['font'][:8]
    dl = man.get('dlc', {})
    rows_ = ['| DLC | Kitap SHA-256 (orijinal) | Beklenen sonuç SHA-256 |', '|---|---|---|']
    for d_ in dl.values():
        rows_.append(f'| {d_["label"]} | `{d_["src_sha"]}` | `{d_["out_sha"]}` |')
    v['DLC_TABLE_MD'] = '\n'.join(rows_)
    v['DLC_NAMES'] = ' ve '.join(d_['label'].split(' (')[0] for d_ in dl.values()) or 'DLC'
    rows = ['| Dağıtım | Dosya | SHA-256 (orijinal, yamasız) |', '|---|---|---|']
    txt = []
    for s in man['supported']:
        for rel, h in s['files'].items():
            rows.append(f'| {s["label"]} | `{rel}` | `{h}` |')
            txt.append(f'  {rel}')
            txt.append(f'      SHA-256: {h}')
    v['SUPPORTED_MD'] = '\n'.join(rows)
    v['SUPPORTED_TXT'] = '\n'.join(txt)
    v['UNVERIFIED_MD'] = ', '.join(man['unverified'])
    v['UNVERIFIED_TXT'] = ', '.join(man['unverified'])
    n_tr = n_keep = 0
    if os.path.exists(PUBLIC):
        for l in open(PUBLIC, encoding='utf-8'):
            if l.strip():
                if json.loads(l).get('tr'):
                    n_tr += 1
                else:
                    n_keep += 1
    v['N_TR'], v['N_KEEP'] = _fmt(n_tr), _fmt(n_keep)

    pkg = None
    if os.path.exists(BUILT):
        b = _load(BUILT)
        pkg = b.get('package') or None
        if pkg and (b.get('version') != man['version']):
            sys.exit('output/manifest.built.json sürümü manifest.json ile uyuşmuyor; build_all.py çalıştırın')
    if pkg:
        v['EXE_SHA'], v['ZIP_SHA'] = pkg['exe']['sha256'], pkg['zip']['sha256']
        v['EXE_SIZE'], v['ZIP_SIZE'] = _fmt(pkg['exe']['size']), _fmt(pkg['zip']['size'])
    elif need_package:
        sys.exit('paket hash\'leri yok (output/manifest.built.json): önce build_all.py çalıştırın')

    rep = vt_info(pkg) if pkg else None
    if rep:
        rows = ['| Dosya | Tespit | Uyaran motorlar | Rapor |', '|---|---|---|---|']
        sm = []
        for k, label in (('exe', v['EXE_NAME']), ('zip', v['ZIP_NAME'])):
            r = rep[k]
            eng = ', '.join(r['engines']) if r.get('engines') else '—'
            rows.append(f'| `{label}` | {r["detections"]}/{r["total"]} | {eng} | [VirusTotal]({r["url"]}) |')
            sm.append(f'`{label}`: **{r["detections"]}/{r["total"]}** ([rapor]({r["url"]}))')
        v['VT_TABLE_MD'] = '\n'.join(rows) + f'\n\nTarama tarihi: {rep["date"]}.'
        v['VT_SUMMARY_MD'] = 'VirusTotal sonuçları (' + rep['date'] + '): ' + '; '.join(sm) + '.'
        v['VT_ZIP_RESULT'] = f'**{rep["zip"]["detections"]}/{rep["zip"]["total"]}**'
        v['VT_NOTE_MD'] = ('Uyarı veren motorlar yukarıdaki tabloda adıyla listelenmiştir; tespit etiketlerinin ayrıntısı rapor bağlantılarındadır. '
                           'Tespit sayısı 0 değilse bu, dosyanın zararlı olduğunu değil, imzasız ve paketlenmiş bir program için sezgisel bir şüphe '
                           'işaretlendiğini gösterebilir; yine de karar sizindir — güvenmek istemezseniz kaynaktan derleyebilirsiniz.')
    else:
        v['VT_TABLE_MD'] = '*VirusTotal sonuçları sürüm yayınlanırken buraya eklenecektir.*'
        v['VT_SUMMARY_MD'] = 'VirusTotal sonuçları sürüm yayınlanırken eklenecektir.'
        v['VT_NOTE_MD'] = ''
        v['VT_ZIP_RESULT'] = 'temiz'
    return v


def render(text, vals):
    for k, val in vals.items():
        text = text.replace('{{' + k + '}}', val)
    if '{{' in text:
        left = sorted({t.split('}}')[0] for t in text.split('{{')[1:]})
        sys.exit(f'şablonda doldurulmamış alan: {left}')
    return text


def _read(p):
    with open(p, encoding='utf-8-sig') as f:
        return f.read().replace('\r\n', '\n')


def render_okubeni():
    return render(_read(os.path.join(SRC, 'OKUBENI.txt.tpl')), values(need_package=False))


def _write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)


def write_repo_docs(dst):
    v = values(need_package=True)
    _write(os.path.join(dst, 'README.md'), render(_read(os.path.join(SRC, 'README.md.tpl')), v))
    _write(os.path.join(dst, 'docs', 'antivirus.md'), render(_read(os.path.join(SRC, 'antivirus.md.tpl')), v))
    _write(os.path.join(dst, 'docs', 'RELEASE_NOTES.md'), render(_read(os.path.join(SRC, 'RELEASE_NOTES.md.tpl')), v))
    for n in ('LICENSE', 'LICENSE-TRANSLATION'):
        _write(os.path.join(dst, n), render(_read(os.path.join(ROOT, 'tools', 'repo_files', n)), v))
    for n in os.listdir(os.path.join(SRC, 'ISSUE_TEMPLATE')):
        _write(os.path.join(dst, '.github', 'ISSUE_TEMPLATE', n), _read(os.path.join(SRC, 'ISSUE_TEMPLATE', n)))
    if os.path.exists(VT):
        _write(os.path.join(dst, 'vt_report.json'), _read(VT))


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', default=os.path.join(ROOT, 'dist', 'github_repo'))
    a = ap.parse_args()
    write_repo_docs(a.repo)
    print('Belgeler üretildi:', a.repo)
