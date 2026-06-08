# RTM Simulator Installer Skill

> Полный цикл: от dev-сборки до работающего Windows Service на целевой машине.
> Основан на сессии 2026-05-28. Использовать в начале любой сборки/деплоя пакета.

---

## Что даёт этот скилл

- Чёткий порядок шагов: экспорт БД → сборка ZIP → деплой на целевой машине
- Список известных ловушек и их решений (psql, PowerShell, PostgreSQL, права)
- Готовые команды для ручного деплоя если скрипт не справляется

---

## Часть 1 — Подготовка пакета (dev-машина)

### Шаг 1.1 — Экспорт БД

```powershell
# Из корня проекта:
.\tools\Export-SimulatorDB.ps1
# Результат: tools\simulator_db.dump (custom format, --no-owner --no-acl)
```

**Ловушка:** pg_dump может не найтись автоматически.
Решение: передать явный путь `-PGBinPath "C:\Program Files\PostgreSQL\18\bin"`.

### Шаг 1.2 — Сборка ZIP

```powershell
.\tools\Build-SimulatorPackage.ps1
# Результат: publish\RTMViewShell-Simulator.zip
```

Что попадает в ZIP:
- `CcDashboard.Web.exe` + все DLL (self-contained, win-x64)
- `SignalRSimulator\SignalRSimulator.exe` + все DLL
- `tools\simulator_db.dump`
- `tools\Install-CcDashboard.ps1`
- `tools\Uninstall-CcDashboard.ps1`
- `INSTALL-SIMULATOR.md`

---

## Часть 2 — Деплой на целевой машине

### Предварительные требования

| Компонент | Версия | Примечание |
|---|---|---|
| PostgreSQL | 15–18 | EDB installer или официальный MSI |
| Memurai | LTS | Redis-совместимый, работает как Windows Service |
| .NET 8 | Не нужен | self-contained publish включает runtime |

### Шаг 2.1 — Распаковка

Распаковать ZIP в `C:\Program Files\CcDashboard\`.

### Шаг 2.2 — Запуск Install-CcDashboard.ps1

```powershell
# PowerShell от имени Administrator
Set-ExecutionPolicy Bypass -Scope Process
.\Install-CcDashboard.ps1
```

---

## Часть 3 — Ручной деплой (если скрипт не справляется)

Эта последовательность отлажена на реальной установке 2026-05-28.

### 3.1 — Создать пользователя и БД PostgreSQL

```sql
-- в psql -U postgres
CREATE USER ccdashboard_user WITH PASSWORD '!@#qweASDzxc';
CREATE DATABASE rtmviewdb OWNER ccdashboard_user;
```

**КРИТИЧНО:** PostgreSQL хранит имена БД в нижнем регистре.
`CREATE DATABASE RTMViewDB` → хранится как `rtmviewdb`.
Все дальнейшие обращения — только через `rtmviewdb` (строчные).

### 3.2 — Restore из дампа

```powershell
$pgRestore = "C:\Program Files\PostgreSQL\18\bin\pg_restore.exe"
& $pgRestore -U postgres -d rtmviewdb --no-owner --no-acl -F c "C:\Program Files\CcDashboard\simulator_db.dump"
```

Запускать от имени postgres (суперпользователь). Ошибки "already exists" — норма (идемпотентность).

### 3.3 — Выдать права ccdashboard_user

**Это обязательный шаг после restore с --no-acl!**

```powershell
$sql = "GRANT USAGE ON SCHEMA public TO ccdashboard_user; " +
       "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ccdashboard_user; " +
       "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ccdashboard_user; " +
       "GRANT USAGE ON SCHEMA identity TO ccdashboard_user; " +
       "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA identity TO ccdashboard_user; " +
       "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA identity TO ccdashboard_user; " +
       "GRANT USAGE ON SCHEMA audit TO ccdashboard_user; " +
       "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA audit TO ccdashboard_user; " +
       "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA audit TO ccdashboard_user;"
[System.IO.File]::WriteAllText("$env:TEMP\grant.sql", $sql, [System.Text.Encoding]::ASCII)
psql -U postgres -d rtmviewdb -f "$env:TEMP\grant.sql"
```

**Почему файл, а не -c:** psql -c с кавычками в PowerShell — стабильно ломается.
Всегда писать SQL в файл через `[System.IO.File]::WriteAllText(..., [System.Text.Encoding]::ASCII)`.

### 3.4 — Обновить SignalRConnectionUrl

```powershell
[System.IO.File]::WriteAllText(
    "$env:TEMP\fix_url.sql",
    "UPDATE tenant_settings SET ""SignalRConnectionUrl"" = 'http://localhost:5001';",
    [System.Text.Encoding]::ASCII)
psql -U postgres -d rtmviewdb -f "$env:TEMP\fix_url.sql"
```

**Почему двойные кавычки в имени колонки:** PostgreSQL хранит идентификаторы в нижнем
регистре если не заключены в двойные кавычки при создании. `SignalRConnectionUrl` была
создана с кавычками → регистр сохранён → при обращении нужны кавычки.

### 3.5 — Исправить строку подключения в appsettings.json

```powershell
$path = "C:\Program Files\CcDashboard\appsettings.json"
$content = [System.IO.File]::ReadAllText($path)
$content = $content.Replace("Database=RTMViewDB", "Database=rtmviewdb")
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
```

### 3.6 — Зарегистрировать Windows Services

```powershell
New-Service -Name "CcDashboard" `
    -BinaryPathName "C:\Program Files\CcDashboard\CcDashboard.Web.exe" `
    -DisplayName "CC Dashboard" -StartupType Automatic

