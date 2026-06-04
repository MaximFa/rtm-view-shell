# Fix: DBName lowercase + null-safe psql check

## Контекст
Два дефекта, выявленных при установке на сервере:

**BUG-A** — `null-valued expression` в `deploy/Install-RTMView.ps1` шаг 5/6.
  Причина: `(& $psql ... 2>&1).Trim()` при `Set-StrictMode -Version Latest`
  падает если psql возвращает $null (пустой результат SELECT).

**BUG-B** — имя БД должно быть `rtmviewdb` (lowercase) везде:
  в скриптах-дефолтах, в appsettings, в документации.
  PostgreSQL без кавычек хранит идентификаторы lowercase — mixed-case имя требует
  кавычек при каждом обращении и вызывает путаницу.

## ЗАПРЕТЫ
- Read-Host — ЗАПРЕЩЁН
- Интерактивные команды — ЗАПРЕЩЕНЫ

---

## Шаг 1 — Исправить deploy/Install-RTMView.ps1

Внести следующие изменения через Python read→modify→write + os.fsync():

### 1a. Изменить default DBName (строка ~51)
```
OLD: [string]$DBName        = "RTMViewDB",
NEW: [string]$DBName        = "rtmviewdb",
```

### 1b. Null-safe проверка существования БД (строка ~227-228)
```
OLD:
        $exists = (& $psql -h $DBHost -p $DBPort -U $DBUser -d postgres -tAc `
            "SELECT 1 FROM pg_database WHERE datname='$DBName';" 2>&1).Trim()

NEW:
        $existsRaw = & $psql -h $DBHost -p $DBPort -U $DBUser -d postgres -tAc `
            "SELECT 1 FROM pg_database WHERE datname='$DBName';" 2>&1
        $exists = if ($existsRaw -ne $null) { "$existsRaw".Trim() } else { "" }
```

### 1c. Null-safe проверка существования пользователя (строка ~240-241)
```
OLD:
            $userExists = (& $psql -h $DBHost -p $DBPort -U $DBUser -d postgres -tAc `
                "SELECT 1 FROM pg_roles WHERE rolname='$DBAppUser';" 2>&1).Trim()

NEW:
            $userExistsRaw = & $psql -h $DBHost -p $DBPort -U $DBUser -d postgres -tAc `
                "SELECT 1 FROM pg_roles WHERE rolname='$DBAppUser';" 2>&1
            $userExists = if ($userExistsRaw -ne $null) { "$userExistsRaw".Trim() } else { "" }
```

### 1d. CREATE DATABASE без кавычек (lowercase) (строка ~233)
```
OLD: & $psql -h $DBHost -p $DBPort -U $DBUser -d postgres -c "CREATE DATABASE `"$DBName`" ENCODING 'UTF8';" | Out-Null
NEW: & $psql -h $DBHost -p $DBPort -U $DBUser -d postgres -c "CREATE DATABASE $DBName ENCODING 'UTF8';" | Out-Null
```

После записи: sync && tail -3 deploy/Install-RTMView.ps1 && wc -l deploy/Install-RTMView.ps1

---

## Шаг 2 — Изменить default DBName в tools/Build-ProdRelease.ps1

```
OLD: [string]$DBName      = "RTMViewDB",
NEW: [string]$DBName      = "rtmviewdb",
```

Также в комментарии pg_dump строки:
```
OLD:      3. pg_dump RTMViewDB               -> publish\db\
NEW:      3. pg_dump rtmviewdb               -> publish\db\
```

После записи: tail -3 tools/Build-ProdRelease.ps1

---

## Шаг 3 — Изменить RTM appsettings.json (основной источник)

Файл: `RTM/RTM/appsettings.json`
```
OLD: "RTMConnectionString": "Host=localhost;Port=5432;Database=RTMViewDB;...
NEW: "RTMConnectionString": "Host=localhost;Port=5432;Database=rtmviewdb;...
```

После записи: grep -i "database=" RTM/RTM/appsettings.json

---

## Шаг 4 — Изменить Shell appsettings.json (основной источник)

Файл: `src/CcDashboard.Web/appsettings.json`
```
OLD: "Database=RTMViewDB;
NEW: "Database=rtmviewdb;
```

Файл: `src/CcDashboard.Web/appsettings.Development.json`
```
OLD: "Database=RTMViewDB;
NEW: "Database=rtmviewdb;
```

---

## Шаг 5 — RTM deployment appsettings

Файл: `RTM/deployment/publish/appsettings.json`
```
OLD: "Database=RTMViewDB;
NEW: "Database=rtmviewdb;
```

Файл: `RTM/deployment/Restore-RTMDb.ps1`
```
OLD: [string]$DbName = "RTMViewDB",
NEW: [string]$DbName = "rtmviewdb",
```

---

## Шаг 6 — deploy/README.txt

Заменить все вхождения `RTMViewDB` на `rtmviewdb` в этом файле.

---

## Шаг 7 — Прочие инструменты

Файл: `tools/Export-SimulatorDB.ps1`
```
OLD: [string]$DBName     = "RTMViewDB",
NEW: [string]$DBName     = "rtmviewdb",
```

Файл: `tools/Install-CcDashboard.ps1`
```
OLD: [string]$DBName               = "RTMViewDB",
NEW: [string]$DBName               = "rtmviewdb",
```

Файл: `tools/Uninstall-CcDashboard.ps1`
```
OLD: [string]$DBName = "RTMViewDB",
NEW: [string]$DBName = "rtmviewdb",
```

---

## Шаг 8 — Проверка

```powershell
# Убедиться что RTMViewDB не осталось в источниках (bin/ не считается)
grep -rn "RTMViewDB" --include="*.ps1" --include="*.json" --include="*.txt" \
    deploy/ tools/ RTM/RTM/ RTM/deployment/ src/CcDashboard.Web/ \
    | grep -v "bin/" | grep -v "obj/"
```

Ожидаемый результат: пустой вывод (нет вхождений в источниках).

---

## Шаг 9 — Git commit

```bash
# Pre-commit check
bash tools/pre-commit-check.sh deploy/Install-RTMView.ps1 tools/Build-ProdRelease.ps1 \
    RTM/RTM/appsettings.json src/CcDashboard.Web/appsettings.json \
    src/CcDashboard.Web/appsettings.Development.json

# Если exit code 0:
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add deploy/Install-RTMView.ps1 tools/Build-ProdRelease.ps1 \
    RTM/RTM/appsettings.json RTM/deployment/publish/appsettings.json \
    RTM/deployment/Restore-RTMDb.ps1 src/CcDashboard.Web/appsettings.json \
    src/CcDashboard.Web/appsettings.Development.json deploy/README.txt \
    tools/Export-SimulatorDB.ps1 tools/Install-CcDashboard.ps1 tools/Uninstall-CcDashboard.ps1
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix: lowercase rtmviewdb, null-safe psql check in Install script"
cp /tmp/cc-idx .git/index
git log --oneline -1
```

## Шаг 10 — Resync

```bash
for f in deploy/Install-RTMView.ps1 tools/Build-ProdRelease.ps1 \
    RTM/RTM/appsettings.json src/CcDashboard.Web/appsettings.json \
    src/CcDashboard.Web/appsettings.Development.json; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```

## Сообщить результат

- Список изменённых файлов
- Результат grep-проверки (шаг 8)
- Хэш коммита
