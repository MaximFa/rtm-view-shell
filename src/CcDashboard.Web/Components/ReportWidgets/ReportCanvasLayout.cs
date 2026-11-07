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
/// grabbed - "it cannot be moved". The rule is here, in one place, so it can be tested; the page applies it on drop,
/// move and resize. The dashboards' canvas is not touched (coordinator 2026-11-07T15:05:51Z).
/// </summary>
public static class ReportCanvasLayout
{
    /// <summary>The grid the canvas snaps to (widget-resize.js snaps to 10 px).</summary>
    public const int Grid = 10;

    /// <summary>True when <paramref name="rect"/> overlaps any of <paramref name="others"/>.</summary>
    public static bool OverlapsAny(CanvasRect rect, IEnumerable<CanvasRect> others)
        => others.Any(o => o.Overlaps(rect));

    /// <summary>
    /// Where a new widget goes: where it was dropped, or - when that place is taken - straight below the lowest widget
    /// it would cover, repeated until it covers none. Always ends: every step moves it below a widget, and there are
    /// finitely many. Never above or left of the drop point, so it stays near where the person let go.
    /// </summary>
    public static CanvasRect PlaceFree(CanvasRect wanted, IReadOnlyCollection<CanvasRect> others)
    {
        var rect = wanted with { X = Math.Max(0, wanted.X), Y = Math.Max(0, wanted.Y) };
        while (true)
        {
            var hit = others.Where(o => o.Overlaps(rect)).ToList();
            if (hit.Count == 0) return rect;
            rect = rect with { Y = Snap(hit.Max(o => o.Bottom) + Grid) };
        }
    }

    private static int Snap(int v) => (int)Math.Ceiling(v / (double)Grid) * Grid;
}
