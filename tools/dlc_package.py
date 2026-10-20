r"""Fable III PC DLC paketi yazıcı: oyunun kendi DLC düzenine uygun YENİ bir paket klasörü üretir (f3patch ve test araçları kullanır).
Mevcut hiçbir DLC dosyasına dokunmaz; yalnızca yeni bir klasör oluşturur (silmek = geri alma).

Paket yapısı (99_dlc2_fixes örnek alınarak, doğrulandı):
  <paket>\content.xbx                           UTF-16 metin (TitleID, ContentID ...)
  <paket>\Content\package_collection_info.xmb   düz XML (paket listesi; mountOrder büyük = sonra yüklenir)
  <paket>\Content\<ad>.bnk + <ad>.bnk.dat       arşiv (indeks + ham veri); sanal yol özeti = FNV-1 (32 bit, küçük harf, '\')
Arşivde package_info.xml ve istenen dosyalar (örn. language\en-uk\text\book.babel) bulunur.
.bnk biçimi: [u32 toplam][u32 4][1 bayt 0][u32 sıkıştırılmış][u32 açık] + zlib(index);
  index = [u32 0][u32 N] + N*(u32 özet, u32 ofset, u32 boyut) + N*([u32 uzunluk][ad\0][27 sıfır + hizalama baytı]).
"""
import os
import struct
import zlib

ALIGN = 8
FOLDER = '99_tr_yama'
CONTENT_ID = 'B1A2C3D4E5F60718293A4B5C6D7E8F9012345678'
# Kaldırma, bu klasörde YALNIZCA şu adları tanır (başka bir şey varsa hiçbir şey silinmez):
KNOWN_NAMES = ['content.xbx', 'tr_yama.txt', 'Content\\package_collection_info.xmb']


def fnv1(path):
    h = 0x811C9DC5
    for c in path.lower().encode('ascii'):
        h = (h * 0x01000193) & 0xFFFFFFFF
        h ^= c
    return h


def build_archive(files, align=ALIGN):
    """files: [(sanal_yol, bytes)] -> (bnk_bytes, dat_bytes)"""
    dat = bytearray()
    ents = []
    for name, data in files:
        while len(dat) % align:
            dat.append(0)
        ents.append((fnv1(name), len(dat), len(data), name))
        dat.extend(data)
    while len(dat) % align:
        dat.append(0)
    idx = struct.pack('>II', 0, len(ents)) + b''.join(struct.pack('>3I', h, o, s) for h, o, s, _ in ents)
    for _, _, _, name in ents:
        nb = name.encode('ascii') + b'\x00'
        idx += struct.pack('>I', len(nb)) + nb + b'\x00' * 27 + bytes([align])
    comp = zlib.compress(idx, 9)
    assert len(idx) <= 65536
    body = struct.pack('>II', len(comp), len(idx)) + comp
    total = 9 + len(body)
    bnk = struct.pack('>II', total, 4) + b'\x00' + body
    return bnk, bytes(dat)


def _crlf(s):
    return s.replace('\r\n', '\n').replace('\n', '\r\n')


def package_info(bank, desc, order, uid, required=True):
    """required=True: v1.1.0 davranışı (bank içindeki package_info.xml'de isRequired=true; oyun bunu kayda 'zorunlu paket' yazar).
    required=False: resmî isteğe bağlı paketler gibi 'False' (kayıt bu pakete bağlanmaz)."""
    return _crlf(
        '<?xml version="1.0" ?>\n<package>\n\t<bankName>\n\t\t' + bank + '.bnk\n\t</bankName>\n'
        '\t<premiumContentMask>\n\t\t0\n\t</premiumContentMask>\n'
        '\t<contentsDescription>\n\t\t' + desc + '\n\t</contentsDescription>\n'
        '\t<isRequired>\n\t\t' + ('true' if required else 'False') + '\n\t</isRequired>\n\t<dependencies>\n\t\t\n\t</dependencies>\n'
        '\t<mountOrder>\n\t\t' + str(order) + '\n\t</mountOrder>\n'
        '\t<canIgnoreMountOrder>\n\t\ttrue\n\t</canIgnoreMountOrder>\n'
        '\t<name>\n\t\t' + bank + '\n\t</name>\n'
        '\t<needsRestart>\n\t\tfalse\n\t</needsRestart>\n'
        '\t<installContentMask>\n\t\t0\n\t</installContentMask>\n'
        '\t<packageUniqueId>\n\t\t' + str(uid) + '\n\t</packageUniqueId>\n'
        '\t<version>\n\t\t1.0\n\t</version>\n'
        '\t<deployment_folder>\n\t\t' + bank + '\\\n\t</deployment_folder>\n</package>\n').encode('utf-8')


