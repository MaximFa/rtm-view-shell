using System.Diagnostics;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Collections.Concurrent;
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

// CC config
var ccConfig = config.GetSection("Cc");
var ccExe = ccConfig["Exe"] ?? "claude";
var ccSkipPermissions = bool.TryParse(ccConfig["SkipPermissions"], out var sp) && sp;
var repoRoot = ccConfig["RepoRoot"] ?? shellWorkingDir;
var promptsDir = ccConfig["PromptsDir"] ?? "tools";
var ccRunsDir = Path.Combine(AppContext.BaseDirectory, "cc-runs");
var ccRunsJsonPath = Path.Combine(AppContext.BaseDirectory, "cc-runs.json");

Directory.CreateDirectory(ccRunsDir);

builder.WebHost.ConfigureKestrel(opts => { opts.ListenLocalhost(port); });

var app = builder.Build();

Process? trackedShellProcess = null;
var shellLock = new object();
var ccRunsLock = new object();
var activeRuns = new ConcurrentDictionary<string, Process>();

void AuditLog(string action, string details)
{
    var entry = $"{DateTime.UtcNow:O}|{action}|{details}";
    try { File.AppendAllText(auditLogPath, entry + Environment.NewLine); } catch { }
}

// Build ProcessStartInfo for CC exe (handles .ps1/.cmd npm shims on Windows)
ProcessStartInfo BuildCcProcess(string exe, string workDir, IEnumerable<string> args)
{
    var psi = new ProcessStartInfo
    {
        WorkingDirectory = workDir,
        UseShellExecute = false,
        RedirectStandardOutput = true,
        RedirectStandardError = true,
        CreateNoWindow = true
    };

    var ext = Path.GetExtension(exe).ToLowerInvariant();
    if (ext == ".ps1")
    {
        psi.FileName = "powershell.exe";
        psi.ArgumentList.Add("-NoProfile");
        psi.ArgumentList.Add("-ExecutionPolicy");
        psi.ArgumentList.Add("Bypass");
        psi.ArgumentList.Add("-File");
        psi.ArgumentList.Add(exe);
    }
    else if (ext == ".cmd" || ext == ".bat")
    {
        psi.FileName = "cmd.exe";
        psi.ArgumentList.Add("/c");
        psi.ArgumentList.Add(exe);
    }
    else
    {
        psi.FileName = exe;
    }

    foreach (var arg in args)
        psi.ArgumentList.Add(arg);

    return psi;
}

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

string[] ReadLinesShared(string path)
{
    using var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
    using var sr = new StreamReader(fs);
    var lines = new List<string>();
    string? line;
    while ((line = sr.ReadLine()) != null) lines.Add(line);
    return lines.ToArray();
}

string ReadTextShared(string path)
{
    using var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
    using var sr = new StreamReader(fs);
    return sr.ReadToEnd();
}

List<CcRunEntry> LoadCcRuns()
{
    lock (ccRunsLock)
    {
        if (!File.Exists(ccRunsJsonPath)) return new List<CcRunEntry>();
        try { var json = File.ReadAllText(ccRunsJsonPath); return JsonSerializer.Deserialize<List<CcRunEntry>>(json) ?? new List<CcRunEntry>(); }
        catch { return new List<CcRunEntry>(); }
    }
}

