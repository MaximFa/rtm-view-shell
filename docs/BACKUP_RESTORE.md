# RTM View Shell — Backup & Restore Guide

> **Goal:** Full project backup to Box.com so work can resume on any Windows PC
> from the exact same state.
>
> **Last updated:** 2026-05-27
> **GitHub repo:** https://github.com/MaximFa/rtm-view-shell (branch: v2)

---

## What is stored where

| Layer | Location | Backup method |
|---|---|---|
| Source code + docs | GitHub `v2` branch | Already pushed — no action needed |
| `.claude/memory/` + `widget-creator/planner` skills | GitHub (committed via plumbing) | Already in git |
| `.claude/` full (13 extra SKILL.md files) | Local only | Box.com ZIP |
| CC auto-memory | `C:\Users\farbe\.claude\projects\C--Users-farbe-Documents-Claude-Projects-RTM-View-Shell\` | Box.com ZIP |
| PostgreSQL database (RTMViewDB) | Local PostgreSQL | Box.com pg_dump |
| Redis | Transient cache — no persistent data needed | Skip |

---

## Part 1 — Backup (run on current PC)

### Step 1 — Push latest code to GitHub

```powershell
cd "C:\Users\farbe\Documents\Claude\Projects\RTM View Shell"
git push origin v2
```

Verify: open https://github.com/MaximFa/rtm-view-shell — check commit timestamp.

### Step 2 — Export PostgreSQL database

```powershell
# Creates RTMViewDB_backup_YYYYMMDD.sql in your Documents folder
$date = Get-Date -Format "yyyyMMdd"
$outFile = "$env:USERPROFILE\Documents\RTMViewDB_backup_$date.sql"

pg_dump `
  --host=localhost `
  --port=5432 `
  --username=ccdashboard_user `
  --format=plain `
  --no-password `
  --file=$outFile `
  RTMViewDB

Write-Host "Database exported to: $outFile"
```

If `pg_dump` is not in PATH, use full path:
`C:\Program Files\PostgreSQL\16\bin\pg_dump.exe`

Password prompt: enter `!@#qweASDzxc`

### Step 3 — ZIP the .claude directory

```powershell
$src = "C:\Users\farbe\Documents\Claude\Projects\RTM View Shell\.claude"
$dst = "$env:USERPROFILE\Documents\rtm-claude-dir_$(Get-Date -Format 'yyyyMMdd').zip"
Compress-Archive -Path $src -DestinationPath $dst -Force
Write-Host "Zipped to: $dst"
```

### Step 4 — ZIP CC auto-memory

```powershell
$src = "C:\Users\farbe\.claude\projects\C--Users-farbe-Documents-Claude-Projects-RTM-View-Shell"
$dst = "$env:USERPROFILE\Documents\rtm-cc-memory_$(Get-Date -Format 'yyyyMMdd').zip"
Compress-Archive -Path $src -DestinationPath $dst -Force
Write-Host "Zipped to: $dst"
```

### Step 5 — Upload to Box.com

Upload these 3 files to Box.com folder `RTM View Shell / Backups / YYYYMMDD`:
- `RTMViewDB_backup_YYYYMMDD.sql`
- `rtm-claude-dir_YYYYMMDD.zip`
- `rtm-cc-memory_YYYYMMDD.zip`

---

## Part 2 — Restore on a new PC

### Prerequisites — install on new PC

1. **Git** — https://git-scm.com/download/win
2. **.NET 8 SDK + Hosting Bundle** — https://dotnet.microsoft.com/download/dotnet/8.0
3. **Node.js** (for Claude Code) — https://nodejs.org
4. **Claude Code CLI** — `npm install -g @anthropic-ai/claude-code`
5. **PostgreSQL 16** — https://www.enterprisedb.com/downloads/postgres-postgresql-downloads
   - During install: set password for `postgres` user
6. **Memurai** (Redis for Windows) — https://www.memurai.com/get-memurai

### Step 1 — Clone the repository

