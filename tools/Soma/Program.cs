using System.Diagnostics;
using System.Text.Json;
using System.Text.RegularExpressions;
using Npgsql;

var builder = WebApplication.CreateBuilder(args);

var config = builder.Configuration.GetSection("Soma");

bool IsUnset(string? v) => string.IsNullOrWhiteSpace(v) || v.StartsWith("<FILL", StringComparison.OrdinalIgnoreCase);

var configErrors = new List<string>();
var portRaw = config["Port"];
int port = 5199;
if (IsUnset(portRaw))
{
    configErrors.Add($"  - Port: должен быть числом, напр. 5199 (сейчас: '{portRaw ?? "(пусто)"}')");
}
else if (!int.TryParse(portRaw, out port))
{
    configErrors.Add($"  - Port: должен быть числом, напр. 5199 (сейчас: '{portRaw}')");
}

var tokenRaw = config["Token"];
if (IsUnset(tokenRaw))
{
    configErrors.Add("  - Token: задай длинный случайный токен (см. README)");
}

var connStrRaw = config["ReadonlyConnectionString"];
if (IsUnset(connStrRaw) || (connStrRaw?.Contains("<FILL") ?? false))
{
    configErrors.Add("  - ReadonlyConnectionString: впиши пароль soma_ro");
}

var serilogPath = config["SerilogPath"];
if (IsUnset(serilogPath))
{
    Console.WriteLine("[warn] SerilogPath не задан — /logs/serilog вернёт ошибку, пока не заполнишь");
}

if (configErrors.Count > 0)
{
    Console.Error.WriteLine();
    Console.Error.WriteLine("Soma: конфиг не готов. Заполни tools/Soma/appsettings.json (секция \"Soma\"):");
    Console.Error.WriteLine();
    foreach (var err in configErrors)
        Console.Error.WriteLine(err);
    Console.Error.WriteLine();
    Console.Error.WriteLine("См. tools/Soma/README.md");
    Console.Error.WriteLine();
    Environment.Exit(1);
}

var token = tokenRaw!;
var connStr = connStrRaw!;
var auditLogPath = config["AuditLogPath"] ?? Path.Combine(AppContext.BaseDirectory, "soma-audit.log");
var shellLogPath = config["ShellLogPath"] ?? Path.Combine(AppContext.BaseDirectory, "soma-shell.log");

var shellConfig = config.GetSection("Shell");
var shellWorkingDir = shellConfig["WorkingDir"] ?? Directory.GetCurrentDirectory();
var shellExe = shellConfig["Exe"] ?? "dotnet";
var shellArgs = shellConfig.GetSection("Args").Get<string[]>() ?? new[] { "watch", "run", "--project", "src/CcDashboard.Web" };
var shellHealthUrl = shellConfig["HealthUrl"] ?? "http://localhost:7196/health";

builder.WebHost.ConfigureKestrel(opts =>
{
    opts.ListenLocalhost(port);
});

var app = builder.Build();

Process? trackedShellProcess = null;
var shellLock = new object();

void AuditLog(string action, string details)
{
    var entry = $"{DateTime.UtcNow:O}|{action}|{details}";
    try { File.AppendAllText(auditLogPath, entry + Environment.NewLine); } catch { }
}

// Resolve log path: if file -> return it; if folder -> return newest .txt/.log/.json (Serilog rotates daily)
string? ResolveLogFile(string? path)
{
    if (string.IsNullOrWhiteSpace(path)) return null;
    if (File.Exists(path)) return path;
    if (Directory.Exists(path))
    {
        var newest = new DirectoryInfo(path)
            .GetFiles("*.*").Where(f => f.Extension is ".txt" or ".log" or ".json")
            .OrderByDescending(f => f.LastWriteTimeUtc).FirstOrDefault();
        return newest?.FullName;
    }
    return null;
}

// Read lines from a file with sharing (Serilog holds it open)
string[] ReadLinesShared(string path)
{
    using var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
    using var sr = new StreamReader(fs);
    var lines = new List<string>();
    string? line;
    while ((line = sr.ReadLine()) != null)
        lines.Add(line);
    return lines.ToArray();
}

