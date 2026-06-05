# CC Task: DayTrend — local view config for View Mode (localStorage, per-user)

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md

## Git push
Do NOT run `git push`. Commit only.

---

## Feature summary

In View Mode (`/screens/{id}`), the DayTrend widget shows a ⚙ icon.
Clicking it opens a local configurator modal. User selects BU and metrics.
Clicking "Apply" saves to localStorage and reloads chart data.
Clicking "Reset" clears localStorage and reverts to saved admin config.
Changes are LOCAL ONLY — never touch `WidgetConfig` in DB.

localStorage key: `cc:daytrendview:{WidgetInstanceId}` (Guid parameter)

---

## File 1 — `src/CcDashboard.Web/Components/Dashboard/RenderWidget.razor`

Add `IsViewMode` parameter and pass it to `DayTrendWidget`:

```razor
@code {
    [Parameter, EditorRequired] public PlacedWidget Widget { get; set; } = null!;
    [Parameter] public bool DarkMode { get; set; }
    [Parameter] public bool IsViewMode { get; set; }
    [Parameter] public EventCallback<int> ActiveFilterCountChanged { get; set; }
}
```

In the DayTrend case line, add `IsViewMode="IsViewMode"`:
```razor
case var n when n.Contains("day") && n.Contains("trend"):
    <DayTrendWidget @key="Widget.Id" Config="Widget.Config" DarkMode="DarkMode"
                    WidgetInstanceId="Widget.Id" IsViewMode="IsViewMode" />
    break;
```

---

## File 2 — `src/CcDashboard.Web/Components/Dashboard/ScreenFullscreenPage.razor`

In the `<RenderWidget>` call, add `IsViewMode="true"`:
```razor
<RenderWidget Widget="widget" DarkMode="_darkMode" IsViewMode="true" />
```

`ScreenEditorPage.razor` does NOT need changes — `IsViewMode` defaults to `false`.

---

## File 3 — `src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor`

### 3.1 — New parameter

```csharp
[Parameter] public bool IsViewMode { get; set; }
```

### 3.2 — New fields (add near other private fields)

```csharp
// View-mode local config
private bool _showViewConfig;
private List<BusinessUnitDto> _viewBuList = [];
private int _localBuId;                          // 0 = use saved config value
private HashSet<string>? _localMetricIds;        // null = use saved config
private HashSet<string>? _localAgentMetricIds;   // null = use saved config

private string LocalStorageKey => $"cc:daytrendview:{WidgetInstanceId}";

// Effective values used for data loading and rendering
private int EffectiveBuId => _localBuId > 0 ? _localBuId : _businessUnitId;
```

### 3.3 — LoadLocalOverridesAsync (call at end of OnInitializedAsync)

```csharp
private async Task LoadLocalOverridesAsync()
{
    try
    {
        var json = await JS.InvokeAsync<string?>("localStorage.getItem", LocalStorageKey);
        if (string.IsNullOrEmpty(json)) return;

        var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        if (root.TryGetProperty("buId", out var buEl) && buEl.TryGetInt32(out var buId) && buId > 0)
            _localBuId = buId;

        if (root.TryGetProperty("metrics", out var mEl) && mEl.ValueKind == JsonValueKind.Array)
            _localMetricIds = mEl.EnumerateArray()
                .Select(x => x.GetString() ?? "")
                .Where(s => !string.IsNullOrEmpty(s))
                .ToHashSet();

        if (root.TryGetProperty("agentMetrics", out var amEl) && amEl.ValueKind == JsonValueKind.Array)
            _localAgentMetricIds = amEl.EnumerateArray()
                .Select(x => x.GetString() ?? "")
                .Where(s => !string.IsNullOrEmpty(s))
                .ToHashSet();
    }
    catch (Exception ex)
    {
        Logger.LogDebug(ex, "DayTrendWidget: failed to load local overrides");
    }
}
```

### 3.4 — SaveLocalOverridesAsync

```csharp
private async Task SaveLocalOverridesAsync()
{
    var obj = new
    {
        buId    = _localBuId,
        metrics = _metrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray(),
        agentMetrics = _agentMetrics.Where(m => m.Enabled).Select(m => m.MetricId).ToArray()
    };
    var json = JsonSerializer.Serialize(obj);
    await JS.InvokeVoidAsync("localStorage.setItem", LocalStorageKey, json);
}
```

