namespace RTMMaintenance.ReadPlane.Contracts;

/// <summary>
/// SF-MS-002 SEAM: Bundle confidentiality — scrub/redact BEFORE write (default-deny).
///
/// Redact patterns:
/// - Connection strings (ConnectionString=, Data Source=, Server=, etc.)
/// - Password fields (Password=, PGPASSWORD, pwd=)
/// - Tokens (token, bearer, secret, api-key, JWT-shaped)
/// - Caller ANI/phone numbers (locale-aware patterns)
///
/// Default-deny: redact anything matching a secret-shaped pattern even if not enumerated.
///
/// STREAMING/IN-MEMORY SCRUB: raw secrets NEVER transiently on disk.
/// This is a security pin-at-build condition from spec §G.
/// </summary>
public interface ISecretScrubber
{
    /// <summary>
    /// Scrub secrets from content BEFORE writing to disk.
    /// MUST be called on ALL bundle content before persistence.
    /// Streaming implementation: scrub as data flows, never buffer unscrubbed raw.
    /// </summary>
    /// <param name="content">Raw content that may contain secrets.</param>
    /// <returns>Scrubbed content with secrets replaced by [REDACTED].</returns>
    string Scrub(string content);

    /// <summary>
    /// Scrub secrets from a stream, writing scrubbed output to destination.
    /// Streaming: processes line-by-line, raw secrets never fully in memory.
    /// </summary>
    /// <param name="source">Source stream with potential secrets.</param>
    /// <param name="destination">Destination for scrubbed output.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    Task ScrubStreamAsync(Stream source, Stream destination, CancellationToken cancellationToken = default);
}
