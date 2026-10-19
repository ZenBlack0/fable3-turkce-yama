r"""DLC (Understone, Traitors Keep) İngilizce kitaplarından çeviri satırları üretir (BAKIMCI aracı).
  python tools/init_dlc.py            -> translations/tr.jsonl'a "dlc" alanlı satırları EKLER (zaten varsa dokunmaz)
Kaynak: backup\dlc_<ad>_en.babel.orig (kendi oyununuzun DLC arşivinden; tools/dlc_bnk.py ile çıkarılır, depoya girmez).
Her satır: tr.jsonl biçimi + "dlc": "understone" | "traitors". Aynı DLC içinde aynı İngilizce metin tek satırda birleşir.
Ana kitapla AYNI İngilizce metne sahip satırların çevirisi doğrudan yeniden kullanılır.
Tür (cat): konuşma satırı = "dialog" (Tam altyazı bayrağı bu satırlara uygulanır); ad/arayüz/öğe = "items"/"ui".
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from babel import Babel, split_nulls
from init_translations import OUT, ROOT, load_jsonl, save_jsonl
from trtext import protected_tokens

DLC_KEYS = ['understone', 'traitors']
UI_PAT = re.compile(r'%\d|%[sd]|<[^>]+>|^\+ ?\d|^[-+]\s?\d+%?|: ?%')
PROMPT = re.compile(r'^(Search|Give|Track|Untie|Hand|Take|Find|Collect|Kill|Dig|Deliver|Return|Bring|Get|Use|Talk|Speak|Open|Free|Rescue|Defeat|Escape|Reach)\b')


def classify(src):
    s = src.strip()
    if UI_PAT.search(s):
        return 'ui'
    if len(s) <= 40 and not re.search(r'[.!?…]$', s) and re.match(r"^[A-Z0-9]", s) and len(s.split()) <= 6:
        return 'items'
    if PROMPT.match(s) and len(s) < 80 and (s.endswith('?') or s.endswith('.')):
        return 'quest'
    return 'dialog'


def make_rows(key, path, main_rows, nstart):
    """-> satırlar listesi (status todo, aynı İngilizce ana kitapta varsa çeviri taşınır)"""
    b = Babel(path)
    uniq = {}
    for e in b.entries:
        core, _ = split_nulls(b.raw_text(e))
        u = uniq.setdefault(core, {'ids': [], 'blocks': set()})
        u['ids'].append(f'0x{e[0]:08X}')
        u['blocks'].add(b.tag_index[e[1]])
    by_src = {r['src']: r for r in main_rows if not r.get('dlc') and r['status'] in ('done', 'review') and r['tr']}
    rows = []
    n = nstart
    for src, u in uniq.items():
        m = by_src.get(src)
        r = {'n': n, 'src': src, 'ids': u['ids'], 'blocks': sorted(u['blocks']), 'tags': sorted(protected_tokens(src)),
             'cat': classify(src), 'tr': m['tr'] if m else '', 'status': 'done' if m else 'todo',
             'note': 'ana kitaptan çeviri yeniden kullanıldı' if m else '', 'dlc': key}
        if re.match(r'^TEXT_[A-Z0-9_]+$', src):
            r['status'], r['tr'] = 'keep', src
        rows.append(r)
        n += 1
    return rows


def main():
    rows = load_jsonl(OUT)
    if any(r.get('dlc') for r in rows):
        print('tr.jsonl içinde zaten DLC satırları var; dokunulmadı.')
        return
    n = max(r['n'] for r in rows) + 1
    for key in DLC_KEYS:
        p = os.path.join(ROOT, 'backup', f'dlc_{key}_en.babel.orig')
        if not os.path.exists(p):
            print('UYARI: yok:', p)
            continue
        add = make_rows(key, p, rows, n)
        n += len(add)
        rows += add
        reuse = sum(1 for r in add if r['note'])
        print(f'{key}: {len(add)} benzersiz metin ({sum(len(r["ids"]) for r in add)} kayıt), ana kitaptan yeniden kullanılan {reuse}')
    save_jsonl(OUT, rows)


if __name__ == '__main__':
    main()
