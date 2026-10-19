"""
tr.jsonl çalışma aracı.
  tr_tool.py stats
  tr_tool.py export --cat ui [--status todo] [--limit 300] [--blocks 276,279] [--out work/batch.json]
  tr_tool.py apply work/batch_tr.json [--status done]
      batch_tr.json: {"<n>": "çeviri", ...}  veya  [{"n":..,"tr":..,"status":..}]
  tr_tool.py set-cat translations/block_map.json   (cat alanını block_map'ten yeniden hesapla)
"""
import argparse
import json
import os
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from init_translations import load_jsonl, save_jsonl, OUT, ROOT


def cmd_stats(rows):
    by = Counter()
    for r in rows:
        by[(r['cat'], r['status'])] += 1
    cats = sorted({c for c, _ in by})
    print(f'{"cat":8} {"todo":>7} {"done":>7} {"review":>7} {"keep":>6} {"toplam":>7}')
    for c in cats:
        t = [by[(c, s)] for s in ('todo', 'done', 'review', 'keep')]
        print(f'{c:8} {t[0]:7} {t[1]:7} {t[2]:7} {t[3]:6} {sum(t):7}')
    print('TOPLAM', len(rows), '| kayıt (ID) bazında çevrilen:',
          sum(len(r['ids']) for r in rows if r['status'] in ('done', 'review', 'keep')),
          '/', sum(len(r['ids']) for r in rows))


def cmd_export(rows, a):
    blocks = {int(x) for x in a.blocks.split(',')} if a.blocks else None
    sel = [r for r in rows if (not a.cat or r['cat'] == a.cat) and (not a.status or r['status'] == a.status)
           and (blocks is None or blocks & set(r['blocks']))]
    sel = sel[:a.limit] if a.limit else sel
    out = [{'n': r['n'], 'src': r['src'], 'tags': r['tags'], 'blocks': r['blocks'], 'copies': len(r['ids'])} for r in sel]
    path = a.out or os.path.join(ROOT, 'work', 'batch.json')
    json.dump(out, open(path, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(f'{len(out)} metin -> {path}')


def cmd_apply(rows, a):
    by_n = {r['n']: r for r in rows}
    if a.file.endswith('.txt'):          # satır: n|çeviri  ('=' -> kaynak aynen kalsın = keep; '⏎' -> satır sonu)
        items = []
        for line in open(a.file, encoding='utf-8'):
            line = line.rstrip('\r\n')
            if not line.strip():
                continue
            k, v = line.split('|', 1)
            n = int(k)
            if v == '=':
                items.append({'n': n, 'tr': by_n[n]['src'], 'status': 'keep'})
            else:
                items.append({'n': n, 'tr': v.replace('⏎', '\n')})
    else:
        data = json.load(open(a.file, encoding='utf-8'))
        items = [{'n': int(k), 'tr': v} for k, v in data.items()] if isinstance(data, dict) else data
    cnt = 0
    for it in items:
        r = by_n[int(it['n'])]
        r['tr'] = it['tr']
        r['status'] = it.get('status', a.status)
        if r['tr'] == r['src'] and r['status'] == 'done':
            r['status'] = 'keep'
        cnt += 1
    save_jsonl(OUT, rows)
    print(f'{cnt} çeviri yazıldı ({a.status}).')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('cmd', choices=['stats', 'export', 'apply'])
    ap.add_argument('file', nargs='?')
    ap.add_argument('--cat')
    ap.add_argument('--status')
    ap.add_argument('--limit', type=int, default=0)
    ap.add_argument('--blocks')
    ap.add_argument('--out')
    a = ap.parse_args()
    rows = load_jsonl(OUT)
    if a.cmd == 'stats':
        cmd_stats(rows)
    elif a.cmd == 'export':
        cmd_export(rows, a)
    else:
        a.status = a.status or 'done'
        cmd_apply(rows, a)
