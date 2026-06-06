using CcDashboard.Application.Commands.Configuration;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Configuration;
using CcDashboard.Infrastructure.Persistence.Repositories;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using NSubstitute;
using System.Text.RegularExpressions;

namespace CcDashboard.Tests.Security.Configuration;

/// <summary>
/// Tests for RtsGridMetric catalogue fields (D3b) and UUIDv7-dashless ID generation.
/// </summary>
[Collection("Postgres")]
public class RtsGridMetricCatalogueTests(PostgresFixture postgres)
{
    private static readonly Regex UuidDashlessRegex = new("^[0-9a-f]{32}$", RegexOptions.Compiled);

    // ── ADD: UUIDv7-dashless ID generation ──────────────────────────────────────

    [Fact]
    [Trait("Req", "D3b")]
    public async Task Add_GeneratesUuidv7DashlessId()
    {
        // Arrange
        var apiHook = Substitute.For<IConfigurationApiHook>();
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var repo = new RtsGridMetricRepository(beDb);
        var handler = new SaveRtsGridMetricCommandHandler(repo, apiHook);

        var request = new SaveRtsGridMetricRequest(
            MetricId: "ignored-client-id",
            Description: "Test metric for UUID check",
            DataType: "Simple",
            MetricFunction: "SumSessionsCount",
            MetricParameter: "TestParam",
            MetricFormat: null,
            DefaultValue: null,
            ValueType: "Number",
            MetricType: "Agent",
            DisplayName: null, ShortDescription: null, LongDescription: null, Comparison: null,
            StandardKpi: null, StandardRef: null, CatalogCategory: null, Family: null, Channel: null,
            ThresholdSec: null, CatalogStatus: null, CatalogNotes: null,
            IsNew: true);

        // Act
        var result = await handler.Handle(new SaveRtsGridMetricCommand(request), CancellationToken.None);
        await beDb.SaveChangesAsync();
        await beDb.SaveChangesAsync();

        // Assert
        result.IsSuccess.Should().BeTrue();

        // Find the newly created metric (not the ignored-client-id)
        var metrics = await beDb.RtsGridMetrics.ToListAsync();
        var newMetric = metrics.FirstOrDefault(m => m.Description == "Test metric for UUID check");
        newMetric.Should().NotBeNull();
        newMetric!.MetricId.Should().NotBe("ignored-client-id", "server must ignore client-supplied MetricId");
        UuidDashlessRegex.IsMatch(newMetric.MetricId).Should().BeTrue(
            $"MetricId should be 32 lowercase hex chars (UUIDv7 dashless), was: {newMetric.MetricId}");
    }

    [Fact]
    [Trait("Req", "D3b")]
    public async Task Add_IgnoresClientSuppliedMetricId()
    {
        // Arrange
        var apiHook = Substitute.For<IConfigurationApiHook>();
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var repo = new RtsGridMetricRepository(beDb);
        var handler = new SaveRtsGridMetricCommandHandler(repo, apiHook);

        var clientId = "client-wants-this-id";
        var request = new SaveRtsGridMetricRequest(
            MetricId: clientId,
            Description: "Client ID ignore test",
            DataType: "Simple",
            MetricFunction: "SumSessionsCount",
            MetricParameter: "IgnoreTest",
            MetricFormat: null,
            DefaultValue: null,
            ValueType: "Number",
            MetricType: "Agent",
            DisplayName: null, ShortDescription: null, LongDescription: null, Comparison: null,
            StandardKpi: null, StandardRef: null, CatalogCategory: null, Family: null, Channel: null,
            ThresholdSec: null, CatalogStatus: null, CatalogNotes: null,
            IsNew: true);

        // Act
        await handler.Handle(new SaveRtsGridMetricCommand(request), CancellationToken.None);
        await beDb.SaveChangesAsync();

        // Assert
        var metric = await beDb.RtsGridMetrics.FirstOrDefaultAsync(m => m.MetricId == clientId);
        metric.Should().BeNull("server should NOT use client-supplied MetricId");
    }

    // ── ADD: Catalogue fields persistence ───────────────────────────────────────

