# Mevcut durum (YALNIZCA OKUR): DLC klasorleri ve 99_tr_yama paket kimlikleri / isRequired degerleri.
param([Parameter(Mandatory)][string]$Game)
"DLC klasorleri:"
Get-ChildItem (Join-Path $Game 'DLC') -Directory | ForEach-Object { '  ' + $_.Name }
$pk = Join-Path $Game 'DLC\99_tr_yama'
$p = Join-Path $pk 'Content\package_collection_info.xmb'
if (Test-Path $p) {
    $t = [IO.File]::ReadAllText($p)
    'xmb paketleri:'
    [regex]::Matches($t, '<package>.*?</package>', 'Singleline') | ForEach-Object {
        $b = $_.Value
        '  uid=' + [regex]::Match($b, '<packageUniqueId>\s*(\d+)').Groups[1].Value + '  isRequired(xmb)=' + [regex]::Match($b, '<isRequired>\s*(\w+)').Groups[1].Value + '  bank=' + [regex]::Match($b, '<bankName>\s*([\w.]+)').Groups[1].Value
    }
    'dosyalar:'
    Get-ChildItem $pk -Recurse -File | ForEach-Object { '  ' + $_.FullName.Substring($pk.Length + 1) + '   ' + $_.Length }
} else { '99_tr_yama YOK (oyun yamasiz DLC durumunda)' }
