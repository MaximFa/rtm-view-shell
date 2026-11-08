namespace CcDashboard.Web.Components.ReportWidgets;

/// <summary>One widget's rectangle on the report canvas, in canvas pixels.</summary>
public readonly record struct CanvasRect(int X, int Y, int Width, int Height)
{
    public int Right => X + Width;
    public int Bottom => Y + Height;

    /// <summary>True when the two rectangles share area. Touching edges is NOT an overlap.</summary>
    public bool Overlaps(CanvasRect other)
        => X < other.Right && other.X < Right && Y < other.Bottom && other.Y < Bottom;
}

/// <summary>
/// PR234-V4-REPORT-EDITOR-WIDGET-OVERLAP-STUCK-01: widgets on the report canvas never overlap. A widget dropped onto
/// another one used to slide UNDER the neighbour's sticky table header, where its own drag handle could no longer be
/// grabbed - "it cannot be moved". The rule is here, in one place, so it can be tested; the page applies it on move
/// and resize. A NEW widget is not held to it (operator 2026-11-08 11:57): it lands exactly where the mouse was let go.
/// The dashboards' canvas is not touched (coordinator 2026-11-07T15:05:51Z).
/// </summary>
public static class ReportCanvasLayout
{
    /// <summary>The grid the canvas snaps to (widget-resize.js snaps to 10 px).</summary>
    public const int Grid = 10;

    /// <summary>True when <paramref name="rect"/> overlaps any of <paramref name="others"/>.</summary>
    public static bool OverlapsAny(CanvasRect rect, IEnumerable<CanvasRect> others)
        => others.Any(o => o.Overlaps(rect));

    /// <summary>
    /// The ONE place that says which corner of a new widget sits at the point where the mouse was let go: the top-left
    /// corner, as in the dashboard editor (coordinator 2026-11-08T09:02:21Z; the operator was asked about RTL and did not
    /// change it). To anchor the top-right corner instead, this is the one line to change: X = x - width.
    /// </summary>
    public static CanvasRect AnchoredAt(int x, int y, int width, int height) => new(x, y, width, height);
}
