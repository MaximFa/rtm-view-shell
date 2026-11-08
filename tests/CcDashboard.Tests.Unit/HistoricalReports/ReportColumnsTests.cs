using CcDashboard.Application.HistoricalReports;
using CcDashboard.Domain.Domain.Reports;
using FluentAssertions;

namespace CcDashboard.Tests.Unit.HistoricalReports;

/// <summary>FEAT-REPORT-COLUMN-FUNNEL-FILTERS-01: one kind rule for every column of every table report.</summary>
public class ReportColumnsTests
{
    [Theory]
    [InlineData(ReportWidgetType.QueueInterval)]
    [InlineData(ReportWidgetType.QueueWaitTime)]
    [InlineData(ReportWidgetType.AgentMonthly)]
    [InlineData(ReportWidgetType.AgentShiftDetail)]
    [InlineData(ReportWidgetType.EndOfShiftAgents)]
    [InlineData(ReportWidgetType.EndOfShiftQueues)]
    [InlineData(ReportWidgetType.AgentPerformance)]
    public void EveryFieldOfEveryRow_HasAKind(ReportWidgetType type)
    {
        var row = ReportColumns.RowTypeOf(type)!;
        ReportColumns.For(type).Select(c => c.Name).Should().Equal(row.GetProperties().Select(p => p.Name));
    }

    private record RowWithAnUnknownField(string AgentExternalId, int Whatever);

    [Fact]
    public void EveryTableType_IsListed_AndOnlyTheChartsAreNot()
    {
        // a new table type added to the enum without a row in RowTypeOf would be missed by the theory above;
        // the types without a table: Distribution (retired) and the queue trend chart (FEAT-REPORT-QUEUE-TREND-COMPARE-01)
        Enum.GetValues<ReportWidgetType>().Where(t => ReportColumns.RowTypeOf(t) is null)
            .Should().Equal(ReportWidgetType.Distribution, ReportWidgetType.QueueTrend, ReportWidgetType.AgentStateTrend);
    }

    [Fact]
    public void AFieldWithoutAKind_IsADefect_NotADefault()
    {
        var act = () => ReportColumns.KindsOf(typeof(RowWithAnUnknownField));
        act.Should().Throw<InvalidOperationException>().WithMessage("*Whatever*");
    }

    [Fact]
    public void Kinds_AsMeasured()
    {
        // FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01: the agents row has IntervalStart (by step) instead of Date (ByDate, retired)
        Kind(ReportWidgetType.EndOfShiftAgents, "IntervalStart").Should().Be(ReportColumnKind.DateTime);
        Kind(ReportWidgetType.QueueInterval, "IntervalStart").Should().Be(ReportColumnKind.DateTime);
        Kind(ReportWidgetType.AgentMonthly, "YearMonth").Should().Be(ReportColumnKind.Text);
        Kind(ReportWidgetType.EndOfShiftQueues, "QueueId").Should().Be(ReportColumnKind.Id);
        Kind(ReportWidgetType.QueueWaitTime, "SumWaitAnswered").Should().Be(ReportColumnKind.DurationSec, "seconds, not ms");
        Kind(ReportWidgetType.EndOfShiftAgents, "SumLoggedInMs").Should().Be(ReportColumnKind.DurationMs);
        Kind(ReportWidgetType.AgentShiftDetail, "AgentAht").Should().Be(ReportColumnKind.DurationSec);
        Kind(ReportWidgetType.EndOfShiftQueues, "SlPct").Should().Be(ReportColumnKind.Percent);
        Kind(ReportWidgetType.AgentMonthly, "Handled").Should().Be(ReportColumnKind.Count);
    }

    [Fact]
    public void NoFunnel_OnIdAndOnTheAlwaysEmptyWorkgroup()
    {
        ReportColumns.Find(ReportWidgetType.EndOfShiftQueues, "QueueId")!.Filterable.Should().BeFalse();
        ReportColumns.Find(ReportWidgetType.QueueInterval, "Workgroup")!.Filterable.Should().BeFalse();
        ReportColumns.Find(ReportWidgetType.QueueWaitTime, "Workgroup")!.Filterable.Should().BeFalse();
        ReportColumns.Find(ReportWidgetType.EndOfShiftQueues, "Workgroup")!.Filterable.Should().BeTrue("negative half: there it is filled");
        ReportColumns.For(ReportWidgetType.Distribution).Should().BeEmpty();
    }

    private static ReportColumnKind Kind(ReportWidgetType t, string c) => ReportColumns.Find(t, c)!.Kind;
}
