# Fable III Türkçe Yama

**Fable III (PC, Steam)** için tam Türkçe yerelleştirme: menüler, görevler, eşya metinleri ve altyazılar. **Köylü ve muhafız konuşmaları dahil tüm konuşmalarda Türkçe altyazı** gösterilir. Understone ve Traitor's Keep DLC metinleri de (kuruluysa) Türkçeleşir. Konuşmalar (ses) İngilizce kalır.
> Resmî olmayan bir fan çevirisidir; Microsoft veya Lionhead Studios ile bağlantılı değildir. Fable III, Microsoft Corporation'ın ticari markasıdır.

> **Durum: {{TAG}}** — {{N_TR}} metin çevrildi; {{N_KEEP}} metin (özel adlar, krediler, yer tutucular) bilerek değiştirilmedi. Çeviri **yapay zekâ desteğiyle** hazırlanmış ve elden geçirilmiştir; hatalar olabilir, düzeltmelere açıktır.

> **Resmî olmayan bir fan çevirisidir.** Fable III, Microsoft Corporation'ın ticari markasıdır; bu proje Microsoft veya Lionhead Studios ile bağlantılı değildir.
>
> **Bu depo (ve kurulum programı) oyuna ait hiçbir dosya ya da İngilizce oyun metni içermez.** Yama, *sizin kendi, yasal oyun kopyanızdaki* dosyalardan üretilir. Oyunun yasal bir kopyasına sahip olmanız gerekir. Tek istisna: yazı tipine eklenen 6 Türkçe harfi tarif eden ~2,5 KB'lık bir fark dosyasıdır (`font.xdelta`); kurulum programının içinde bulunur.

## Ekran görüntüleri

<!-- Görüntüleri docs/ekran/ klasörüne koyun, sonra bu HTML yorum bloğunu kaldırın (ilk ve son satır).
![Ana menü](docs/ekran/menu.png)
![Altyazı](docs/ekran/altyazi.png)
![Görev günlüğü](docs/ekran/gorev.png)
-->

*(Ekran görüntüleri yakında eklenecek.)*

## İndirme ve kurulum

