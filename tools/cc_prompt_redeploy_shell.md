# Redeploy Shell — relay GridInit fix (commit 08980c6)

**Session name:** RTM — Redeploy Shell
**Goal:** Пересобрать Shell (win-x64 self-contained) и скопировать на сервер C:\RTMView\Shell\

---

## §0 — Session-resume check

```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
git log --oneline -2
```

Ожидаем: последний commit = `08980c6 fix(relay): GridInitAsync InvokeAsync`.

---

## Шаг 1 — Build

```bash
dotnet publish src/CcDashboard.Web/CcDashboard.Web.csproj \
  -c Release -r win-x64 --self-contained \
  -o D:\Claude\Projects\RTM View Shell\publish\shell
```

Должно быть: `Build succeeded`, 0 errors.

---

## Шаг 2 — Остановить сервис на сервере

```powershell
Stop-Process -Name "CcDashboard.Web" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
```

---

## Шаг 3 — Скопировать только изменённые DLL

Если полный редеплой нежелателен — достаточно скопировать только изменённый файл:

```powershell
Copy-Item "D:\Claude\Projects\RTM View Shell\publish\shell\CcDashboard.Infrastructure.dll" `
  -Destination "C:\RTMView\Shell\CcDashboard.Infrastructure.dll" -Force

Copy-Item "D:\Claude\Projects\RTM View Shell\publish\shell\CcDashboard.Infrastructure.pdb" `
  -Destination "C:\RTMView\Shell\CcDashboard.Infrastructure.pdb" -Force
```

Или полный деплой (рекомендуется):

```powershell
# Скопировать все файлы кроме appsettings.json (не перезаписывать production config)
Get-ChildItem "D:\Claude\Projects\RTM View Shell\publish\shell\" |
  Where-Object { $_.Name -notin @("appsettings.json", "appsettings.Development.json") } |
  ForEach-Object {
    Copy-Item $_.FullName -Destination "C:\RTMView\Shell\$($_.Name)" -Force -Recurse
  }
```

---

## Шаг 4 — Запустить сервис

```cmd
cd C:\RTMView\Shell
CcDashboard.Web.exe
```

Ожидаемые логи:
```
[INF] Running database seed...
[INF] Database seed complete.
```

Затем открыть браузер, войти, нажать Retry на виджетах.

Ожидаемые логи в консоли:
```
[INF] RtmRelayService: connecting to http://localhost:8088/signalr ...
[INF] RtmRelayService: connected to tenant ... grid ...
[INF] RtmRelayService: init+refreshCells complete for grid ...
```

Без WRN/ERR от HubException.