def collection_info(banks, title, desc):
    """banks: [{'bank','desc','order','uid'}]"""
    pk = ''
    for b in banks:
        pk += (
            '\t<package>\n\t\t<bankName>\n\t\t\t' + b['bank'] + '.bnk\n\t\t</bankName>\n'
            '\t\t<premiumContentMask>\n\t\t\t0\n\t\t</premiumContentMask>\n'
            '\t\t<contentsDescription>\n\t\t\t' + b['desc'] + '\n\t\t</contentsDescription>\n'
            '\t\t<isRequired>\n\t\t\t' + b.get('xmb_required', 'false') + '\n\t\t</isRequired>\n\t\t<dependencies>\n\t\t\t\n\t\t</dependencies>\n'
            '\t\t<mountOrder>\n\t\t\t' + str(b['order']) + '\n\t\t</mountOrder>\n'
            '\t\t<canIgnoreMountOrder>\n\t\t\tfalse\n\t\t</canIgnoreMountOrder>\n'
            '\t\t<name>\n\t\t\t' + b['bank'] + '\n\t\t</name>\n'
            '\t\t<needsRestart>\n\t\t\tfalse\n\t\t</needsRestart>\n'
            '\t\t<installContentMask>\n\t\t\t0\n\t\t</installContentMask>\n'
            '\t\t<packageUniqueId>\n\t\t\t' + str(b['uid']) + '\n\t\t</packageUniqueId>\n'
            '\t\t<version>\n\t\t\t1.0\n\t\t</version>\n'
            '\t\t<deployment_folder>\n\t\t\t' + b['bank'] + '\\\n\t\t</deployment_folder>\n\t</package>\n')
    img = 'E:\\dev\\Fable3\\PCDLC2Branch\\SourceCode\\Fable2\\LIVE images\\X_IMAGEID_GAME.png'
    return _crlf(
        '<?xml version="1.0" ?>\n<packageCollection>\n'
        '\t<XContent_AllowProfileTransfer>\n\t\ttrue\n\t</XContent_AllowProfileTransfer>\n'
        '\t<XContent_thumbnail_path>\n\t\t' + img + '\n\t</XContent_thumbnail_path>\n'
        '\t<name>\n\t\t' + title + '\n\t</name>\n'
        '\t<XContent_IsMarketplace>\n\t\ttrue\n\t</XContent_IsMarketplace>\n'
        '\t<XContent_PublisherFlags>\n\t\t0xFFFFFFFF\n\t</XContent_PublisherFlags>\n'
        '\t<XContent_ContentID>\n\t\t0x' + CONTENT_ID + '\n\t</XContent_ContentID>\n'
        '\t<requiredGameVersion>\n\t\t53\n\t</requiredGameVersion>\n'
        '\t<XContent_HasCost>\n\t\tfalse\n\t</XContent_HasCost>\n'
        '\t<XContent_DashIconPath>\n\t\t' + img + '\n\t</XContent_DashIconPath>\n'
        '\t<XContent_PubBitFlags>\n\t\tFFFFFFFF\n\t</XContent_PubBitFlags>\n'
        '\t<XContent_activation_date>\n\t\t01/01/2010\n\t</XContent_activation_date>\n'
        '\t<isLanguagePack>\n\t\tFalse\n\t</isLanguagePack>\n'
        '\t<XContent_TitleIconPath>\n\t\t' + img + '\n\t</XContent_TitleIconPath>\n'
        '\t<XContent_title_id>\n\t\t0x4D53090A\n\t</XContent_title_id>\n'
        '\t<XContent_AllowDeviceTransfer>\n\t\ttrue\n\t</XContent_AllowDeviceTransfer>\n'
        '\t<XContent_PubOfferingID>\n\t\tECF0000\n\t</XContent_PubOfferingID>\n'
        '\t<XContent_folder>\n\t\txContent\n\t</XContent_folder>\n'
        '\t<XContent_title>\n\t\tFable III\n\t</XContent_title>\n'
        '\t<description>\n\t\t' + desc + '\n\t</description>\n' + pk + '</packageCollection>\n').encode('utf-8')


