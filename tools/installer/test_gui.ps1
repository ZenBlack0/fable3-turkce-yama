# Sahte oyun klasöründe sihirbazı NORMAL (sessiz değil) açıp her sayfanın ekran görüntüsünü alır.
# Çıktı: work\installer_ss\<senaryo>_<adım>.png   (gerçek oyuna dokunmaz)
param([string]$Only = '')
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$ver = (Get-Content "$root\manifest.json" -Raw -Encoding UTF8 | ConvertFrom-Json).tag
$Exe = if ($env:F3_EXE) { $env:F3_EXE } else { "$root\dist\$ver\Fable3_Turkce_Yama_$ver.exe" }
$ss = "$root\work\installer_ss"; New-Item -ItemType Directory -Force $ss | Out-Null
$base = Join-Path $env:TEMP 'f3_gui_test'
$g = "$base\Oyun Klasörü ğüşİ\Fable 3"
$orig = "$root\backup"; $kit = "$root\work\delta_build"
$B = "$g\data\language\en-uk\text\book.babel"; $F = "$g\data\language\en-uk\fonts\gui_normal.bft"
$sh = New-Object -ComObject WScript.Shell
function Sh10($p) { if (Test-Path $p) { (Get-FileHash $p).Hash.Substring(0, 10).ToLower() } else { '-' } }
function Reset-Game {
    Kill-All
    Start-Sleep 1
    if (Test-Path $base) { Remove-Item $base -Recurse -Force }
    New-Item -ItemType Directory -Force "$g\data\language\en-uk\text", "$g\data\language\en-uk\fonts" | Out-Null
    Copy-Item "$orig\book.babel.orig" $B; Copy-Item "$orig\gui_normal.bft.orig" $F
}
function Shot($name) {
    $r = New-Object Drawing.Rectangle 480, 160, 960, 700
    $bmp = New-Object Drawing.Bitmap $r.Width, $r.Height
    $gr = [Drawing.Graphics]::FromImage($bmp); $gr.CopyFromScreen($r.Location, [Drawing.Point]::Empty, $r.Size)
    $bmp.Save("$ss\$name.png"); $gr.Dispose(); $bmp.Dispose(); "  [ss] $name"
}
function Keys($k, $wait = 2) { $null = $sh.AppActivate('Kurulum yardımcısı'); Start-Sleep -Milliseconds 500; Start-Sleep -Milliseconds 400; $sh.SendKeys($k); Start-Sleep $wait }
function Start-Setup($extra = '') {
    $script:p = Start-Process $Exe -ArgumentList "/CURRENTUSER /DIR=`"$base\_app`" /GAME=`"$g`" $extra" -PassThru
    Start-Sleep 5
}
function Kill-All { Get-Process | ? { $_.ProcessName -like 'Fable3_Turkce*' -or $_.ProcessName -like '*unins*' -or $_.ProcessName -in 'Fable3','FableLauncher' -or ($_.Path -like '*\f3_gui_test\*') } | Stop-Process -Force -ErrorAction SilentlyContinue }
function Close-Setup { Kill-All }
function St {
    $bn = Sh10 $B; $fn = Sh10 $F
    $man = Get-Content "$root\manifest.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    $bk = $man.outputs.book.Substring(0, 10); $fk = $man.outputs.font.Substring(0, 10)
    $lb = switch ($bn) { '1a588553b9' { 'ORIJINAL' } 'cb177f4f59' { 'ESKI-STANDART' } '5dd31cf1c2' { 'ESKI-TAM' } $bk { 'GUNCEL' } default { "BILINMEYEN($bn)" } }
    $lf = switch ($fn) { '913cf1699e' { 'orijinal' } '0ba43fe00c' { 'eski-yama' } $fk { 'guncel' } default { "bilinmeyen($fn)" } }
    "  durum: book=$lb font=$lf | yedek book=$(Sh10 "$g\_TR_yedek\book.babel") font=$(Sh10 "$g\_TR_yedek\gui_normal.bft") | _TR_yedek var=$(Test-Path "$g\_TR_yedek")"
}
function Run($id) { return ($Only -eq '' -or $Only -eq $id) }
function Hdr($t) { "`n=== $t" }

