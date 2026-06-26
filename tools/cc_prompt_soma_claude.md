# CC task — кодифицировать § Soma в CLAUDE.md (durable onboarding) + token-гигиена

## Git push
НЕ пушить. Только commit.

## STEP 0 — INTEGRITY
`git status --short`; усечённые -> `git show HEAD:"$f" > "$f"`; `sync`. Записи — Python+`os.fsync` (§0.3); после `sync; tail -3; wc -l`.

## ЦЕЛЬ
Ввести Soma в always-reloaded слой (CLAUDE.md), чтобы КАЖДАЯ сессия знала о теле колонии. Durable — переживает хендофф
(runtime-анонс распадается; CLAUDE.md перечитывается каждой сессией).

## (1) Добавить новую секцию в CLAUDE.md (следующий свободный § после §46, перед строкой версии)
```
## §NN — Soma: локальный ops-мост колонии (для ВСЕХ ролей)
- ЧТО: Soma даёт read-глаза (БД, логи) + named-операции (Shell start/stop/restart/status, build, test, health, tail) на ЛОКАЛЬНОЙ машине.
- ПРЕДУСЛОВИЕ: Soma — operator-managed демон на `http://127.0.0.1:<PORT>`. ПЕРЕД использованием — `GET /health`.
  Connection-refused = Soma не запущена -> ФЛАГНУТЬ ОПЕРАТОРУ (роли НЕ запускают её сами).
- AUTH: Bearer-токен, читать из `tools/Soma/appsettings.json` (`Soma:Token`). НИКОГДА не хардкодить и не коммитить токен.
- ВЫЗОВ: HttpClient / Invoke-RestMethod с `Authorization: Bearer <token>`. Полный каталог эндпойнтов + примеры -> `tools/Soma/USAGE.md`.
- ПРИНЦИП: ТОЛЬКО именованные операции (ноль произвольного shell / SQL сверх SELECT). Видит всё, чинит ничего —
  находки роутятся ВЛАДЕЛЬЦУ фикса. Для `identity.users`/`sso_configurations`/`tenant_settings` — запрашивать `*_safe` views (секреты redacted).
- БЕЗОПАСНОСТЬ: loopback-only, read-only роль `soma_ro` (секреты revoked), spawn без shell (ArgumentList), таймауты, аудит control/exec.
```

## (2) Token-гигиена
- Добавить в `.gitignore`: `tools/Soma/appsettings.json` (реальный токен НЕ должен попасть в git).
- Если в репо закоммичен appsettings с placeholder `<FILL>` — создать `tools/Soma/appsettings.example.json` (placeholder-шаблон, tracked),
  а реальный `appsettings.json` — gitignored. В README отметить: реальный токен живёт только локально.

## (3) (опц.) §D-реф в роль-скилах тяжёлых пользователей (test/devops/qa, если есть) — одна строка-указатель на §Soma.

## КОММИТ (NO push)
commit.lock; `bash tools/pre-commit-check.sh`; add CLAUDE.md .gitignore tools/Soma/appsettings.example.json; commit `docs:` prefix — НЕ push.
§0.6 verify; §0.7 re-sync.
