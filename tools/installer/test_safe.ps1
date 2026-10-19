# Güvenlik testi: kurulum/kaldırma sonrası oyun klasöründe YALNIZCA book.babel, gui_normal.bft ve _TR_yedek farklı olabilir.
# Sahte oyun klasörü ekstra dosyalarla (save, exe, alt klasörler, satıcıya ait unins000.exe) doldurulur.
param([string]$Exe = '',            # varsayılan: dist\<sürüm>\Fable3_Turkce_Yama_<sürüm>.exe
      [string]$Old102 = '',         # (isteğe bağlı) eski v1.0.2 kurulum programı; yoksa T11 atlanır
      [string]$OldExe = '',         # (isteğe bağlı) eski hatalı v1.0 kurulum programı; yoksa T5 atlanır
      [string]$RealGame = $env:F3_GAME)  # (isteğe bağlı) gerçek oyun klasörü: test boyunca DEĞİŞMEDİĞİ denetlenir
Add-Type -AssemblyName System.Windows.Forms
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$ver = (Get-Content "$root\manifest.json" -Raw -Encoding UTF8 | ConvertFrom-Json).tag
if (-not $Exe) { $Exe = "$root\dist\$ver\Fable3_Turkce_Yama_$ver.exe" }
$base = Join-Path $env:TEMP ('f3_safe_' + (Get-Random))
New-Item -ItemType Directory -Force $base | Out-Null
$orig = "$root\backup"
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{7C1D3B52-5E0A-4B53-9A6E-F3A1B7D2C411}_is1'
$sh = New-Object -ComObject WScript.Shell
$script:fail = 0
function Say($m) { Write-Host $m }
function Check($ok, $what) { if ($ok) { Say "  [OK]   $what" } else { Say "  [HATA] $what"; $script:fail++ } }