app.Use(async (ctx, next) =>
{
    if (ctx.Request.Path == "/health")
    {
        await next();
        return;
    }
    var auth = ctx.Request.Headers.Authorization.ToString();
    if (string.IsNullOrEmpty(auth) || !auth.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
    {
        ctx.Response.StatusCode = 401;
        await ctx.Response.WriteAsync("Unauthorized: Bearer token required");
        return;
    }
    var provided = auth["Bearer ".Length..].Trim();
    if (provided != token)
    {
        ctx.Response.StatusCode = 401;
        await ctx.Response.WriteAsync("Unauthorized: Invalid token");
        return;
    }
    await next();
});

var reportWhitelist = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
{
    "hist_queue_intervals",
    "hist_agent_intervals"
};

var logSourceWhitelist = new Dictionary<string, Func<string?>>(StringComparer.OrdinalIgnoreCase)
{
    ["serilog"] = () => ResolveLogFile(serilogPath),
    ["soma-shell"] = () => ResolveLogFile(shellLogPath),
    ["soma-audit"] = () => ResolveLogFile(auditLogPath)
};

var testSuiteWhitelist = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
{
    ["unit"] = "tests/CcDashboard.Tests.Unit",
    ["integration"] = "tests/CcDashboard.Tests.Integration",
    ["architecture"] = "tests/CcDashboard.Tests.Architecture",
    ["security"] = "tests/CcDashboard.Tests.Security"
};

var dangerousSqlPatterns = new Regex(
    @"\b(INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|TRUNCATE|GRANT|REVOKE|COPY|pg_read_file|pg_ls_dir|lo_import|lo_export|dblink|pg_sleep)\b",
    RegexOptions.IgnoreCase | RegexOptions.Compiled);

app.MapGet("/health", () => Results.Json(new { ok = true, version = "2.0.2", service = "Soma" }));

app.MapGet("/db/agent-states", async (Guid? tenant) =>
{
    if (tenant is null || tenant == Guid.Empty)
        return Results.BadRequest("tenant is required and must be a valid GUID");

    await using var conn = new NpgsqlConnection(connStr);
    await conn.OpenAsync();

    var results = new List<object>();
    var sql = @"
        SELECT tas.""Id"", tas.""AgentStateName"", tas.""IsActive"", tas.""TenantId"",
               tasg.""GroupName"" as ""MappedGroup""
        FROM public.tenant_agent_states tas
        LEFT JOIN public.tenant_agent_state_definitions tasd ON tas.""Id"" = tasd.""AgentStateId"" AND tasd.""TenantId"" = @t
        LEFT JOIN public.tenant_agent_state_groups tasg ON tasd.""AgentStateGroupId"" = tasg.""Id""
        WHERE tas.""TenantId"" = @t
        ORDER BY tas.""AgentStateName""
    ";
    await using var cmd = new NpgsqlCommand(sql, conn);
    cmd.Parameters.AddWithValue("t", tenant.Value);
    await using var rdr = await cmd.ExecuteReaderAsync();
    while (await rdr.ReadAsync())
    {
        results.Add(new
        {
            Id = rdr.GetGuid(0),
            AgentStateName = rdr.GetString(1),
            IsActive = rdr.GetBoolean(2),
            TenantId = rdr.GetGuid(3),
            MappedGroup = rdr.IsDBNull(4) ? null : rdr.GetString(4)
        });
    }
    return Results.Json(results);
});

app.MapGet("/db/queues", async (Guid? tenant) =>
{
    if (tenant is null || tenant == Guid.Empty)
        return Results.BadRequest("tenant is required and must be a valid GUID");

    await using var conn = new NpgsqlConnection(connStr);
    await conn.OpenAsync();

    var results = new List<object>();
    var sql = @"
        SELECT q.""Id"", q.""ExternalId"", q.""Name"", q.""IsActive"", q.""TenantId"",
               (SELECT COUNT(*) FROM public.""RTSData_Interaction"" i WHERE i.""Workgroup"" = q.""ExternalId"" AND i.""TenantId"" = @t) as ""ActiveInteractions""
        FROM public.queues q
        WHERE q.""TenantId"" = @t
        ORDER BY q.""Name""
    ";
    await using var cmd = new NpgsqlCommand(sql, conn);
    cmd.Parameters.AddWithValue("t", tenant.Value);
    await using var rdr = await cmd.ExecuteReaderAsync();
    while (await rdr.ReadAsync())
    {
        results.Add(new
        {
            Id = rdr.GetGuid(0),
            ExternalId = rdr.IsDBNull(1) ? null : rdr.GetString(1),
            Name = rdr.GetString(2),
            IsActive = rdr.GetBoolean(3),
            TenantId = rdr.GetGuid(4),
            ActiveInteractions = rdr.GetInt64(5)
        });
    }
    return Results.Json(results);
});

app.MapGet("/db/dashboards", async (Guid? tenant) =>
{
    if (tenant is null || tenant == Guid.Empty)
        return Results.BadRequest("tenant is required and must be a valid GUID");

    await using var conn = new NpgsqlConnection(connStr);
    await conn.OpenAsync();

    var results = new List<object>();
    var sql = @"
        SELECT d.""Id"", d.""Name"", d.""Description"", d.""IsPublic"", d.""IsDeleted"",
               d.""CreatedAt"", d.""TenantId""
        FROM public.dashboards d
        WHERE d.""TenantId"" = @t
        ORDER BY d.""Name""
    ";
    await using var cmd = new NpgsqlCommand(sql, conn);
    cmd.Parameters.AddWithValue("t", tenant.Value);
    await using var rdr = await cmd.ExecuteReaderAsync();
    var dashboards = new List<(Guid Id, string Name, string? Desc, bool Public, bool Deleted, DateTime Created)>();
    while (await rdr.ReadAsync())
    {
        dashboards.Add((
            rdr.GetGuid(0),
            rdr.GetString(1),
            rdr.IsDBNull(2) ? null : rdr.GetString(2),
            rdr.GetBoolean(3),
            rdr.GetBoolean(4),
            rdr.GetDateTime(5)
        ));
    }

    foreach (var db in dashboards)
    {
        var widgets = new List<object>();
        var widgetSql = @"
            SELECT w.""Id"", w.""WidgetCatalogItemId"", w.""PositionJson"", w.""ConfigJson""
            FROM public.dashboard_widgets w
            WHERE w.""DashboardId"" = @d
        ";
        await using var wcmd = new NpgsqlCommand(widgetSql, conn);
        wcmd.Parameters.AddWithValue("d", db.Id);
        await using var wrdr = await wcmd.ExecuteReaderAsync();
        while (await wrdr.ReadAsync())
        {
            widgets.Add(new
            {
                Id = wrdr.GetGuid(0),
                WidgetCatalogItemId = wrdr.IsDBNull(1) ? (Guid?)null : wrdr.GetGuid(1),
                PositionJson = wrdr.IsDBNull(2) ? null : wrdr.GetString(2),
                ConfigJson = wrdr.IsDBNull(3) ? null : wrdr.GetString(3)
            });
        }
        results.Add(new
        {
            db.Id,
            db.Name,
            Description = db.Desc,
            IsPublic = db.Public,
            IsDeleted = db.Deleted,
            CreatedAt = db.Created,
            Widgets = widgets
        });
    }
    return Results.Json(results);
});

app.MapGet("/db/report", async (string? name, Guid? tenant, DateTime? from, DateTime? to) =>
{
    if (string.IsNullOrWhiteSpace(name))
        return Results.BadRequest("name is required");
    if (!reportWhitelist.Contains(name))
        return Results.NotFound($"Unknown report: {name}. Allowed: {string.Join(", ", reportWhitelist)}");
    if (tenant is null || tenant == Guid.Empty)
        return Results.BadRequest("tenant is required");
    if (from is null || to is null)
        return Results.BadRequest("from and to are required (UTC dates)");

    await using var conn = new NpgsqlConnection(connStr);
    await conn.OpenAsync();

    string sql = name.ToLowerInvariant() switch
    {
        "hist_queue_intervals" => @"
            SELECT * FROM public.hist_queue_intervals
            WHERE ""TenantId"" = @t AND ""IntervalStart"" >= @f AND ""IntervalStart"" < @to
            ORDER BY ""IntervalStart"" LIMIT 1000
        ",
        "hist_agent_intervals" => @"
            SELECT * FROM public.hist_agent_intervals
            WHERE ""TenantId"" = @t AND ""IntervalStart"" >= @f AND ""IntervalStart"" < @to
            ORDER BY ""IntervalStart"" LIMIT 1000
        ",
        _ => throw new InvalidOperationException("Unknown report")
    };

    await using var cmd = new NpgsqlCommand(sql, conn);
    cmd.Parameters.AddWithValue("t", tenant.Value);
    cmd.Parameters.AddWithValue("f", from.Value.ToUniversalTime());
    cmd.Parameters.AddWithValue("to", to.Value.ToUniversalTime());

    var results = new List<Dictionary<string, object?>>();
    await using var rdr = await cmd.ExecuteReaderAsync();
    while (await rdr.ReadAsync())
    {
        var row = new Dictionary<string, object?>();
        for (int i = 0; i < rdr.FieldCount; i++)
        {
            row[rdr.GetName(i)] = rdr.IsDBNull(i) ? null : rdr.GetValue(i);
        }
        results.Add(row);
    }
    return Results.Json(results);
});

app.MapPost("/db/query", async (HttpContext ctx) =>
{
    using var reader = new StreamReader(ctx.Request.Body);
    var body = await reader.ReadToEndAsync();

    string sql;
    try
    {
        using var doc = JsonDocument.Parse(body);
        if (doc.RootElement.TryGetProperty("sql", out var sqlProp) ||
            doc.RootElement.TryGetProperty("Sql", out sqlProp) ||
            doc.RootElement.TryGetProperty("SQL", out sqlProp))
        {
            sql = sqlProp.GetString() ?? "";
        }
        else
        {
            sql = body;
        }
    }
    catch (JsonException)
    {
        sql = body;
    }

    if (string.IsNullOrWhiteSpace(sql))
        return Results.BadRequest("SQL query required in body (JSON {\"sql\":\"...\"} or raw text)");
    if (sql.Length > 10000)
        return Results.BadRequest("Query too long (max 10000 chars)");
    if (sql.Contains(';'))
        return Results.BadRequest("Multi-statement queries not allowed");
    
    var trimmed = sql.Trim();
    if (!trimmed.StartsWith("SELECT", StringComparison.OrdinalIgnoreCase) &&
        !trimmed.StartsWith("WITH", StringComparison.OrdinalIgnoreCase))
        return Results.BadRequest("Only SELECT/WITH queries allowed");
    
    if (dangerousSqlPatterns.IsMatch(sql))
        return Results.BadRequest("Query contains forbidden keywords");

    AuditLog("DB_QUERY", $"len={sql.Length}|preview={sql[..Math.Min(100, sql.Length)]}");

    await using var conn = new NpgsqlConnection(connStr);
    await conn.OpenAsync();

    await using var timeoutCmd = new NpgsqlCommand("SET LOCAL statement_timeout = '8s'", conn);
    await timeoutCmd.ExecuteNonQueryAsync();

    await using var cmd = new NpgsqlCommand(sql, conn);
    var results = new List<Dictionary<string, object?>>();
    var truncated = false;
    const int RowCap = 5000;

    try
    {
        await using var rdr = await cmd.ExecuteReaderAsync();
        while (await rdr.ReadAsync())
        {
            if (results.Count >= RowCap)
            {
                truncated = true;
                break;
            }
            var row = new Dictionary<string, object?>();
            for (int i = 0; i < rdr.FieldCount; i++)
            {
                row[rdr.GetName(i)] = rdr.IsDBNull(i) ? null : rdr.GetValue(i);
            }
            results.Add(row);
        }
    }
    catch (PostgresException ex)
    {
        return Results.BadRequest($"SQL error: {ex.MessageText}");
    }

    return Results.Json(new { rows = results, truncated, rowCount = results.Count });
});

app.MapGet("/logs/tail", (string? source, int? n) =>
{
    if (string.IsNullOrWhiteSpace(source))
        return Results.BadRequest("source is required");
    if (!logSourceWhitelist.TryGetValue(source, out var pathFn))
        return Results.NotFound($"Unknown source: {source}. Allowed: {string.Join(", ", logSourceWhitelist.Keys)}");
    
    var path = pathFn();
    if (string.IsNullOrWhiteSpace(path))
        return Results.BadRequest($"Path not configured for source: {source}");

    var count = n ?? 100;
    if (count < 1 || count > 2000)
        return Results.BadRequest("n must be 1..2000");

    if (path is null || !File.Exists(path))
        return Results.NotFound($"Log file not found: {path ?? "(unresolved)"}");

    var lines = ReadLinesShared(path).TakeLast(count).ToArray();
    return Results.Json(new { source, path, lineCount = lines.Length, lines });
});

app.MapGet("/logs/serilog", (int? tail, string? contains) =>
{
    if (IsUnset(serilogPath))
        return Results.Problem("SerilogPath not configured", statusCode: 500);
    
    var file = ResolveLogFile(serilogPath);
    if (file is null)
        return Results.Problem($"Serilog file not found under: {serilogPath}", statusCode: 500);
    
    var n = tail ?? 100;
    if (n < 1 || n > 2000)
        return Results.BadRequest("tail must be 1..2000");

    var lines = ReadLinesShared(file);
    IEnumerable<string> result = lines.TakeLast(n);
    
    if (!string.IsNullOrWhiteSpace(contains))
        result = result.Where(l => l.Contains(contains, StringComparison.OrdinalIgnoreCase));

    return Results.Json(result.ToArray());
});

app.MapGet("/shell/status", () =>
{
    lock (shellLock)
    {
        if (trackedShellProcess is null || trackedShellProcess.HasExited)
        {
            return Results.Json(new { running = false, pid = (int?)null, healthy = false });
        }
        var healthy = false;
        try
        {
            using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(3) };
            var resp = http.GetAsync(shellHealthUrl).GetAwaiter().GetResult();
            healthy = resp.IsSuccessStatusCode;
        }
        catch { }
        return Results.Json(new { running = true, pid = trackedShellProcess.Id, healthy });
    }
});

