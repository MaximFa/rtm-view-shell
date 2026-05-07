using CcDashboard.Api.Middleware;
using CcDashboard.Application.Extensions;
using CcDashboard.Infrastructure.Extensions;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using Serilog;
using Serilog.Events;
using System.Text;

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

    services.AddInfrastructure(config);
    services.AddApplication();

    var jwtSection = config.GetSection("Jwt");
    var secret = jwtSection["SecretKey"] ?? throw new InvalidOperationException("Jwt:SecretKey not configured");
    var issuer = jwtSection["Issuer"] ?? "CcDashboard";
    var audience = jwtSection["Audience"] ?? "CcDashboard";

    services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
        .AddJwtBearer(opts =>
        {
            opts.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidateAudience = true,
                ValidateLifetime = true,
                ValidateIssuerSigningKey = true,
                ValidIssuer = issuer,
                ValidAudience = audience,
                IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret)),
                ClockSkew = TimeSpan.Zero
            };
        });

    services.AddAuthorization();

    services.AddEndpointsApiExplorer();
    services.AddSwaggerGen(opts =>
    {
        opts.SwaggerDoc("v1", new OpenApiInfo
        {
            Title = "RTM View Shell API",
            Version = "v1",
            Description = "REST API for RTM View Shell — auth, dashboards, permissions"
        });

        opts.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
        {
            Type = SecuritySchemeType.Http,
            Scheme = "bearer",
            BearerFormat = "JWT",
            Description = "Enter the JWT access token obtained from /api/auth/login"
        });

        opts.AddSecurityRequirement(new OpenApiSecurityRequirement
        {
            {
                new OpenApiSecurityScheme
                {
                    Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" }
                },
                Array.Empty<string>()
            }
        });
    });

    services.AddHealthChecks()
        .AddNpgSql(config.GetConnectionString("Default")!)
        .AddRedis(config.GetConnectionString("Redis") ?? "localhost:6379");

    var app = builder.Build();

    app.UseSerilogRequestLogging();

    if (app.Environment.IsDevelopment())
    {
        app.UseSwagger();
        app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "RTM View Shell API v1"));
    }
    else
    {
        app.UseHttpsRedirection();
    }

    app.UseAuthentication();
    app.UseMiddleware<JtiRevocationMiddleware>();
    app.UseAuthorization();

    app.MapHealthChecks("/health");

    app.Run();
}
catch (Exception ex) when (ex is not HostAbortedException)
{
    Log.Fatal(ex, "API terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}
