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
    /// The ONE place that says which corner of a new widget sits at the point where the mouse was let go: the top-left
    /// corner, as in the dashboard editor (coordinator 2026-11-08T09:02:21Z; the operator was asked about RTL and did not
    /// change it). To anchor the top-right corner instead, this is the one line to change: X = x - width.
    /// </summary>
    public static CanvasRect AnchoredAt(int x, int y, int width, int height) => new(x, y, width, height);

    /// <summary>
    /// PR234-V4-REPORT-EDITOR-NEW-WIDGET-POSITION-01 (operator 2026-11-08 10:50 / 11:02: "it just flies down, and the
    /// mouse stays where it was"): where a new widget goes - the free place NEAREST to where it was dropped, on the
    /// 10 px grid, inside the canvas width. Measured on 234 (ba72973) with the rule this replaces ("straight below the
    /// lowest widget it would cover"): 3 drops of 4 landed at y=940, below the visible edge of the canvas (878), while
    /// a free place was 100-200 px away. Ties: the smaller vertical move, then the smaller horizontal one.
    /// Always finds a place: below the lowest widget everything is free.
    /// </summary>
    public static CanvasRect NearestFree(CanvasRect wanted, IReadOnlyCollection<CanvasRect> others, int canvasWidth)
    {
        var maxX = Math.Max(0, Floor(canvasWidth - wanted.Width));
        var start = wanted with
        {
            X = Math.Clamp(Snap(wanted.X), 0, maxX),
            Y = Math.Max(0, Snap(wanted.Y))
        };
        if (!OverlapsAny(start, others)) return start;

        // Below the lowest widget (and below the drop point) nothing is taken: the search never needs to go further.
        var maxY = Snap(Math.Max(start.Y, others.Count == 0 ? 0 : others.Max(o => o.Bottom)));
        CanvasRect? best = null;
        long bestD = long.MaxValue;
        for (var y = 0; y <= maxY; y += Grid)
        {
            long dy = y - start.Y;
            for (var x = 0; x <= maxX; x += Grid)
            {
                long dx = x - start.X;
                var d = dx * dx + dy * dy;
                if (d > bestD) continue;
                var candidate = start with { X = x, Y = y };
                if (OverlapsAny(candidate, others)) continue;
                if (d < bestD || best is null || IsCloser(candidate, best.Value, start))
                {
                    best = candidate;
                    bestD = d;
                }
            }
        }
        return best ?? start with { Y = maxY };
    }

    private static bool IsCloser(CanvasRect a, CanvasRect b, CanvasRect to)
    {
        var ay = Math.Abs(a.Y - to.Y); var by = Math.Abs(b.Y - to.Y);
        return ay != by ? ay < by : Math.Abs(a.X - to.X) < Math.Abs(b.X - to.X);
    }

    private static int Snap(int v) => (int)Math.Round(v / (double)Grid, MidpointRounding.AwayFromZero) * Grid;

    private static int Floor(int v) => (int)Math.Floor(v / (double)Grid) * Grid;
}
