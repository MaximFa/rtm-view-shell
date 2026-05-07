using CcDashboard.Application.Extensions;
using Microsoft.AspNetCore.RateLimiting;
using CcDashboard.Infrastructure.Extensions;
using CcDashboard.Web.Components;
using CcDashboard.Web.Middleware;
using CcDashboard.Web.Services;
using Microsoft.AspNetCore.Authentication.Cookies;
using Serilog;
using Serilog.Events;

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .MinimumLevel.Override("Microsoft", LogEventLevel.Warning)
    .WriteTo.Console()
    .CreateBootstrapLogger();

try
{
    var builder = WebApplication.CreateBuilder(args);

    builder.Host.UseSerilog((ctx, cfg) =>
        cfg.ReadFrom.Configuration(ctx.Configuration).Enrich.FromLogContext());

    var services = builder.Services;
    var config = builder.Configuration;
    var isDev = builder.Environment.IsDevelopment();

    services.AddInfrastructure(config);
    services.AddApplication();

    services.AddRazorComponents()
        .AddInteractiveServerComponents();

    services.AddCascadingAuthenticationState();

    services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
        .AddCookie(opts =>
        {
            opts.LoginPath = "/login";
            opts.LogoutPath = "/logout";
            opts.AccessDeniedPath = "/access-denied";
            opts.Cookie.Name = isDev ? "cc_auth" : "__Host-cc_auth";
            opts.Cookie.HttpOnly = true;
            opts.Cookie.SameSite = isDev ? SameSiteMode.Lax : SameSiteMode.Strict;
            opts.Cookie.SecurePolicy = isDev ? CookieSecurePolicy.SameAsRequest : CookieSecurePolicy.Always;
            opts.SlidingExpiration = true;
            opts.ExpireTimeSpan = TimeSpan.FromMinutes(30);
        });

    services.AddAuthorization();
    services.AddHttpContextAccessor();
    services.AddLocalization();

    services.AddRateLimiter(opts =>
    {
        opts.AddFixedWindowLimiter("login", o =>
        {
            o.PermitLimit = 10;
            o.Window = TimeSpan.FromMinutes(1);
        });
    });

    services.AddHealthChecks()
        .AddNpgSql(config.GetConnectionString("Default")!)
        .AddRedis(config.GetConnectionString("Redis") ?? "localhost:6379");

    services.AddScoped<CurrentUserAccessor>();

    var app = builder.Build();

    if (!isDev) app.UseHttpsRedirection();

    app.UseStaticFiles();
    app.UseRouting();
    app.UseRateLimiter();
    app.UseAuthentication();
    app.UseAuthorization();
    app.UseAntiforgery();
    app.UseMiddleware<SecurityHeadersMiddleware>();
    app.UseMiddleware<TenantResolutionMiddleware>();

    app.MapHealthChecks("/health");
    app.MapHealthChecks("/health/ready");

    app.MapRazorComponents<App>()
        .AddInteractiveServerRenderMode();

    app.Run();
}
catch (Exception ex) when (ex is not HostAbortedException)
{
    Log.Fatal(ex, "Application terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}
