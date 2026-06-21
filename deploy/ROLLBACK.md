# RTM View Shell — Rollback Runbook

## Server-Verified Version: v2-server-verified-20260619

**Tag:** `v2-server-verified-20260619`  
**Commit:** `b58e2c299724884e4519ccfc65a027b398fe5ab9`  
**Date verified:** 2026-06-19  
**Servers:** 234 and 45 (both smoke-confirmed: Compare B=0, UI/widgets functional)

### What this version contains

- **Shell (src/):** Blazor Server frontend, all widgets (QueueGrid, AgentGrid, DataSlot, DayTrend, etc.)
- **RTM Service (RTM/):** Real-time monitoring backend
- **DB module (db/):** Schema, functions, seed data (PRE-carve version)

### Live-data backup locations (deploy-time snapshots)

| Server | Backup path                          | Timestamp   |
|--------|--------------------------------------|-------------|
| 234    | `C:\RTMView\Backup\19062026_1134`    | 2026-06-19 11:34 |
| 45     | `C:\RTMView\Backup\19062026_1214`    | 2026-06-19 12:14 |

---

## Rollback Procedure

### Step 1 — Code checkout

```powershell
cd "D:\Claude\Projects\RTM View Shell"
git fetch origin --tags
git checkout v2-server-verified-20260619
```

This checks out the exact FE + BE + DB module state that was deployed.

### Step 2 — Database rollback

**Option A: Full restore from deploy-time backup (recommended for complete rollback)**

```powershell
# On server 234:
$backupPath = "C:\RTMView\Backup\19062026_1134\rtmviewdb.dump"
psql -U postgres -c "DROP DATABASE IF EXISTS rtmviewdb;"
psql -U postgres -c "CREATE DATABASE rtmviewdb OWNER ccdashboard_user;"
pg_restore -U postgres -d rtmviewdb $backupPath

# On server 45:
$backupPath = "C:\RTMView\Backup\19062026_1214\rtmviewdb.dump"
# Same commands as above
```

**Option B: Rebuild from version-controlled db/ module (schema + functions + seed only)**

```powershell
# From the checked-out v2-server-verified-20260619
cd db
powershell -File tools/Restore-All.ps1 -AppPassword "..." -SuperPassword "..." -DropAndRecreate
```

Note: Option B creates a clean DB without runtime data. Use Option A if you need to restore user data, dashboards, and NGC configurations.

### Step 3 — Redeploy binaries

Use the original deployment package: `234_b58e2c2_19062026_Full.zip`

```powershell
# Extract package and run update script
powershell -ExecutionPolicy Bypass -File Update-RTMView.ps1 -SkipDB
```

Or rebuild from the checked-out commit:

```powershell
dotnet publish src/CcDashboard.Web -c Release -r win-x64 --self-contained -o publish\web
dotnet publish RTM/RTM -c Release -r win-x64 --self-contained -o publish\rtm
# Then copy to server and restart services
```

### Step 4 — Verify

```powershell
# Check services
Get-Service RTMViewShell, RTMService | Select Name, Status

# Health check
Invoke-WebRequest http://localhost:5000/health -UseBasicParsing

# UI verification
# Open browser to http://localhost:5000, verify login and widget rendering
```

---

## Notes

- This tag marks the LAST version physically tested on production servers before v3 reports work.
- Any commits after b58e2c2 (including db/ schema carve, historical reports, incident fixes) were coded but NOT server-tested.
- The db/ module at this commit is PRE-carve (functions embedded in schema.sql, not separated).
- For fresher data, use the most recent pg_dump from the server's Backup folder rather than deploy-time snapshots.