void SaveCcRuns(List<CcRunEntry> runs)
{
    lock (ccRunsLock)
    {
        var json = JsonSerializer.Serialize(runs, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(ccRunsJsonPath, json);
    }
}

void UpdateCcRun(string runId, Action<CcRunEntry> update)
{
    var runs = LoadCcRuns();
    var entry = runs.FirstOrDefault(r => r.RunId == runId);
    if (entry != null) { update(entry); SaveCcRuns(runs); }
}

{ var runs = LoadCcRuns(); var changed = false;
  foreach (var r in runs.Where(r => r.Status == "running" && r.StartedAt < DateTime.UtcNow.AddHours(-6)))
  { r.Status = "interrupted"; r.FinishedAt = DateTime.UtcNow; changed = true; }
  if (changed) SaveCcRuns(runs); }

var promptFileRegex = new Regex(@"^tools[/\\]cc_prompt_[A-Za-z0-9_.\-]+\.md$", RegexOptions.Compiled);

bool ValidatePromptFile(string promptFile, out string? error)
{
    error = null;
    if (string.IsNullOrWhiteSpace(promptFile)) { error = "promptFile is required"; return false; }
    if (!promptFileRegex.IsMatch(promptFile)) { error = "promptFile must match pattern: tools/cc_prompt_*.md"; return false; }
    var normalized = promptFile.Replace('\\', '/');
    if (normalized.Contains("..")) { error = "promptFile cannot contain '..'"; return false; }
    var fullPath = Path.GetFullPath(Path.Combine(repoRoot, promptFile));
    if (!fullPath.StartsWith(repoRoot, StringComparison.OrdinalIgnoreCase)) { error = "promptFile must be inside repository root"; return false; }
    if (!File.Exists(fullPath)) { error = $"promptFile not found: {promptFile}"; return false; }
    return true;
}

app.Use(async (ctx, next) =>
{
    if (ctx.Request.Path == "/health" || ctx.Request.Path == "/ui")
    { await next(); return; }
    var auth = ctx.Request.Headers.Authorization.ToString();
    if (string.IsNullOrEmpty(auth) || !auth.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
    { ctx.Response.StatusCode = 401; await ctx.Response.WriteAsync("Unauthorized: Bearer token required"); return; }
    var provided = auth["Bearer ".Length..].Trim();
    if (provided != token)
    { ctx.Response.StatusCode = 401; await ctx.Response.WriteAsync("Unauthorized: Invalid token"); return; }
    await next();
});

var reportWhitelist = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "hist_queue_intervals", "hist_agent_intervals" };

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

app.MapGet("/health", () => Results.Json(new { ok = true, version = "2.3.0", service = "Soma" }));

app.MapGet("/ui", () => Results.Content(GenerateUiHtml(token), "text/html"));

app.MapGet("/cc/prompts", () =>
{
    var promptsPath = Path.Combine(repoRoot, promptsDir);
    if (!Directory.Exists(promptsPath)) return Results.Json(Array.Empty<object>());
    var runs = LoadCcRuns();
    var files = Directory.GetFiles(promptsPath, "cc_prompt_*.md")
        .Select(f => new FileInfo(f)).OrderByDescending(f => f.LastWriteTimeUtc)
        .Select(f => {
            var relPath = Path.Combine(promptsDir, f.Name).Replace('\\', '/');
            var lastRun = runs.Where(r => r.PromptFile == relPath).OrderByDescending(r => r.StartedAt).FirstOrDefault();
            return new { file = relPath, mtime = f.LastWriteTimeUtc, lastStatus = lastRun?.Status, lastRunAt = lastRun?.StartedAt, lastRunId = lastRun?.RunId };
        }).ToArray();
    return Results.Json(files);
});

app.MapPost("/cc/run", async (HttpContext ctx) =>
{
    using var reader = new StreamReader(ctx.Request.Body);
    var body = await reader.ReadToEndAsync();
    string promptFile;
    try { using var doc = JsonDocument.Parse(body); promptFile = doc.RootElement.GetProperty("promptFile").GetString() ?? ""; }
    catch { return Results.BadRequest("Invalid JSON body, expected {\"promptFile\": \"...\"}"); }
    if (!ValidatePromptFile(promptFile, out var error)) return Results.BadRequest(error);

    var runId = $"{DateTime.UtcNow:yyyyMMdd-HHmmss}-{Guid.NewGuid().ToString()[..8]}";
    var logPath = Path.Combine(ccRunsDir, $"{runId}.log");
    var runs = LoadCcRuns();
    runs.Add(new CcRunEntry { RunId = runId, PromptFile = promptFile, StartedAt = DateTime.UtcNow, Status = "running" });
    SaveCcRuns(runs);
    AuditLog("CC_RUN", $"runId={runId}|promptFile={promptFile}|skipPermissions={ccSkipPermissions}");

    var fullPrompt = $"Выполни задачу из файла {promptFile}. В САМОМ конце ОБЯЗАТЕЛЬНО продублируй в stdout краткий RESULT-блок (commits, build/test, files changed, status done|failed, blockers).";
    var ccArgs = new List<string> { "-p" };
    if (ccSkipPermissions) ccArgs.Add("--dangerously-skip-permissions");
    ccArgs.Add(fullPrompt);
    var psi = BuildCcProcess(ccExe, repoRoot, ccArgs);

    StreamWriter logWriter; Process proc;
    try { logWriter = new StreamWriter(new FileStream(logPath, FileMode.Create, FileAccess.Write, FileShare.ReadWrite)) { AutoFlush = true }; proc = Process.Start(psi)!; }
    catch (Exception ex) { UpdateCcRun(runId, r => { r.Status = "fail"; r.FinishedAt = DateTime.UtcNow; r.ExitCode = -1; }); return Results.Problem($"Failed to start CC: {ex.Message}", statusCode: 500); }

    activeRuns[runId] = proc;
    _ = Task.Run(async () => {
        try {
            proc.OutputDataReceived += (_, e) => { if (e.Data != null) lock (logWriter) { logWriter.WriteLine(e.Data); } };
            proc.ErrorDataReceived += (_, e) => { if (e.Data != null) lock (logWriter) { logWriter.WriteLine($"[ERR] {e.Data}"); } };
            proc.BeginOutputReadLine(); proc.BeginErrorReadLine();
            await proc.WaitForExitAsync();
            lock (logWriter) { logWriter.WriteLine($"\n[EXIT] code={proc.ExitCode} at {DateTime.UtcNow:O}"); }
            logWriter.Dispose();
            UpdateCcRun(runId, r => { r.Status = proc.ExitCode == 0 ? "ok" : "fail"; r.FinishedAt = DateTime.UtcNow; r.ExitCode = proc.ExitCode; });
            AuditLog("CC_RUN_DONE", $"runId={runId}|exitCode={proc.ExitCode}");
        } finally { activeRuns.TryRemove(runId, out _); }
    });
    return Results.Json(new { runId });
});

app.MapGet("/cc/runs/{id}", (string id) =>
{
    var runs = LoadCcRuns();
    var entry = runs.FirstOrDefault(r => r.RunId == id);
    if (entry == null) return Results.NotFound($"Run not found: {id}");
    return Results.Json(entry);
});

app.MapGet("/cc/runs/{id}/log", (string id) =>
{
    var logPath = Path.Combine(ccRunsDir, $"{id}.log");
    if (!File.Exists(logPath)) return Results.NotFound($"Log not found for run: {id}");
    return Results.Text(ReadTextShared(logPath), "text/plain");
});

app.MapPost("/cc/mark-done", async (HttpContext ctx) =>
{
    using var reader = new StreamReader(ctx.Request.Body);
    var body = await reader.ReadToEndAsync();
    string promptFile;
    try { using var doc = JsonDocument.Parse(body); promptFile = doc.RootElement.GetProperty("promptFile").GetString() ?? ""; }
    catch { return Results.BadRequest("Invalid JSON body"); }
    if (!ValidatePromptFile(promptFile, out var error)) return Results.BadRequest(error);

    var runId = $"manual-{DateTime.UtcNow:yyyyMMdd-HHmmss-fff}";
    var now = DateTime.UtcNow;
    var runs = LoadCcRuns();
    runs.Add(new CcRunEntry { RunId = runId, PromptFile = promptFile, StartedAt = now, FinishedAt = now, Status = "ok", ExitCode = 0 });
    SaveCcRuns(runs);
    AuditLog("CC_MARK_DONE", $"promptFile={promptFile}");
    return Results.Json(new { promptFile, status = "ok", manual = true });
});

app.MapPost("/cc/mark-all-done", async (HttpContext ctx) =>
{
    bool onlyUnrun = true;
    try {
        using var reader = new StreamReader(ctx.Request.Body);
        var body = await reader.ReadToEndAsync();
        if (!string.IsNullOrWhiteSpace(body)) {
            using var doc = JsonDocument.Parse(body);
            if (doc.RootElement.TryGetProperty("onlyUnrun", out var prop)) onlyUnrun = prop.GetBoolean();
        }
    } catch { }

    var promptsPath = Path.Combine(repoRoot, promptsDir);
    if (!Directory.Exists(promptsPath)) return Results.Json(new { marked = 0, skipped = 0 });

    var runs = LoadCcRuns();
    var files = Directory.GetFiles(promptsPath, "cc_prompt_*.md");
    int marked = 0, skipped = 0;
    var now = DateTime.UtcNow;

    foreach (var f in files)
    {
        var relPath = Path.Combine(promptsDir, Path.GetFileName(f)).Replace('\\', '/');
        var lastRun = runs.Where(r => r.PromptFile == relPath).OrderByDescending(r => r.StartedAt).FirstOrDefault();
        if (onlyUnrun && lastRun?.Status == "ok") { skipped++; continue; }
        var runId = $"manual-{now:yyyyMMdd-HHmmss-fff}-{marked}";
        runs.Add(new CcRunEntry { RunId = runId, PromptFile = relPath, StartedAt = now, FinishedAt = now, Status = "ok", ExitCode = 0 });
        marked++;
    }

    SaveCcRuns(runs);
    AuditLog("CC_MARK_ALL", $"marked={marked}|skipped={skipped}");
    return Results.Json(new { marked, skipped });
});

app.MapGet("/db/agent-states", async (Guid? tenant) =>
{
    if (tenant is null || tenant == Guid.Empty) return Results.BadRequest("tenant is required and must be a valid GUID");
    await using var conn = new NpgsqlConnection(connStr); await conn.OpenAsync();
    var results = new List<object>();
    var sql = @"SELECT tas.""Id"", tas.""AgentStateName"", tas.""IsActive"", tas.""TenantId"", tasg.""GroupName"" as ""MappedGroup""
        FROM public.tenant_agent_states tas
        LEFT JOIN public.tenant_agent_state_definitions tasd ON tas.""Id"" = tasd.""AgentStateId"" AND tasd.""TenantId"" = @t
        LEFT JOIN public.tenant_agent_state_groups tasg ON tasd.""AgentStateGroupId"" = tasg.""Id""
        WHERE tas.""TenantId"" = @t ORDER BY tas.""AgentStateName""";
    await using var cmd = new NpgsqlCommand(sql, conn); cmd.Parameters.AddWithValue("t", tenant.Value);
    await using var rdr = await cmd.ExecuteReaderAsync();
    while (await rdr.ReadAsync()) { results.Add(new { Id = rdr.GetGuid(0), AgentStateName = rdr.GetString(1), IsActive = rdr.GetBoolean(2), TenantId = rdr.GetGuid(3), MappedGroup = rdr.IsDBNull(4) ? null : rdr.GetString(4) }); }
    return Results.Json(results);
});

app.MapGet("/db/queues", async (Guid? tenant) =>
{
    if (tenant is null || tenant == Guid.Empty) return Results.BadRequest("tenant is required and must be a valid GUID");
    await using var conn = new NpgsqlConnection(connStr); await conn.OpenAsync();
    var results = new List<object>();
    var sql = @"SELECT q.""Id"", q.""ExternalId"", q.""Name"", q.""IsActive"", q.""TenantId"",
        (SELECT COUNT(*) FROM public.""RTSData_Interaction"" i WHERE i.""Workgroup"" = q.""ExternalId"" AND i.""TenantId"" = @t) as ""ActiveInteractions""
        FROM public.queues q WHERE q.""TenantId"" = @t ORDER BY q.""Name""";
    await using var cmd = new NpgsqlCommand(sql, conn); cmd.Parameters.AddWithValue("t", tenant.Value);
    await using var rdr = await cmd.ExecuteReaderAsync();
    while (await rdr.ReadAsync()) { results.Add(new { Id = rdr.GetGuid(0), ExternalId = rdr.IsDBNull(1) ? null : rdr.GetString(1), Name = rdr.GetString(2), IsActive = rdr.GetBoolean(3), TenantId = rdr.GetGuid(4), ActiveInteractions = rdr.GetInt64(5) }); }
    return Results.Json(results);
});

app.MapGet("/db/dashboards", async (Guid? tenant) =>
{
    if (tenant is null || tenant == Guid.Empty) return Results.BadRequest("tenant is required and must be a valid GUID");
    await using var conn = new NpgsqlConnection(connStr); await conn.OpenAsync();
    var sql = @"SELECT d.""Id"", d.""Name"", d.""Description"", d.""IsPublic"", d.""IsDeleted"", d.""CreatedAt"", d.""TenantId"" FROM public.dashboards d WHERE d.""TenantId"" = @t ORDER BY d.""Name""";
    await using var cmd = new NpgsqlCommand(sql, conn); cmd.Parameters.AddWithValue("t", tenant.Value);
    await using var rdr = await cmd.ExecuteReaderAsync();
    var dashboards = new List<(Guid Id, string Name, string? Desc, bool Public, bool Deleted, DateTime Created)>();
    while (await rdr.ReadAsync()) { dashboards.Add((rdr.GetGuid(0), rdr.GetString(1), rdr.IsDBNull(2) ? null : rdr.GetString(2), rdr.GetBoolean(3), rdr.GetBoolean(4), rdr.GetDateTime(5))); }
    var results = new List<object>();
    foreach (var db in dashboards)
    {
        var widgets = new List<object>();
        var widgetSql = @"SELECT w.""Id"", w.""WidgetCatalogItemId"", w.""PositionJson"", w.""ConfigJson"" FROM public.dashboard_widgets w WHERE w.""DashboardId"" = @d";
        await using var wcmd = new NpgsqlCommand(widgetSql, conn); wcmd.Parameters.AddWithValue("d", db.Id);
        await using var wrdr = await wcmd.ExecuteReaderAsync();
        while (await wrdr.ReadAsync()) { widgets.Add(new { Id = wrdr.GetGuid(0), WidgetCatalogItemId = wrdr.IsDBNull(1) ? (Guid?)null : wrdr.GetGuid(1), PositionJson = wrdr.IsDBNull(2) ? null : wrdr.GetString(2), ConfigJson = wrdr.IsDBNull(3) ? null : wrdr.GetString(3) }); }
        results.Add(new { db.Id, db.Name, Description = db.Desc, IsPublic = db.Public, IsDeleted = db.Deleted, CreatedAt = db.Created, Widgets = widgets });
    }
    return Results.Json(results);
});

app.MapGet("/db/report", async (string? name, Guid? tenant, DateTime? from, DateTime? to) =>
{
    if (string.IsNullOrWhiteSpace(name)) return Results.BadRequest("name is required");
    if (!reportWhitelist.Contains(name)) return Results.NotFound($"Unknown report: {name}. Allowed: {string.Join(", ", reportWhitelist)}");
    if (tenant is null || tenant == Guid.Empty) return Results.BadRequest("tenant is required");
    if (from is null || to is null) return Results.BadRequest("from and to are required (UTC dates)");
    await using var conn = new NpgsqlConnection(connStr); await conn.OpenAsync();
    string sql = name.ToLowerInvariant() switch {
        "hist_queue_intervals" => @"SELECT * FROM public.hist_queue_intervals WHERE ""TenantId"" = @t AND ""IntervalStart"" >= @f AND ""IntervalStart"" < @to ORDER BY ""IntervalStart"" LIMIT 1000",
        "hist_agent_intervals" => @"SELECT * FROM public.hist_agent_intervals WHERE ""TenantId"" = @t AND ""IntervalStart"" >= @f AND ""IntervalStart"" < @to ORDER BY ""IntervalStart"" LIMIT 1000",
        _ => throw new InvalidOperationException("Unknown report")
    };
    await using var cmd = new NpgsqlCommand(sql, conn);
    cmd.Parameters.AddWithValue("t", tenant.Value); cmd.Parameters.AddWithValue("f", from.Value.ToUniversalTime()); cmd.Parameters.AddWithValue("to", to.Value.ToUniversalTime());
    var results = new List<Dictionary<string, object?>>();
    await using var rdr = await cmd.ExecuteReaderAsync();
    while (await rdr.ReadAsync()) { var row = new Dictionary<string, object?>(); for (int i = 0; i < rdr.FieldCount; i++) row[rdr.GetName(i)] = rdr.IsDBNull(i) ? null : rdr.GetValue(i); results.Add(row); }
    return Results.Json(results);
});

app.MapPost("/db/query", async (HttpContext ctx) =>
{
    using var reader = new StreamReader(ctx.Request.Body);
    var body = await reader.ReadToEndAsync();
    string sql;
    try { using var doc = JsonDocument.Parse(body);
        if (doc.RootElement.TryGetProperty("sql", out var sqlProp) || doc.RootElement.TryGetProperty("Sql", out sqlProp) || doc.RootElement.TryGetProperty("SQL", out sqlProp))
            sql = sqlProp.GetString() ?? "";
        else sql = body;
    } catch (JsonException) { sql = body; }
    if (string.IsNullOrWhiteSpace(sql)) return Results.BadRequest("SQL query required in body");
    if (sql.Length > 10000) return Results.BadRequest("Query too long (max 10000 chars)");
    if (sql.Contains(';')) return Results.BadRequest("Multi-statement queries not allowed");
    var trimmed = sql.Trim();
    if (!trimmed.StartsWith("SELECT", StringComparison.OrdinalIgnoreCase) && !trimmed.StartsWith("WITH", StringComparison.OrdinalIgnoreCase))
        return Results.BadRequest("Only SELECT/WITH queries allowed");
    if (dangerousSqlPatterns.IsMatch(sql)) return Results.BadRequest("Query contains forbidden keywords");
    AuditLog("DB_QUERY", $"len={sql.Length}|preview={sql[..Math.Min(100, sql.Length)]}");
    await using var conn = new NpgsqlConnection(connStr); await conn.OpenAsync();
    await using var timeoutCmd = new NpgsqlCommand("SET LOCAL statement_timeout = '8s'", conn); await timeoutCmd.ExecuteNonQueryAsync();
    await using var cmd = new NpgsqlCommand(sql, conn);
    var results = new List<Dictionary<string, object?>>(); var truncated = false; const int RowCap = 5000;
    try { await using var rdr = await cmd.ExecuteReaderAsync();
        while (await rdr.ReadAsync()) { if (results.Count >= RowCap) { truncated = true; break; }
            var row = new Dictionary<string, object?>(); for (int i = 0; i < rdr.FieldCount; i++) row[rdr.GetName(i)] = rdr.IsDBNull(i) ? null : rdr.GetValue(i); results.Add(row); }
    } catch (PostgresException ex) { return Results.BadRequest($"SQL error: {ex.MessageText}"); }
    return Results.Json(new { rows = results, truncated, rowCount = results.Count });
});

app.MapGet("/logs/tail", (string? source, int? n) =>
{
    if (string.IsNullOrWhiteSpace(source)) return Results.BadRequest("source is required");
    if (!logSourceWhitelist.TryGetValue(source, out var pathFn)) return Results.NotFound($"Unknown source: {source}. Allowed: {string.Join(", ", logSourceWhitelist.Keys)}");
    var path = pathFn();
    if (string.IsNullOrWhiteSpace(path)) return Results.BadRequest($"Path not configured for source: {source}");
    var count = n ?? 100;
    if (count < 1 || count > 2000) return Results.BadRequest("n must be 1..2000");
    if (path is null || !File.Exists(path)) return Results.NotFound($"Log file not found: {path ?? "(unresolved)"}");
    var lines = ReadLinesShared(path).TakeLast(count).ToArray();
    return Results.Json(new { source, path, lineCount = lines.Length, lines });
});

app.MapGet("/logs/serilog", (int? tail, string? contains) =>
{
    if (IsUnset(serilogPath)) return Results.Problem("SerilogPath not configured", statusCode: 500);
    var file = ResolveLogFile(serilogPath);
    if (file is null) return Results.Problem($"Serilog file not found under: {serilogPath}", statusCode: 500);
    var n = tail ?? 100;
    if (n < 1 || n > 2000) return Results.BadRequest("tail must be 1..2000");
    var lines = ReadLinesShared(file);
    IEnumerable<string> result = lines.TakeLast(n);
    if (!string.IsNullOrWhiteSpace(contains)) result = result.Where(l => l.Contains(contains, StringComparison.OrdinalIgnoreCase));
    return Results.Json(result.ToArray());
});

app.MapGet("/shell/status", () =>
{
    lock (shellLock) {
        if (trackedShellProcess is null || trackedShellProcess.HasExited) return Results.Json(new { running = false, pid = (int?)null, healthy = false });
        var healthy = false;
        try { using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(3) }; var resp = http.GetAsync(shellHealthUrl).GetAwaiter().GetResult(); healthy = resp.IsSuccessStatusCode; } catch { }
        return Results.Json(new { running = true, pid = trackedShellProcess.Id, healthy });
    }
});