New-Service -Name "CcDashboardSignalR" `
    -BinaryPathName "C:\Program Files\CcDashboard\SignalRSimulator\SignalRSimulator.exe" `
    -DisplayName "CC Dashboard SignalR Simulator" -StartupType Automatic
```

**Не использовать sc.exe create:** синтаксис кавычек в PowerShell → sc.exe выводит help
вместо того чтобы создать сервис. `New-Service` работает корректно.

### 3.7 — Установить переменные среды для сервисов (реестр)

```powershell
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CcDashboard" `
    -Name "Environment" -PropertyType MultiString `
    -Value @("ASPNETCORE_ENVIRONMENT=Development", "ASPNETCORE_URLS=http://localhost:5000") -Force

New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CcDashboardSignalR" `
    -Name "Environment" -PropertyType MultiString `
    -Value @("ASPNETCORE_ENVIRONMENT=Development", "ASPNETCORE_URLS=http://localhost:5001") -Force
```

**Почему реестр:** Windows Services не наследуют env переменные из сессии.
Единственный надёжный способ — `HKLM:\SYSTEM\CurrentControlSet\Services\<name>\Environment`.

### 3.8 — Запустить сервисы

```powershell
Start-Service CcDashboardSignalR
Start-Sleep -Seconds 2
Start-Service CcDashboard
Start-Sleep -Seconds 5
Get-Service CcDashboard, CcDashboardSignalR
```

SignalR запускать первым — основное приложение подключается к нему при старте.

---

## Часть 4 — Диагностика при сбоях

### Тест без сервиса (видны все ошибки)

```powershell
$env:ASPNETCORE_ENVIRONMENT = "Development"
cd "C:\Program Files\CcDashboard"
.\CcDashboard.Web.exe
```

**ОБЯЗАТЕЛЬНО:** установить `$env:ASPNETCORE_ENVIRONMENT = "Development"` ДО запуска exe,
иначе Production-проверки упадут с ошибкой.

### Типичные ошибки и решения

| Ошибка | Причина | Решение |
|---|---|---|
| `Default seed password detected in production` | ASPNETCORE_ENVIRONMENT не Development | Установить env var до запуска |
| `permission denied for table __ef_migrations_history` | restore с --no-acl, права не выданы | Шаг 3.3 — GRANT ALL на все схемы |
| `database "RTMViewDB" does not exist` | PostgreSQL хранит имя в нижнем регистре | Использовать `rtmviewdb` везде |
| `ï»¿UPDATE` или BOM-ошибки в psql | PowerShell Out-File/WriteAllText пишет BOM | Писать через ASCII encoding или utf-8-sig для PS1 |
| psql -c с кавычками → "extra argument" | PowerShell экранирование ломает команду | Всегда использовать -f с SQL-файлом |
| sc.exe create выводит USAGE | Кавычки не пропускаются в sc.exe | Использовать New-Service |
| pg_dump не найден | PostgreSQL 18, нестандартный путь | Передать -PGBinPath явно |
| Null-valued on .Trim() | psql возвращает $null если БД не существует | Проверять null перед .Trim() |

---

## Часть 5 — PowerShell best practices для psql

### Золотое правило: всегда файл, никогда -c

```powershell
# ПРАВИЛЬНО — ASCII, нет BOM, работает всегда
[System.IO.File]::WriteAllText("$env:TEMP\query.sql", "SELECT 1;", [System.Text.Encoding]::ASCII)
psql -U postgres -d rtmviewdb -f "$env:TEMP\query.sql"

# НЕПРАВИЛЬНО — BOM, сломанные кавычки, непредсказуемый результат
psql -U postgres -d rtmviewdb -c "SELECT \"column\" FROM table;"
Out-File / Set-Content   # всегда BOM в PowerShell 5.x
```

### Изменение JSON-конфига без BOM

```powershell
$content = [System.IO.File]::ReadAllText($path)
$content = $content.Replace("old", "new")
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
```

### PowerShell скрипты (.ps1) — должны быть UTF-8 BOM

Парадокс: PS1-файлы PowerShell 5.x **требуют** BOM для корректного парсинга Unicode.
SQL-файлы — только ASCII, никакого BOM.

В Python: `open(path, "w", encoding="utf-8-sig")` для PS1-файлов.

---

## Часть 6 — После успешного деплоя

Проверить доступность:
- `http://localhost:5000` — основное приложение
- `http://localhost:5001` — SignalR Simulator (должен отвечать)

Учётные данные Superadmin:
- Email: `admin@platform.local`
- Пароль: тот что в dev БД на момент создания дампа (не из appsettings!)

**Важно:** seed-пароль в appsettings (`Seed:SuperadminPassword`) используется только при
первоначальном seed пустой БД. После restore из дампа — пароль из дампа.

---

## Часть 7 — Что нужно починить в Install-CcDashboard.ps1

После отладки 2026-05-28 выявлены баги которые нужно исправить в скрипте:

1. **DB name case:** использовать `$DBNamePG = $DBName.ToLower()` везде
2. **GRANT после restore:** добавить блок GRANT ALL на все три схемы (public, identity, audit)
3. **SignalRConnectionUrl:** использовать файл ASCII вместо psql -c
4. **appsettings.json:** replace `Database=RTMViewDB` → `Database=rtmviewdb`
5. **Проверка null от psql:** `if ($raw) { $raw.Trim() } else { "" }`
