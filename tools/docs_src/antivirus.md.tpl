# Antivirüs yanlış alarmları

Kurulum programı **Inno Setup** ile hazırlanmıştır; çeviriyi sizin `book.babel` dosyanıza uygulayan `f3patch.exe` yardımcısı Python ile yazılmış ve [Nuitka](https://nuitka.net) ile derlenmiştir. İmzasız (kod imzalama sertifikasız) programlar, içlerinde bir fark yaması aracı (`xdelta3.exe`) ve bir Python çalışma zamanı bulunduğunda, bazı antivirüs motorlarının **statik makine öğrenmesi** (ML/AI) sezgilerinde yanlış pozitif verebilir.

Kurulum programının yaptığı işler (kaynak kodu bu depoda: `tools/installer/fable3_tr.iss`, `tools/helper/f3patch.py`):
- oyun klasöründe yalnızca `book.babel`, `gui_normal.bft`, `_TR_yedek` ve DLC kuruluysa kendi `DLC\99_tr_yama` klasörüne dokunur; DLC arşivlerini yalnızca OKUR;
- orijinal dosyaları SHA-256 ile doğrular, yedekler, ürettiği dosyaları SHA-256 ile doğrular;
- `f3patch.exe` ile çeviri paketini sizin `book.babel` dosyanıza uygular; `xdelta3.exe` ile yalnızca yazı tipi farkını (~2,5 KB) uygular;
- yardımcı program (`f3patch.exe`) ağ modüllerini (`socket`, `ssl`) içermez ve internete bağlanmaz.

## Release dosyalarının VirusTotal raporları

{{VT_TABLE_MD}}

{{VT_NOTE_MD}}

## Microsoft Defender uyarısı hakkında

**v1.1.0** kurulum programında Microsoft Defender `Trojan:Win32/Wacatac.B!ml` adlı bir tespit verebiliyordu. Adın sonundaki **`!ml`**, bu tespitin dosyanın içeriğine bakılarak değil, **makine öğrenmesi (ML) tahminiyle** verildiğini gösterir; imzasız, yeni ve paketlenmiş (Python çalışma zamanı içeren) programlarda sık görülür. Bu bir **yanlış alarmdı** ve Microsoft'a yanlış alarm (false positive) bildirimi yapılmıştı.

**v1.1.1'de bu Defender tespiti yok** (VirusTotal'da Microsoft v1.1.1 için tespit vermiyor; sonuçlar yukarıdaki tabloda). v1.1.0 kullanıyorsanız v1.1.1'e yükseltmeniz önerilir.

Defender dosyayı engeller ya da karantinaya alırsa:

1. **Windows Güvenliği → Virüs ve tehdit koruması → Koruma geçmişi** bölümünü açın.
2. Engellenen `{{EXE_NAME}}` kaydını bulun, **Eylemler → İzin ver** (gerekirse **Geri yükle**) seçin.
3. Dosyayı yeniden çalıştırın.

Önce dosyaya güvenmek istiyorsanız:

- Aşağıdaki "Kendiniz doğrulama" bölümüyle SHA-256 değerini bu sayfadaki değerle karşılaştırın (`exe`: `{{EXE_SHA}}`).
- Kaynak kodu bu depodadır (`tools/installer/fable3_tr.iss`, `tools/helper/f3patch.py`); okuyabilir ya da kendiniz derleyebilirsiniz.
- Dilerseniz VirusTotal'a kendiniz yükleyip sonucu görebilirsiniz.

Hiç şüpheniz varsa kurulum programını çalıştırmayın; yama gerekli değildir, oyununuz yamasız da çalışır.

## Karşılaştırma notu (Fable II projesinden)

Aynı yazarın [Fable II Türkçe Yama](https://github.com/ZenBlack0/fable2-turkce-yama) projesinde, benzer bir Python programı farklı yöntemlerle paketlenip VirusTotal'da denendi: PyInstaller `--onefile` 6/70, Nuitka `--onefile` 9/71, **Nuitka `--standalone` (klasör çıktısı) 0/71**. Bu proje de bu sonuca dayanarak PyInstaller yerine Nuitka `--standalone` kullanır (`--onefile` ve UPX kullanılmaz). **Bu karşılaştırma Fable II içindir; Fable III dosyalarının sonuçları yukarıdaki tablodadır.**

## Kendiniz doğrulama

- Zip içindeki `SHA256SUMS.txt` ve sürüm sayfasındaki `SHA256SUMS.txt` ile dosya özetlerini karşılaştırın (`Get-FileHash -Algorithm SHA256 DOSYA`).
- Kaynak kodundan kendiniz derleyin: bu depoyu indirip `python tools/build_all.py` çalıştırın (gereksinimler için ana sayfadaki "Kaynaktan derleme" bölümüne bakın). Ürettiğiniz oyun dosyalarının hash'leri `manifest.json` ile aynı olmalıdır.
- Kurulum programı oyun klasörünüze kaldırıcı veya başka bir program kurmaz; `kurulum_log.txt` dosyasında yapılan her adım yazılıdır.
- Yanlış alarmı ilgili antivirüs sağlayıcısına "false positive" olarak bildirebilirsiniz.
