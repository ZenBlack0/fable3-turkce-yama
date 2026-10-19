# Sürüm notları

## v1.1.0

- Kurulum programı artık zip içinde dağıtılır: `Fable3_Turkce_Yama_v1.1.0.zip` (kurulum programı + `OKUBENI.txt` + `SHA256SUMS.txt`).
- `f3patch.exe` yardımcısı PyInstaller yerine **Nuitka `--standalone` + MSVC** ile derlenir (`--onefile` ve UPX yok); antivirüs yanlış alarm riskini azaltmak için. Sonuçlar: [docs/antivirus.md](antivirus.md).
- Kuruluma kendi kendini sınama modu eklendi (`/SELFTEST`): gömülü paketleri, `xdelta3`'ü ve `f3patch`'i denetler; orijinal dosyalar verilirse beklenen SHA-256 değerlerini doğrular.
- Kurulum programı zip'in içinden çalıştırılırsa "Lütfen zip dosyasını önce bir klasöre çıkarın" uyarısı verir.
- Yayın düzeni: tek kaynak `manifest.json` (sürüm, desteklenen orijinal hash'ler, sonuç hash'leri); `validate_all.py`, `build_all.py` ve `scan_release.py` ile tek komutla derleme ve tarama.
- **Standart mod kaldırıldı:** yama artık yalnızca tam altyazıyı (köylü ve muhafız konuşmaları dahil tüm konuşmalarda Türkçe altyazı) kurar; mod seçim sayfası ve "Modu değiştir" yoktur. Önceki sürümle Standart (ya da eski Tam) kurmuş biri yeni kurulum programını çalıştırınca "kurulu (eski sürüm)" olarak tanınır ve *Yeniden kur / onar* ile güncel sürüme geçer; orijinal yedeğe dokunulmaz.
- **DLC metinleri Türkçe:** Understone ve Traitors Keep DLC'lerinin metinleri (örn. Bay Boyle'un perili fabrika görevi) çevrildi. DLC arşivlerine dokunulmaz; kuruluysa yalnızca o DLC'nin Türkçe metin paketi `DLC\99_tr_yama` klasörüne eklenir, kaldırma bu klasörü yalnızca içi bizim dosyalarımızdan oluşuyorsa siler.
- **Yazı tipi:** `ğ`/`Ğ` harflerinin üzerindeki breve işareti kalınlaştırıldı ve düzeltildi (eskisi ters ve neredeyse görünmezdi).
- **Bağlam düzeltmeleri:** *Vault* eylemi "Atla" / menü kategorisi "Kasa", *Zoom* "Yakınlaştır", *Pan* "Kaydır", *Rename* "Yeniden Adlandır", *Kick* "Oyundan At", *Pause Menu* "Duraklatma Menüsü"; savunma terimi her yerde "bloklamak/blok".
- Bilinen sınır: bazı harita etiketleri (bölge adları) resim olarak çizildiği için İngilizce kalır.

## v1.0.2

- Kurulum programı oyun dosyası ya da oyun metni içermez: yalnızca "kayıt kimliği → Türkçe" çeviri paketi, kendi `book.babel` dosyanızdan yamalı kitabı üreten yardımcı program ve yazı tipi farkı taşır.
- Kurulum klasörü oyun klasöründen ayrıldı; oyun klasöründe yalnızca iki dosya + `_TR_yedek` değişir.
- "Yama zaten kurulu" menüsü (yeniden kur / mod değiştir / kaldır), oyun klasörünü otomatik bulma (Steam, kurulum kayıtları, sürücü taraması), FableLauncher ile oyunu başlatma.
- Güvenlik: kaldırma yalnızca `_TR_yedek` içindeki bilinen dosyaları siler; oyun klasöründeki yabancı kaldırıcılar asla çalıştırılmaz.

## v1.0

- İlk tam sürüm: tüm metinler Türkçe, Standart ve Tam altyazı modları.
