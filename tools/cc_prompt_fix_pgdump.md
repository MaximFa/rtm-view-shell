# Fix: pg_dump --clean --if-exists + install restore guard

## Контекст
При установке на сервер с уже существующей БД pg_restore генерирует сотни ошибок
"relation already exists" / "duplicate key". Причина: pg_dump запускается без
--clean --if-exists, поэтому дамп не содержит DROP перед CREATE.

Два изменения:

### Изменение 1 — tools/Build-ProdRelease.ps1
Добавить флаги `--clean --if-exists` к команде pg_dump:

```
OLD: & pg_dump -h $DBHost -p $DBPort -U $DBUser -d $DBName -F p --no-password -f $dumpFile
NEW: & pg_dump -h $DBHost -p $DBPort -U $DBUser -d $DBName -F p --no-password --clean --if-exists -f $dumpFile
```

### Изменение 2 — deploy/Install-RTMView.ps1
После строки `Write-Host "  Restoring $($sqlFile.Name)..." -ForegroundColor Gray`
добавить перед вызовом psql:
```powershell
        Write-Host "  (using --clean dump: existing objects will be replaced)" -ForegroundColor Gray
```

И заменить вызов psql на вариант с `-v ON_ERROR_STOP=0` чтобы явно продолжать при ошибках
(это уже текущее поведение, но сделать явным):
```
OLD: & $psql -h $DBHost -p $DBPort -U $DBUser -d $DBName -f $sqlFile.FullName
NEW: & $psql -h $DBHost -p $DBPort -U $DBUser -d $DBName -v ON_ERROR_STOP=0 -f $sqlFile.FullName
```

Это не меняет логику, но документирует намерение (ошибки совместимости версий PG — игнорировать).

## ЗАПРЕТЫ
- Read-Host — ЗАПРЕЩЁН
- Интерактивные команды — ЗАПРЕЩЕНЫ

---

## Шаг 1 — Исправить tools/Build-ProdRelease.ps1

Python read→modify→write + os.fsync().

Найти строку:
```
& pg_dump -h $DBHost -p $DBPort -U $DBUser -d $DBName -F p --no-password -f $dumpFile
```

Заменить на:
```
& pg_dump -h $DBHost -p $DBPort -U $DBUser -d $DBName -F p --no-password --clean --if-exists -f $dumpFile
```

После записи: sync && grep "pg_dump" tools/Build-ProdRelease.ps1 | grep -v "#"

---

## Шаг 2 — Исправить deploy/Install-RTMView.ps1

Найти строку:
```
            & $psql -h $DBHost -p $DBPort -U $DBUser -d $DBName -f $sqlFile.FullName
```

Заменить на:
```
            & $psql -h $DBHost -p $DBPort -U $DBUser -d $DBName -v ON_ERROR_STOP=0 -f $sqlFile.FullName
```

После записи: sync && grep "ON_ERROR_STOP\|psql.*sqlFile" deploy/Install-RTMView.ps1

---

## Шаг 3 — Проверка

```bash
grep "pg_dump" tools/Build-ProdRelease.ps1 | grep "clean"
# Ожидаемый результат: строка содержит --clean --if-exists

grep "ON_ERROR_STOP" deploy/Install-RTMView.ps1
# Ожидаемый результат: строка содержит ON_ERROR_STOP=0
```

---

## Шаг 4 — Git commit

```bash
bash tools/pre-commit-check.sh tools/Build-ProdRelease.ps1 deploy/Install-RTMView.ps1

cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add tools/Build-ProdRelease.ps1 deploy/Install-RTMView.ps1
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix: pg_dump --clean --if-exists; psql ON_ERROR_STOP=0"
cp /tmp/cc-idx .git/index
git log --oneline -1
```

## Шаг 5 — Resync

```bash
for f in tools/Build-ProdRelease.ps1 deploy/Install-RTMView.ps1; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```

## Сообщить результат
Хэш коммита. Вывод grep-проверок из шага 3.