    [Fact]
    [Trait("Req", "D3b")]
    public async Task Add_PersistsAll12CatalogueFields()
    {
        // Arrange
        var apiHook = Substitute.For<IConfigurationApiHook>();
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var repo = new RtsGridMetricRepository(beDb);
        var handler = new SaveRtsGridMetricCommandHandler(repo, apiHook);

        var request = new SaveRtsGridMetricRequest(
            MetricId: "will-be-replaced",
            Description: "Catalogue fields test",
            DataType: "Simple",
            MetricFunction: "SumSessionsCount",
            MetricParameter: "CatalogueTest",
            MetricFormat: null,
            DefaultValue: null,
            ValueType: "Number",
            MetricType: "Data",
            DisplayName: "Test Display Name",
            ShortDescription: "Short desc",
            LongDescription: "This is the long description",
            Comparison: "Lower is better",
            StandardKpi: "AHT",
            StandardRef: "ISO 18295",
            CatalogCategory: "Queue",
            Family: "Volume",
            Channel: "Voice",
            ThresholdSec: 120,
            CatalogStatus: "active",
            CatalogNotes: "Test notes",
            IsNew: true);

        // Act
        var result = await handler.Handle(new SaveRtsGridMetricCommand(request), CancellationToken.None);
        await beDb.SaveChangesAsync();
        await beDb.SaveChangesAsync();

        // Assert
        result.IsSuccess.Should().BeTrue();

        var metric = await beDb.RtsGridMetrics.FirstOrDefaultAsync(m => m.Description == "Catalogue fields test");
        metric.Should().NotBeNull();
        metric!.DisplayName.Should().Be("Test Display Name");
        metric.ShortDescription.Should().Be("Short desc");
        metric.LongDescription.Should().Be("This is the long description");
        metric.Comparison.Should().Be("Lower is better");
        metric.StandardKpi.Should().Be("AHT");
        metric.StandardRef.Should().Be("ISO 18295");
        metric.CatalogCategory.Should().Be("Queue");
        metric.Family.Should().Be("Volume");
        metric.Channel.Should().Be("Voice");
        metric.ThresholdSec.Should().Be(120);
        metric.CatalogStatus.Should().Be("active");
        metric.CatalogNotes.Should().Be("Test notes");
    }

    [Fact]
    [Trait("Req", "D3b")]
    public async Task Add_DefaultsCatalogStatusToActive_WhenNull()
    {
        // Arrange
        var apiHook = Substitute.For<IConfigurationApiHook>();
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var repo = new RtsGridMetricRepository(beDb);
        var handler = new SaveRtsGridMetricCommandHandler(repo, apiHook);

        var request = new SaveRtsGridMetricRequest(
            MetricId: "will-be-replaced",
            Description: "Status default test",
            DataType: "Simple",
            MetricFunction: "SumSessionsCount",
            MetricParameter: "StatusDefault",
            MetricFormat: null,
            DefaultValue: null,
            ValueType: "Number",
            MetricType: "Agent",
            DisplayName: null, ShortDescription: null, LongDescription: null, Comparison: null,
            StandardKpi: null, StandardRef: null, CatalogCategory: null, Family: null, Channel: null,
            ThresholdSec: null, CatalogStatus: null, CatalogNotes: null,
            IsNew: true);

        // Act
        await handler.Handle(new SaveRtsGridMetricCommand(request), CancellationToken.None);
        await beDb.SaveChangesAsync();

        // Assert
        var metric = await beDb.RtsGridMetrics.FirstOrDefaultAsync(m => m.Description == "Status default test");
        metric.Should().NotBeNull();
        metric!.CatalogStatus.Should().Be("active", "CatalogStatus should default to active on ADD");
    }

    // ── EDIT: Catalogue fields update ───────────────────────────────────────────