app.MapPost("/shell/start", async () =>
{
    lock (shellLock) { if (trackedShellProcess is not null && !trackedShellProcess.HasExited) return Results.Conflict(new { error = "Shell already running (tracked)", pid = trackedShellProcess.Id }); }
    try { using var probe = new HttpClient { Timeout = TimeSpan.FromSeconds(2) }; var probeResp = await probe.GetAsync(shellHealthUrl);
        if (probeResp.IsSuccessStatusCode) return Results.Json(new { running = true, tracked = false, healthy = true, note = "Shell already up (untracked)" });
    } catch { }
    AuditLog("SHELL_START", $"exe={shellExe}|args={string.Join(" ", shellArgs)}|cwd={shellWorkingDir}");
    var psi = new ProcessStartInfo { FileName = shellExe, WorkingDirectory = shellWorkingDir, UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true };
    foreach (var arg in shellArgs) psi.ArgumentList.Add(arg);
    StreamWriter logFile; Process proc;
    try { logFile = new StreamWriter(new FileStream(shellLogPath, FileMode.Append, FileAccess.Write, FileShare.ReadWrite)) { AutoFlush = true }; proc = Process.Start(psi)!; }
    catch (Exception ex) { return Results.Problem($"Failed to start shell: {ex.Message}", statusCode: 500); }
    proc.OutputDataReceived += (_, e) => { if (e.Data != null) lock (logFile) { logFile.WriteLine(e.Data); } };
    proc.ErrorDataReceived += (_, e) => { if (e.Data != null) lock (logFile) { logFile.WriteLine($"[ERR] {e.Data}"); } };
    proc.BeginOutputReadLine(); proc.BeginErrorReadLine();
    lock (shellLock) { trackedShellProcess = proc; }
    var healthy = false; using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
    for (int i = 0; i < 12; i++) { await Task.Delay(5000); try { var resp = await http.GetAsync(shellHealthUrl); if (resp.IsSuccessStatusCode) { healthy = true; break; } } catch { } }
    AuditLog("SHELL_STARTED", $"pid={proc.Id}|healthy={healthy}");
    return Results.Json(new { running = true, tracked = true, pid = proc.Id, healthy });
});

