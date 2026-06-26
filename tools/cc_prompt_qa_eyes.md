# CC task — BUILD QaEyes: локальный read-only сервис «глаз QA» (RTM, 127.0.0.1)

> Самодостаточная задача. Оператор запускает её нативным CC одной строкой; колонию дёргать не нужно.
> Это READ-PLANE срез `docs/MaintenanceService-Design.md`, заточенный под QA. Standalone — без полной
> §42-координации, но с обязательной дисциплиной записи/коммита.

## Git push
НЕ запускать `git push`. Только commit.

## STEP 0 — INTEGRITY (обязательно, до любой работы)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
# для каждого M-файла: сравни HEAD vs working по line-count; усечён -> git show HEAD:"$f" > "$f"
sync; echo "=== integrity ok ==="
```
Все записи файлов — ТОЛЬКО Python + `os.fsync` (Edit BANNED, §0.3). После записи: `sync; tail -3 <file>; wc -l <file>`.

## ЦЕЛЬ
Собрать ЛОКАЛЬНЫЙ loopback-сервис **QaEyes**, дающий роли QA прямые read-глаза на БД и логи RTM —
БЕЗ операторского релея. Read-only, именованные операции, `127.0.0.1` + токен.

## БЕЗОПАСНОСТЬ (НЕ-обсуждается)
1. Kestrel слушает **только `http://127.0.0.1:<PORT>`** — никогда `0.0.0.0`/LAN.
2. **Bearer-токен** на каждом запросе (из appsettings/env). Без токена -> 401.
3. БД: **read-only пользователь `qa_eyes_ro`** (только SELECT). Сервис НИКОГДА не пишет.
4. **Каталог ИМЕНОВАННЫХ read-операций.** НИКАКОГО эндпойнта с произвольным SQL. Параметры валидируются.
5. Логи: читать ТОЛЬКО сконфигурированный путь Serilog. Никакого произвольного чтения ФС.

## ДЕЛИВЕРАБЛЫ
1. `tools/QaEyes/QaEyes.csproj` — net8.0, минимальный ASP.NET Core, Npgsql.
2. `tools/QaEyes/Program.cs` — Kestrel на `127.0.0.1:<PORT>`, middleware токена, эндпойнты (ниже).
3. `tools/QaEyes/appsettings.json` — ПЛЕЙСХОЛДЕРЫ: `Port`, `Token`, `ReadonlyConnectionString`, `SerilogPath`
   (оператор впишет при запуске; в задаче — заглушки `<FILL>`).
4. `db/qa_eyes_readonly_role.sql` — идемпотентно: `CREATE ROLE qa_eyes_ro LOGIN` + `GRANT USAGE` на схемы
   public/audit/identity + `GRANT SELECT ON ALL TABLES` + `ALTER DEFAULT PRIVILEGES ... GRANT SELECT`.
   НЕ давать INSERT/UPDATE/DELETE/USAGE-на-sequence-для-записи.
5. `tools/QaEyes/README.md` — как запустить + как QA дёргает (примеры HttpClient C# и PowerShell `Invoke-RestMethod`).

## ЭНДПОЙНТЫ (именованные read-операции; каждый = ФИКСИРОВАННЫЙ параметризованный запрос)
- `GET /health` -> `{ok:true,version}` (без БД).
- `GET /db/agent-states?tenant=<guid>` -> tenant_agent_states + текущие RTSData_UserStatus по тенанту.
- `GET /db/queues?tenant=<guid>` -> queues + живые счётчики из RTSData_Interaction.
- `GET /db/dashboards?tenant=<guid>` -> dashboards + dashboard_widgets (ConfigJson/PositionJson).
- `GET /db/report?name=<reportName>&tenant=<guid>&from=<date>&to=<date>` -> выполнить ИМЕНОВАННЫЙ
  read-запрос исторического отчёта, вернуть строки. (Прямо проверяет «работают ли отчёты».)
  Список `name` — белый список (hist_queue_intervals, hist_agent_intervals; расширяемо).
- `GET /logs/serilog?tail=<N>&contains=<text>` -> последние N строк JSON-лога Serilog, опц. фильтр. N<=2000.

Валидация: `tenant` -> Guid; `from/to` -> DateTime (UTC); `name` -> из белого списка; `N` -> 1..2000.
Любой невалидный параметр -> 400. Неизвестная операция -> 404. Никогда не конкатенировать строки в SQL —
только `NpgsqlParameter` (CODE-01).

## КАК QA ПОТРЕБЛЯЕТ (нативный CC на машине -> `127.0.0.1` достижим напрямую)
README показывает оба пути:
- C#: `HttpClient` с `Authorization: Bearer <token>` -> GET `/db/...` -> JSON.
- PowerShell: `Invoke-RestMethod -Uri "http://127.0.0.1:<PORT>/db/agent-states?tenant=..." -Headers @{Authorization="Bearer <token>"}`.

## СБОРКА + SMOKE (критерии приёмки)
1. `dotnet build tools/QaEyes` — чисто.
2. Запустить; `GET /health` с токеном -> 200; без токена -> 401.
3. `GET /db/agent-states?tenant=<seed-tenant>` -> строки (read-only коннект работает).
4. Доказать read-only: под `qa_eyes_ro` тестовый INSERT -> `permission denied` (зафиксировать в README как проверенное).
5. `GET /logs/serilog?tail=20` -> строки лога.
6. `GET /db/report?name=hist_queue_intervals&tenant=<seed>&from=<d>&to=<d>` -> строки или пустой набор без ошибки.

## КОММИТ (NO push)
```bash
# commit.lock (python open 'x'); pre-commit-check.sh; затем:
GIT_INDEX_FILE=/tmp/qa-idx git add tools/QaEyes db/qa_eyes_readonly_role.sql
# commit с префиксом tools: (или db: для sql) — НЕ push
```
- §0.6 post-commit: `git status --short` пусто; `git diff HEAD -- <key>` пусто.
- §0.7 re-sync committed files from HEAD.
- CAPTURE урок (если был) в role-skill §B.

## ЗАМЕТКА ДЛЯ ОПЕРАТОРА (после сборки)
Перед запуском: впиши в `appsettings.json` реальные `Port`, длинный случайный `Token`, `ReadonlyConnectionString`
(пользователь `qa_eyes_ro`, пароль), `SerilogPath`. Запусти `dotnet run --project tools/QaEyes`.
QA дёргает `127.0.0.1:<PORT>` с этим токеном. Наружу сервис не выставлять.