1. **[Releases]({{RELEASES_URL}})** sayfasından `{{ZIP_NAME}}` dosyasını indirin.
2. **Zip'i önce bir klasöre çıkarın.** Zip'in içinden kurulum programına çift tıklarsanız program çalışmayı reddeder.
3. `{{EXE_NAME}}` dosyasını çalıştırın. Windows SmartScreen uyarı çıkarırsa: **Ek bilgi → Yine de çalıştır** (kurulum programı imzasız, açık kaynaklı bir programdır; aşağıdaki [Antivirüs](#antivirüs-uyarıları) bölümüne bakın).
4. Oyun klasörü otomatik bulunur; bulunamazsa kendiniz seçersiniz. Kur'a basın; başka seçenek yoktur.
5. Oyunda Seçenekler'den **Altyazılar** ayarını açın ve oyunu **FableLauncher.exe** ile başlatın (`Fable3.exe` tek başına "Wrong executable" hatası verir).

Ayrıntılı adımlar zip içindeki `OKUBENI.txt` dosyasındadır.

**Altyazılar:** yama köylü ve muhafız konuşmaları dahil tüm konuşmaları altyazılı yapar (uzaktaki konuşmalar oyunun mesafe sınırı yüzünden yine görünmez). Ayrı bir mod ya da seçenek yoktur.

**Yeniden kurmak / onarmak / kaldırmak:** kurulum programını yeniden çalıştırın; "Yama zaten kurulu" sayfasında *Yeniden kur / onar*, *Yamayı kaldır* ya da *Çık* seçilir. Windows "Yüklü uygulamalar" listesinden *Fable III Türkçe Yama*'yı kaldırmak da aynı işi yapar. Kaldırma, orijinal dosyaları `_TR_yedek` klasöründen geri yükler (SHA-256 ile doğrulanır), kendi DLC klasörümüzü (`DLC\99_tr_yama`) siler ve oyun klasöründeki başka hiçbir dosyaya dokunmaz.

**Önceki sürümden yükseltme:** v1.0.x ya da v1.1.0 öncesi Standart modla kurduysanız yeni kurulum programı bunu "kurulu (eski sürüm)" olarak tanır; *Yeniden kur / onar* ile güncel sürüme geçersiniz. Orijinal yedeğinize dokunulmaz.

**Steam notu:** Steam'de "Oyun dosyalarının bütünlüğünü doğrula" yamayı geri alabilir; kurulum programını yeniden çalıştırmanız yeterlidir.

## Desteklenen oyun sürümü

Yama **yalnızca** aşağıdaki orijinal (yamasız) dosyalarla çalışır; kurulum programı bu dosyaların SHA-256 değerlerini doğrular, uyuşmazsa **hiçbir şeyi değiştirmeden durur**.

{{SUPPORTED_MD}}

**Test edilmemiş sürümler** (bu dosyalara sahip olmadığımız için desteklendiğini söylemiyoruz): {{UNVERIFIED_MD}}. Bu sürümlerde dosya hash'leri farklıysa kurulum zaten durur; farklı bir sürümde çalışan biri varsa [Issues]({{ISSUES_URL}}) üzerinden hash değerlerini paylaşabilir.

Oyun dili **İngilizce (UK)** olmalıdır; yama `en-uk` dil klasörünün üzerine yazar. Diğer dil klasörlerine dokunulmaz.

## DLC desteği

{{DLC_NAMES}} DLC'lerinin metinleri oyunun ana kitabında değil, DLC arşivlerinin içindeki ayrı kitaplarda durur. Yama bu arşivlere **dokunmaz**: kurulum, bilgisayarınızda **hangi DLC'ler kuruluysa** yalnızca onların Türkçe metin paketini oyunun `DLC\99_tr_yama` klasörüne ekler (oyunun kendi DLC düzenine uygun, tüm DLC'lerden sonra yüklenen küçük bir paket). Hiç DLC kurulu değilse bu klasör eklenmez. Kaldırma bu klasörü yalnızca içinde sadece bizim bildiğimiz dosyalar varsa siler.

DLC kitaplarının SHA-256 değerleri doğrulanır; farklı bir DLC sürümünde o DLC atlanır (ana yama yine kurulur):

{{DLC_TABLE_MD}}

Çok oyunculu (co-op) oyunda eklenen paket, DLC listesinde "farklı DLC" olarak görünebilir; sorun yaşarsanız yamayı kaldırın ve bize bildirin.

## Bilinen sınırlar

{{DLC_NOTE_MD}}- **Bazı harita etiketleri resim olarak çizildiği için İngilizce kalır** (ör. bölge adları). Bunlar yazı değil doku olduğundan bu yamayla çevrilemez.
- Konuşmalar (ses) İngilizce kalır; uzaktaki konuşmalar oyunun mesafe sınırı yüzünden altyazısız kalır.
- Yama yalnızca İngilizce (UK) dil klasörünün üzerine yazar.

## Dosya bütünlüğü (SHA-256)

| Dosya | SHA-256 |
|---|---|
| `{{ZIP_NAME}}` ({{ZIP_SIZE}} bayt) | `{{ZIP_SHA}}` |
| `{{EXE_NAME}}` ({{EXE_SIZE}} bayt) | `{{EXE_SHA}}` |

Kurulumdan sonra oyun klasöründe beklenen değerler:

| Dosya | SHA-256 |
|---|---|
| `book.babel` | `{{OUT_BOOK}}` |
| `gui_normal.bft` (yamalı yazı tipi) | `{{OUT_FONT}}` |

PowerShell: `Get-FileHash -Algorithm SHA256 DOSYA`. Bu tablo `manifest.json` dosyasından betikle üretilir; sürüm sayfasındaki `SHA256SUMS.txt` ile aynı değerleri içerir.

## Antivirüs uyarıları

Kurulum programı (Inno Setup) ve içindeki `f3patch.exe` yardımcısı **açık kaynaklıdır** (`tools/installer/fable3_tr.iss`, `tools/helper/f3patch.py`). Yardımcı, Python ile yazılmış ve [Nuitka](https://nuitka.net) `--standalone` (klasör çıktısı, UPX yok) ile MSVC kullanılarak derlenmiştir. İmzasız olduğundan bazı antivirüs motorları yanlış alarm verebilir.

{{VT_SUMMARY_MD}}

**Microsoft Defender** kurulum programında `Trojan:Win32/Wacatac.B!ml` gösterebilir. Sondaki `!ml`, tespitin makine öğrenmesi tahmini olduğunu belirtir; bu dosyada **yanlış alarm** olduğunu düşünüyoruz ve Microsoft'a yanlış alarm bildirimi yapıldı (sonuç bekleniyor). Defender dosyayı engellerse: *Windows Güvenliği → Virüs ve tehdit koruması → Koruma geçmişi →* engellenen kaydı seçip *Eylemler → İzin ver*. Kaynak kodun tamamı bu depodadır; indirdiğiniz dosyanın SHA-256 değerini yukarıdaki tabloyla karşılaştırarak doğrulayabilirsiniz.

Ayrıntılar, tarama sonuçları ve kendiniz doğrulama/derleme yolları: **[docs/antivirus.md](docs/antivirus.md)**.

## Sorun bildirme

- **Çeviri hatası** (yanlış, eksik, taşan ya da tutarsız metin): [Issues]({{ISSUES_URL}}) → *Çeviri hatası* şablonu. Ekran görüntüsü ve metin çok yardımcı olur.
- **Kurulum sorunu:** [Issues]({{ISSUES_URL}}) → *Kurulum sorunu* şablonu. Şu dosyayı ekleyin: `C:\Program Files\Fable3 Turkce Yama\kurulum_log.txt` (her adım, dosya hash'leri ve hata kodları orada yazılıdır).

## Katkı

Çeviri `translations/tr_public.jsonl` içindedir: her satırda kayıt kimlikleri (`ids`), kategori, durum ve Türkçe metin (`tr`) bulunur. **İngilizce kaynak metin depoda yoktur.** Kaynağı görmek için kendi `book.babel` dosyanızdan yerel bir çalışma dosyası üretirsiniz (bu dosya İngilizce oyun metni içerir; **asla depoya eklenmez**, `.gitignore` bunu dışlar).

```
python tools/import_public.py      # yerel tr.jsonl (İngilizce kaynak + Türkçe) üretir
python tools/validate_all.py       # etiket, yer tutucu, font karakteri, sözlük denetimi
python tools/tr_tool.py apply ...  # düzeltme uygula
python tools/export_public.py      # translations/tr_public.jsonl'ı yeniden üretir (İngilizce kaynak olmadan)
```

Düzeltmeyi `tr_public.jsonl` içindeki ilgili satırın `tr` alanında yapıp *pull request* açabilirsiniz. Etiketler (`%1`, `<...>`) ve satır sonları aynen korunmalı; terimler için [`glossary.csv`](glossary.csv) ve [`docs/STYLE_VILLAGERS.md`](docs/STYLE_VILLAGERS.md) dosyalarına bakın. Dosya biçimleri: [`docs/FORMAT.md`](docs/FORMAT.md).

## Kaynaktan derleme

Gereksinimler: Python **3.14** (aşağıdaki nota bakın), `pip install nuitka`, Visual Studio Build Tools (MSVC), [Inno Setup 6](https://jrsoftware.org/isinfo.php) ve yazı tipi farkı için `xdelta3.exe` (bkz. `tools/installer/xdelta3/README.md`).

1. **Kendi orijinal dosyalarınızı** oyun klasörünüzden kopyalayın:

   ```
   <oyun>\data\language\en-uk\text\book.babel       ->  backup\book.babel.orig
   <oyun>\data\language\en-uk\fonts\gui_normal.bft  ->  backup\gui_normal.bft.orig
   ```

   (Başka bir klasörden kullanmak için `F3_ORIG_BABEL` ve `F3_ORIG_FONT` ortam değişkenlerini ayarlayın. `F3_PUBLIC=1` doğrulamayı `tr_public.jsonl` üzerinden yapar.)

2. Tek komut: `python tools/build_all.py` — doğrulama → çeviri paketi ve font farkı → `f3patch` (Nuitka) → kurucu → selftest → zip → `output\SHA256SUMS.txt` → yayın taraması. Hash'ler `manifest.json` ile karşılaştırılır; tutmazsa derleme durur.

> **Python/zlib sürümü:** `book.babel` zlib ile sıkıştırılır; çıktının baytları (dolayısıyla SHA-256) zlib sürümüne bağlıdır. Referans çıktılar Python {{PY_PIN}} (zlib-ng 1.3.1) ile üretilmiştir; farklı bir Python'da hash'ler tutmayabilir (oyun yine de çalışır, ama kurulum programı yalnızca beklenen hash'li dosyaları kabul eder).

## Yama nasıl çalışır (kısaca)

`book.babel` (UTF-16BE, zlib bloklu) yeniden paketlenir; `gui_normal.bft` Türkçe karakterler için yamalanır. Ayrıca altyazı bayrağı tüm diyalog kayıtlarında açılır. Ayrıntılar: [docs/FORMAT.md](docs/FORMAT.md).

Kitap bir fark dosyasıyla (xdelta) **dağıtılmaz**: sıkıştırma yüzünden fark dosyası yamalı dosyanın tamamını ve çevrilmemiş İngilizce satırları taşırdı. Bunun yerine paket yalnızca "kayıt kimliği → Türkçe metin" eşlemesini içerir ve `f3patch` yardımcısı kullanıcının **kendi** `book.babel` dosyasını bununla yeniden paketler.

Kurulum programı:
- oyun klasöründe yalnızca `book.babel`, `gui_normal.bft`, `_TR_yedek` ve (DLC kuruluysa) kendi `DLC\99_tr_yama` klasörüne dokunur; DLC arşivlerini yalnızca okur;
- orijinal dosyaları SHA-256 ile doğrular (eşleşmezse hiçbir şey değiştirmeden durur) ve yedekler;
- kendi klasörüne (`Program Files\Fable3 Turkce Yama`) kurulur, oyun klasörüne hiçbir şey kurmaz;
- kaldırma yalnızca `_TR_yedek` içindeki bilinen dosyaları ve `DLC\99_tr_yama` içinde yalnızca bizim bildiğimiz dosyaları siler; oyun klasöründeki başka kaldırıcıları asla çalıştırmaz.

## Emeği geçenler

- Çeviri, araçlar ve kurulum programı: **{{HOLDER}}** ([{{OWNER}}](https://github.com/{{OWNER}})), yapay zekâ desteğiyle.
- **xdelta3** (Joshua MacDonald) — font farkı için; **Nuitka** ve **Python** projeleri; **Inno Setup** (Jordan Russell, Martijn Laan).
- Fable III, Lionhead Studios / Microsoft'a aittir; bu proje resmî değildir.

## Üçüncü taraf bileşenler

- **xdelta3** 3.1.0 (Joshua MacDonald) kurulum programında yazı tipi farkı için **ayrı bir program olarak** çalıştırılır. Lisansı **GPL-2.0**'dır; metni `tools/installer/xdelta3/COPYING.txt` içindedir. Kaynak kodu: <https://github.com/jmacd/xdelta-gpl/releases/tag/v3.1.0> (`xdelta3-3.1.0.tar.gz`). xdelta3 bu depoya dahil değildir.
- **Nuitka** çalışma zamanı (Apache-2.0), **Python** çalışma zamanı (PSF), **OpenSSL** (Apache-2.0) ve Microsoft Visual C++ çalışma zamanı: `f3patch` yardımcısı ile birlikte gelir; lisans metinleri kurulumla `lisans\` klasörüne kopyalanır.
- Inno Setup, kendi lisansı altında ayrı olarak indirilir.

## Lisans

- **Araçlar ve betikler** (`tools/`): [MIT](LICENSE) — Copyright (c) 2026 {{HOLDER}}.
- **Çeviri metinleri** (`translations/`, `glossary.csv`, `docs/STYLE_VILLAGERS.md`): **CC BY-NC-SA 4.0** — bkz. [LICENSE-TRANSLATION](LICENSE-TRANSLATION) (atıf, ticari olmayan kullanım, aynı lisansla paylaşım).
- Oyunun kendisi ve metinleri üzerindeki tüm haklar Microsoft / Lionhead Studios'a aittir; bu lisanslar onları kapsamaz.

## Sorumluluk reddi

Bu yama olduğu gibi, hiçbir garanti verilmeden sunulur. Kurulum programı yalnızca belirtilen dosyalara dokunur ve orijinallerini yedekler; yine de yamayı kendi sorumluluğunuzda kullanırsınız. Oyunun yasal bir kopyasına sahip olmanız gerekir; bu proje oyunu edinmek için bir kaynak göstermez.
