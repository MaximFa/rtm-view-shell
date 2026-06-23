# QaEyes — Local Read-Only QA Service

A localhost-only service providing QA role with direct read access to the database and Serilog logs.
Security-hardened: loopback-only binding, bearer token auth, read-only DB user, named operations only.

## Security Model

1. **Loopback only**: Kestrel binds to `127.0.0.1:<PORT>` — no external network access
2. **Bearer token**: Every request (except /health) requires `Authorization: Bearer <token>`
3. **Read-only DB**: Uses `qa_eyes_ro` PostgreSQL role with SELECT-only privileges
4. **Named operations**: No arbitrary SQL — only predefined parameterized queries
5. **Log path restriction**: Only reads the configured Serilog JSON log file

## Setup

### 1. Create the read-only PostgreSQL role

Run as postgres superuser:

```powershell
psql -U postgres -d rtmviewdb -f db\qa_eyes_readonly_role.sql
# Then set a strong password:
psql -U postgres -c "ALTER ROLE qa_eyes_ro PASSWORD 'your-strong-password';"
```

### 2. Configure appsettings.json

Edit `tools/QaEyes/appsettings.json`:

```json
{
  "QaEyes": {
    "Port": "5199",
    "Token": "your-long-random-token-here",
    "ReadonlyConnectionString": "Host=127.0.0.1;Database=rtmviewdb;Username=qa_eyes_ro;Password=your-strong-password;SSL Mode=Disable",
    "SerilogPath": "C:\\ProgramData\\CcDashboard\\logs\\log-20260623.json"
  }
}
```

Generate a secure token:
```powershell
[Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
```

### 3. Run the service

```powershell
cd "D:\Claude\Projects\RTM View Shell"
dotnet run --project tools/QaEyes
```

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /health` | Health check (no auth required) |
| `GET /db/agent-states?tenant=<guid>` | Agent states + mapped groups for tenant |
| `GET /db/queues?tenant=<guid>` | Queues + active interaction counts |
| `GET /db/dashboards?tenant=<guid>` | Dashboards + widgets with ConfigJson/PositionJson |
| `GET /db/report?name=<name>&tenant=<guid>&from=<date>&to=<date>` | Historical report data |
| `GET /logs/serilog?tail=<N>&contains=<text>` | Last N lines of Serilog JSON log |

### Report names (whitelist)
- `hist_queue_intervals`
- `hist_agent_intervals`

## Usage Examples

### PowerShell

```powershell
$token = "your-token-here"
$tenant = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$headers = @{ Authorization = "Bearer $token" }

# Health check
Invoke-RestMethod -Uri "http://127.0.0.1:5199/health"

# Agent states
Invoke-RestMethod -Uri "http://127.0.0.1:5199/db/agent-states?tenant=$tenant" -Headers $headers

# Queues with counts
Invoke-RestMethod -Uri "http://127.0.0.1:5199/db/queues?tenant=$tenant" -Headers $headers

# Dashboards
Invoke-RestMethod -Uri "http://127.0.0.1:5199/db/dashboards?tenant=$tenant" -Headers $headers

# Historical report
$from = "2026-06-01T00:00:00Z"
$to = "2026-06-23T00:00:00Z"
Invoke-RestMethod -Uri "http://127.0.0.1:5199/db/report?name=hist_queue_intervals&tenant=$tenant&from=$from&to=$to" -Headers $headers

# Serilog tail
Invoke-RestMethod -Uri "http://127.0.0.1:5199/logs/serilog?tail=50" -Headers $headers

# Serilog filtered
Invoke-RestMethod -Uri "http://127.0.0.1:5199/logs/serilog?tail=100&contains=Error" -Headers $headers
```

### C# HttpClient

```csharp
using var client = new HttpClient();
client.BaseAddress = new Uri("http://127.0.0.1:5199");
client.DefaultRequestHeaders.Authorization = 
    new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", "your-token-here");

var tenant = Guid.Parse("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx");

// Agent states
var states = await client.GetFromJsonAsync<List<AgentStateDto>>($"/db/agent-states?tenant={tenant}");

// Queues
var queues = await client.GetFromJsonAsync<List<QueueDto>>($"/db/queues?tenant={tenant}");

// Dashboards
var dashboards = await client.GetFromJsonAsync<List<DashboardDto>>($"/db/dashboards?tenant={tenant}");
```

## Verify Read-Only Protection

After setup, verify the role cannot write:

```powershell
# Connect as qa_eyes_ro
psql -U qa_eyes_ro -d rtmviewdb

# Attempt INSERT (must fail)
INSERT INTO public.tenants ("Id", "Slug", "Name", "Status", "CreatedAt", "UpdatedAt")
VALUES ('00000000-0000-0000-0000-000000000099', 'test', 'Test', 'Active', NOW(), NOW());
-- Expected: ERROR: permission denied for table tenants

# SELECT works
SELECT COUNT(*) FROM public.tenants;
-- Expected: returns count
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| 401 Unauthorized | Check token in request matches appsettings.json |
| Connection refused | Verify service is running, port matches config |
| Permission denied (DB) | Run qa_eyes_readonly_role.sql as postgres |
| Log file not found | Set correct SerilogPath in appsettings.json |

## Notes

- Never expose this service outside localhost
- Token should be rotated periodically
- The service has no persistence — restart to reload config