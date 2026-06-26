using CcDashboard.Domain.Domain.Reports;
using FluentValidation;

namespace CcDashboard.Application.HistoricalReports.Validators;

/// <summary>
/// ConfigJson validation per Reports-Backend-v1-Spec §2.
/// Invalid ConfigJson -> ValidationException -> 400 to client.
/// BU-ONLY scope (operator decision 2026-06-26).
/// </summary>
public class ReportWidgetConfigValidator : AbstractValidator<ReportWidgetConfig>
{
    private static readonly HashSet<int> ValidIntervals = new() { 30, 60 };
    private static readonly HashSet<int> ValidPageSizes = new() { 25, 50, 100 };

    public ReportWidgetConfigValidator()
    {
        RuleFor(x => x.Title)
            .MaximumLength(200)
            .When(x => x.Title != null);

        RuleFor(x => x.Scope)
            .NotNull()
            .WithMessage("Scope is required");

        RuleFor(x => x.Scope.BusinessUnitIds)
            .NotEmpty()
            .WithMessage("BusinessUnitIds required (scope is BU-only)");

        // Columns are OPTIONAL in v1 — server supplies DefaultColumns per WidgetType when null/empty.
        // Full Columns picker deferred to v1.1.

        RuleFor(x => x.Interval)
            .Must(i => !i.HasValue || ValidIntervals.Contains(i.Value))
            .WithMessage("Interval must be 30 or 60");

        RuleFor(x => x.PageSize)
            .Must(ValidPageSizes.Contains)
            .WithMessage("PageSize must be 25, 50, or 100");
    }
}

/// <summary>
/// Context-aware validator: validates AgentAxis requirement based on widget type.
/// BU-ONLY scope (operator decision 2026-06-26).
/// </summary>
public class ReportWidgetConfigWithTypeValidator : AbstractValidator<(ReportWidgetConfig Config, ReportWidgetType WidgetType)>
{
    private static readonly HashSet<ReportWidgetType> AgentWidgetTypes = new()
    {
        ReportWidgetType.AgentMonthly,
        ReportWidgetType.AgentShiftDetail
    };

    public ReportWidgetConfigWithTypeValidator()
    {
        RuleFor(x => x.Config).SetValidator(new ReportWidgetConfigValidator());

        RuleFor(x => x)
            .Must(x => !IsAgentWidget(x.WidgetType) || x.Config.Scope.AgentAxis.HasValue)
            .WithMessage("AgentAxis required for agent widgets");
    }

    private static bool IsAgentWidget(ReportWidgetType type) => AgentWidgetTypes.Contains(type);
}
