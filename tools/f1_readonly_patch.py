#!/usr/bin/env python3
"""
F-1 Security Fix: Make MetricsPage read-only
Removes all metric mutation UI and backend commands.
"""
import os

# === 1. MetricsPage.razor - rewrite to read-only version ===
metrics_page_content = r'''@page "/admin/configuration/metrics"
@rendermode InteractiveServer
@layout MainLayout
@attribute [Authorize(Roles = "Superadmin")]
@inject IMediator Mediator
@inject IRtmRelayService RtmRelay
@inject IMetricDeployLedgerReader LedgerReader
@inject IMetricApplyClient ApplyClient
@inject ICurrentUserAccessor CurrentUser
@inject ITenantContext TenantContext
@inject ILogger<MetricsPage> Logger
@using MediatR
@using CcDashboard.Application.Queries.Configuration
@using CcDashboard.Application.Interfaces
@using CcDashboard.Contracts.DTOs.Configuration
@using CcDashboard.Contracts.DTOs.Metrics
@using CcDashboard.Domain.Interfaces
@using Microsoft.AspNetCore.Authorization
@using System.Text.Json
@implements IDisposable

<PageTitle>@L["Metrics_Title"] — RTM View Shell</PageTitle>

<div class="d-flex justify-content-between align-items-center mb-3">
    <h1 class="h4 mb-0">@L["Metrics_Title"]</h1>
</div>

<!-- Tab navigation -->
<ul class="nav nav-tabs mb-3">
    <li class="nav-item">
        <button class="nav-link @(ActiveTab == "list" ? "active" : "")" @onclick='() => ActiveTab = "list"'>
            @L["Metrics_TabList"]
        </button>
    </li>
    <li class="nav-item">
        <button class="nav-link @(ActiveTab == "deploy" ? "active" : "")" @onclick="SwitchToDeployTab">
            @L["Metrics_TabDeploy"]
            @if (UndeployedCount > 0)
            {
                <span class="badge bg-warning text-dark ms-1">@UndeployedCount</span>
            }
        </button>
    </li>
</ul>

@if (Error is not null)
{
    <div class="alert alert-danger py-2 alert-dismissible">
        @Error <button class="btn-close btn-sm" @onclick="() => Error = null"></button>
    </div>
}

@if (ActiveTab == "list")
{
    <!-- Metrics List Tab (read-only) -->
    @if (Loading)
    {
        <div class="text-center py-4"><span class="spinner-border spinner-border-sm text-primary"></span></div>
    }
    else
    {
        <div class="row g-2 mb-3">
            <div class="col-md-4">
                <input class="form-control form-control-sm" placeholder="@L["Metrics_MetricId"]…" @bind="SearchId" @bind:event="oninput" @bind:after="ResetPage" />
            </div>
            <div class="col-md-5">
                <input class="form-control form-control-sm" placeholder="@L["Metrics_Description"]…" @bind="SearchDesc" @bind:event="oninput" @bind:after="ResetPage" />
            </div>
        </div>

        <div class="table-responsive" aria-busy="@Loading">
            <table class="table table-sm table-hover align-middle" style="table-layout:fixed; width:100%;">
                <colgroup>
                    <col style="width:16%" />
                    <col style="width:16%" />
                    <col style="width:24%" />
                    <col style="width:10%" />
                    <col style="width:9%" />
                    <col style="width:9%" />
                    <col style="width:16%" />
                </colgroup>
                <thead class="table-light">
                    <tr>
                        <th>@L["Metrics_MetricId"]</th>
                        <th>@L["Metrics_DisplayName"]</th>
                        <th>@L["Metrics_Description"]</th>
                        <th>@L["Metrics_DataType"]</th>
                        <th>@L["Metrics_ValueType"]</th>
                        <th>@L["Metrics_MetricType"]</th>
                        <th>@L["Metrics_Function"]</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach (var m in PagedMetrics)
                    {
                        <tr @key="m.MetricId">
                            <td class="small text-truncate" title="@m.MetricId">@m.MetricId</td>
                            <td class="small text-truncate" title="@(m.DisplayName ?? m.Description)">@(m.DisplayName ?? m.Description)</td>
                            <td class="small text-truncate" title="@m.Description">@m.Description</td>
                            <td class="small text-truncate">@m.DataType</td>
                            <td class="small text-truncate">@m.ValueType</td>
                            <td class="small text-truncate">@m.MetricType</td>
                            <td class="small text-truncate" title="@m.MetricFunction">@m.MetricFunction</td>
                        </tr>
                    }
                    @if (TotalFiltered == 0)
                    {
                        <tr><td colspan="7" class="text-center text-muted py-3">@L["Metrics_Empty"]</td></tr>
                    }
                </tbody>
            </table>
        </div>

        <div class="pagination-bar">
            <span class="pagination-info">@TotalFiltered @L["Common_Records"]</span>
            <div class="pagination-controls">
                <select class="pagination-size" @bind="PageSize" @bind:after="ResetPage">
                    <option value="10">10</option>
                    <option value="25">25</option>
                    <option value="50">50</option>
                    <option value="100">100</option>
                </select>
                <button class="btn btn-sm btn-outline-secondary" disabled="@(CurrentPage <= 1)" @onclick="PrevPage">&#8249;</button>
                <span class="pagination-counter">@PageLabel</span>
                <button class="btn btn-sm btn-outline-secondary" disabled="@(CurrentPage >= TotalPages)" @onclick="NextPage">&#8250;</button>
            </div>
        </div>
    }
}
else if (ActiveTab == "deploy")
{
    <!-- Deploy New Metrics Tab -->
    @if (DeployLoading)
    {
        <div class="text-center py-4"><span class="spinner-border spinner-border-sm text-primary"></span></div>
    }
    else
    {
        @if (DeployError is not null)
        {
            <div class="alert alert-warning py-2 mb-3">
                <i class="bi bi-exclamation-triangle me-1"></i>@DeployError
            </div>
        }
        @if (DeploySuccess is not null)
        {
            <div class="alert alert-success py-2 mb-3 alert-dismissible">
                @DeploySuccess <button class="btn-close btn-sm" @onclick="() => DeploySuccess = null"></button>
            </div>
        }

        @if (UndeployedMetrics.Count == 0 && DeployedMetrics.Count == 0)
        {
            <div class="alert alert-info py-3 text-center">
                <i class="bi bi-check-circle me-1"></i>@L["Metrics_AllDeployed"]
            </div>
        }
        else
        {
            @if (UndeployedMetrics.Count > 0)
            {
                <h6 class="mb-2">@L["Metrics_UndeployedSection"] <span class="badge bg-warning text-dark">@UndeployedMetrics.Count</span></h6>
                <div class="table-responsive mb-4">
                    <table class="table table-sm table-hover align-middle">
                        <thead class="table-light">
                            <tr>
                                <th style="width:25%">@L["Metrics_MetricId"]</th>
                                <th style="width:25%">@L["Metrics_DisplayName"]</th>
                                <th style="width:10%">@L["Metrics_Type"]</th>
                                <th style="width:25%">@L["Metrics_Description"]</th>
                                <th style="width:15%"></th>
                            </tr>
                        </thead>
                        <tbody>
                            @foreach (var entry in UndeployedMetrics)
                            {
                                <tr @key="entry.MetricId">
                                    <td class="small text-truncate" title="@entry.MetricId">
                                        @entry.MetricId
                                        @if (!string.IsNullOrEmpty(entry.MirrorMetricId))
                                        {
                                            <br /><span class="text-muted">↔ @entry.MirrorMetricId</span>
                                        }
                                    </td>
                                    <td class="small text-truncate" title="@entry.DisplayName">@entry.DisplayName</td>
                                    <td class="small">
                                        <span class="badge @(entry.MetricType == "RT" ? "bg-primary" : "bg-secondary")">@entry.MetricType</span>
                                    </td>
                                    <td class="small text-truncate" title="@entry.ShortDescription">@entry.ShortDescription</td>
                                    <td class="text-end">
                                        <button class="btn btn-success btn-sm" @onclick="() => ConfirmDeploy(entry)" disabled="@Deploying">
                                            <i class="bi bi-cloud-upload me-1"></i>@L["Metrics_Deploy"]
                                        </button>
                                    </td>
                                </tr>
                            }
                        </tbody>
                    </table>
                </div>
            }

            @if (DeployedMetrics.Count > 0)
            {
                <h6 class="mb-2">@L["Metrics_DeployedSection"] <span class="badge bg-success">@DeployedMetrics.Count</span></h6>
                <div class="table-responsive">
                    <table class="table table-sm table-hover align-middle">
                        <thead class="table-light">
                            <tr>
                                <th style="width:25%">@L["Metrics_MetricId"]</th>
                                <th style="width:25%">@L["Metrics_DisplayName"]</th>
                                <th style="width:10%">@L["Metrics_Type"]</th>
                                <th style="width:25%">@L["Metrics_Description"]</th>
                                <th style="width:15%"></th>
                            </tr>
                        </thead>
                        <tbody>
                            @foreach (var entry in DeployedMetrics.Take(20))
                            {
                                <tr @key="entry.MetricId">
                                    <td class="small text-truncate" title="@entry.MetricId">@entry.MetricId</td>
                                    <td class="small text-truncate" title="@entry.DisplayName">@entry.DisplayName</td>
                                    <td class="small">
                                        <span class="badge @(entry.MetricType == "RT" ? "bg-primary" : "bg-secondary")">@entry.MetricType</span>
                                    </td>
                                    <td class="small text-truncate" title="@entry.ShortDescription">@entry.ShortDescription</td>
                                    <td class="text-end">
                                        @if (entry.MetricType == "RT")
                                        {
                                            <button class="btn btn-outline-primary btn-sm" @onclick="() => Recompile(entry)" disabled="@Deploying" title="@L["Metrics_RecompileHint"]">
                                                <i class="bi bi-arrow-repeat me-1"></i>@L["Metrics_Recompile"]
                                            </button>
                                        }
                                    </td>
                                </tr>
                            }
                            @if (DeployedMetrics.Count > 20)
                            {
                                <tr><td colspan="5" class="text-center text-muted small">@L["Metrics_MoreDeployed", DeployedMetrics.Count - 20]</td></tr>
                            }
                        </tbody>
                    </table>
                </div>
            }
        }
    }
}

@if (DeployTarget is not null)
{
    <div class="modal show d-block" tabindex="-1" role="dialog" aria-modal="true" aria-labelledby="modal-deploy-title">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="modal-deploy-title">@L["Metrics_DeployConfirm"]</h5>
                    <button class="btn-close" @onclick="() => DeployTarget = null"></button>
                </div>
                <div class="modal-body">
                    <p>@L["Metrics_DeployWarning"]</p>
                    <p><strong>@DeployTarget.DisplayName</strong> (@DeployTarget.MetricId)</p>
                    @if (!string.IsNullOrEmpty(DeployTarget.MirrorMetricId))
                    {
                        <p class="text-muted small">@L["Metrics_MirrorPair"]: @DeployTarget.MirrorMetricId</p>
                    }
                </div>
                <div class="modal-footer">
                    <button class="btn btn-secondary btn-sm" @onclick="() => DeployTarget = null">@L["Cancel"]</button>
                    <button class="btn btn-success btn-sm" @onclick="ExecuteDeploy" disabled="@Deploying">
                        @if (Deploying) { <span class="spinner-border spinner-border-sm me-1"></span> }
                        @L["Metrics_Deploy"]
                    </button>
                </div>
            </div>
        </div>
    </div>
}

@code {
    private string ActiveTab = "list";

    private IReadOnlyList<RtsGridMetricDto> Metrics = [];
    private string SearchId = "";
    private string SearchDesc = "";
    private IEnumerable<RtsGridMetricDto> FilteredMetrics =>
        Metrics.Where(m =>
            (string.IsNullOrWhiteSpace(SearchId) || m.MetricId.Contains(SearchId, StringComparison.OrdinalIgnoreCase)) &&
            (string.IsNullOrWhiteSpace(SearchDesc) || (m.Description ?? "").Contains(SearchDesc, StringComparison.OrdinalIgnoreCase)));

    private int CurrentPage = 1;
    private int PageSize = 25;
    private int TotalFiltered => FilteredMetrics.Count();
    private int TotalPages => (int)Math.Ceiling((double)TotalFiltered / PageSize);
    private string PageLabel => $"{CurrentPage} / {Math.Max(1, TotalPages)}";
    private IEnumerable<RtsGridMetricDto> PagedMetrics => FilteredMetrics.Skip((CurrentPage - 1) * PageSize).Take(PageSize);
    private void ResetPage() => CurrentPage = 1;
    private void PrevPage() { if (CurrentPage > 1) CurrentPage--; }
    private void NextPage() { if (CurrentPage < TotalPages) CurrentPage++; }

    private bool Loading = true;
    private string? Error;

    private bool DeployLoading;
    private string? DeployError;
    private string? DeploySuccess;
    private bool Deploying;
    private DeployEntry? DeployTarget;
    private List<DeployEntry> UndeployedMetrics = new();
    private List<DeployEntry> DeployedMetrics = new();
    private int UndeployedCount => UndeployedMetrics.Count;

    private sealed record DeployEntry(string MetricId, string? DisplayName, string? ShortDescription, string MetricType, string? MirrorMetricId);

    protected override async Task OnInitializedAsync() => await LoadAsync();

    private async Task LoadAsync()
    {
        Loading = true;
        try { Metrics = await Mediator.Send(new GetRtsGridMetricsQuery()); CurrentPage = 1; }
        catch (Exception ex) { Error = ex.Message; }
        finally { Loading = false; }
    }

    private async Task SwitchToDeployTab()
    {
        ActiveTab = "deploy";
        await LoadDeployDataAsync();
    }

    private async Task LoadDeployDataAsync()
    {
        DeployLoading = true;
        DeployError = null;
        UndeployedMetrics.Clear();
        DeployedMetrics.Clear();

        try
        {
            var catalogPath = Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "docs", "metrics-catalog.json");
            if (!File.Exists(catalogPath))
                catalogPath = Path.Combine(AppContext.BaseDirectory, "docs", "metrics-catalog.json");

            List<CatalogMetric> catalogMetrics = new();
            if (File.Exists(catalogPath))
            {
                var json = await File.ReadAllTextAsync(catalogPath);
                var catalog = JsonSerializer.Deserialize<MetricsCatalog>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                catalogMetrics = catalog?.Metrics ?? new();
            }
            else
            {
                DeployError = "Metrics catalog not found. Using database metrics as fallback.";
                foreach (var m in Metrics.Where(m => m.CatalogStatus == "active"))
                {
                    catalogMetrics.Add(new CatalogMetric { MetricId = m.MetricId, DisplayName = m.DisplayName ?? m.Description, ShortDescription = m.ShortDescription, Status = m.CatalogStatus ?? "active" });
                }
            }

            IReadOnlySet<string> appliedIds;
            try { appliedIds = await LedgerReader.GetAppliedMetricIdsAsync(_cts.Token); }
            catch { appliedIds = new HashSet<string>(); if (DeployError == null) DeployError = "Deploy ledger not available. Showing all catalog metrics as undeployed."; }

            foreach (var m in catalogMetrics.Where(m => m.Status == "active"))
            {
                var isRt = !m.MetricId.Contains('.');
                var entry = new DeployEntry(m.MetricId, m.DisplayName, m.ShortDescription, isRt ? "RT" : "history", null);
                if (!appliedIds.Contains(m.MetricId)) UndeployedMetrics.Add(entry);
                else DeployedMetrics.Add(entry);
            }
        }
        catch (Exception ex) { DeployError = $"Failed to load deploy data: {ex.Message}"; Logger.LogError(ex, "MetricsPage: failed to load deploy data"); }
        finally { DeployLoading = false; }
    }

    private void ConfirmDeploy(DeployEntry entry) => DeployTarget = entry;

    private async Task ExecuteDeploy()
    {
        if (DeployTarget is null) return;
        Deploying = true;
        DeploySuccess = null;
        DeployError = null;

        var userId = CurrentUser.UserId?.ToString() ?? "unknown";
        var metricIds = new List<string> { DeployTarget.MetricId };
        if (!string.IsNullOrEmpty(DeployTarget.MirrorMetricId)) metricIds.Add(DeployTarget.MirrorMetricId);

        Logger.LogInformation("MetricsPage: Deploy triggered by {UserId} for metrics [{MetricIds}]", userId, string.Join(", ", metricIds));

        try
        {
            if (CurrentUser.Role != "Superadmin") { DeployError = "Deploy requires Superadmin role."; return; }

            var request = new ApplyMetricsRequest { PackageRef = "shell-manual", MigrationRef = "manual-deploy", MetricIds = metricIds, TriggeredBy = userId };
            var response = await ApplyClient.ApplyAsync(request, _cts.Token);

            if (!response.Success) { DeployError = response.Error ?? "Apply failed with no error message."; Logger.LogWarning("MetricsPage: Deploy failed for {MetricId}: {Error}", DeployTarget.MetricId, DeployError); return; }

            if (response.AppliedRtMetricIds?.Count > 0)
            {
                if (!TenantContext.IsResolved) throw new InvalidOperationException("No tenant context");
                await RtmRelay.InvokeCompileMetricsAsync(TenantContext.TenantId, response.AppliedRtMetricIds, _cts.Token);
            }

            Logger.LogInformation("MetricsPage: Deploy success for {MetricId}, appliedRtMetricIds=[{RtIds}], auditId={AuditId}", DeployTarget.MetricId, string.Join(", ", response.AppliedRtMetricIds ?? []), response.AuditId);
            DeploySuccess = $"Deployed: {DeployTarget.DisplayName ?? DeployTarget.MetricId}";
            if (response.Warnings?.Count > 0) DeploySuccess += $" (warnings: {string.Join("; ", response.Warnings)})";
            await LoadDeployDataAsync();
        }
        catch (Exception ex) { DeployError = $"Deploy error: {ex.Message}"; Logger.LogError(ex, "MetricsPage: Deploy exception for {MetricId}", DeployTarget.MetricId); }
        finally { Deploying = false; DeployTarget = null; }
    }

    private async Task Recompile(DeployEntry entry)
    {
        if (entry.MetricType != "RT") return;
        Deploying = true;
        DeploySuccess = null;
        DeployError = null;
        var userId = CurrentUser.UserId?.ToString() ?? "unknown";
        Logger.LogInformation("MetricsPage: Recompile triggered by {UserId} for metric {MetricId}", userId, entry.MetricId);

        try
        {
            if (!TenantContext.IsResolved) throw new InvalidOperationException("No tenant context");
            await RtmRelay.InvokeCompileMetricsAsync(TenantContext.TenantId, new[] { entry.MetricId }, _cts.Token);
            DeploySuccess = $"Recompile sent: {entry.DisplayName ?? entry.MetricId}";
            Logger.LogInformation("MetricsPage: Recompile success for {MetricId}", entry.MetricId);
        }
        catch (Exception ex) { DeployError = $"Recompile error: {ex.Message}"; Logger.LogError(ex, "MetricsPage: Recompile exception for {MetricId}", entry.MetricId); }
        finally { Deploying = false; }
    }

    private readonly CancellationTokenSource _cts = new();
    public void Dispose() => _cts.Cancel();

    private sealed class MetricsCatalog { public List<CatalogMetric> Metrics { get; set; } = new(); }
    private sealed class CatalogMetric { public string MetricId { get; set; } = ""; public string? DisplayName { get; set; } public string? ShortDescription { get; set; } public string Status { get; set; } = "active"; }
}
'''

