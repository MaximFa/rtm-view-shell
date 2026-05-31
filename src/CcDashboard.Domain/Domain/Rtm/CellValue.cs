namespace CcDashboard.Domain.Domain.Rtm;

/// <summary>
/// Raw string value from RTM Hub. May represent a number, a clock (epoch ms), or plain text.
/// </summary>
public readonly record struct CellValue(string Raw)
{
    public static CellValue Parse(string? s) => new(s ?? "");

    public bool IsClock => long.TryParse(Raw, out var ms) && ms > 1_000_000_000_000L;
    public long EpochMs => long.TryParse(Raw, out var ms) ? ms : 0L;

    public string ToDisplay(DateTimeOffset? serverNow, TimeSpan? serverOffset)
    {
        if (!IsClock) return Raw;
        var epoch = DateTimeOffset.FromUnixTimeMilliseconds(EpochMs);
        var elapsed = (serverNow ?? DateTimeOffset.UtcNow) - epoch;
        return elapsed.TotalSeconds < 0 ? "0:00"
             : elapsed.TotalHours >= 1  ? $"{(int)elapsed.TotalHours}:{elapsed.Minutes:D2}:{elapsed.Seconds:D2}"
             :                            $"{elapsed.Minutes}:{elapsed.Seconds:D2}";
    }

    public override string ToString() => Raw;
}
