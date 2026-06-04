# RTM View Shell — Simulator Installation Guide

Deployment target: **Windows 10/11 or Windows Server 2019/2022, Kestrel Windows Service**

The simulator package contains a pre-baked PostgreSQL dump (`simulator_db.dump`) with all
schema, seed data, and RTS test rows already applied. Installation restores this snapshot
to a fresh database — no EF migration run from scratch required.

---

## Prerequisites overview

| Component | Version | Notes |
|---|---|---|
| PostgreSQL | 15 or 16 | EDB installer (MSI) — includes `psql`, `pg_restore` |
| Memurai (Redis) | 4.x | Redis-compatible Windows service |
| .NET 8 Runtime | bundled | Included in self-contained package — not required on host |

---

## Step 1 — Install PostgreSQL

1. Download the **EDB PostgreSQL 16 Windows installer** from
   https://www.enterprisedb.com/downloads/postgres-postgresql-downloads

2. Run the installer. Accept defaults; note the `postgres` superuser password you set.

3. After install, add the PostgreSQL `bin` directory to your `PATH`:
   `C:\Program Files\PostgreSQL\16\bin`
   (or the installer does it automatically — verify with `psql --version` in a new shell).

> The install script creates the database and user automatically.
> You only need the `postgres` superuser password during installation.

---

## Step 2 — Install Memurai (Redis for Windows)

1. Download **Memurai** (free Developer edition) from https://www.memurai.com/get-memurai

2. Run the installer. Memurai registers itself as a Windows Service named **Memurai**.

3. Verify it is running:

```powershell
redis-cli ping
# Expected: PONG
```

---

## Step 3 — Extract the package

Extract `RTMViewShell-Simulator.zip` to any folder, for example `C:\Temp\rtm-install`:

```
C:\Temp\rtm-install\
    CcDashboard.Web.exe         <- main executable
    *.dll                       <- runtime dependencies
    appsettings.json            <- template (overwritten by installer)
    appsettings.Development.json
    wwwroot\
    simulator_db.dump           <- pre-baked DB snapshot  ← KEY FILE
    Install-CcDashboard.ps1
    Uninstall-CcDashboard.ps1
    INSTALL-SIMULATOR.md        <- this file
```

---

## Step 4 — Run the installer

Open **PowerShell as Administrator**, navigate to the extracted folder, and run:

```powershell
cd C:\Temp\rtm-install

powershell -ExecutionPolicy Bypass -File Install-CcDashboard.ps1 `
    -DBPassword "YourAppUserPassword!" `
    -PGSuperPassword "YourPostgresPassword"
```

The script will:
1. **Create** PostgreSQL user `ccdashboard_user` and database `RTMViewDB`
2. **Restore** `simulator_db.dump` via `pg_restore` (all schema + seed + RTS simulator data)
3. **Grant** schema privileges to the app user
4. **Write** `appsettings.json` with the connection string and Kestrel URL
5. **Register** Windows Service `CcDashboard`
6. **Set** `ASPNETCORE_ENVIRONMENT=Development` in service registry (activates simulator path)
7. **Start** the service and open `http://localhost:5000` in your browser

### Optional parameters

| Parameter | Default | Description |
|---|---|---|
| `-InstallPath` | `C:\Program Files\CcDashboard` | Installation directory |
| `-Port` | `5000` | HTTP port Kestrel listens on |
| `-BindAddress` | `http://localhost` | `http://0.0.0.0` to allow network access |
| `-DBHost` | `localhost` | PostgreSQL host |
| `-DBName` | `RTMViewDB` | Target database name |
| `-DBUser` | `ccdashboard_user` | Application DB user |
| `-DBPassword` | *(prompted)* | Password for the app user |
| `-PGSuperUser` | `postgres` | PostgreSQL superuser for DB creation and restore |
| `-PGSuperPassword` | *(prompted)* | Superuser password |
| `-RedisConn` | `localhost:6379` | Redis connection string |

Example — listen on all interfaces, port 8080:

```powershell
powershell -ExecutionPolicy Bypass -File Install-CcDashboard.ps1 `
    -BindAddress "http://0.0.0.0" `
    -Port 8080 `
    -DBPassword "AppPwd!" `
    -PGSuperPassword "PgPwd!"
```

> **Firewall:** If using `0.0.0.0`, open the port:
> `netsh advfirewall firewall add rule name="RTM View Shell" protocol=TCP dir=in localport=8080 action=allow`

---

## Step 5 — First login

Open `http://localhost:5000` (or your configured address).

| Field | Value |
|---|---|
| Username or email | `admin@platform.local` |
| Password | `Admin@123456!` |

**Change the admin password immediately after first login** — the system will redirect you to
the Change Password screen automatically (credentials are baked into the dump).

---

## Step 6 — Verify

```powershell
# Service status
Get-Service CcDashboard

# Health checks (both should return HTTP 200)
Invoke-WebRequest http://localhost:5000/health       | Select-Object StatusCode
Invoke-WebRequest http://localhost:5000/health/ready | Select-Object StatusCode

# Tail application log
Get-Content "C:\Program Files\CcDashboard\logs\log-$(Get-Date -f 'yyyy-MM-dd').txt" -Tail 30
```

---

## Managing the service

```powershell
Start-Service   CcDashboard
Stop-Service    CcDashboard
Restart-Service CcDashboard

# Uninstall (keeps files and DB)
powershell -ExecutionPolicy Bypass -File "C:\Temp\rtm-install\Uninstall-CcDashboard.ps1"

# Uninstall + remove files
powershell -ExecutionPolicy Bypass -File "C:\Temp\rtm-install\Uninstall-CcDashboard.ps1" -RemoveFiles

# Uninstall + remove files + drop DB
powershell -ExecutionPolicy Bypass -File "C:\Temp\rtm-install\Uninstall-CcDashboard.ps1" -RemoveFiles -RemoveData
```

---

## Building a new simulator package (developer workflow)

Run these steps on the development machine when you want to produce a fresh package:

```powershell
# 1. Make sure the dev app has run at least once (DB fully migrated and seeded)

# 2. Export the current dev DB snapshot
powershell -ExecutionPolicy Bypass -File tools\Export-SimulatorDB.ps1
# → creates tools\simulator_db.dump

# 3. Build + package
powershell -ExecutionPolicy Bypass -File tools\Build-SimulatorPackage.ps1
# → creates publish\RTMViewShell-Simulator.zip

# Or combine steps 2+3 in one command:
powershell -ExecutionPolicy Bypass -File tools\Build-SimulatorPackage.ps1 -ExportDB -DBPassword "dev_password"
```

---

## Troubleshooting

### pg_restore exits with warnings (exit code 1)

Exit code 1 means non-fatal warnings (e.g. "schema already exists"). The restore is
successful. Exit codes > 1 indicate real errors.

### "locale is not supported" on CREATE DATABASE

The installer automatically retries without explicit locale. If it still fails, create
the database manually:
```sql
CREATE DATABASE "RTMViewDB" OWNER ccdashboard_user ENCODING 'UTF8';
```
Then re-run the installer — it will detect the existing DB and skip creation.

### Service fails to start

```powershell
Get-Content "C:\Program Files\CcDashboard\logs\log-$(Get-Date -f 'yyyy-MM-dd').txt" -Tail 50
```

Common causes:
- **Port in use:** `netstat -aon | findstr :5000` → kill the process, or change `-Port`
- **Redis unreachable:** `Get-Service Memurai` — ensure it is Running
- **DB connection failed:** verify credentials in `appsettings.json`

---

*Guide version: 1.1 — Simulator (Kestrel Windows Service, DB backup/restore)*
