# Build Shell-only package (Mode=Shell, no DB, no RTM)

## ЗАПРЕТЫ
- Read-Host — ЗАПРЕЩЁН
- Интерактивные команды — ЗАПРЕЩЕНЫ

## Шаг 1 — Сборка

```powershell
cd "D:\Claude\Projects\RTM View Shell"
.\tools\Build-ProdRelease.ps1 -Mode Shell -SkipDB
```

Дождись завершения. Успех = последняя строка содержит `╚` или `Done`.
При ошибке — показать последние 30 строк вывода и остановиться.

## Шаг 2 — Проверить zip

```powershell
$zip = Get-ChildItem "Installations\*_Shell.zip" | Sort-Object LastWriteTime -Desc | Select-Object -First 1
if ($zip) {
    Write-Host "ZIP: $($zip.FullName)  $([math]::Round($zip.Length/1MB,1)) MB"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $e = [System.IO.Compression.ZipFile]::OpenRead($zip.FullName).Entries.FullName
    @("Install-RTMView.ps1","Update-RTMView.ps1","README.txt") | ForEach-Object {
        Write-Host "$(if ($_ -in $e){'[OK]  '}else{'[MISS]'}) $_"
    }
    Write-Host "Shell bins: $(($e -like 'Shell/*').Count)"
    Write-Host "RTM bins:   $(($e -like 'RTM/*').Count)  (должно быть 0)"
    Write-Host "DB files:   $(($e -like 'DB/*').Count)   (должно быть 0)"
} else {
    Write-Host "[ERROR] ZIP not found"
}
```

## Шаг 3 — Сообщить результат

Путь к zip, размер, Shell bins, RTM bins (должно быть 0), DB files (должно быть 0).
