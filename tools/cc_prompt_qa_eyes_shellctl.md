# CC task — QaEyes: именованное управление Shell-сервисом (start/stop/restart/status), БЕЗ shell

> Standalone follow-up к QaEyes. NAMED-операции, НЕ произвольный shell (оператор явно отверг RCE/free-PowerShell).
> Оператор запускает нативным CC одной строкой.

## Git push
НЕ пушить. Только commit.

## STEP 0 — INTEGRITY
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short   # M-файлы усечены? git show HEAD:"$f" > "$f"
sync
```
Все записи — ТОЛЬКО Python + `os.fsync` (Edit BANNED, §0.3). После: `sync; tail -3 <file>; wc -l <file>`.

## ЦЕЛЬ
Дать QA управление Shell-сервисом: **start / stop / restart + status**. ИМЕНОВАННЫЕ операции — БЕЗ произвольного shell.
**Принцип безопасности:** вызыватель выбирает ТОЛЬКО действие (фиксированные роуты); имя сервиса — из КОНФИГА,
НИКОГДА не из запроса; никакого PowerShell/`sc.exe`-строки — **чистый ServiceController API** → ноль injection-поверхности.

## ДЕЛИВЕРАБЛЫ
1. `tools/QaEyes/appsettings.json`: добавить `"ShellServiceName": "RTMViewShell"` (дефолт; оператор поправит под свою машину).
2. `tools/QaEyes/QaEyes.csproj`: добавить пакет `System.ServiceProcess.ServiceController` (Windows-only, net8-совместимый).
3. `tools/QaEyes/Program.cs`: 4 эндпойнта, ВСЕ на `config["ShellServiceName"]` через `System.ServiceProcess.ServiceController`:
   - `POST /shell/start`   -> `.Start()`; `WaitForStatus(Running, 30s)`; вернуть `{service, status}`.
   - `POST /shell/stop`    -> `.Stop()`;  `WaitForStatus(Stopped, 30s)`; `{service, status}`.
   - `POST /shell/restart` -> Stop -> wait Stopped -> Start -> wait Running; `{service, status}`.
   - `GET  /shell/status`  -> текущий `{service, status}`.
   - Имя сервиса из тела/квери запроса — ИГНОРИРОВАТЬ; брать ТОЛЬКО из конфига.
4. **Аудит:** каждое control-действие (start/stop/restart) -> строка в `qa-query-audit.log` (рядом с SerilogPath):
   `<UTC> | shell-<action> | result=<status>`.
5. Обновить `tools/QaEyes/USAGE-QA.md` + `README.md`: раздел «Shell control» (примеры POST) + нота про привилегии.

## БЕЗОПАСНОСТЬ (NON-negotiable)
- Вызыватель выбирает ТОЛЬКО action (фиксированные роуты). Имя сервиса — из конфига, не из запроса.
- НИКАКОГО shell/PowerShell/Invoke-Expression/process-spawn с пользовательским вводом. Только ServiceController API.
- Auth (Bearer) + loopback — как есть. Control-действия аудируются (п.4).
- `WaitForStatus` с таймаутом 30с — не висеть; при таймауте/исключении -> 500 с понятным сообщением.

## ПРИВИЛЕГИИ (нота оператору — ВАЖНО)
`ServiceController.Start/Stop` требует прав на управление сервисом. Дай QaEyes-процессу право на ЭТОТ сервис
**наименьшими привилегиями:** либо запускай QaEyes под аккаунтом с service-control ACL на `RTMViewShell`
(`sc sdset` / вкладка Security сервиса), либо (хуже) под admin. НЕ давай больше, чем control над одним сервисом.

## ПРИЁМКА
1. `dotnet build tools/QaEyes` — чисто (пакет ServiceController подтянут).
2. `GET /shell/status` -> текущий статус.
3. `POST /shell/stop` -> Stopped; `POST /shell/start` -> Running; `POST /shell/restart` -> Running.
4. Каждое действие -> строка в аудит-логе.
5. Если прав нет -> **500 с понятным сообщением** («access denied — нужно service-control право»), не падать молча.
6. Имя сервиса, переданное в теле запроса, ИГНОРИРУЕТСЯ (берётся из конфига) — проверить.

## КОММИТ (NO push)
```bash
# commit.lock (python open 'x'); bash tools/pre-commit-check.sh; add tools/QaEyes; commit tools: prefix — НЕ push
```
- §0.6 post-commit: `git status --short` пусто. §0.7 re-sync committed from HEAD.

## ЗАМЕТКА ОПЕРАТОРУ
После сборки: проверь `ShellServiceName` в appsettings (на твоей машине Shell может зваться иначе или вообще
быть `dotnet run`, а не сервисом — тогда start/stop неприменимы, нужен сервис). Дай QaEyes service-control право. Перезапусти сервис.
