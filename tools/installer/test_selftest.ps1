# Kurucunun /SELFTEST modu ve "zip içinden çalıştırma" korumasını sınar. Oyun klasörüne ve kayıt defterine DOKUNMAZ.
param([string]$Exe = '',
      [string]$Orig = '')
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$ver = (Get-Content "$root\manifest.json" -Raw -Encoding UTF8 | ConvertFrom-Json).tag
if (-not $Exe) { $Exe = "$root\output\Fable3_Turkce_Yama_$ver.exe" }
if (-not $Orig) { $Orig = "$root\backup" }
$ErrorActionPreference = 'Stop'
$t = Join-Path $env:TEMP 'f3_selftest'
if (Test-Path $t) { Remove-Item $t -Recurse -Force }
New-Item -ItemType Directory $t | Out-Null
Copy-Item (Join-Path $Orig 'book.babel.orig') "$t\book.babel"
Copy-Item (Join-Path $Orig 'gui_normal.bft.orig') "$t\gui_normal.bft"
New-Item -ItemType Directory "$t\bad" | Out-Null
[IO.File]::WriteAllBytes("$t\bad\book.babel", [byte[]](1..200))
[IO.File]::WriteAllBytes("$t\bad\gui_normal.bft", [byte[]](1..200))
$fail = 0
function Check($name, $ok) { if ($ok) { "  GEÇTİ  $name" } else { "  KALDI  $name"; $script:fail++ } }
function RunST($log, $extra) {
    $a = @("/SELFTEST=$log", '/VERYSILENT') + $extra
    $p = Start-Process -FilePath $Exe -ArgumentList $a -Wait -PassThru
    if (Test-Path $log) { Get-Content $log -Encoding Default } else { @() }
}
"1) Orijinal dosyalarla tam sınama"
$r = RunST "$t\a.txt" @("/ORIGDIR=$t")
$r | % { "    $_" }
Check 'SONUC: GECTI' ($r -contains 'SONUC: GECTI')
Check 'book.babel (tam altyazı) + font üretildi' (($r | ? { $_ -like 'TAMAM  book.babel*' -or $_ -like 'TAMAM  gui_normal*' }).Count -eq 2)
"1b) DLC adımı (sahte DLC klasörü varsa)"
$fk = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) 'work\fake_dlc\DLC'
if (Test-Path $fk) {
    New-Item -ItemType Directory "$t\dlcgame" | Out-Null
    Copy-Item $fk "$t\dlcgame\DLC" -Recurse
    Copy-Item "$t\book.babel" "$t\dlcgame\book.babel"; Copy-Item "$t\gui_normal.bft" "$t\dlcgame\gui_normal.bft"
    New-Item -ItemType Directory "$t\dlcgame\o" | Out-Null; Move-Item "$t\dlcgame\DLC" "$t\dlcgame\o\DLC"
    Copy-Item "$t\book.babel" "$t\dlcgame\o\book.babel"; Copy-Item "$t\gui_normal.bft" "$t\dlcgame\o\gui_normal.bft"
    $r = RunST "$t\a2.txt" @("/ORIGDIR=$t\dlcgame\o")
    Check 'DLC raporu üretildi' ($r | ? { $_ -like 'TAMAM  f3patch dlc*' })
} else { "  ATLANDI (work\fake_dlc yok)" }
"2) Orijinal verilmeden (yalnızca bileşen sınaması)"
$r = RunST "$t\b.txt" @()
Check 'SONUC: GECTI + uygulama atlandı notu' (($r -contains 'SONUC: GECTI') -and ($r | ? { $_ -like 'ATLANDI*' }))
"3) Yanlış (orijinal olmayan) dosyalarla: BAŞARISIZ olmalı"
$r = RunST "$t\c.txt" @("/ORIGDIR=$t\bad")
Check 'SONUC: BASARISIZ' ($r -contains 'SONUC: BASARISIZ')
"4) Zip içinden çalıştırma: reddedilmeli, hiçbir şey kurmamalı"
New-Item -ItemType Directory "$t\paket.zip" | Out-Null
Copy-Item $Exe "$t\paket.zip\k.exe"
$p = Start-Process "$t\paket.zip\k.exe" -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', "/DIR=$t\hedef" -Wait -PassThru
Check 'çıkış kodu != 0 ve hedef klasör oluşmadı' (($p.ExitCode -ne 0) -and -not (Test-Path "$t\hedef"))
"5) Normal klasörden SELFTEST yine çalışır (zip kuralı yanlış alarm vermez)"
New-Item -ItemType Directory "$t\normal" | Out-Null
Copy-Item $Exe "$t\normal\k.exe"
$Exe2 = "$t\normal\k.exe"
$p = Start-Process $Exe2 -ArgumentList "/SELFTEST=$t\d.txt", '/VERYSILENT' -Wait -PassThru
Check 'SONUC: GECTI' ((Get-Content "$t\d.txt" -Encoding Default) -contains 'SONUC: GECTI')
Remove-Item $t -Recurse -Force
if ($fail) { "SONUÇ: $fail test KALDI"; exit 1 } else { 'SONUÇ: tüm selftest senaryoları geçti'; exit 0 }