metrics_page_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Admin\Configuration\MetricsPage.razor"
with open(metrics_page_path, "w", encoding="utf-8") as f:
    f.write(metrics_page_content)
    f.flush()
    os.fsync(f.fileno())
print(f"MetricsPage.razor written: {len(metrics_page_content.splitlines())} lines")

# === 2. ConfigurationCommands.cs - remove metric mutation commands ===
config_commands_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Application\Commands\Configuration\ConfigurationCommands.cs"
with open(config_commands_path, "r", encoding="utf-8") as f:
    config_content = f.read()

# Remove everything from "// ── Metrics" to end of file, keep everything before
marker = "// ── Metrics ──"
if marker in config_content:
    config_content = config_content[:config_content.index(marker)]

with open(config_commands_path, "w", encoding="utf-8") as f:
    f.write(config_content)
    f.flush()
    os.fsync(f.fileno())
print(f"ConfigurationCommands.cs written: {len(config_content.splitlines())} lines")

# === 3. CommandValidators.cs - remove SaveRtsGridMetricCommandValidator ===
validators_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Application\Validators\CommandValidators.cs"
with open(validators_path, "r", encoding="utf-8") as f:
    validators_content = f.read()

# Remove the entire RTS Grid Metrics section
marker = "// ── RTS Grid Metrics ──"
if marker in validators_content:
    validators_content = validators_content[:validators_content.index(marker)]