app.MapPost("/shell/start", async () =>
{
    lock (shellLock)
    {
        if (trackedShellProcess is not null && !trackedShellProcess.HasExited)
        {
            return Results.Conflict(new { error = "Shell already running (tracked)", pid = trackedShellProcess.Id });
        }
    }

    // Guard: check if Shell is already up (started manually, not tracked by Soma)
    try
    {
        using var probe = new HttpClient { Timeout = TimeSpan.FromSeconds(2) };
        var probeResp = await probe.GetAsync(shellHealthUrl);
        if (probeResp.IsSuccessStatusCode)
        {
            return Results.Json(new { running = true, tracked = false, healthy = true, note = "Shell already up (untracked)" });
        }
    }
    catch { /* Shell not responding - proceed to start */ }

    AuditLog("SHELL_START", $"exe={shellExe}|args={string.Join(" ", shellArgs)}|cwd={shellWorkingDir}");

    var psi = new ProcessStartInfo
    {
        FileName = shellExe,
        WorkingDirectory = shellWorkingDir,
        UseShellExecute = false,
        RedirectStandardOutput = true,
        RedirectStandardError = true,
        CreateNoWindow = true
    };
    foreach (var arg in shellArgs)
        psi.ArgumentList.Add(arg);

    StreamWriter logFile;
    Process proc;
    try
    {
        logFile = new StreamWriter(new FileStream(shellLogPath, FileMode.Append, FileAccess.Write, FileShare.ReadWrite)) { AutoFlush = true };
        proc = Process.Start(psi)!;
    }
    catch (Exception ex)
    {
        return Results.Problem($"Failed to start shell: {ex.Message}", statusCode: 500);
    }

    proc.OutputDataReceived += (_, e) => { if (e.Data != null) { lock (logFile) { logFile.WriteLine(e.Data); } } };
    proc.ErrorDataReceived += (_, e) => { if (e.Data != null) { lock (logFile) { logFile.WriteLine($"[ERR] {e.Data}"); } } };
    proc.BeginOutputReadLine();
    proc.BeginErrorReadLine();

    lock (shellLock)
    {
        trackedShellProcess = proc;
    }

    var healthy = false;
    using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
    for (int i = 0; i < 12; i++)
    {
        await Task.Delay(5000);
        try
        {
            var resp = await http.GetAsync(shellHealthUrl);
            if (resp.IsSuccessStatusCode)
            {
                healthy = true;
                break;
            }
        }
        catch { }
    }

    AuditLog("SHELL_STARTED", $"pid={proc.Id}|healthy={healthy}");
    return Results.Json(new { running = true, tracked = true, pid = proc.Id, healthy });
});

