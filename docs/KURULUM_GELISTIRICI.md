# Geliştirici ortamı: sıfırdan kurulum ve sürüm çıkarma

Amaç: yalnızca bu GitHub deposu ve kendi Fable III kurulumunuzla, başka hiçbir yerel dosyaya ihtiyaç duymadan hata düzeltip yeni sürüm çıkarabilmek. Mimari ve kurallar: [GELISTIRICI.md](GELISTIRICI.md).

Aşağıdaki adımlar Windows 11 + PowerShell içindir. Depo klasörü örnekte `Fable3-TR` diye anılır; her yere kendi yolunuzu koyun.

## 1. Gerekli araçlar ve sürümler

| Araç | Sürüm (v1.1.0 çıktıları bununla üretildi) | Not |
|---|---|---|
| Windows | 10/11 x64, Windows PowerShell 5.1 | testler için etkileşimli masaüstü gerekir |
| Git, GitHub CLI (`gh`) | güncel | klonlama ve Release için |
| **Python** | **3.14.7 (x64)** | python.org Windows yükleyicisi ya da Python Install Manager (`py install 3.14`); kullanılan: `3.14.7 (tags/v3.14.7, MSC v.1944 64 bit)` |
| **zlib** | **`1.3.1.zlib-ng`** (Python'un içindekidir) | **çok önemli**, aşağıya bakın |
| numpy, Pillow | **2.5.3**, **12.3.0** | `python -m pip install numpy==2.5.3 pillow==12.3.0` (yazı tipi yaması `font_patch.py`; build için gerekir) |
| Nuitka | **4.3** | `python -m pip install nuitka==4.3 ordered-set==4.1.0 zstandard==0.25.0` (yalnızca `f3patch.exe` için) |
| Visual Studio | **18 Community (18.10)**, iş yükü "C++ ile masaüstü geliştirme" (MSVC toolset 14.52, Windows 11 SDK 26100) | Nuitka `--msvc=latest` ile `cl.exe` kullanır. **MinGW'ye geri dönmeyin.** Farklı VS kullanıyorsanız `F3_VCVARS` ortam değişkenini `vcvars64.bat` yoluna ayarlayın |
| Inno Setup | **6.7.3** | `winget install JRSoftware.InnoSetup` (`ISCC.exe` otomatik bulunur: `%LOCALAPPDATA%\Programs\Inno Setup 6` ya da `Program Files`) |
| xdelta3 | **3.1.0 x86_64** | yalnızca yazı tipi farkı için; §3 |

Çalışma zamanı Python bağımlılıkları yalnızca numpy ve Pillow'dur (font yaması); Nuitka ve yan paketleri sadece `f3patch.exe` derlemesi içindir. `f3patch.exe`'nin kendisi yalnızca standart kütüphaneyi kullanır.

**zlib neden önemli?** `book.babel` içindeki zlib akışlarının baytları zlib sürümüne bağlıdır. Çıktı hash'leri (`manifest.json`) bu sürümle üretilmiştir; `build.py` hash tutmazsa **durur**. Kontrol:

```powershell
python -c "import sys,zlib; print(sys.version); print(zlib.ZLIB_RUNTIME_VERSION)"
# beklenen: 3.14.7 ... ve 1.3.1.zlib-ng
```

Farklı bir Python/zlib ile hash'ler değişirse bu **bir hata değil, uyarıdır**: yeni hash'leri bilinçli olarak `manifest.json`'a işlemeden (yeni sürüm olarak) yayımlamayın.

## 2. Depoyu klonla, orijinal oyun dosyalarını al

```powershell
git clone https://github.com/ZenBlack0/fable3-turkce-yama.git Fable3-TR
cd Fable3-TR
mkdir backup
```

Kendi **yamasız** Steam oyun klasörünüzden (dil: İngilizce UK) iki dosya kopyalanır (oyun klasörüne yazılmaz):

```powershell
$g = 'D:\SteamLibrary\steamapps\common\Fable 3'    # kendi yolunuz
copy "$g\data\language\en-uk\text\book.babel"       backup\book.babel.orig
copy "$g\data\language\en-uk\fonts\gui_normal.bft"  backup\gui_normal.bft.orig
Get-FileHash backup\*.orig -Algorithm SHA256
```

SHA-256 değerleri **tam olarak** şunlar olmalıdır (aksi halde dosyalar yamalı ya da farklı sürümdür; yamalıysa Steam'den "dosya bütünlüğünü doğrula" ya da kurucunun *Yamayı kaldır* seçeneği ile orijinale dönün):

- `book.babel.orig`: `1a588553b9dde08b3aa37d609f5e2ec9a9a9f2cb8f0d93bb3b93cdeca2e7afc3`
- `gui_normal.bft.orig`: `913cf1699e2fc3b612f18ee88957f44451abf8bbe88df0bf6c5d075ec6e8f0a3`

DLC İngilizce kitapları (DLC kuruluysa) oyun klasöründen **yalnızca okunarak** çıkarılır:

```powershell
python tools\dlc_bnk.py $g
# backup\dlc_understone_en.babel.orig  (SHA-256 16000712a304bd6cb8ea4175800d5490369c0995eed70b9f3133b0538c04a55b)
# backup\dlc_traitors_en.babel.orig    (SHA-256 529aaf16e1455ad55b3570c7d8cb2bc4e6301ddbf4eae81ca9ddd3769762ac11)
```

İki DLC de kurulu olmalıdır; biri eksikse o DLC'nin paketi derlenmez ve hash'i doğrulanamaz (build uyarı verir).

## 3. xdelta3'ü indir

Lisansı GPL-2.0'dır, depoya **dahil değildir** (`tools\installer\xdelta3\README.md`).

1. İndirin: <https://github.com/jmacd/xdelta-gpl/releases/download/v3.1.0/xdelta3-3.1.0-x86_64.exe.zip>
   SHA-256: `b10e0d1df3e212e5a2d37d5c088d2f72ecec760bc3c26caeca51499c3118b93a`
2. Zip içindeki `xdelta3-3.1.0-x86_64.exe` dosyasını `tools\installer\xdelta3\xdelta3.exe` adıyla kaydedin.
   SHA-256: `6855c01cf4a1662ba421e6f95370cf9afa2b3ab6c148473c63efe60d634dfb9a`

## 4. Çalışma dosyasını (tr.jsonl) yeniden üret

```powershell
python tools\import_public.py
```

Beklenen çıktı: 55.761 benzersiz metin, `DLC understone: 487 satır eklendi`, `DLC traitors: 1553 satır eklendi`, "1 satır bağlama göre bölündü", `57802 satır, çevrilmiş 49273, eşleşmeyen 0`. `translations\tr.jsonl` (İngilizce kaynak içerir, `.gitignore`'dadır, **asla depoya eklenmez**) oluşur. "eşleşmeyen > 0" ise oyun dosyanız çeviri dosyasının hazırlandığı sürümden farklıdır.

Doğrulama (isteğe bağlı): `python tools\export_public.py` çalıştırıp `git add translations\tr_public.jsonl; git status`: **değişiklik görünmemelidir** (çıktı sıralı ve bayt bayt aynıdır). Windows'ta `autocrlf` yüzünden `git status` `git add`'den önce ` M` gösterebilir; içerik aynıysa `git add` ile kaybolur.

## 5. Düzelt

1. `translations\tr.jsonl` içindeki satırın `tr` alanını düzenleyin. Her satır bir benzersiz İngilizce metindir: `{"n","src","ids":[...],"cat","tr","status",...}`.
   - Toplu iş için: `python tools\tr_tool.py stats`, `... export --cat ui --status todo --limit 300 --out work\batch.json`, `... apply work\batch_tr.json` (`tr_tool.py` başlığına bakın); bloğu bağlamıyla görmek için `python tools\show.py --from 293 --to 300`.
   - `<...>` etiketlerini, `%1 %2` yer tutucularını ve satır sonlarını koruyun; `…` yerine `...` yazın; kısa menü/buton metinlerini taşırmayın (`glossary.csv`, `docs\STYLE_VILLAGERS.md`).
   - Aynı İngilizce metnin tek kaydına özel farklı çeviri gerekirse `translations\overrides.csv` (`id,ceviri,not`).
2. `python tools\export_public.py` ile paylaşılan dosyayı yazın; `git diff translations\tr_public.jsonl` yalnızca değiştirdiğiniz satırları göstermelidir.
3. `python tools\validate_all.py` (qa + tutarlılık; `HATA: 0` / `SONUÇ: GEÇTİ`). qa uyarıları hata değildir.

## 6. Derle (build_all)

Çeviriyi değiştirdiyseniz çıktı hash'leri değişir; bu beklenen bir durumdur:

1. `python tools\build.py` (ya da doğrudan `build_all`) ilk çalıştırmada hash uyuşmazlığını yazdırır: ana kitap/font için `manifest.json` → `outputs.book` / `outputs.font`, her DLC için `dlc.<ad>.out_sha`. **Yeni değerleri bilinçli olarak** `manifest.json`'a yazın (her DLC uyuşmazlığı sırayla gösterilir; bu yüzden build birkaç kez çalışabilir).
2. Yeni sürüm için `manifest.json` içinde `version` ve `tag` değerlerini artırın (örn. `1.1.1` / `v1.1.1`). `tools\docs_src\RELEASE_NOTES.md.tpl` içine sürüm notunu ekleyin.
3. Derleyin:

```powershell
python tools\build_all.py
```

Adımlar: [1] `validate_all` → [2] `build.py --exe` (çeviri paketi, `font.xdelta`, `f3patch` Nuitka derlemesi, Inno Setup; çıktı hash'leri **doğrulanır**) → [2a] `verify_output` (üretilen kitaplarda kod/boş kayıt denetimi) → [2b] kurucu `/SELFTEST` → [3] zip → [4] `output\SHA256SUMS.txt` → [5] `scan_release` (pakette/depoda İngilizce oyun metni, oyun dosyası uzantısı taraması). Klon içinde "4b" (depo klasörü üretimi) atlanır çünkü klasör zaten bir git deposudur; `scan_release` bu durumda `dist\github_repo` yok uyarısı verir, sorun değildir.

**v1.1.0 için doğrulanmış sonuç** (depo klonundan, yalnızca orijinal oyun dosyaları ve bu araçlarla): `book.babel` `3eba8894429ac5ffb35e750ae1edba59192e131724c005c128e5700bdcb66754`, `gui_normal.bft` `a88867207aacaa772a2f36d60ba576671cd21a7e965fb19ad6f7429818690e08`, Understone paketi `9a26a9adcb749bc3e241565d321a2cd2a3d1f800729aa112d38f816eaea07e53`, Traitor's Keep paketi `86d2cd99627432cf983d0bca6dc251cca3f525b1045773dfd1e9ee42e784e996` (hepsi v1.1.0 ile birebir). `exe`/`zip` dosyalarının kendi hash'leri her derlemede farklıdır (Nuitka/Inno zaman damgaları); sürümü yayımladığınız dosya, **VirusTotal'a yüklediğiniz ve Release'e eklediğiniz dosya**dır.

Çıktılar `output\` altındadır: `Fable3_Turkce_Yama_<tag>.exe`, `.zip`, `SHA256SUMS.txt`, `scan_release.txt`.

## 7. Test

Her test sahte oyun klasörü kullanır. Sırayla çalıştırın (aynı anda iki test çalıştırmayın), etkileşimli masaüstünde:

```powershell
$exe = (Resolve-Path output\Fable3_Turkce_Yama_v1.1.0.exe).Path    # sürümünüze göre
powershell -NoProfile -ExecutionPolicy Bypass -File tools\installer\test_selftest.ps1 -Exe $exe
powershell -NoProfile -ExecutionPolicy Bypass -File tools\installer\test_safe.ps1     -Exe $exe   # T1–T11: "TÜM TESTLER GEÇTİ" beklenir
powershell -NoProfile -ExecutionPolicy Bypass -File tools\installer\test_exe.ps1      -Exe $exe
$env:F3_EXE = $exe
powershell -NoProfile -ExecutionPolicy Bypass -File tools\installer\test_detect.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\installer\test_gui.ps1       # ekran görüntüleri: work\installer_ss
```

- `test_safe.ps1`: `-Old102` (eski v1.0.2 kurucusu, T11 "eski Standart kurulumu onar") ve `-OldExe` (eski hatalı v1.0, T5) verilmezse bu iki test **atlanır** (eski kurucular depoda yoktur). Eski sürümden geçişi sınamak istiyorsanız o sürümün exe'sini bu parametrelerle verin.
- `test_safe.ps1` DLC senaryoları için `python tools\installer\make_fake_dlc.py` ile üretilen sahte DLC klasörünü (`work\fake_dlc\DLC`) kullanır; önce onu çalıştırın.
- `test_gui.ps1` bölüm D ("Yamayı kaldır") onay penceresine tuş gönderemez (bilinen düzenek sınırı); aynı akış `test_safe.ps1` T2'de sınanır.
- Gerçek oyun klasörünün test boyunca değişmediğini de görmek için `$env:F3_GAME = '<oyun klasörü>'`.
- Gerçek oyunda deneme: derlenen exe'yi oyun klasörüne kurun, oyunu `FableLauncher.exe` ile açıp değişen metinlere bakın. Deneme paketleri (`apply.bat`) kullandıysanız **mutlaka `restore.bat`** çalıştırın. Kaldırma sonrası oyun dosyaları orijinal hash'lere dönmelidir.

## 8. Yayın

```powershell
# 1) exe ve zip'i (output\) VirusTotal'a kendiniz yükleyin; sonuçları vt_report.json'a yazın
#    (biçim: tools\gen_docs.py başlığı). Dosya SHA-256'ları yerel dosyalarla eşleşmezse gen_docs bilerek durur:
#    yeni bir derleme = yeni hash = yeni VirusTotal taraması.
# 2) Belgeler (README, docs\*.md, issue şablonları, LICENSE) şablonlardan üretilir; elle düzenlemeyin
python tools\gen_docs.py --repo .
# 3) Commit + push (exe/zip/tr.jsonl/backup/work/output .gitignore'dadır; git status ile eklenecekleri gözden geçirin)
git add -A; git status
git commit -m "v1.1.1: ..."; git push origin main
# 4) Taslak Release (önce taslak!), ekler: exe, zip, SHA256SUMS.txt; notlara RELEASE_NOTES + VirusTotal bağlantıları
gh release create v1.1.1 --draft --target main --title "Fable III Türkçe Yama v1.1.1" --notes-file notlar.md `
   output\Fable3_Turkce_Yama_v1.1.1.exe output\Fable3_Turkce_Yama_v1.1.1.zip output\SHA256SUMS.txt
# 5) Taslaktaki zip'i indirip SHA-256'sını output\SHA256SUMS.txt ile karşılaştırın, sonra yayımlayın
gh release edit v1.1.1 --draft=false --latest
```

Kurallar: yayımlanmış bir sürümün etiketine ve eklerine **dokunulmaz** (hata varsa yeni sürüm); VirusTotal sonuçları olmadan yayımlamayın; kişisel yol/e-posta/oyun metni içeren dosya (`tr.jsonl`, `backup\`, `work\`) depoya girmemelidir (`scan_release` bunu denetler).

## 9. Sorun giderme

- `HATA: Çıktı hash'leri beklenenle uyuşmuyor`: Python/zlib sürümü ya da çeviri değişti (§1, §6).
- `MSVC bulunamadi`: Visual Studio C++ iş yükü yok; `F3_VCVARS` ortam değişkenini ayarlayın.
- `Inno Setup bulunamadı`: `winget install JRSoftware.InnoSetup`.
- `DLC kaynağı manifest ile uyuşmuyor`: DLC'niz farklı bir sürümdür; o DLC desteklenmez (kurucu o DLC'yi atlar).
- Derleme sırasında exe kilitli ("output file appears to be in use"): önceki test kurucusu hâlâ çalışıyordur; kapatın.