    [Fact]
    [Trait("Req", "D3b")]
    public async Task Edit_UpdatesCatalogueFields_WithoutChangingMetricId()
    {
        // Arrange: Create a metric first
        var apiHook = Substitute.For<IConfigurationApiHook>();
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var repo = new RtsGridMetricRepository(beDb);
        var handler = new SaveRtsGridMetricCommandHandler(repo, apiHook);

        var createRequest = new SaveRtsGridMetricRequest(
            MetricId: "ignored",
            Description: "Edit test metric",
            DataType: "Simple",
            MetricFunction: "SumSessionsCount",
            MetricParameter: "EditTest",
            MetricFormat: null,
            DefaultValue: null,
            ValueType: "Number",
            MetricType: "Agent",
            DisplayName: "Initial Name",
            ShortDescription: null, LongDescription: null, Comparison: null,
            StandardKpi: null, StandardRef: null, CatalogCategory: null, Family: null, Channel: null,
            ThresholdSec: null, CatalogStatus: "active", CatalogNotes: null,
            IsNew: true);

        await handler.Handle(new SaveRtsGridMetricCommand(createRequest), CancellationToken.None);
        await beDb.SaveChangesAsync();

        var created = await beDb.RtsGridMetrics.FirstOrDefaultAsync(m => m.Description == "Edit test metric");
        created.Should().NotBeNull();
        var originalId = created!.MetricId;

        // Detach to avoid tracking conflicts
        beDb.Entry(created).State = EntityState.Detached;

        // Act: Edit with new catalogue values
        var editRequest = new SaveRtsGridMetricRequest(
            MetricId: originalId,
            Description: "Edit test metric",
            DataType: "Simple",
            MetricFunction: "SumSessionsCount",
            MetricParameter: "EditTest",
            MetricFormat: null,
            DefaultValue: null,
            ValueType: "Number",
            MetricType: "Agent",
            DisplayName: "Updated Name",
            ShortDescription: "New short desc",
            LongDescription: "New long desc",
            Comparison: "Higher is better",
            StandardKpi: "FCR",
            StandardRef: "COPC",
            CatalogCategory: "Agent",
            Family: "Quality",
            Channel: "All",
            ThresholdSec: 60,
            CatalogStatus: "deprecated",
            CatalogNotes: "Updated notes",
            IsNew: false);

        var result = await handler.Handle(new SaveRtsGridMetricCommand(editRequest), CancellationToken.None);
        await beDb.SaveChangesAsync();

        // Assert
        result.IsSuccess.Should().BeTrue();

        var updated = await beDb.RtsGridMetrics.FirstOrDefaultAsync(m => m.MetricId == originalId);
        updated.Should().NotBeNull();
        updated!.MetricId.Should().Be(originalId, "MetricId should never change on EDIT");
        updated.DisplayName.Should().Be("Updated Name");
        updated.ShortDescription.Should().Be("New short desc");
        updated.LongDescription.Should().Be("New long desc");
        updated.Comparison.Should().Be("Higher is better");
        updated.StandardKpi.Should().Be("FCR");
        updated.StandardRef.Should().Be("COPC");
        updated.CatalogCategory.Should().Be("Agent");
        updated.Family.Should().Be("Quality");
        updated.Channel.Should().Be("All");
        updated.ThresholdSec.Should().Be(60);
        updated.CatalogStatus.Should().Be("deprecated");
        updated.CatalogNotes.Should().Be("Updated notes");
    }

    // ── Duplicate ID guard ──────────────────────────────────────────────────────

    [Fact]
    [Trait("Req", "D3b")]
    public async Task Edit_NonExistentMetric_ReturnsFailure()
    {
        // Arrange
        var apiHook = Substitute.For<IConfigurationApiHook>();
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var repo = new RtsGridMetricRepository(beDb);
        var handler = new SaveRtsGridMetricCommandHandler(repo, apiHook);

        var request = new SaveRtsGridMetricRequest(
            MetricId: "non-existent-id",
            Description: "Should fail",
            DataType: "Simple",
            MetricFunction: "SumSessionsCount",
            MetricParameter: "Fail",
            MetricFormat: null,
            DefaultValue: null,
            ValueType: "Number",
            MetricType: "Agent",
            DisplayName: null, ShortDescription: null, LongDescription: null, Comparison: null,
            StandardKpi: null, StandardRef: null, CatalogCategory: null, Family: null, Channel: null,
            ThresholdSec: null, CatalogStatus: null, CatalogNotes: null,
            IsNew: false);

        // Act
        var result = await handler.Handle(new SaveRtsGridMetricCommand(request), CancellationToken.None);
        await beDb.SaveChangesAsync();
        await beDb.SaveChangesAsync();

        // Assert
        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }
}
