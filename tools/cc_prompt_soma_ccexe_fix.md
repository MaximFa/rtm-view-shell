# CC-задача: Soma — корректный запуск claude (Windows npm-шим .ps1/.cmd)

## Git push
Do NOT run `git push`. Commit only (опционально). Push отдельно (§37).

## Запись файлов
Только `tools/Soma/Program.cs` и `tools/Soma/appsettings.json`. Python + `os.fsync` (§0.3),
после записи `tail -3` + `wc -l`. Edit-tool НЕ использовать.

## Проблема (подтверждено)
`/cc/run` падает 500: `Failed to start CC: ... trying to start process 'claude' ... cannot find the file specified`.
На этой машине claude — npm-шим: `C:\Users\farbe\AppData\Roaming\npm\claude.ps1` (рядом обычно и `claude.cmd`).
`ProcessStartInfo(UseShellExecute=false, FileName="claude")` НЕ резолвит шим и не может запускать `.ps1`/`.cmd`
напрямую (это не .exe). Нужно звать через интерпретатор.

## Фикс

1. **appsettings.json**, секция `Soma`:
   `"CcExe": "C:\\Users\\farbe\\AppData\\Roaming\\npm\\claude.ps1"`

2. **Program.cs, `/cc/run`** — собирать `ProcessStartInfo` по расширению `ccExe`. Все аргументы —
   ТОЛЬКО через `ArgumentList` (без конкатенации). Промпт остаётся ОДНИМ элементом ArgumentList.
   Логика (вынеси в хелпер, напр. `BuildCcProcess(ccExe, IEnumerable<string> ccArgs)`):
   - оканчивается на `.ps1` → `FileName = "powershell.exe"`, в начало ArgumentList:
     `"-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ccExe`, затем все `ccArgs`
     (`-p`, при `CcSkipPermissions` `--dangerously-skip-permissions`, и `<fullPrompt>`).
   - оканчивается на `.cmd`/`.bat` → `FileName = "cmd.exe"`, в начало: `"/c", ccExe`, затем `ccArgs`.
   - иначе → `FileName = ccExe`, затем `ccArgs` (как сейчас).
   Остальное (`UseShellExecute=false`, `RedirectStandardOutput/Error=true`, `CreateNoWindow=true`,
   `WorkingDirectory=RepoRoot`) — без изменений.

## Проверка (обязательно)
```bash
cd "D:\Claude\Projects\RTM View Shell"
dotnet build tools/Soma          # без ошибок
# рестарт Сомы хирургически (порт 5199), поднять заново.
```
Дымовой тест:
- В панели `http://localhost:5199/ui` → ▶ Run на `tools/cc_prompt_soma_selftest.md` (read-only).
- В консоли течёт вывод CC; по завершении **бейдж ✅** (exit 0), кнопка «Копировать» отдаёт лог
  с RESULT-блоком в конце.
- Если 500 — глянь `cc-runs/<runId>.log` и `err.log`: уточни флаги через `claude --help`
  (headless: `-p`/`--print`).

## Коммит (опционально, без push)
Префикс `rtm:`. Сообщение: `rtm: Soma launch claude via npm shim (.ps1/.cmd wrapper)`.
appsettings.json gitignored — не коммитится.
