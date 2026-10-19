"""
translations/tr.jsonl oluşturur / günceller (kaldığı yerden devam eder).
Her satır = bir BENZERSİZ kaynak metin:
  {"n", "src", "ids":[...], "blocks":[...], "tags":[...], "cat", "tr", "status", "note"}
status: todo | done | review | keep   (keep = bilerek çevrilmedi, kaynak olduğu gibi)
Yeniden çalıştırınca mevcut tr/status/note korunur; yalnızca yeni metinler eklenir, ids/blocks/cat yenilenir.
cat: translations/block_map.json  {"ui":[275,276,...], "quest":[...], ...} (dosya blok numaralarıdır)
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from babel import Babel, split_nulls
from trtext import protected_tokens

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'translations', 'tr.jsonl')
MAP = os.path.join(ROOT, 'translations', 'block_map.json')
PLACEHOLDER = re.compile(r'^TEXT_[A-Z0-9_]+$')
NAME_RX = re.compile(r"^[A-ZÉ][a-zA-ZéöüÉáíóúñ'\.\-]+( [A-ZÉ][a-zA-ZéöüÉáíóúñ'\.\-]+){0,3}( +\([\w ,]+\))?\s*$")
CREDIT_RX = re.compile(
    r"^<s4|\bby\b|^Lead:|Recorded|Copyright|©|trademark|Studio|^Uses |Orchestra|Autodesk|Xbox, |Microsoft|"
    r"Concertmaster|Accordion|Mixed at|Producer|Foley| - [A-Z][\w' ]+$|"
    r"\((Volt|Atlantic|Testology|Filter|Aquent|Soundelux|Brook Street)")
UI_RX = re.compile(
    r"storage device|gamer profile|downloadable content|Direct3D|title screen|Home screen|Recheck|\bdoor\b|"
    r"Gold Keys|<gold_key|<gnome|save game|'s World|Unlocked:|How much gold|Continue without|divorc|"
    r"marriage between|Certificate of|^Reason:|cheating|Irreconcilable|No longer finds|Bored with you|"
    r"Don't like you|Would rather work|Haven't seen you|Not making enough|Sale of Joint|Wash off|"
    r"Press <interact|Do you want to set your property|Children that will be sent|Your downloaded content|"
    r"Want to earn it|Max and Sam|Apply dye")
EPITAPH_RX = re.compile(r"^(Here (lies|lyes|sleeps) )?[A-Z][\w\.\-' ]{2,38}\. ")


def reclass_names(src):
    """'names' bloklarına (kredi + karışık içerik) düşen metni içeriğine göre sınıflandır."""
    if NAME_RX.match(src) or CREDIT_RX.search(src):
        return 'names'
    if UI_RX.search(src):
        return 'ui'
    if EPITAPH_RX.match(src) and len(src.split('.')[0].split()) <= 4:
        return 'epitaph'
    return 'dialog'



def load_jsonl(path):
    rows = []
    if os.path.exists(path):
        with open(path, encoding='utf-8') as f:
            rows = [json.loads(l) for l in f if l.strip()]
    return rows


def save_jsonl(path, rows):
    tmp = path + '.tmp'
    with open(tmp, 'w', encoding='utf-8', newline='\n') as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + '\n')
    os.replace(tmp, path)


def main():
    babel = Babel(os.environ.get('F3_ORIG_BABEL') or os.path.join(ROOT, 'backup', 'book.babel.orig'))
    cat_of, prio, off_rules = {}, [], []
    if os.path.exists(MAP):
        bm = json.load(open(MAP, encoding='utf-8'))
        prio = bm.pop('_priority', [])
        off_rules = bm.pop('offset_rules', [])
        for cat, blocks in bm.items():
            for b in blocks:
                cat_of[b] = cat

    def entry_cat(blk, off):
        for r in off_rules:
            if r['block'] == blk and off < r.get('offset_lt', 1 << 30):
                return r['cat']
        return cat_of.get(blk, '?')

    uniq = {}
    for e in babel.entries:
        core, _ = split_nulls(babel.raw_text(e))
        blk = babel.tag_index[e[1]]
        u = uniq.setdefault(core, {'ids': [], 'blocks': set(), 'cats': set()})
        u['ids'].append(f'0x{e[0]:08X}')
        u['blocks'].add(blk)
        u['cats'].add(entry_cat(blk, e[2]))
    old = {r['src']: r for r in load_jsonl(OUT)}
    rows, n = [], 0
    for src, u in uniq.items():       # sözlük ekleme sırası = ilk görülme sırası (kararlı)
        o = old.get(src, {})
        cats = u['cats'] - {'?'}
        cat = next((c for c in prio if c in cats), '?') if cats else '?'
        if cat == 'names':
            cat = reclass_names(src)
        if cat == 'ui' and len(src) > 500:      # arayüz bloklarına karışmış uzun kitap metinleri
            cat = 'book'
        status = o.get('status', 'todo')
        tr = o.get('tr', '')
        if status == 'todo' and PLACEHOLDER.match(src):       # TEXT_AI_... yer tutucular: çevrilmez
            status, tr = 'keep', src
        rows.append({'n': n, 'src': src, 'ids': u['ids'], 'blocks': sorted(u['blocks']),
                     'tags': sorted(protected_tokens(src)), 'cat': cat,
                     'tr': tr, 'status': status, 'note': o.get('note', '')})
        n += 1
    save_jsonl(OUT, rows)
    done = sum(1 for r in rows if r['status'] in ('done', 'review', 'keep'))
    print(f'{len(rows)} benzersiz metin yazıldı -> {OUT} (çevrilmiş/işaretli: {done})')


if __name__ == '__main__':
    main()
