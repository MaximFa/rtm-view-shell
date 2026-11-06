using CcDashboard.Contracts.Common;
using FluentAssertions;

namespace CcDashboard.Tests.Unit.Common;

/// <summary>
/// The date column follows the MODE, not the column picker. Measured 2026-11-04: the server's
/// standard set for this report has eight columns and no Date, and a user may also pick the
/// columns by hand - so neither side can be relied on to supply it in by-date mode.
/// </summary>
public class AgentSummaryColumnsTests
{
    private static readonly string[] Picked = { "AgentExternalId", "Handled", "AgentAht" };

    [Fact]
    public void ByDate_showsTheDateFirst_evenWhenNobodyPickedIt()
    {
        AgentSummaryColumns.ForMode(Picked, byDate: true)
            .Should().Equal("Date", "AgentExternalId", "Handled", "AgentAht");
    }

    [Fact]
    public void ByDate_doesNotShowTheDateTwice_whenItWasPicked()
    {
        // A duplicated column renders two identical headers over two identical cells, which reads
        // as a data error in the report rather than as a repeated column.
        AgentSummaryColumns.ForMode(new[] { "AgentExternalId", "Date", "Handled" }, byDate: true)
            .Should().Equal("Date", "AgentExternalId", "Handled");
    }

    [Fact]
    public void Summary_dropsTheDate_evenWhenItWasPicked()
    {
        // In summary mode Date is null for every row: the column would be a stripe of dashes
        // standing where data is expected.
        AgentSummaryColumns.ForMode(new[] { "Date", "AgentExternalId", "Handled" }, byDate: false)
            .Should().Equal("AgentExternalId", "Handled");
    }

    [Fact]
    public void TheOtherColumnsKeepTheirOrder()
    {
        // The order comes from the server's answer; re-sorting here would make the table look
        // different from what the picker promised.
        var many = new[] { "Handled", "AgentExternalId", "AgentAht", "OccupancyPct" };
        AgentSummaryColumns.ForMode(many, byDate: true).Skip(1).Should().Equal(many);
        AgentSummaryColumns.ForMode(many, byDate: false).Should().Equal(many);
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public void NoColumnsAtAll_isNotACrash(bool byDate)
    {
        // An empty or null set reaches here when the server answered with none; by-date still
        // shows the date, summary shows nothing - and neither throws, because a widget that threw
        // would show an error where the honest answer is "no columns".
        AgentSummaryColumns.ForMode(null, byDate).Should().Equal(byDate ? new[] { "Date" } : Array.Empty<string>());
        AgentSummaryColumns.ForMode(Array.Empty<string>(), byDate)
            .Should().Equal(byDate ? new[] { "Date" } : Array.Empty<string>());
    }
}
