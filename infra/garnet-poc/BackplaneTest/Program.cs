using Microsoft.AspNetCore.SignalR;
using StackExchange.Redis;

// Minimal SignalR app to prove Garnet pub/sub backplane FAN-OUT across two instances.
// Mirrors the real Shell's wiring (Program.cs:44-47): AddStackExchangeRedis + ChannelPrefix "CcDashboard".
// NOTE: unlike the Shell, the backplane is wired UNCONDITIONALLY here (no isDev guard) so env doesn't matter.

var builder = WebApplication.CreateBuilder(args);

var redisConn = Environment.GetEnvironmentVariable("REDIS_CONN") ?? "localhost:6379,password=TestPwd123";

builder.Services.AddSignalR().AddStackExchangeRedis(redisConn, o =>
{
    o.Configuration.ChannelPrefix = RedisChannel.Literal("CcDashboard");
    o.Configuration.AbortOnConnectFail = false;
});

var app = builder.Build();
app.UseDefaultFiles();
app.UseStaticFiles();
app.MapHub<TestHub>("/testhub");

// Any instance can trigger a fan-out to ALL connected clients (across instances, via the Redis/Garnet backplane).
app.MapGet("/broadcast", async (HttpContext ctx, IHubContext<TestHub> hub, string? msg) =>
{
    var from = ctx.Request.Host.Value;
    await hub.Clients.All.SendAsync("recv", $"[{DateTime.Now:HH:mm:ss}] broadcast BY instance {from}: {msg ?? "ping"}");
    return Results.Ok($"sent from {from}");
});

Console.WriteLine($"[BackplaneTest] Redis/Garnet = {redisConn}");
app.Run();

public class TestHub : Hub { }
