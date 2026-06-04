# Redeploy Shell — commits 36a6842 + f3508ba + 6b376cd

**Session name:** RTM — Redeploy Shell v2
**Goal:** Пересобрать Shell (win-x64 self-contained) и задеплоить на C:\RTMView\Shell\

---

## §0 — Session-resume check

```bash
cd "D:\Claude\Projects\RTM View Shell"
git log --oneline -4
```

Ожидаем последние 3 коммита:
- `6b376cd` Sites/Supergroups Tenant column
- `f3508ba` UnitOfWork BackendEmulationDbContext
- `36a6842` QueueGrid GridId fix

---

## Шаг 1 — Build

```bash
dotnet publish src/CcDashboard.Web/CcDashboard.Web.csproj ^
  -c Release -r win-x64 --self-contained ^
  -o "D:\Claude\Projects\RTM View Shell\publish\shell"
```

0 errors.

---

## Шаг 2 — Остановить Shell на сервере

```powershell
Stop-Process -Name "CcDashboard.Web" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
```

---

## Шаг 3 — Деплой (все файлы кроме appsettings)

```powershell
Get-ChildItem "D:\Claude\Projects\RTM View Shell\publish\shell\" |
  Where-Object { $_.Name -notin @("appsettings.json", "appsettings.Development.json") } |
  ForEach-Object {
    Copy-Item $_.FullName -Destination "C:\RTMView\Shell\$($_.Name)" -Force -Recurse
  }
```

---

## Шаг 4 — Запустить Shell

```cmd
cd C:\RTMView\Shell
CcDashboard.Web.exe
```

Ожидаемые логи:
```
[INF] Running database seed...
[INF] Database seed complete.
```
