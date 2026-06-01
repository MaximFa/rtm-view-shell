using SignalRSimulator.Generators;
using SignalRSimulator.Hubs;
using SignalRSimulator.Services;

var builder = WebApplication.CreateBuilder(args);
builder.Host.UseWindowsService(); // enables running as Windows Service

builder.Services.AddSignalR()
    .AddNewtonsoftJsonProtocol(options =>
    {
        options.PayloadSerializerSettings.ContractResolver =
            new Newtonsoft.Json.Serialization.DefaultContractResolver();
    });

builder.Services.AddLogging(logging =>
{
    logging.AddConsole();
    logging.SetMinimumLevel(LogLevel.Information);
});

// Register database service and generators
builder.Services.AddSingleton<IDbMetricService, DbMetricService>();
builder.Services.AddSingleton<AgentDataGenerator>();
builder.Services.AddSingleton<QueueDataGenerator>();

var app = builder.Build();

// Verify database connection on startup
var metricService = app.Services.GetRequiredService<IDbMetricService>();
try
{
    var metrics = await metricService.GetAllMetricsAsync();
    app.Logger.LogInformation("Connected to database. Found {Count} metrics", metrics.Count);

    var agentMetrics = await metricService.GetAgentMetricsAsync();
    var queueMetrics = await metricService.GetQueueMetricsAsync();
    app.Logger.LogInformation("Agent metrics: {AgentCount}, Queue metrics: {QueueCount}",
        agentMetrics.Count, queueMetrics.Count);
}
catch (Exception ex)
{
    app.Logger.LogError(ex, "Failed to connect to database. Check connection string in appsettings.json");
}


app.MapGet("/", () => "RTM SignalR Simulator is running.\n\nHub: /signalr\nClient calls init(gridId) after connecting:\n- Queue/DataSlot: init(\"42\") - numeric gridId\n- Agent: init(\"u5\") - u + UnionId\n\nMetrics are loaded from database.");

// Matches real RTM Server endpoint — called by RtmConfigurationApiHook after config changes.
// Invalidates the metric cache so the next push includes newly configured MetricIds.
app.MapGet("/LoadData", (IDbMetricService db, ILogger<Program> logger) =>
{
    db.InvalidateCaches();
    logger.LogInformation("[Simulator] /LoadData called — metric cache cleared");
    return Results.Ok("LoadData OK");
});

// RTM protocol hub (single endpoint like real RTM server)
app.MapHub<RtmSimulatorHub>("/signalr");

app.Run();
