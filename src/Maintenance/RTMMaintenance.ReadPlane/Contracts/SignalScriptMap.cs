using System.Collections.Frozen;

namespace RTMMaintenance.ReadPlane.Contracts;

/// <summary>
/// SF-MS-003: Compile-time immutable mapping SignalType → script identifier.
/// This is the ONLY sanctioned path from enum value to script execution.
///
/// ANTI-RCE GUARANTEE:
/// - Static, readonly, no runtime mutation, no reflection-built keys
/// - Each enum value maps to exactly ONE script identifier
/// - User input NEVER selects a script - only enum values do
/// - Startup assertion: all enum values must be mapped
/// </summary>
public static class SignalScriptMap
{
    /// <summary>
    /// Immutable mapping from SignalType to script identifier.
    /// The script identifier is a fixed key that devops's runner resolves
    /// to the physical pre-authored script location.
    /// </summary>
    private static readonly FrozenDictionary<SignalType, string> Map = new Dictionary<SignalType, string>
    {
        [SignalType.EventLog] = "eventlog",
        [SignalType.ServiceRecovery] = "service-recovery",
        [SignalType.RedisInfo] = "redis-info",
        [SignalType.DiskMem] = "disk-mem",
        [SignalType.SerilogTail] = "serilog-tail",
        [SignalType.Health] = "health"
    }.ToFrozenDictionary();

    /// <summary>
    /// Verifies at startup that every SignalType enum value is mapped.
    /// Call this during service initialization to fail fast on unmapped signals.
    /// </summary>
    /// <exception cref="InvalidOperationException">
    /// Thrown if any SignalType value is not present in the map.
    /// </exception>
    public static void VerifyCompleteness()
    {
        var allSignals = Enum.GetValues<SignalType>();
        var unmapped = allSignals.Where(s => !Map.ContainsKey(s)).ToList();

        if (unmapped.Count > 0)
        {
            throw new InvalidOperationException(
                $"SF-MS-003 VIOLATION: The following SignalType values are not mapped to scripts: " +
                $"{string.Join(", ", unmapped)}. This is a security-critical configuration error.");
        }
    }

    /// <summary>
    /// Gets the script identifier for the given signal type.
    /// </summary>
    /// <param name="signal">The signal type (must be a valid enum value).</param>
    /// <returns>The script identifier string.</returns>
    /// <exception cref="KeyNotFoundException">
    /// Thrown if the signal is not in the map (should never happen after VerifyCompleteness).
    /// </exception>
    public static string GetScriptId(SignalType signal)
    {
        if (!Map.TryGetValue(signal, out var scriptId))
        {
            throw new KeyNotFoundException(
                $"SF-MS-003 VIOLATION: SignalType '{signal}' has no mapped script. " +
                "This indicates a configuration error - call VerifyCompleteness at startup.");
        }

        return scriptId;
    }

    /// <summary>
    /// Checks if the given signal type is mapped to a script.
    /// </summary>
    /// <param name="signal">The signal type to check.</param>
    /// <returns>True if mapped, false otherwise.</returns>
    public static bool IsMapped(SignalType signal) => Map.ContainsKey(signal);

    /// <summary>
    /// Gets all mapped script identifiers (for diagnostics only).
    /// </summary>
    public static IReadOnlyCollection<string> AllScriptIds => Map.Values;

    /// <summary>
    /// Gets the count of mapped signals (should equal Enum.GetValues count).
    /// </summary>
    public static int MappedCount => Map.Count;
}
