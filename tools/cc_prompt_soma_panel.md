# CC-задача: Soma — панель запуска CC-промптов (/ui) + журнал прогонов

## Git push
Do NOT run `git push`. Commit only (опционально). Push запрашивается отдельно (§37).

## Запись файлов
Только `tools/Soma/Program.cs`, `tools/Soma/appsettings.json`, новые файлы под `tools/Soma/`.
Запись — Python + `os.fsync` (§0.3); после записи `tail -3` + `wc -l`. Edit-tool НЕ использовать.

## Контекст и назначение
Сделать Соме веб-панель — **кнопку оператора (Макса)** для запуска подготовленных CC-промптов из
`tools/cc_prompt_*.md`, с журналом прогонов и сохранённым логом вывода CC.

Зачем лог: вывод CC ловится Сомой **нативно** (мимо Cowork-mount, который §0.5 застывает) → становится
надёжной КОПИРУЕМОЙ записью результата. Это решает боль спецов «не читается биндинг — скопируй результат».

**РУБЕЖ (критично).** Эндпойнты `/cc/*` — кнопка ОПЕРАТОРА, не само-диспатч колонии:
- все `/cc/*` требуют Bearer-токен (loopback-only, как остальная Сома);
- `promptFile` строго валидируется: должен матчить `^tools[/\\]cc_prompt_[A-Za-z0-9_.\-]+\.md$`
  и резолвиться ВНУТРИ repo root (никакого `..`, никаких произвольных путей/команд);
- в коде и README пометить: эти эндпойнты НЕ предназначены для вызова шиной/сессиями — только оператором.
- каждый запуск пишется в audit-log (как остальные control-операции Сомы) + в журнал прогонов.

## Конфиг (appsettings.json, секция Soma; gitignored — правится локально)
- `CcExe` (default `"claude"`) — CLI Claude Code.
- `CcSkipPermissions` (default `true`) — явный, аудируемый флаг (оператор уже работает в этом режиме).
- `RepoRoot` (default = `Shell:WorkingDir` = `D:\Claude\Projects\RTM View Shell`) — cwd для CC.
- `PromptsDir` (default `tools`) — где лежат `cc_prompt_*.md`.

## Состояние (под tools/Soma/)
- `cc-runs/<runId>.log` — полный stdout+stderr прогона (writer с `FileShare.ReadWrite`, AutoFlush —
  чтобы панель читала лог, пока он пишется; это урок F-QA-2).
- `cc-runs.json` — журнал: список `{ runId, promptFile, startedAt, finishedAt, status, exitCode }`.
  `status` ∈ `running|ok|fail`. На старте Сомы: висящие `running` старше N часов → пометить `interrupted`.

## Эндпойнты

1. **`GET /ui`** — отдаёт HTML-страницу панели (один файл, inline CSS/JS).
   - ОСВОБОЖДЁН от Bearer (как `/health`) — иначе браузер не загрузит; loopback-only это покрывает.
   - Сома ВШИВАЕТ свой токен в страницу (JS-константа) для вызовов `/cc/*` и `/shell/*`.

2. **`GET /cc/prompts`** (Bearer) — список файлов `PromptsDir/cc_prompt_*.md`:
   `{ file, mtime, lastStatus, lastRunAt, lastRunId }` (lastStatus из журнала — самый свежий прогон файла).
   Сортировка: по mtime убыв. (новые сверху).

3. **`POST /cc/run`** (Bearer) body `{ "promptFile": "tools/cc_prompt_X.md" }`:
   - валидировать promptFile (regex+resolve внутри RepoRoot), иначе 400.
   - сгенерировать runId; завести запись в журнале `running`; открыть `cc-runs/<runId>.log`.
   - спавн (ProcessStartInfo, `UseShellExecute=false`, ArgumentList — НЕ конкатенация):
     `CcExe` с аргументами для headless+skip-permissions и промптом (WorkingDirectory=RepoRoot):
     `Выполни задачу из файла <promptFile>. В САМОМ конце ОБЯЗАТЕЛЬНО продублируй в stdout
     краткий RESULT-блок (commits, build/test, files changed, status done|failed, blockers) —
     чтобы он гарантированно попал в лог прогона, даже если биндинг в инбокс через mount не лёг.`
     (Сверь точные флаги через `claude --help`: print/headless `-p`/`--print`,
     `--dangerously-skip-permissions`.)
   - stdout+stderr стримить в лог-файл; по выходу — обновить журнал (`ok` если exit==0 иначе `fail`,
     finishedAt, exitCode). Запуск АСИНХРОННЫЙ: вернуть `{ runId }` сразу, не блокируя HTTP на весь прогон.
   - AuditLog("CC_RUN", ...).

4. **`GET /cc/runs/{id}`** (Bearer) — `{ runId, promptFile, status, exitCode, startedAt, finishedAt }`.

5. **`GET /cc/runs/{id}/log`** (Bearer) — сырой лог `text/plain` (для стрима в панель И для «скопировать результат»).

## Панель `/ui` — как выглядит
- Шапка: статус Сомы; статус Shell (через `/shell/status`).
- Фильтры: чекбокс **«скрыть успешно прогнанные»** (по умолчанию ВКЛ — в `tools/` промптов очень много),
  поле поиска по имени.
- Список промптов (новые сверху), у каждой строки:
  - имя файла + mtime;
  - **бейдж**: ⚪ не запускался · 🟡 выполняется · ✅ прогнан (дата) · ❌ упал (дата) — ✅ ТОЛЬКО при exit==0;
  - кнопка **▶ Запустить** (с подтверждением «запустить X?»);
  - если есть прогоны — ссылка **[лог]** → открывает лог в панели снизу.
- Консоль снизу: при запуске поллит `/cc/runs/{id}` + `/cc/runs/{id}/log`, **живьём течёт вывод CC**;
  кнопка **«Копировать»** (копирует весь лог в буфер — это и есть «скопируй результат» для спецов).
- При завершении бейдж строки обновляется (✅/❌).

## Сборка и проверка (обязательно)
```bash
cd "D:\Claude\Projects\RTM View Shell"
dotnet build tools/Soma         # без ошибок
# перезапуск Сомы хирургически (только её порт 5199), затем поднять заново.
```
Дымовой тест:
- Открыть `http://localhost:5199/ui` → список промптов с бейджами, фильтр прячет прогнанные.
- Запустить заведомо безопасный короткий промпт (например `tools/cc_prompt_soma_fix.md` если ещё не
  прогнан, ИЛИ создать пустышку `tools/cc_prompt_ping.md` с задачей «echo OK») → лог течёт в консоль,
  по завершении бейдж ✅, кнопка «Копировать» отдаёт лог.
- Проверить рубеж: `POST /cc/run` с `promptFile=../../etc/passwd` или `promptFile=foo.md` → 400.

## Коммит (опционально, без push)
Префикс `rtm:`. Сообщение: `rtm: Soma /ui CC-launch panel + run log/ledger`.
appsettings.json gitignored — не коммитится.
