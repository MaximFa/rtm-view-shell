using SignalRSimulator.Generators;
using SignalRSimulator.Hubs;
using SignalRSimulator.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSignalR();
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins(
                "https://localhost:7196",
                "http://localhost:5196",
                "https://localhost:5239",
                "http://localhost:5238")
            .AllowAnyHeader()
            .AllowAnyMethod()
            .AllowCredentials();
    });
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

app.UseCors();

app.MapGet("/", () => "SignalR Simulator is running.\n\nAvailable hubs:\n- /hubs/agent-grid?gridId={int}\n- /hubs/queue-grid?gridId={int}\n\nMetrics are loaded from database (rtsgrid_metric table).");

// Widget Hubs
app.MapHub<AgentGridHub>("/hubs/agent-grid");
app.MapHub<QueueGridHub>("/hubs/queue-grid");

app.Run();
