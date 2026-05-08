using CcDashboard.Application.Interfaces;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Infrastructure.Services;

/// <summary>
/// No-op implementation. Replace with REST/SignalR client when CC-platform API is available.
/// </summary>
public class NoOpConfigurationApiHook(ILogger<NoOpConfigurationApiHook> logger) : IConfigurationApiHook
{
    public Task NotifyAsync(string entityType, object payload, CancellationToken ct = default)
    {
        logger.LogDebug("[API-HOOK] {EntityType} changed — external notification not yet wired", entityType);
        return Task.CompletedTask;
    }
}
