# Build package v2: DumpFile param, Restore-SqlDump, log4net, data.sys, AdaptorServiceName

## Контекст
Комплекс изменений для правильной сборки RTM+DB пакета:
1. appsettings: добавить AdaptorServiceName в секцию RTM
2. Build-ProdRelease.ps1: параметр -DumpFile (готовый дамп вместо pg_dump) + включить Restore-SqlDump.ps1 + log4net.config + data.sys в zip
3. Install-RTMView.ps1: заменить inline psql рестор на вызов Restore-SqlDump.ps1

## ЗАПРЕТЫ
- Read-Host — ЗАПРЕЩЁН
- Интерактивные команды — ЗАПРЕЩЕНЫ

---

## Шаг 1 — RTM/RTM/appsettings.json: добавить AdaptorServiceName

Python read->modify->write + os.fsync().

Найти в секции RTM строку:
    "TenantId": "00000000-0000-0000-0000-000000000000"

Заменить на:
    "TenantId": "00000000-0000-0000-0000-000000000000",
    "AdaptorServiceName": "RTMView.Nayax"

После записи: grep -A 8 '"RTM"' RTM/RTM/appsettings.json

---

## Шаг 2 — tools/Build-ProdRelease.ps1: добавить -DumpFile параметр

Python read->modify->write + os.fsync().

### 2a. Добавить параметр -DumpFile в блок param()

Найти:
    [switch]$SkipDB,

Заменить на:
    [switch]$SkipDB,
    [string]$DumpFile    = "",

### 2b. Заменить шаг 3 (pg_dump) на логику с DumpFile

