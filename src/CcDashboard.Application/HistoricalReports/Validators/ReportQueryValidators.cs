using CcDashboard.Application.HistoricalReports.Queries;
using FluentValidation;

namespace CcDashboard.Application.HistoricalReports.Validators;

public class GetQueueIntervalReportQueryValidator : AbstractValidator<GetQueueIntervalReportQuery>
{
    public GetQueueIntervalReportQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To)
            .WithMessage("From date must be before or equal to To date");
        RuleFor(x => x.PageSize).InclusiveBetween(1, 1000);
        RuleFor(x => x.Page).GreaterThanOrEqualTo(1);
    }
}

public class GetQueueWaitTimeReportQueryValidator : AbstractValidator<GetQueueWaitTimeReportQuery>
{
    public GetQueueWaitTimeReportQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To)
            .WithMessage("From date must be before or equal to To date");
        RuleFor(x => x.PageSize).InclusiveBetween(1, 1000);
        RuleFor(x => x.Page).GreaterThanOrEqualTo(1);
    }
}

public class GetAgentMonthlyReportQueryValidator : AbstractValidator<GetAgentMonthlyReportQuery>
{
    public GetAgentMonthlyReportQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To)
            .WithMessage("From date must be before or equal to To date");
        RuleFor(x => x.PageSize).InclusiveBetween(1, 1000);
        RuleFor(x => x.Page).GreaterThanOrEqualTo(1);
    }
}

public class GetAgentShiftDetailReportQueryValidator : AbstractValidator<GetAgentShiftDetailReportQuery>
{
    public GetAgentShiftDetailReportQueryValidator()
    {
        RuleFor(x => x.From).LessThanOrEqualTo(x => x.To)
            .WithMessage("From date must be before or equal to To date");
        RuleFor(x => x.PageSize).InclusiveBetween(1, 1000);
        RuleFor(x => x.Page).GreaterThanOrEqualTo(1);
    }
}
