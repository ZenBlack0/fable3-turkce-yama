"""
Kalite kontrol. Kullanım: python tools/qa.py [--cat ui] [--report work/qa_report.txt]
HATA (build'i durdurur): kod/etiket eksik-fazla, fontta olmayan karakter, null karakter.
UYARI: arayüz uzunluk aşımı, sözlük tutarsızlığı, İngilizce kalıntı, büyük harf kuralı, kaynakla aynı çeviri.
"""
import argparse
import contextlib
import csv
import io
import os
import re
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from init_translations import load_jsonl, OUT, ROOT
from trtext import missing_tokens, tr_lower, tr_upper, is_all_caps, font_charset

ENGLISH_STOP = set('the and you your with for that this have are not will from what was were they them their '
                   'but can has had his her him she its out who how when where which would could should '
                   'there here into about than then been being just only'.split())
OK_CTRL = {'\n', '\xa0'}


def font_path():
    p = os.path.join(ROOT, 'work', '_qa_font.bft')
    if not os.path.exists(p):
        os.makedirs(os.path.dirname(p), exist_ok=True)
        from font_patch import patch_font
        with contextlib.redirect_stdout(io.StringIO()):
            patch_font(os.environ.get('F3_ORIG_FONT') or os.path.join(ROOT, 'backup', 'gui_normal.bft.orig'), p, 'full_patch')
    return p


def load_glossary():
    g = []
    with open(os.path.join(ROOT, 'glossary.csv'), encoding='utf-8-sig', newline='') as f:
        lines = [l for l in f if not l.startswith('#')]
        for r in csv.DictReader(lines):
            if r['durum'].strip() in ('Onaylandı', 'Korunmalı') and r['orijinal_terim'].strip():
                g.append((r['orijinal_terim'].strip(), r['turkce_karsilik'].strip()))
    return g


def load_quest_names():
    path = os.path.join(ROOT, 'translations', 'quest_names.csv')
    out = []
    if os.path.exists(path):
        with open(path, encoding='utf-8-sig', newline='') as f:
            for r in csv.DictReader(f):
                if r.get('en') and r.get('tr'):
                    out.append((r['en'].strip(), r['tr'].strip()))
    return out


def ui_limit(n):
    return max(round(n * 1.3), n + 2)


CALQUE = [
    (r"\bI bet\b", r"bahse girerim", 'I bet'),
    (r"how does it feel", r"hissettiriyor", 'how does it feel'),
    (r"\bI must (say|admit)\b", r"söylemeliyim|itiraf etmeliyim", 'I must say'),
    (r"do you mind", r"sakıncası|sakınca", 'do you mind'),
    (r"\b(quite|rather)\b", r"(?i)\b(oldukça|epey)\b", 'quite/rather'),
    (r"^Why, ", r"^Neden, ", 'Why, (cümle başı)'),
    (r"\bI(?:'d| would) rather\b", r"tercih ederim|yeğlerim", "I'd rather"),
    (r"\b[Yy]awn\b", r"\b[Ee]sne", 'Yawn'),
]


