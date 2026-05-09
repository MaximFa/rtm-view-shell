using CcDashboard.Application.Extensions;
using Microsoft.AspNetCore.Components.Server.Circuits;
using Microsoft.AspNetCore.RateLimiting;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Extensions;
using CcDashboard.Infrastructure.Seeding;
using CcDashboard.Web.Components;
using CcDashboard.Web.Middleware;
using CcDashboard.Web.Services;
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
    builder.Host.UseWindowsService(); // enables running as Windows Service in production

    builder.Host.UseSerilog((ctx, cfg) =>
        cfg.ReadFrom.Configuration(ctx.Configuration).Enrich.FromLogContext());

    var services = builder.Services;
    var config = builder.Configuration;
    var isDev = builder.Environment.IsDevelopment();

    services.AddInfrastructure(config);
    services.AddApplication();

    // [SCALE-01] SignalR Redis backplane — required for multi-instance deployments
    // In development use in-memory transport; Redis backplane is for production only.
    var redisConn = config.GetConnectionString("Redis") ?? "localhost:6379";
    var signalR = services.AddSignalR();
    if (!isDev)
        signalR.AddStackExchangeRedis(redisConn, opts =>
            opts.Configuration.ChannelPrefix = StackExchange.Redis.RedisChannel.Literal("CcDashboard"));

    services.AddRazorComponents()
        .AddInteractiveServerComponents();

    services.AddCascadingAuthenticationState();

    // [AUTH-WEB-01] Configure the Identity application cookie
    services.ConfigureApplicationCookie(opts =>
    {
        opts.LoginPath = "/login";
        opts.LogoutPath = "/logout";
        opts.AccessDeniedPath = "/access-denied";
        // __Host- prefix enforces Secure + Path=/ + no Domain [AUTH-WEB-01]
        // In dev without HTTPS, fall back to standard name (requires UseHttpsRedirection in dev for full security)
        opts.Cookie.Name = isDev ? "cc_auth_dev" : "__Host-cc_auth";
        opts.Cookie.HttpOnly = true;
        opts.Cookie.SameSite = isDev ? SameSiteMode.Lax : SameSiteMode.Strict;
        opts.Cookie.SecurePolicy = isDev ? CookieSecurePolicy.SameAsRequest : CookieSecurePolicy.Always;
        opts.SlidingExpiration = true;
        opts.ExpireTimeSpan = TimeSpan.FromMinutes(30);
    });

    // Production security checks [CODE-05]
    if (!isDev)
    {
        var jwtSecret = config["Jwt:SecretKey"];
        var jwtPrivateKey = config["Jwt:PrivateKeyPath"];

        // Ensure RS256 is configured for production
        if (string.IsNullOrEmpty(jwtPrivateKey))
        {
            if (!string.IsNullOrEmpty(jwtSecret) && !jwtSecret.Contains("dev", StringComparison.OrdinalIgnoreCase))
                Log.Warning("Production environment using HS256 JWT signing. Configure Jwt:PrivateKeyPath for RS256.");
        }

        // Ensure no dev secrets in production
        if (jwtSecret?.Contains("dev-only", StringComparison.OrdinalIgnoreCase) == true)
            throw new InvalidOperationException("Development JWT secret detected in production! Configure production secrets.");

        var seedPassword = config["Seed:SuperadminPassword"];
        if (seedPassword?.Contains("Admin@123456", StringComparison.OrdinalIgnoreCase) == true)
            throw new InvalidOperationException("Default seed password detected in production! Configure production secrets.");
    }

    services.AddAuthorization();
    services.AddHttpContextAccessor();

    // [I18N-01..03] Localization — add new language = new .resx file, no code change
    services.AddLocalization();
    services.Configure<RequestLocalizationOptions>(opts =>
    {
        var supported = new[] { "en-US", "ru-RU", "he-IL" };
        opts.SetDefaultCulture("en-US")
            .AddSupportedCultures(supported)
            .AddSupportedUICultures(supported);
        opts.ApplyCurrentCultureToResponseHeaders = true;
    });

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

    services.AddScoped<ICurrentUserAccessor, CurrentUserAccessor>();

    // Blazor circuit handler: resolves tenant context for SignalR circuits [ARCH-03]
    services.AddScoped<CircuitHandler, TenantCircuitHandler>();

    var app = builder.Build();

    // Run database seed on startup
    using (var scope = app.Services.CreateScope())
    {
        var initializer = scope.ServiceProvider.GetRequiredService<DatabaseInitializer>();
        await initializer.InitializeAsync();
    }

    if (!isDev) app.UseHttpsRedirection();

    app.UseRequestLocalization();
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
