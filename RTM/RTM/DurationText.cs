namespace RTM
{
    // [SYNC-PORT 2026-10-16 src=2026-08-25] Day-wrap fix: the TimeSpan "hh" specifier is hours NOT counted in days (0-23), so a
    // 47:52:16 duration rendered as 23:52:16. WholeHours emits Days*24+Hours instead; identical below 24 h.
    // Used by engine C# code and by the runtime-compiled metric templates (RTM assembly is in their reference set).
    public static class DurationText
    {
        public static string WholeHours(TimeSpan ts) => Math.Abs(ts.Days * 24 + ts.Hours).ToString("00") + ts.ToString(@"\:mm\:ss");
    }
}