```powershell
# Create the same folder structure
New-Item -ItemType Directory -Force "C:\Users\<username>\Documents\Claude\Projects"
cd "C:\Users\<username>\Documents\Claude\Projects"

git clone https://github.com/MaximFa/rtm-view-shell.git "RTM View Shell"
cd "RTM View Shell"
git checkout v2
```

### Step 2 — Restore PostgreSQL database

```powershell
# 1. Create the database user and DB
psql -U postgres -c "CREATE USER ccdashboard_user WITH PASSWORD '!@#qweASDzxc';"
psql -U postgres -c "CREATE DATABASE RTMViewDB OWNER ccdashboard_user;"
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE RTMViewDB TO ccdashboard_user;"

# 2. Restore from dump
psql --host=localhost --port=5432 --username=ccdashboard_user --dbname=RTMViewDB `
  --file="$env:USERPROFILE\Downloads\RTMViewDB_backup_YYYYMMDD.sql"
```

### Step 3 — Restore .claude directory

```powershell
# Extract the ZIP from Box.com to the project folder
Expand-Archive `
  -Path "$env:USERPROFILE\Downloads\rtm-claude-dir_YYYYMMDD.zip" `
  -DestinationPath "C:\Users\<username>\Documents\Claude\Projects\RTM View Shell" `
  -Force
```

### Step 4 — Restore CC auto-memory

```powershell
# Create the target directory and extract
$target = "C:\Users\<username>\.claude\projects\C--Users-<username>-Documents-Claude-Projects-RTM-View-Shell"
New-Item -ItemType Directory -Force $target

Expand-Archive `
  -Path "$env:USERPROFILE\Downloads\rtm-cc-memory_YYYYMMDD.zip" `
  -DestinationPath "C:\Users\<username>\.claude\projects" `
  -Force
```

> **Note:** The CC memory folder name encodes the project path. If your username differs
> from `farbe`, rename the extracted folder to match:
> `C--Users-<newusername>-Documents-Claude-Projects-RTM-View-Shell`

### Step 5 — Configure appsettings.Development.json

The file is already in the repo with the correct connection string.
Verify: `src/CcDashboard.Web/appsettings.Development.json` contains:

```json
"ConnectionStrings": {
  "Default": "Host=localhost;Port=5432;Database=RTMViewDB;Username=ccdashboard_user;Password=!@#qweASDzxc;SSL Mode=Prefer",
  "Redis": "localhost:6379"
}
```

### Step 6 — Run EF migrations

```powershell
cd "C:\Users\<username>\Documents\Claude\Projects\RTM View Shell"
dotnet restore

# Main database
dotnet ef database update `
  --project src/CcDashboard.Infrastructure `
  --startup-project src/CcDashboard.Web

# Backend emulation (RTSData, NGC tables)
dotnet ef database update `
  --context BackendEmulationDbContext `
  --project src/CcDashboard.Infrastructure `
  --startup-project src/CcDashboard.Web
```

> **Skip this step if you restored the full pg_dump** — migrations are already applied.
> Use migrations only if starting with an empty DB.

### Step 7 — Start the app

```powershell
dotnet run --project src/CcDashboard.Web
```

Open: `http://localhost:5000` (or the port shown in output).
Login: `admin@platform.local` / `Admin@123456!`

---

## Quick reference — connection strings

| Service | Value |
|---|---|
| PostgreSQL host | `localhost:5432` |
| Database | `RTMViewDB` |
| User | `ccdashboard_user` |
| Redis | `localhost:6379` |
| App URL (dev) | `http://localhost:5000` |
| GitHub repo | `https://github.com/MaximFa/rtm-view-shell` |
| Branch | `v2` |

---

## Backup frequency recommendation

| Trigger | Action |
|---|---|
| After each CC session with code changes | `git push origin v2` (CC does this) |
| Weekly | pg_dump + upload to Box |
| After major milestone | Full backup (all 3 ZIPs + dump) |

