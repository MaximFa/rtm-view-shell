using CcDashboard.Application.Extensions;
using CcDashboard.Application.Interfaces;
using CcDashboard.Web.Hubs;
using Microsoft.AspNetCore.Components.Server.Circuits;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Extensions;
using CcDashboard.Infrastructure.RtmRelay;
using CcDashboard.Infrastructure.Metrics;
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
        {
            opts.Configuration.ChannelPrefix = StackExchange.Redis.RedisChannel.Literal("CcDashboard");
            opts.Configuration.AbortOnConnectFail = false;
        });

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

    // [AUD-04] Configure ForwardedHeaders for correct client IP extraction behind reverse proxy
    services.Configure<ForwardedHeadersOptions>(opts =>
    {
        opts.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
        // In production, configure known proxy IPs in appsettings; clear defaults for testing
        opts.KnownNetworks.Clear();
        opts.KnownProxies.Clear();
    });

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

    // RTM Relay — Singleton, server-side SignalR client to RTM Service (CLAUDE.md §34)
    services.Configure<RtmRelayOptions>(builder.Configuration.GetSection(RtmRelayOptions.Section));
    services.AddSingleton<IRtmRelayService, RtmRelayService>();

    // Metrics hot-reload services (CLAUDE.md §34 / contract §6)
    services.Configure<MetricsApplyOptions>(builder.Configuration.GetSection(MetricsApplyOptions.Section));
    services.AddScoped<IMetricDeployLedgerReader, MetricDeployLedgerReader>();
    services.AddHttpClient<IMetricApplyClient, MetricApplyHttpClient>();

    var app = builder.Build();

    // migrate-only: apply EF migrations and EXIT — no seed, no hosted services, no web host.
    // Canonical fresh-install ordering (DEPLOY-14): `Web.exe migrate` runs BEFORE schema.sql, so backend tables don't exist yet.
    if (args.Any(a => string.Equals(a, "migrate", StringComparison.OrdinalIgnoreCase)))
    {
        using var migrateScope = app.Services.CreateScope();
        var migrator = migrateScope.ServiceProvider.GetRequiredService<IDatabaseInitializer>();
        await migrator.MigrateOnlyAsync();
        Log.Information("migrate-only complete — exiting (no seed, no hosted services, no web host).");
        return;
    }

    // Run database seed on startup (backend tables exist by now in the canonical flow)
    using (var scope = app.Services.CreateScope())
    {
        var initializer = scope.ServiceProvider.GetRequiredService<IDatabaseInitializer>();
        await initializer.InitializeAsync();
    }

    // [AUD-04] ForwardedHeaders must be early in pipeline to set correct RemoteIpAddress
    app.UseForwardedHeaders();

    if (!isDev) app.UseHttpsRedirection();

    app.UseRequestLocalization();
    app.UseStaticFiles();
    app.UseRouting();
    app.UseRateLimiter();
    app.UseMiddleware<LoginRateLimitMiddleware>();  // [BFP-02] Rate limit login attempts
    app.UseAuthentication();
    app.UseAuthorization();
    app.UseAntiforgery();
    app.UseMiddleware<SecurityHeadersMiddleware>();
    app.UseMiddleware<TenantResolutionMiddleware>();

    app.MapHealthChecks("/health");
    app.MapHealthChecks("/health/ready");

    app.MapHub<InfoSlotHub>("/hubs/info-slot");
    app.MapHub<RtmRelayHub>("/hubs/rtm-relay");

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

// Make Program accessible to WebApplicationFactory for integration testing.
// Required for top-level statements which generate an internal Program class by default.
// See: https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests
public partial class Program { }
