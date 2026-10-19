r"""Çeviri doğrulaması: tek giriş noktası. Hata varsa çıkış kodu 1 (build_all durur).
  python tools/validate_all.py [--report work/validate_report.txt]
Denetimler (qa.py): kontrol kodları (<...>, %1, \n) eksik/fazla, fontta olmayan karakter, null karakter, boş çeviri.
Ek denetimler: çevrilmemiş (todo) satır, status değerleri, paylaşılan tr_public.jsonl ile tr.jsonl eşleşmesi,
orijinal dosya hash'leri (backup\*.orig == manifest), sözlük ve yer tutucu uyarıları (qa.py UYARI'ları: hata değil).
"""
import argparse
import hashlib
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from init_translations import load_jsonl, OUT, ROOT
import qa

MANIFEST = os.path.join(ROOT, 'manifest.json')
PUBLIC = os.path.join(ROOT, 'translations', 'tr_public.jsonl')


def sha(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for c in iter(lambda: f.read(1 << 20), b''):
            h.update(c)
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--report', default=os.path.join(ROOT, 'work', 'validate_report.txt'))
    a = ap.parse_args()
    man = json.load(open(MANIFEST, encoding='utf-8'))
    errors, notes = [], []

    if not os.path.exists(OUT):
        # Genel depo kopyası: İngilizce kaynak (tr.jsonl) yok. Kod/yer tutucu/font denetimleri YAPILAMAZ; yalnızca yapı denetlenir.
        # Bu mod, bakımcının yayın hattında kabul edilmez (F3_PUBLIC=1 verilmedikçe hata).
        if os.environ.get('F3_PUBLIC') != '1':
            errors.append('translations/tr.jsonl yok (bakımcı kaynağı); tam doğrulama yapılamaz (genel kopyada F3_PUBLIC=1 verin)')
        elif os.path.exists(PUBLIC):
            pub = load_jsonl(PUBLIC)
            notes.append(f'UYARI: tr.jsonl yok; kod/yer tutucu/font/sözlük denetimleri ATLANDI. tr_public.jsonl: {len(pub):,} satır.')
            bad = [p['n'] for p in pub if 'src' in p or p['status'] not in ('done', 'review', 'keep')
                   or (p['status'] in ('done', 'review') and not p.get('tr', '').strip())]
            if bad:
                errors.append(f'tr_public.jsonl yapı hatası: n={bad[:10]} ({len(bad)})')
        else:
            errors.append('translations/tr_public.jsonl yok')
        rows = []
    else:
        rows = load_jsonl(OUT)
        err, warn, stats = qa.run(rows)
        errors += ['qa: ' + e for e in err]
        notes.append(f'Satır: {sum(stats.values()):,} | done {stats["done"]:,} | review {stats["review"]} | todo {stats["todo"]} | keep {stats["keep"]:,}')
        notes.append(f'qa UYARI sayısı: {len(warn)} (hata değil; ayrıntı work/qa_report.txt)')
        if stats['todo']:
            errors.append(f'{stats["todo"]} satır çevrilmemiş (todo)')
        odd = [r['n'] for r in rows if r['status'] not in ('todo', 'done', 'review', 'keep')]
        if odd:
            errors.append(f'geçersiz status: n={odd[:10]}')
        empty = [r['n'] for r in rows if r['status'] in ('done', 'review') and not r['tr'].strip()]
        if empty:
            errors.append(f'boş çeviri (done/review): n={empty[:10]} ({len(empty)})')
        # tr_public.jsonl ile tr.jsonl aynı mı?
        if not os.path.exists(PUBLIC):
            errors.append('translations/tr_public.jsonl yok (python tools/export_public.py)')
        else:
            pub = load_jsonl(PUBLIC)
            if len(pub) != len(rows):
                errors.append(f'tr_public.jsonl satır sayısı {len(pub)} != tr.jsonl {len(rows)} (export_public.py çalıştırın)')
            else:
                diff = [r['n'] for r, p in zip(rows, pub)
                        if r['ids'] != p['ids'] or r['status'] != p['status'] or (r['tr'] if r['status'] in ('done', 'review') and r['tr'] else None) != p.get('tr')]
                if diff:
                    errors.append(f'tr_public.jsonl güncel değil ({len(diff)} satır farklı, örn n={diff[:5]}); export_public.py çalıştırın')
                if any('src' in p for p in pub):
                    errors.append('tr_public.jsonl içinde "src" (İngilizce kaynak) alanı var')

    for k, d in man.get('dlc', {}).items():
        if d['out_sha'] == 'TBD' and os.environ.get('F3_INTERIM') != '1':
            errors.append(f'manifest.json dlc.{k}.out_sha hâlâ TBD (çeviri/derleme bitince doldurulmalı; ara derleme için F3_INTERIM=1)')
    # orijinal dosyalar manifest ile aynı mı (yanlış dosyadan derleme olmasın)
    ref = man['supported'][0]['files']
    for rel, want in ref.items():
        name = os.path.basename(rel)
        env = os.environ.get('F3_ORIG_BABEL' if name.endswith('.babel') else 'F3_ORIG_FONT')
        p = env or os.path.join(ROOT, 'backup', name + '.orig')
        if not os.path.exists(p):
            errors.append(f'orijinal dosya yok: {p}')
        elif sha(p) != want:
            errors.append(f'orijinal dosya hash\'i manifest ile uyuşmuyor: {p}')

    out = ['--- Doğrulama ---'] + notes + [f'HATA: {len(errors)}'] + ['  ' + e for e in errors[:50]]
    os.makedirs(os.path.dirname(a.report), exist_ok=True)
    open(a.report, 'w', encoding='utf-8').write('\n'.join(out + ['  ' + e for e in errors[50:]]))
    print('\n'.join(out))
    print('SONUÇ:', 'GEÇTİ' if not errors else 'BAŞARISIZ')
    sys.exit(1 if errors else 0)


if __name__ == '__main__':
    main()
