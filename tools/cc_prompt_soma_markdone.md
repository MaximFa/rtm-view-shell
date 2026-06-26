# CC-задача: Soma — пометка промптов «выполнено» без запуска (mark-done) + кнопки в /ui

## Git push
Do NOT run `git push`. Commit only (опционально). Push запрашивается отдельно (§37).

## Запись файлов
Только `tools/Soma/Program.cs` (+ при нужде новые файлы под `tools/Soma/`).
Запись — Python + `os.fsync` (§0.3); после записи `tail -3` + `wc -l`. Edit-tool НЕ использовать.

## Контекст
В панели `/ui` весь накопленный бэклог `tools/cc_prompt_*.md` показан как «not run», хотя почти всё
уже выполнено исторически. Нужна возможность пометить промпт(ы) как завершённые БЕЗ запуска CC —
нативно (Сома пишет журнал сама, мимо Cowork-mount). Переиспользуй существующие хелперы
`LoadCcRuns()`, `SaveCcRuns()`, класс `CcRunEntry`, `ValidatePromptFile()`.

**РУБЕЖ:** новые эндпойнты — Bearer (loopback), как остальные `/cc/*`. `promptFile` валидировать тем же
`ValidatePromptFile`. Каждую пометку — в AuditLog.

## Эндпойнты (добавить)

1. **`POST /cc/mark-done`** (Bearer) body `{ "promptFile": "tools/cc_prompt_X.md" }`:
   - валидировать `promptFile` (ValidatePromptFile), иначе 400.
   - добавить в журнал синтетическую запись: `RunId = "manual-" + DateTime.UtcNow:yyyyMMdd-HHmmss-fff`,
     `Status = "ok"`, `StartedAt = FinishedAt = UtcNow`, `ExitCode = 0`. (Лог-файла у ручной пометки нет.)
   - AuditLog("CC_MARK_DONE", $"promptFile={promptFile}").
   - вернуть `{ promptFile, status = "ok", manual = true }`.

2. **`POST /cc/mark-all-done`** (Bearer), без тела или `{ "onlyUnrun": true }` (default true):
   - перечислить все `cc_prompt_*.md` в `PromptsDir`; для каждого, у кого текущий `lastStatus != "ok"`,
     добавить такую же синтетическую `ok`-запись (как mark-done).
   - вернуть `{ marked = <N>, skipped = <уже ok> }`. AuditLog("CC_MARK_ALL", $"marked={N}").

Различение в журнале (по желанию): можно пометить ручные записи `RunId`-префиксом `manual-`, чтобы
панель отличала «✓ отмечен» от «✓ прогнан».

## Панель `/ui` (добавить)
- В шапке — кнопка **«✓ Отметить все как завершённые»** → подтверждение → `POST /cc/mark-all-done`
  → перечитать список (`/cc/prompts`). После этого с включённым «Hide successful» бэклог сворачивается.
- В каждой строке рядом с **▶ Run** — маленькая кнопка-галочка **«✓»** (tooltip «отметить выполненным»)
  → `POST /cc/mark-done` для этого файла → обновить строку.
- Бейдж по желанию: ручная пометка → **✅ отмечен (дата)**; реальный прогон остаётся **✅ прогнан (дата)**.

## Сборка и проверка (обязательно)
```bash
cd "D:\Claude\Projects\RTM View Shell"
dotnet build tools/Soma          # без ошибок
# перезапуск Сомы хирургически (только порт 5199), поднять заново.
```
Дымовой тест:
- `http://localhost:5199/ui` → жмёшь «✓ Отметить все как завершённые» → бейджи зеленеют,
  «Hide successful» прячет бэклог, остаётся пусто/только новые.
- Поштучная **«✓»** на одной строке → она помечается ✅ без запуска CC.
- Рубеж: `POST /cc/mark-done` с `promptFile=../../x` → 400.

## Коммит (опционально, без push)
Префикс `rtm:`. Сообщение: `rtm: Soma mark-done (manual ✓) + panel buttons`.
