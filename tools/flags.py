"""Table 2 son durum baytı (fd_subtitled) bayrağını ayarlar: 'Tam altyazı' varyantı."""
import struct
from babel import Babel


def set_subtitle_flags(babel_path, ids):
    t = Babel(babel_path).tail
    d = bytearray(open(babel_path, 'rb').read())
    base = len(d) - len(t)
    cnt = struct.unpack('>I', t[4:8])[0]
    n = 0
    for i in range(cnt):
        o = base + 8 + i * 11
        if struct.unpack('>I', d[o:o + 4])[0] in ids:
            d[o + 10] = 1
            n += 1
    open(babel_path, 'wb').write(d)
    return n


def dialog_ids(rows):
    return {int(i, 16) for r in rows if r['cat'] == 'dialog' for i in r['ids']}