app.MapPost("/shell/stop", () =>
{
    lock (shellLock) {
        if (trackedShellProcess is null || trackedShellProcess.HasExited) return Results.Json(new { stopped = false, reason = "No tracked shell process running" });
        var pid = trackedShellProcess.Id; AuditLog("SHELL_STOP", $"pid={pid}");
        try { trackedShellProcess.Kill(entireProcessTree: true); trackedShellProcess.WaitForExit(10000); }
        catch (Exception ex) { return Results.Problem($"Failed to stop shell: {ex.Message}"); }
        trackedShellProcess = null; AuditLog("SHELL_STOPPED", $"pid={pid}");
        return Results.Json(new { stopped = true, pid });
    }
});

app.MapPost("/shell/restart", async () =>
{
    lock (shellLock) {
        if (trackedShellProcess is not null && !trackedShellProcess.HasExited) {
            var pid = trackedShellProcess.Id; AuditLog("SHELL_RESTART_STOP", $"pid={pid}");
            try { trackedShellProcess.Kill(entireProcessTree: true); trackedShellProcess.WaitForExit(10000); } catch { }
            trackedShellProcess = null;
        }
    }
    AuditLog("SHELL_RESTART_START", $"exe={shellExe}");
    var psi = new ProcessStartInfo { FileName = shellExe, WorkingDirectory = shellWorkingDir, UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true };
    foreach (var arg in shellArgs) psi.ArgumentList.Add(arg);
    StreamWriter logFile; Process proc;
    try { logFile = new StreamWriter(new FileStream(shellLogPath, FileMode.Append, FileAccess.Write, FileShare.ReadWrite)) { AutoFlush = true }; proc = Process.Start(psi)!; }
    catch (Exception ex) { return Results.Problem($"Failed to start shell: {ex.Message}", statusCode: 500); }
    proc.OutputDataReceived += (_, e) => { if (e.Data != null) lock (logFile) { logFile.WriteLine(e.Data); } };
    proc.ErrorDataReceived += (_, e) => { if (e.Data != null) lock (logFile) { logFile.WriteLine($"[ERR] {e.Data}"); } };
    proc.BeginOutputReadLine(); proc.BeginErrorReadLine();
    lock (shellLock) { trackedShellProcess = proc; }
    var healthy = false; using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
    for (int i = 0; i < 12; i++) { await Task.Delay(5000); try { var resp = await http.GetAsync(shellHealthUrl); if (resp.IsSuccessStatusCode) { healthy = true; break; } } catch { } }
    AuditLog("SHELL_RESTARTED", $"pid={proc.Id}|healthy={healthy}");
    return Results.Json(new { running = true, pid = proc.Id, healthy });
});

