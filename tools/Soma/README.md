# Soma — Colony Ops Bridge

Local loopback service providing the colony with read access to database/logs and 
named control operations (shell management, build, test). Security-hardened: 
loopback-only, bearer token, read-only DB role with revoked secrets, whitelisted 
operations only.

## Security Model

1. **Loopback only**: Kestrel binds to `127.0.0.1:<PORT>` — no network exposure
2. **Bearer token**: Every request (except /health) requires `Authorization: Bearer <token>`
3. **Read-only DB**: Uses `soma_ro` role with SELECT-only privileges and revoked secret columns
4. **Named operations**: All control/exec operations are fixed in code — no arbitrary commands
5. **ProcessStartInfo.ArgumentList**: All process spawns use ArgumentList (no shell injection)
6. **Audit log**: All control/exec operations logged to `soma-audit.log`
7. **Soma-tracked processes only**: Shell control only affects processes Soma started

## Revoked Secrets (soma_ro role)

The `soma_ro` role CANNOT access:
- `identity.refresh_tokens` — entire table revoked
- `identity.two_factor_codes` — entire table revoked  
- `identity.user_password_history` — entire table revoked
- User secrets — use `identity.users_safe` view (no PasswordHash/SecurityStamp)
- SSO secrets — use `sso_configurations_safe` view (ClientSecret = 'REDACTED')
- Email config — use `tenant_settings_safe` view (EmailProviderConfig = 'REDACTED')

## Setup

### 1. Create/migrate the soma_ro role

```powershell
# Run as postgres superuser
psql -U postgres -d rtmviewdb -f db\soma_readonly_role.sql

# Set a strong password
psql -U postgres -c "ALTER ROLE soma_ro PASSWORD 'your-strong-password';"
```

### 2. Configure appsettings.json

Copy `appsettings.example.json` to `appsettings.json` and fill in your values:

```powershell
Copy-Item tools\Soma\appsettings.example.json tools\Soma\appsettings.json
# Edit appsettings.json with your values
```

Required fields:
- `Port`: e.g. `5199`
- `Token`: long random string (see below)
- `ReadonlyConnectionString`: with soma_ro password
- `SerilogPath`: path to Serilog JSON log file

Generate a secure token:
```powershell
[Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
```

### 3. Run Soma

```powershell
dotnet run --project tools/Soma
```

If config is incomplete, Soma will print a friendly error listing missing fields.

## Important: Shell Process Ownership

Soma ONLY controls shell processes it started itself:
- `/shell/start` spawns a new `dotnet watch run` and tracks it
- `/shell/stop` kills ONLY the Soma-tracked process
- A manually-started `dotnet watch run` by the operator is NOT affected

This means you can run Soma alongside your own dev server without interference.

## /db/query Endpoint

Accepts SQL queries in two formats:

1. **JSON (preferred)**: `POST /db/query` with body `{"sql": "SELECT ..."}`
2. **Raw text (fallback)**: `POST /db/query` with body `SELECT ...`

See `USAGE.md` for full examples.