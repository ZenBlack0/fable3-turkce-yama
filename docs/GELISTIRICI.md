# Geliştirici belgesi (mimari, kurallar, karar geçmişi)

Bu belge projeyi sıfırdan devralan birinin (ya da gelecekteki kendimizin) bilmesi gerekenleri toplar. Ortam kurulumu ve adım adım sürüm çıkarma: [KURULUM_GELISTIRICI.md](KURULUM_GELISTIRICI.md). Oyun dosyası biçimi: [FORMAT.md](FORMAT.md). Üslup: [STYLE_VILLAGERS.md](STYLE_VILLAGERS.md) ve `glossary.csv`.

## 1. Özet

- Hedef: Fable III (PC, Steam, App 105400, en-uk dil) için Türkçe yama. Metinler `data\language\en-uk\text\book.babel` içindedir; yama bu dosyayı **kullanıcının kendi kopyasından** yeniden üretir. Depoda ve kurucuda oyun dosyası ya da İngilizce oyun metni **yoktur**.
- Desteklenen orijinaller (Steam en-uk): `book.babel` SHA-256 `1a588553b9dde08b3aa37d609f5e2ec9a9a9f2cb8f0d93bb3b93cdeca2e7afc3` (3.197.586 bayt), `gui_normal.bft` `913cf1699e2fc3b612f18ee88957f44451abf8bbe88df0bf6c5d075ec6e8f0a3` (1.071.935 bayt). Başka sürümde kurucu hiçbir şeyi değiştirmeden durur.
- Yama yalnızca **tam altyazı** kurar (köylü/muhafız konuşmaları dahil tüm konuşmalarda Türkçe altyazı). Eski "Standart mod" v1.1.0'da kaldırıldı; eski Standart/Tam kurulumlar "kurulu (eski sürüm)" olarak tanınır ve *Yeniden kur / onar* ile güncellenir.
- Understone ve Traitor's Keep DLC metinleri de çevrilidir (§5).

## 2. Mimari

```
manifest.json            TEK KAYNAK: sürüm/tag, desteklenen orijinal hash'ler, çıktı hash'leri (book, font, DLC out_sha), DLC tanımları
translations/tr_public.jsonl   paylaşılan çeviri: {n, ids, cat, status, tr, dlc?}  (İngilizce kaynak YOK)
translations/tr.jsonl    YEREL çalışma dosyası (İngilizce kaynak içerir, depoya girmez): import_public.py ile üretilir
translations/block_map.json, overrides.csv, glossary.csv
tools/babel.py           book.babel okuma/yazma (UTF-16BE, zlib blokları, Table 1/2/3)
tools/repack.py          çeviri -> book.babel (önce kayıt ID'si, sonra tam metin eşleşmesi)
tools/flags.py           tam altyazı bayrağı (Table 2, her kaydın son baytı)
tools/font_patch.py      gui_normal.bft yaması (ğ Ğ ş Ş ı İ glifleri)
tools/qa.py, validate_all.py   kod/etiket/uzunluk/sözlük denetimi; doğrulama
tools/build.py           çıktıları üretir/doğrular, çeviri paketini (book_pack.lzma) ve font.xdelta'yı yazar, f3patch'i Nuitka ile derler, Inno Setup'ı çağırır
tools/build_all.py       validate -> build --exe -> selftest -> zip -> SHA256SUMS -> (yerel çalışma alanında depo klasörü) -> scan_release
tools/scan_release.py    sızıntı taraması: pakette/depoda İngilizce oyun metni, oyun dosyası uzantısı
tools/helper/f3patch.py  kurucunun çağırdığı yardımcı: `book` ve `dlc` komutları
tools/dlc_bnk.py, dlc_build.py, dlc_package.py, init_dlc.py   DLC arşivi okuma / DLC kitabı üretme / DLC paketi yazma / DLC satırlarını üretme
tools/installer/fable3_tr.iss  Inno Setup betiği (Pascal Script), known_hashes.inc build tarafından üretilir
tools/installer/test_*.ps1     kurucu testleri (sahte oyun klasörlerinde)
tools/gen_docs.py + tools/docs_src/   README, OKUBENI, RELEASE_NOTES, antivirus.md, issue şablonları buradan üretilir (elle yazılmaz)
```

