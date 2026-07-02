using CcDashboard.Application.HistoricalReports;
using CcDashboard.Application.HistoricalReports.Validators;
using CcDashboard.Domain.Domain.Reports;
using FluentAssertions;

namespace CcDashboard.Tests.Unit.HistoricalReports;

/// <summary>
/// Tests for ReportWidgetConfig parsing and validation.
/// Per Reports-Backend-v1-Spec §2 LOCKED.
/// Updated 2026-07-02: BU-ONLY scope (Mode/QueueIds removed), PageSize 1..1000 (ValidPageSizes removed).
/// </summary>
public class ReportWidgetConfigValidatorTests
{
    [Fact]
    public void ValidConfig_BuScope_Passes()
    {
        var config = new ReportWidgetConfig
        {
            Title = "Test Widget",
            Scope = new ReportWidgetScope
            {
                BusinessUnitIds = new[] { 1, 2 }
            },
            Columns = new[] { "Offered", "Answered" },
            PageSize = 25
        };

        var validator = new ReportWidgetConfigValidator();
        var result = validator.Validate(config);

        result.IsValid.Should().BeTrue();
    }

    [Fact]
    public void BuScope_EmptyBusinessUnitIds_Fails()
    {
        var config = new ReportWidgetConfig
        {
            Scope = new ReportWidgetScope
            {
                BusinessUnitIds = Array.Empty<int>()
            },
            Columns = new[] { "Offered" },
            PageSize = 25
        };

        var validator = new ReportWidgetConfigValidator();
        var result = validator.Validate(config);

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.ErrorMessage.Contains("BusinessUnitIds"));
    }

    [Fact]
    public void BuScope_NullBusinessUnitIds_Fails()
    {
        var config = new ReportWidgetConfig
        {
            Scope = new ReportWidgetScope
            {
                BusinessUnitIds = null
            },
            Columns = new[] { "Offered" },
            PageSize = 25
        };

        var validator = new ReportWidgetConfigValidator();
        var result = validator.Validate(config);

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.ErrorMessage.Contains("BusinessUnitIds"));
    }

    [Fact]
    public void EmptyColumns_Valid_v1()
    {
        // v1: Columns are OPTIONAL — server supplies DefaultColumns when null/empty
        var config = new ReportWidgetConfig
        {
            Scope = new ReportWidgetScope
            {
                BusinessUnitIds = new[] { 1 }
            },
            Columns = Array.Empty<string>(),
            PageSize = 25
        };

        var validator = new ReportWidgetConfigValidator();
        var result = validator.Validate(config);

        result.IsValid.Should().BeTrue();
    }

    [Fact]
    public void NullColumns_Valid_v1()
    {
        // v1: Columns are OPTIONAL — server supplies DefaultColumns when null/empty
        var config = new ReportWidgetConfig
        {
            Scope = new ReportWidgetScope
            {
                BusinessUnitIds = new[] { 1 }
            },
            Columns = null,
            PageSize = 25
        };

        var validator = new ReportWidgetConfigValidator();
        var result = validator.Validate(config);

        result.IsValid.Should().BeTrue();
    }

    [Fact]
    public void ScopeOnlyConfig_Valid_v1()
    {
        // v1: A Scope-only config (no columns) is VALID — server supplies DefaultColumns
        var config = new ReportWidgetConfig
        {
            Scope = new ReportWidgetScope
            {
                BusinessUnitIds = new[] { 1, 2 }
            },
            PageSize = 25
            // NO Columns property
        };

        var validator = new ReportWidgetConfigValidator();
        var result = validator.Validate(config);

        result.IsValid.Should().BeTrue();
    }

    [Theory]
    [InlineData(30, true)]
    [InlineData(60, true)]
    [InlineData(15, false)]
    [InlineData(45, false)]
    public void Interval_ValidatesCorrectly(int interval, bool expectedValid)
    {
        var config = new ReportWidgetConfig
        {
            Scope = new ReportWidgetScope
            {
                BusinessUnitIds = new[] { 1 }
            },
            Columns = new[] { "Offered" },
            Interval = interval,
            PageSize = 25
        };

        var validator = new ReportWidgetConfigValidator();
        var result = validator.Validate(config);

        result.IsValid.Should().Be(expectedValid);
    }

    [Theory]
    [InlineData(1, true)]      // Min valid
    [InlineData(25, true)]     // Common page size
    [InlineData(50, true)]     // Common page size
    [InlineData(100, true)]    // Common page size
    [InlineData(500, true)]    // Mid-range
    [InlineData(1000, true)]   // Max valid
    [InlineData(0, false)]     // Below min
    [InlineData(1001, false)]  // Above max
    public void PageSize_ValidatesCorrectly(int pageSize, bool expectedValid)
    {
        var config = new ReportWidgetConfig
        {
            Scope = new ReportWidgetScope
            {
                BusinessUnitIds = new[] { 1 }
            },
            Columns = new[] { "Offered" },
            PageSize = pageSize
        };

        var validator = new ReportWidgetConfigValidator();
        var result = validator.Validate(config);

        result.IsValid.Should().Be(expectedValid);
        if (!expectedValid)
        {
            result.Errors.Should().Contain(e => e.ErrorMessage.Contains("PageSize must be between 1 and 1000"));
        }
    }

    [Fact]
    public void AgentWidget_BuScope_NoAgentAxis_Fails()
    {
        var config = new ReportWidgetConfig
        {
            Scope = new ReportWidgetScope
            {
                BusinessUnitIds = new[] { 1 }
            },
            Columns = new[] { "SumAvailableMs" },
            PageSize = 25
        };

        var validator = new ReportWidgetConfigWithTypeValidator();
        var result = validator.Validate((config, ReportWidgetType.AgentMonthly));

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.ErrorMessage.Contains("AgentAxis"));
    }

    [Fact]
    public void AgentWidget_BuScope_WithAgentAxis_Passes()
    {
        var config = new ReportWidgetConfig
        {
            Scope = new ReportWidgetScope
            {
                BusinessUnitIds = new[] { 1 },
                AgentAxis = AgentReportAxis.Detail
            },
            Columns = new[] { "SumAvailableMs" },
            PageSize = 25
        };

        var validator = new ReportWidgetConfigWithTypeValidator();
        var result = validator.Validate((config, ReportWidgetType.AgentMonthly));

        result.IsValid.Should().BeTrue();
    }

    [Fact]
    public void QueueWidget_BuScope_Passes()
    {
        var config = new ReportWidgetConfig
        {
            Scope = new ReportWidgetScope
            {
                BusinessUnitIds = new[] { 1, 2 }
            },
            Columns = new[] { "Offered" },
            PageSize = 25
        };

        var validator = new ReportWidgetConfigWithTypeValidator();
        var result = validator.Validate((config, ReportWidgetType.QueueInterval));

        result.IsValid.Should().BeTrue();
    }

    [Fact]
    public void ParseValidJson_ReturnsConfig()
    {
        var json = """
        {
            "title": "My Widget",
            "scope": {
                "businessUnitIds": [1, 2, 3],
                "agentAxis": "detail"
            },
            "columns": ["Offered", "Answered"],
            "pageSize": 50,
            "interval": 30
        }
        """;

        var config = ReportWidgetConfig.Parse(json);

        config.Title.Should().Be("My Widget");
        config.Scope.BusinessUnitIds.Should().BeEquivalentTo(new[] { 1, 2, 3 });
        config.Scope.AgentAxis.Should().Be(AgentReportAxis.Detail);
        config.Columns.Should().BeEquivalentTo(new[] { "Offered", "Answered" });
        config.PageSize.Should().Be(50);
        config.Interval.Should().Be(30);
    }

    [Fact]
    public void ParseInvalidJson_Throws()
    {
        var json = "{ invalid json }";

        Action act = () => ReportWidgetConfig.Parse(json);

        act.Should().Throw<System.Text.Json.JsonException>();
    }

    [Fact]
    public void TitleTooLong_Fails()
    {
        var config = new ReportWidgetConfig
        {
            Title = new string('x', 250),
            Scope = new ReportWidgetScope
            {
                BusinessUnitIds = new[] { 1 }
            },
            Columns = new[] { "Offered" },
            PageSize = 25
        };

        var validator = new ReportWidgetConfigValidator();
        var result = validator.Validate(config);

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.PropertyName.Contains("Title"));
    }

    #region DefaultColumns and GetEffectiveColumns tests

    [Theory]
    [InlineData(ReportWidgetType.QueueInterval, new[] { "IntervalStart", "Offered", "Answered", "Abandoned", "AnsweredInSl", "AbandonPct", "SlPct", "Asa", "QueueAht" })]
    [InlineData(ReportWidgetType.QueueWaitTime, new[] { "IntervalStart", "Answered", "Asa", "AnsweredInSl", "SlPct" })]
    [InlineData(ReportWidgetType.Distribution, new[] { "Label", "Count", "Percentage" })]
    public void DefaultColumns_ReturnsCorrectColumnsPerType(ReportWidgetType widgetType, string[] expectedColumns)
    {
        var columns = ReportWidgetConfig.DefaultColumns(widgetType);

        columns.Should().BeEquivalentTo(expectedColumns, opts => opts.WithStrictOrdering());
    }

    [Fact]
    public void DefaultColumns_AgentMonthly_ReturnsExpected()
    {
        var columns = ReportWidgetConfig.DefaultColumns(ReportWidgetType.AgentMonthly);

        columns.Should().Contain("YearMonth");
        columns.Should().Contain("AgentExternalId");
        columns.Should().Contain("OccupancyPct");
        columns.Should().Contain("AgentAht");
    }

    [Fact]
    public void DefaultColumns_AgentShiftDetail_ReturnsExpected()
    {
        var columns = ReportWidgetConfig.DefaultColumns(ReportWidgetType.AgentShiftDetail);

        columns.Should().Contain("IntervalStart");
        columns.Should().Contain("AgentExternalId");
        columns.Should().Contain("TalkPureMs");
    }

    [Fact]
    public void GetEffectiveColumns_WithExplicitColumns_ReturnsExplicit()
    {
        var config = new ReportWidgetConfig
        {
            Scope = new ReportWidgetScope { BusinessUnitIds = new[] { 1 } },
            Columns = new[] { "Offered", "Abandoned" },
            PageSize = 25
        };

        var effective = config.GetEffectiveColumns(ReportWidgetType.QueueInterval);

        effective.Should().BeEquivalentTo(new[] { "Offered", "Abandoned" }, opts => opts.WithStrictOrdering());
    }

    [Fact]
    public void GetEffectiveColumns_WithNullColumns_ReturnsDefaults()
    {
        var config = new ReportWidgetConfig
        {
            Scope = new ReportWidgetScope { BusinessUnitIds = new[] { 1 } },
            Columns = null,
            PageSize = 25
        };

        var effective = config.GetEffectiveColumns(ReportWidgetType.QueueInterval);

        effective.Should().BeEquivalentTo(ReportWidgetConfig.DefaultColumns(ReportWidgetType.QueueInterval));
    }

    [Fact]
    public void GetEffectiveColumns_WithEmptyColumns_ReturnsDefaults()
    {
        var config = new ReportWidgetConfig
        {
            Scope = new ReportWidgetScope { BusinessUnitIds = new[] { 1 } },
            Columns = Array.Empty<string>(),
            PageSize = 25
        };

        var effective = config.GetEffectiveColumns(ReportWidgetType.QueueWaitTime);

        effective.Should().BeEquivalentTo(ReportWidgetConfig.DefaultColumns(ReportWidgetType.QueueWaitTime));
    }

    #endregion

    #region Scope rules still enforced (SF-BI-001 intact)

    [Fact]
    public void ScopeOnlyConfig_MissingBUs_StillFails()
    {
        // Scope rules STAY required even when Columns is optional
        var config = new ReportWidgetConfig
        {
            Scope = new ReportWidgetScope
            {
                BusinessUnitIds = Array.Empty<int>()
            },
            PageSize = 25
        };

        var validator = new ReportWidgetConfigValidator();
        var result = validator.Validate(config);

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.ErrorMessage.Contains("BusinessUnitIds"));
    }

    #endregion
}
