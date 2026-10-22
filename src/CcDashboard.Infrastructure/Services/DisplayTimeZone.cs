using CcDashboard.Application.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Infrastructure.Services;

/// <summary>
/// IDisplayTimeZone from configuration "Display:TimeZoneId" (Windows or IANA id), else the server's local zone.
/// Why the server zone by default: it is what the Shell already uses for every other time it shows (ToLocalTime() on
/// admin pages, info slots, the WFM widget), it follows DST, and on 234 it is Israel Standard Time (measured
/// 2026-10-18, tzdepth-1015). There is no tenant time zone, and the site zone is a fixed offset without DST.
/// An unknown configured id falls back to the server zone and says so in the log.
/// </summary>
public sealed class DisplayTimeZone : IDisplayTimeZone
{
    public TimeZoneInfo Zone { get; }

    public DisplayTimeZone(IConfiguration config, ILogger<DisplayTimeZone> logger)
    {
        var id = config["Display:TimeZoneId"];
        Zone = TimeZoneInfo.Local;
        if (!string.IsNullOrWhiteSpace(id))
        {
            try { Zone = TimeZoneInfo.FindSystemTimeZoneById(id.Trim()); }
            catch (Exception ex) when (ex is TimeZoneNotFoundException or InvalidTimeZoneException)
            {
                logger.LogWarning("Display:TimeZoneId '{Id}' is not a known time zone; showing times in the server zone {Zone}", id, Zone.Id);
            }
        }
        logger.LogInformation("Times are shown in zone {Zone} (DST: {Dst})", Zone.Id, Zone.SupportsDaylightSavingTime);
    }
}
