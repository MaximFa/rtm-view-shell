#requires -Version 5.1
# probe_LOCAL_20260908_package-hash.ps1
# Замер на ЛОКАЛЬНОЙ машине: sha256 и размер собранного пакета 08092026.0859_Full.zip.
# Ничего не меняет. Только читает и пишет файл замера.

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$lines = New-Object System.Collections.Generic.List[string]
function Say([string]$s) { $lines.Add($s); Write-Host $s }

Say ("=== LOCAL package hash probe ===")
Say ("time      : " + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
Say ("host name : " + $env:COMPUTERNAME)
Say ("user      : " + $env:USERNAME)
Say ("ps        : " + $PSVersionTable.PSVersion.ToString())
Say ("")

# --- 1. Поиск пакета -------------------------------------------------------
$root = 'D:\Claude\Build'
Say ("build root      : " + $root)
Say ("build root есть : " + (Test-Path -LiteralPath $root))

$found = @()
if (Test-Path -LiteralPath $root) {
    $found = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*_Full.zip' -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending)
}
Say ("найдено *_Full.zip : " + $found.Count)
Say ("")

if ($found.Count -eq 0) {
    Say ("ВЕРДИКТ: пакетов не найдено. Замер пуст не потому, что всё хорошо, а потому, что искать было негде.")
} else {
    $i = 0
    foreach ($f in $found) {
        $i++
        if ($i -gt 5) { Say ("... остальные " + ($found.Count - 5) + " не печатаю"); break }
        $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
        Say ("--- пакет #" + $i)
        Say ("  path   : " + $f.FullName)
        Say ("  name   : " + $f.Name)
        Say ("  bytes  : " + $f.Length)
        Say ("  MB     : " + [math]::Round($f.Length / 1MB, 2))
        Say ("  mtime  : " + $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
        Say ("  sha256 : " + $h)
        Say ("")
    }

    # --- 2. Целевой пакет по имени ----------------------------------------
    $target = @($found | Where-Object { $_.Name -like '08092026.0859*' })
    Say ("копий 08092026.0859*_Full.zip : " + $target.Count + "   <-- ждём ровно 1")
    if ($target.Count -eq 1) {
        $t  = $target[0]
        $th = (Get-FileHash -LiteralPath $t.FullName -Algorithm SHA256).Hash
        Say ("")
        Say ("ЦЕЛЕВОЙ ПАКЕТ")
        Say ("  path   : " + $t.FullName)
        Say ("  bytes  : " + $t.Length)
        Say ("  sha256 : " + $th)

        # --- 3. Положительный контроль предиката: соседний пакет ----------
        $prev = @($found | Where-Object { $_.Name -like '08092026.0027*' })
        Say ("")
        Say ("положительный контроль поиска: копий 08092026.0027*_Full.zip = " + $prev.Count)
        if ($prev.Count -ge 1) {
            $ph = (Get-FileHash -LiteralPath $prev[0].FullName -Algorithm SHA256).Hash
            Say ("  прежний пакет sha256 : " + $ph)
            Say ("  хеши различаются     : " + ($ph -ne $th) + "   <-- должно быть True")
        } else {
            Say ("  прежнего пакета рядом нет — сравнение не делаю, о совпадении не заявляю")
        }
        Say ("")
        Say ("ВЕРДИКТ: замер снят. Это число идёт в бокс переноса как ожидаемое.")
    } else {
        Say ("ВЕРДИКТ: целевой пакет не опознан однозначно. В бокс переноса ничего не беру.")
    }
}

# --- 4. Запись файла замера -----------------------------------------------
$outDir = 'C:\RTMView-Ops\output'
if (-not (Test-Path -LiteralPath $outDir)) {
    $outDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$stamp   = (Get-Date).ToString('yyyyMMdd_HHmmss')
$outFile = Join-Path $outDir ("measure_LOCAL_" + $stamp + "_package-hash.txt")
[System.IO.File]::WriteAllLines($outFile, $lines, (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
Write-Host ("ФАЙЛ ЗАМЕРА: " + $outFile)
Write-Host ("строк: " + $lines.Count + ", байт: " + (Get-Item -LiteralPath $outFile).Length)
