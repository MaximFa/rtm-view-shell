# Update prod-release SKILL.md

## Контекст
Решение 2026-06-02: используется `deploy/Restore-SqlDump.ps1` для рестора БД.
Файл: `.claude/skills/prod-release/SKILL.md` (read-only для Cowork, CC пишет).

## ЗАПРЕТЫ
- Read-Host — ЗАПРЕЩЁН
- Интерактивные команды — ЗАПРЕЩЕНЫ

## Шаг 1 — Добавить секцию в SKILL.md

Python read->modify->write + os.fsync().
Найти последнюю строку файла:
  `Детали всех багов: файл памяти `feedback_prod_release_bugs.md`.`

Добавить после неё:

---

## DB Restore — Restore-SqlDump.ps1

Для установки БД используется `deploy/Restore-SqlDump.ps1`.

### Что делает скрипт
1. Автоопределяет формат дампа (PGDMP magic bytes = custom -> pg_restore; иначе psql)
2. Терминирует соединения с БД
3. Дропает и пересоздаёт БД
4. Восстанавливает из дампа
5. Создаёт/обновляет app user + grants
6. Запускает RTMService (если data.sys есть)

### Где лежит бекап
- Чистый бекап: `Installations/dump-rtmviewdb-YYYYMMDDHHMI.sql`
- Включается в zip при сборке (Mode=RTM или Full)
- Формат: pg_dump custom (-F c)

### Команда установки (RTM+DB)
```powershell
powershell -ExecutionPolicy Bypass -File deploy\Restore-SqlDump.ps1 `
    -DumpFile "Installations\dump-rtmviewdb-YYYYMMDDHHMI.sql" `
    -DBPassword "PG_SUPERUSER_PASSWORD" `
    -DBAppPassword "APP_USER_PASSWORD" `
    -StopService
```

### KNOWN BUGS при написании PS1 через Python
- Использовать raw-строки (r-strings) или обычные строки без backslash перед $
- Python не интерполирует $, но backslash+$ в строке даёт backslash+$ в файле
  -> PowerShell воспринимает как команду, не переменную
- $ErrorActionPreference = Continue на время pg_restore (stderr = нормальный progress)
- SQL: одинарные кавычки вокруг значений: '$DBName' внутри double-quoted PS строки
- BOM = b'\xef\xbb\xbf' (bytes literal); write в binary mode

---

## Шаг 2 — Git commit

```bash
bash tools/pre-commit-check.sh .claude/skills/prod-release/SKILL.md

cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add .claude/skills/prod-release/SKILL.md
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "docs: prod-release skill add Restore-SqlDump section"
cp /tmp/cc-idx .git/index
git log --oneline -1
```

## Шаг 3 — Resync

```bash
git show HEAD:".claude/skills/prod-release/SKILL.md" > ".claude/skills/prod-release/SKILL.md"
echo "Re-synced ($(wc -l < .claude/skills/prod-release/SKILL.md) lines)"
sync
```

## Сообщить результат
Хэш коммита + количество строк после добавления.
