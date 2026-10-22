namespace CcDashboard.Application.Interfaces;

/// <summary>
/// The zone in which people read times of day, intervals and days (BL-234-INTERACTION-TIME-AHEAD-01).
/// The database holds true UTC; everything shown as a clock time / interval / day is converted with THIS zone,
/// which follows daylight saving (e.g. Israel Standard Time: +02:00 winter, +03:00 summer).
/// Not the site's fixed offset (NGC_Site.TimeZone "+02:00" has no DST - BL-234-SITE-TZ-FIXED-NO-DST-01).
/// </summary>
public interface IDisplayTimeZone
{
    TimeZoneInfo Zone { get; }
}

public static class DisplayTimeZoneExtensions
{
    /// <summary>A UTC instant from the database -> the wall-clock time people read (Kind=Unspecified).</summary>
    public static DateTime ToDisplay(this TimeZoneInfo zone, DateTime utc)
    {
        if (utc.Year <= 1 || utc.Year >= 9999) return utc;
        var u = utc.Kind == DateTimeKind.Local ? utc.ToUniversalTime() : DateTime.SpecifyKind(utc, DateTimeKind.Utc);
        return TimeZoneInfo.ConvertTimeFromUtc(u, zone);
    }

    /// <summary>
    /// A wall-clock value a person picked (a report date, a day boundary) -> the UTC instant to compare with the database.
    /// The Kind of the input is ignored: a picked date is always a wall-clock value in the display zone.
    /// A wall time that does not exist (spring-forward gap) is moved forward by the gap.
    /// </summary>
    public static DateTime WallToUtc(this TimeZoneInfo zone, DateTime wall)
    {
        if (wall.Year <= 1 || wall.Year >= 9999) return DateTime.SpecifyKind(wall, DateTimeKind.Utc);
        var w = DateTime.SpecifyKind(wall, DateTimeKind.Unspecified);
        if (zone.IsInvalidTime(w)) w = w.AddHours(1);
        return TimeZoneInfo.ConvertTimeToUtc(w, zone);
    }

    /// <summary>Today's date as people in the display zone see it.</summary>
    public static DateOnly Today(this TimeZoneInfo zone, DateTime utcNow) => DateOnly.FromDateTime(zone.ToDisplay(utcNow));
}
