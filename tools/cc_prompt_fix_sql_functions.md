# Fix: SQL functions TenantId+OnDate signatures + Timer overflow

## Контекст
Два дефекта в RTM Service:

**BUG-A** — `02_rtsdata_functions.sql`: функции `RTSData_getInteractions` и
`RTSData_getUsersStatuses` определены как `(p_tenant_id uuid)`, но C# (DBMng.cs)
вызывает их с двумя параметрами `(@OnDate text, @TenantId uuid)`.
Нужно добавить `p_on_date text` как первый параметр + фильтр WHERE по OnDate.

**BUG-B** — `Engine.cs` ScheduleNextCheck(): когда `nextClearTime = DateTime.MaxValue`
(no union configured), `dueTime` = ~2516 лет → переполняет Timer max (4294967294 ms).
Нужен cap или ранний return.

## ЗАПРЕТЫ
- Read-Host — ЗАПРЕЩЁН
- Интерактивные команды — ЗАПРЕЩЕНЫ

---

## Шаг 1 — Исправить RTM/sql/pgsql/02_rtsdata_functions.sql

Python read→modify→write + os.fsync().

### 1a. RTSData_GetInteractions: добавить p_on_date

Найти и заменить блок DROP+CREATE для RTSData_GetInteractions (основная функция):

OLD:
```
DROP FUNCTION IF EXISTS "RTSData_GetInteractions"();
DROP FUNCTION IF EXISTS "RTSData_GetInteractions"(uuid);

CREATE OR REPLACE FUNCTION "RTSData_GetInteractions"(p_tenant_id uuid)
```
(включая всё тело до строки)
```
    WHERE i."TenantId" = p_tenant_id;
```

NEW:
```
DROP FUNCTION IF EXISTS "RTSData_GetInteractions"();
DROP FUNCTION IF EXISTS "RTSData_GetInteractions"(uuid);
DROP FUNCTION IF EXISTS "RTSData_GetInteractions"(text, uuid);

CREATE OR REPLACE FUNCTION "RTSData_GetInteractions"(p_on_date text, p_tenant_id uuid)
```
(тело функции то же, но WHERE меняется)
```
    WHERE i."TenantId" = p_tenant_id
      AND i."OnDate" = p_on_date;
```

### 1b. RTSData_getInteractions (lowercase alias): добавить p_on_date

OLD:
```
DROP FUNCTION IF EXISTS "RTSData_getInteractions"();
DROP FUNCTION IF EXISTS "RTSData_getInteractions"(uuid);

CREATE OR REPLACE FUNCTION "RTSData_getInteractions"(p_tenant_id uuid)
```
(тело)
```
AS $$ SELECT * FROM "RTSData_GetInteractions"(p_tenant_id); $$;
```

NEW:
```
DROP FUNCTION IF EXISTS "RTSData_getInteractions"();
DROP FUNCTION IF EXISTS "RTSData_getInteractions"(uuid);
DROP FUNCTION IF EXISTS "RTSData_getInteractions"(text, uuid);

CREATE OR REPLACE FUNCTION "RTSData_getInteractions"(p_on_date text, p_tenant_id uuid)
```
(тело)
```
AS $$ SELECT * FROM "RTSData_GetInteractions"(p_on_date, p_tenant_id); $$;
```

### 1c. RTSData_GetUsersStatuses: добавить p_on_date

OLD:
```
DROP FUNCTION IF EXISTS "RTSData_GetUsersStatuses"();
DROP FUNCTION IF EXISTS "RTSData_GetUsersStatuses"(uuid);

CREATE OR REPLACE FUNCTION "RTSData_GetUsersStatuses"(p_tenant_id uuid)
```
(тело до)
```
    WHERE s."TenantId" = p_tenant_id;
```

NEW:
```
DROP FUNCTION IF EXISTS "RTSData_GetUsersStatuses"();
DROP FUNCTION IF EXISTS "RTSData_GetUsersStatuses"(uuid);
DROP FUNCTION IF EXISTS "RTSData_GetUsersStatuses"(text, uuid);

CREATE OR REPLACE FUNCTION "RTSData_GetUsersStatuses"(p_on_date text, p_tenant_id uuid)
```
(тело то же, WHERE меняется)
```
    WHERE s."TenantId" = p_tenant_id
      AND s."OnDate" = p_on_date;
```

