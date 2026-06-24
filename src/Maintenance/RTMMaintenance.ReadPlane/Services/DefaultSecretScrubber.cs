using System.Text.RegularExpressions;
using RTMMaintenance.ReadPlane.Contracts;

namespace RTMMaintenance.ReadPlane.Services;

/// <summary>
/// SF-MS-002: Default-deny secret scrubber. Streaming scrub BEFORE write.
/// </summary>
public partial class DefaultSecretScrubber : ISecretScrubber
{
    private const string Redacted = "[REDACTED]";

    private static readonly Regex[] ScrubPatterns =
    [
        PasswordPattern(),
        ConnectionStringPattern(),
        TokenPattern(),
        BearerPattern(),
        SecretPattern(),
        ApiKeyPattern(),
        JwtPattern(),
        PhoneUsPattern(),
        PhoneIntlPattern(),
        PgPasswordPattern(),
    ];

    [GeneratedRegex(@"(?i)(password|pwd|passwd)\s*[=:]\s*[^\s;,]+", RegexOptions.Compiled)]
    private static partial Regex PasswordPattern();
    [GeneratedRegex(@"(?i)(connectionstring|data source|server|host)\s*[=:]\s*[^\s;]+", RegexOptions.Compiled)]
    private static partial Regex ConnectionStringPattern();
    [GeneratedRegex(@"(?i)(token)\s*[=:]\s*[^\s;,]+", RegexOptions.Compiled)]
    private static partial Regex TokenPattern();
    [GeneratedRegex(@"(?i)(bearer)\s+[A-Za-z0-9\-_\.]+", RegexOptions.Compiled)]
    private static partial Regex BearerPattern();
    [GeneratedRegex(@"(?i)(secret|client_secret)\s*[=:]\s*[^\s;,]+", RegexOptions.Compiled)]
    private static partial Regex SecretPattern();
    [GeneratedRegex(@"(?i)(api[-_]?key|apikey)\s*[=:]\s*[^\s;,]+", RegexOptions.Compiled)]
    private static partial Regex ApiKeyPattern();
    [GeneratedRegex(@"eyJ[A-Za-z0-9\-_]+\.eyJ[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+", RegexOptions.Compiled)]
    private static partial Regex JwtPattern();
    [GeneratedRegex(@"\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b", RegexOptions.Compiled)]
    private static partial Regex PhoneUsPattern();
    [GeneratedRegex(@"\+\d{1,3}[-.\s]?\d{2,4}[-.\s]?\d{3,4}[-.\s]?\d{4}\b", RegexOptions.Compiled)]
    private static partial Regex PhoneIntlPattern();
    [GeneratedRegex(@"(?i)PGPASSWORD\s*[=:]\s*[^\s;,]+", RegexOptions.Compiled)]
    private static partial Regex PgPasswordPattern();

    public string Scrub(string content)
    {
        if (string.IsNullOrEmpty(content)) return content;
        var result = content;
        foreach (var pattern in ScrubPatterns)
            result = pattern.Replace(result, m => m.Value.Contains('=') || m.Value.Contains(':')
                ? m.Value.Split(['=', ':'], 2)[0].TrimEnd() + "=" + Redacted
                : Redacted);
        return result;
    }

    public async Task ScrubStreamAsync(Stream source, Stream destination, CancellationToken cancellationToken = default)
    {
        using var reader = new StreamReader(source, leaveOpen: true);
        await using var writer = new StreamWriter(destination, leaveOpen: true);
        string? line;
        while ((line = await reader.ReadLineAsync(cancellationToken)) != null)
            await writer.WriteLineAsync(Scrub(line).AsMemory(), cancellationToken);
        await writer.FlushAsync(cancellationToken);
    }
}
