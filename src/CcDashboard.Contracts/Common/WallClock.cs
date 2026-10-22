namespace CcDashboard.Contracts.Common;

/// <summary>
/// BL-V4-INFOSLOT-TIME-NO-LOCAL-01: a stored instant turned into the clock time people read.
///
/// The database holds true UTC for everything the shell itself writes (InfoSlotHandlers.cs:277,408
/// stamp CreatedAt from clock.UtcNow; the editor sends ExpiresAt through ToUniversalTime,
/// InfoSlotMessages.razor:421,515), and both columns are "timestamp with time zone"
/// (migration 20260529054939_AddInfoSlotTables.cs:44,46), so Npgsql hands them back with
/// Kind=Utc. Thirteen places in the shell already print such values through ToLocalTime();
/// InfoSlotWidget printed them raw, so the same message showed one time in the management panel
/// and another - three hours off on 234 in summer - on the screen.
///
/// WHICH ZONE: the SERVER's, as in those thirteen places. This is Blazor Server, so ToLocalTime()
/// is the host's zone, not the viewer's. Showing the viewer's own zone is a different unit of work
/// and a different decision; it is deliberately not done here.
///
/// A value that is NOT marked as UTC is returned untouched. That matters: some values reach the
/// screen already local (DayTrendWidget's _lastUpdate is DateTime.Now; DayTrendQueryHandler hands
/// out interval starts already converted, with Kind=Unspecified). Shifting those would be a second,
/// opposite defect - the double conversion this class exists to avoid.
/// </summary>
public static class WallClock
{
    /// <summary>A stored instant as the server's wall clock; a value not marked UTC is left as it is.</summary>
    public static DateTime ToServerLocal(DateTime stored)
        => stored.Kind == DateTimeKind.Utc ? stored.ToLocalTime() : stored;

    /// <summary>The "HH:mm" people read, converted first.</summary>
    public static string HourMinute(DateTime stored) => ToServerLocal(stored).ToString("HH:mm");
}
