using CcDashboard.Application.Commands.Configuration;
using CcDashboard.Contracts.DTOs.Configuration;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Commands.Configuration;

public class SaveMetricTranslationCommandHandlerTests
{
    private readonly IRtsGridMetricRepository _repo = Substitute.For<IRtsGridMetricRepository>();
    private readonly SaveMetricTranslationCommandHandler _handler;

    public SaveMetricTranslationCommandHandlerTests()
    {
        _handler = new SaveMetricTranslationCommandHandler(_repo);
    }

    [Fact]
    public async Task Handle_InsertPath_AddsNewTranslation()
    {
        // Arrange: metric exists, no existing translation
        _repo.GetByIdAsync("METRIC-001", Arg.Any<CancellationToken>())
            .Returns(new RtsGridMetric { MetricId = "METRIC-001" });
        _repo.GetTranslationAsync("METRIC-001", "ru-RU", Arg.Any<CancellationToken>())
            .Returns((RtsGridMetricTranslation?)null);

        RtsGridMetricTranslation? saved = null;
        await _repo.UpsertTranslationAsync(Arg.Do<RtsGridMetricTranslation>(t => saved = t), Arg.Any<CancellationToken>());

        var req = new SaveMetricTranslationRequest(
            "METRIC-001", "ru-RU", "Название", "Краткое", "Длинное", "Сравнение");

        // Act
        var result = await _handler.Handle(new SaveMetricTranslationCommand(req), CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeTrue();
        saved.Should().NotBeNull();
        saved!.MetricId.Should().Be("METRIC-001");
        saved.Locale.Should().Be("ru-RU");
        saved.DisplayName.Should().Be("Название");
        saved.ShortDescription.Should().Be("Краткое");
        saved.LongDescription.Should().Be("Длинное");
        saved.Comparison.Should().Be("Сравнение");
    }

    [Fact]
    public async Task Handle_UpdatePath_ModifiesExistingTranslation()
    {
        // Arrange: metric exists, translation exists
        _repo.GetByIdAsync("METRIC-002", Arg.Any<CancellationToken>())
            .Returns(new RtsGridMetric { MetricId = "METRIC-002" });

        RtsGridMetricTranslation? saved = null;
        await _repo.UpsertTranslationAsync(Arg.Do<RtsGridMetricTranslation>(t => saved = t), Arg.Any<CancellationToken>());

        var req = new SaveMetricTranslationRequest(
            "METRIC-002", "he-IL", "שם", "קצר", "ארוך", "השוואה");

        // Act
        var result = await _handler.Handle(new SaveMetricTranslationCommand(req), CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeTrue();
        saved.Should().NotBeNull();
        saved!.Locale.Should().Be("he-IL");
        saved.DisplayName.Should().Be("שם");
    }

    [Fact]
    public async Task Handle_EmptyStringBecomesNull()
    {
        // Arrange
        _repo.GetByIdAsync("METRIC-003", Arg.Any<CancellationToken>())
            .Returns(new RtsGridMetric { MetricId = "METRIC-003" });

        RtsGridMetricTranslation? saved = null;
        await _repo.UpsertTranslationAsync(Arg.Do<RtsGridMetricTranslation>(t => saved = t), Arg.Any<CancellationToken>());

        // Empty strings and whitespace-only should become null (for EN-fallback to work)
        var req = new SaveMetricTranslationRequest(
            "METRIC-003", "ru-RU", "", "  ", null, "   ");

        // Act
        var result = await _handler.Handle(new SaveMetricTranslationCommand(req), CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeTrue();
        saved!.DisplayName.Should().BeNull();
        saved.ShortDescription.Should().BeNull();
        saved.LongDescription.Should().BeNull();
        saved.Comparison.Should().BeNull();
    }

    [Fact]
    public async Task Handle_UnsupportedLocale_ReturnsFailure()
    {
        _repo.GetByIdAsync("METRIC-004", Arg.Any<CancellationToken>())
            .Returns(new RtsGridMetric { MetricId = "METRIC-004" });

        var req = new SaveMetricTranslationRequest("METRIC-004", "fr-FR", "Nom", null, null, null);
        var result = await _handler.Handle(new SaveMetricTranslationCommand(req), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("Unsupported locale");
    }

    [Fact]
    public async Task Handle_MetricNotFound_ReturnsFailure()
    {
        _repo.GetByIdAsync("MISSING", Arg.Any<CancellationToken>())
            .Returns((RtsGridMetric?)null);

        var req = new SaveMetricTranslationRequest("MISSING", "ru-RU", "Название", null, null, null);
        var result = await _handler.Handle(new SaveMetricTranslationCommand(req), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }

    [Fact]
    public async Task Handle_TrimsWhitespace()
    {
        _repo.GetByIdAsync("METRIC-005", Arg.Any<CancellationToken>())
            .Returns(new RtsGridMetric { MetricId = "METRIC-005" });

        RtsGridMetricTranslation? saved = null;
        await _repo.UpsertTranslationAsync(Arg.Do<RtsGridMetricTranslation>(t => saved = t), Arg.Any<CancellationToken>());

        var req = new SaveMetricTranslationRequest(
            "METRIC-005", "ru-RU", "  Название  ", "  Краткое  ", null, null);

        await _handler.Handle(new SaveMetricTranslationCommand(req), CancellationToken.None);

        saved!.DisplayName.Should().Be("Название");
        saved.ShortDescription.Should().Be("Краткое");
    }
}
