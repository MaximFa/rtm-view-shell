# CC task — Soma: консолидированный локальный ops-мост колонии (для ВСЕХ ролей)

> ЗАМЕНЯЕТ `tools/cc_prompt_qa_eyes_freeselect.md` + `tools/cc_prompt_qa_eyes_shellctl.md` — те НЕ запускать.
> Standalone, нативный CC, одна команда. Строится на QaEyes (commit 8c5ab20).
> **Soma** = «тело» колонии на хосте: оно ЧУВСТВУЕТ (читает БД/логи) и ДЕЙСТВУЕТ (управляет Shell, билд/тест).
> ТОЛЬКО именованные операции — НИКАКОГО произвольного shell (вердикт оператора).

## Git push
НЕ пушить. Только commit.

## STEP 0 — INTEGRITY
`git status --short`; усечённые M-файлы -> `git show HEAD:"$f" > "$f"`; `sync`. Все записи — Python+`os.fsync` (§0.3); после: `sync; tail -3; wc -l`.

## ПРИНЦИП (NON-negotiable, во всех фазах)
Вызыватель выбирает ТОЛЬКО фиксированное ДЕЙСТВИЕ (или whitelisted suite/report/log-source). НИКОГДА не передаёт
команду, аргументы, имя сервиса/процесса, SQL сверх SELECT, или путь. Ноль произвольного выполнения. Spawn процессов —
через `ProcessStartInfo` с `ArgumentList` (без shell, без конкатенации строк). Read-only роль БД + revoked секреты.
Loopback + Bearer-токен. Аудит всех control/exec.

## ФАЗА 1 — RENAME QaEyes -> Soma
- `tools/QaEyes` -> `tools/Soma` (папка, `QaEyes.csproj`->`Soma.csproj`, namespace).
- Секция конфига `"QaEyes"` -> `"Soma"` в `appsettings.json`.
- Роль БД: `ALTER ROLE qa_eyes_ro RENAME TO soma_ro` (файл `db/qa_eyes_readonly_role.sql` -> `db/soma_readonly_role.sql`;
  идемпотентно: rename если старая есть, иначе create `soma_ro`). Connection string username -> `soma_ro`.
- Аудит-лог -> `soma-audit.log`. Обновить все ссылки в README/доках.

## ФАЗА 2 — Read/query плоскость (folds free-select)
- (A) Сузить `soma_ro` (по `db/schema.sql`): `identity.users` -> grant только НЕ-секретные колонки (без PasswordHash/SecurityStamp/ConcurrencyStamp);
  `REVOKE` целиком `refresh_tokens`, `two_factor_codes`, `user_password_history`; `sso_configurations` без `ClientSecret`;
  `tenant_settings` без `EmailProviderConfig`. Идемпотентно.
- (B) `POST /db/query` — свободный SELECT с гардом: только SELECT/WITH; reject `;`-мультистейтмент, DDL/write-ключевые слова,
  опасные функции (pg_read_file, pg_ls_dir, lo_, dblink, pg_sleep), длина<=10000 -> 400. В транзакции `SET LOCAL statement_timeout='8s'`.
  ROW_CAP=5000 + `truncated`. Аудит каждого запроса.
- Существующие read-эндпойнты (`/db/agent-states|queues|dashboards|report`, `/logs/serilog`) — оставить.

## ФАЗА 3 — Control/exec плоскость (named, bounded)
**Shell (`dotnet watch run` — Soma ВЛАДЕЕТ процессом, вариант A):**
- Конфиг `Soma:Shell = { WorkingDir, Exe:"dotnet", Args:["watch","run","--project","src\CcDashboard.Web"], HealthUrl }`. Всё из конфига, не от вызывателя.
- `POST /shell/start`: если Soma-tracked процесс жив -> already-running; иначе spawn (`ProcessStartInfo`+`ArgumentList` из конфига,
  redirect stdout/stderr -> `soma-shell.log`), хранить `Process`-handle (singleton in-memory), поллить HealthUrl до ready/60с. Вернуть `{running,pid}`.
- `POST /shell/stop`: убить ДЕРЕВО Soma-tracked процесса (`Process.Kill(entireProcessTree:true)`), дождаться exit. Только тот процесс, что Soma запустила.
- `POST /shell/restart`: stop+start.
- `GET /shell/status`: `{running, pid, healthy(ping HealthUrl)}`.
- ВАЖНО: Soma НИКОГДА не трогает процесс, который не запускала сама (ручной `dotnet watch run` оператора — нетронут; один Shell на порт).
**Build/Test/Health (фиксированные/whitelisted):**
- `POST /ops/build`: spawn фиксированный `dotnet build CcDashboard.sln` (из конфига), capture output, timeout 5мин, `{success,exitCode,tail}`.
- `POST /ops/test?suite=<name>`: `suite` из WHITELIST `{unit->tests/CcDashboard.Tests.Unit, integration->..., architecture->..., security->...}`
  (фикс-маппинг; не-whitelisted -> 404). Spawn `dotnet test <project>`, timeout, вернуть результат.
- `GET /ops/health`: пинг Shell `/health` + `/health/ready`, вернуть up/down+latency.
- `GET /logs/tail?source=<name>&n=<N>`: `source` из whitelist `{serilog, soma-shell, soma-audit}`; tail N (<=2000).
- Все spawn: `ArgumentList` (без shell), timeout, аудит.

## ФАЗА 4 — Доки (ВСЕ роли)
- `tools/Soma/USAGE.md` (переименовать USAGE-QA -> USAGE, role-agnostic «для любой роли колонии»): все эндпойнты (read+query+shell+ops),
  примеры PowerShell+C#, модель безопасности, принцип «видит всё / действует только именованными операциями».
- `tools/Soma/README.md`: setup (роль `soma_ro`, appsettings вкл. Shell-launch конфиг), запуск.

## SECURITY RECAP
loopback+токен; read-only роль+revoked секреты; SELECT-only `/db/query`; ТОЛЬКО фиксированные/whitelisted команды
(никаких произвольных cmd/args/path/service-name); `ProcessStartInfo.ArgumentList` (без shell-инъекции); таймауты; аудит всех control/exec;
Soma трогает только процессы, что запустила сама.

## ПРИЁМКА (по фазам)
1. `dotnet build tools/Soma` — чисто.
2. `/db/query` SELECT ok; INSERT -> 400; `SELECT * FROM identity.refresh_tokens` -> permission denied.
3. `/shell/start` спавнит + становится healthy; `/shell/stop` гасит; `/shell/restart` цикл; status точен; РУЧНОЙ Shell не тронут.
4. `/ops/build` success; `/ops/test?suite=unit` бежит; не-whitelisted suite -> 404; `/ops/health` пингует.
5. Аудит-лог содержит control/exec записи.

## КОММИТ (NO push)
commit.lock; `bash tools/pre-commit-check.sh`; add `tools/Soma db/soma_readonly_role.sql`; commit `tools:`/`db:` prefix — НЕ push.
§0.6 post-commit verify; §0.7 re-sync.

## ЗАМЕТКА ОПЕРАТОРУ
Пере-применить роль (`psql -U postgres -d rtmviewdb -f db\soma_readonly_role.sql`), вписать appsettings (Port/Token/ConnStr soma_ro/SerilogPath/Shell-конфиг),
`dotnet run --project tools/Soma`. Твой ручной `dotnet watch run` остаётся как есть — Soma его не трогает (один Shell на порт).
