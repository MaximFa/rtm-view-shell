using CcDashboard.Application.Services.Metrics;
using CcDashboard.Contracts.DTOs.Configuration;
using FluentAssertions;

namespace CcDashboard.Tests.Unit.Metrics;

public class MetricCatalogFilterTests
{
    private static RtsGridMetricDto MakeMetric(
        string metricId,
        string? metricType = "Data",
        string? catalogCategory = "Queue",
        string? family = null,
        string? channel = null,
        int? thresholdSec = null,
        string? displayName = null,
        string? description = null,
        string? shortDescription = null,
        string? standardKpi = null,
        string? catalogStatus = null)
    {
        return new RtsGridMetricDto(
            MetricId: metricId,
            Description: description ?? $"Description for {metricId}",
            DataType: "Interactions Summary",
            MetricFunction: "InteractionsCount",
            MetricParameter: "",
            MetricFormat: null,
            DefaultValue: null,
            ValueType: "number",
            MetricType: metricType ?? "Data",
            DisplayName: displayName,
            ShortDescription: shortDescription,
            LongDescription: null,
            Comparison: null,
            StandardKpi: standardKpi,
            StandardRef: null,
            CatalogCategory: catalogCategory,
            Family: family,
            Channel: channel,
            ThresholdSec: thresholdSec,
            CatalogStatus: catalogStatus,
            CatalogNotes: null);
    }

    private static readonly IReadOnlyList<RtsGridMetricDto> TestMetrics = new List<RtsGridMetricDto>
    {
        MakeMetric("QueueNumAnsweredCalls30sec", metricType: "Data", catalogCategory: "Queue",
            family: "queue.volume.answered_threshold", channel: "calls", thresholdSec: 30,
            displayName: "Answered Calls in 30s", shortDescription: "Calls answered within 30 seconds",
            standardKpi: "Service Level"),
        MakeMetric("QueueNumAnsweredCalls60sec", metricType: "Data", catalogCategory: "Queue",
            family: "queue.volume.answered_threshold", channel: "calls", thresholdSec: 60,
            displayName: "Answered Calls in 60s", shortDescription: "Calls answered within 60 seconds"),
        MakeMetric("QueueNumAnsweredChats30sec", metricType: "Data", catalogCategory: "Queue",
            family: "queue.volume.answered_threshold", channel: "chats", thresholdSec: 30,
            displayName: "Answered Chats in 30s"),
        MakeMetric("MonAgentTalkDuration", metricType: "Agent", catalogCategory: "Agent",
            family: "agent.duration", displayName: "Agent Talk Duration"),
        MakeMetric("MonAgentStatusAvailable", metricType: "Agent", catalogCategory: "AgentGroup",
            family: "group.state_count", displayName: "Available Agents"),
        MakeMetric("DuplicateMetric", catalogStatus: "duplicate"),
        MakeMetric("DeprecatedMetric", catalogStatus: "deprecated"),
        MakeMetric("DefectCandidate", catalogStatus: "defect-candidate",
            displayName: "Defect Metric", shortDescription: "This metric has issues"),
        MakeMetric("NoDisplayName", displayName: null, description: "Has Description Only"),
        MakeMetric("NoDisplayOrDesc", displayName: null, description: ""),
    };

    [Fact]
    public void Apply_ExcludesDuplicateAndDeprecated_Always()
    {
        var criteria = new MetricFilterCriteria(null, null, null, null, null, null);
        var result = MetricCatalogFilter.Apply(TestMetrics, criteria);

        result.Should().NotContain(m => m.MetricId == "DuplicateMetric");
        result.Should().NotContain(m => m.MetricId == "DeprecatedMetric");
    }

    [Fact]
    public void Apply_RetainsDefectCandidate()
    {
        var criteria = new MetricFilterCriteria(null, null, null, null, null, null);
        var result = MetricCatalogFilter.Apply(TestMetrics, criteria);

        result.Should().Contain(m => m.MetricId == "DefectCandidate");
    }

