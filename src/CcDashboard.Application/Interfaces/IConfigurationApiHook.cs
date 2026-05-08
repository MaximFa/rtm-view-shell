namespace CcDashboard.Application.Interfaces;

/// <summary>
/// Reserved hook for notifying the CC-platform of configuration changes.
/// Currently a no-op. Replace the registered implementation (NoOpConfigurationApiHook)
/// with a real REST/SignalR client when the external API is available.
/// </summary>
public interface IConfigurationApiHook
{
    Task NotifyAsync(string entityType, object payload, CancellationToken ct = default);
}