### 3.5 — ClearLocalOverridesAsync (Reset button)

```csharp
private async Task ClearLocalOverridesAsync()
{
    await JS.InvokeVoidAsync("localStorage.removeItem", LocalStorageKey);
    _localBuId = 0;
    _localMetricIds = null;
    _localAgentMetricIds = null;
    _showViewConfig = false;
    ParseConfig();
    await LoadDataAsync();
}
```

### 3.6 — OpenViewConfigAsync (⚙ button click)

```csharp
private async Task OpenViewConfigAsync()
{
    if (!_viewBuList.Any())
        _viewBuList = (await Mediator.Send(new GetMyBusinessUnitsQuery(), _cts.Token)).ToList();

    // Pre-select current effective values in the metric lists
    if (_localMetricIds is not null)
        foreach (var m in _metrics)
            m = m with { Enabled = _localMetricIds.Contains(m.MetricId) };

    if (_localAgentMetricIds is not null)
        foreach (var m in _agentMetrics)
            m = m with { Enabled = _localAgentMetricIds.Contains(m.MetricId) };

    _showViewConfig = true;
}
```

Note: `DayTrendMetricConfig` is a record — use `with` expression or replace the list:
```csharp
if (_localMetricIds is not null)
    _metrics = _metrics.Select(m => m with { Enabled = _localMetricIds.Contains(m.MetricId) }).ToList();

if (_localAgentMetricIds is not null)
    _agentMetrics = _agentMetrics.Select(m => m with { Enabled = _localAgentMetricIds.Contains(m.MetricId) }).ToList();
```

### 3.7 — ApplyViewConfigAsync (Apply button)

```csharp
private async Task ApplyViewConfigAsync()
{
    await SaveLocalOverridesAsync();
    _showViewConfig = false;
    await LoadDataAsync();
}
```

### 3.8 — Use EffectiveBuId in LoadDataAsync

Find the `DayTrendQuery(...)` call in `LoadDataAsync` and replace `_businessUnitId` with `EffectiveBuId`:

```csharp
var result = await Mediator.Send(new DayTrendQuery(
    EffectiveBuId,       // ← was _businessUnitId
    _intervalMinutes,
    includeAgentMetrics), _cts.Token);
```

Also update the guard at the top of LoadDataAsync:
```csharp
if (EffectiveBuId == 0)   // ← was _businessUnitId == 0
```

### 3.9 — Call LoadLocalOverridesAsync in OnInitializedAsync

At the end of `OnInitializedAsync`, before `await LoadDataAsync()`:
```csharp
if (IsViewMode)
    await LoadLocalOverridesAsync();
```

### 3.10 — HTML: ⚙ button overlay + modal

Inside the root `<div class="daytrend-widget h-100">`, at the very TOP (before all `@if` blocks), add:

```razor
@if (IsViewMode)
{
    <button class="btn btn-sm btn-link p-0 daytrendview-settings-btn"
            title="@L["Widget_LocalViewSettings"]"
            @onclick="OpenViewConfigAsync">
        <i class="bi bi-sliders" style="font-size: 0.9rem;"></i>
    </button>
}
```

After the root div's content (before closing `</div>`), add the modal:

