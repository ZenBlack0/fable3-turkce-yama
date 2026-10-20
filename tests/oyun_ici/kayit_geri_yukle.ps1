# Yedekten geri yukleme: hicbir dosya SILINMEZ. Yedekte olmayan (testte olusan) dosyalar TEST_ARTIKLARI altina tasinir.
param([Parameter(Mandatory)][string]$Saves, [Parameter(Mandatory)][string]$Yedek, [string]$Ts = (Get-Date -Format yyyyMMdd_HHmmss))
$sr = (Resolve-Path $Saves).Path.TrimEnd('\'); $yr = (Resolve-Path $Yedek).Path.TrimEnd('\')
$art = Join-Path (Split-Path $sr -Parent) ("Fable 3_TEST_ARTIKLARI\" + $Ts)
# 1) yedekte olmayan dosyalari kenara al
Get-ChildItem $sr -Recurse -File -Force | ForEach-Object {
    $rel = $_.FullName.Substring($sr.Length + 1)
    if (-not (Test-Path (Join-Path $yr $rel))) {
        $dst = Join-Path $art $rel
        New-Item -ItemType Directory -Force (Split-Path $dst -Parent) | Out-Null
        Move-Item $_.FullName $dst
        "  kenara alindi (test artigi): $rel"
    }
}
# 2) yedekteki dosyalari geri yaz (gerekirse uzerine yazar)
Get-ChildItem $yr -Recurse -File -Force | ForEach-Object {
    $rel = $_.FullName.Substring($yr.Length + 1)
    $dst = Join-Path $sr $rel
    New-Item -ItemType Directory -Force (Split-Path $dst -Parent) | Out-Null
    if ((-not (Test-Path $dst)) -or ((Get-FileHash $dst -Algorithm SHA256).Hash -ne (Get-FileHash $_.FullName -Algorithm SHA256).Hash)) {
        Copy-Item $_.FullName $dst -Force
        "  geri yazildi: $rel"
    }
}
& (Join-Path $PSScriptRoot 'kayit_karsilastir.ps1') -A $sr -B $yr
exit $LASTEXITCODE
