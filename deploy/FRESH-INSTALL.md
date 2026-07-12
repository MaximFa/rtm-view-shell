# Fresh Install Runbook (Design B)

This document describes the canonical fresh install process for RTM View Shell on a NEW server.
All steps use the installer script with git-native DB provisioning — no dumps required.

## Prerequisites

- Windows Server 2019+ with PowerShell 5.1+
- PostgreSQL 18 installed and running
- .NET 8 Hosting Bundle installed
- Release package unpacked to `C:\Temp\<timestamp>\`
- `data.sys` (RTM license file) available

## Canonical Install Command

```powershell
# Side-by-side install example (separate from existing RTM on 8088/rtmpipe)
powershell -ExecutionPolicy Bypass -File Install-RTMView.ps1 `
    -Mode Full `
    -InstallRoot "C:\RTMView" `
    -ShellPort 5000 `
    -ShellHttpsPort 5239 `
    -Fqdn "rtmview.example.com" `
    -CertSubject "CN=rtmview.example.com" `
    -DBHost localhost `
    -DBPort 5432 `
    -DBName rtmviewdb `
    -DBUser postgres `
    -DBPassword "<postgres-super-pw>" `
    -DBAppUser ccdashboard_user `
    -DBAppPassword "<app-user-pw>" `
    -RedisPassword "<garnet-pw>" `
    -SuperadminPassword "<initial-superadmin-pw>" `
    -RTMPort 8089 `
    -RTMPipeName "rtmpipe_v3" `
    -RTMTenantId "00000000-0000-0000-0000-000000000000" `
    -AdaptorServiceName "RTMView.Nayax" `
    -FreshDb `
    -NoStartServices
```

### Parameter Reference

| Parameter | Description | Example |
|-----------|-------------|---------|
| `-Mode` | Full / Shell / RTM | `Full` |
| `-InstallRoot` | Installation root | `C:\RTMView` |
| `-ShellPort` / `-ShellHttpsPort` | Kestrel HTTP/HTTPS ports | `5000` / `5239` |
| `-Fqdn` | Server FQDN for Kestrel | `rtmview.example.com` |
| `-CertSubject` | HTTPS cert subject (LocalMachine\My) | `CN=rtmview.example.com` |
| `-DBPassword` | PostgreSQL superuser password | |
| `-DBAppPassword` | Application user password | |
| `-RedisPassword` | Garnet --auth password | |
| `-SuperadminPassword` | Initial superadmin login password | |
| `-RTMPort` | RTM Kestrel port (side-by-side) | `8089` |
| `-RTMPipeName` | Named pipe (side-by-side) | `rtmpipe_v3` |
| `-RTMTenantId` | Tenant UUID (set after tenant created) | |
| `-AdaptorServiceName` | RTM adapter service name | `RTMView.Nayax` |
| `-FreshDb` | Use Provision-FreshDb.ps1 (git-native) | |
| `-NoStartServices` | Register but don't start services | |

## Design B Order (what `-FreshDb` does)

1. `dropdb --if-exists` + `createdb` (superuser)
2. `db/setup/01_init_db.sql` — extensions + app user (superuser)
3. `CcDashboard.Web.exe migrate` — shell tables + tenant seed (Production env, from Shell dir)
4. `db/schema.sql` — backend tables (superuser) + ownership transfer
5. `db/functions/*.sql` — RTM SQL functions (superuser)
6. `db/data/*.sql` — RTM seed data (superuser)
7. Sequence resync + grants

## Post-Install Steps

1. **Copy data.sys** (before starting RTM service):
   ```powershell
   Copy-Item "\\source\data.sys" -Destination "C:\RTMView\RTM\data.sys"
   ```

2. **Set RTM TenantId** (once the tenant is created in the Shell):
   - Log into Shell as superadmin
   - Create the tenant via Tenant Management
   - Copy the TenantId UUID
   - Edit `C:\RTMView\RTM\appsettings.json` → `RTM:TenantId`

3. **Start services**:
   ```powershell
   Start-Service RTMViewShell
   Start-Service RTMService
   ```

4. **Verify**:
   - Shell: `https://rtmview.example.com:5239`
   - RTM health: `http://127.0.0.1:8089/health`

## Existing Dev DB Caveat (CC-1)

The `DropAppOwnedBackendTables` migration (CC-1, 46c6d4b) drops backend tables during
App migrate. On an ALREADY-MIGRATED dev database (where beDb history is applied),
`beDb.MigrateAsync` will not run again (history says all migrations are applied),
so the backend tables stay dropped.

**Solution for dev:** Reset the dev database completely (`-FreshDb`), or manually
clear `__BackendEmulationMigrationsHistory` so beDb migrations re-apply.

**Fresh installs are not affected** — beDb migrations run after App migrations on a
clean database.

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| Shell startup: `connectionString null` | migrate ran from wrong CWD | Provision-FreshDb.ps1 runs migrate with Push-Location to Shell dir |
| Shell: `Password authentication failed` | ConnectionStrings:Default wrong | Verify `-DBAppPassword` matches the app user's password |
| Garnet: `AUTH failed` | ConnectionStrings:Redis missing password | Pass `-RedisPassword` to inject the connection string |
| `superadmin will not be created` | Seed:SuperadminPassword absent | Pass `-SuperadminPassword` |
| RTM: `TenantId cannot be empty` | TenantId not set in appsettings | Edit appsettings.json after tenant is created |

## Package Contents (when built with `-Mode Full`)

```
<timestamp>.zip
├── Shell/          # CcDashboard.Web binaries
├── RTM/            # RTM Service binaries + app.dat
├── DB/             # pg_dump backup (optional)
├── db/             # Git-native DB module (schema.sql, functions/, data/, tools/)
├── Extras/
│   ├── Garnet/     # Redis-compatible cache
│   └── nssm/       # Service wrapper
├── Install-RTMView.ps1
├── Update-RTMView.ps1
├── Restore-SqlDump.ps1
└── README.txt
```

The `db/` folder contains everything needed for `-FreshDb` mode.
The `DB/` folder (uppercase) contains the pg_dump backup for restore mode.
