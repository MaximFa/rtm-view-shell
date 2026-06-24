using Microsoft.AspNetCore.Server.Kestrel.Core;
using Microsoft.AspNetCore.Server.Kestrel.Https;
using RTMMaintenance.ReadPlane.Middleware;
using RTMMaintenance.ReadPlane.Models;
using RTMMaintenance.ReadPlane.Services;
using RTMMaintenance.ReadPlane.Jobs;
using RTMMaintenance.ReadPlane.Contracts;
using RTMMaintenance.ReadPlane.Validation;
using Serilog;
using System.Net;
using System.Security.Cryptography.X509Certificates;

namespace RTMMaintenance.ReadPlane;

public class Program
{
    public static void Main(string[] args)
    {
        Log.Logger = new LoggerConfiguration()
            .MinimumLevel.Information()
            .WriteTo.File(
                path: @"C:\RTMView-Ops\output\rtmmaintenance-read-.log",
                rollingInterval: RollingInterval.Day,
                retainedFileCountLimit: 30,
                outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception}")
            .WriteTo.EventLog(
                source: "RTMMaintenance.ReadPlane",
                logName: "Application",
                restrictedToMinimumLevel: Serilog.Events.LogEventLevel.Warning)
            .CreateLogger();

        try
        {
            Log.Information("Starting RTMMaintenance.ReadPlane service");

            // SF-MS-003: Verify signal-to-script mapping is complete at startup (fail fast)
            SignalScriptMap.VerifyCompleteness();
            Log.Information("SF-MS-003: Signal-script map verified ({Count} signals)", SignalScriptMap.MappedCount);

            var builder = WebApplication.CreateBuilder(args);

            builder.Host.UseSerilog();
            builder.Host.UseWindowsService(options =>
            {
                options.ServiceName = "RTMMaintenance.ReadPlane";
            });

            ConfigureKestrel(builder);
            ConfigureServices(builder.Services, builder.Configuration);

            var app = builder.Build();

            ConfigureMiddleware(app);
            ConfigureEndpoints(app);

            app.Run();
        }
        catch (Exception ex)
        {
            Log.Fatal(ex, "Service terminated unexpectedly");
        }
        finally
        {
            Log.CloseAndFlush();
        }
    }

    private static void ConfigureKestrel(WebApplicationBuilder builder)
    {
        var config = builder.Configuration;

        builder.WebHost.ConfigureKestrel((context, serverOptions) =>
        {
            var bindAddress = config.GetValue<string>("Kestrel:BindAddress") ?? "127.0.0.1";
            var port = config.GetValue<int>("Kestrel:Port", 5443);
            var certThumbprint = config.GetValue<string>("Kestrel:CertificateThumbprint");

            if (string.IsNullOrEmpty(certThumbprint))
            {
                throw new InvalidOperationException(
                    "Server certificate thumbprint not configured. Set Kestrel:CertificateThumbprint.");
            }

            serverOptions.Listen(IPAddress.Parse(bindAddress), port, listenOptions =>
            {
                var serverCert = LoadCertificate(certThumbprint);
                if (serverCert == null)
                {
                    throw new InvalidOperationException(
                        $"Server certificate with thumbprint {certThumbprint} not found in LocalMachine\\My store.");
                }

                listenOptions.UseHttps(httpsOptions =>
                {
                    httpsOptions.ServerCertificate = serverCert;
                    httpsOptions.ClientCertificateMode = ClientCertificateMode.RequireCertificate;
                    httpsOptions.ClientCertificateValidation = (cert, chain, errors) =>
                    {
                        return true;
                    };
                });

                listenOptions.Protocols = HttpProtocols.Http1AndHttp2;
            });
        });
    }

    private static X509Certificate2? LoadCertificate(string thumbprint)
    {
        using var store = new X509Store(StoreName.My, StoreLocation.LocalMachine);
        store.Open(OpenFlags.ReadOnly);

        var certs = store.Certificates.Find(
            X509FindType.FindByThumbprint,
            thumbprint.Replace(" ", "").ToUpperInvariant(),
            validOnly: false);

        return certs.Count > 0 ? certs[0] : null;
    }

    private static void ConfigureServices(IServiceCollection services, IConfiguration config)
    {
        services.AddControllers();

        services.Configure<SecurityOptions>(config.GetSection("Security"));
        services.Configure<JobOptions>(config.GetSection("Jobs"));

        services.AddSingleton<ISignalValidator, CollectIncidentValidator>();
        services.AddSingleton<ISecretScrubber, DefaultSecretScrubber>();
        services.AddSingleton<IAuditService, LocalAuditService>();
        services.AddSingleton<IJobManager, JobManager>();

        services.AddSingleton<IStatusReader, StatusReader>();
        services.AddSingleton<ISignalCollector, SignalCollector>();
    }

    private static void ConfigureMiddleware(WebApplication app)
    {
        app.UseMiddleware<IpAllowListMiddleware>();
        app.UseMiddleware<MtlsValidationMiddleware>();
        app.UseMiddleware<TokenValidationMiddleware>();
        app.UseMiddleware<AuditMiddleware>();

        app.UseRouting();
    }

    private static void ConfigureEndpoints(WebApplication app)
    {
        app.MapControllers();
    }
}
