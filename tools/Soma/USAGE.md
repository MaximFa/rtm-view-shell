# Soma — Usage Guide (All Colony Roles)

Soma is the colony's "body" on the host: it SENSES (reads DB/logs) and ACTS 
(controls Shell, runs build/test). All operations are named and bounded — 
no arbitrary shell execution.

## Endpoints Overview

### Health & Status
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Service health (no auth) |
| `/shell/status` | GET | Shell process status + health |
| `/ops/health` | GET | Ping Shell /health + /health/ready |

### Read Plane (Database)
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/db/agent-states?tenant=<guid>` | GET | Agent states + mapped groups |
| `/db/queues?tenant=<guid>` | GET | Queues + active interaction counts |
| `/db/dashboards?tenant=<guid>` | GET | Dashboards + widgets |
| `/db/report?name=<n>&tenant=<g>&from=<d>&to=<d>` | GET | Historical report data |
| `/db/query` | POST | Free SELECT (body = SQL, max 5000 rows) |

### Read Plane (Logs)
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/logs/serilog?tail=<N>&contains=<text>` | GET | Serilog JSON log tail |
| `/logs/tail?source=<name>&n=<N>` | GET | Any whitelisted log source |

Log sources: `serilog`, `soma-shell`, `soma-audit`

### Control Plane (Shell)
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/shell/start` | POST | Spawn Shell (dotnet watch run) |
| `/shell/stop` | POST | Kill Soma-tracked Shell process |
| `/shell/restart` | POST | Stop + Start |

### Control Plane (Ops)
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/ops/build` | POST | Run `dotnet build CcDashboard.sln` |
| `/ops/test?suite=<name>` | POST | Run test suite (whitelisted) |

Test suites: `unit`, `integration`, `architecture`, `security`

---

## PowerShell Examples

```powershell
$base = "http://127.0.0.1:5199"
$token = "your-token"
$headers = @{ Authorization = "Bearer $token" }
$tenant = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Health (no auth)
Invoke-RestMethod "$base/health"

# Agent states
Invoke-RestMethod "$base/db/agent-states?tenant=$tenant" -Headers $headers

# Queues with counts
Invoke-RestMethod "$base/db/queues?tenant=$tenant" -Headers $headers

# Dashboards
Invoke-RestMethod "$base/db/dashboards?tenant=$tenant" -Headers $headers

# Historical report
$from = "2026-06-01T00:00:00Z"
$to = "2026-06-23T00:00:00Z"
Invoke-RestMethod "$base/db/report?name=hist_queue_intervals&tenant=$tenant&from=$from&to=$to" -Headers $headers

# Free SELECT query
$sql = 'SELECT "Id", "Name" FROM public.tenants LIMIT 10'
Invoke-RestMethod "$base/db/query" -Method POST -Headers $headers -Body $sql -ContentType "text/plain"

# Serilog tail
Invoke-RestMethod "$base/logs/serilog?tail=50" -Headers $headers

# Log tail (any source)
Invoke-RestMethod "$base/logs/tail?source=soma-audit&n=20" -Headers $headers

# Shell status
Invoke-RestMethod "$base/shell/status" -Headers $headers

# Start Shell
Invoke-RestMethod "$base/shell/start" -Method POST -Headers $headers

# Stop Shell
Invoke-RestMethod "$base/shell/stop" -Method POST -Headers $headers

# Restart Shell
Invoke-RestMethod "$base/shell/restart" -Method POST -Headers $headers

# Build
Invoke-RestMethod "$base/ops/build" -Method POST -Headers $headers

# Test (unit)
Invoke-RestMethod "$base/ops/test?suite=unit" -Method POST -Headers $headers

# Ops health
Invoke-RestMethod "$base/ops/health" -Headers $headers
```

---

## C# Examples

```csharp
using var client = new HttpClient();
client.BaseAddress = new Uri("http://127.0.0.1:5199");
client.DefaultRequestHeaders.Authorization = 
    new AuthenticationHeaderValue("Bearer", "your-token");

var tenant = Guid.Parse("...");

// Agent states
var states = await client.GetFromJsonAsync<List<AgentStateDto>>($"/db/agent-states?tenant={tenant}");

// Free query
var response = await client.PostAsync("/db/query", 
    new StringContent("SELECT * FROM public.tenants", Encoding.UTF8, "text/plain"));
var result = await response.Content.ReadFromJsonAsync<QueryResult>();

// Shell control
await client.PostAsync("/shell/start", null);
var status = await client.GetFromJsonAsync<ShellStatus>("/shell/status");
await client.PostAsync("/shell/stop", null);

// Build
var build = await client.PostAsync("/ops/build", null);
var buildResult = await build.Content.ReadFromJsonAsync<BuildResult>();

// Test
var test = await client.PostAsync("/ops/test?suite=unit", null);
```

---

## /db/query Security

The free SELECT endpoint has these guards:

1. **SELECT/WITH only** — query must start with SELECT or WITH
2. **No multi-statement** — semicolons rejected
3. **No dangerous keywords** — INSERT, UPDATE, DELETE, DROP, CREATE, ALTER, 
   TRUNCATE, GRANT, REVOKE, COPY, pg_read_file, pg_ls_dir, lo_*, dblink, pg_sleep
4. **Length limit** — max 10,000 characters
5. **Timeout** — 8 second statement timeout
6. **Row cap** — max 5,000 rows returned (truncated flag if more)
7. **Read-only role** — soma_ro has no write privileges anyway

---

## Audit Log

All control/exec operations are logged to `soma-audit.log`:

```
2026-06-23T14:30:00.000Z|SHELL_START|exe=dotnet|args=watch run --project src/CcDashboard.Web|cwd=...
2026-06-23T14:30:45.000Z|SHELL_STARTED|pid=12345|healthy=true
2026-06-23T14:35:00.000Z|OPS_BUILD|start
2026-06-23T14:35:30.000Z|OPS_BUILD|exitCode=0
2026-06-23T14:40:00.000Z|DB_QUERY|len=45|preview=SELECT * FROM public.tenants...
```

---

## Notes

- Never expose Soma outside localhost
- Token should be rotated periodically
- Soma only controls processes it started (manual `dotnet watch run` is untouched)
- AuditLogPath/ShellLogPath default to app directory if not configured