**Çeviri akışı.** `import_public.py` kullanıcının orijinal `book.babel` dosyasındaki İngilizceyi `tr_public.jsonl` ile kayıt ID'si üzerinden birleştirip `tr.jsonl` üretir (aynı İngilizce metnin bağlama göre farklı çevrildiği satırları böler; DLC satırlarını DLC kitaplarından ekler). Düzeltme `tr.jsonl` üzerinde yapılır, `export_public.py` sıralı (n'e göre) ve bayt bayt tekrarlanabilir şekilde `tr_public.jsonl` yazar; depoya yalnızca o girer.

**Kurucu akışı.** Kurucu iki şey taşır: `book_pack.lzma` (kayıt ID -> Türkçe, DLC bölümü dahil) ve `f3patch` + `font.xdelta`. Kullanıcının kendi dosyasından kitabı yeniden paketler ve çıktıyı SHA-256 ile doğrular. DLC için: kullanıcının DLC kitabı (SHA-256'sı pakette tanımlı sürümlerle eşleşirse) Türkçeleştirilip **ayrı** bir paket olarak yazılır.

**Çıktı tekrarlanabilirliği.** `book.babel` içindeki zlib akışlarının baytları zlib sürümüne bağlıdır. Hash'ler **Python 3.14.7 + zlib-ng 1.3.1** ile üretilmiştir; `build.py` başta sürümü yazdırır ve her durumda çıktıyı manifest'teki hash ile karşılaştırır (tutmazsa durur). Güncel hash'ler: ana kitap `3eba8894429ac5ffb35e750ae1edba59192e131724c005c128e5700bdcb66754`, font `a88867207aacaa772a2f36d60ba576671cd21a7e965fb19ad6f7429818690e08`; DLC çıktıları `manifest.json` içindeki `dlc.*.out_sha`.

## 3. Kurucu güvenlik kuralları (ihlal etme)

1. `{app}` (kurucu + kaldırıcı + `kurulum_log.txt`, `Program Files\Fable3 Turkce Yama`) ile oyun klasörü **ASLA aynı yer değildir**. Oyun klasörü yolu kayıt defterinde `OyunKlasoru` olarak tutulur.
2. Oyun klasöründe yalnızca `data\language\en-uk\text\book.babel`, `...\fonts\gui_normal.bft`, `_TR_yedek` ve (DLC kuruluysa) kendi klasörümüz `DLC\99_tr_yama` değişir (kaldırmadan sonra bu klasör **yer tutucu olarak kalabilir**, kural 10). DLC arşivlerine (`.bnk`, `.bnk.dat`) yalnızca **okunur**; yazılmaz.
3. Oyun klasörüne `[Files]` ile yazılmaz; kodla kopyalanır ve hash ile doğrulanır.
4. Kaldırma: orijinalleri `_TR_yedek`ten geri yükler (yedeğin hash'i orijinal değilse geri yüklemez, yedeği silmez). `_TR_yedek` içinde ve `DLC\99_tr_yama` içinde **yalnızca bizim bildiğimiz dosyaları** siler/değiştirir; listede olmayan bir öğe varsa hiçbir şey silmez. `DelTree` kullanılmaz.
5. Oyun klasöründeki hiçbir `unins*.exe` çalıştırılmaz/silinmez (oyunun kendi kaldırıcısı olabilir). Eski hatalı kayıt/`unins*.dat` yalnızca `.dat` içinde bizim AppId'miz varsa temizlenir.
6. Kurulum öncesi orijinaller SHA-256 ile doğrulanır; tutmazsa kurucu çıkış kodu 3/7 ile durur, hiçbir şey yazmaz. `/FORCE` etkisizdir.
7. Yalnızca desteklenen DLC kitabı sürümleri için paket eklenir; DLC yoksa/desteklenmiyorsa paket eklenmez (ana yama yine kurulur).
8. Gerçek oyun klasörüne test amaçlı dosya koyma: testler sahte klasörlerde çalışır. Oyun içi deneme paketleri (`apply.bat`) kullanılırsa **testten sonra mutlaka `restore.bat`** çalıştırılmalıdır; aksi halde kurucu "desteklenmiyor" der (oyun klasöründe bilinmeyen kitap kalır).
9. Yeni kurulum sürümü, eski sürümlerle kurulmuş yamayı ("kurulu (eski sürüm)") tanımalı ve orijinal yedeğe dokunmadan güncellemelidir.

## 4. Olay notu: kaldırıcı oyun klasörünü sildi (2026-10, ilk .exe sürümü)

İlk kurulum programı sürümünde `{app}` oyun klasörüydü ve "Yamayı kaldır" yolunda, kayıt bulunamazsa oyun klasöründeki `unins000.exe` çalıştırılıyordu. Bir kullanıcının oyun klasörü (büyük olasılıkla oyunun kendi Inno kaldırıcısının çalışması yüzünden) tamamen silindi. Kesin kanıt yok (kendi kaldırıcımızla sahte klasörde yeniden üretilemedi). Önlemler yukarıdaki §3'tür: ayrı uygulama klasörü, oyun klasöründe unins çalıştırma/silme yok, `DelTree` yok, izinli dosya listesi, eski kaydı güvenli temizleme; hepsi `test_safe.ps1` ile sınanır (T1–T11). Eski hatalı sürüm yayımlanmamalıdır.

## 5. Teknik bulgular (doğrulandı)

- **book.babel**: bkz. FORMAT.md. 395 blok; bloklar 16 KB'yi aşabilir (64 KB'a kadar oyunda okundu). Varsayılan "bölme yok".
- **Altyazı bayrağı**: Table 2'deki 11 baytlık kaydın son baytı = "altyazılı" bayrağı. Köylü barklarında bayrak 1 yapılınca altyazı görünür. Yama tüm konuşma satırlarına uygular (ana kitap 45.721 kayıt).
- **Aynı İngilizce metnin çok kaydı**: menü beklenmedik kopyayı kullanabildiği için çeviri benzersiz metnin **tüm kayıtlarına** uygulanır; bağlama göre farklı çeviri gerekirse satır bölünür (örn. "Vault": eylem "Atla" / menü "Kasa"), istisnalar `overrides.csv`.
- **Font**: `gui_normal.bft` SDF atlası 512x512; Türkçe harfler `font_patch.py` ile eklenir. `ğ/Ğ` üzerindeki breve U biçimli ve ~2 piksel çekirdeklidir (eski ∩ biçimli sürüm neredeyse görünmezdi). `…` (U+2026) fontta yok: "..." kullan.
- **Harita bölge adları** dokudur (resim); yazı değildir, yama çeviremez (README/OKUBENI'de not var).
- **DLC kitapları ana kitaba eklenemez** ("A yolu" test edildi: DLC kitabı ana kitabın üstüne biner, ana kitaba eklenen kayıtlar DLC metinlerini geçmez). **Çalışan yol**: oyunun DLC klasörüne yeni paket `DLC\99_tr_yama` (mountOrder 10000/10001, tüm DLC'lerden sonra). Paket formatı (`dlc_package.py`): `content.xbx`, `Content\package_collection_info.xmb`, `Content\tr_yama_us.bnk(.dat)` ve `tr_yama_tk.bnk(.dat)`; `.bnk` = [u32 toplam][u32 4][1 bayt][parçalar: u32 sıkıştırılmış, u32 açık(64 KB) + zlib]; indeks = [0][N] + N x (FNV-1 yol özeti, ofset, boyut) + N x ([u32 uzunluk][ad\0][27 sıfır + hizalama]). İngilizce kitap yol özeti `0x50B6B0BF` = FNV-1("language\en-uk\text\book.babel"). Resmî DLC paketleri Microsoft imzalı `content.cat` taşır; `99_dlc2_fixes` taşımaz ve çalışır, bizim paket de `content.cat` içermez ve oyunda çalışır (xlive.dll'de WinVerifyTrust var, cat-sız paket kabul edilir).
- **DLC kitapları**: Understone `src_sha` `16000712a304bd6cb8ea4175800d5490369c0995eed70b9f3133b0538c04a55b`, Traitor's Keep `529aaf16e1455ad55b3570c7d8cb2bc4e6301ddbf4eae81ca9ddd3769762ac11` (manifest'te). DLC satırlarının ana kitapla aynı İngilizce olanları (106 adet) ana çeviriyi yeniden kullanır; konuşma satırlarına tam altyazı bayrağı uygulanır.
- **Steam "dosya bütünlüğünü doğrula"** book/font'u orijinaline döndürebilir (yamayı geri alır); `DLC\99_tr_yama` klasörünü silip silmediği kesin sınanmadı. Çare: kurucuyu yeniden çalıştırmak.
- Kurucu bir Nuitka `--standalone` derlemesi olan `f3patch.exe`'yi içerir (`--onefile` ve UPX yok). Yanlış alarm geçmişi ve sonuçlar: [antivirus.md](antivirus.md).

## 6. Çeviri ilkeleri (özet)

- Terimler `glossary.csv`'de (onaylı): Hobb, Kof Adam (Hollow Man), Balverin, Kum İfriti (Sand Fury), Sanayi Şövalyesi, Kale (Keep), Cadı Mary, Ravenscar Kalesi; yer adları çevrilmez (Bowerstone, Mistpeak...), yalnızca genel kısımlar çevrilir (Vadisi, Kalesi).
- Halk/yoldaş "sen"; resmî bağlamlar ve hükümdara hitap "siz"/"Majesteleri". Dini ifade yok. Calque yok (STYLE_VILLAGERS.md'deki yasak kalıplar).
- Korunan kodlar: `<...>` etiketleri, `%1 %2 %s %d`, gerçek satır sonları. `[Köşeli parantez]` altyazı sahne notudur ve çevrilir. Orijinal BÜYÜK HARFLİ kısa metinler elle büyütülür.
- Kısa buton/menü metinleri İngilizce uzunluğunun yaklaşık %20 fazlasını aşmamalı (taşma); aşılıyorsa anlam için bilinçli istisna not edilir (örn. "Hapishaneyi Büyüt", "Özgürleştir").
- Kısaltma kararları: Pan->Kaydır, Rename->Yeniden Adlandır, Kick->Oyundan At, Pause Menu->Duraklatma Menüsü, Hero Titles->Kahraman Unvanları, Thumbs Up/Down->Beğen/Beğenme, The Purist->Pürist, The Debaser->Yozlaştırıcı, Block->blok(lamak), Force Push->İtiş.
- Çeviri yapay zekâ desteğiyle yapıldı; terim/üslup elle belirlendi, örnekleme ve oyun içi testlerle denetlendi. 57 binden fazla satırın hepsi tek tek okunmadı: hata bildirimleri bekleniyor.

## 7. Karar geçmişi

| Sürüm | Karar / olay |
|---|---|
| v0.9–v1.0 | Çeviri ve font tamamlandı; Inno Setup ile ilk .exe. İlk .exe'de oyun klasörünü silme olayı (§4). |
| v1.0.1 | Delta (xdelta3) dağıtımı denendi: delta yamalı dosyanın büyük kısmını taşıdığı için bırakıldı. |
| v1.0.2 | "Kayıt ID -> Türkçe" çeviri paketi + `f3patch` yardımcısı (kullanıcının kendi dosyasından üretim); çıktı hash'leri sabitlendi; `.exe` PyInstaller. |
| v1.1.0 | `manifest.json` tek kaynak; Nuitka standalone + MSVC; zip içinde dağıtım + `OKUBENI.txt`; Standart mod kaldırıldı (yalnızca tam altyazı); DLC çevirisi (`DLC\99_tr_yama` paketi); `ğ/Ğ` düzeltmesi; bağlam düzeltmeleri; "Yama zaten kurulu" sayfası yeniden yazıldı (3 seçenek + dosya dosya durum). Yayın: GitHub Release v1.1.0. |
| v1.1.1 (2026-10-20) | v1.1.0'da yama kaldırılınca yama kuruluyken alınan kayıtlar "required downloadable content" uyarısıyla açılmıyordu (paket kayda RequiredPackage 120/121 yazıyordu). Çözüm: paket `isRequired=False` (kimlikler/klasör aynı), kaldırıcı kayıt klasörünü salt okunur tarayıp gerekirse yer tutucu bırakır (kural 10), yükseltme eski paketi/yer tutucuyu değiştirir. Ayrıca `%1%` kod kaybı (2 satır), 21 DLC calque'ı, qa/verify_output iyileştirmeleri. VirusTotal: zip 0/67, exe 2/70 (SecureAge, Skyhigh; Microsoft/Defender tespiti YOK). Release: https://github.com/ZenBlack0/fable3-turkce-yama/releases/tag/v1.1.1 |

Önemli düzeltmeler/dersler: (1) `'Vault'` gibi bölünmüş satırlar için `repack` her kaynak satırı kayıt ID'siyle de kaydeder; yerel (metin eşleşmesi) ve paket (ID) üretimi aynı sonucu verir. (2) PyInstaller `--onefile`/Nuitka `--onefile` antivirüs yanlış alarmı artırdı; `--standalone` seçildi. (3) xdelta3'ün gömülü kaynak yolu hatası (`-A=` ile giderildi). (4) Testlerde bir kerede tek test çalıştırın: ortak `%TEMP%` klasörleri karışır. (5) `test_gui.ps1` D bölümü (kaldır) onay penceresine tuş gönderemez: bu bir test düzeneği sınırıdır, aynı akış `test_safe.ps1` T2'de geçer.

## 8. Testler

Hepsi sahte oyun klasörlerinde çalışır (gerçek oyuna dokunmaz). Etkileşimli masaüstü gerekir (SendKeys/ekran görüntüsü); arka plan/oturumu kilitli koşullarda `test_gui`/`test_detect` çalışmaz.

| Betik | Ne sınar |
|---|---|
| `test_selftest.ps1` | `/SELFTEST` (gömülü paketler, xdelta3, f3patch, hash'ler), zip içinden çalıştırmayı reddetme |
| `test_safe.ps1` | T1–T11: oyun klasöründe yalnızca izinli dosyalar değişir; kaldırma; yabancı `unins000`; `_TR_yedek` içinde beklenmeyen dosya; DLC paketi ekleme/silme; eski Standart kurulumu onarma. Eski sürüm kurucuları (`-Old102`, `-OldExe`) verilmezse ilgili testler atlanır |
| `test_exe.ps1` | sessiz senaryolar (bozuk yedek, bilinmeyen dosyalar, eski yedek yenileme) |
| `test_detect.ps1` | oyun klasörü otomatik bulma, oyunu başlatma |
| `test_gui.ps1` | sihirbaz sayfalarının ekran görüntüleri (`work\installer_ss`) |
| `shot_instpage.ps1` | "Yama zaten kurulu" sayfası ekran görüntüsü |

`F3_GAME` ortam değişkeni (ya da `-RealGame`) verilirse `test_safe.ps1` bu gerçek oyun klasörünün test boyunca değişmediğini de denetler.

## 9. Sürüm çıkarma (özet)

Ayrıntılı komutlar [KURULUM_GELISTIRICI.md](KURULUM_GELISTIRICI.md) §6'dadır: hata düzelt -> `tr_public.jsonl` -> `manifest.json` sürüm/hash güncelle -> `build_all` -> testler -> belgeler (`gen_docs`) -> VirusTotal -> Release. Yayımlanmış sürümün dosyalarına ve etiketine dokunulmaz; her düzeltme yeni sürüm olur.

## 10. Açık işler / bilinen sınırlar

- v1.1.0'daki Microsoft Defender `Trojan:Win32/Wacatac.B!ml` (ML tahmini) yanlış alarmı v1.1.1'de görülmüyor (Microsoft tespit vermiyor); bildirim daha önce yapılmıştı. Yayın sonrası her yeni derleme yeniden VirusTotal'a yüklenmelidir.
- Yalnızca Steam en-uk hash'leri doğrulandı; perakende (DVD) ve GFWL sürümleri sınanmadı. Yama yalnızca en-uk slotuna yazar.
- Kurucu imzasızdır (SmartScreen uyarısı); UAC gerektiren gerçek launcher ile "oyunu başlat" yolu otomatik sınanamaz.
- Harita bölge adları (doku) İngilizce kalır.
- Çeviri kalitesi: hata bildirimleri GitHub Issues üzerinden toplanır.
10. **`DLC\99_tr_yama` kaldırmada yer tutucu olarak kalabilir (v1.1.1).** Paket kimlikleri (`packageUniqueId` 120/121) ve klasör adı (`99_tr_yama`) SABİTTİR, değiştirilmez. Gerçek paket `isRequired=False` yazılır (bank içi `package_info.xml` + xmb `False`; oyun kayda RequiredPackage'i bank içi değerden alır). v1.1.0 paketi `isRequired=true` idi: v1.1.0 ile alınan kayıtlar 120/121'i Required listesinde taşır ve paket yoksa "required downloadable content" uyarısıyla açılmaz. Bu yüzden kaldırıcı: (a) `%USERPROFILE%\Saved Games\Lionhead Studios\Fable 3` altındaki tüm `*chaptersave.bin` dosyalarını **YALNIZCA OKUR** (kayıt dosyalarına ASLA yazılmaz; testle doğrulanır), `RequiredPackage` listesinde 120/121 arar; (b) bulursa, klasör yoksa ya da okunamazsa (güvenli taraf) `DLC\99_tr_yama`'yı SİLMEZ, metin içermeyen YER TUTUCUYA (aynı kimlikler, arşivde yalnızca `package_info.xml`, kitap yok, `isRequired=False`; oyuna hiçbir şey eklemez) çevirir ve kullanıcıya açıkça söyler; (c) bulmazsa klasörü tamamen siler. Yer tutucu dosyaları kurucuyla birlikte `{app}\placeholder\{both,us,tk}` altına kurulur (kaldırıcı oraya erişebilsin). Yeniden kurulum/onar yer tutucuyu da, v1.1.0 paketini de tam (zorunlu olmayan) pakete yükseltir. Test ortamlarında kayıt klasörü `F3_SAVESDIR` ortam değişkeniyle değiştirilir. `test_safe.ps1` T12–T16 bunu sınar (kayıtta Required var/yok, kayıt klasörü yok/bozuk, yer tutucudan ve v1.1.0'dan yükseltme).

## 11. Kayıt dosyası biçimi, paket zorunluluğu ve oyun içi test kitleri

**Kayıt konumu.** `%USERPROFILE%\Saved Games\Lionhead Studios\Fable 3\<oyuncu kimliği>\` (ör. `1122334400000000`). Kahraman başına **tek otomatik kayıt yuvası** vardır (`hero1autosave_*.bin`); "yeni yuva" yoktur, kaydetmek aynı dosyaları yeniden yazar. Dosyalar: `..._chaptersave.bin`, `..._mainsave.bin`, `..._herosave.bin`, `..._failquestmainsave.bin`, `..._checksumsave.bin`, `..._saveuid.bin`, `..._entityuid.bin`, `..._leaderboardstatssave.bin`. `mainsave/herosave/failquest*` zlib sıkıştırılmıştır (`00 00 xx xx 00 01 00 00` + `78 da ...`); `chaptersave.bin` ve `leaderboardstatssave.bin` **4 baytlık başlık + düz XML**dir.

**SaveInfo (chaptersave.bin).** XML kökü `<SaveInfo>` → `<GameVersion>` içinde `CompiledVersion` ve üç liste: `InstalledPackage`, `PremiumPackage`, `RequiredPackage`; her giriş `<PackageId type="uint">N</PackageId>`. `N`, paketin `package_info.xml` / xmb içindeki **`packageUniqueId`** değeridir. Oyun kaydı yüklerken Required listesindeki her kimliğin kurulu bir paketle eşleşmesini ister; eşleşmezse "You do not have the required downloadable content necessary to load this save game. Would you like to download this content now?" der (**"Download Now"a basılmamalı**).

| packageUniqueId | Paket | isRequired (resmî) |
|---|---|---|
| 30 | Understone (DayOne FreeForAll) | True |
| 31–40, 50, 51 | Understone kozmetik paketleri (saç, dövme, köpek vb.) | False |
| 60, 61 | Traitor's Keep (Free / Paid) | True |
| 70, 71 | Inquisitor paketleri | False |
| 98 | `99_dlc2_fixes` (resmî düzeltme paketi) | bank içinde `true` (xmb'de `false`) |
| **120, 121** | **bizim `99_tr_yama` paketleri (Understone / Traitor's Keep)** | v1.1.0: `true`; v1.1.1: `False` |

**isRequired bulgusu.** Required listesine girenler: `isRequired=True` olan paketler (30, 60, 61) ve **bank içindeki `package_info.xml`'de `isRequired=true` yazan** `99_dlc2_fixes` (98). İsteğe bağlı resmî paketler Installed'da olur ama Required'da olmaz. v1.1.0 paketimiz `dlc2_fixes`'ten kopyalandığı için bank içinde `isRequired=true` taşıyordu; kayıtlar 120/121'i Required'a yazdı ve paket kaldırılınca açılmadı. Fable3.exe'nin okuduğu xmb/package_info alanları: `contentsDescription, bankName, packageUniqueId, mountOrder, isRequired, needsRestart, installContentMask, premiumContentMask, dependencies, version, requiredGameVersion, isLanguagePack, isTitleUpdate, XContent_activation_date`; **`canIgnoreMountOrder` okunmaz**. Gerçek oyunda doğrulandı: bank içi + xmb `isRequired=False` ile alınan kayıtta Required = 98, 60, 61, 30 (120/121 yok). Ayrıca Required kayıt anında hesaplanır: "paket kuruluyken yükle → kaydet → kaldır" eski bir kaydı da yamadan bağımsız yapar.

**Kural (v1.1.1).** Paket kimlikleri 120/121 ve klasör adı `99_tr_yama` değişmez; paket `isRequired=False` yazılır; v1.1.0 kayıtları için kaldırıcı gerektiğinde yer tutucu bırakır (bkz. §3 kural 10). `dlc_package.write_collection(..., required=False, xmb_required='False')` gerçek paketi, `book=None` yer tutucuyu yazar; `build.py` `delta\placeholder\{both,us,tk}` üretir ve `manifest.json` `placeholders` (dosya SHA-256'ları) ile doğrular. **Kaydı elle düzenlemeyin**; kullanıcıya da önermeyin.

**Oyun içi test kitleri** (`tests/oyun_ici/`, ayrıntı: [tests/oyun_ici/README.md](../tests/oyun_ici/README.md)): hepsi kayıtları önce yedekler/doğrular, sonunda geri yükler, hiçbir dosyayı silmez.
- `TEST_YUKSELT.bat`: v1.1.0 → v1.1.1 yükseltmenin tamamı (yedek, v1.1.0 hazırla [GitHub Release'ten indirir + SHA-256 doğrular], yükselt, oyunda kayıt al, Required raporu, kaldır [bilgi kutusu metinleri], kayıt açıldı mı, eski kaydı geri yükle, kur+kaldır [yer tutucu], eski kayıt açıldı mı, geri yükle, v1.1.1 kurulu bırak) → `SONUC.txt` (her satırın yanında "beklenen").
- `TEST.bat` / `TEST_B.bat`: `tools\make_test_save.py` ile üretilen V0/V1/V1x/V1y/V2 paketleriyle A/B testleri (önce `python tools\dlc_bnk.py "<oyun>"`).
- `04_kayit_rapor.bat`: herhangi bir kaydın Installed/Required listesi (yalnızca okur). `sahte\sim_yukselt.ps1`: oyunsuz uçtan uca deneme (gerçek kurucular, sahte oyun/kayıt).
- Kaldırıcı bilgi kutusu metinleri ayrıca `%TEMP%\Fable3_Turkce_Yama_kaldirma_log.txt` dosyasına yazılır ("BİLGİ KUTUSU: ..."); UI Automation bu kutuların metnini bazen boş okur, günlük güvenilirdir.
- Sahte denemelerde `RegUninst` yalnızca `HKCU` kaydına bakar: gerçek (`HKLM`) kurulumun kaldırıcısı hiçbir zaman çalıştırılmaz.

**Açık not — "Kaçak Mahkûm" ödül penceresi (v1.1.1'e bırakılmadı).** Traitor's Keep oynarken "Kaçak Mahkûm" görevi bitince çıkan pencerede altın simgesi var ama miktar görünmüyor (bildirim). İnceleme: pencerenin başlığı ("Escaped Convict / Escaped Prisoner / Convict on the Run", n=1576/7392/41708) ve açıklaması (n=9914) **ana kitaptadır**, DLC kitaplarında karşılığı yoktur; 7 dilin hiçbirinde bu iki satırda miktar yer tutucusu yoktur. Miktar metinden değil oyun koduyla çizilir (`<s2><gold_img> %1</s2>` n=51528, `<gold_img> %1` n=8466, `<s1><gold_img> -%1</s1>` n=47452; üretilen kitapta orijinalle bayt bayt aynı). Metinden kaynaklanan bir eksik bulunamadı. Ayırıcı test (yapılmadı): aynı ekrana (a) `DLC\99_tr_yama` olmadan ve (b) yamasız orijinal oyunda bakmak; miktar orijinalde görünüyorsa neden araştırılmalı (font/yerleşim?), görünmüyorsa oyunun kendi davranışıdır.
