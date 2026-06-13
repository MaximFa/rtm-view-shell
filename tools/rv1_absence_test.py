#!/usr/bin/env python3
"""
RV-1: Rewrite orphaned RtsGridMetricCatalogueTests.cs as F-1 absence regression.
"""
import os

content = r'''using System.Reflection;
using FluentAssertions;

namespace CcDashboard.Tests.Security.Configuration;

/// <summary>
/// F-1 regression: metrics are vendor product-constants — the client has NO server-side
/// command/request to create/edit/delete/translate a metric. If any reappears, F-1 has
/// regressed (RCE surface via Roslyn-compiled MetricFunction/Parameter/Format).
/// </summary>
public class RtsGridMetricCatalogueTests
{
    /// <summary>
    /// Forbidden type names that must NOT exist in the Application assembly.
    /// These represent metric mutation commands removed by F-1 (b7b20e4).
    /// </summary>
    private static readonly HashSet<string> ForbiddenApplicationTypes = new(StringComparer.Ordinal)
    {
        "SaveRtsGridMetricCommand",
        "SaveRtsGridMetricCommandHandler",
        "DeleteRtsGridMetricCommand",
        "DeleteRtsGridMetricCommandHandler",
        "SaveMetricTranslationCommand",
        "SaveMetricTranslationCommandHandler",
        "DeleteMetricTranslationCommand",
        "DeleteMetricTranslationCommandHandler"
    };

    /// <summary>
    /// Forbidden type names that must NOT exist in the Contracts assembly.
    /// These represent metric mutation request DTOs removed by F-1 (b7b20e4).
    /// </summary>
    private static readonly HashSet<string> ForbiddenContractsTypes = new(StringComparer.Ordinal)
    {
        "SaveRtsGridMetricRequest",
        "SaveMetricTranslationRequest"
    };

    [Fact]
    [Trait("Req", "F-1")]
    public void ApplicationAssembly_ShouldNotContain_MetricMutationCommands()
    {
        // Arrange: get the Application assembly via a still-existing type
        var applicationAssembly = typeof(CcDashboard.Application.Queries.Configuration.GetRtsGridMetricsQuery).Assembly;

        // Act: get all type names in the assembly
        var typeNames = applicationAssembly.GetTypes()
            .Select(t => t.Name)
            .ToHashSet(StringComparer.Ordinal);

        // Assert: none of the forbidden types should exist
        var found = ForbiddenApplicationTypes.Intersect(typeNames).ToList();

        found.Should().BeEmpty(
            because: "F-1 invariant: metrics are vendor product-constants — no client-driven " +
                     "create/edit/delete/translate commands may exist. " +
                     $"Found forbidden types: [{string.Join(", ", found)}]. " +
                     "If any mutation command reappears, F-1 has regressed (RCE surface via " +
                     "Roslyn-compiled MetricFunction/Parameter/Format).");
    }

    [Fact]
    [Trait("Req", "F-1")]
    public void ContractsAssembly_ShouldNotContain_MetricMutationRequests()
    {
        // Arrange: get the Contracts assembly via a still-existing type
        var contractsAssembly = typeof(CcDashboard.Contracts.DTOs.Auth.LoginRequest).Assembly;

        // Act: get all type names in the assembly
        var typeNames = contractsAssembly.GetTypes()
            .Select(t => t.Name)
            .ToHashSet(StringComparer.Ordinal);

        // Assert: none of the forbidden types should exist
        var found = ForbiddenContractsTypes.Intersect(typeNames).ToList();

        found.Should().BeEmpty(
            because: "F-1 invariant: metrics are vendor product-constants — no client-driven " +
                     "mutation request DTOs may exist. " +
                     $"Found forbidden types: [{string.Join(", ", found)}]. " +
                     "The only sanctioned metric change path is vendor package-deploy via ApplyService.");
    }

    [Fact]
    [Trait("Req", "F-1")]
    public void ReadPath_ShouldStillExist_GetRtsGridMetricsQuery()
    {
        // Sanity check: the READ path must still exist (we use it to get the assembly)
        var applicationAssembly = typeof(CcDashboard.Application.Queries.Configuration.GetRtsGridMetricsQuery).Assembly;

        var typeNames = applicationAssembly.GetTypes()
            .Select(t => t.Name)
            .ToHashSet(StringComparer.Ordinal);

        typeNames.Should().Contain("GetRtsGridMetricsQuery",
            because: "the read-only metrics query is the sanctioned read path and must exist");
    }
}
'''

path = r"D:\Claude\Projects\RTM View Shell\tests\CcDashboard.Tests.Security\Configuration\RtsGridMetricCatalogueTests.cs"
with open(path, "w", encoding="utf-8") as f:
    f.write(content)
    f.flush()
    os.fsync(f.fileno())

print(f"Written: {len(content.splitlines())} lines")
