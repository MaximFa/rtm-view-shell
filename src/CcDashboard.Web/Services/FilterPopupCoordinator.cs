namespace CcDashboard.Web.Services;

/// <summary>
/// Holds "which filter popup is open" above the widget level. Scoped = one instance per Blazor
/// circuit, that is, per browser tab of one user.
/// </summary>
public interface IFilterPopupCoordinator
{
    event Action<object>? PopupOpened;
    void NotifyOpened(object owner);
}

public sealed class FilterPopupCoordinator : IFilterPopupCoordinator
{
    public event Action<object>? PopupOpened;
    public void NotifyOpened(object owner) => PopupOpened?.Invoke(owner);
}