### 1d. RTSData_getUsersStatuses (lowercase alias): добавить p_on_date

OLD:
```
DROP FUNCTION IF EXISTS "RTSData_getUsersStatuses"();
DROP FUNCTION IF EXISTS "RTSData_getUsersStatuses"(uuid);

CREATE OR REPLACE FUNCTION "RTSData_getUsersStatuses"(p_tenant_id uuid)
```
(тело)
```
AS $$ SELECT * FROM "RTSData_GetUsersStatuses"(p_tenant_id); $$;
```

NEW:
```
DROP FUNCTION IF EXISTS "RTSData_getUsersStatuses"();
DROP FUNCTION IF EXISTS "RTSData_getUsersStatuses"(uuid);
DROP FUNCTION IF EXISTS "RTSData_getUsersStatuses"(text, uuid);

CREATE OR REPLACE FUNCTION "RTSData_getUsersStatuses"(p_on_date text, p_tenant_id uuid)
```
(тело)
```
AS $$ SELECT * FROM "RTSData_GetUsersStatuses"(p_on_date, p_tenant_id); $$;
```

После записи:
```bash
sync && grep -n "CREATE OR REPLACE FUNCTION.*getInteractions\|CREATE OR REPLACE FUNCTION.*getUsersStatuses\|CREATE OR REPLACE FUNCTION.*GetInteractions\|CREATE OR REPLACE FUNCTION.*GetUsersStatuses" RTM/sql/pgsql/02_rtsdata_functions.sql
```
Ожидаемый результат: все 4 функции с `(p_on_date text, p_tenant_id uuid)`.

---

## Шаг 2 — Исправить RTM/RTM/Engine.cs: Timer overflow

Python read→modify→write + os.fsync().

В методе `ScheduleNextCheck()` найти блок:

OLD:
```csharp
            if (dueTime < TimeSpan.FromSeconds(1))
            {
                AsyncLogger.Info(
                    $"ScheduleNextCheck | dueTime adjusted from {dueTime.TotalSeconds:F3}s to 1s");
                dueTime = TimeSpan.FromSeconds(1);
            }
```

NEW:
```csharp
            if (dueTime < TimeSpan.FromSeconds(1))
            {
                AsyncLogger.Info(
                    $"ScheduleNextCheck | dueTime adjusted from {dueTime.TotalSeconds:F3}s to 1s");
                dueTime = TimeSpan.FromSeconds(1);
            }

            // Cap to Timer max (~49.7 days). DateTime.MaxValue → no unions configured → skip.
            const double MaxTimerMs = 4_294_967_294.0;
            if (dueTime.TotalMilliseconds > MaxTimerMs)
            {
                AsyncLogger.Info(
                    $"ScheduleNextCheck | dueTime {dueTime.TotalSeconds:F0}s exceeds Timer max — skipping (no unions configured)");
                return;
            }
```

После записи:
```bash
sync && grep -n "MaxTimerMs\|4_294_967_294" RTM/RTM/Engine.cs
```
Ожидаемый результат: строка с константой.

---

## Шаг 3 — Верификация

```bash
# SQL: все 4 функции имеют (text, uuid)
grep -c "p_on_date text, p_tenant_id uuid" RTM/sql/pgsql/02_rtsdata_functions.sql
# Ожидаемый результат: 4

# Engine: cap присутствует
grep -c "MaxTimerMs" RTM/RTM/Engine.cs
# Ожидаемый результат: 2 (объявление + использование)
```

---

## Шаг 4 — Git commit

```bash
bash tools/pre-commit-check.sh RTM/sql/pgsql/02_rtsdata_functions.sql RTM/RTM/Engine.cs

cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add RTM/sql/pgsql/02_rtsdata_functions.sql RTM/RTM/Engine.cs
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix: RTSData functions add p_on_date param; Engine timer overflow cap"
cp /tmp/cc-idx .git/index
git log --oneline -1
```

## Шаг 5 — Resync

```bash
for f in RTM/sql/pgsql/02_rtsdata_functions.sql RTM/RTM/Engine.cs; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```

## Сообщить результат
- Хэш коммита
- Вывод grep-проверок из шага 3
- Количество строк в обоих файлах