function New-Game($name, [bool]$vendorUnins = $true, [bool]$dlc = $false) {
    $g = "$base\$name\Oyun Klasörü ğüşİ\Fable 3"
    foreach ($d in 'data\language\en-uk\text', 'data\language\en-uk\fonts', 'data\language\de-de\text', 'data\language\fr-fr\fonts', 'save\profil1', 'Bonus Content\Extra', 'DLC\paket', '_Redist', 'SupportFiles') { New-Item -ItemType Directory -Force "$g\$d" | Out-Null }
    Copy-Item "$orig\book.babel.orig" "$g\data\language\en-uk\text\book.babel"
    Copy-Item "$orig\gui_normal.bft.orig" "$g\data\language\en-uk\fonts\gui_normal.bft"
    [IO.File]::WriteAllBytes("$g\Fable3.exe", [byte[]](1..200)); [IO.File]::WriteAllBytes("$g\FableLauncher.exe", [byte[]](3..99))
    [IO.File]::WriteAllText("$g\Fable3.dll", 'dll'); [IO.File]::WriteAllText("$g\save\profil1\kayit.sav", 'SAVE-DATA-ÖNEMLİ')
    [IO.File]::WriteAllText("$g\save\profil1\kayit2.sav", 'SAVE2'); [IO.File]::WriteAllText("$g\Bonus Content\Extra\x.txt", 'bonus')
    [IO.File]::WriteAllText("$g\DLC\paket\d.pak", 'dlc'); [IO.File]::WriteAllText("$g\_Redist\vc.exe", 'redist')
    [IO.File]::WriteAllText("$g\data\language\de-de\text\book.babel", 'alman'); [IO.File]::WriteAllText("$g\data\language\fr-fr\fonts\gui_normal.bft", 'fr')
    [IO.File]::WriteAllText("$g\SupportFiles\a.ini", 'ini'); [IO.File]::WriteAllText("$g\README.htm", 'readme')
    if ($dlc) { Copy-Item "$root\work\fake_dlc\DLC\*" "$g\DLC" -Recurse }
    if ($vendorUnins) { [IO.File]::WriteAllText("$g\unins000.exe", 'VENDOR-UNINS'); [IO.File]::WriteAllText("$g\unins000.dat", 'VENDOR-DAT') }
    return $g
}
function Snap($g) {
    $h = @{}
    Get-ChildItem $g -Recurse -Force -File | ForEach-Object { $h[$_.FullName.Substring($g.Length)] = "$($_.Length)|$((Get-FileHash $_.FullName).Hash.Substring(0,12))" }
    $d = @{}; Get-ChildItem $g -Recurse -Force -Directory | ForEach-Object { $d[$_.FullName.Substring($g.Length)] = 1 }
    return @{ f = $h; d = $d }
}
# fark: allowed = göreli yol önekleri (book/font/_TR_yedek)
function FDiff($a, $b, [string[]]$allowedFiles = @(), [string[]]$allowedPrefix = @()) {
    $bad = @()
    $names = @($a.f.Keys) + @($b.f.Keys) | Sort-Object -Unique
    foreach ($n in $names) {
        if ($a.f[$n] -ne $b.f[$n]) {
            $ok = ($allowedFiles -contains $n)
            foreach ($p in $allowedPrefix) { if ($n.StartsWith($p)) { $ok = $true } }
            if (-not $ok) { $bad += "$n  ($($a.f[$n]) -> $($b.f[$n]))" }
        }
    }
    foreach ($n in @($a.d.Keys) + @($b.d.Keys) | Sort-Object -Unique) {
        if ((($a.d.ContainsKey($n)) -ne ($b.d.ContainsKey($n)))) {
            $ok = $false
            foreach ($p in $allowedPrefix) { if ($n.StartsWith($p.TrimEnd('\'))) { $ok = $true } }
            if (-not $ok) { $bad += "KLASÖR $n" }
        }
    }
    return $bad
}
$BK = '\data\language\en-uk\text\book.babel'; $FN = '\data\language\en-uk\fonts\gui_normal.bft'
function Silent($exe, $argline) { (Start-Process $exe -ArgumentList $argline -Wait -PassThru).ExitCode }
function Inst($g, $app, $mode = 0) { Silent $Exe "/VERYSILENT /SUPPRESSMSGBOXES /CURRENTUSER /NORESTART /DIR=`"$app`" /GAME=`"$g`"" }
function KeyLoc { if (Test-Path $key) { (Get-ItemProperty $key).InstallLocation } else { $null } }
function Unins-Registry { $u = (Get-ItemProperty $key).UninstallString.Trim('"'); $r = Silent $u '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART'; Start-Sleep 5; $r }
function Kill-All { Get-Process | Where-Object { $_.ProcessName -like 'Fable3_Turkce*' -or $_.ProcessName -like '*unins*' } | Stop-Process -Force -ErrorAction SilentlyContinue }
# gerçek kurulum (varsa) test boyunca değişmemeli
$realGame = $RealGame
function RealState { if (-not $realGame -or -not (Test-Path $realGame)) { return 'gerçek oyun verilmedi' }; $b = "$realGame\data\language\en-uk\text\book.babel"; $f = "$realGame\data\language\en-uk\fonts\gui_normal.bft"
    "$(if (Test-Path $b) { (Get-FileHash $b).Hash.Substring(0,12) })|$(if (Test-Path $f) { (Get-FileHash $f).Hash.Substring(0,12) })|HKLM:$(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{7C1D3B52-5E0A-4B53-9A6E-F3A1B7D2C411}_is1')|PF:$(Test-Path 'C:\Program Files\Fable3 Turkce Yama\unins000.exe')" }
$real0 = RealState
Kill-All

# ===== T0: eski (test sırasında kalmış) hatalı kayıt temizliği
Say "`n=== T0 eski/hatalı kayıt temizliği (varsa)"
Say "  önceki kayıt InstallLocation: $(KeyLoc)"

# ===== T1/T2: kurulum + 'Yamayı kaldır' menüsü (GUI)
Say "`n=== T1 kurulum (Tam), oyun klasöründe yalnızca book/font/_TR_yedek değişmeli"
$g = New-Game 'A' $true; $app = "$base\A\uygulama klasoru"
$s0 = Snap $g
Check ((Inst $g $app 2) -eq 0) 'kurulum çıkış kodu 0'
$s1 = Snap $g
$bad = FDiff $s0 $s1 @($BK, $FN) @('\_TR_yedek')
Check ($bad.Count -eq 0) "kurulumda beklenmeyen değişiklik yok $($bad -join ' ; ')"
Check ((KeyLoc).TrimEnd('\') -eq $app) "kaldırma kaydının uygulama klasörü = '$app' (oyun klasörü DEĞİL): $(KeyLoc)"
Check (Test-Path "$app\unins000.exe") 'kaldırıcı uygulama klasöründe'
Check (-not (Test-Path "$g\unins000.exe") -or ((Get-Content "$g\unins000.exe") -eq 'VENDOR-UNINS')) 'oyun klasöründe bizim unins yok; satıcı dosyası dokunulmadı'
Check ((Get-Content "$g\save\profil1\kayit.sav" -Encoding UTF8) -eq 'SAVE-DATA-ÖNEMLİ') 'save dosyası sağlam'

Say "`n=== T2 'Yamayı kaldır' menüsü (kurulum programını yeniden aç)"
$p = Start-Process $Exe -ArgumentList "/CURRENTUSER /DIR=`"$app`" /GAME=`"$g`"" -PassThru; Start-Sleep 5
$null = $sh.AppActivate('Kurulum yardımcısı'); Start-Sleep -Milliseconds 500; $sh.SendKeys('{ENTER}'); Start-Sleep 2; $sh.SendKeys('{DOWN}'); Start-Sleep 1; $sh.SendKeys('{ENTER}'); Start-Sleep 3
$sh.SendKeys('{LEFT}{ENTER}'); Start-Sleep 7; $sh.SendKeys('{ENTER}'); Start-Sleep 4; for($i=0;$i -lt 12;$i++){ if(-not (Get-Process | ? { $_.ProcessName -like '*unins*' -or $_.ProcessName -like 'Fable3_Turkce*' })){break}; $sh.SendKeys('{ENTER}'); Start-Sleep 3 }; Start-Sleep 3
Kill-All
$s2 = Snap $g
$bad = FDiff $s0 $s2
Check ($bad.Count -eq 0) "kaldırma sonrası oyun klasörü BAŞLANGIÇLA AYNI (book/font geri geldi, _TR_yedek gitti, başka hiçbir şey değişmedi) $($bad -join ' ; ')"
Check (-not (Test-Path $g) -eq $false) 'oyun klasörü duruyor'
Check (-not (Test-Path $app)) 'uygulama klasörü ve kaldırıcı silindi'
Check ($null -eq (KeyLoc)) 'kaldırma kaydı silindi'

# ===== T3: Uygulamalar listesinden kaldırma (UninstallString)
Say "`n=== T3 Uygulamalar listesi (UninstallString) ile kaldırma"
$g = New-Game 'B' $true; $app = "$base\B\uygulama"
$s0 = Snap $g
Inst $g $app 1 | Out-Null
$s1 = Snap $g
Check ((FDiff $s0 $s1 @($BK, $FN) @('\_TR_yedek')).Count -eq 0) 'kurulum (Standart): yalnızca izinli değişiklik'
Check ((Unins-Registry) -eq 0) 'kaldırıcı çıkış kodu 0'
$bad = FDiff $s0 (Snap $g)
Check ($bad.Count -eq 0) "kaldırma sonrası oyun klasörü BAŞLANGIÇLA AYNI $($bad -join ' ; ')"
Check (-not (Test-Path $app)) 'uygulama klasörü silindi'; Check ($null -eq (KeyLoc)) 'kayıt silindi'

# ===== T4: _TR_yedek içinde beklenmeyen dosya -> hiçbir şey silinmemeli
Say "`n=== T4 _TR_yedek içinde beklenmeyen dosya var: yedek klasöründe hiçbir şey silinmemeli"
$g = New-Game 'C' $false; $app = "$base\C\uygulama"
$s0 = Snap $g
Inst $g $app 2 | Out-Null
[IO.File]::WriteAllText("$g\_TR_yedek\kullanici_notu.txt", 'benim notum')
Check ((Unins-Registry) -eq 0) 'kaldırıcı çıkış kodu 0'
$bad = FDiff $s0 (Snap $g) @() @('\_TR_yedek')
Check ($bad.Count -eq 0) "oyun dosyaları orijinal döndü, _TR_yedek dışında fark yok $($bad -join ' ; ')"
Check ((Test-Path "$g\_TR_yedek\kullanici_notu.txt") -and (Test-Path "$g\_TR_yedek\book.babel")) 'beklenmeyen dosya olduğu için _TR_yedek hiç silinmedi'

# ===== T5: eski hatalı sürüm (kayıt + unins oyun klasöründe) -> yeni kurulum temizlemeli, oyuna dokunmamalı
if ($OldExe -and (Test-Path $OldExe)) {
Say "`n=== T5 eski hatalı kurulum (oyun klasörü = uygulama klasörü) -> yeni sürüm temizler"
$g = New-Game 'D' $false
$s0 = Snap $g
$r = Silent $OldExe "/VERYSILENT /SUPPRESSMSGBOXES /CURRENTUSER /NORESTART /DIR=`"$g`" /MODE=2"
Say "  eski exe çıkış kodu: $r ; eski kayıt InstallLocation: $(KeyLoc) ; oyunda unins000: $(Test-Path "$g\unins000.exe")"
$sOld = Snap $g
$app = "$base\D\uygulama"
Check ((Inst $g $app 2) -eq 0) 'yeni exe kurulum çıkış kodu 0'
$sNew = Snap $g
Check ($null -ne (KeyLoc) -and (KeyLoc).TrimEnd('\') -eq $app) "kayıt artık uygulama klasörünü gösteriyor: $(KeyLoc)"
Check (-not (Test-Path "$g\unins000.exe") -and -not (Test-Path "$g\unins000.dat")) 'oyun klasöründeki eski unins000.exe/.dat kaldırıldı'
$bad = FDiff $sOld $sNew @($BK, $FN, '\unins000.exe', '\unins000.dat', '\unins000.msg') @('\_TR_yedek')
Check ($bad.Count -eq 0) "eski kaydı temizlerken oyun dosyalarına dokunulmadı $($bad -join ' ; ')"
Check ((Unins-Registry) -eq 0) 'yeni kaldırıcı çalıştı'
$bad = FDiff $s0 (Snap $g)
Check ($bad.Count -eq 0) "sonunda oyun klasörü BAŞLANGIÇLA AYNI $($bad -join ' ; ')"
} else { Say "  ATLANDI (eski hatalı sürüm kurucusu verilmedi)" }

# ===== T6: eski kaldırıcıyı oyun klasöründe çalıştırma güvenliği (yeni exe'de kalmadığı için yalnızca yeni kaldırıcı kontrolü)
Say "`n=== T6 sessiz yanlış klasör: hiçbir şey yazılmamalı"
$bad = "$base\bos"; New-Item -ItemType Directory -Force $bad | Out-Null
$g = New-Game 'E' $false; $s0 = Snap $g
$rc = Silent $Exe "/VERYSILENT /SUPPRESSMSGBOXES /CURRENTUSER /DIR=`"$base\E\uyg`" /GAME=`"$bad`" /MODE=2"
Check ($rc -ne 0) "yanlış klasör reddedildi (çıkış $rc)"
Check ((Get-ChildItem $bad -Recurse -Force | Measure-Object).Count -eq 0) 'boş klasöre hiçbir şey yazılmadı'
Check ((FDiff $s0 (Snap $g)).Count -eq 0) 'gerçek sahte oyun klasörü değişmedi'
# uygulama klasörü = oyun klasörü verilirse reddedilmeli
$g = New-Game 'F' $false; $s0 = Snap $g
$rc = Silent $Exe "/VERYSILENT /SUPPRESSMSGBOXES /CURRENTUSER /DIR=`"$g`" /GAME=`"$g`" /MODE=2"
Check ($rc -ne 0) "uygulama klasörü = oyun klasörü reddedildi (çıkış $rc)"
Check ((FDiff $s0 (Snap $g)).Count -eq 0) 'oyun klasörü değişmedi'


# ===== T7: kaldırma kaydı YOK + oyun klasöründe BAŞKASININ unins000.exe'si var (ör. repack kurulumu) -> o çalıştırılmamalı
Say "`n=== T7 kayıt yok + oyun klasöründe yabancı unins000.exe: yabancı kaldırıcı ASLA çalıştırılmamalı"
$g = New-Game 'G' $false; $app = "$base\G\uygulama"
Copy-Item "$env:SystemRoot\System32\cmd.exe" "$g\unins000.exe"; [IO.File]::WriteAllText("$g\unins000.dat", 'YABANCI-DAT')
$s0 = Snap $g
Inst $g $app 2 | Out-Null
Remove-Item $key -Recurse -Force
$p = Start-Process $Exe -ArgumentList "/CURRENTUSER /DIR=`"$app`" /GAME=`"$g`"" -PassThru; Start-Sleep 5
$null = $sh.AppActivate('Kurulum yardımcısı'); Start-Sleep -Milliseconds 500; $sh.SendKeys('{ENTER}'); Start-Sleep 2; $sh.SendKeys('{DOWN}'); Start-Sleep 1; $sh.SendKeys('{ENTER}'); Start-Sleep 4
$ran = [bool](Get-Process unins000 -ErrorAction SilentlyContinue)
$sh.SendKeys('{ENTER}'); Start-Sleep 4
for ($i = 0; $i -lt 6; $i++) { if (-not (Get-Process | Where-Object { $_.ProcessName -like 'Fable3_Turkce*' })) { break }; $sh.SendKeys('{ENTER}'); Start-Sleep 2 }
Kill-All
Check (-not $ran) 'yabancı unins000.exe çalıştırılmadı'
$bad = FDiff $s0 (Snap $g)
Check ($bad.Count -eq 0) "oyun klasörü BAŞLANGIÇLA AYNI (book/font geri geldi, yabancı unins dosyaları duruyor) $($bad -join ' ; ')"


# ===== T8: DLC paketi: kurulu DLC'ler için DLC\99_tr_yama eklenir; DLC arşivlerine DOKUNULMAZ; kaldırma her şeyi geri alır
Say "`n=== T8 DLC paketi (sahte Understone + Traitors Keep + yabancı DLC)"
$exp = @('\DLC\99_tr_yama\content.xbx', '\DLC\99_tr_yama\tr_yama.txt', '\DLC\99_tr_yama\Content\package_collection_info.xmb',
         '\DLC\99_tr_yama\Content\tr_yama_us.bnk', '\DLC\99_tr_yama\Content\tr_yama_us.bnk.dat',
         '\DLC\99_tr_yama\Content\tr_yama_tk.bnk', '\DLC\99_tr_yama\Content\tr_yama_tk.bnk.dat')
$g = New-Game 'H' $false $true; $app = "$base\H\uygulama"
$s0 = Snap $g
Check ((Inst $g $app) -eq 0) 'kurulum çıkış kodu 0'
$s1 = Snap $g
Check ((FDiff $s0 $s1 @($BK, $FN) @('\_TR_yedek', '\DLC\99_tr_yama')).Count -eq 0) "yalnızca book/font/_TR_yedek/DLC\99_tr_yama değişti (DLC arşivleri ve diğer DLC'ler aynı) $((FDiff $s0 $s1 @($BK, $FN) @('\_TR_yedek', '\DLC\99_tr_yama')) -join ' ; ')"
$missing = @($exp | ? { -not $s1.f.ContainsKey($_) })
Check ($missing.Count -eq 0) "DLC\99_tr_yama dosyaları tamam $($missing -join ',')"
$xmb = [IO.File]::ReadAllText("$g\DLC\99_tr_yama\Content\package_collection_info.xmb")
Check (($xmb -match 'tr_yama_us\.bnk') -and ($xmb -match 'tr_yama_tk\.bnk') -and ($xmb -match '<mountOrder>\s*10000')) 'paket listesi iki paketi ve mountOrder 10000 içeriyor'
Check ((Get-Content "$app\kurulum_log.txt" -Encoding Default | Select-String 'DLC.*kuruldu ve doğrulandı') -ne $null) 'günlükte DLC kurulumu doğrulandı'
Check ((Inst $g $app) -eq 0) 'yeniden kurulum (onar) çıkış kodu 0'
$s1b = Snap $g
Check ((FDiff $s1 $s1b).Count -eq 0) "yeniden kurulum aynı sonucu verdi (kararlı) $((FDiff $s1 $s1b) -join ' ; ')"
Check ((Unins-Registry) -eq 0) 'kaldırıcı çıkış kodu 0'
$bad = FDiff $s0 (Snap $g)
Check ($bad.Count -eq 0) "kaldırma sonrası oyun klasörü (DLC dahil) BAŞLANGIÇLA AYNI $($bad -join ' ; ')"

# ===== T9: DLC\99_tr_yama içinde bilinmeyen dosya varsa kaldırma o klasörde HİÇBİR şey silmez
Say "`n=== T9 DLC\99_tr_yama içinde kullanıcı dosyası: silinmemeli"
$g = New-Game 'I' $false $true; $app = "$base\I\uygulama"; $s0 = Snap $g
Inst $g $app | Out-Null
[IO.File]::WriteAllText("$g\DLC\99_tr_yama\benim.txt", 'kullanici')
Check ((Unins-Registry) -eq 0) 'kaldırıcı çıkış kodu 0'
Check ((Test-Path "$g\DLC\99_tr_yama\benim.txt") -and (Test-Path "$g\DLC\99_tr_yama\content.xbx")) 'bilinmeyen dosya olduğu için klasörde hiçbir şey silinmedi'
$bad = FDiff $s0 (Snap $g) @() @('\DLC\99_tr_yama')
Check ($bad.Count -eq 0) "oyun dosyaları orijinal döndü; DLC arşivleri ve diğer DLC'ler aynı $($bad -join ' ; ')"

# ===== T10: DLC yok / yalnızca yabancı DLC / desteklenmeyen DLC kitabı -> paket EKLENMEZ, ana yama kurulur
Say "`n=== T10 DLC yok ya da desteklenmeyen sürüm: paket eklenmemeli"
$g = New-Game 'J' $false $false; $app = "$base\J\uygulama"
Check (((Inst $g $app) -eq 0) -and -not (Test-Path "$g\DLC\99_tr_yama")) 'destekli DLC yok (yalnızca yabancı paket): DLC\99_tr_yama oluşturulmadı'
Unins-Registry | Out-Null
$g = New-Game 'K' $false $false; $app = "$base\K\uygulama"
New-Item -ItemType Directory -Force "$g\DLC" | Out-Null; Copy-Item "$root\work\fake_dlc\DLC\99_dlc2_fixes" "$g\DLC\99_dlc2_fixes" -Recurse
Check (((Inst $g $app) -eq 0) -and -not (Test-Path "$g\DLC\99_tr_yama")) 'yalnızca yabancı DLC var: paket eklenmedi'
Unins-Registry | Out-Null
$g = New-Game 'L' $false $true; $app = "$base\L\uygulama"
$bnk = "$g\DLC\understone_quest\Content\dlc_freeforall.bnk.dat"
$bytes = [IO.File]::ReadAllBytes($bnk); $bytes[200] = $bytes[200] -bxor 0xFF; [IO.File]::WriteAllBytes($bnk, $bytes)   # desteklenmeyen (değiştirilmiş) kitap
Check ((Inst $g $app) -eq 0) 'kurulum çıkış kodu 0'
$xmb = if (Test-Path "$g\DLC\99_tr_yama\Content\package_collection_info.xmb") { [IO.File]::ReadAllText("$g\DLC\99_tr_yama\Content\package_collection_info.xmb") } else { '' }
Check (($xmb -notmatch 'tr_yama_us\.bnk') -and ($xmb -match 'tr_yama_tk\.bnk')) 'bozuk Understone atlandı, Traitors Keep paketi eklendi'
Check ((Get-Content "$app\kurulum_log.txt" -Encoding Default | Select-String 'desteklenmeyen DLC|SKIP') -ne $null) 'günlükte atlanan DLC kaydı var'
Unins-Registry | Out-Null

# ===== T11: eski sürüm (v1.0.2 Standart) -> yeni kurulum programı onarır; orijinal yedeğe dokunulmaz
Say "`n=== T11 eski Standart kurulum (v1.0.2) -> yeni sürüm onarır"
if ($Old102 -and (Test-Path $Old102)) {
    $g = New-Game 'M' $false $true; $app = "$base\M\uygulama"; $s0 = Snap $g
    $r = Silent $Old102 "/VERYSILENT /SUPPRESSMSGBOXES /CURRENTUSER /NORESTART /DIR=`"$app`" /GAME=`"$g`" /MODE=1"
    $hOld = (Get-FileHash "$g$BK").Hash.Substring(0, 10).ToLower(); $hBak = (Get-FileHash "$g\_TR_yedek\book.babel").Hash
    Check (($r -eq 0) -and ($hOld -eq 'cb177f4f59')) "v1.0.2 Standart kuruldu (book $hOld)"
    Check ((Inst $g $app) -eq 0) 'yeni kurulum programı (onar) çıkış kodu 0'
    $man = Get-Content "$root\manifest.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    Check ((Get-FileHash "$g$BK").Hash.ToLower() -eq $man.outputs.book) 'book.babel güncel (tam altyazı) sürüme geçti'
    Check ((Get-FileHash "$g$FN").Hash.ToLower() -eq $man.outputs.font) 'gui_normal.bft güncel sürüme geçti'
    Check ((Get-FileHash "$g\_TR_yedek\book.babel").Hash -eq $hBak) 'orijinal yedeğe dokunulmadı'
    Check ((Unins-Registry) -eq 0) 'kaldırıcı çıkış kodu 0'
    $bad = FDiff $s0 (Snap $g)
    Check ($bad.Count -eq 0) "sonunda oyun klasörü BAŞLANGIÇLA AYNI $($bad -join ' ; ')"
} else { Say '  [ATLANDI] eski v1.0.2 exe yok' }

Check ((RealState) -eq $real0) "gerçek kurulum test boyunca değişmedi ($real0)"
Say "`n=== SONUÇ: $(if ($script:fail -eq 0) { 'TÜM TESTLER GEÇTİ' } else { "$($script:fail) HATA" })"
Say "çalışma klasörü: $base"
