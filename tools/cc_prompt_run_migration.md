# CC Task: Run metrics migration on dev server

## Git push
Do NOT run `git push`.

---

## Task

Run the migration file on the dev PostgreSQL server:

```powershell
psql -U ccdashboard_user -d rtmviewdb -f "D:\Claude\Projects\RTM View Shell\db\migrations\20260605_001_add_missing_metrics.sql"
```

Expected output:
- `INSERT 0 4` (or `INSERT 0 0` if already exist — idempotent)
- SELECT at end returns 4 rows: QueueNumAbandonedCalls, QueueNumAbandonedCallbacks, QueueNumOutboundCalls, QueueNumTransferredCalls

If psql is not in PATH, try:
```powershell
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U ccdashboard_user -d rtmviewdb -f "D:\Claude\Projects\RTM View Shell\db\migrations\20260605_001_add_missing_metrics.sql"
```

If connection fails (password prompt), check `src\CcDashboard.Web\appsettings.Development.json`
or User Secrets for the connection string, then use:
```powershell
$env:PGPASSWORD="<password>"; psql -U ccdashboard_user -d rtmviewdb -f "..."
```

## Report

Print the full psql output including the SELECT result.
