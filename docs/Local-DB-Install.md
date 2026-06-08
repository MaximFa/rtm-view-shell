# Локальная установка БД — RTM View Shell

> Метод: **Restore-All из git** (чистая БД из `db/`: schema + functions + data).
> EF-миграции и собранный Shell НЕ нужны — `schema.sql` самодостаточен.
> PostgreSQL 18 установлен локально. Все пароли: `!@#qweASDzxc`.
> Проверено 2026-06-08: 59 таблиц, 202 метрики, seed platform/superadmin OK.

## 0. Путь к psql (PG18)

`psql` не в PATH, поэтому везде используем полный путь:

```powershell
$psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
```

## 1. Установка БД (пересоздание с нуля)

```powershell
cd "C:\Claude\Projects\RTM View Shell"
powershell -ExecutionPolicy Bypass -File "db\tools\Restore-All.ps1" `
  -SuperPassword "!@#qweASDzxc" `
  -AppPassword "!@#qweASDzxc" `
  -DropAndRecreate
```

Скрипт сам находит psql/dropdb/createdb в `C:\Program Files\PostgreSQL\{18,17,16,15}\bin`.
Порядок: terminate connections -> dropdb -> createdb -> 01_init_db.sql (extensions + user)
-> schema.sql -> ownership -> functions/ -> data/ -> grants.

## 2. Пароль app-юзера (ОБЯЗАТЕЛЬНО при установке начисто)

`01_init_db.sql` создаёт `ccdashboard_user` с паролем `CHANGE_ME` (параметр
`-AppPassword` в Restore-All на пароль НЕ влияет — он только в грантах).
Если юзер создаётся впервые — выставить реальный пароль от postgres:

```powershell
$psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
$env:PGPASSWORD="!@#qweASDzxc"
& $psql -h localhost -U postgres -d rtmviewdb -c "ALTER USER ccdashboard_user WITH PASSWORD '!@#qweASDzxc';"
$env:PGPASSWORD=""
```

Симптом «забыли пароль»: `FATAL: password authentication failed for user "ccdashboard_user"`.

## 3. Проверка

ВАЖНО про кавычки и кодировку:
- Идентификаторы регистрозависимые PascalCase (`"RTSGrid_Metric"`, `"Slug"`, `"Email"`)
  и требуют двойных кавычек.
- НЕ передавай SQL с двойными кавычками через `-c` — PowerShell их съедает.
- НЕ используй `Set-Content -Encoding UTF8` (Windows PS 5.1 добавляет BOM, ломает строку 1).
- Правильно: записать SQL в файл `-Encoding ascii` и выполнить через `-f`.

```powershell
$psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
$sql = @'
SELECT count(*) AS metric_count FROM "RTSGrid_Metric";
SELECT "Slug","Status" FROM tenants;
SELECT "Email" FROM identity.users;
\dn
'@
$sql | Set-Content -Path "$env:TEMP\rtm_check.sql" -Encoding ascii
$env:PGPASSWORD="!@#qweASDzxc"
& $psql -h localhost -U ccdashboard_user -d rtmviewdb -f "$env:TEMP\rtm_check.sql"
$env:PGPASSWORD=""
```

Ожидаемый результат (эталон 2026-06-08):
- `metric_count` = **202**
- tenants: `platform` / `Active`
- identity.users: `admin@platform.local`
- схемы: `public`, `identity`, `audit`

Быстрый список таблиц (без кавычек, безопасно):

```powershell
& $psql -h localhost -U ccdashboard_user -d rtmviewdb -c "\dt public.*"
```

## 4. Строка подключения (appsettings)

```
Host=localhost;Port=5432;Database=rtmviewdb;Username=ccdashboard_user;Password=!@#qweASDzxc
```

## 5. Альтернативы (для справки)

- **Restore-SqlDump.ps1** — восстановление из готового дампа
  `Installations/dump-rtmviewdb-202606041735.sql` (быстрый снимок от 04.06).
- **Create-FreshDb.ps1** — с нуля через EF-миграции (нужен `CcDashboard.Web.exe`).

---
*Создано: 2026-06-08. Метод по умолчанию — Restore-All из git. Проверки: SQL-файл + `-f` (ascii, без BOM).*