Найти блок (целиком):
```
if (-not $SkipDB) {
    Write-Host "[ 3/4 ] Running pg_dump for $DBName..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $PublishDB -Force | Out-Null
    $dumpFile = Join-Path $PublishDB ("$DBName`_" + (Get-Date -Format "ddMMyyyy") + ".sql")

    $env:PGPASSWORD = $DBPassword
    & pg_dump -h $DBHost -p $DBPort -U $DBUser -d $DBName -F p --no-password --clean --if-exists -f $dumpFile
    $env:PGPASSWORD = ""

    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $dumpFile)) {
        Write-Host "  [WARN] pg_dump failed. DB backup will not be included." -ForegroundColor Yellow
    } else {
        $sizeMB = [math]::Round((Get-Item $dumpFile).Length / 1MB, 2)
        Write-Host "  Dump  : $dumpFile ($sizeMB MB)" -ForegroundColor Green
    }
} else {
    Write-Host "[ 3/4 ] DB backup skipped." -ForegroundColor Yellow
}
```

Заменить на:
```
if ($DumpFile -ne "" -and (Test-Path $DumpFile)) {
    Write-Host "[ 3/4 ] Using existing dump: $DumpFile" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $PublishDB -Force | Out-Null
    $destDump = Join-Path $PublishDB ([System.IO.Path]::GetFileName($DumpFile))
    Copy-Item $DumpFile -Destination $destDump -Force
    $sizeMB = [math]::Round((Get-Item $destDump).Length / 1MB, 2)
    Write-Host "  Dump  : $destDump ($sizeMB MB)" -ForegroundColor Green
} elseif (-not $SkipDB) {
    Write-Host "[ 3/4 ] Running pg_dump for $DBName..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $PublishDB -Force | Out-Null
    $pgDumpFile = Join-Path $PublishDB ("$DBName`_" + (Get-Date -Format "ddMMyyyy") + ".sql")

    $env:PGPASSWORD = $DBPassword
    & pg_dump -h $DBHost -p $DBPort -U $DBUser -d $DBName -F c --no-password -f $pgDumpFile
    $env:PGPASSWORD = ""

    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $pgDumpFile)) {
        Write-Host "  [WARN] pg_dump failed. DB backup will not be included." -ForegroundColor Yellow
    } else {
        $sizeMB = [math]::Round((Get-Item $pgDumpFile).Length / 1MB, 2)
        Write-Host "  Dump  : $pgDumpFile ($sizeMB MB)" -ForegroundColor Green
    }
} else {
    Write-Host "[ 3/4 ] DB backup skipped." -ForegroundColor Yellow
}
```

### 2c. Добавить Restore-SqlDump.ps1 + data.sys + log4net.config в zip

Найти блок:
```
# Deploy scripts and README
foreach ($f in @("Install-RTMView.ps1", "Update-RTMView.ps1", "README.txt")) {
    $src = Join-Path $DeployDir $f
    if (Test-Path $src) {
        Copy-Item $src -Destination $StagingDir -Force
```

Заменить на:
```
# Deploy scripts, Restore script and README
foreach ($f in @("Install-RTMView.ps1", "Update-RTMView.ps1", "Restore-SqlDump.ps1", "README.txt")) {
    $src = Join-Path $DeployDir $f
    if (Test-Path $src) {
        Copy-Item $src -Destination $StagingDir -Force
```

Также после блока добавления app.dat (найти строку `Write-Host "  + RTM/app.dat"`), добавить:

```
    # data.sys
    $dataSysSrc = Join-Path $Root "RTM\deployment\data.sys"
    if (Test-Path $dataSysSrc) {
        Copy-Item $dataSysSrc -Destination $stgRTM -Force
        Write-Host "  + RTM/data.sys" -ForegroundColor Gray
    } else {
        Write-Host "  [WARN] RTM\deployment\data.sys not found" -ForegroundColor Yellow
    }

    # log4net.config — from published output
    $log4netSrc = Join-Path $PublishRTM "log4net.config"
    if (Test-Path $log4netSrc) {
        Copy-Item $log4netSrc -Destination $stgRTM -Force
        Write-Host "  + RTM/log4net.config" -ForegroundColor Gray
    } else {
        Write-Host "  [WARN] log4net.config not found in publish\rtm\" -ForegroundColor Yellow
    }
```

После записи:
```bash
sync && grep -n "DumpFile\|Restore-SqlDump\|data.sys\|log4net" tools/Build-ProdRelease.ps1 | grep -v "#"
```

---

## Шаг 3 — deploy/Install-RTMView.ps1: заменить шаг 5 на Restore-SqlDump.ps1

Python read->modify->write + os.fsync().

Найти весь блок шага 5 (начиная с `# 5a`) до конца секции DB:

Найти строку:
```
        # 5a — Create database if not exists
```

И до (включительно):
```
            Write-Host "  No SQL backup found in DB\ — skipping restore." -ForegroundColor Gray
        }
```

Заменить всё это на:
```
        # 5 — Restore via Restore-SqlDump.ps1
        $restoreScript = Join-Path $ScriptDir "Restore-SqlDump.ps1"
        $dbDumpFile = Get-ChildItem -Path (Join-Path $ScriptDir "DB") -ErrorAction SilentlyContinue |
                      Sort-Object Name -Descending | Select-Object -First 1
        if (-not (Test-Path $restoreScript)) {
            Write-Host "  [WARN] Restore-SqlDump.ps1 not found — skipping DB restore." -ForegroundColor Yellow
        } elseif (-not $dbDumpFile) {
            Write-Host "  [WARN] No dump file found in DB\ — skipping DB restore." -ForegroundColor Yellow
        } else {
            Write-Host "  Calling Restore-SqlDump.ps1 with $($dbDumpFile.Name)..." -ForegroundColor Gray
            $prevPref = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            & powershell -ExecutionPolicy Bypass -File $restoreScript `
                -DumpFile $dbDumpFile.FullName `
                -DBPassword $DBPassword `
                -DBAppUser $DBAppUser `
                -DBAppPassword $DBAppPassword
            $ErrorActionPreference = $prevPref
        }
```

После записи: grep -n "Restore-SqlDump\|5a\|5b\|5c" deploy/Install-RTMView.ps1

---

## Шаг 4 — Верификация

```bash
# appsettings содержит AdaptorServiceName
grep "AdaptorServiceName" RTM/RTM/appsettings.json

# Build содержит DumpFile параметр
grep "DumpFile" tools/Build-ProdRelease.ps1 | grep -v "#" | head -5

# Install использует Restore-SqlDump
grep "Restore-SqlDump" deploy/Install-RTMView.ps1
```

---

## Шаг 5 — Git commit

```bash
bash tools/pre-commit-check.sh \
    RTM/RTM/appsettings.json \
    tools/Build-ProdRelease.ps1 \
    deploy/Install-RTMView.ps1

cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
    RTM/RTM/appsettings.json \
    tools/Build-ProdRelease.ps1 \
    deploy/Install-RTMView.ps1
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "feat: package v2 - DumpFile param, Restore-SqlDump in Install, data.sys, log4net, AdaptorServiceName"
cp /tmp/cc-idx .git/index
git log --oneline -1
```

## Шаг 6 — Resync

```bash
for f in RTM/RTM/appsettings.json tools/Build-ProdRelease.ps1 deploy/Install-RTMView.ps1; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```

## Сообщить результат
- Хэш коммита
- Вывод grep-проверок из шага 4