    [Fact]
    public void IsDefect_ReturnsTrueForDefectCandidate()
    {
        var defect = TestMetrics.First(m => m.MetricId == "DefectCandidate");
        MetricCatalogFilter.IsDefect(defect).Should().BeTrue();
    }

    [Fact]
    public void IsDefect_ReturnsFalseForNormalMetric()
    {
        var normal = TestMetrics.First(m => m.MetricId == "QueueNumAnsweredCalls30sec");
        MetricCatalogFilter.IsDefect(normal).Should().BeFalse();
    }

    [Fact]
    public void Apply_MetricTypeFilter_Agent_ExcludesDataMetrics()
    {
        var criteria = new MetricFilterCriteria("Agent", null, null, null, null, null);
        var result = MetricCatalogFilter.Apply(TestMetrics, criteria);

        result.Should().OnlyContain(m => m.MetricType == "Agent");
        result.Should().NotContain(m => m.MetricType == "Data");
    }

    [Fact]
    public void Apply_MetricTypeFilter_Data_ExcludesAgentMetrics()
    {
        var criteria = new MetricFilterCriteria("Data", null, null, null, null, null);
        var result = MetricCatalogFilter.Apply(TestMetrics, criteria);

        result.Should().OnlyContain(m => m.MetricType == "Data");
        result.Should().NotContain(m => m.MetricType == "Agent");
    }

    [Fact]
    public void Apply_CategoryFilter_NarrowsResults()
    {
        var criteria = new MetricFilterCriteria(null, "Queue", null, null, null, null);
        var result = MetricCatalogFilter.Apply(TestMetrics, criteria);

        result.Should().OnlyContain(m => m.CatalogCategory == "Queue");
    }

    [Fact]
    public void Apply_FamilyFilter_NarrowsResults()
    {
        var criteria = new MetricFilterCriteria(null, null, "queue.volume.answered_threshold", null, null, null);
        var result = MetricCatalogFilter.Apply(TestMetrics, criteria);

        result.Should().OnlyContain(m => m.Family == "queue.volume.answered_threshold");
        result.Should().HaveCount(3); // 30s calls, 60s calls, 30s chats
    }

    [Fact]
    public void Apply_ChannelFilter_NarrowsResults()
    {
        var criteria = new MetricFilterCriteria(null, null, null, "calls", null, null);
        var result = MetricCatalogFilter.Apply(TestMetrics, criteria);

        result.Should().OnlyContain(m => m.Channel == "calls");
    }

    [Fact]
    public void Apply_ThresholdFilter_NarrowsResults()
    {
        var criteria = new MetricFilterCriteria(null, null, null, null, 30, null);
        var result = MetricCatalogFilter.Apply(TestMetrics, criteria);

        result.Should().OnlyContain(m => m.ThresholdSec == 30);
    }

    [Fact]
    public void Apply_Search_MatchesLabel()
    {
        var criteria = new MetricFilterCriteria(null, null, null, null, null, "Talk Duration");
        var result = MetricCatalogFilter.Apply(TestMetrics, criteria);

        result.Should().Contain(m => m.MetricId == "MonAgentTalkDuration");
    }

    [Fact]
    public void Apply_Search_MatchesShortDescription()
    {
        var criteria = new MetricFilterCriteria(null, null, null, null, null, "within 30 seconds");
        var result = MetricCatalogFilter.Apply(TestMetrics, criteria);

        result.Should().Contain(m => m.MetricId == "QueueNumAnsweredCalls30sec");
    }

    [Fact]
    public void Apply_Search_MatchesStandardKpi()
    {
        var criteria = new MetricFilterCriteria(null, null, null, null, null, "Service Level");
        var result = MetricCatalogFilter.Apply(TestMetrics, criteria);

        result.Should().Contain(m => m.MetricId == "QueueNumAnsweredCalls30sec");
    }

    [Fact]
    public void Apply_Search_MatchesFamily()
    {
        var criteria = new MetricFilterCriteria(null, null, null, null, null, "agent.duration");
        var result = MetricCatalogFilter.Apply(TestMetrics, criteria);

        result.Should().Contain(m => m.MetricId == "MonAgentTalkDuration");
    }