app.MapPost("/shell/stop", () =>
{
    lock (shellLock)
    {
        if (trackedShellProcess is null || trackedShellProcess.HasExited)
        {
            return Results.Json(new { stopped = false, reason = "No tracked shell process running" });
        }

        var pid = trackedShellProcess.Id;
        AuditLog("SHELL_STOP", $"pid={pid}");

        try
        {
            trackedShellProcess.Kill(entireProcessTree: true);
            trackedShellProcess.WaitForExit(10000);
        }
        catch (Exception ex)
        {
            return Results.Problem($"Failed to stop shell: {ex.Message}");
        }

        trackedShellProcess = null;
        AuditLog("SHELL_STOPPED", $"pid={pid}");
        return Results.Json(new { stopped = true, pid });
    }
});

app.MapPost("/shell/restart", async () =>
{
    lock (shellLock)
    {
        if (trackedShellProcess is not null && !trackedShellProcess.HasExited)
        {
            var pid = trackedShellProcess.Id;
            AuditLog("SHELL_RESTART_STOP", $"pid={pid}");
            try
            {
                trackedShellProcess.Kill(entireProcessTree: true);
                trackedShellProcess.WaitForExit(10000);
            }
            catch { }
            trackedShellProcess = null;
        }
    }

    AuditLog("SHELL_RESTART_START", $"exe={shellExe}");
    var psi = new ProcessStartInfo
    {
        FileName = shellExe,
        WorkingDirectory = shellWorkingDir,
        UseShellExecute = false,
        RedirectStandardOutput = true,
        RedirectStandardError = true,
        CreateNoWindow = true
    };
    foreach (var arg in shellArgs)
        psi.ArgumentList.Add(arg);

    StreamWriter logFile;
    Process proc;
    try
    {
        logFile = new StreamWriter(new FileStream(shellLogPath, FileMode.Append, FileAccess.Write, FileShare.ReadWrite)) { AutoFlush = true };
        proc = Process.Start(psi)!;
    }
    catch (Exception ex)
    {
        return Results.Problem($"Failed to start shell: {ex.Message}", statusCode: 500);
    }

    proc.OutputDataReceived += (_, e) => { if (e.Data != null) { lock (logFile) { logFile.WriteLine(e.Data); } } };
    proc.ErrorDataReceived += (_, e) => { if (e.Data != null) { lock (logFile) { logFile.WriteLine($"[ERR] {e.Data}"); } } };
    proc.BeginOutputReadLine();
    proc.BeginErrorReadLine();

    lock (shellLock)
    {
        trackedShellProcess = proc;
    }

    var healthy = false;
    using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
    for (int i = 0; i < 12; i++)
    {
        await Task.Delay(5000);
        try
        {
            var resp = await http.GetAsync(shellHealthUrl);
            if (resp.IsSuccessStatusCode)
            {
                healthy = true;
                break;
            }
        }
        catch { }
    }

    AuditLog("SHELL_RESTARTED", $"pid={proc.Id}|healthy={healthy}");
    return Results.Json(new { running = true, pid = proc.Id, healthy });
});

