using Microsoft.AspNetCore.Components;

namespace CcDashboard.Web.Services;

/// <summary>
/// One modal window for the report screens, drawn by ONE host at page level (ReportModalHost), outside the scaled design
/// layer of the viewer. FEAT-REPORT-FILTER-MODAL-01 (operator 2026-11-07 16:22: "делаем модалку").
///
/// Why not inside the widget: the viewer scales its board with transform: scale(...), and position: fixed inside a
/// transformed ancestor is fixed to that ancestor, not to the screen. Measured on 234 on 2026-11-07: the step window
/// opened inside a widget darkened only the board, and the date bar above stayed bright and clickable. A filter window
/// inside the widget was clipped by the widget instead. One host outside the layer removes both.
///
/// A widget (or a column funnel) asks for the window with a title and a body; it keeps ownership of its state and is
/// told when the person dismisses the window (Esc, background, the close button). One window at a time: opening another
/// one dismisses the first.
/// </summary>
public sealed class ReportModalService
{
    public object? Owner { get; private set; }
    /// <summary>What the owner belongs to (a widget's filter state): owners of one group replace each other quietly.</summary>
    private object? _group;
    public string? Title { get; private set; }
    public RenderFragment? Body { get; private set; }
    public RenderFragment? Footer { get; private set; }
    private Func<Task>? _onDismiss;

    /// <summary>Raised whenever the window opens, closes or its content changes; the host re-renders.</summary>
    public event Action? Changed;

    public bool IsOpenFor(object owner) => ReferenceEquals(Owner, owner);

    /// <summary>Opens the window for <paramref name="owner"/>, or refreshes it when the owner already has it.</summary>
    /// <param name="group">
    /// What the owner belongs to. Two funnels of ONE widget are one group: switching between them replaces the window
    /// quietly (the widget already moved its open column), because telling the old funnel "you closed" would make the
    /// widget close its filter state - the new column with it. A window of another group is dismissed, so its owner
    /// learns it closed.
    /// </param>
    public async Task ShowAsync(object owner, object? group, string title, RenderFragment body, Func<Task> onDismiss, RenderFragment? footer = null)
    {
        if (Owner is not null && !ReferenceEquals(Owner, owner)
            && (group is null || !ReferenceEquals(_group, group)))
            await DismissAsync();   // one window at a time: another widget's window is told it closed
        Owner = owner;
        _group = group;
        Title = title;
        Body = body;
        Footer = footer;
        _onDismiss = onDismiss;
        Changed?.Invoke();
    }

    /// <summary>Re-draws the open window (its owner's state changed). No-op for anyone else.</summary>
    public void Refresh(object owner)
    {
        if (ReferenceEquals(Owner, owner)) Changed?.Invoke();
    }

    /// <summary>Closes the window without telling the owner (the owner closed it itself).</summary>
    public void Hide(object owner)
    {
        if (!ReferenceEquals(Owner, owner)) return;
        Clear();
    }

    /// <summary>The person dismissed the window: the owner is told, then it closes.</summary>
    public async Task DismissAsync()
    {
        var onDismiss = _onDismiss;
        Clear();
        if (onDismiss is not null) await onDismiss();
    }

    private void Clear()
    {
        Owner = null;
        _group = null;
        Title = null;
        Body = null;
        Footer = null;
        _onDismiss = null;
        Changed?.Invoke();
    }
}