# ---- A: temiz kurulum (orijinal dosyalar), Tam altyazı, uyarı HİÇ çıkmamalı
if (Run 'A') {
    Hdr 'A temiz kurulum'; Reset-Game; Copy-Item "$env:SystemRoot\System32\cmd.exe" "$g\FableLauncher.exe"
    Start-Setup; Shot 'A1_karsilama'
    Keys '{ENTER}'; Shot 'A2_klasor'
    Keys '{ENTER}'; Shot 'A3_hazir'
    Keys '{ENTER}' 6; Shot 'A4_bitti_oyunu_baslat_kutulu'
    Keys '{ENTER}' 4
    $l = Get-Process FableLauncher -ErrorAction SilentlyContinue
    "  FableLauncher.exe baslatildi mi: $([bool]$l) $($l.Path)"
    Get-Process FableLauncher -ErrorAction SilentlyContinue | Stop-Process -Force
    St
}
# ---- B: yama kurulu -> "Yama zaten kurulu" sayfası; modu değiştir
if (Run 'B') {
    Hdr 'B kurulu: yeniden kur / onar'
    Start-Setup; Shot 'B1_karsilama'
    Keys '{ENTER}'; Shot 'B2_yama_zaten_kurulu'
    Keys '{ENTER}'; Shot 'B3_hazir_(klasor atlandi)'
    Keys '{ENTER}' 6; Shot 'B4_bitti'
    Keys '{ENTER}' 4; Get-Process FableLauncher -ErrorAction SilentlyContinue | Stop-Process -Force
    St
}
# ---- C: yama kurulu -> Çık
if (Run 'C') {
    Hdr 'C kurulu: cik'
    Start-Setup; Keys '{ENTER}'; Keys '{DOWN}{DOWN}' 1; Shot 'C1_cik_secili'
    Keys '{ENTER}' 3; Shot 'C2_cikis_sonrasi'
    "  kurulum penceresi kapandi mi: $(-not (Get-Process | ? { $_.ProcessName -like 'Fable3_Turkce*' }))"
    Close-Setup; St
}
# ---- D: yama kurulu -> Yamayı kaldır (kaldırıcı arayüzü)
if (Run 'D') {
    Hdr 'D kurulu: yamayi kaldir'
    Start-Setup; Keys '{ENTER}'; Keys '{DOWN}' 1; Shot 'D1_kaldir_secili'
    Keys '{ENTER}' 3; Shot 'D2_kaldirici_onay'
    Keys '{LEFT}{ENTER}' 6; Shot 'D3_kaldirma_sonucu'
    Keys '{ENTER}' 3; Shot 'D4_sonrasi'
    Close-Setup; Get-Process unins000 -ErrorAction SilentlyContinue | Stop-Process -Force
    St
}
# ---- E: kullanıcının gerçek durumu: book orijinal, font yamalı, _TR_yedek'te font yok, eski .bat yedeği en-uk\_TR_yedek'te
if (Run 'E') {
    Hdr 'E karisik durum (book orijinal, font yamali, eski bat yedegi var)'
    Reset-Game
    Copy-Item "$kit\gui_normal.bft" $F
    New-Item -ItemType Directory -Force "$g\_TR_yedek", "$g\data\language\en-uk\_TR_yedek" | Out-Null
    Copy-Item "$orig\book.babel.orig" "$g\_TR_yedek\book.babel"
    Copy-Item "$orig\book.babel.orig" "$g\data\language\en-uk\_TR_yedek\book.babel"
    Copy-Item "$orig\gui_normal.bft.orig" "$g\data\language\en-uk\_TR_yedek\gui_normal.bft"
    St
    Start-Setup; Keys '{ENTER}'; Shot 'E1_kismi_kurulu'
    Keys '{ENTER}'; Shot 'E2_hazir'
    Keys '{ENTER}' 6; Shot 'E3_bitti_(uyari_cikmamali)'
    Keys '{ENTER}' 3
    St; Get-Content "$g\_TR_yedek\kurulum_log.txt" | Select-Object -Last 12
}
# ---- F: orijinal yedek hiçbir yerde yok + bilinmeyen dosya -> uyarı (dosya adı + durum), Hayır
if (Run 'F') {
    Hdr 'F bilinmeyen dosya, yedek yok: uyari'
    Reset-Game; [IO.File]::WriteAllBytes($B, [byte[]](9, 9, 9)); Copy-Item $kit\gui_normal.bft $F
    Start-Setup; Keys '{ENTER}'; Keys '{ENTER}' 1; Shot 'F1_hazir'
    Keys '{ENTER}' 4; Shot 'F2_desteklenmeyen_surum'
    Keys '{ENTER}' 3; Shot 'F3_hayir_sonrasi'
    Close-Setup; St
}
# ---- G: yanlış klasör (DIR bozuk -> klasör sayfası, İleri)
if (Run 'G') {
    Hdr 'G yanlis klasor'
    Reset-Game; $bad = "$base\bos klasor"; New-Item -ItemType Directory -Force $bad | Out-Null
    $script:p = Start-Process $Exe -ArgumentList "/CURRENTUSER /DIR=`"$base\_app`" /GAME=`"$bad`"" -PassThru; Start-Sleep 5
    Keys '{ENTER}' 1; Shot 'G1_klasor_sayfasi'
    Keys '{ENTER}' 2; Shot 'G2_bu_bir_fable_klasoru_degil'
    Keys '{ENTER}' 1; Close-Setup
}
# ---- H: oyun açıkken (FableLauncher.exe çalışıyor)
if (Run 'H') {
    Hdr 'H oyun acik'
    Reset-Game; Copy-Item "$env:SystemRoot\System32\PING.EXE" "$base\FableLauncher.exe"
    $gp = Start-Process "$base\FableLauncher.exe" -ArgumentList '-t 127.0.0.1' -WindowStyle Hidden -PassThru
    Start-Sleep 1
    Start-Setup; Keys '{ENTER}'; Keys '{ENTER}' 1; Keys '{ENTER}' 3; Shot 'H1_oyun_acik_uyarisi'
    Keys '{ENTER}' 2; Shot 'H2_sonrasi'
    $gp | Stop-Process -Force; Close-Setup; St
}
# ---- I: kullanıcı ÜST klasörü seçti -> alt klasörde oyun bulunmalı
if (Run 'I') {
    Hdr 'I ust klasor secildi'
    Reset-Game; $parent = Split-Path $g -Parent
    $script:p = Start-Process $Exe -ArgumentList "/CURRENTUSER /DIR=`"$base\_app`" /GAME=`"$parent`"" -PassThru; Start-Sleep 5
    Keys '{ENTER}' 1; Shot 'I1_klasor_sayfasi_ust_klasor'
    Keys '{ENTER}' 2; Shot 'I2_oyun_alt_klasorde_bulundu'
    Keys '{ENTER}' 2; Shot 'I3_hazir_sayfasi'
    Close-Setup
}
# ---- J: oyun var ama en-uk yok (yalnızca başka diller)
if (Run 'J') {
    Hdr 'J en-uk yok, baska diller var'
    Reset-Game; $j = "$base\Baska Dil\Fable 3"
    foreach ($d in 'data\language\de-de\text', 'data\language\fr-fr\text', 'data\language\it-it\text') { New-Item -ItemType Directory -Force "$j\$d" | Out-Null }
    Copy-Item "$env:SystemRoot\System32\PING.EXE" "$j\Fable3.exe"
    $script:p = Start-Process $Exe -ArgumentList "/CURRENTUSER /DIR=`"$base\_app`" /GAME=`"$j`"" -PassThru; Start-Sleep 5
    Keys '{ENTER}'; Keys '{ENTER}' 2; Shot 'J1_en-uk_yok_diller_listeli'
    Keys '{ENTER}' 1; Close-Setup
}
# ---- K: en-uk var ama book.babel eksik
if (Run 'K') {
    Hdr 'K book.babel eksik'
    Reset-Game; $k = "$base\Eksik\Fable 3"
    New-Item -ItemType Directory -Force "$k\data\language\en-uk\fonts", "$k\data\language\en-uk\text", "$k\data\language\de-de\text" | Out-Null
    Copy-Item "$orig\gui_normal.bft.orig" "$k\data\language\en-uk\fonts\gui_normal.bft"
    $script:p = Start-Process $Exe -ArgumentList "/CURRENTUSER /DIR=`"$base\_app`" /GAME=`"$k`"" -PassThru; Start-Sleep 5
    Keys '{ENTER}'; Keys '{ENTER}' 2; Shot 'K1_book_eksik'
    Keys '{ENTER}' 1; Close-Setup
}
Reset-Game | Out-Null