app.MapPost("/ops/build", async () =>
{
    AuditLog("OPS_BUILD", "start");

    var psi = new ProcessStartInfo
    {
        FileName = "dotnet",
        WorkingDirectory = shellWorkingDir,
        UseShellExecute = false,
        RedirectStandardOutput = true,
        RedirectStandardError = true,
        CreateNoWindow = true
    };
    psi.ArgumentList.Add("build");
    psi.ArgumentList.Add("CcDashboard.sln");

    var output = new List<string>();
    using var proc = Process.Start(psi)!;
    proc.OutputDataReceived += (_, e) => { if (e.Data != null) output.Add(e.Data); };
    proc.ErrorDataReceived += (_, e) => { if (e.Data != null) output.Add($"[ERR] {e.Data}"); };
    proc.BeginOutputReadLine();
    proc.BeginErrorReadLine();

    var completed = await Task.Run(() => proc.WaitForExit(300000));
    if (!completed)
    {
        proc.Kill(entireProcessTree: true);
        AuditLog("OPS_BUILD", "timeout");
        return Results.Json(new { success = false, exitCode = -1, reason = "timeout", tail = output.TakeLast(50).ToArray() });
    }

    AuditLog("OPS_BUILD", $"exitCode={proc.ExitCode}");
    return Results.Json(new { success = proc.ExitCode == 0, exitCode = proc.ExitCode, tail = output.TakeLast(50).ToArray() });
});

