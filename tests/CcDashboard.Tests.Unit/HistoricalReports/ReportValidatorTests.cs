using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Application.HistoricalReports.Validators;
using FluentAssertions;

namespace CcDashboard.Tests.Unit.HistoricalReports;

public class ReportValidatorTests
{
    [Fact]
    public void QueueIntervalValidator_RejectsInvalidDateRange()
    {
        var validator = new GetQueueIntervalReportQueryValidator();
        var query = new GetQueueIntervalReportQuery(
            DateTime.UtcNow,
            DateTime.UtcNow.AddDays(-1));

        var result = validator.Validate(query);

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.ErrorMessage.Contains("From date"));
    }

    [Fact]
    public void QueueIntervalValidator_AcceptsValidDateRange()
    {
        var validator = new GetQueueIntervalReportQueryValidator();
        var query = new GetQueueIntervalReportQuery(
            DateTime.UtcNow.AddDays(-7),
            DateTime.UtcNow);

        var result = validator.Validate(query);

        result.IsValid.Should().BeTrue();
    }

    [Fact]
    public void QueueIntervalValidator_RejectsInvalidPageSize()
    {
        var validator = new GetQueueIntervalReportQueryValidator();
        var query = new GetQueueIntervalReportQuery(
            DateTime.UtcNow.AddDays(-1),
            DateTime.UtcNow,
            PageSize: 10000);

        var result = validator.Validate(query);

        result.IsValid.Should().BeFalse();
    }

    [Fact]
    public void AgentMonthlyValidator_RejectsInvalidPage()
    {
        var validator = new GetAgentMonthlyReportQueryValidator();
        var query = new GetAgentMonthlyReportQuery(
            DateTime.UtcNow.AddDays(-30),
            DateTime.UtcNow,
            Page: 0);

        var result = validator.Validate(query);

        result.IsValid.Should().BeFalse();
    }

    [Fact]
    public void AllValidators_AcceptSameDateForFromAndTo()
    {
        var date = DateTime.UtcNow;

        var queueValidator = new GetQueueIntervalReportQueryValidator();
        var agentValidator = new GetAgentMonthlyReportQueryValidator();

        queueValidator.Validate(new GetQueueIntervalReportQuery(date, date)).IsValid.Should().BeTrue();
        agentValidator.Validate(new GetAgentMonthlyReportQuery(date, date)).IsValid.Should().BeTrue();
    }

    [Fact]
    public void QueueIntervalValidator_RejectsDateRangeOverCap()
    {
        var validator = new GetQueueIntervalReportQueryValidator();
        var query = new GetQueueIntervalReportQuery(
            DateTime.UtcNow.AddDays(-100),
            DateTime.UtcNow);

        var result = validator.Validate(query);

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.ErrorMessage.Contains("92 days"));
    }

    [Fact]
    public void QueueIntervalValidator_AcceptsDateRangeWithinCap()
    {
        var validator = new GetQueueIntervalReportQueryValidator();
        var query = new GetQueueIntervalReportQuery(
            DateTime.UtcNow.AddDays(-90),
            DateTime.UtcNow);

        var result = validator.Validate(query);

        result.IsValid.Should().BeTrue();
    }

    [Fact]
    public void AgentMonthlyValidator_RejectsDateRangeOverCap()
    {
        var validator = new GetAgentMonthlyReportQueryValidator();
        var query = new GetAgentMonthlyReportQuery(
            DateTime.UtcNow.AddDays(-100),
            DateTime.UtcNow);

        var result = validator.Validate(query);

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.ErrorMessage.Contains("92 days"));
    }
}
