"""Paylaşılabilir çeviri dosyası üretir (BAKIMCI aracı; yerel tr.jsonl gerekir).
  python tools/export_public.py [cikis.jsonl]
Her satır: {"n", "ids":[kayıt ID'leri], "cat", "status", "tr"}  -- İNGİLİZCE KAYNAK METİN YOKTUR.
  status=done/review -> "tr" Türkçe çeviri
  status=keep        -> "tr" yok (oyundaki metin değiştirilmez; İngilizce yer tutucu/özel ad/kredi satırı)
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from init_translations import load_jsonl, OUT, ROOT

dst = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'translations', 'tr_public.jsonl')
rows = sorted(load_jsonl(OUT), key=lambda r: r['n'])   # sıralı çıktı: aynı çeviri her zaman aynı bayt dizisini üretir
n_tr = n_keep = 0
with open(dst, 'w', encoding='utf-8', newline='\n') as f:
    for r in rows:
        o = {'n': r['n'], 'ids': r['ids'], 'cat': r['cat'], 'status': r['status']}
        if r.get('dlc'):
            o['dlc'] = r['dlc']
        if r['status'] in ('done', 'review') and r['tr']:
            o['tr'] = r['tr']
            n_tr += 1
        else:
            n_keep += 1
        f.write(json.dumps(o, ensure_ascii=False) + '\n')
print(f'{len(rows)} satır -> {dst} (çeviri {n_tr}, değişmeyen {n_keep})')