def run(rows, cats=None):
    charset = font_charset(font_path())
    gloss_re = [(re.compile(r'\b' + re.escape(o) + r'\b', re.I), o, t, tr_lower(t)[:max(3, len(t) - 2)])
                for o, t in load_glossary()]
    qnames = [(re.compile(re.escape(e)), e, t, tr_lower(t)[:max(4, len(t) - 2)]) for e, t in load_quest_names() if len(e) > 3]
    err, warn = [], []
    stats = Counter()
    for r in rows:
        if cats and r['cat'] not in cats:
            continue
        st = r['status']
        stats[st] += 1
        if st not in ('done', 'review', 'keep'):
            continue
        src, tr = r['src'], r['tr']
        loc = f"n={r['n']} {r['ids'][0]} b{r['blocks'][0]} [{r['cat']}]"
        if src.strip() and not tr.strip():
            err.append(f'{loc} çeviri boş')
            continue
        if re.search(r'\byou see\b', src, re.I) and re.search(r'görüyorsun', tr):
            warn.append(f'{loc} "you see" kalıbı: {tr[:60]!r}')
        if re.search(r"my (king|queen)\b|your majesty", src, re.I) and re.search(r"\b(sen|senin|sana|seni|sende)\b|(?<![a-zçğıöşü])\w+(sin|sın|sun|sün)\b[ ,.!?]", tr) and not re.search(r'(?<=\w)(siniz|sınız|sunuz|sünüz)', tr):
            warn.append(f'{loc} Majesteleri hitabı "siz" olmalı: {tr[:60]!r}')
        for srx, trx, tag in CALQUE:
            if re.search(srx, src, re.I) and re.search(trx, tr, re.I):
                warn.append(f'{loc} calque ({tag}): {tr[:60]!r}')
        miss, extra = missing_tokens(src, tr)
        if miss:
            err.append(f'{loc} kod eksik {dict(miss)} | {tr[:50]!r}')
        if extra:
            err.append(f'{loc} kod fazla {dict(extra)} | {tr[:50]!r}')
        bad = sorted({c for c in tr if ord(c) not in charset and c not in OK_CTRL})
        if bad:
            err.append(f'{loc} fontta yok: {bad} | {tr[:50]!r}')
        if '\x00' in tr:
            err.append(f'{loc} null karakter')
        if r['cat'] == 'ui' and len(src) <= 30 and len(tr) > ui_limit(len(src)):
            warn.append(f'{loc} uzun ({len(tr)}>{ui_limit(len(src))}): {src!r} -> {tr!r}')
        if tr == src and st != 'keep' and any(c.isalpha() for c in src):
            warn.append(f'{loc} kaynakla aynı: {src[:50]!r}')
        if is_all_caps(src) and tr != tr_upper(tr):
            warn.append(f'{loc} kaynak BÜYÜK HARF, çeviri değil: {tr[:50]!r}')
        for rx, o, t, stem in gloss_re:
            if (' ' in o or len(src.split()) <= 3) and rx.search(src) and stem not in tr_lower(tr):
                warn.append(f'{loc} sözlük: "{o}" -> "{t}" bekleniyordu | {tr[:60]!r}')
        for rx, e, t, stem in qnames:
            if rx.search(src) and src != e and stem not in tr_lower(tr):
                warn.append(f'{loc} görev adı: "{e}" -> "{t}" bekleniyordu | {tr[:60]!r}')
        words = re.findall(r"[A-Za-z']{3,}", re.sub(r'<[^>]+>|%\w+', ' ', tr))
        hits = {w.lower() for w in words if w.lower() in ENGLISH_STOP}
        if len(hits) >= 2:
            warn.append(f'{loc} İngilizce kalıntı {sorted(hits)}: {tr[:60]!r}')
    dup = {}
    for r in rows:
        if r['status'] not in ('done', 'review') or not r['tr'] or (cats and r['cat'] not in cats):
            continue
        if r['cat'] in ('ui', 'items', 'names'):
            continue
        for b in r['blocks'][:1]:
            dup.setdefault((b, r['tr']), []).append(r['n'])
    for (b, tr), ns in sorted(dup.items()):
        if len(ns) >= 3:
            warn.append(f'blok {b}: {len(ns)} farklı İngilizce metin aynı çeviriye sahip {tr[:40]!r} n={ns[:6]}')
    return err, warn, stats


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--cat', action='append')
    ap.add_argument('--report', default=os.path.join(ROOT, 'work', 'qa_report.txt'))
    a = ap.parse_args()
    rows = load_jsonl(OUT)
    err, warn, stats = run(rows, a.cat)
    total = sum(stats.values())
    lines = [f'Metin: {total} | todo {stats["todo"]} | done {stats["done"]} | review {stats["review"]} | keep {stats["keep"]}',
             f'HATA: {len(err)} | UYARI: {len(warn)}', '', '--- HATALAR ---'] + err + ['', '--- UYARILAR ---'] + warn
    os.makedirs(os.path.dirname(a.report), exist_ok=True)
    open(a.report, 'w', encoding='utf-8').write('\n'.join(lines))
    print('\n'.join(lines[:2]))
    for l in err[:15]:
        print('  HATA', l)
    for l in warn[:15]:
        print('  UYARI', l)
    print('Tam rapor:', a.report)
    sys.exit(1 if err else 0)
