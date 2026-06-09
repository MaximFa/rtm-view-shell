using CcDashboard.Contracts.DTOs.Metrics;

namespace CcDashboard.Application.Interfaces;

/// <summary>
/// Client to the devops apply-endpoint (contract §3/§5).
/// Triggers apply-service to execute the metric-migration and write ledger.
/// Shell only TRIGGERS; never executes migration SQL (no web-DML, contract §2).
/// </summary>
public interface IMetricApplyClient
{
    /// <summary>
    /// Sends apply request to the localhost apply-service.
    /// Returns ApplyMetricsResponse with Success, AppliedRtMetricIds, LedgerRows, Warnings, Error.
    /// On transport/non-200 error -> returns Success=false + Error message (never throws to UI raw).
    /// </summary>
    Task<ApplyMetricsResponse> ApplyAsync(ApplyMetricsRequest request, CancellationToken ct = default);
}
