using RTMMaintenance.ReadPlane.Contracts;

namespace RTMMaintenance.ReadPlane.Validation;

/// <summary>
/// SF-MS-003 ANTI-RCE: Validated argument array producer.
///
/// This is the ONLY sanctioned path from validated CollectIncidentRequest to script arguments.
///
/// SECURITY GUARANTEES:
/// - Timestamps converted to ISO-8601 round-trip format ("o") - never free text
/// - No shell metacharacters can reach the output un-isolated
/// - No string concatenation with user input
/// - Output is a typed IReadOnlyList&lt;string&gt; for ProcessStartInfo.ArgumentList
/// </summary>
public static class ArgumentArrayGuard
{
    /// <summary>
    /// Shell metacharacters that are NEVER allowed in arguments.
    /// If any of these appear in generated args, it's a bug in this class.
    /// </summary>
    private static readonly char[] ShellMetachars = ['|', '&', ';', '$', '`', '(', ')', '{', '}', '<', '>', '\n', '\r', '\0'];

    /// <summary>
    /// Builds the argument array for a signal invocation.
    /// </summary>
    /// <param name="request">Validated collect incident request.</param>
    /// <param name="signal">The specific signal being invoked.</param>
    /// <returns>Argument array safe for ProcessStartInfo.ArgumentList.</returns>
    /// <exception cref="InvalidOperationException">
    /// Thrown if the generated arguments contain shell metacharacters (should never happen).
    /// </exception>
    public static IReadOnlyList<string> BuildArgumentArray(CollectIncidentRequest request, SignalType signal)
    {
        var args = new List<string>
        {
            "-Since", FormatTimestamp(request.Since),
            "-Until", FormatTimestamp(request.Until),
            "-Signal", signal.ToString()
        };

        ValidateNoShellMetachars(args);

        return args.AsReadOnly();
    }

    /// <summary>
    /// Formats a timestamp in ISO-8601 round-trip format.
    /// This format is unambiguous and contains no shell-dangerous characters.
    /// </summary>
    private static string FormatTimestamp(DateTime timestamp)
    {
        return timestamp.ToUniversalTime().ToString("o", System.Globalization.CultureInfo.InvariantCulture);
    }

    /// <summary>
    /// Validates that no argument contains shell metacharacters.
    /// This is a defense-in-depth check - the format methods should never produce these.
    /// </summary>
    private static void ValidateNoShellMetachars(IEnumerable<string> args)
    {
        foreach (var arg in args)
        {
            var badCharIndex = arg.IndexOfAny(ShellMetachars);
            if (badCharIndex >= 0)
            {
                throw new InvalidOperationException(
                    $"SF-MS-003 VIOLATION: Generated argument contains shell metacharacter " +
                    $"'{arg[badCharIndex]}' at position {badCharIndex}. " +
                    "This is a bug in ArgumentArrayGuard - arguments should never contain these.");
            }
        }
    }

    /// <summary>
    /// Checks if a string contains any shell metacharacters.
    /// Exposed for testing.
    /// </summary>
    public static bool ContainsShellMetachars(string value)
    {
        return value.IndexOfAny(ShellMetachars) >= 0;
    }

    /// <summary>
    /// Gets the list of shell metacharacters that are blocked.
    /// Exposed for testing.
    /// </summary>
    public static IReadOnlyList<char> BlockedMetachars => ShellMetachars;
}
