r"""Kayıt/DLC-paketi testi için paket üretir (BAKIMCI aracı; üretilen paketler tests\oyun_ici\paketler\ altına yazılır ve depoya GİRMEZ, .gitignore'dadır): tests\oyun_ici\paketler\
Sorun: v1.1.0'ın DLC\99_tr_yama paketi kayda 'zorunlu paket' (RequiredPackage 120/121) olarak yazılıyor; yama kaldırılınca kayıt
"required downloadable content" uyarısı veriyor.

Varyantlar (hepsi aynı paket kimlikleriyle: packageUniqueId 120/121, klasör 99_tr_yama):
  V0   v1.1.0 gibi (bank içi isRequired=true, xmb 'false')            -> sorunun yeniden üretimi / karşılaştırma
  V1   bank içi isRequired=False, xmb 'False' (resmî isteğe bağlı paketler gibi)  -> ÖNERİLEN düzeltme (a)
  V1x  yalnızca bank içi isRequired=False (xmb eskisi gibi 'false')   -> V1 işe yaramazsa ayırt etmek için
  V1y  yalnızca xmb 'False' (bank içi true)                          -> V1 işe yaramazsa ayırt etmek için
  V2   YER TUTUCU: aynı kimlikler, arşivde yalnızca package_info.xml (book.babel YOK, isRequired=False)  -> seçenek (b)
Kullanım: python tools\make_test_save.py   (gerekli: backup\dlc_*_en.babel.orig, translations\tr_public.jsonl, manifest.json)
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dlc_build
import dlc_package
from init_translations import ROOT, load_jsonl

KIT = os.path.join(ROOT, 'tests', 'oyun_ici')


def banks_for(variant, books, defs):
    out = []
    for key, d in defs.items():
        b = {'bank': d['bank'], 'desc': d['desc'], 'uid': d['uid'], 'order': d['order'], 'book': books[key]}
        if variant == 'V0':
            pass
        elif variant == 'V1':
            b.update(required=False, xmb_required='False')
        elif variant == 'V1x':
            b.update(required=False)
        elif variant == 'V1y':
            b.update(xmb_required='False')
        elif variant == 'V2':
            b.update(required=False, xmb_required='False', book=None)
        else:
            raise ValueError(variant)
        out.append(b)
    return out


def main():
    man = json.load(open(os.path.join(ROOT, 'manifest.json'), encoding='utf-8'))
    defs = man['dlc']
    rows = load_jsonl(os.path.join(ROOT, 'translations', 'tr_public.jsonl'))
    books = {}
    for key, d in defs.items():
        src = os.path.join(ROOT, 'backup', f'dlc_{key}_en.babel.orig')
        raw = open(src, 'rb').read()
        assert dlc_build.sha256(raw) == d['src_sha'], 'DLC kaynağı manifest ile uyuşmuyor: ' + src
        tr, dlg = [], []
        for r in rows:
            if r.get('dlc') != key:
                continue
            if r['cat'] == 'dialog':
                dlg.extend(int(i, 16) for i in r['ids'])
            if r['status'] in ('done', 'review') and r.get('tr'):
                tr.append([[int(i, 16) for i in r['ids']], r['tr']])
        data, applied = dlc_build.build_dlc_book(raw, tr, sorted(set(dlg)))
        books[key] = data
        print(f'{key}: {applied} kayıt, kitap {dlc_build.sha256(data)[:12]} (manifest out_sha {d["out_sha"][:12]}; çeviri v1.1.1 düzeltmelerini içerir, farklı olabilir)')
    for v in ('V0', 'V1', 'V1x', 'V1y', 'V2'):
        dest = os.path.join(KIT, 'paketler', v, dlc_package.FOLDER)
        dlc_package.write_collection(dest, banks_for(v, books, defs), version='test-' + v)
        print('paket:', os.path.relpath(dest, ROOT))
    print('Kit klasörü:', KIT)


if __name__ == '__main__':
    main()
