using System;

namespace RTM
{
    /// <summary>
    /// PR234-SITE-TZ-FIXED-OFFSET-01: the ONE reader of a site / union / row time zone string.
    ///
    /// Before, three readers disagreed: IDInteraction.toLocal and UserManager.getLocalDateTime accepted a fixed offset
    /// (lenient TimeSpan.TryParse) or a time zone id; the nightly union clear (Engine.TryParseOffset) accepted ONLY
    /// "±hh:mm", so a zone id there meant "INVALID_OFFSET, never clear". With the site at a fixed "+02:00" the engine's day
    /// started at 01:00 local in Israeli summer time (measured on 234: clears at 22:00Z every night 12-20.10).
    ///
    /// Accepted forms, in this order:
    ///   1. "±hh:mm" (exact)                        -> that fixed offset;
    ///   2. any other TimeSpan text within ±14:00   -> that fixed offset (what toLocal always accepted, e.g. "03:00");
    ///   3. a Windows or IANA time zone id          -> the zone, with daylight saving, offset taken AT the instant.
    /// Empty or unresolvable: Offset() gives 0 (the old toLocal behaviour: "unknown => UTC"); TryOffset() gives false
    /// (the old clear behaviour: invalid => no clear, logged by the caller).
    /// </summary>
    internal static class SiteZone
    {
        private static readonly TimeSpan MaxOffset = TimeSpan.FromHours(14);

        internal static bool TryResolve(string? timeZone, out TimeZoneInfo? zone, out TimeSpan fixedOffset)
        {
            zone = null;
            fixedOffset = TimeSpan.Zero;
            if (string.IsNullOrWhiteSpace(timeZone))
                return false;

            var cleaned = timeZone.Trim();
            bool negative = cleaned.StartsWith("-");
            var stripped = cleaned.TrimStart('+').TrimStart('-');

            if (TimeSpan.TryParseExact(stripped, @"hh\:mm", null, out var exact))
            {
                fixedOffset = negative ? exact.Negate() : exact;
                return true;
            }
            if (TimeSpan.TryParse(stripped, out var lenient) && lenient.Duration() <= MaxOffset)
            {
                fixedOffset = negative ? lenient.Negate() : lenient;
                return true;
            }
            try
            {
                zone = TimeZoneInfo.FindSystemTimeZoneById(cleaned);
                return true;
            }
            catch (Exception ex) when (ex is TimeZoneNotFoundException or InvalidTimeZoneException)
            {
                return false;
            }
        }

        /// <summary>Offset of the zone at the UTC instant; false for empty / unresolvable.</summary>
        internal static bool TryOffset(string? timeZone, DateTime utc, out TimeSpan offset)
        {
            offset = TimeSpan.Zero;
            if (!TryResolve(timeZone, out var zone, out var fixedOffset))
                return false;
            offset = zone is null ? fixedOffset : zone.GetUtcOffset(DateTime.SpecifyKind(utc, DateTimeKind.Utc));
            return true;
        }

        /// <summary>Offset of the zone at the UTC instant; 0 for empty / unresolvable (toLocal's "unknown => UTC").</summary>
        internal static TimeSpan Offset(string? timeZone, DateTime utc) => TryOffset(timeZone, utc, out var o) ? o : TimeSpan.Zero;

        /// <summary>The site's local day at the UTC instant.</summary>
        internal static DateOnly LocalDay(TimeSpan offset, DateTime utc) => DateOnly.FromDateTime(DateTime.SpecifyKind(utc, DateTimeKind.Utc) + offset);

        /// <summary>
        /// The UTC instant of "clearTime on localDay" in the site's zone.
        /// Spring-forward night: a clear time that does not exist (e.g. 02:30 when 02:00 jumps to 03:00) moves forward by the gap.
        /// Fall-back night: a clear time that occurs twice is taken at its FIRST occurrence, so the clear happens once.
        /// </summary>
        internal static bool TryClearUtc(string? timeZone, DateOnly localDay, TimeSpan clearTime, out DateTime clearUtc)
        {
            clearUtc = default;
            if (!TryResolve(timeZone, out var zone, out var fixedOffset))
                return false;

            var wall = localDay.ToDateTime(TimeOnly.MinValue).Add(clearTime);
            if (zone is null)
            {
                clearUtc = DateTime.SpecifyKind(wall - fixedOffset, DateTimeKind.Utc);
                return true;
            }

            for (int i = 0; i < 8 && zone.IsInvalidTime(wall); i++)
                wall = wall.AddMinutes(30);

            if (zone.IsAmbiguousTime(wall))
            {
                var offsets = zone.GetAmbiguousTimeOffsets(wall);
                var largest = offsets[0] > offsets[1] ? offsets[0] : offsets[1];   // larger offset = earlier instant
                clearUtc = DateTime.SpecifyKind(wall - largest, DateTimeKind.Utc);
                return true;
            }

            clearUtc = TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(wall, DateTimeKind.Unspecified), zone);
            return true;
        }

        /// <summary>
        /// Should the union clear now? True inside [clear, clear + window] of today's local clear time, once per local day.
        /// The decision of Engine.isUnionClearTime, made testable (the caller owns the "already cleared today" memory).
        /// </summary>
        internal static bool IsClearDue(string? timeZone, TimeSpan clearTime, DateTime nowUtc, DateOnly? lastClearLocalDay,
                                        TimeSpan window, out DateOnly todayLocal)
        {
            todayLocal = default;
            if (!TryOffset(timeZone, nowUtc, out var offset))
                return false;
            todayLocal = LocalDay(offset, nowUtc);
            if (lastClearLocalDay == todayLocal)
                return false;
            if (!TryClearUtc(timeZone, todayLocal, clearTime, out var clearUtc))
                return false;
            var now = DateTime.SpecifyKind(nowUtc, DateTimeKind.Utc);
            return now >= clearUtc && now <= clearUtc + window;
        }

        /// <summary>Next clear instant (UTC) strictly after nowUtc; false for an unresolvable zone.</summary>
        internal static bool TryNextClearUtc(string? timeZone, TimeSpan clearTime, DateTime nowUtc, out DateTime nextUtc)
        {
            nextUtc = default;
            if (!TryOffset(timeZone, nowUtc, out var offset))
                return false;
            var now = DateTime.SpecifyKind(nowUtc, DateTimeKind.Utc);
            var day = LocalDay(offset, now);
            for (int i = 0; i < 3; i++)
            {
                if (!TryClearUtc(timeZone, day.AddDays(i), clearTime, out var c))
                    return false;
                if (c > now) { nextUtc = c; return true; }
            }
            return false;
        }
    }
}