app.MapPost("/ops/build", async () =>
{
    AuditLog("OPS_BUILD", "start");
    var psi = new ProcessStartInfo { FileName = "dotnet", WorkingDirectory = shellWorkingDir, UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true };
    psi.ArgumentList.Add("build"); psi.ArgumentList.Add("CcDashboard.sln");
    var output = new List<string>(); using var proc = Process.Start(psi)!;
    proc.OutputDataReceived += (_, e) => { if (e.Data != null) output.Add(e.Data); };
    proc.ErrorDataReceived += (_, e) => { if (e.Data != null) output.Add($"[ERR] {e.Data}"); };
    proc.BeginOutputReadLine(); proc.BeginErrorReadLine();
    var completed = await Task.Run(() => proc.WaitForExit(300000));
    if (!completed) { proc.Kill(entireProcessTree: true); AuditLog("OPS_BUILD", "timeout"); return Results.Json(new { success = false, exitCode = -1, reason = "timeout", tail = output.TakeLast(50).ToArray() }); }
    AuditLog("OPS_BUILD", $"exitCode={proc.ExitCode}");
    return Results.Json(new { success = proc.ExitCode == 0, exitCode = proc.ExitCode, tail = output.TakeLast(50).ToArray() });
});

app.MapPost("/ops/test", async (string? suite) =>
{
    if (string.IsNullOrWhiteSpace(suite)) return Results.BadRequest("suite is required");
    if (!testSuiteWhitelist.TryGetValue(suite, out var project)) return Results.NotFound($"Unknown suite: {suite}. Allowed: {string.Join(", ", testSuiteWhitelist.Keys)}");
    AuditLog("OPS_TEST", $"suite={suite}|project={project}");
    var psi = new ProcessStartInfo { FileName = "dotnet", WorkingDirectory = shellWorkingDir, UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true };
    psi.ArgumentList.Add("test"); psi.ArgumentList.Add(project);
    var output = new List<string>(); using var proc = Process.Start(psi)!;
    proc.OutputDataReceived += (_, e) => { if (e.Data != null) output.Add(e.Data); };
    proc.ErrorDataReceived += (_, e) => { if (e.Data != null) output.Add($"[ERR] {e.Data}"); };
    proc.BeginOutputReadLine(); proc.BeginErrorReadLine();
    var completed = await Task.Run(() => proc.WaitForExit(600000));
    if (!completed) { proc.Kill(entireProcessTree: true); AuditLog("OPS_TEST", $"suite={suite}|timeout"); return Results.Json(new { success = false, exitCode = -1, reason = "timeout", tail = output.TakeLast(100).ToArray() }); }
    AuditLog("OPS_TEST", $"suite={suite}|exitCode={proc.ExitCode}");
    return Results.Json(new { success = proc.ExitCode == 0, exitCode = proc.ExitCode, tail = output.TakeLast(100).ToArray() });
});

