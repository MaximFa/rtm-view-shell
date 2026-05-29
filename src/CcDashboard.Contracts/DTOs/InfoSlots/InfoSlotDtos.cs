namespace CcDashboard.Contracts.DTOs.InfoSlots;

public record InfoSlotListDto(
    Guid Id,
    string Name,
    string? Description,
    string DisplayMode,
    int SecondsPerMessage,
    bool IsActive,
    int ActiveMessageCount,
    int AssignedPgCount,
    List<Guid> PermissionGroupIds);

public record InfoSlotViewerDto(
    Guid Id,
    string Name,
    string DisplayMode,
    int SecondsPerMessage,
    int ActiveMessageCount,
    List<string> DashboardNames,
    List<InfoSlotMessageDto> ActiveMessages);

public record InfoSlotMessageDto(
    Guid Id,
    Guid InfoSlotId,
    string Content,
    string Priority,
    DateTime? ExpiresAt,
    string AuthorName,
    DateTime CreatedAt);

public record InfoSlotSummaryDto(Guid Id, string Name, string DisplayMode);

public record InfoSlotWidgetConfig
{
    public Guid? InfoSlotId { get; init; }
    public string DisplayName { get; init; } = "";
    public string ScrollDirection { get; init; } = "LeftToRight";
    public string ScrollSpeed { get; init; } = "Medium";
    public int FontSize { get; init; } = 14;
    public int SecondsPerMessage { get; init; } = 10;
    public string BackgroundColor { get; init; } = "auto";
    public string TextColor { get; init; } = "auto";
    public string PriorityHighBackgroundColor { get; init; } = "auto";
    public string PriorityHighTextColor { get; init; } = "auto";
    public bool ShowAuthor { get; init; } = true;
    public bool ShowTimestamp { get; init; } = true;
    public string EmptyStateMessage { get; init; } = "";
    public int MaxMessagesVisible { get; init; } = 0;
}