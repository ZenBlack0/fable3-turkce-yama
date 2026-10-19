r"""DLC kitabı üretimi (build.py ve f3patch ortak kullanır; aynı kod = aynı baytlar).

Kullanıcının KENDİ DLC İngilizce kitabı (DLC arşivinden okunur) + "kayıt ID'si -> Türkçe" çeviri = Türkçe DLC kitabı.
Tam altyazı: DLC'deki konuşma satırlarının altyazı bayrağı (Table 2 son bayt) 1 yapılır.
"""
import hashlib
import os
import tempfile

from babel import Babel, write_babel
from flags import set_subtitle_flags
from repack import apply_translations


def sha256(b):
    return hashlib.sha256(b).hexdigest()


def build_dlc_book(src_bytes, tr_pairs, dialog_ids):
    """src_bytes: DLC İngilizce book.babel; tr_pairs: [[ [id,...], 'Türkçe' ], ...]; dialog_ids: {id:int}. -> (bytes, uygulanan)"""
    tmpd = tempfile.mkdtemp(prefix='f3dlc_')
    src = os.path.join(tmpd, 's.babel')
    out = os.path.join(tmpd, 'o.babel')
    try:
        with open(src, 'wb') as f:
            f.write(src_bytes)
        b = Babel(src)
        by_id = {}
        for ids, tr in tr_pairs:
            for i in ids:
                by_id[f'0x{i:08X}'] = tr
        new_texts, st = apply_translations(b, by_id, {}, {})
        write_babel(b, new_texts, out, 0)
        set_subtitle_flags(out, set(dialog_ids))
        with open(out, 'rb') as f:
            data = f.read()
        return data, st['applied']
    finally:
        for p in (src, out):
            if os.path.exists(p):
                os.remove(p)
        try:
            os.rmdir(tmpd)
        except OSError:
            pass