```razor
@if (IsViewMode && _showViewConfig)
{
    <div class="modal fade show d-block" tabindex="-1" style="background:rgba(0,0,0,0.5);">
        <div class="modal-dialog modal-lg">
            <div class="modal-content">
                <div class="modal-header py-2">
                    <h6 class="modal-title mb-0">@L["Widget_LocalViewSettings"]</h6>
                    <button class="btn-close btn-close-white" @onclick="() => _showViewConfig = false"></button>
                </div>
                <div class="modal-body">
                    <!-- BU selector -->
                    <div class="mb-3">
                        <label class="form-label fw-semibold">@L["Widgets_BusinessUnit"]</label>
                        <select class="form-select form-select-sm" @bind="_localBuId">
                            <option value="0">— @L["Widget_UseDefault"] —</option>
                            @foreach (var bu in _viewBuList)
                            {
                                <option value="@bu.BusinessUnitId">@bu.BusinessUnitName</option>
                            }
                        </select>
                    </div>

                    <!-- Interaction metrics -->
                    <div class="mb-2 fw-semibold small">@L["DayTrend_InteractionMetrics"]</div>
                    @foreach (var m in _metrics)
                    {
                        <div class="form-check form-check-sm mb-1">
                            <input class="form-check-input" type="checkbox" id="vm_@m.MetricId"
                                   checked="@m.Enabled"
                                   @onchange="e => { var idx = _metrics.IndexOf(m); if(idx>=0) _metrics[idx] = m with { Enabled = (bool)e.Value! }; }" />
                            <label class="form-check-label small" for="vm_@m.MetricId">
                                @GetDisplayLabel(m)
                            </label>
                        </div>
                    }

                    <!-- Agent metrics -->
                    @if (_agentMetrics.Any())
                    {
                        <div class="mt-2 mb-2 fw-semibold small">@L["DayTrend_AgentMetrics"]</div>
                        @foreach (var m in _agentMetrics)
                        {
                            <div class="form-check form-check-sm mb-1">
                                <input class="form-check-input" type="checkbox" id="vm_@m.MetricId"
                                       checked="@m.Enabled"
                                       @onchange="e => { var idx = _agentMetrics.IndexOf(m); if(idx>=0) _agentMetrics[idx] = m with { Enabled = (bool)e.Value! }; }" />
                                <label class="form-check-label small" for="vm_@m.MetricId">
                                    @GetDisplayLabel(m)
                                </label>
                            </div>
                        }
                    }
                </div>
                <div class="modal-footer py-2 d-flex justify-content-between">
                    <button class="btn btn-sm btn-outline-danger" @onclick="ClearLocalOverridesAsync">
                        <i class="bi bi-arrow-counterclockwise me-1"></i>@L["Widget_ResetToDefault"]
                    </button>
                    <div>
                        <button class="btn btn-sm btn-secondary me-2" @onclick="() => _showViewConfig = false">
                            @L["Cancel"]
                        </button>
                        <button class="btn btn-sm btn-primary" @onclick="ApplyViewConfigAsync">
                            <i class="bi bi-check2 me-1"></i>@L["Apply"]
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </div>
}
```

### 3.11 — CSS for ⚙ button (add to DayTrendWidget.razor.css or app.css)

```css
.daytrendview-settings-btn {
    position: absolute;
    top: 4px;
    right: 4px;
    z-index: 10;
    opacity: 0.4;
    transition: opacity 0.2s;
    color: inherit;
}
.daytrend-widget:hover .daytrendview-settings-btn {
    opacity: 1;
}
```

### 3.12 — Add missing @using

At the top of DayTrendWidget.razor, add:
```razor
@using CcDashboard.Application.Queries.Configuration
@using CcDashboard.Contracts.DTOs
```

---

## New localization keys needed

Check `SharedResources.en-US.resx`, `SharedResources.ru-RU.resx`, `SharedResources.he-IL.resx`.
Add if missing:

| Key | EN | RU |
|---|---|---|
| `Widget_LocalViewSettings` | Local view settings | Локальные настройки отображения |
| `Widget_UseDefault` | Use default | Использовать по умолчанию |
| `Widget_ResetToDefault` | Reset to default | Сбросить к настройкам |
| `Apply` | Apply | Применить |

---

## Implementation steps

1. Read skill files
2. `git status --short` + integrity check
3. Make all changes via Python atomic write + fsync (Edit tool BANNED):
   - `RenderWidget.razor` — add `IsViewMode` param + pass to DayTrendWidget
   - `ScreenFullscreenPage.razor` — add `IsViewMode="true"`
   - `DayTrendWidget.razor` — all §3.x changes
   - `.resx` files — add missing keys
4. `dotnet build CcDashboard.sln` — 0 errors
5. `bash tools/pre-commit-check.sh`
6. Commit: `feat: DayTrend local view config in View Mode (BU + metrics, localStorage)`
7. Re-sync from HEAD (§0.6 PD-007)

---

## Re-sync block (§0.6 PD-007)

```bash
for f in \
  "src/CcDashboard.Web/Components/Dashboard/RenderWidget.razor" \
  "src/CcDashboard.Web/Components/Dashboard/ScreenFullscreenPage.razor" \
  "src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor" \
  "src/CcDashboard.Web/Resources/SharedResources.en-US.resx" \
  "src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx" \
  "src/CcDashboard.Web/Resources/SharedResources.he-IL.resx"; do
  git show HEAD:"$f" > "$f"
  echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