    [Fact]
    public void Apply_Search_CaseInsensitive()
    {
        var criteria = new MetricFilterCriteria(null, null, null, null, null, "TALK DURATION");
        var result = MetricCatalogFilter.Apply(TestMetrics, criteria);

        result.Should().Contain(m => m.MetricId == "MonAgentTalkDuration");
    }

    [Fact]
    public void Apply_Search_NoMatch_ReturnsEmpty()
    {
        var criteria = new MetricFilterCriteria(null, null, null, null, null, "NonexistentSearchTerm123");
        var result = MetricCatalogFilter.Apply(TestMetrics, criteria);

        result.Should().BeEmpty();
    }

    [Fact]
    public void Label_ReturnsDisplayName_WhenPresent()
    {
        var metric = TestMetrics.First(m => m.MetricId == "QueueNumAnsweredCalls30sec");
        var label = MetricCatalogFilter.Label(metric);

        label.Should().Be("Answered Calls in 30s");
    }

    [Fact]
    public void Label_FallsBackToDescription_WhenNoDisplayName()
    {
        var metric = TestMetrics.First(m => m.MetricId == "NoDisplayName");
        var label = MetricCatalogFilter.Label(metric);

        label.Should().Be("Has Description Only");
    }

    [Fact]
    public void Label_FallsBackToMetricId_WhenNoDisplayNameOrDescription()
    {
        var metric = TestMetrics.First(m => m.MetricId == "NoDisplayOrDesc");
        var label = MetricCatalogFilter.Label(metric);

        label.Should().Be("NoDisplayOrDesc");
    }

    [Fact]
    public void Families_ReturnsDistinctSortedFamilies()
    {
        var pool = TestMetrics.Where(m => m.CatalogStatus is null or "").ToList();
        var families = MetricCatalogFilter.Families(pool);

        families.Should().BeInAscendingOrder();
        families.Should().OnlyHaveUniqueItems();
        families.Should().Contain("agent.duration");
        families.Should().Contain("queue.volume.answered_threshold");
    }

    [Fact]
    public void Channels_ReturnsDistinctSortedChannels_NonNullOnly()
    {
        var pool = TestMetrics.Where(m => m.CatalogStatus is null or "").ToList();
        var channels = MetricCatalogFilter.Channels(pool);

        channels.Should().BeInAscendingOrder();
        channels.Should().OnlyHaveUniqueItems();
        channels.Should().Contain("calls");
        channels.Should().Contain("chats");
    }

    [Fact]
    public void Thresholds_ReturnsDistinctSortedThresholds_NonNullOnly()
    {
        var pool = TestMetrics.Where(m => m.CatalogStatus is null or "").ToList();
        var thresholds = MetricCatalogFilter.Thresholds(pool);

        thresholds.Should().BeInAscendingOrder();
        thresholds.Should().OnlyHaveUniqueItems();
        thresholds.Should().Contain(30);
        thresholds.Should().Contain(60);
    }

    [Fact]
    public void Categories_ReturnsDistinctSortedCategories()
    {
        var pool = TestMetrics.Where(m => m.CatalogStatus is null or "").ToList();
        var categories = MetricCatalogFilter.Categories(pool);

        categories.Should().BeInAscendingOrder();
        categories.Should().OnlyHaveUniqueItems();
        categories.Should().Contain("Queue");
        categories.Should().Contain("Agent");
        categories.Should().Contain("AgentGroup");
    }

    [Fact]
    public void Apply_CombinedFilters_WorkTogether()
    {
        var criteria = new MetricFilterCriteria(
            MetricType: "Data",
            Category: "Queue",
            Family: "queue.volume.answered_threshold",
            Channel: "calls",
            ThresholdSec: 30,
            Search: null);
        var result = MetricCatalogFilter.Apply(TestMetrics, criteria);

        result.Should().HaveCount(1);
        result[0].MetricId.Should().Be("QueueNumAnsweredCalls30sec");
    }
}
