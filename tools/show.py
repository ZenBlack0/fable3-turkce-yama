"""
Çeviri partisini blok SIRASIYLA göster (sahne bağlamı için).
  show.py --from 293 --to 300 [--status todo] [--context 8] [--cat quest]
Her benzersiz metin ilk geçtiği (blok, ofset) konumunda gösterilir; yalnızca ilk geçişi aralıktaysa listelenir.
`--context N`: aralıktan önceki bloğun son N metnini '#' ile (varsa çevirisiyle) gösterir.
Çıktı satırı: n|metin   (satır sonu '⏎'),  blok başlıkları: '## blok B (kayıt sayısı)'
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from babel import Babel, split_nulls
from init_translations import load_jsonl, OUT, ROOT

ap = argparse.ArgumentParser()
ap.add_argument('--from', dest='a', type=int, default=0)
ap.add_argument('--to', dest='b', type=int, default=394)
ap.add_argument('--status', default='todo')
ap.add_argument('--cat')
ap.add_argument('--context', type=int, default=0)
args = ap.parse_args()

rows = {r['src']: r for r in load_jsonl(OUT)}
babel = Babel(os.path.join(ROOT, 'backup', 'book.babel.orig'))
per_block = {}
for e in babel.entries:
    per_block.setdefault(babel.tag_index[e[1]], []).append((e[2], split_nulls(babel.raw_text(e))[0]))
first_seen = set()
order = []                              # (blok, ofset, metin) ilk geçişler, dosya sırasıyla
for blk in range(len(babel.blocks)):
    for off, txt in sorted(per_block.get(blk, [])):
        if txt in first_seen:
            continue
        first_seen.add(txt)
        order.append((blk, off, txt))


def fmt(t):
    return t.replace('\n', '⏎')


if args.context:
    prev = [(b, t) for b, o, t in order if b < args.a][-args.context:]
    for b, t in prev:
        r = rows[t]
        tr = f" => {fmt(r['tr'])}" if r['tr'] else ''
        print(f"# (b{b}) {fmt(t)}{tr}")
cur = None
cnt = 0
for blk, off, txt in order:
    if blk < args.a or blk > args.b:
        continue
    r = rows[txt]
    if r['status'] != args.status or (args.cat and r['cat'] != args.cat):
        continue
    if blk != cur:
        cur = blk
        print(f"## blok {blk}")
    print(f"{r['n']}|{fmt(txt)}")
    cnt += 1
print(f'{cnt} metin', file=sys.stderr)
