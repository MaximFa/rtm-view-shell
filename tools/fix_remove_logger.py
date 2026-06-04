#!/usr/bin/env python3
"""Remove Logger calls from NotifyRtmLoadDataAsync method."""
import os

path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Dashboard\ScreenEditorPage.razor"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Replace Logger calls with empty statements (or just remove them)
old_method = '''    private async Task NotifyRtmLoadDataAsync()
    {
        try
        {
            if (Dashboard?.TenantId == null) return;

            var settings = await Mediator.Send(new GetTenantSettingsQuery(Dashboard.TenantId), _cts.Token);
            if (string.IsNullOrEmpty(settings?.SignalRConnectionUrl)) return;

            // Build base URL from SignalR URL (strip /signalr suffix if present)
            var baseUrl = settings.SignalRConnectionUrl.TrimEnd('/');
            if (baseUrl.EndsWith("/signalr", StringComparison.OrdinalIgnoreCase))
                baseUrl = baseUrl[..^8];

            using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
            await http.GetAsync($"{baseUrl}/LoadData");
            Logger.LogInformation("ScreenEditorPage: RTM LoadData triggered after column save");
        }
        catch (Exception ex)
        {
            Logger.LogWarning(ex, "ScreenEditorPage: RTM LoadData notification failed (non-critical)");
        }
    }'''

new_method = '''    private async Task NotifyRtmLoadDataAsync()
    {
        try
        {
            if (Dashboard?.TenantId == null) return;

            var settings = await Mediator.Send(new GetTenantSettingsQuery(Dashboard.TenantId), _cts.Token);
            if (string.IsNullOrEmpty(settings?.SignalRConnectionUrl)) return;

            // Build base URL from SignalR URL (strip /signalr suffix if present)
            var baseUrl = settings.SignalRConnectionUrl.TrimEnd('/');
            if (baseUrl.EndsWith("/signalr", StringComparison.OrdinalIgnoreCase))
                baseUrl = baseUrl[..^8];

            using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
            await http.GetAsync($"{baseUrl}/LoadData");
        }
        catch
        {
            // RTM reload failed - non-critical, widget will show data after RTM restart
        }
    }'''

text = text.replace(old_method, new_method)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print(f"Fixed NotifyRtmLoadDataAsync method ({len(text.splitlines())} lines)")
