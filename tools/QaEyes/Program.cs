using System.Text.Json;
using System.Text.RegularExpressions;
using Npgsql;

var builder = WebApplication.CreateBuilder(args);

var config = builder.Configuration.GetSection("QaEyes");
var port = int.Parse(config["Port"] ?? "5199");
var token = config["Token"] ?? throw new InvalidOperationException("QaEyes:Token not configured");
var connStr = config["ReadonlyConnectionString"] ?? throw new InvalidOperationException("QaEyes:ReadonlyConnectionString not configured");
var serilogPath = config["SerilogPath"];

builder.WebHost.ConfigureKestrel(opts =>
{
    opts.ListenLocalhost(port);
});

var app = builder.Build();

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

app.MapGet("/health", () => Results.Json(new { ok = true, version = "1.0.0" }));

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

app.MapGet("/logs/serilog", (int? tail, string? contains) =>
{
    if (string.IsNullOrWhiteSpace(serilogPath))
        return Results.BadRequest("SerilogPath not configured");
    
    var n = tail ?? 100;
    if (n < 1 || n > 2000)
        return Results.BadRequest("tail must be 1..2000");

    if (!File.Exists(serilogPath))
        return Results.NotFound($"Log file not found: {serilogPath}");

    var lines = File.ReadAllLines(serilogPath);
    IEnumerable<string> result = lines.TakeLast(n);
    
    if (!string.IsNullOrWhiteSpace(contains))
        result = result.Where(l => l.Contains(contains, StringComparison.OrdinalIgnoreCase));

    return Results.Json(result.ToArray());
});

app.Run();