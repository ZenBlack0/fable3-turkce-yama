# Oyun içi test kitleri (gerçek oyunda, gerçek kayıtla)

Bu klasör, kayıt dosyası ile DLC paketi (`DLC\99_tr_yama`) etkileşimini **gerçek oyunda** denemek içindir. Betiklerin hepsi **kayıtlarınızı önce yedekler**, sonunda yedekten geri yükler ve hiçbir dosyayı silmez (fazlalıklar `Fable 3_TEST_ARTIKLARI` altına taşınır). Arka plan: [docs/GELISTIRICI.md §11](../../docs/GELISTIRICI.md).

> Etkileşimli Windows masaüstü gerekir (oyunu açıp bakacak, E/H tuşlayacaksınız). Uyarı çıkarsa oyunda **"Download Now / Şimdi indir"e asla basmayın.**

## Ayar

Oyun klasörü: `F3_GAME` ortam değişkeni ya da [ayarlar.bat](ayarlar.bat) içindeki `GAME` satırı (varsayılan Steam yolu). Kayıt klasörü: `%USERPROFILE%\Saved Games\Lionhead Studios\Fable 3`.

## Tek tıklamalı testler

| Dosya | Ne yapar |
|---|---|
| `TEST_YUKSELT.bat` | v1.1.0 → v1.1.1 yükseltme senaryosunun tamamı: yedek → v1.1.0 hazırla (yoksa **GitHub Release'ten indirir ve SHA-256 ile doğrular**) → yükselt → oyun (DLC Türkçe mi? kayıt al) → Required raporu → kaldır (bilgi kutusu metinleri kaydedilir) → kayıt açıldı mı → eski v1.1.0 kaydını geri yükle → kur + kaldır (yer tutucu) → eski kayıt açıldı mı → geri yükle → v1.1.1 kurulu bırak → `SONUC.txt` |
| `TEST.bat` | `paketler\` içindeki test paketleriyle (V2 yer tutucu, V1 "zorunlu değil") A/B testi |
| `TEST_B.bat` | yalnızca B adımı |

`TEST_YUKSELT` yeni kurucuyu `output\Fable3_Turkce_Yama_<tag>.exe` (ya da `dist\<tag>\`) altında arar; yoksa Release'ten indirir (`_indirilen\`). `TEST.bat` için önce paketleri üretin (aşağıda).

Sonuç dosyası (`SONUC.txt`) her satırın yanına "beklenen" değeri yazar; içeriği geliştiriciye yapıştırın.

## Elle adımlar (01–06)

`01_kayit_yedek_al.bat`, `02_paket_kur.bat <V0|V1|V1x|V1y|V2>`, `03_paketi_kaldir.bat`, `04_kayit_rapor.bat` (kayıtların Installed/Required listeleri), `05_kayitlari_geri_yukle.bat`, `06_durum.bat`.

## Test paketlerini üretmek (`TEST.bat` ve 02 için)

Test paketleri (V0–V2) oyun metni içerdiği için depoda **yoktur**; kendi DLC kitaplarınızdan üretilir:

```powershell
python tools\dlc_bnk.py "<oyun klasörü>"      # backup\dlc_*_en.babel.orig  (yalnızca okur)
python tools\make_test_save.py                  # tests\oyun_ici\paketler\V0, V1, V1x, V1y, V2
```

Varyantlar (hepsi packageUniqueId 120/121, klasör `99_tr_yama`): V0 = v1.1.0 gibi (bank içi `isRequired=true`), V1 = bank içi ve xmb `False`, V1x = yalnızca bank içi `False`, V1y = yalnızca xmb `False`, V2 = yer tutucu (arşivde yalnızca `package_info.xml`, kitap yok).

## Gerçek oyun olmadan deneme (sahte klasörler)

`sahte\sim_yukselt.ps1`, `TEST_YUKSELT`'i sahte oyun ve sahte kayıt klasörüyle, **gerçek kurucularla** uçtan uca çalıştırır (oyun oturumlarını taklit eder; `F3T_SIM=1`). Önkoşul: `work\fake_dlc` (önce `python tools\installer\make_fake_dlc.py`) ve `backup\*.orig`. Betik sonunda sahte kurulumu kendisi kaldırır ve geçici klasörleri siler.
