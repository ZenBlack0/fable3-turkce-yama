"""Paylaşılan çeviriyi (tr_public.jsonl) KENDİ oyun dosyanızdaki İngilizce metinle birleştirip yerel
translations/tr.jsonl üretir (qa.py, review araçları ve geliştirme için). Bu dosya oyun metni içerir; depoya EKLEMEYİN.
  1) Orijinal book.babel dosyanızı backup/book.babel.orig olarak kopyalayın (ya da F3_ORIG_BABEL ortam değişkeni)
  2) python tools/import_public.py
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import init_translations as it
from init_translations import ROOT, OUT, load_jsonl, save_jsonl

PUBLIC = os.path.join(ROOT, 'translations', 'tr_public.jsonl')
src = os.environ.get('F3_ORIG_BABEL') or os.path.join(ROOT, 'backup', 'book.babel.orig')
if not os.path.exists(src):
    sys.exit('Orijinal book.babel bulunamadı: ' + src)
if os.path.exists(OUT):
    sys.exit(OUT + ' zaten var; üzerine yazmamak için durdu (silip yeniden çalıştırın).')

# 1) kendi book.babel'ınızdan İngilizce kaynaklı boş çalışma dosyası (status=todo)
it.main()
rows = load_jsonl(OUT)
# 2) çevirileri kayıt ID'sine göre işle
pub = {}
for r in load_jsonl(PUBLIC):
    pub[r['ids'][0]] = r
miss = 0
for r in rows:
    p = pub.get(r['ids'][0])
    if not p:
        miss += 1
        continue
    r['status'] = p['status']
    r['tr'] = p.get('tr', r['src'] if p['status'] == 'keep' else '')
# 3) aynı İngilizce metne sahip kayıtlar için BAĞLAMA göre farklı çeviri varsa (örn. 'Vault': eylem / kasa) satırı böl
from babel import Babel
pub_all = {}
for r in load_jsonl(PUBLIC):
    for i in r['ids']:
        pub_all[i] = r
bab = Babel(src)
tag_of = {f'0x{e[0]:08X}': bab.tag_index[e[1]] for e in bab.entries}
nmax = max(r['n'] for r in rows)
extra = []
for r in rows:
    groups = {}
    for i in r['ids']:
        p = pub_all.get(i)
        key = (p['status'], p.get('tr')) if p else None
        groups.setdefault(key, []).append(i)
    if len(groups) <= 1:
        continue
    first = True
    for key, ids in groups.items():
        blocks = sorted({tag_of[i] for i in ids})
        if first:
            r['ids'], r['blocks'] = ids, blocks
            if key:
                r['status'], r['tr'] = key[0], (key[1] if key[1] is not None else r['src'])
            first = False
        else:
            nmax += 1
            n2 = dict(r)
            n2.update({'n': nmax, 'ids': ids, 'blocks': blocks})
            if key:
                n2['status'], n2['tr'] = key[0], (key[1] if key[1] is not None else r['src'])
            extra.append(n2)
rows += extra
# 4) DLC satırları: kendi DLC İngilizce kitaplarınızdan (backup\dlc_<ad>_en.babel.orig) üretilir, çeviriler kayıt ID'sine göre işlenir
import init_dlc
nn = max(r['n'] for r in rows) + 1
for key in init_dlc.DLC_KEYS:
    p = os.path.join(ROOT, 'backup', f'dlc_{key}_en.babel.orig')
    if not os.path.exists(p):
        print(f'DLC {key}: İngilizce DLC kitabı yok ({p}); DLC satırları atlandı.')
        continue
    add = init_dlc.make_rows(key, p, rows, nn)
    for r in add:
        pr = pub_all.get(r['ids'][0])
        if pr:
            r['status'] = pr['status']
            r['tr'] = pr.get('tr', r['src'] if pr['status'] == 'keep' else '')
            r['cat'] = pr.get('cat', r['cat'])
            r['note'] = ''
    nn += len(add)
    rows += add
    print(f'DLC {key}: {len(add)} satır eklendi')
if extra:
    print(f'{len(extra)} satır bağlama göre bölündü (aynı İngilizce, farklı çeviri)')
save_jsonl(OUT, rows)
done = sum(1 for r in rows if r['status'] in ('done', 'review'))
print(f'{len(rows)} satır, çevrilmiş {done}, eşleşmeyen {miss} -> {OUT}')
if miss:
    print('UYARI: oyun sürümünüz çeviri dosyasının hazırlandığı sürümden farklı olabilir.')
