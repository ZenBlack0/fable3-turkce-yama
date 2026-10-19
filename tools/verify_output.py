r"""Uçtan uca çıktı denetimi: ÜRETİLEN kitapların (ana book.babel ve iki DLC kitabı) her kaydını ORİJİNALİYLE karşılaştırır.
qa.py çeviri satırlarını (tr.jsonl) denetler; bu araç ise gerçekten yazılan baytları denetler:
  - kayıt sayısı ve kayıt ID kümesi orijinalle aynı mı,
  - her kayıtta korunan kodlar (<...>, %1, %s, %d ...) orijinaldeki gibi mi (eksik/fazla -> HATA),
  - boş kayıt var mı (orijinalde dolu, çıktıda boş -> HATA).
  python tools/verify_output.py        (build.py çalıştıktan sonra: work/delta_build/book.babel)
build_all.py bunu build'den sonra otomatik çalıştırır. Hata varsa çıkış kodu 1.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from babel import Babel, split_nulls
from init_translations import ROOT, load_jsonl
from trtext import protected_tokens
import dlc_build

BUILT = os.path.join(ROOT, 'work', 'delta_build', 'book.babel')
ORIG = os.environ.get('F3_ORIG_BABEL') or os.path.join(ROOT, 'backup', 'book.babel.orig')
PUBLIC = os.path.join(ROOT, 'translations', 'tr_public.jsonl')


def compare(name, orig_path, built_path, limit=25):
    a, b = Babel(orig_path), Babel(built_path)
    da = {e[0]: split_nulls(a.raw_text(e))[0] for e in a.entries}
    db = {e[0]: split_nulls(b.raw_text(e))[0] for e in b.entries}
    errs = []
    if set(da) != set(db):
        errs.append(f'{name}: kayıt ID kümesi farklı (eksik {len(set(da) - set(db))}, fazla {len(set(db) - set(da))})')
    changed = 0
    for i, src in da.items():
        out = db.get(i)
        if out is None:
            continue
        if out != src:
            changed += 1
        if src.strip() and not out.strip():
            errs.append(f'{name}: 0x{i:08X} çıktı boş (kaynak {src[:40]!r})')
        ta, tb = protected_tokens(src), protected_tokens(out)
        if ta != tb:
            errs.append(f'{name}: 0x{i:08X} kod uyuşmazlığı eksik={dict(ta - tb)} fazla={dict(tb - ta)} | {src[:40]!r} -> {out[:40]!r}')
    print(f'{name}: {len(da):,} kayıt, çevrilen/değişen {changed:,}, kod uyuşmazlığı/boş: {len(errs)}')
    for e in errs[:limit]:
        print('  HATA', e)
    return errs


def main():
    if not os.path.exists(BUILT):
        sys.exit('çıktı yok: ' + BUILT + ' (önce build.py çalıştırın)')
    errs = compare('ana kitap', ORIG, BUILT)
    man = json.load(open(os.path.join(ROOT, 'manifest.json'), encoding='utf-8'))
    rows = load_jsonl(PUBLIC)
    for key in man.get('dlc', {}):
        src = os.environ.get('F3_DLC_' + key.upper()) or os.path.join(ROOT, 'backup', f'dlc_{key}_en.babel.orig')
        if not os.path.exists(src):
            print(f'DLC {key}: İngilizce kitap yok, atlandı ({src})')
            continue
        tr, dlg = [], []
        for r in rows:
            if r.get('dlc') != key:
                continue
            if r['cat'] == 'dialog':
                dlg.extend(int(i, 16) for i in r['ids'])
            if r['status'] in ('done', 'review') and r.get('tr'):
                tr.append([[int(i, 16) for i in r['ids']], r['tr']])
        data, _ = dlc_build.build_dlc_book(open(src, 'rb').read(), tr, sorted(set(dlg)))
        tmp = os.path.join(ROOT, 'work', f'_verify_{key}.babel')
        os.makedirs(os.path.dirname(tmp), exist_ok=True)
        open(tmp, 'wb').write(data)
        try:
            errs += compare(f'DLC {key}', src, tmp)
        finally:
            os.remove(tmp)
    print('SONUÇ:', 'GEÇTİ' if not errs else f'BAŞARISIZ ({len(errs)} hata)')
    sys.exit(1 if errs else 0)


if __name__ == '__main__':
    main()
