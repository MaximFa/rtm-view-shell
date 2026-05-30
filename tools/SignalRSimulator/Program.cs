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

// CORS origins loaded from appsettings — CcDashboard.Web URL must be listed
var corsOrigins = builder.Configuration.GetSection("CorsOrigins").Get<string[]>()
    ?? new[] { "http://localhost:5000" };

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins(corsOrigins)
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

app.MapGet("/", () => "RTM SignalR Simulator is running.\n\nHub: /signalr\nClient calls init(gridId) after connecting:\n- Queue/DataSlot: init(\"42\") - numeric gridId\n- Agent: init(\"u5\") - u + UnionId\n\nMetrics are loaded from database.");

// RTM protocol hub (single endpoint like real RTM server)
app.MapHub<RtmSimulatorHub>("/signalr");

app.Run();
