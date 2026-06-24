namespace RTMMaintenance.ReadPlane.Jobs.Contracts;

/// <summary>
/// SF-MS-003 ANTI-RCE CONTRACT: Script invocation interface.
///
/// This contract defines HOW scripts are invoked. Devops's runner MUST satisfy this.
///
/// SECURITY REQUIREMENTS:
/// - Params passed ONLY as a typed IReadOnlyList&lt;string&gt; argument array
/// - Maps to ProcessStartInfo.ArgumentList, NEVER ProcessStartInfo.Arguments (string concat)
/// - No value reaches a shell unquoted
/// - No cmd /c or -Command "&lt;concat&gt;" patterns
/// - PowerShell scripts invoked as: pwsh -File &lt;fixed-script&gt; -Since &lt;arg&gt; -Until &lt;arg&gt;
///   via ArgumentList only
///
/// The ArgumentArrayGuard is the ONLY sanctioned path from validated request to script args.
/// </summary>
public interface IScriptInvocation
{
    /// <summary>
    /// Executes a read script with the given argument array.
    /// </summary>
    /// <param name="scriptId">
    /// Script identifier from SignalScriptMap. This resolves to the physical
    /// pre-authored script location via devops's configuration.
    /// </param>
    /// <param name="arguments">
    /// Typed argument array produced by ArgumentArrayGuard.
    /// MUST be passed to ProcessStartInfo.ArgumentList, never concatenated.
    /// </param>
    /// <param name="ct">Cancellation token.</param>
    /// <returns>Script output (stdout).</returns>
    /// <exception cref="ScriptExecutionException">
    /// Thrown on non-zero exit code or execution failure.
    /// </exception>
    Task<ScriptOutput> ExecuteAsync(
        string scriptId,
        IReadOnlyList<string> arguments,
        CancellationToken ct = default);
}

/// <summary>
/// Output from script execution.
/// </summary>
public record ScriptOutput
{
    /// <summary>
    /// Standard output from the script.
    /// </summary>
    public required string StdOut { get; init; }

    /// <summary>
    /// Standard error from the script (may contain warnings).
    /// </summary>
    public required string StdErr { get; init; }

    /// <summary>
    /// Exit code (0 = success).
    /// </summary>
    public required int ExitCode { get; init; }

    /// <summary>
    /// Execution duration.
    /// </summary>
    public required TimeSpan Duration { get; init; }
}

/// <summary>
/// Exception thrown when script execution fails.
/// </summary>
public class ScriptExecutionException : Exception
{
    public string ScriptId { get; }
    public int? ExitCode { get; }
    public string? StdErr { get; }

    public ScriptExecutionException(string scriptId, string message)
        : base($"Script '{scriptId}' failed: {message}")
    {
        ScriptId = scriptId;
    }

    public ScriptExecutionException(string scriptId, int exitCode, string stdErr)
        : base($"Script '{scriptId}' exited with code {exitCode}")
    {
        ScriptId = scriptId;
        ExitCode = exitCode;
        StdErr = stdErr;
    }
}
