using Microsoft.AspNetCore.SignalR.Client;

namespace CcDashboard.Infrastructure.RtmRelay;

/// <summary>
/// BL-V4-STALE-VALUES-LOOK-LIVE-01, second half: is a relay channel's link to the RTM hub up?
///
/// Found by the coordinator's question about a six-minute strip on 2026-10-27: a widget learned the
/// link state ONLY from the ConnectionChanged notice, so a screen opened AFTER the link went down
/// never heard anything and showed the last values with no strip at all - exactly what the unit was
/// written to stop. The notice is not enough on its own; a subscriber must be able to ask.
///
/// The verdict lives in its own function, away from the service's dictionaries and locks, because
/// that is the only way to test it: a HubConnection is built inside the service and has no
/// interface, so no test can produce a genuinely Connected one. Here every state can be passed in,
/// including the ones that look like success and are not.
/// </summary>
internal static class RtmChannelLink
{
    /// <summary>
    /// True only when the channel can actually deliver data right now.
    ///
    /// Reconnecting and Connecting are deliberately NOT "up": during them nothing arrives, and a
    /// widget that treated them as up would clear its stale mark and present old values as
    /// current - the defect, narrowed to a few seconds. A null state means there is no connection
    /// object at all (never built, or abandoned after a failed reconnect), which is also not up.
    /// </summary>
    internal static bool IsUp(HubConnectionState? state) => state == HubConnectionState.Connected;
}
