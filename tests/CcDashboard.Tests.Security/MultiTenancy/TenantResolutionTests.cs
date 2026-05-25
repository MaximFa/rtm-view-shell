using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Enums;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Web.Middleware;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using NSubstitute;

namespace CcDashboard.Tests.Security.MultiTenancy;

/// <summary>
/// Unit tests for TenantResolutionMiddleware (ARCH-03).
/// Tests subdomain → TenantId resolution logic without full WAF overhead.
/// </summary>
public class TenantResolutionTests
{
    private readonly ITenantContext _tenantContext;
    private readonly ITenantRepository _tenantRepo;
    private readonly IConfiguration _config;
    private readonly RequestDelegate _next;

    public TenantResolutionTests()
    {
        _tenantContext = Substitute.For<ITenantContext>();
        _tenantRepo = Substitute.For<ITenantRepository>();
        _config = Substitute.For<IConfiguration>();
        _next = Substitute.For<RequestDelegate>();
    }

    [Fact]
    [Trait("Req", "ARCH-03")]
    public async Task InvokeAsync_KnownActiveSlug_SetsTenantContext()
    {
        // Arrange
        var tenantId = Guid.NewGuid();
        var tenant = new Tenant { Id = tenantId, Slug = "acme", Status = TenantStatus.Active };
        _tenantRepo.GetBySlugAsync("acme").Returns(tenant);

        var httpContext = new DefaultHttpContext();
        httpContext.Request.Host = new HostString("acme.cc-dashboard.local");

        var middleware = new TenantResolutionMiddleware(_next, _config);

        // Act
        await middleware.InvokeAsync(httpContext, _tenantContext, _tenantRepo);

        // Assert
        _tenantContext.Received(1).Set(tenantId, "acme");
        await _next.Received(1).Invoke(httpContext);
    }

    [Fact]
    [Trait("Req", "ARCH-03")]
    public async Task InvokeAsync_UnknownSlug_DoesNotSetTenantContext()
    {
        // Arrange
        _tenantRepo.GetBySlugAsync("unknown").Returns((Tenant?)null);

        var httpContext = new DefaultHttpContext();
        httpContext.Request.Host = new HostString("unknown.cc-dashboard.local");

        var middleware = new TenantResolutionMiddleware(_next, _config);

        // Act
        await middleware.InvokeAsync(httpContext, _tenantContext, _tenantRepo);

        // Assert: Set not called, but next delegate still invoked
        _tenantContext.DidNotReceive().Set(Arg.Any<Guid>(), Arg.Any<string>());
        await _next.Received(1).Invoke(httpContext);
    }

    [Fact]
    [Trait("Req", "ARCH-03")]
    public async Task InvokeAsync_SuspendedTenant_DoesNotSetTenantContext()
    {
        // Arrange
        var tenant = new Tenant { Id = Guid.NewGuid(), Slug = "suspended", Status = TenantStatus.Suspended };
        _tenantRepo.GetBySlugAsync("suspended").Returns(tenant);

        var httpContext = new DefaultHttpContext();
        httpContext.Request.Host = new HostString("suspended.cc-dashboard.local");

        var middleware = new TenantResolutionMiddleware(_next, _config);

        // Act
        await middleware.InvokeAsync(httpContext, _tenantContext, _tenantRepo);

        // Assert: Suspended tenant should not be activated
        _tenantContext.DidNotReceive().Set(Arg.Any<Guid>(), Arg.Any<string>());
        await _next.Received(1).Invoke(httpContext);
    }

    [Fact]
    [Trait("Req", "ARCH-03")]
    public async Task InvokeAsync_DeletedTenant_TreatedAsUnknown()
    {
        // Arrange: ARCH-06 says Deleted tenant is invisible to auth
        var tenant = new Tenant { Id = Guid.NewGuid(), Slug = "deleted", Status = TenantStatus.Deleted };
        _tenantRepo.GetBySlugAsync("deleted").Returns(tenant);

        var httpContext = new DefaultHttpContext();
        httpContext.Request.Host = new HostString("deleted.cc-dashboard.local");

        var middleware = new TenantResolutionMiddleware(_next, _config);

        // Act
        await middleware.InvokeAsync(httpContext, _tenantContext, _tenantRepo);

        // Assert: Deleted tenant should not be activated
        _tenantContext.DidNotReceive().Set(Arg.Any<Guid>(), Arg.Any<string>());
        await _next.Received(1).Invoke(httpContext);
    }

    [Fact]
    [Trait("Req", "ARCH-03")]
    public async Task InvokeAsync_NoSubdomain_UsesDefaultTenantSlugFromConfig()
    {
        // Arrange
        var tenantId = Guid.NewGuid();
        var tenant = new Tenant { Id = tenantId, Slug = "default", Status = TenantStatus.Active };
        _config["DefaultTenantSlug"].Returns("default");
        _tenantRepo.GetBySlugAsync("default").Returns(tenant);

        var httpContext = new DefaultHttpContext();
        httpContext.Request.Host = new HostString("localhost"); // Single part = no subdomain

        var middleware = new TenantResolutionMiddleware(_next, _config);

        // Act
        await middleware.InvokeAsync(httpContext, _tenantContext, _tenantRepo);

        // Assert
        _tenantContext.Received(1).Set(tenantId, "default");
    }
}
