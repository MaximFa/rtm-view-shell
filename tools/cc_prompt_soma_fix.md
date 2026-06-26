# CC-задача: Soma — починка /logs/serilog (F-QA-2) и /shell/start (F-QA-3)

## Git push
Do NOT run `git push`. Commit only (опционально). Push запрашивается отдельно (§37).

## Контекст
QA обязан проверять лог Shell после каждого прогона. Live-Serilog из Cowork-mount не читается
(§0.5), поэтому ЕДИНСТВЕННЫЙ путь QA к логам Shell — Сомин эндпойнт `/logs/serilog` (и
`/logs/tail?source=serilog`). Сейчас он сломан. Также `/shell/start` отдаёт 500 при повторном вызове.

Файлы: только `tools/Soma/Program.cs` и `tools/Soma/appsettings.json`.
Запись — Python + `os.fsync` (§0.3), после записи `tail -3` + `wc -l`. Edit-tool НЕ использовать.

Факты про Shell (проверены):
- Shell пишет Serilog в `src/CcDashboard.Web/logs/log-ГГГГММДД.txt`, ротация по дню
  (rollingInterval=Day). Полный путь папки: `D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\logs`.
- Shell слушает на порту **5239** (подтверждено: /login на 5239). Если launchSettings даёт иной —
  использовать фактический; 5239 — дефолт.

---

## Fix 1 — F-QA-2: `/logs/serilog` и `/logs/tail` должны читать ПАПКУ Serilog Shell

Сейчас `SerilogPath` указывает на логи самой Сомы И на ПАПКУ, а код (`File.Exists` +
`File.ReadAllLines`) ждёт ФАЙЛ → 500. Serilog ротится по дню, поэтому путь к конкретному файлу
протухает каждый день — нужно резолвить «свежий файл в папке».

1. **appsettings.json** (`tools/Soma/appsettings.json`, gitignored — правка локальная):
   - `Soma:SerilogPath` → `D:\\Claude\\Projects\\RTM View Shell\\src\\CcDashboard.Web\\logs`

2. **Program.cs** — добавить локальную функцию-резолвер (до объявления `logSourceWhitelist`, ~стр.112):
   ```csharp
   // Если path = файл → вернуть его; если папка → вернуть самый свежий файл (Serilog ротится по дню)
   string? ResolveLogFile(string? path)
   {
       if (string.IsNullOrWhiteSpace(path)) return null;
       if (File.Exists(path)) return path;
       if (Directory.Exists(path))
       {
           var newest = new DirectoryInfo(path)
               .GetFiles("*.*").Where(f => f.Extension is ".txt" or ".log" or ".json")
               .OrderByDescending(f => f.LastWriteTimeUtc).FirstOrDefault();
           return newest?.FullName;
       }
       return null;
   }
   ```

3. **whitelist** (`["serilog"] = () => serilogPath`) → `["serilog"] = () => ResolveLogFile(serilogPath)`.
   (`soma-shell` / `soma-audit` — файлы, можно тоже обернуть в `ResolveLogFile`, безвредно.)

4. **`/logs/serilog`** handler: заменить проверку `if (!File.Exists(serilogPath))` и
   `File.ReadAllLines(serilogPath)` на резолв:
   ```csharp
   var file = ResolveLogFile(serilogPath);
   if (file is null)
       return Results.Problem($"Serilog file not found under: {serilogPath}", statusCode: 500);
   var lines = File.ReadAllLines(file);
   ```
   (Открывать файл с шарингом, т.к. Shell пишет в него: используй
   `File.ReadAllLines` через `new StreamReader(new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))`
   и читай построчно — иначе можно поймать «file in use», пока Serilog держит файл.)

**Приёмка F-QA-2:** `GET /logs/serilog?tail=20` и `GET /logs/tail?source=serilog&n=20`
возвращают хвост сегодняшнего `log-ГГГГММДД.txt`, не 500.

---

## Fix 2 — F-QA-3: `/shell/start` 500 при повторном вызове + дубль при ручном старте

Причина 500: `var logFile = File.AppendText(shellLogPath);` стоит ВНЕ try/catch, и хэндл течёт
(на успехе не закрывается) → второй вызов ловит «file in use» → необработанное исключение → 500.

1. **appsettings.json**: `Soma:Shell:HealthUrl` → `http://localhost:5239/health` (был 7196).

2. **Program.cs `/shell/start`**:
   - Перед спавном — guard по порту: если `shellHealthUrl` отвечает healthy (Shell уже поднят,
     пусть и не трекается Сомой — напр. запущен вручную), НЕ плодить дубль, а вернуть
     `Results.Json(new { running = true, tracked = false, healthy = true, note = "Shell already up (untracked)" })`.
   - Открытие лог-файла — ВНУТРЬ try, с шарингом, чтобы повторный старт не падал:
     ```csharp
     StreamWriter logFile;
     try
     {
         logFile = new StreamWriter(new FileStream(shellLogPath, FileMode.Append, FileAccess.Write, FileShare.ReadWrite)) { AutoFlush = true };
         proc = Process.Start(psi)!;
     }
     catch (Exception ex)
     {
         return Results.Problem($"Failed to start shell: {ex.Message}", statusCode: 500);
     }
     ```

**Приёмка F-QA-3:** `/shell/start` дважды подряд НЕ даёт 500; при уже поднятом Shell возвращает
понятный ответ без спавна дубля.

---

## Сборка и проверка (обязательно)
```bash
cd "D:\Claude\Projects\RTM View Shell"
dotnet build tools/Soma          # должно собраться без ошибок
# перезапуск Сомы (хирургически, только её порт 5199):
#   Get-NetTCPConnection -LocalPort 5199 -State Listen | %{ Stop-Process -Id $_.OwningProcess -Force }
#   затем поднять заново (dotnet run из tools/Soma)
```
Дымовой тест после рестарта:
- `GET http://localhost:5199/logs/serilog?tail=10` (Bearer) → строки сегодняшнего лога Shell.
- `POST http://localhost:5199/shell/start` дважды → второй раз без 500.

## Коммит (опционально, без push)
Префикс `rtm:` (Soma живёт в RTM-репо). Сообщение: `rtm: fix Soma serilog dir-resolve (F-QA-2) + shell/start handle leak (F-QA-3)`.
appsettings.json gitignored — не коммитится, правится локально на машине.
