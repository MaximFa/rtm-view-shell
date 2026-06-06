using CcDashboard.Application.Services.Metrics;
using CcDashboard.Contracts.DTOs.Configuration;
using CcDashboard.Domain.Domain;
using FluentAssertions;
using Xunit;

namespace CcDashboard.Tests.Unit.Metrics;

public class MetricLocalizationTests
{
    private static RtsGridMetricDto CreateBaseDto(
        string metricId = "TestMetric",
        string displayName = "Base Display",
        string shortDesc = "Base Short",
        string longDesc = "Base Long",
        string comparison = "Base Comparison")
    {
        return new RtsGridMetricDto(
            metricId,
            Description: "Description",
            DataType: "Data",
            MetricFunction: "Func",
            MetricParameter: "Param",
            MetricFormat: null,
            DefaultValue: null,
            ValueType: "String",
            MetricType: "Agent",
            DisplayName: displayName,
            ShortDescription: shortDesc,
            LongDescription: longDesc,
            Comparison: comparison,
            StandardKpi: "KPI",
            StandardRef: "Ref",
            CatalogCategory: "Queue",
            Family: "family",
            Channel: "calls",
            ThresholdSec: 30,
            CatalogStatus: "active",
            CatalogNotes: "notes");
    }

    [Fact]
    public void Apply_WithFullTranslation_UsesAllLocalizedValues()
    {
        // Arrange
        var baseDto = CreateBaseDto();
        var translation = new RtsGridMetricTranslation
        {
            MetricId = "TestMetric",
            Locale = "ru-RU",
            DisplayName = "Локализованное имя",
            ShortDescription = "Короткое описание",
            LongDescription = "Длинное описание",
            Comparison = "Сравнение"
        };

        // Act
        var result = MetricLocalization.Apply(baseDto, translation);

        // Assert
        result.DisplayName.Should().Be("Локализованное имя");
        result.ShortDescription.Should().Be("Короткое описание");
        result.LongDescription.Should().Be("Длинное описание");
        result.Comparison.Should().Be("Сравнение");
    }

    [Fact]
    public void Apply_WithNullTranslation_UsesBaseValues()
    {
        // Arrange
        var baseDto = CreateBaseDto();

        // Act
        var result = MetricLocalization.Apply(baseDto, null);

        // Assert
        result.DisplayName.Should().Be("Base Display");
        result.ShortDescription.Should().Be("Base Short");
        result.LongDescription.Should().Be("Base Long");
        result.Comparison.Should().Be("Base Comparison");
    }

    [Fact]
    public void Apply_WithPartialTranslation_UsesLocalizedForPresent_FallbackForMissing()
    {
        // Arrange
        var baseDto = CreateBaseDto();
        var translation = new RtsGridMetricTranslation
        {
            MetricId = "TestMetric",
            Locale = "he-IL",
            DisplayName = null,  // Missing
            ShortDescription = "תיאור קצר",  // Present
            LongDescription = "",  // Empty = fallback
            Comparison = "   "  // Whitespace = fallback
        };

        // Act
        var result = MetricLocalization.Apply(baseDto, translation);

        // Assert
        result.DisplayName.Should().Be("Base Display");  // Fallback
        result.ShortDescription.Should().Be("תיאור קצר");  // Localized
        result.LongDescription.Should().Be("Base Long");  // Fallback (empty)
        result.Comparison.Should().Be("Base Comparison");  // Fallback (whitespace)
    }

    [Fact]
    public void Apply_NonTranslatableFields_NeverChange()
    {
        // Arrange
        var baseDto = CreateBaseDto();
        var translation = new RtsGridMetricTranslation
        {
            MetricId = "TestMetric",
            Locale = "ru-RU",
            DisplayName = "Локализованное имя",
            ShortDescription = "Короткое описание",
            LongDescription = "Длинное описание",
            Comparison = "Сравнение"
        };

        // Act
        var result = MetricLocalization.Apply(baseDto, translation);

        // Assert non-translatable fields unchanged
        result.MetricId.Should().Be(baseDto.MetricId);
        result.Family.Should().Be(baseDto.Family);
        result.StandardKpi.Should().Be(baseDto.StandardKpi);
        result.Channel.Should().Be(baseDto.Channel);
        result.CatalogCategory.Should().Be(baseDto.CatalogCategory);
        result.MetricFunction.Should().Be(baseDto.MetricFunction);
        result.MetricParameter.Should().Be(baseDto.MetricParameter);
        result.DataType.Should().Be(baseDto.DataType);
        result.ValueType.Should().Be(baseDto.ValueType);
        result.MetricType.Should().Be(baseDto.MetricType);
        result.ThresholdSec.Should().Be(baseDto.ThresholdSec);
        result.CatalogStatus.Should().Be(baseDto.CatalogStatus);
        result.CatalogNotes.Should().Be(baseDto.CatalogNotes);
        result.StandardRef.Should().Be(baseDto.StandardRef);
    }
}