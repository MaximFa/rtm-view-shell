using CcDashboard.Application.DTOs;
using CcDashboard.Application.Interfaces;

namespace CcDashboard.Application.Services;

public class WidgetCatalogService : IWidgetCatalogService
{
    // TODO: widget-library — replace with real catalogue loaded from widget library package
    private static readonly IReadOnlyList<WidgetCategoryDto> Categories = new[]
    {
        new WidgetCategoryDto("queues",  "Queues",  "Real-time queue monitoring widgets"),
        new WidgetCategoryDto("agents",  "Agents",  "Agent performance and status widgets"),
        new WidgetCategoryDto("skills",  "Skills",  "Skill-based routing widgets"),
        new WidgetCategoryDto("reports", "Reports", "Summary and historical report widgets"),
    };

    private static readonly IReadOnlyList<WidgetTypeDto> Types = new[]
    {
        new WidgetTypeDto("queue-summary",    "queues",  "Queue Summary",    "Shows calls waiting, handling time, and SLA"),
        new WidgetTypeDto("queue-chart",      "queues",  "Queue Trend Chart","Historical queue depth line chart"),
        new WidgetTypeDto("agent-grid",       "agents",  "Agent Grid",       "Live grid of agent states"),
        new WidgetTypeDto("agent-scorecard",  "agents",  "Agent Scorecard",  "Individual agent KPI card"),
        new WidgetTypeDto("skill-heatmap",    "skills",  "Skill Heatmap",    "Availability heatmap by skill"),
        new WidgetTypeDto("report-table",     "reports", "Report Table",     "Tabular summary report"),
    };

    public Task<IReadOnlyList<WidgetCategoryDto>> GetCategoriesAsync(CancellationToken ct = default)
        => Task.FromResult(Categories);

    public Task<IReadOnlyList<WidgetTypeDto>> GetTypesInCategoryAsync(string categoryId, CancellationToken ct = default)
    {
        IReadOnlyList<WidgetTypeDto> result = Types
            .Where(t => t.CategoryId == categoryId)
            .ToList();
        return Task.FromResult(result);
    }

    public Task<WidgetTypeDto?> GetTypeByIdAsync(string categoryId, string typeId, CancellationToken ct = default)
    {
        var result = Types.FirstOrDefault(t => t.CategoryId == categoryId && t.TypeId == typeId);
        return Task.FromResult(result);
    }
}