def content_xbx(title, desc):
    t = _crlf(
        '[All]\nPremium=No\nTitleID=0x4D53090A\nContentPackageType=0x00000002\nLicenseBits=0x00000000\n'
        'BaseVersion=0x00000000\nUpdateVersion=0x00000000\nThumbnailImage=icon.png\nOfferingID=0xECF0F00\n'
        'AdminFriendlyName="' + title + '"\nTitleName="Fable III"\nPurchaseOnceOnly=Yes\nContentFlags=0xC0\n'
        'ContentID=' + CONTENT_ID + '\nPlatform=0x10\nBitFlags=0xFFFFFFFF\nActivationDate=01/01/2010\n'
        'DefaultDisplayName="' + title + '"\nOfferRegions.0=103,0,0,TaxNotApplicable\nOfferingType=Content\n'
        'EndDate=12/31/2999\nDisplayInDash=Yes\nVersion=0x00000001\n'
        'DashDisplayName.0=EN,"' + title + '"\nDashDescription.0=EN,"' + desc + '"\n')
    return b'\xff\xfe' + t.encode('utf-16-le')


def write_collection(dest, banks, version='', title='Fable III Turkce Yama', desc='Turkce yama (DLC metinleri)'):
    """dest: oluşturulacak paket klasörü (içeriği önceden BOŞ/YOK olmalı; var olan dosyaların üzerine yazılır).
    banks: [{'bank': 'tr_yama_us', 'desc': '..', 'uid': 120, 'order': 10000, 'book': bytes}]
    Dönen: [(göreli yol, sha256)] — yazılan tüm dosyalar."""
    import hashlib
    os.makedirs(os.path.join(dest, 'Content'), exist_ok=True)
    out = []

    def put(rel, data):
        p = os.path.join(dest, rel)
        with open(p, 'wb') as f:
            f.write(data)
        out.append((rel, hashlib.sha256(data).hexdigest()))
    for b in banks:
        info = package_info(b['bank'], b['desc'], b['order'], b['uid'], b.get('required', True))
        files = [('package_info.xml', info)]
        if b.get('book') is not None:      # book=None: yer tutucu paket (yalnızca package_info.xml; oyuna hiçbir şey eklemez)
            files.append(('language\\en-uk\\text\\book.babel', b['book']))
        bnk, dat = build_archive(files)
        put('Content\\' + b['bank'] + '.bnk', bnk)
        put('Content\\' + b['bank'] + '.bnk.dat', dat)
    put('Content\\package_collection_info.xmb', collection_info(banks, title, desc))
    put('content.xbx', content_xbx(title, desc))
    marker = _crlf('Fable III Turkce Yama - DLC metin paketi (kurulum programi tarafindan olusturuldu; silmek guvenlidir).\n'
                   'Surum: ' + version + '\nPaketler: ' + ', '.join(b['bank'] for b in banks) + '\n')
    put('tr_yama.txt', marker.encode('ascii'))
    return out


def known_files(banks_names):
    """Kaldırmanın silmesine izin verilen tüm göreli yollar."""
    names = list(KNOWN_NAMES)
    for b in banks_names:
        names += ['Content\\' + b + '.bnk', 'Content\\' + b + '.bnk.dat']
    return names
