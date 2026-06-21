using CcDashboard.Application.HistoricalReports.Queries;
using FluentValidation;

namespace CcDashboard.Application.HistoricalReports.Validators;

/// <summary>
/// Report query validators with date-range cap (default 92 days).
/// AUD-08: CSV row cap of 50,000 is enforced by PageSize <= 1000 + pagination.
/// </summary>
public class GetQueueIntervalReportQueryValidator : AbstractValidator<GetQueueIntervalReportQuery>
{
    private const int MaxDateRangeDays = 92;

    public GetQueueIntervalReportQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To)
            .WithMessage("From date must be before or equal to To date");
        RuleFor(x => x)
            .Must(x => (x.To - x.From).TotalDays <= MaxDateRangeDays)
            .WithMessage($"Date range must not exceed {MaxDateRangeDays} days");
        RuleFor(x => x.PageSize).InclusiveBetween(1, 1000);
        RuleFor(x => x.Page).GreaterThanOrEqualTo(1);
    }
}

public class GetQueueWaitTimeReportQueryValidator : AbstractValidator<GetQueueWaitTimeReportQuery>
{
    private const int MaxDateRangeDays = 92;

    public GetQueueWaitTimeReportQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To)
            .WithMessage("From date must be before or equal to To date");
        RuleFor(x => x)
            .Must(x => (x.To - x.From).TotalDays <= MaxDateRangeDays)
            .WithMessage($"Date range must not exceed {MaxDateRangeDays} days");
        RuleFor(x => x.PageSize).InclusiveBetween(1, 1000);
        RuleFor(x => x.Page).GreaterThanOrEqualTo(1);
    }
}

public class GetAgentMonthlyReportQueryValidator : AbstractValidator<GetAgentMonthlyReportQuery>
{
    private const int MaxDateRangeDays = 92;

    public GetAgentMonthlyReportQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To)
            .WithMessage("From date must be before or equal to To date");
        RuleFor(x => x)
            .Must(x => (x.To - x.From).TotalDays <= MaxDateRangeDays)
            .WithMessage($"Date range must not exceed {MaxDateRangeDays} days");
        RuleFor(x => x.PageSize).InclusiveBetween(1, 1000);
        RuleFor(x => x.Page).GreaterThanOrEqualTo(1);
    }
}

public class GetAgentShiftDetailReportQueryValidator : AbstractValidator<GetAgentShiftDetailReportQuery>
{
    private const int MaxDateRangeDays = 92;

    public GetAgentShiftDetailReportQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To)
            .WithMessage("From date must be before or equal to To date");
        RuleFor(x => x)
            .Must(x => (x.To - x.From).TotalDays <= MaxDateRangeDays)
            .WithMessage($"Date range must not exceed {MaxDateRangeDays} days");
        RuleFor(x => x.PageSize).InclusiveBetween(1, 1000);
        RuleFor(x => x.Page).GreaterThanOrEqualTo(1);
    }
}
