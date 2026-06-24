using CcDashboard.Domain.Domain.Reports;

namespace CcDashboard.Application.Reports.Interfaces;

public interface IReportScreenRepository
{
    Task<ReportScreen?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<ReportScreen?> GetByIdWithWidgetsAsync(Guid id, CancellationToken ct = default);

    Task<(IReadOnlyList<ReportScreen> Items, int Total)> GetPageAsync(
        Guid tenantId,
        string? search,
        Guid? categoryId,
        ReportScreenStatus? status,
        bool? isPublic,
        Guid userId,
        Guid? pgId,
        bool isSuperadmin,
        int page,
        int pageSize,
        CancellationToken ct = default);

    Task<IReadOnlyList<ReportCategory>> GetCategoriesAsync(Guid tenantId, CancellationToken ct = default);

    Task<int> GetUserAccessLevelAsync(Guid reportScreenId, Guid? pgId, bool isPublic, bool isSuperadmin, CancellationToken ct = default);

    Task AddAsync(ReportScreen screen, CancellationToken ct = default);
    void Update(ReportScreen screen);
    void UpdateWidget(ReportWidget widget);
    Task AddWidgetAsync(ReportWidget widget, CancellationToken ct = default);
}