with open(validators_path, "w", encoding="utf-8") as f:
    f.write(validators_content)
    f.flush()
    os.fsync(f.fileno())
print(f"CommandValidators.cs written: {len(validators_content.splitlines())} lines")

# === 4. ConfigurationDtos.cs - remove SaveRtsGridMetricRequest and SaveMetricTranslationRequest ===
dtos_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Contracts\DTOs\Configuration\ConfigurationDtos.cs"
with open(dtos_path, "r", encoding="utf-8") as f:
    dtos_content = f.read()

# Remove SaveRtsGridMetricRequest (from "public record SaveRtsGridMetricRequest" to its closing paren + semicolon)
# And SaveMetricTranslationRequest
import re

# Remove SaveRtsGridMetricRequest record
dtos_content = re.sub(
    r'\npublic record SaveRtsGridMetricRequest\([^)]+\);',
    '',
    dtos_content,
    flags=re.DOTALL
)

# Remove SaveMetricTranslationRequest record
dtos_content = re.sub(
    r'\npublic record SaveMetricTranslationRequest\([^)]+\);',
    '',
    dtos_content,
    flags=re.DOTALL
)

with open(dtos_path, "w", encoding="utf-8") as f:
    f.write(dtos_content)
    f.flush()
    os.fsync(f.fileno())
print(f"ConfigurationDtos.cs written: {len(dtos_content.splitlines())} lines")

print("\n=== F-1 patch complete ===")
