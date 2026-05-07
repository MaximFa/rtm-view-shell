using CcDashboard.Application.Interfaces;
using CcDashboard.Application.Security;
using CcDashboard.Application.Services;
using FluentValidation;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace CcDashboard.Application;

public static class ApplicationServiceExtensions
{
    public static IServiceCollection AddApplication(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.Configure<JwtSettings>(configuration.GetSection("Jwt"));

        services.AddScoped<IUserService, UserService>();
        services.AddScoped<IPermissionService, PermissionService>();
        services.AddScoped<IScreenService, ScreenService>();
        services.AddSingleton<IWidgetCatalogService, WidgetCatalogService>();

        services.AddScoped<IJwtTokenService, JwtTokenService>();
        services.AddScoped<ITwoFactorService, TwoFactorService>();
        services.AddScoped<ISsoService, SsoService>();

        services.AddValidatorsFromAssembly(typeof(ApplicationServiceExtensions).Assembly);

        return services;
    }
}
