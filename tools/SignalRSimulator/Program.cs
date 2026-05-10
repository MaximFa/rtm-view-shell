using SignalRSimulator.Hubs;

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

var app = builder.Build();

app.UseCors();

app.MapGet("/", () => "SignalR Simulator is running.\n\nAvailable hubs:\n- /hubs/agent-grid?gridId={guid}");

// Widget Hubs
app.MapHub<AgentGridHub>("/hubs/agent-grid");

app.Run();
