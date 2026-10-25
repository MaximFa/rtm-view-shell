namespace RTM.Tools
{
    /// <summary>
    /// ADAPTER-SEED-STATUS-MOMENT-01: the start-up seed (setUsersStatusList) must carry the moment the worker really
    /// entered its current activity (Twilio worker.DateStatusChanged), not the adapter's "now" - otherwise every agent's
    /// time-in-status restarts at the adapter start. The engine counts status time in machine-local wall time
    /// (live events are stamped DateTime.Now), so the Twilio value (UTC) is converted to machine local, Kind=Local.
    /// Fallback to nowLocal (the previous behaviour) when Twilio gives no value or a value ahead of the local clock.
    /// </summary>
    public static class SeedTime
    {
        public static DateTime ToEngineLocal(DateTime? twilioValue, DateTime nowLocal, out bool fallback)
        {
            if (twilioValue is null || twilioValue.Value == default || twilioValue.Value == DateTime.MinValue)
            {
                fallback = true;
                return nowLocal;
            }

            var v = twilioValue.Value;
            // Twilio sends ISO-8601 UTC; an Unspecified value is read as UTC, a Local one is already converted.
            var utc = v.Kind switch
            {
                DateTimeKind.Utc => v,
                DateTimeKind.Local => v.ToUniversalTime(),
                _ => DateTime.SpecifyKind(v, DateTimeKind.Utc)
            };
            var local = utc.ToLocalTime();

            if (local > nowLocal)
            {
                // clock skew between Twilio and this machine: never seed a status that starts in the future
                fallback = true;
                return nowLocal;
            }

            fallback = false;
            return local;
        }
    }
}