app.MapGet("/ops/health", async () =>
{
    using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
    var liveness = new { up = false, latencyMs = 0L }; var readiness = new { up = false, latencyMs = 0L };
    try { var sw = Stopwatch.StartNew(); var resp = await http.GetAsync(shellHealthUrl); sw.Stop(); liveness = new { up = resp.IsSuccessStatusCode, latencyMs = sw.ElapsedMilliseconds }; } catch { }
    try { var readyUrl = shellHealthUrl.Replace("/health", "/health/ready"); var sw = Stopwatch.StartNew(); var resp = await http.GetAsync(readyUrl); sw.Stop(); readiness = new { up = resp.IsSuccessStatusCode, latencyMs = sw.ElapsedMilliseconds }; } catch { }
    return Results.Json(new { liveness, readiness });
});

static string GenerateUiHtml(string token) => $@"<!DOCTYPE html>
<html lang=""en"">
<head>
<meta charset=""UTF-8""><meta name=""viewport"" content=""width=device-width,initial-scale=1"">
<title>Soma Panel</title>
<style>
*{{box-sizing:border-box}}body{{font-family:system-ui,-apple-system,sans-serif;margin:0;padding:20px;background:#1a1a2e;color:#eee}}
h1{{margin:0 0 20px;font-size:1.5rem;color:#00d9ff}}
.header{{display:flex;gap:20px;align-items:center;margin-bottom:20px}}
.status{{padding:4px 12px;border-radius:4px;font-size:0.85rem}}
.status.ok{{background:#0a3d0a;color:#4caf50}}.status.err{{background:#3d0a0a;color:#ff5252}}
.filters{{display:flex;gap:12px;margin-bottom:16px;align-items:center}}
.filters input[type=text]{{padding:6px 12px;border:1px solid #333;background:#252540;color:#eee;border-radius:4px;width:250px}}
.filters label{{font-size:0.9rem;cursor:pointer}}
table{{width:100%;border-collapse:collapse;margin-bottom:20px}}
th,td{{padding:10px 12px;text-align:left;border-bottom:1px solid #333}}
th{{background:#252540;font-weight:500;color:#888}}
tr:hover{{background:#252540}}
.badge{{display:inline-block;padding:2px 8px;border-radius:10px;font-size:0.8rem}}
.badge.none{{background:#444;color:#888}}.badge.running{{background:#ff9800;color:#000}}
.badge.ok{{background:#4caf50;color:#000}}.badge.fail{{background:#f44336;color:#fff}}
.badge.interrupted{{background:#9e9e9e;color:#000}}
button{{padding:6px 14px;border:none;border-radius:4px;cursor:pointer;font-size:0.85rem}}
.btn-run{{background:#00d9ff;color:#000}}.btn-run:hover{{background:#00b8d4}}
.btn-log{{background:#444;color:#eee}}.btn-log:hover{{background:#555}}
.btn-mark{{background:#2e7d32;color:#fff;padding:4px 8px;font-size:0.75rem}}.btn-mark:hover{{background:#388e3c}}
.btn-markall{{background:#1b5e20;color:#fff}}.btn-markall:hover{{background:#2e7d32}}
.console{{background:#0d0d1a;border:1px solid #333;border-radius:6px;padding:12px;margin-top:20px;min-height:300px;max-height:500px;overflow:auto;font-family:monospace;font-size:0.85rem;white-space:pre-wrap}}
.console-header{{display:flex;justify-content:space-between;align-items:center;margin-bottom:8px}}
.console-header h3{{margin:0;font-size:1rem;color:#888}}
.btn-copy{{background:#333;color:#eee;padding:4px 10px}}.btn-copy:hover{{background:#444}}
#logContent{{color:#0f0}}
.mtime{{color:#666;font-size:0.8rem}}
</style>
</head>
<body>
<div class=""header"">
<h1>Soma CC Panel</h1>
<span id=""somaStatus"" class=""status"">...</span>
<span id=""shellStatus"" class=""status"">...</span>
<button class=""btn-markall"" onclick=""markAllDone()"">Mark All Done</button>
</div>
<div class=""filters"">
<input type=""text"" id=""searchInput"" placeholder=""Search prompts..."">
<label><input type=""checkbox"" id=""hideOk"" checked> Hide successful</label>
</div>
<table>
<thead><tr><th>Prompt</th><th>Modified</th><th>Status</th><th>Actions</th></tr></thead>
<tbody id=""promptList""></tbody>
</table>
<div class=""console"">
<div class=""console-header""><h3 id=""consoleTitle"">Console</h3><button class=""btn-copy"" onclick=""copyLog()"">Copy</button></div>
<div id=""logContent"">Ready.</div>
</div>
<script>
const TOKEN='{token}';
const headers={{'Authorization':'Bearer '+TOKEN,'Content-Type':'application/json'}};
let prompts=[],currentRunId=null,pollInterval=null;

async function loadStatus(){{
try{{const r=await fetch('/health');const d=await r.json();document.getElementById('somaStatus').className='status ok';document.getElementById('somaStatus').textContent='Soma v'+d.version;}}catch{{document.getElementById('somaStatus').className='status err';document.getElementById('somaStatus').textContent='Soma offline';}}
try{{const r=await fetch('/shell/status',{{headers}});const d=await r.json();const el=document.getElementById('shellStatus');if(d.running&&d.healthy){{el.className='status ok';el.textContent='Shell healthy';}}else if(d.running){{el.className='status err';el.textContent='Shell unhealthy';}}else{{el.className='status err';el.textContent='Shell stopped';}}}}catch{{document.getElementById('shellStatus').className='status err';document.getElementById('shellStatus').textContent='Shell ?';}}
}}

async function loadPrompts(){{
try{{const r=await fetch('/cc/prompts',{{headers}});prompts=await r.json();renderPrompts();}}catch(e){{console.error(e);}}
}}

function renderPrompts(){{
const search=document.getElementById('searchInput').value.toLowerCase();
const hideOk=document.getElementById('hideOk').checked;
const filtered=prompts.filter(p=>{{
if(search&&!p.file.toLowerCase().includes(search))return false;
if(hideOk&&p.lastStatus==='ok')return false;
return true;
}});
const tbody=document.getElementById('promptList');
tbody.innerHTML=filtered.map(p=>{{
const badge=p.lastStatus?`<span class=""badge ${{p.lastStatus}}"">${{p.lastStatus==='ok'?'✅':p.lastStatus==='fail'?'❌':p.lastStatus==='running'?'🟡':'⚪'}} ${{p.lastStatus}}</span>`:'<span class=""badge none"">⚪ not run</span>';
const lastRun=p.lastRunAt?new Date(p.lastRunAt).toLocaleString():'';
const logBtn=p.lastRunId?`<button class=""btn-log"" onclick=""viewLog('${{p.lastRunId}}')"">log</button>`:'';
return `<tr>
<td>${{p.file}}</td>
<td class=""mtime"">${{new Date(p.mtime).toLocaleString()}}</td>
<td>${{badge}} <span class=""mtime"">${{lastRun}}</span></td>
<td><button class=""btn-run"" onclick=""runPrompt('${{p.file}}')"">▶ Run</button> <button class=""btn-mark"" onclick=""markDone('${{p.file}}')"" title=""Mark done"">✓</button> ${{logBtn}}</td>
</tr>`;
}}).join('');
}}

async function runPrompt(file){{
if(!confirm('Run '+file+'?'))return;
try{{
const r=await fetch('/cc/run',{{method:'POST',headers,body:JSON.stringify({{promptFile:file}})}});
const d=await r.json();
if(d.runId){{currentRunId=d.runId;document.getElementById('consoleTitle').textContent='Running: '+file;document.getElementById('logContent').textContent='Started...\\n';startPolling();}}
else{{alert('Error: '+JSON.stringify(d));}}
}}catch(e){{alert('Error: '+e);}}
}}

function startPolling(){{
if(pollInterval)clearInterval(pollInterval);
pollInterval=setInterval(async()=>{{
try{{
const r=await fetch('/cc/runs/'+currentRunId,{{headers}});
const run=await r.json();
const lr=await fetch('/cc/runs/'+currentRunId+'/log',{{headers}});
const log=await lr.text();
document.getElementById('logContent').textContent=log;
document.getElementById('logContent').scrollTop=document.getElementById('logContent').scrollHeight;
if(run.status!=='running'){{
clearInterval(pollInterval);pollInterval=null;
document.getElementById('consoleTitle').textContent=(run.status==='ok'?'✅':'❌')+' '+run.promptFile;
loadPrompts();
}}
}}catch(e){{console.error(e);}}
}},2000);
}}

async function viewLog(runId){{
try{{
const r=await fetch('/cc/runs/'+runId,{{headers}});
const run=await r.json();
const lr=await fetch('/cc/runs/'+runId+'/log',{{headers}});
const log=await lr.text();
document.getElementById('consoleTitle').textContent=(run.status==='ok'?'✅':run.status==='fail'?'❌':'⚪')+' '+run.promptFile;
document.getElementById('logContent').textContent=log;
}}catch(e){{alert('Error: '+e);}}
}}

function copyLog(){{
const text=document.getElementById('logContent').textContent;
navigator.clipboard.writeText(text).then(()=>alert('Copied!')).catch(e=>alert('Copy failed: '+e));
}}

async function markDone(file){{
if(!confirm('Mark '+file+' as done (without running)?'))return;
try{{
const r=await fetch('/cc/mark-done',{{method:'POST',headers,body:JSON.stringify({{promptFile:file}})}});
const d=await r.json();
if(d.status==='ok'){{loadPrompts();}}else{{alert('Error: '+JSON.stringify(d));}}
}}catch(e){{alert('Error: '+e);}}
}}

async function markAllDone(){{
if(!confirm('Mark ALL unrun prompts as done?'))return;
try{{
const r=await fetch('/cc/mark-all-done',{{method:'POST',headers,body:JSON.stringify({{onlyUnrun:true}})}});
const d=await r.json();
alert('Marked: '+d.marked+', Skipped (already ok): '+d.skipped);
loadPrompts();
}}catch(e){{alert('Error: '+e);}}
}}

document.getElementById('searchInput').addEventListener('input',renderPrompts);
document.getElementById('hideOk').addEventListener('change',renderPrompts);

loadStatus();loadPrompts();setInterval(loadStatus,30000);
</script>
</body>
</html>";

app.Run();

class CcRunEntry
{
    public string RunId { get; set; } = "";
    public string PromptFile { get; set; } = "";
    public DateTime StartedAt { get; set; }
    public DateTime? FinishedAt { get; set; }
    public string Status { get; set; } = "running";
    public int? ExitCode { get; set; }
}