app.MapPost("/ops/test", async (string? suite) =>
{
    if (string.IsNullOrWhiteSpace(suite))
        return Results.BadRequest("suite is required");
    if (!testSuiteWhitelist.TryGetValue(suite, out var project))
        return Results.NotFound($"Unknown suite: {suite}. Allowed: {string.Join(", ", testSuiteWhitelist.Keys)}");

    AuditLog("OPS_TEST", $"suite={suite}|project={project}");

    var psi = new ProcessStartInfo
    {
        FileName = "dotnet",
        WorkingDirectory = shellWorkingDir,
        UseShellExecute = false,
        RedirectStandardOutput = true,
        RedirectStandardError = true,
        CreateNoWindow = true
    };
    psi.ArgumentList.Add("test");
    psi.ArgumentList.Add(project);

    var output = new List<string>();
    using var proc = Process.Start(psi)!;
    proc.OutputDataReceived += (_, e) => { if (e.Data != null) output.Add(e.Data); };
    proc.ErrorDataReceived += (_, e) => { if (e.Data != null) output.Add($"[ERR] {e.Data}"); };
    proc.BeginOutputReadLine();
    proc.BeginErrorReadLine();

    var completed = await Task.Run(() => proc.WaitForExit(600000));
    if (!completed)
    {
        proc.Kill(entireProcessTree: true);
        AuditLog("OPS_TEST", $"suite={suite}|timeout");
        return Results.Json(new { success = false, exitCode = -1, reason = "timeout", tail = output.TakeLast(100).ToArray() });
    }

    AuditLog("OPS_TEST", $"suite={suite}|exitCode={proc.ExitCode}");
    return Results.Json(new { success = proc.ExitCode == 0, exitCode = proc.ExitCode, tail = output.TakeLast(100).ToArray() });
});

app.MapGet("/ops/health", async () =>
{
    using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
    var liveness = new { up = false, latencyMs = 0L };
    var readiness = new { up = false, latencyMs = 0L };

    try
    {
        var sw = Stopwatch.StartNew();
        var resp = await http.GetAsync(shellHealthUrl);
        sw.Stop();
        liveness = new { up = resp.IsSuccessStatusCode, latencyMs = sw.ElapsedMilliseconds };
    }
    catch { }

    try
    {
        var readyUrl = shellHealthUrl.Replace("/health", "/health/ready");
        var sw = Stopwatch.StartNew();
        var resp = await http.GetAsync(readyUrl);
        sw.Stop();
        readiness = new { up = resp.IsSuccessStatusCode, latencyMs = sw.ElapsedMilliseconds };
    }
    catch { }

    return Results.Json(new { liveness, readiness });
});

app.Run();