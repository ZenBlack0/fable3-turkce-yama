"""Ortak yardımcılar: korunan kodlar, Türkçe büyük/küçük harf, font charmap."""
import re
import struct
from collections import Counter

# Çeviride AYNEN korunacak kodlar. Not: [Köşeli parantez] metinleri altyazı sahne notlarıdır
# ("[Laughter]") ve ÇEVRİLİR; yalnızca <...>, %1 %2 %s %d %name% ve satır sonu korunur.
PROTECTED = re.compile(r'<[^>]+>|%[1-9](?!\d)|%[sdfiux]|%[A-Za-z_]+%|\n')


def protected_tokens(text):
    return Counter(PROTECTED.findall(text or ''))


def missing_tokens(src, tr):
    """Kaynakta olup çeviride eksik/fazla olan kodlar -> (eksik, fazla)"""
    a, b = protected_tokens(src), protected_tokens(tr)
    return a - b, b - a


_UP = {'i': 'İ', 'ı': 'I'}
_LO = {'I': 'ı', 'İ': 'i'}


def tr_upper(s):
    return ''.join(_UP.get(c, c.upper()) for c in s)


def tr_lower(s):
    return ''.join(_LO.get(c, c.lower()) for c in s)


def is_all_caps(s):
    letters = [c for c in s if c.isalpha()]
    return len(letters) >= 2 and all(c == tr_upper(c) for c in letters)


def font_charset(bft_path):
    """.bft içindeki charmap'te glifi olan kod noktaları kümesi."""
    f = open(bft_path, 'rb').read()
    gc = struct.unpack('<I', f[21:25])[0]
    p = 25 + gc * 28
    ec = struct.unpack('<I', f[p:p + 4])[0]
    cm = struct.unpack('<%dH' % ec, f[p + 4:p + 4 + ec * 2])
    return {i for i, g in enumerate(cm) if g != 0xE1E1}
