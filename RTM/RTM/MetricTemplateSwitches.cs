namespace RTM
{
    // [SYNC-PORT 2026-10-15 src=2026-08-06] The only configuration surface visible to runtime-compiled metric templates.
    // Read-only and secret-free: it forwards the de-dup switch so templates never need a reference to RTM.Configuration.
    public static class MetricTemplateSwitches
    {
        public static bool SegmentDedupEnabled => RTM.Configuration.AppConfig.SegmentDedupEnabled;
    }
}
