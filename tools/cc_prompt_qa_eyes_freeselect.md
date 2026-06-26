# CC task — QaEyes: безопасный свободный SELECT (POST /db/query) + сужение роли

> Standalone follow-up к QaEyes (commit 8c5ab20). Оператор запускает нативным CC одной строкой; колонию не дёргать.

## Git push
НЕ пушить. Только commit.

## STEP 0 — INTEGRITY (до любой работы)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
# каждый M-файл: HEAD vs working line-count; усечён -> git show HEAD:"$f" > "$f"
sync
```
Все записи файлов — ТОЛЬКО Python + `os.fsync` (Edit BANNED, §0.3). После записи: `sync; tail -3 <file>; wc -l <file>`.

## ЦЕЛЬ
Дать QA свободный ad-hoc SELECT — БЕЗОПАСНО. Главный предохранитель уже есть: `qa_eyes_ro` read-only на уровне БД
(write/DDL физически невозможны). Добавляем: (A) сузить роль (revoke секретов), (B) `POST /db/query` с гардами, (C) доки.

## (A) Сузить роль — `db/qa_eyes_readonly_role.sql` (APPEND, идемпотентно)
То, что роль не видит — не достанет НИ ОДИН запрос (именованный или свободный). По `db/schema.sql` ревокнуть секреты:
- `identity.users`: `REVOKE SELECT` целиком, затем `GRANT SELECT` ТОЛЬКО на не-секретные колонки
  (Id, UserName, Email, FirstName, LastName, TenantId, Role/нормализованные, IsActive, Is2faEnabled, LastLoginAt,
  PreferredLocale, PermissionGroupId) — БЕЗ PasswordHash, SecurityStamp, ConcurrencyStamp.
- `REVOKE SELECT` ЦЕЛИКОМ: `identity.refresh_tokens`, `identity.two_factor_codes`, `identity.user_password_history`,
  и любые AspNet*Tokens / *UserLogins, несущие токены.
- `sso_configurations`: revoke whole + `GRANT SELECT` на колонки КРОМЕ `ClientSecret`.
- `tenant_settings`: `GRANT SELECT` на все КРОМЕ `EmailProviderConfig` (encrypted).
Идемпотентно (REVOKE безопасен повторно). Чувствительность определять по `db/schema.sql`.

## (B) `POST /db/query` в `tools/QaEyes/Program.cs`
- Body JSON: `{ "sql": "SELECT ..." }`. Auth — существующий Bearer-middleware.
- **ГАРД (defense-in-depth; роль и так блокирует write, но даём чистую ошибку):**
  - trim; ДОЛЖЕН начинаться (case-insensitive) с `SELECT` или `WITH`; иначе **400**.
  - есть `;` кроме хвостового (мультистейтмент) -> **400**.
  - whole-word match любого из: INSERT, UPDATE, DELETE, DROP, ALTER, CREATE, GRANT, REVOKE, TRUNCATE, COPY,
    CALL, DO, MERGE, VACUUM, + опасные функции pg_read_file, pg_ls_dir, lo_, dblink, pg_sleep -> **400**.
  - длина SQL <= 10000 символов -> иначе **400**.
- **ИСПОЛНЕНИЕ:**
  - read-only коннект; в транзакции `SET LOCAL statement_timeout = '8s'` (анти-DoS).
  - читать до **ROW_CAP = 5000**; если строк больше — стоп + `truncated: true`.
  - вернуть `{ columns:[...], rows:[[...]], rowCount, truncated }` (значения как строки/JSON).
- **АУДИТ:** каждый `/db/query` -> строка в локальный `qa-query-audit.log` (рядом с SerilogPath): `<UTC> | rowCount=<n> | <sql>`.

## (C) Доки
- `tools/QaEyes/USAGE-QA.md`: добавить инструмент `POST /db/query` (пример PowerShell `Invoke-RestMethod -Method Post -Body (@{sql="SELECT ..."}|ConvertTo-Json) -ContentType application/json -Headers $h` + C#), + раздел безопасности (read-only роль, сужённый охват, timeout 8с, cap 5000, аудит).
- `tools/QaEyes/README.md`: добавить эндпойнт + ноту про сужение роли (revoke секретов).

## СБОРКА + ПРИЁМКА
1. `dotnet build tools/QaEyes` — чисто.
2. `POST /db/query {"sql":"SELECT 1 AS x"}` с токеном -> `rows:[["1"]]`.
3. `POST {"sql":"INSERT INTO ..."}` -> **400** (гард); и под ролью write всё равно `permission denied`.
4. `POST {"sql":"SELECT * FROM identity.refresh_tokens"}` -> `permission denied` (роль сужена) — зафиксировать в README как проверенное.
5. `POST {"sql":"SELECT pg_sleep(20)"}` -> **400** (гард ловит pg_sleep; если просочится — timeout 8с).
6. Большой результат -> capped 5000 + `truncated:true`.

## КОММИТ (NO push)
```bash
# commit.lock (python open 'x'); bash tools/pre-commit-check.sh; затем add tools/QaEyes db/qa_eyes_readonly_role.sql
# commit tools:/db: prefix — НЕ push
```
- §0.6 post-commit: `git status --short` пусто; `git diff HEAD -- <key>` пусто.
- §0.7 re-sync committed files from HEAD.

## ЗАМЕТКА ОПЕРАТОРУ
После сборки: перезапусти `qa_eyes_ro`-роль (`psql -U postgres -d rtmviewdb -f db\qa_eyes_readonly_role.sql`)
ЧТОБЫ revoke'и применились, затем перезапусти сервис. Свободный SELECT работает в сужённом, read-only, loopback+token охвате.
