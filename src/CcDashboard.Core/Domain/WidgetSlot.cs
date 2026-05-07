namespace CcDashboard.Core.Domain;

public class WidgetSlot
{
    public Guid Id { get; set; }
    public Guid ScreenId { get; set; }
    public Screen Screen { get; set; } = null!;
    public string CategoryId { get; set; } = string.Empty;
    public string WidgetTypeId { get; set; } = string.Empty;
    // TODO: widget-library
}
