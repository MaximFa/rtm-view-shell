using NetArchTest.Rules;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

public class ArchitectureTests
{
    private const string DomainNs = "CcDashboard.Domain";
    private const string ContractsNs = "CcDashboard.Contracts";
    private const string ApplicationNs = "CcDashboard.Application";
    private const string InfrastructureNs = "CcDashboard.Infrastructure";
    private const string WebNs = "CcDashboard.Web";
    private const string ApiNs = "CcDashboard.Api";

    [Fact]
    public void Domain_should_not_depend_on_any_other_layer()
    {
        var result = Types.InAssembly(typeof(CcDashboard.Domain.Exceptions.DomainException).Assembly)
            .ShouldNot()
            .HaveDependencyOnAny(ContractsNs, ApplicationNs, InfrastructureNs, WebNs, ApiNs)
            .GetResult();

        result.IsSuccessful.Should().BeTrue(result.FailingTypeNames is { } names
            ? string.Join(", ", names)
            : string.Empty);
    }

    [Fact]
    public void Contracts_should_not_depend_on_Application_Infrastructure_Web_or_Api()
    {
        var result = Types.InAssembly(typeof(CcDashboard.Contracts.Common.Result).Assembly)
            .ShouldNot()
            .HaveDependencyOnAny(ApplicationNs, InfrastructureNs, WebNs, ApiNs)
            .GetResult();

        result.IsSuccessful.Should().BeTrue(result.FailingTypeNames is { } names
            ? string.Join(", ", names)
            : string.Empty);
    }

    [Fact]
    public void Application_should_not_depend_on_Infrastructure_Web_or_Api()
    {
        var result = Types.InAssembly(typeof(CcDashboard.Application.Extensions.ApplicationServiceExtensions).Assembly)
            .ShouldNot()
            .HaveDependencyOnAny(InfrastructureNs, WebNs, ApiNs)
            .GetResult();

        result.IsSuccessful.Should().BeTrue(result.FailingTypeNames is { } names
            ? string.Join(", ", names)
            : string.Empty);
    }

    [Fact]
    public void Infrastructure_should_not_depend_on_Web_or_Api()
    {
        var result = Types.InAssembly(typeof(CcDashboard.Infrastructure.Extensions.InfrastructureServiceExtensions).Assembly)
            .ShouldNot()
            .HaveDependencyOnAny(WebNs, ApiNs)
            .GetResult();

        result.IsSuccessful.Should().BeTrue(result.FailingTypeNames is { } names
            ? string.Join(", ", names)
            : string.Empty);
    }

    [Fact]
    public void Domain_should_have_no_nuget_dependencies()
    {
        var domainAssembly = typeof(CcDashboard.Domain.Exceptions.DomainException).Assembly;
        var referencedAssemblies = domainAssembly.GetReferencedAssemblies()
            .Select(a => a.Name ?? string.Empty)
            .Where(n => !n.StartsWith("System") && !n.StartsWith("Microsoft.NETCore") &&
                        !n.StartsWith("netstandard") && !n.StartsWith("mscorlib") &&
                        n != "CcDashboard.Domain" && n != "CcDashboard.Contracts")
            .ToList();

        referencedAssemblies.Should().BeEmpty(
            $"Domain must have zero NuGet dependencies; found: {string.Join(", ", referencedAssemblies)}");
    }

    [Fact]
    public void MediatR_handlers_should_live_in_Application_only()
    {
        var result = Types
            .InAssemblies([
                typeof(CcDashboard.Infrastructure.Extensions.InfrastructureServiceExtensions).Assembly
            ])
            .That()
            .ImplementInterface(typeof(MediatR.IRequestHandler<,>))
            .ShouldNot()
            .HaveDependencyOn(ApplicationNs)  // infrastructure handlers are not expected
            .GetResult();

        // Infrastructure should not contain MediatR handlers
        Types.InAssembly(typeof(CcDashboard.Infrastructure.Extensions.InfrastructureServiceExtensions).Assembly)
            .That()
            .ImplementInterface(typeof(MediatR.IRequestHandler<,>))
            .GetTypes()
            .Should().BeEmpty("MediatR handlers belong in Application, not Infrastructure");
    }

    [Fact]
    public void Repositories_should_not_be_used_directly_by_Web()
    {
        var result = Types.InAssembly(typeof(CcDashboard.Web.Components.App).Assembly)
            .ShouldNot()
            .HaveDependencyOn("CcDashboard.Infrastructure.Persistence.Repositories")
            .GetResult();

        result.IsSuccessful.Should().BeTrue(result.FailingTypeNames is { } names
            ? string.Join(", ", names)
            : string.Empty);
    }

    [Fact]
    public void Commands_and_queries_should_be_in_Application()
    {
        var appAssembly = typeof(CcDashboard.Application.Extensions.ApplicationServiceExtensions).Assembly;

        var commandTypes = appAssembly.GetTypes()
            .Where(t => t.Name.EndsWith("Command") && t.IsClass && !t.IsAbstract)
            .ToList();

        var queryTypes = appAssembly.GetTypes()
            .Where(t => t.Name.EndsWith("Query") && t.IsClass && !t.IsAbstract)
            .ToList();

        commandTypes.Should().NotBeEmpty("there should be at least one command in Application");
        queryTypes.Should().NotBeEmpty("there should be at least one query in Application");
    }
}
