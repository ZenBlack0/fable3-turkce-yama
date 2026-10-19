# Sahte oyun klasöründe kurulum .exe testleri (gerçek oyuna dokunmaz)
param([string]$Exe = '')
$base = Join-Path $env:TEMP 'f3_exe_test'
$g = "$base\Oyun Klasörü ğüşİ\Fable 3"
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$ver = (Get-Content "$root\manifest.json" -Raw -Encoding UTF8 | ConvertFrom-Json).tag
if (-not $Exe) { $Exe = "$root\dist\$ver\Fable3_Turkce_Yama_$ver.exe" }
$orig = "$root\backup"
$kit = "$root\work\delta_build"
$B = "$g\data\language\en-uk\text\book.babel"; $F = "$g\data\language\en-uk\fonts\gui_normal.bft"
function Sh($p) { if (Test-Path $p) { (Get-FileHash $p).Hash.Substring(0, 10).ToLower() } else { '-' } }
$tam = Sh "$kit\book.babel"; $fnt = Sh "$kit\gui_normal.bft"   # tek sonuç: tam altyazı
$ob = Sh "$orig\book.babel.orig"; $of = Sh "$orig\gui_normal.bft.orig"
function Reset-Game {
    if (Test-Path $base) { Get-Process Fable3 -ErrorAction SilentlyContinue | Stop-Process -Force; Remove-Item $base -Recurse -Force }
    New-Item -ItemType Directory -Force "$g\data\language\en-uk\text", "$g\data\language\en-uk\fonts" | Out-Null
    Copy-Item "$orig\book.babel.orig" $B; Copy-Item "$orig\gui_normal.bft.orig" $F
}
function Inst($mode, $extra = '', $dir = $g) {
    $a = "/VERYSILENT /SUPPRESSMSGBOXES /CURRENTUSER /NORESTART /DIR=`"$base\_app`" /GAME=`"$dir`" $extra"
    (Start-Process $Exe -ArgumentList $a -Wait -PassThru).ExitCode
}
function Unins { $u = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{7C1D3B52-5E0A-4B53-9A6E-F3A1B7D2C411}_is1' -ErrorAction SilentlyContinue).UninstallString -replace '"',''; if ($u -and (Test-Path $u)) { $r=(Start-Process $u -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART' -Wait -PassThru).ExitCode; Start-Sleep 4; $r } else { 'unins yok' } }
function St { $bn = Sh $B; $label = switch ($bn) { $ob { 'ORIJINAL' } $tam { 'GUNCEL' } default { 'BILINMEYEN' } }
    $fn = Sh $F; $fl = switch ($fn) { $of { 'orijinal' } $fnt { 'yama' } default { 'bilinmeyen' } }
    "book=$label font=$fl | yedek: book=$(Sh "$g\_TR_yedek\book.babel") font=$(Sh "$g\_TR_yedek\gui_normal.bft")" }
function T($t) { "`n=== $t" }

T '0 baslangic'; Reset-Game; St
T '1 temiz kurulum'; "exit=$(Inst 2)"; St
"dosyalar: $((Get-ChildItem "$g\_TR_yedek" | % Name) -join ', ')"
"kayit (Uygulamalar ve Ozellikler): $((Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall' | ? { $_.PSChildName -like '*7C1D3B52*' } | % { $_.GetValue('DisplayName') + ' ' + $_.GetValue('DisplayVersion') }))"
T '2 yeniden kurulum - yedek korunmali'; "exit=$(Inst 1)"; St
T '2b yeniden kurulum'; "exit=$(Inst 2)"; St
T '3 oyun acikken kurulum (Fable3.exe calisiyor)'
Copy-Item "$env:SystemRoot\System32\PING.EXE" "$base\Fable3.exe"; $p = Start-Process "$base\Fable3.exe" -ArgumentList '-t 127.0.0.1' -WindowStyle Hidden -PassThru
Start-Sleep 1; "exit=$(Inst 1) (0 olmamali)"; St
$p | Stop-Process -Force
T '3b oyun kapaninca kurulum devam'; "exit=$(Inst 1)"; St
T '4 yanlis klasor'; $bad = "$base\bos klasor"; New-Item -ItemType Directory -Force $bad | Out-Null
"exit=$(Inst 2 '' $bad) (0 olmamali)"; "bos klasore bir sey yazildi mi: $((Get-ChildItem $bad -Recurse | Measure-Object).Count) dosya"
T '5 kaldirma (gecerli yedek)'; "exit=$(Unins)"; St; "_TR_yedek var mi: $(Test-Path "$g\_TR_yedek")"
T '6 bozuk yedek, oyun yamali: uyari + iptal (varsayilan Hayir)'
Reset-Game; Inst 2 | Out-Null
[IO.File]::WriteAllBytes("$g\_TR_yedek\book.babel", [byte[]](1, 2, 3))
"exit=$(Inst 1) (0 olmamali)"; St
"6b /FORCE=1 ile devam"; "exit=$(Inst 1 '/FORCE=1')"; St
T '7 bozuk yedekle kaldirma: geri yukleme yapmamali, yedek silinmemeli'
"exit=$(Unins)"; St; "_TR_yedek var mi: $(Test-Path "$g\_TR_yedek")"
T '8 bilinmeyen oyun dosyalari (ne orijinal ne bizim)'
Reset-Game; [IO.File]::WriteAllBytes($B, [byte[]](9, 9, 9)); "exit=$(Inst 2) (0 olmamali)"; St
"8b /FORCE=1"; "exit=$(Inst 2 '/FORCE=1')"; St; "supheli: $((Get-ChildItem "$g\_TR_yedek\supheli" -ErrorAction SilentlyContinue | % Name) -join ', ')"
T '9 orijinal + eski gecersiz yedek -> yedek yenilenmeli'
Reset-Game; New-Item -ItemType Directory -Force "$g\_TR_yedek" | Out-Null; [IO.File]::WriteAllBytes("$g\_TR_yedek\book.babel", [byte[]](5, 5)); Copy-Item $F "$g\_TR_yedek\gui_normal.bft"
"exit=$(Inst 2)"; St; "supheli: $((Get-ChildItem "$g\_TR_yedek\supheli" -ErrorAction SilentlyContinue | % Name) -join ', ')"
T '10 kaldirma (yenilenen yedek)'; "exit=$(Unins)"; St; "_TR_yedek var mi: $(Test-Path "$g\_TR_yedek")"
Write-Host "`nOzet hash: orijinal=$ob tam=$tam font=$fnt"
