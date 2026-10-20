# TEK TIKLAMALI YUKSELTME TESTI (TEST_YUKSELT.bat bunu calistirir): v1.1.0 -> v1.1.1 yukseltme, kaldirma, eski kaydin acilmasi.
# Siz yalnizca oyunu acip bakar ve E/H tuslarsiniz. Kayitlar once yedeklenir, sonunda yedekten geri yuklenir. Kayit dosyalari DEGISTIRILMEZ
# (oyunun kendi kaydi disinda: sizin "kaydet" adiminiz oyunun dosyasini yeniden yazar; test sonunda yedekten geri yuklenir).
# Ic test degiskenleri (yalnizca sahte klasorlerde deneme): F3T_GAME, F3T_SAVES, F3T_SIM=1 (oyun oturumlari taklit edilir), F3T_FAIL=<adim>
param()
$ErrorActionPreference = 'Stop'
$kit = $PSScriptRoot
$root = (Resolve-Path (Join-Path $kit '..\..')).Path
$ts = Get-Date -Format yyyyMMdd_HHmmss
$sim = ($env:F3T_SIM -eq '1')
$man = Get-Content (Join-Path $root 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json

# ---- ayarlar
$game = $env:F3T_GAME; if (-not $game) { $game = $env:F3_GAME }
if (-not $game) {
    $o = Join-Path $kit 'ayarlar.bat'
    if (Test-Path $o) { $game = [regex]::Match((Get-Content $o -Raw), 'set "GAME=(.*?)"').Groups[1].Value }
}
if (-not $game) { throw 'Oyun klasoru bilinmiyor: F3_GAME ortam degiskenini ya da ayarlar.bat icindeki GAME yolunu ayarlayin.' }
$saves = $env:F3T_SAVES; if (-not $saves) { $saves = Join-Path $env:USERPROFILE 'Saved Games\Lionhead Studios\Fable 3' }
if ($sim) { $env:F3_SAVESDIR = $saves } else { Remove-Item Env:F3_SAVESDIR -ErrorAction SilentlyContinue }
$yedek = $saves + '_YEDEK_YUKSELT_' + $ts
$relBase = 'https://github.com/' + $man.repo + '/releases/download/'
# eski (v1.1.0) kurucu: GitHub Release'ten indirilir ve SHA-256 ile dogrulanir
$v110 = Join-Path $kit '_indirilen\Fable3_Turkce_Yama_v1.1.0.exe'
$V110_ZIP_SHA = '7a6b2b19329d77236ba8c9677b391175ca65240b5f94d704c9539473fd8f16d9'; $V110_EXE_SHA = '300fcbb1eeabcdce1cb10165eee6e79bd6665f3e1f3db9b16e5384bfdfb7058f'
# yeni kurucu: bu depoda derlenmis (output\ ya da dist\); yoksa Release'ten indirilir
$v111 = Join-Path $root ('output\Fable3_Turkce_Yama_' + $man.tag + '.exe')
if (-not (Test-Path $v111)) { $alt = Join-Path $root ('dist\' + $man.tag + '\Fable3_Turkce_Yama_' + $man.tag + '.exe'); if (Test-Path $alt) { $v111 = $alt } }
$sonuc = Join-Path $kit 'SONUC.txt'
$simApp = Join-Path $env:TEMP 'f3_yukselt_app'
$H_ORIG = '1a588553b9dde08b3aa37d609f5e2ec9a9a9f2cb8f0d93bb3b93cdeca2e7afc3'
$H_V110 = '3eba8894429ac5ffb35e750ae1edba59192e131724c005c128e5700bdcb66754'
$H_V111 = $man.outputs.book
$dlcDir = Join-Path $game 'DLC'; $pkgDir = Join-Path $dlcDir '99_tr_yama'
$bookP = Join-Path $game 'data\language\en-uk\text\book.babel'
$py = $null
foreach ($c in "$env:LOCALAPPDATA\Python\pythoncore-3.14-64\python.exe", "$env:LOCALAPPDATA\Programs\Python\Python314\python.exe") { if (-not $py -and (Test-Path $c)) { $py = $c } }
if (-not $py) { $g2 = Get-Command python -ErrorAction SilentlyContinue | Where-Object { $_.Source -notlike '*WindowsApps*' } | Select-Object -First 1; if ($g2) { $py = $g2.Source } }
$R = [ordered]@{}
$log = New-Object System.Collections.Generic.List[string]
function Log([string]$m) { $log.Add($m) }
function Set-R([string]$k, $v) { $script:R[$k] = $v }

# ---- ekran yardimcilari
function Banner([string]$title, [string[]]$lines, [string]$color = 'Yellow') {
    Write-Host ''; Write-Host ('=' * 78) -ForegroundColor $color; Write-Host ('  ' + $title) -ForegroundColor $color; Write-Host ('=' * 78) -ForegroundColor $color
    foreach ($l in $lines) { Write-Host ('  ' + $l) -ForegroundColor White }
    Write-Host ('=' * 78) -ForegroundColor $color; Write-Host ''
}
function Info([string]$m) { Write-Host ('  ' + $m) -ForegroundColor Gray }
function GameRunning { if ($sim) { return $false }; [bool](Get-Process -Name 'Fable3', 'FableLauncher' -ErrorAction SilentlyContinue) }
function WaitClosed([string]$why) {
    if (-not (GameRunning)) { return }
    Banner 'OYUNU KAPATIN' @($why, 'Oyunu ve baslaticiyi (FableLauncher) tamamen kapatin.', 'Kapaninca bu pencere kendiliginden devam eder.') 'Red'
    while (GameRunning) { Start-Sleep -Seconds 2 }
    Start-Sleep -Seconds 2
}
function Ask([string]$q) {
    Write-Host ''; Write-Host ('  ' + $q + '   [E = Evet / H = Hayir]') -ForegroundColor Cyan
    while ($true) { $k = [Console]::ReadKey($true).KeyChar.ToString().ToUpper(); if ($k -eq 'E' -or $k -eq 'H') { Write-Host "  Cevap: $k" -ForegroundColor Green; return $k } }
}
function WaitSession([scriptblock]$simAction) {
    if ($sim) { if ($simAction) { & $simAction }; return }
    Write-Host '  Oyunun acilmasi bekleniyor... (testi iptal etmek icin I tusuna basin)' -ForegroundColor DarkGray
    while (-not (GameRunning)) {
        Start-Sleep -Milliseconds 700
        if ([Console]::KeyAvailable) { if ([Console]::ReadKey($true).KeyChar.ToString().ToUpper() -eq 'I') { throw 'Kullanici testi iptal etti.' } }
    }
    Write-Host '  Oyun acildi. Isiniz bitince oyunu KAPATIN; bu pencere kendiliginden devam eder.' -ForegroundColor DarkGray
    $closed = 0; while ($closed -lt 3) { if (GameRunning) { $closed = 0 } else { $closed++ }; Start-Sleep -Seconds 1 }
}

# ---- dosya / durum yardimcilari
function FileHash([string]$p) { if (Test-Path $p) { (Get-FileHash $p -Algorithm SHA256).Hash.ToLower() } else { '-' } }
function Snap([string]$dir) {
    $h = @{}
    if (Test-Path $dir) { $r = (Resolve-Path $dir).Path.TrimEnd('\'); Get-ChildItem $dir -Recurse -File -Force | ForEach-Object { $h[$_.FullName.Substring($r.Length + 1).ToLower()] = (Get-FileHash $_.FullName -Algorithm SHA256).Hash } }
    $h
}
function BookState {
    $h = FileHash $bookP
    if ($h -eq $H_ORIG) { 'orijinal' } elseif ($h -eq $H_V110) { 'v1.1.0' } elseif ($h -eq $H_V111) { 'v1.1.1' } else { 'BILINMEYEN:' + $h.Substring(0, [Math]::Min(12, $h.Length)) }
}
# DLC\99_tr_yama durumu: yok | tam | yer tutucu | diger ; xmb isRequired degerleri ; uid listesi
function PkgState {
    $o = [ordered]@{ tur = 'yok'; xmbReq = ''; uids = ''; datSizes = ''; ayrinti = '' }
    if (-not (Test-Path (Join-Path $pkgDir 'content.xbx'))) { return $o }
    $x = Join-Path $pkgDir 'Content\package_collection_info.xmb'
    if (Test-Path $x) {
        $t = [IO.File]::ReadAllText($x)
        $o.xmbReq = (([regex]::Matches($t, '<isRequired>\s*(\w+)') | ForEach-Object { $_.Groups[1].Value }) -join ',')
        $o.uids = (([regex]::Matches($t, '<packageUniqueId>\s*(\d+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object) -join ',')
    }
    $dats = @(Get-ChildItem (Join-Path $pkgDir 'Content') -Filter '*.bnk.dat' -ErrorAction SilentlyContinue)
    $o.datSizes = (($dats | ForEach-Object { $_.Name + '=' + $_.Length }) -join ' ')
    if ($dats.Count -eq 0) { $o.tur = 'diger' }
    elseif (($dats | Where-Object { $_.Length -gt 100000 }).Count -eq $dats.Count) { $o.tur = 'tam' }
    elseif (($dats | Where-Object { $_.Length -lt 5000 }).Count -eq $dats.Count) { $o.tur = 'yer tutucu' }
    else { $o.tur = 'diger' }
    if ($py -and (Test-Path (Join-Path $root 'tools\installer\check_pkg.py'))) {
        try { $o.ayrinti = ((& $py (Join-Path $root 'tools\installer\check_pkg.py') show $pkgDir 2>&1) -join ' | ') } catch { }
    }
    $o
}
function PkgText($s) { "$($s.tur) | xmb isRequired=$($s.xmbReq) | uid=$($s.uids) | $($s.datSizes)" + $(if ($s.ayrinti) { "`r`n     $($s.ayrinti)" } else { '' }) }
function SaveInfo([string]$file) {
    $b = [IO.File]::ReadAllBytes($file); $t = [Text.Encoding]::UTF8.GetString($b, 4, $b.Length - 4)
    $e = $t.LastIndexOf('</SaveInfo>'); if ($e -lt 0) { return $null }
    $x = $t.Substring(0, $e + 11)
    $ids = { param($tag) @([regex]::Matches($x, "<$tag>\s*<PackageId type=""uint"">(\d+)</PackageId>") | ForEach-Object { [int]$_.Groups[1].Value }) }
    [pscustomobject]@{ Installed = (& $ids 'InstalledPackage'); Required = (& $ids 'RequiredPackage') }
}
function NewestChapter([string]$dir) {
    if (-not (Test-Path $dir)) { return $null }
    Get-ChildItem $dir -Recurse -File -Filter '*chaptersave.bin' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
function ReqText($f) {
    if (-not $f) { return '(kayit yok)' }
    $i = SaveInfo $f.FullName; if (-not $i) { return '(XML okunamadi)' }
    $z = ($i.Required -contains 120) -or ($i.Required -contains 121)
    "Installed=$($i.Installed -join ',') | Required=$($i.Required -join ',') | Required'da 120/121: $(if ($z) { 'EVET' } else { 'HAYIR' })"
}
function ReqHas120($f) { if (-not $f) { return $null }; $i = SaveInfo $f.FullName; if (-not $i) { return $null }; (($i.Required -contains 120) -or ($i.Required -contains 121)) }

# ---- kurucular
function Download-Zip([string]$url, [string]$destDir, [string]$expectZipSha) {
    New-Item -ItemType Directory -Force $destDir | Out-Null
    $z = Join-Path $destDir 'indirilen.zip'
    Info "Indiriliyor: $url"
    Invoke-WebRequest -Uri $url -OutFile $z -UseBasicParsing
    if ($expectZipSha -and ((Get-FileHash $z -Algorithm SHA256).Hash.ToLower() -ne $expectZipSha)) { Remove-Item $z -Force; throw "Indirilen zip'in SHA-256 degeri beklenenle uyusmuyor: $url" }
    Expand-Archive $z $destDir -Force
    Remove-Item $z -Force
}
function Ensure-Installers {
    $d = Split-Path $v110 -Parent
    if (-not (Test-Path $v110)) {
        Download-Zip ($relBase + 'v1.1.0/Fable3_Turkce_Yama_v1.1.0.zip') $d $V110_ZIP_SHA
        if (-not (Test-Path $v110) -or ((Get-FileHash $v110 -Algorithm SHA256).Hash.ToLower() -ne $V110_EXE_SHA)) { throw 'v1.1.0 kurucusu dogrulanamadi (SHA-256).' }
    }
    if (-not (Test-Path $v111)) {
        $tag = $man.tag; $d2 = Join-Path $kit ('_indirilen\' + $tag); $v111x = Join-Path $d2 ('Fable3_Turkce_Yama_' + $tag + '.exe')
        if (-not (Test-Path $v111x)) { Download-Zip ($relBase + $tag + '/Fable3_Turkce_Yama_' + $tag + '.zip') $d2 $null }
        $script:v111 = $v111x
    }
}

function RegUninst {
    $hives = if ($sim) { @('HKCU:') } else { @('HKLM:', 'HKCU:') }      # sahte denemede GERCEK (HKLM) kurulumun kaldiricisi ASLA calistirilmaz
    foreach ($h in $hives) {
        $k = "$h\Software\Microsoft\Windows\CurrentVersion\Uninstall\{7C1D3B52-5E0A-4B53-9A6E-F3A1B7D2C411}_is1"
        if (Test-Path $k) { $u = (Get-ItemProperty $k).UninstallString; if ($u) { return $u.Trim('"') } }
    }
    $null
}
function RunInstall([string]$exe, [string]$name) {
    if (-not (Test-Path $exe)) { throw "Kurucu bulunamadi: $exe" }
    $a = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /GAME=`"$game`""
    if ($sim) { $a += " /CURRENTUSER /DIR=`"$simApp`"" }
    Info "$name kuruluyor (sessiz)... (Windows izin/UAC sorarsa EVET deyin)"
    $p = Start-Process $exe -ArgumentList $a -Wait -PassThru
    Log "$name kurulum cikis kodu: $($p.ExitCode)"
    if ($p.ExitCode -ne 0) { throw "$name kurulumu basarisiz (cikis kodu $($p.ExitCode))" }
    Start-Sleep -Seconds 2
}
# --- kaldirici bilgi kutularini okuyup (UI Automation) Tamam'a basar
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Windows.Forms
function Read-Dialogs([System.Collections.Generic.List[string]]$outTexts, [string[]]$seen) {
    $root = [System.Windows.Automation.AutomationElement]::RootElement
    $cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Window)
    foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)) {
        try {
            $pid2 = $w.Current.ProcessId; $pn = (Get-Process -Id $pid2 -ErrorAction Stop).ProcessName
            if ($pn -notlike '*unins*' -and $pn -notlike '_iu*' -and $pn -notlike 'Fable3_Turkce*') { continue }
            $key = "$pid2|" + ($w.GetRuntimeId() -join '.')
            if ($seen -contains $key) { continue }
            $texts = @(); $btns = @()
            foreach ($e in $w.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
                $n = $e.Current.Name; if (-not $n) { continue }
                $ct = $e.Current.ControlType.ProgrammaticName
                if ($ct -like '*Text*') { $texts += $n } elseif ($ct -like '*Button*') { $btns += $e }
            }
            $btnNames = ($btns | ForEach-Object { $_.Current.Name }) -join ' / '
            if (-not $texts -and -not $btns) { continue }      # henuz cizilmemis
            if (-not $texts) {                                  # dugmeler var ama metin henuz okunmadi: bir kez daha dene
                Start-Sleep -Milliseconds 900
                foreach ($e in $w.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
                    $n = $e.Current.Name; if ($n -and ($e.Current.ControlType.ProgrammaticName -like '*Text*')) { $texts += $n }
                }
            }
            if (-not $texts) { $texts = @('(metin UI Automation ile okunamadi; kaldiricinin %TEMP%\Fable3_Turkce_Yama_kaldirma_log.txt dosyasindaki "BİLGİ KUTUSU" satirlarina bakin)') }
            $outTexts.Add("[" + (Get-Date -Format 'HH:mm:ss') + "] PENCERE '" + $w.Current.Name + "' (dugmeler: $btnNames)`r`n      " + ($texts -join "`r`n      "))
            Start-Sleep -Milliseconds 1500          # kullanici da gorsun
            $ok = $btns | Where-Object { $_.Current.Name -match '^(Tamam|OK|&?Tamam|&?OK)$' } | Select-Object -First 1
            if (-not $ok) { $ok = $btns | Select-Object -First 1 }
            if ($ok) { try { ($ok.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)).Invoke() } catch { try { $w.SetFocus(); [System.Windows.Forms.SendKeys]::SendWait('{ENTER}') } catch { } } }
            return $key
        } catch { }
    }
    return $null
}
function RunUninstall([string]$name) {
    $u = RegUninst
    if (-not $u) { throw "$name icin kaldirma kaydi bulunamadi" }
    Info "$name kaldiriliyor... (bilgi kutulari gorunebilir; bu pencere Tamam'a kendisi basar)"
    $texts = New-Object 'System.Collections.Generic.List[string]'
    $seen = @()
    $p = Start-Process $u -ArgumentList '/VERYSILENT /NORESTART' -PassThru
    $t0 = Get-Date; $idle = 0
    while ($true) {
        $k = Read-Dialogs $texts $seen
        if ($k) { $seen += $k; $idle = 0 }
        $alive = [bool](Get-Process | Where-Object { $_.ProcessName -like '*unins*' -or $_.ProcessName -like '_iu*' })
        if (-not $alive) { $idle++ } else { $idle = 0 }
        if ($idle -ge 6) { break }
        if (((Get-Date) - $t0).TotalSeconds -gt 240) { Log "$name kaldirma 240 sn'de bitmedi"; break }
        Start-Sleep -Milliseconds 400
    }
    Start-Sleep -Seconds 2
    $texts.ToArray()
}
function Restore-Saves {
    if (-not (Test-Path $yedek)) { return 'YEDEK YOK (kayitlara dokunulmadi)' }
    $o = & (Join-Path $kit 'kayit_geri_yukle.ps1') -Saves $saves -Yedek $yedek -Ts $ts 2>&1 | Out-String
    $code = $LASTEXITCODE
    Log "--- kayit geri yukleme ciktisi ---`r`n$o"
    $nMoved = ([regex]::Matches($o, 'kenara alindi')).Count; $nBack = ([regex]::Matches($o, 'geri yazildi')).Count
    if ($code -eq 0) { "TAMAM: kayitlar yedekle bayt bayt AYNI | kenara alinan yeni dosya: $nMoved$(if ($nMoved) { " (Fable 3_TEST_ARTIKLARI\$ts)" }) | yedekten geri yazilan: $nBack" } else { 'SORUNLU (ayrintilar asagida)' }
}
function Sim-Session([string]$kind) {
    # yalnizca sahte test: gercek oyunu taklit eder
    $pk = PkgState
    switch ($kind) {
        'save' {   # kayit alinir: Required'a paket, yalnizca isRequired=true ise yazilir
            $src = NewestChapter $saves
            $b = [IO.File]::ReadAllBytes($src.FullName); $t = [Text.Encoding]::UTF8.GetString($b, 4, $b.Length - 4)
            if ($pk.xmbReq -notmatch 'true' -and ($pk.ayrinti -notmatch 'isRequired=true')) {
                $t = [regex]::Replace($t, '<RequiredPackage>\s*<PackageId type="uint">(120|121)</PackageId>\s*</RequiredPackage>\s*', '')
            }
            $t = $t -replace '<CompiledVersion type="uint">4</CompiledVersion>', ('<CompiledVersion type="uint">4</CompiledVersion><!--' + (Get-Random) + '-->')
            $nb = New-Object byte[] 4; [Array]::Copy($b, $nb, 4)
            [IO.File]::WriteAllBytes($src.FullName, ($nb + [Text.Encoding]::UTF8.GetBytes($t)))
        }
    }
}
function Sim-Opens {
    # kayit acilir mi: Required'daki 120/121 icin ilgili paket kimligi kurulu olmali
    $f = NewestChapter $saves; $i = SaveInfo $f.FullName; $pk = PkgState
    $have = @($pk.uids -split ',')
    foreach ($id in 120, 121) { if (($i.Required -contains $id) -and ($have -notcontains "$id")) { return 'H' } }
    'E'
}
function Sim-Turkish { $pk = PkgState; if ($pk.tur -eq 'tam') { 'E' } else { 'H' } }

# =================================================================================================
$restored = $false
$bStart = $null
try {
    Clear-Host
    Banner 'FABLE III - v1.1.0 -> v1.1.1 YUKSELTME TESTI' @(
        'Bu test kayitlarinizi KORUR: once tam yedek alinir, sonunda yedekten geri yuklenir. Hicbir dosya silinmez.',
        'Siz yalnizca oyunu acip bakacak ve E / H tuslayacaksiniz. Gerisini bu pencere yapar.',
        'Windows izin (UAC) sorarsa EVET deyin. Bilgi kutulari kendiliginden okunup kapatilir.',
        'Uyari cikarsa "Download Now / Simdi indir"e ASLA basmayin.') 'Green'
    Ensure-Installers
    foreach ($p in $v110, $v111) { if (-not (Test-Path $p)) { throw "Gerekli kurucu yok: $p" } }
    if (-not (Test-Path $dlcDir)) { throw "DLC klasoru bulunamadi: $dlcDir" }
    if (-not (Test-Path $saves)) { throw "Kayit klasoru bulunamadi: $saves" }
    WaitClosed 'Teste baslamadan once oyun kapali olmali.'

    # ---- 1) yedek
    Banner 'ADIM 1 - KAYITLAR YEDEKLENIYOR' @('Kayit klasoru kopyalanip hash ile dogrulaniyor...')
    & robocopy $saves $yedek /E /COPY:DAT /R:1 /W:1 /NFL /NDL /NJH /NJS | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Yedekleme basarisiz (robocopy $LASTEXITCODE)" }
    $o = & (Join-Path $kit 'kayit_karsilastir.ps1') -A $saves -B $yedek 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { Log $o; throw 'Yedek dogrulanamadi: test BASLATILMADI.' }
    Info "Yedek hazir ve dogrulandi: $yedek"
    $nw0 = NewestChapter $saves
    Set-R 'baslangic_kayit' (ReqText $nw0)
    Set-R 'baslangic_oyun' ("book=" + (BookState) + " | paket: " + (PkgText (PkgState)))
    Info ('Baslangic kaydi: ' + $R['baslangic_kayit'])

    # ---- 2) v1.1.0 hazirla
    Banner 'ADIM 2 - v1.1.0 HAZIRLANIYOR' @('Oyunda v1.1.0 kurulu degilse kuruluyor...') 'Cyan'
    $bs = BookState
    if ($bs -like 'BILINMEYEN*') { throw "Oyundaki book.babel orijinal de, bizim yamamiz da degil ($bs). Test durduruldu; hicbir sey degistirilmedi." }
    if ($bs -eq 'v1.1.1') { Info 'v1.1.1 kurulu: once kaldiriliyor...'; [void](RunUninstall 'v1.1.1'); $bs = BookState; Log "v1.1.1 kaldirildi, book=$bs" }
    if ($bs -eq 'orijinal') { RunInstall $v110 'v1.1.0'; $bs = BookState }
    if ($bs -ne 'v1.1.0') { throw "v1.1.0 hazirlanamadi (book=$bs)" }
    $pk = PkgState; Set-R 'v110_durum' ("book=v1.1.0 | paket: " + (PkgText $pk))
    Info ('v1.1.0 hazir. Paket: ' + $pk.tur + ' | xmb isRequired=' + $pk.xmbReq)

    # ---- 3) yukselt
    Banner 'ADIM 3 - v1.1.1''e YUKSELTILIYOR' @('Kurulum programi sessiz calisiyor...') 'Cyan'
    $app0 = Get-Date
    RunInstall $v111 'v1.1.1'
    $pk = PkgState; $bs = BookState
    Set-R 'yukseltme' ("book=$bs (beklenen v1.1.1) | paket: " + (PkgText $pk))
    $upOk = ($bs -eq 'v1.1.1') -and ($pk.tur -eq 'tam') -and ($pk.xmbReq -eq 'False,False')
    Set-R 'yukseltme_sonuc' $(if ($upOk) { 'TAMAM (kitap v1.1.1, paket tam ve isRequired=False)' } else { 'SORUNLU' })
    Info ('Yukseltme: ' + $R['yukseltme_sonuc'])
    if ($env:F3T_FAIL -eq 'yukselt') { throw 'F3T_FAIL=yukselt (deneme amacli hata)' }

    # ---- U1) oyun: DLC Turkce mi + kaydet
    $snapU1 = Snap $saves
    $found = $null; $attempt = 0
    while (-not $found) {
        $attempt++
        Banner ("SIZIN SIRANIZ (1)  -  deneme $attempt") @(
            '1) OYUNU ACIN.',
            '2) Kaydi yukleyin; DLC METINLERI TURKCE MI BAKIN (ornek: Bay Boyle gorevi, Traitor''s Keep hapishane).',
            '3) BASKA BIR BOLGEYE GECIN ve ekranin kosesinde "kaydediliyor" simgesini gorun (kayit bu sekilde alinir).',
            '4) Duraklat menusunden ANA MENUYE DONUN, sonra OYUNU KAPATIN.',
            '',
            'Oyunu kapattiginizda soru ekranda gorunecek.') 'Yellow'
        WaitSession { Sim-Session 'save' }
        if ($attempt -eq 1) { $a = if ($sim) { Sim-Turkish } else { Ask 'DLC metinleri TURKCE miydi?' }; Set-R 'u1_dlc_turkce' $a }
        $now = Snap $saves
        $changed = @($now.Keys | Where-Object { (-not $snapU1.ContainsKey($_)) -or ($snapU1[$_] -ne $now[$_]) })
        Log ("U1 deneme ${attempt}: degisen/yeni dosya = " + $changed.Count + $(if ($changed.Count) { ' -> ' + ($changed -join '; ') }))
        $cs = @($changed | Where-Object { $_ -like '*chaptersave.bin' })
        if ($cs.Count) { $found = Get-Item (Join-Path (Resolve-Path $saves).Path $cs[0]) }
        else {
            Banner 'KAYIT ALINMADI' @('Kayit klasorunde degisen kayit dosyasi gorulmedi. Bolge degistirip kayit simgesini gorun; sonra oyunu kapatin.') 'Red'
            if ($attempt -ge 3) { break }
            if ((Ask 'Tekrar denemek ister misiniz?') -ne 'E') { break }
        }
    }
    if ($found) {
        Set-R 'u1_kayit' ($found.FullName.Substring($saves.Length).TrimStart('\') + ' [degisti]')
        Set-R 'u1_required' (ReqText $found)
        $z = ReqHas120 $found
        Set-R 'u1_sonuc' $(if ($z -eq $false) { 'TAMAM: yeni kayitta Required listesinde 120/121 YOK' } elseif ($z -eq $true) { 'SORUN: yeni kayit hala 120/121 istiyor' } else { 'okunamadi' })
        Banner 'OTOMATIK KAYIT OKUMA' @(('Kayit degisti: evet'), ('Required: ' + $R['u1_required']), ('Sonuc: ' + $R['u1_sonuc'])) 'Cyan'
    } else { Set-R 'u1_kayit' 'KAYIT ALINMADI'; Set-R 'u1_required' '-'; Set-R 'u1_sonuc' 'OLCULEMEDI (kayit alinmadi)' }
    if ($env:F3T_FAIL -eq 'u1') { throw 'F3T_FAIL=u1 (deneme amacli hata)' }

    # ---- 4) v1.1.1 kaldir
    Banner 'ADIM 4 - v1.1.1 KALDIRILIYOR' @('Kaldirici kayit klasorunu YALNIZCA OKUR; bilgi kutulari varsa metinleri kaydedilir.') 'Cyan'
    $sv = Snap $saves
    $texts = RunUninstall 'v1.1.1'
    Set-R 'kaldir1_kutular' $(if ($texts.Count) { ($texts -join "`r`n") } else { '(bilgi kutusu gorulmedi / yakalanamadi)' })
    Set-R 'kaldir1_durum' ("book=" + (BookState) + " | paket: " + (PkgText (PkgState)))
    $svn = Snap $saves; $same = ($svn.Count -eq $sv.Count) -and -not ($sv.Keys | Where-Object { $svn[$_] -ne $sv[$_] })
    Set-R 'kaldir1_kayitlara_dokunuldu_mu' $(if ($same) { 'HAYIR (kayit dosyalari bayt bayt ayni)' } else { 'EVET (beklenmiyordu!)' })
    Info ('Kaldirma sonrasi: ' + $R['kaldir1_durum'])

    # ---- U2) kayit acilir mi
    Banner 'SIZIN SIRANIZ (2)' @('1) OYUNU ACIN.', '2) AZ ONCE KAYDETTIGINIZ KAYDI YUKLEYIN (yama artik kaldirildi).', '3) Acildi mi, yoksa "downloadable content" uyarisi mi cikti? (Uyari cikarsa "Download Now"a BASMAYIN.)', '4) KAYDETMEDEN OYUNU KAPATIN.') 'Yellow'
    WaitSession $null
    $a = if ($sim) { Sim-Opens } else { Ask 'Kayit ACILDI mi? (uyari cikmadan yuklendi mi)' }
    Set-R 'u2_acildi' $a

    # ---- 5) eski v1.1.0 kayitlarini geri yukle, v1.1.1 kur + kaldir
    Banner 'ADIM 5 - ESKI (v1.1.0) KAYITLAR GERI YUKLENIYOR' @('Yedekten geri yukleniyor; sonra v1.1.1 kurulup kaldirilacak (yer tutucu denemesi).') 'Cyan'
    WaitClosed 'Kayitlari geri yuklemek icin oyun kapali olmali.'
    Set-R 'eski_geri_yukleme' (Restore-Saves)
    $nw1 = NewestChapter $saves
    Set-R 'eski_kayit' (ReqText $nw1)
    RunInstall $v111 'v1.1.1'
    Set-R 'kur2_durum' ("book=" + (BookState) + " | paket: " + (PkgText (PkgState)))
    $sv = Snap $saves
    $texts = RunUninstall 'v1.1.1'
    Set-R 'kaldir2_kutular' $(if ($texts.Count) { ($texts -join "`r`n") } else { '(bilgi kutusu gorulmedi / yakalanamadi)' })
    $pk2 = PkgState
    Set-R 'kaldir2_durum' ("book=" + (BookState) + " | paket: " + (PkgText $pk2))
    $ulog = Join-Path $env:TEMP 'Fable3_Turkce_Yama_kaldirma_log.txt'      # kaldirici bilgi kutusu metinlerini buraya da yazar
    $ulogLines = @(); if (Test-Path $ulog) { $ulogLines = @(Get-Content $ulog -Encoding Default | Where-Object { $_ -match 'KUTUSU' } | Select-Object -Last 6) }
    Set-R 'kaldir2_kaldirici_logu' $(if ($ulogLines) { ($ulogLines -join "`r`n") } else { '(%TEMP%\Fable3_Turkce_Yama_kaldirma_log.txt bulunamadi: eski kaldirici)' })
    $yt = @($texts | Where-Object { $_ -match 'YER TUTUCU|yer tutucu' }) + @($ulogLines | Where-Object { $_ -match 'YER TUTUCU|yer tutucu' })
    Set-R 'kaldir2_yer_tutucu_mesaji' $(if ($yt) { 'EVET (bilgi kutusunda yer tutucu mesaji goruldu)' } else { 'HAYIR / yakalanamadi' })
    Set-R 'kaldir2_yer_tutucu_paketi' $(if ($pk2.tur -eq 'yer tutucu') { 'EVET (paket yer tutucuya donustu)' } else { 'HAYIR: ' + $pk2.tur })
    $svn = Snap $saves; $same = ($svn.Count -eq $sv.Count) -and -not ($sv.Keys | Where-Object { $svn[$_] -ne $sv[$_] })
    Set-R 'kaldir2_kayitlara_dokunuldu_mu' $(if ($same) { 'HAYIR (bayt bayt ayni)' } else { 'EVET (beklenmiyordu!)' })

    # ---- U3) eski kayit acilir mi
    Banner 'SIZIN SIRANIZ (3)' @('1) OYUNU ACIN.', '2) ESKI KAYDI (v1.1.0 ile alinmis) YUKLEYIN. Yama kaldirildi; geride bos bir yer tutucu var.', '3) Acildi mi, yoksa "downloadable content" uyarisi mi cikti? (Uyari cikarsa "Download Now"a BASMAYIN.)', '4) KAYDETMEDEN OYUNU KAPATIN.') 'Yellow'
    WaitSession $null
    $a = if ($sim) { Sim-Opens } else { Ask 'ESKI kayit ACILDI mi? (uyari cikmadan yuklendi mi)' }
    Set-R 'u3_acildi' $a
}
catch {
    Set-R 'hata' $_.Exception.Message
    Banner 'HATA / IPTAL' @($R['hata'], 'Kayitlar simdi yedekten geri yukleniyor...') 'Red'
}
finally {
    Banner 'SON ADIM - KAYITLAR GERI YUKLENIYOR, v1.1.1 KURULU BIRAKILIYOR' @('Lutfen bekleyin; pencereyi kapatmayin.') 'Cyan'
    try {
        if (Test-Path $yedek) {
            WaitClosed 'Geri yukleme icin oyun kapali olmali.'
            Set-R 'son_geri_yukleme' (Restore-Saves)
            $nwF = NewestChapter $saves
            Set-R 'son_kayit' (ReqText $nwF)
        } else { Set-R 'son_geri_yukleme' 'Yedek alinmadigi icin geri yukleme gerekmedi' }
    } catch { Set-R 'son_geri_yukleme' ('HATA: ' + $_.Exception.Message) }
    try {
        if ((BookState) -ne 'v1.1.1' -and -not ((BookState) -like 'BILINMEYEN*') -and (Test-Path $yedek)) {
            RunInstall $v111 'v1.1.1'
        }
        $pkF = PkgState
        Set-R 'son_oyun' ("book=" + (BookState) + " | paket: " + (PkgText $pkF))
        if ((BookState) -eq 'v1.1.1' -and $pkF.tur -eq 'tam') {
            # kurulu v1.1.1 ile kayitlar degismemis olmali
            Set-R 'son_oyun_sonuc' 'TAMAM: v1.1.1 kurulu (tam paket)'
        } else { Set-R 'son_oyun_sonuc' 'v1.1.1 tam kurulu degil (ayrintilar yukarida)' }
    } catch { Set-R 'son_oyun' ('HATA: ' + $_.Exception.Message) }
    # ---- SONUC.txt
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('YUKSELTME TESTI SONUCU  (' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + ')   v1.1.0 -> ' + $man.tag)
    [void]$sb.AppendLine('Oyun klasoru : ' + $game); [void]$sb.AppendLine('Kayit klasoru: ' + $saves); [void]$sb.AppendLine('Yedek        : ' + $yedek); [void]$sb.AppendLine('')
    $beklenen = @{
        baslangic_kayit = 'Required''da 120/121 EVET (v1.1.0 kaydi)'; yukseltme_sonuc = 'TAMAM'; u1_dlc_turkce = 'E'; u1_sonuc = 'yeni kayitta 120/121 YOK'
        kaldir1_kayitlara_dokunuldu_mu = 'HAYIR'; u2_acildi = 'E'; kaldir2_yer_tutucu_mesaji = 'EVET'; kaldir2_yer_tutucu_paketi = 'EVET'
        kaldir2_kayitlara_dokunuldu_mu = 'HAYIR'; u3_acildi = 'E'
    }
    foreach ($k in $R.Keys) {
        $v = "$($R[$k])"
        $bk = if ($beklenen.ContainsKey($k)) { "   (beklenen: $($beklenen[$k]))" } else { '' }
        [void]$sb.AppendLine("[$k]$bk"); [void]$sb.AppendLine('   ' + ($v -replace "`r`n", "`r`n   ")); [void]$sb.AppendLine('')
    }
    if ($log.Count) { [void]$sb.AppendLine('--- ayrintilar ---'); foreach ($l in $log) { [void]$sb.AppendLine($l) } }
    Set-Content -Path $sonuc -Value $sb.ToString() -Encoding UTF8
}
Banner 'TEST BITTI' @(('SONUC DOSYASI:  ' + $sonuc), '', 'Bu dosyanin ICERIGINI kopyalayip Claude Code''a YAPISTIRIN.', '(Dosyayi simdi Not Defteri ile aciyorum.)') 'Green'
if (-not $sim) { Start-Process notepad.exe $sonuc }
