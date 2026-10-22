using RTM.Tools;
using System;

namespace RTM
{
    /// <summary>
    /// BL-234-INTERACTION-TIME-AHEAD-01: the ONE place where engine time meets the database.
    ///
    /// Inside, the engine keeps working in "site local" wall-clock time (IDInteraction.toLocal /
    /// UserManager.getLocalDateTime: UTC + offset of the row's TimeZone) - it needs that for its day,
    /// OnDate and the daily clear, and none of that changes here. Before this class, DBMng stamped those local
    /// values with DateTimeKind.Utc into timestamptz columns, so every row was stored ahead by the site offset
    /// (+2h on 234), and times arriving from the adapter in the machine's zone were stored ahead by the
    /// machine offset (+3h in Israeli summer time). Every reader outside the engine saw shifted times.
    ///
    /// Now: write = true UTC; read back (engine restart) = convert UTC back to the same site-local value.
    /// Offset rules are byte-for-byte those of IDInteraction.toLocal: empty zone => 0; "+02:00"/"-05:00"/"03:00"
    /// => that fixed offset; otherwise a Windows/IANA id; anything unparseable => 0.
    /// Sentinels (InQueueDateTime = SqlDateTime.MaxValue, AnsweredDateTime = SqlDateTime.MinValue) are passed
    /// through untouched both ways, so "not queued / not answered" keeps meaning the same.
    /// </summary>
    internal static class DbTime
    {
        /// <summary>Year 9999 (SqlDateTime.MaxValue, also after a lossy text round trip) or year &lt;= 1753 (SqlDateTime.MinValue, DateTime.MinValue).</summary>
        internal static bool IsSentinel(DateTime t) => t.Year >= 9999 || t.Year <= 1753;

        /// <summary>Offset the engine adds to UTC for this zone at instant <paramref name="utc"/> (same rules as IDInteraction.toLocal).</summary>
        internal static TimeSpan SiteOffset(string? timeZone, DateTime utc)
        {
            if (string.IsNullOrWhiteSpace(timeZone))
                return TimeSpan.Zero;
            try
            {
                string cleaned = timeZone.Trim();
                bool negative = cleaned.StartsWith("-");
                string stripped = cleaned.TrimStart('+').TrimStart('-');
                if (TimeSpan.TryParse(stripped, out var offset))
                    return negative ? offset.Negate() : offset;

                var tzi = TimeZoneInfo.FindSystemTimeZoneById(timeZone);
                return tzi.GetUtcOffset(DateTime.SpecifyKind(utc, DateTimeKind.Utc));
            }
            catch
            {
                return TimeSpan.Zero;
            }
        }

        /// <summary>
        /// Site-local value stamped by the engine -> true UTC (Kind=Utc) for a timestamptz parameter.
        /// Exact inverse of local = utc + SiteOffset(zone, utc); for a DST zone it solves the fixed point in two steps.
        /// </summary>
        internal static DateTime EngineLocalToUtc(DateTime local, string? timeZone)
        {
            if (IsSentinel(local))
                return DateTime.SpecifyKind(local, DateTimeKind.Utc);

            var guess = local - SiteOffset(timeZone, local);           // first approximation
            var utc = local - SiteOffset(timeZone, guess);             // offset taken at the (approximate) true instant
            if (utc + SiteOffset(timeZone, utc) != local)              // DST edge: one more step settles it
                utc = local - SiteOffset(timeZone, utc);
            return DateTime.SpecifyKind(utc, DateTimeKind.Utc);
        }

        /// <summary>
        /// Interaction stamp for the DB: a value that is already a UTC instant (Kind=Utc, captured at stamping - see
        /// IDInteraction.InQueueUtc/AnsweredUtc) goes as is; otherwise it is a site-local stamp and is converted with the zone.
        /// </summary>
        internal static DateTime ToDbUtc(DateTime value, string? timeZone)
            => value.Kind == DateTimeKind.Utc && !IsSentinel(value) ? value : EngineLocalToUtc(value, timeZone);

        /// <summary>UTC wall value read back from the database (timestamp ... AT TIME ZONE 'UTC') -> the engine's site-local value.</summary>
        internal static DateTime UtcToEngineLocal(DateTime utcWall, string? timeZone)
        {
            if (IsSentinel(utcWall))
                return utcWall;
            var utc = DateTime.SpecifyKind(utcWall, DateTimeKind.Utc);
            return DateTime.SpecifyKind(utc + SiteOffset(timeZone, utc), DateTimeKind.Unspecified);
        }

        /// <summary>
        /// A time that came from OUTSIDE the engine (adapter payload, e.g. Agent.StatusChanged, chat time stamps)
        /// -> true UTC, decided by its Kind: Utc as is; Local converted; Unspecified is ambiguous - it is taken
        /// as the machine's local time (what the deserializer produces for an offset-carrying string) and logged once
        /// per process so the assumption is visible.
        /// </summary>
        internal static DateTime ExternalToUtc(DateTime t)
        {
            if (IsSentinel(t))
                return DateTime.SpecifyKind(t, DateTimeKind.Utc);
            switch (t.Kind)
            {
                case DateTimeKind.Utc:
                    return t;
                case DateTimeKind.Local:
                    return t.ToUniversalTime();
                default:
                    if (!_unspecifiedLogged)
                    {
                        _unspecifiedLogged = true;
                        AsyncLogger.Info("DbTime: an external time arrived with DateTimeKind.Unspecified; treated as machine local time " +
                                         $"({TimeZoneInfo.Local.Id}). Example value={t:O}");
                    }
                    return DateTime.SpecifyKind(t, DateTimeKind.Local).ToUniversalTime();
            }
        }

        private static volatile bool _unspecifiedLogged;
    }
}
