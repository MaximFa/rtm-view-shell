# Fix: Install-RTMView.ps1 — stop only services relevant to Mode

## Проблема
В шаге [3/6] скрипт останавливает и удаляет ОБА сервиса (RTMViewShell + RTMService)
независимо от Mode. При Mode=Shell удаляется RTMService — это неверно.

## Исправление — deploy/Install-RTMView.ps1

Python read->modify->write + os.fsync().

Найти:
```
foreach ($svcName in @($ShellSvcName, $RTMSvcName)) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) {
        Stop-Service $svcName -Force -ErrorAction SilentlyContinue
        sc.exe delete $svcName | Out-Null
        Start-Sleep 2
        Write-Host "  Removed: $svcName" -ForegroundColor Gray
    }
}
```

Заменить на:
```
$svcsToStop = @()
if ($InstallShell) { $svcsToStop += $ShellSvcName }
if ($InstallRTM)   { $svcsToStop += $RTMSvcName }
foreach ($svcName in $svcsToStop) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) {
        Stop-Service $svcName -Force -ErrorAction SilentlyContinue
        sc.exe delete $svcName | Out-Null
        Start-Sleep 2
        Write-Host "  Removed: $svcName" -ForegroundColor Gray
    }
}
```

После записи: grep -n "svcsToStop\|InstallShell\|InstallRTM" deploy/Install-RTMView.ps1 | head -10

## Git commit

```bash
bash tools/pre-commit-check.sh deploy/Install-RTMView.ps1

cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add deploy/Install-RTMView.ps1
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix: Install-RTMView stop only Mode-relevant services"
cp /tmp/cc-idx .git/index
git log --oneline -1
```

## Resync

```bash
git show HEAD:"deploy/Install-RTMView.ps1" > "deploy/Install-RTMView.ps1"
echo "Re-synced ($(wc -l < deploy/Install-RTMView.ps1) lines)"
sync
```

## Сообщить результат
Хэш коммита + вывод grep.
