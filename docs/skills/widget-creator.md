# Widget Creator Skill

> Comprehensive guide for creating RTS grid widgets (Agent Grid, Queue Grid, etc.)
> Based on proven patterns from AgentGridWidget implementation.

## 1. Widget Architecture Overview

### File Structure
```
src/CcDashboard.Web/Components/Widgets/
├── {Name}Widget.razor          # Main widget component
├── {Name}Widget.razor.css      # Scoped CSS (minimal, most styles in app.css)
```

### Core Dependencies
```razor
@using CcDashboard.Contracts.DTOs.Widgets
@using CcDashboard.Application.Queries.TenantSettings
@using Microsoft.AspNetCore.SignalR.Client
@using MediatR
@using static CcDashboard.Web.Components.Dashboard.ScreenEditorPage
@using Microsoft.Extensions.Localization
@implements IAsyncDisposable

@inject IStringLocalizer<CcDashboard.Web.Resources.SharedResources> L
@inject IJSRuntime JS
```

### Parameters
```csharp
[Parameter] public WidgetConfig? Config { get; set; }
[Parameter] public int GridId { get; set; }  // DB auto-increment ID for SignalR
```

---

## 2. RTS Database Schema

### Core Tables (per MetricType)

**RTS_Grid** — Grid definition table
```sql
Id INT IDENTITY PRIMARY KEY,
Name NVARCHAR(200),
MetricType NVARCHAR(20),  -- 'Agent' | 'Data'
TenantId UNIQUEIDENTIFIER
```

**RTS_GridMetric** — Available metrics catalog
```sql
Id INT IDENTITY PRIMARY KEY,
MetricId NVARCHAR(100),      -- e.g. 'agent_name', 'duration', 'state'
Description NVARCHAR(500),
MetricType NVARCHAR(20),     -- 'Agent' | 'Data'
ValueType NVARCHAR(20),      -- 'String' | 'Number' | 'Time'
IsActive BIT
```

**RTS_GridColumnsSet** — Saved column configurations
```sql
Id INT IDENTITY PRIMARY KEY,
GridId INT FK,
Columns NVARCHAR(MAX)  -- JSON array of column definitions
```

### MetricType Values
- `Agent` — Agent-related metrics (name, state, duration, talk%, etc.)
- `Data` — Data metrics (calls waiting, SLA, abandon rate, etc.)

### ValueType Values
- `String` — Text values (agent name, state name)
- `Number` — Numeric values (call count, percentage)
- `Time` — Duration values (HH:MM:SS format)

---

## 3. SignalR Connection Pattern

### Hub Connection Setup
```csharp
private HubConnection? _hub;
private ConnectionState _connectionState = ConnectionState.Connecting;

private async Task ConnectAsync()
{
    if (GridId == 0) return;
    
    // Get SignalR URL from tenant settings
    var settings = await Mediator.Send(new GetTenantSettingsQuery());
    var hubUrl = settings?.SignalRConnectionUrl;
    if (string.IsNullOrEmpty(hubUrl)) return;

    _hub = new HubConnectionBuilder()
        .WithUrl(hubUrl)
        .WithAutomaticReconnect()
        .Build();

    // Register data handler
    _hub.On<List<RowData>>("ReceiveGridData", OnDataReceived);
    
    // Connection state handlers
    _hub.Reconnecting += _ => { _connectionState = ConnectionState.Reconnecting; InvokeAsync(StateHasChanged); return Task.CompletedTask; };
    _hub.Reconnected += _ => { _connectionState = ConnectionState.Connected; InvokeAsync(StateHasChanged); return Task.CompletedTask; };
    _hub.Closed += _ => { _connectionState = ConnectionState.Failed; InvokeAsync(StateHasChanged); return Task.CompletedTask; };

    await _hub.StartAsync();
    _connectionState = ConnectionState.Connected;
    
    // Subscribe to grid data
    await _hub.InvokeAsync("SubscribeToGrid", GridId);
}
```

### Row Data Structure
```csharp
private class RowData
{
    public string RowId { get; set; } = "";
    public Dictionary<string, string> Metrics { get; set; } = new();
}
```

---

## 4. Color Configuration Rules

### CRITICAL: All widget elements MUST use colors from Appearance config

**Never use hardcoded colors** like `#fff`, `#333`, `bg-primary`, `text-muted` inside widget body.

### Configuration Fields
```csharp
private string? _backgroundColor;        // Widget outer background
private string? _tableBackgroundColor;   // Table/content area background
private string? _fontColor;              // Text color
```

### Style Helper Methods
```csharp
private string GetTableStyle()
{
    var styles = new List<string>();
    if (!string.IsNullOrEmpty(_tableBackgroundColor) && _tableBackgroundColor != "transparent")
        styles.Add($"background-color: {_tableBackgroundColor}");
    if (!string.IsNullOrEmpty(_fontColor))
        styles.Add($"color: {_fontColor}");
    return string.Join("; ", styles);
}

private string GetFontColorStyle()
{
    return !string.IsNullOrEmpty(_fontColor) ? $"color: {_fontColor};" : "";
}

private string GetBadgeInvertStyle()
{
    var bg = !string.IsNullOrEmpty(_fontColor) ? _fontColor : "#ffffff";
    var fg = !string.IsNullOrEmpty(_tableBackgroundColor) && _tableBackgroundColor != "transparent"
        ? _tableBackgroundColor : "#1e3a5f";
    return $"background-color: {bg}; color: {fg};";
}

private string GetFilterDropdownStyle()
{
    var bg = !string.IsNullOrEmpty(_tableBackgroundColor) && _tableBackgroundColor != "transparent"
        ? _tableBackgroundColor : "#1e3a5f";
    var fg = !string.IsNullOrEmpty(_fontColor) ? _fontColor : "#ffffff";
    return $"background: {bg}; color: {fg}; border: 1px solid {fg}33;";
}

private string GetFilterInputStyle()
{
    var bg = !string.IsNullOrEmpty(_tableBackgroundColor) && _tableBackgroundColor != "transparent"
        ? _tableBackgroundColor : "#1e3a5f";
    var fg = !string.IsNullOrEmpty(_fontColor) ? _fontColor : "#ffffff";
    return $"background: {bg}; color: {fg}; border: 1px solid {fg}66;";
}
```

### Apply to ALL Elements
- Table headers and rows: `style="@GetTableStyle()"`
- Filter dropdowns: `style="@GetFilterDropdownStyle()"`
- Filter inputs/selects: `style="@GetFilterInputStyle()"`
- Badges: `style="@GetBadgeInvertStyle()"`
- Buttons/links: `style="@GetFontColorStyle()"`
- Active filters toolbar: use GetTableStyle() with opacity
- Pagination controls: transparent background, inherit font color

---

## 5. Column Configuration

### Column Definition Class
```csharp
public class GridColumnDef
{
    public string MetricId { get; set; } = "";
    public string Name { get; set; } = "";       // Display name
    public int Width { get; set; } = 100;
    public string? ValueType { get; set; }       // From RTS_GridMetric
}
```

### Loading Columns from Config
```csharp
_columnDefs = Config.AgentGridColumnDefs?.ToList() ?? new();
// or for Queue:
_columnDefs = Config.QueueGridColumnDefs?.ToList() ?? new();
```

### Numeric Column Detection
```csharp
private bool IsNumericColumn(string metricId)
{
    var col = _columnDefs.FirstOrDefault(c => c.MetricId == metricId);
    return col?.ValueType == "Number" || col?.ValueType == "Time";
}
```

### CSS Class for Numeric Columns
```razor
<td class="text-start @(IsNumericColumn(colDef.MetricId) ? "font-monospace" : "")">
```

---

## 6. Filter System

### Filter State Class
```csharp
private class ColumnFilter
{
    public string Mode { get; set; } = "";  // "value" or "list"
    public string Operator { get; set; } = "contains";
    public string TextValue { get; set; } = "";
    public HashSet<string> SelectedValues { get; set; } = new();
}

private Dictionary<string, ColumnFilter> _columnFilters = new();
```

### Filter Operators
**Text columns:** contains, equal, startsWith, endsWith
**Numeric columns:** less, lessOrEqual, greater, greaterOrEqual, equal

### Filter Persistence (localStorage)
```csharp
private class WidgetState
{
    public int PageSize { get; set; } = 20;
    public Dictionary<string, ColumnFilterState> Filters { get; set; } = new();
}

private string GetStorageKey() => $"agentGrid_{GridId}_state";

private async Task SaveWidgetStateAsync()
{
    if (GridId == 0) return;
    var state = new WidgetState { PageSize = _pageSize, Filters = ... };
    var json = JsonSerializer.Serialize(state);
    await JS.InvokeVoidAsync("localStorage.setItem", GetStorageKey(), json);
}

private async Task LoadWidgetStateAsync()
{
    var json = await JS.InvokeAsync<string?>("localStorage.getItem", GetStorageKey());
    // Deserialize and apply...
}
```

### Load State in OnAfterRenderAsync
```csharp
protected override async Task OnAfterRenderAsync(bool firstRender)
{
    if (firstRender && GridId != 0 && !_stateLoaded)
    {
        _stateLoaded = true;
        await LoadWidgetStateAsync();
        StateHasChanged();
    }
}
```

---

## 7. Threshold System

### Threshold Definition
```csharp
private record ColumnThreshold(
    string? MatchType,   // "numeric" or "text"
    string? From,        // For numeric: lower bound
    string? To,          // For numeric: upper bound (optional)
    string? TextMatch,   // For text: exact match value
    string? TextTo,      // Reserved
    string? BgColor,     // Background color
    string? FgColor      // Text color
);
```

### MatchType Detection
Use `ValueType` from RTS_GridMetric:
- `String` → `MatchType = "text"`
- `Number` or `Time` → `MatchType = "numeric"`

### Threshold Matching Logic
```csharp
private (string? bg, string? fg) GetThresholdStyle(string metricId, string cellValue)
{
    if (!_columnThresholds.TryGetValue(metricId, out var thresholds)) return (null, null);
    
    foreach (var t in thresholds)
    {
        if (t.MatchType == "text")
        {
            if (string.Equals(cellValue, t.TextMatch, StringComparison.OrdinalIgnoreCase))
                return (t.BgColor, t.FgColor);
        }
        else // numeric
        {
            var numericValue = ParseToSeconds(cellValue); // Convert HH:MM:SS or number
            var from = ParseToSeconds(t.From);
            var to = ParseToSeconds(t.To);
            
            if (to.HasValue)
            {
                if (numericValue >= from && numericValue <= to)
                    return (t.BgColor, t.FgColor);
            }
            else
            {
                if (numericValue >= from)
                    return (t.BgColor, t.FgColor);
            }
        }
    }
    return (null, null);
}
```

### Time Parsing
```csharp
private static double? ParseToSeconds(string? value)
{
    if (string.IsNullOrEmpty(value)) return null;
    if (double.TryParse(value, out var num)) return num;
    
    // Parse HH:MM:SS or MM:SS
    var parts = value.Split(':');
    if (parts.Length == 3)
        return int.Parse(parts[0]) * 3600 + int.Parse(parts[1]) * 60 + int.Parse(parts[2]);
    if (parts.Length == 2)
        return int.Parse(parts[0]) * 60 + int.Parse(parts[1]);
    return null;
}
```

---

## 8. Pagination

### State Fields
```csharp
private int _pageSize = 20;
private int _currentPage = 1;
private int TotalPages => Math.Max(1, (int)Math.Ceiling(FilteredRowCount / (double)_pageSize));
```

### UI: Free Input Only (no dropdown)
```razor
<div class="d-flex align-items-center gap-1">
    <input type="number" class="form-control form-control-sm"
           style="width: 50px; background: transparent; border: 1px solid currentColor; color: inherit; text-align: center; @GetFontColorStyle()"
           min="1" max="500"
           value="@_pageSize"
           @onchange="OnPageSizeInputChanged"
           title="@L["Widget_RowsPerPage"]" />
    <span style="@GetFontColorStyle()">/ @filteredRows.Count</span>
</div>
```

### Page Size Change Handler (with persistence)
```csharp
private async Task OnPageSizeInputChanged(ChangeEventArgs e)
{
    if (int.TryParse(e.Value?.ToString(), out var size) && size > 0 && size <= 500)
    {
        _pageSize = size;
        _currentPage = 1;
        await SaveWidgetStateAsync();
    }
}
```

---

## 9. Configuration Modal Tabs

### Tab Structure (ScreenEditorPage.razor)
```
General     — DisplayName, GridId selection
Appearance  — Background, Table BG, Font Color, Font Size, Avatar (with BG/Font color pickers)
Thresholds  — Per-column threshold rules
Filters     — Saved filter presets (optional)
Columns     — Dual-pane column selector + ordering
Score       — Score formula rules (Agent Grid specific)
```

### Key Config Properties (WidgetConfig class)
```csharp
public string? DisplayName { get; set; }
public string? BackgroundColor { get; set; }
public string? TableBackgroundColor { get; set; }
public string? FontColor { get; set; }
public string? FontSize { get; set; }  // "small" | "medium" | "large" | "xlarge" | "xxlarge"

// Avatar (Agent Grid)
public bool ShowAvatar { get; set; }
public string? AvatarBgColor { get; set; }
public string? AvatarFontColor { get; set; }

// Score (Agent Grid)
public bool ShowScore { get; set; }
public string? ScoreStarColor { get; set; }
public List<ScoreFormulaRule>? ScoreFormula { get; set; }

// Columns
public List<AgentGridColumnDef>? AgentGridColumnDefs { get; set; }
public List<QueueGridColumnDef>? QueueGridColumnDefs { get; set; }

// Thresholds
public Dictionary<string, List<ColumnThreshold>>? ColumnThresholds { get; set; }

// RTS IDs
public int? ColumnsSetId { get; set; }
```

### Score Formula Tab
- Show only columns from `ConfigAgentColumnDefs` (configured in Columns tab)
- Use dropdown, not all metrics from DB
```razor
<select @onchange="...">
    @foreach (var col in ConfigAgentColumnDefs)
    {
        <option value="@col.MetricId">@col.Name</option>
    }
</select>
```

---

## 10. Widget Registration

### RenderWidget.razor — Widget Type Detection
```razor
@switch (Widget.Name.ToLower())
{
    case var n when n.Contains("agent") && n.Contains("grid"):
        <AgentGridWidget @key="Widget.GridId" Config="Widget.Config" GridId="Widget.GridId" />
        break;
    case var n when n.Contains("queue") && n.Contains("grid"):
        <QueueGridWidget @key="Widget.GridId" Config="Widget.Config" GridId="Widget.GridId" />
        break;
    // ... other widget types
}
```

### ScreenFullscreenPage.razor — View Mode
**CRITICAL:** Always pass `GridId` when creating PlacedWidget:
```csharp
PlacedWidgets.Add(new ScreenEditorPage.PlacedWidget
{
    Id = w.Id,
    GridId = w.GridId,  // <-- REQUIRED for SignalR connection
    CatalogItemId = w.WidgetCatalogItemId,
    // ...
});
```

---

## 11. RTL/LTR Support

### Use CSS Logical Properties
```css
/* Good */
text-align: start;        /* not left */
text-align: end;          /* not right */
margin-inline-start: 1em; /* not margin-left */
padding-inline-end: 1em;  /* not padding-right */
inset-inline-start: 0;    /* not left: 0 */

/* Table alignment */
.text-start { text-align: start; }
```

### Bootstrap 5 RTL
- Include `bootstrap.rtl.min.css` for RTL locales
- Set `dir="rtl"` on `<html>` element

---

## 12. Localization

### Resource Keys Pattern
```
Widget_{WidgetType}_{Feature}
Widget_ActiveFilters
Widget_ClearAllFilters
Widget_RowsPerPage
Widget_Live
Widget_Disconnected
```

### Usage
```razor
@L["Widget_ActiveFilters"]
```

---

## 13. Error States

### Connection States
```csharp
private enum ConnectionState { Connecting, Connected, Reconnecting, Failed }
```

### UI for Each State
```razor
@if (GridId == 0)
{
    <div>@L["Widget_SaveConfigFirst"]</div>
}
else if (_connectionState == ConnectionState.Connecting)
{
    <div><span class="spinner-border"></span> @L["Widget_Connecting"]</div>
}
else if (_connectionState == ConnectionState.Failed)
{
    <div>@L["Widget_ConnectionFailed"] <button @onclick="ReconnectAsync">@L["Widget_Retry"]</button></div>
}
else if (_rows.Count == 0)
{
    <div>@L["Widget_NoAgents"]</div>
}
```

---

## 14. Checklist for New Widget

1. [ ] Create `{Name}Widget.razor` with correct dependencies
2. [ ] Add `GridId` and `Config` parameters
3. [ ] Implement SignalR connection with state handling
4. [ ] Use config colors for ALL UI elements (no hardcoded colors)
5. [ ] Implement column configuration loading
6. [ ] Add filter system with localStorage persistence
7. [ ] Add pagination with free input
8. [ ] Implement threshold system with MatchType detection
9. [ ] Add to `RenderWidget.razor` switch statement
10. [ ] Add to `ScreenEditorPage.razor` modal tabs
11. [ ] Ensure `GridId` is passed in `ScreenFullscreenPage.razor`
12. [ ] Add localization keys to all .resx files
13. [ ] Test RTL layout

---

## 15. Queue Grid Implementation

Queue Grid differs from Agent Grid — it has **row-based configuration** where each row represents a Business Unit.

### 15.1 Row Definition Structure
```csharp
public class QueueGridRowDef
{
    public string LocalId { get; set; } = "";        // Client-side UUID for new rows
    public int? DbRowId { get; set; }                // RTS_GridRow.Id after save
    public int? BusinessUnitId { get; set; }         // FK to business_units table
    public string? BusinessUnitName { get; set; }    // Display name
    public string? BackgroundColor { get; set; }     // Row-level override
    public string? FontColor { get; set; }           // Row-level override
    public Dictionary<string, int?> CellIds { get; set; } = new();  // MetricId → RTS_GridCell.Id
}
```

### 15.2 RTS Tables for Queue Grid

**RTSGrid_Grid** — Grid header
```sql
Id INT IDENTITY PRIMARY KEY,
DashboardWidgetId UNIQUEIDENTIFIER,
MetricType NVARCHAR(20) DEFAULT 'Agent'
```

**RTSGrid_Column** — Column definitions (shared across rows)
```sql
Id INT IDENTITY PRIMARY KEY,
GridId INT FK → RTSGrid_Grid,
Name NVARCHAR(200),
MetricId NVARCHAR(100),
ColumnNumber INT
```

**RTSGrid_Row** — Data rows (one per Business Unit)
```sql
Id INT IDENTITY PRIMARY KEY,
GridId INT FK → RTSGrid_Grid,
BusinessUnitId INT NULL,
RowNumber INT
```

**RTSGrid_Cell** — Individual cells (intersection of row × column)
```sql
Id INT IDENTITY PRIMARY KEY,
GridId INT FK,
RowId INT FK → RTSGrid_Row,
ColumnId INT FK → RTSGrid_Column
```

### 15.3 Cascade Delete Pattern
All child tables have `ON DELETE CASCADE` from GridId:
- Delete Grid → auto-deletes all Columns, Rows, Cells
- Simplifies cleanup when widget is removed

### 15.4 SaveQueueGridRtsCommand Pattern
```csharp
public record SaveQueueGridRtsCommand(
    Guid DashboardWidgetId,
    int? ExistingGridId,
    List<QueueGridColumnInput> Columns,
    List<QueueGridRowInput> Rows
) : IRequest<Result<SaveQueueGridRtsResult>>;

public record SaveQueueGridRtsResult(
    int GridId,
    int HeaderRowId,
    Dictionary<string, int> SavedColumnIds,      // LocalId → DbId
    Dictionary<string, int> SavedRowIds,         // LocalId → DbId  
    Dictionary<string, Dictionary<string, int>> SavedCellIds  // RowLocalId → {ColLocalId → CellId}
);
```

### 15.5 Row Configuration UI
```razor
@foreach (var row in ConfigQueueGridRows)
{
    <div class="row-config-item">
        <select @bind="row.BusinessUnitId">
            @foreach (var bu in AvailableBusinessUnits)
            {
                <option value="@bu.Id">@bu.Name</option>
            }
        </select>
        <ColorPicker @bind-Value="row.BackgroundColor" />
        <ColorPicker @bind-Value="row.FontColor" />
        <button @onclick="() => RemoveRow(row)">×</button>
    </div>
}
<button @onclick="AddRow">+ Add Row</button>
```

### 15.6 SignalR Data Reception
Queue Grid receives data per Business Unit:
```csharp
_hub.On<List<QueueRowData>>("ReceiveQueueGridData", data =>
{
    foreach (var incoming in data)
    {
        var existingRow = _rows.FirstOrDefault(r => r.BusinessUnitId == incoming.BusinessUnitId);
        if (existingRow != null)
            existingRow.Metrics = incoming.Metrics;
    }
    InvokeAsync(StateHasChanged);
});
```

---

## 16. Dark Mode Implementation

### 16.1 Two-Column Color Configuration

Widget config stores **both** Light Mode and Dark Mode colors:
```csharp
public class WidgetConfig
{
    // Light Mode colors
    public string? BackgroundColor { get; set; }
    public string? FontColor { get; set; }
    public string? TableBackgroundColor { get; set; }
    
    // Dark Mode colors
    public string? DarkBackgroundColor { get; set; }
    public string? DarkFontColor { get; set; }
    public string? DarkTableBackgroundColor { get; set; }
}
```

### 16.2 Configuration UI — Dual Columns
```razor
<div class="color-settings-dual">
    <div class="color-dual-header">
        <span class="color-setting-label"></span>
        <span class="color-mode-label">Light Mode</span>
        <span class="color-mode-label">Dark Mode</span>
    </div>
    
    <div class="color-setting-row-dual">
        <span class="color-setting-label">Widget Background</span>
        <ColorPicker @bind-Value="ConfigBackgroundColor" />
        <ColorPicker @bind-Value="ConfigDarkBackgroundColor" />
    </div>
    <!-- Repeat for FontColor, TableBackgroundColor -->
</div>
```

### 16.3 CSS for Dual-Column Layout
```css
.color-settings-dual {
    display: flex;
    flex-direction: column;
    gap: var(--sp-2);
}

.color-dual-header,
.color-setting-row-dual {
    display: grid;
    grid-template-columns: 140px 1fr 1fr;
    gap: var(--sp-3);
    align-items: center;
}

.color-mode-label {
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    color: var(--clr-text-muted);
}
```

### 16.4 DarkMode Parameter — CRITICAL

**Every widget MUST receive DarkMode parameter:**
```csharp
[Parameter] public bool DarkMode { get; set; }
```

**Parent components MUST pass it:**
```razor
<!-- ScreenEditorPage.razor -->
<RenderWidget Widget="widget" DarkMode="_darkMode" />

<!-- ScreenFullscreenPage.razor -->
<RenderWidget Widget="widget" DarkMode="_darkMode" />
```

### 16.5 Effective Color Properties Pattern

**Never use hardcoded dark mode colors.** Use computed properties:
```csharp
// Load from config with defaults
private string _darkBackgroundColor = "#333333";
private string _darkFontColor = "#FFFFFF";
private string _darkTableBackgroundColor = "#333333";

// Effective properties — check DarkMode at render time
private string EffectiveBackgroundColor 
    => DarkMode ? _darkBackgroundColor : (_backgroundColor ?? "");
    
private string EffectiveFontColor 
    => DarkMode ? _darkFontColor : (_fontColor ?? "");
    
private string EffectiveTableBackgroundColor 
    => DarkMode ? _darkTableBackgroundColor : (_tableBackgroundColor ?? "");
```

### 16.6 Apply Config — Load Dark Mode Colors
```csharp
private void ApplyConfig()
{
    if (Config is null) return;
    
    // Light mode
    _backgroundColor = Config.BackgroundColor;
    _fontColor = Config.FontColor;
    _tableBackgroundColor = Config.TableBackgroundColor;
    
    // Dark mode (with fallback defaults)
    _darkBackgroundColor = Config.DarkBackgroundColor ?? "#333333";
    _darkFontColor = Config.DarkFontColor ?? "#FFFFFF";
    _darkTableBackgroundColor = Config.DarkTableBackgroundColor ?? "#333333";
}
```

### 16.7 Update Style Methods to Use Effective Colors
```csharp
private string GetWidgetStyle()
{
    var styles = new List<string>();
    var bg = EffectiveBackgroundColor;  // <-- Use Effective, not raw
    var fg = EffectiveFontColor;
    
    if (!string.IsNullOrEmpty(bg))
        styles.Add($"background-color: {bg}");
    if (!string.IsNullOrEmpty(fg))
        styles.Add($"color: {fg}");
    return string.Join("; ", styles);
}

private string GetTableStyle()
{
    var styles = new List<string>();
    var tableBg = EffectiveTableBackgroundColor;  // <-- Use Effective
    var fg = EffectiveFontColor;
    
    if (!string.IsNullOrEmpty(tableBg) && tableBg != "transparent")
        styles.Add($"background-color: {tableBg}");
    if (!string.IsNullOrEmpty(fg))
        styles.Add($"color: {fg}");
    return string.Join("; ", styles);
}
```

### 16.8 Common Dark Mode Mistake

**WRONG — Widget doesn't respond to dark mode toggle:**
```razor
<!-- Missing DarkMode parameter! -->
<RenderWidget Widget="widget" />
```

**CORRECT:**
```razor
<RenderWidget Widget="widget" DarkMode="_darkMode" />
```

If dark mode toggle doesn't work, check:
1. Is `DarkMode` parameter passed from parent?
2. Is `_darkMode` variable in parent component?
3. Does widget use `Effective*` properties in style methods?

---

## 17. RTS Grid Patterns and Pitfalls

This section covers the backend RTS table lifecycle — what the CC backend reads from
`RTSGrid_*` / `RTSUserGrid_*` tables and how the shell must write to them.

### 17.1 Type A vs Type B

| | Type A — Agent Grid | Type B — Queue Grid / Data Slot |
|---|---|---|
| Tables | `RTSUserGrid_Grid`, `RTSUserGrid_ColumnsSet`, `RTSUserGrid_Column` | `RTSGrid_Grid`, `RTSGrid_Column`, `RTSGrid_Row`, `RTSGrid_Cell` |
| Command | `SaveAgentGridRtsCommand` | `SaveQueueGridRtsCommand` / `SaveDataSlotRtsCommand` |
| ConfigJson key | `RtsUserGridId` (Grid PK) | `DataSlotGridId` / `GridId` (Grid PK) |
| Delete command | `DeleteAgentGridRtsCommand` | `DeleteQueueGridRtsCommand` |
| Subtype | Full grid (columns only) | Full grid (cols + rows + cells) or 1×1×1 (Data Slot) |

### 17.2 RtsUserGridId vs DashboardWidget.GridId — CRITICAL distinction

`PlacedWidget.GridId` is the **DB auto-increment** from `dashboard_widgets.GridId` (values like 14, 15, 16).
`Config.RtsUserGridId` is the **RTS primary key** from `RTSUserGrid_Grid.GridId` (independent sequence).

These are completely different numbers and must **never** be confused:

```csharp
// ❌ WRONG — was the pre-#18 bug: creates a new RTS record every save
await _mediator.Send(new SaveAgentGridRtsCommand(PlacedWidget.GridId, ...));

// ✅ CORRECT — 0 = INSERT new grid on first save; existing ID = UPDATE
await _mediator.Send(new SaveAgentGridRtsCommand(Config.RtsUserGridId ?? 0, ...));
// Then store the returned RTS ID back into Config, NOT into PlacedWidget.GridId:
Config.RtsUserGridId = result.GridId;
```

**Where the bug manifests:** Without this fix, every "Save config" click creates a new
`RTSUserGrid_Grid` row instead of updating the existing one. The CC platform sees a new grid
each time and loses the previous agent-grid state.

### 17.3 Data Slot as 1×1×1 subtype of RTSGrid_*

The Data Slot widget reuses the Queue Grid's RTSGrid table family but with exactly one of each:

```
RTSGrid_Grid (1 row)
  └── RTSGrid_Column  ColumnNumber=1, MetricId = Config.DataSlotMetricId
        └── RTSGrid_Row     RowNumber=1, BusinessUnitId = Config.DataSlotBusinessUnitId
              └── RTSGrid_Cell  CellType="Data", Value = MetricId
```

ConfigJson carries: `DataSlotGridId`, `DataSlotColumnId`, `DataSlotRowId`, `DataSlotCellId`
(four separate `int?` fields — **not** a dictionary).

### 17.4 SaveDataSlotRtsCommand pattern

```csharp
public record SaveDataSlotRtsCommand(
    int? GridId,          // null = create; existing = update grid header only
    int? ColumnId,        // null = create; existing = update
    int? RowId,           // null = create; existing = update
    int? CellId,          // null = create; existing = update
    string Title,
    string MetricId,
    int? BusinessUnitId)
    : IRequest<SaveDataSlotRtsResult>;

public record SaveDataSlotRtsResult(int GridId, int ColumnId, int RowId, int CellId);
```

Usage in `ScreenEditorPage.SaveWidgetConfig()`:

```csharp
var result = await Mediator.Send(new SaveDataSlotRtsCommand(
    GridId:         Config.DataSlotGridId,
    ColumnId:       Config.DataSlotColumnId,
    RowId:          Config.DataSlotRowId,
    CellId:         Config.DataSlotCellId,
    Title:          Config.DisplayName ?? "Data Slot",
    MetricId:       Config.DataSlotMetricId ?? "",
    BusinessUnitId: Config.DataSlotBusinessUnitId));

Config.DataSlotGridId   = result.GridId;
Config.DataSlotColumnId = result.ColumnId;
Config.DataSlotRowId    = result.RowId;
Config.DataSlotCellId   = result.CellId;
```

### 17.5 Existence-check-before-UPDATE pattern

`SaveDataSlotRtsCommand` does **not** blindly trust the ConfigJson IDs it receives.
Before every UPDATE it re-queries the DB:

```csharp
// Guard against stale IDs after dashboard clone / restore
var existingCol = columnId.HasValue
    ? await db.RtsGridColumns.FirstOrDefaultAsync(c => c.Id == columnId.Value && c.GridId == grid.Id)
    : null;

if (existingCol is null)
{
    // INSERT new column
    existingCol = new RtsGridColumn { GridId = grid.Id, ColumnNumber = 1, MetricId = metricId };
    db.RtsGridColumns.Add(existingCol);
}
else
{
    // UPDATE existing column
    existingCol.MetricId = metricId;
}
await db.SaveChangesAsync(ct);
```

Apply the same pattern for Row and Cell. This prevents orphaned or duplicated RTS records
when a dashboard is cloned and the ConfigJson IDs point to another tenant's records.

### 17.6 Deferred deletion pattern

RTS records are **not** deleted immediately when the user removes a widget in the editor.
They are added to `WidgetsPendingRtsDeletion` (a `List<PlacedWidget>` on `ScreenEditorPage`):

```csharp
private void ConfirmDeleteWidget(PlacedWidget widget)
{
    // Queue for deferred RTS deletion
    if (widget.Config?.RtsUserGridId > 0 || widget.Config?.DataSlotGridId > 0
        || widget.Config?.GridId > 0)
        WidgetsPendingRtsDeletion.Add(widget);

    Widgets.Remove(widget);
    // Note: RTS records still exist in DB until SaveLayout is called
}
```

On `SaveLayout`:

```csharp
foreach (var w in WidgetsPendingRtsDeletion)
{
    if (IsAgentGridWidget(w.OriginalWidgetName) && w.Config?.RtsUserGridId > 0)
        await Mediator.Send(new DeleteAgentGridRtsCommand(w.Config.RtsUserGridId.Value));
    else if ((IsQueueGridWidget(w.OriginalWidgetName) || IsDataSlotWidget(w.OriginalWidgetName))
             && (w.Config?.GridId > 0 || w.Config?.DataSlotGridId > 0))
    {
        var gridId = IsDataSlotWidget(w.OriginalWidgetName)
            ? w.Config!.DataSlotGridId!.Value
            : w.Config!.GridId!.Value;
        await Mediator.Send(new DeleteQueueGridRtsCommand(gridId));
    }
}
WidgetsPendingRtsDeletion.Clear();
```

**Why deferred?** If the user removes a widget and then immediately undoes (re-adds it),
the RTS record is still there and can be reused without a re-create round-trip.

### 17.7 Cascade delete

Both delete commands delete only the root Grid record.
Child records (`Column`, `Row`, `Cell`, `ColumnsSet`) are removed by `ON DELETE CASCADE`
constraints defined by the CC backend. **Do not** issue separate DELETE commands for children.

### 17.8 IsXxxWidget helper

`ScreenEditorPage` uses `OriginalWidgetName` (not `DisplayName`) for widget type detection:

```csharp
private static bool IsAgentGridWidget(string? name) =>
    name?.Contains("agent", StringComparison.OrdinalIgnoreCase) == true &&
    name.Contains("grid",  StringComparison.OrdinalIgnoreCase);

private static bool IsQueueGridWidget(string? name) =>
    name?.Contains("queue", StringComparison.OrdinalIgnoreCase) == true &&
    name.Contains("grid",   StringComparison.OrdinalIgnoreCase);

private static bool IsDataSlotWidget(string? name) =>
    name?.Contains("data", StringComparison.OrdinalIgnoreCase) == true &&
    name.Contains("slot",  StringComparison.OrdinalIgnoreCase);
```

`OriginalWidgetName` is set once on widget creation from the catalogue entry name and
never changed by renaming. This ensures type detection survives display name edits.

### 17.9 ConfigJson round-trip rule

All four `DataSlot*Id` fields and `RtsUserGridId` are `int?` and are nullable by default.
When `ConfigJson` is deserialised from the DB, missing fields default to `null` (not zero).

**Always check for null before sending a command:**
```csharp
// ✅ Treat null and 0 the same way — both mean "no existing RTS record"
var existingGridId = Config.RtsUserGridId ?? 0;
```

**Never** persist `GridId = 0` to ConfigJson — `null` is the canonical "not yet created" state.
After a successful save, the command returns the real integer ID; store that value immediately.

### 17.10 API hook (dual-write)

Every RTS save command calls `IConfigurationApiHook.NotifyAsync` after the DB transaction:

| Command | Event string |
|---|---|
| `SaveAgentGridRtsCommand` | `"AgentGrid.Saved"` |
| `SaveQueueGridRtsCommand` | `"QueueGridRts.Saved"` |
| `SaveDataSlotRtsCommand`  | `"DataSlotRts.Saved"` |

Current implementation (`NoOpConfigurationApiHook`) only logs. Real HTTP call pending
backend API docs (OQ-W-01).

### 17.11 Checklist for a new RTS save command

When adding a new widget type that requires RTS persistence:

- [ ] Identify table family: Type A (`RTSUserGrid_*`) or Type B (`RTSGrid_*`)
- [ ] Add `int? RtsXxxId` fields to `WidgetConfig` (nullable, never default to 0)
- [ ] Create `SaveXxxRtsCommand` + handler (existence-check-before-UPDATE for Type B children)
- [ ] Create `DeleteXxxRtsCommand` + handler (root-only delete; cascade handles children)
- [ ] Wire `SaveXxxRtsCommand` into `ScreenEditorPage.SaveWidgetConfig()` with null-coalesce
- [ ] Store returned IDs back into `Config` fields (not into `PlacedWidget.GridId`)
- [ ] Wire `ConfirmDeleteWidget` to queue the widget in `WidgetsPendingRtsDeletion`
- [ ] Wire `SaveLayout` to call `DeleteXxxRtsCommand` from `WidgetsPendingRtsDeletion`
- [ ] Wire `OpenWidgetConfig` to load all ID fields from `Config`
- [ ] Add null-reset for all RTS ID fields in template-drop logic
- [ ] Add `IsXxxWidget()` helper using `OriginalWidgetName`
- [ ] Add `IConfigurationApiHook.NotifyAsync("Xxx.Saved", ...)` call in the handler
- [ ] Add event string to `IConfigurationApiHook` events list in `widget-framework.md` §5.1
- [ ] Write unit test for the command handler (existence-check paths: all-null, all-present, partial)

---

## 18. Updated Checklist for New Widget

1. [ ] Create `{Name}Widget.razor` with correct dependencies
2. [ ] Add `GridId`, `Config`, and **`DarkMode`** parameters
3. [ ] Implement SignalR connection with state handling
4. [ ] **Load dark mode colors in ApplyConfig()**
5. [ ] **Use Effective* properties for ALL color references**
6. [ ] Use config colors for ALL UI elements (no hardcoded colors)
7. [ ] Implement column configuration loading
8. [ ] Add filter system with localStorage persistence
9. [ ] Add pagination with free input
10. [ ] Implement threshold system with MatchType detection
11. [ ] Add to `RenderWidget.razor` — **pass DarkMode**
12. [ ] Add to `ScreenEditorPage.razor` modal tabs — **pass DarkMode**
13. [ ] Ensure `GridId` is passed in `ScreenFullscreenPage.razor`
14. [ ] Add localization keys to all .resx files
15. [ ] Test RTL layout
16. [ ] **Test dark mode toggle in both editor and fullscreen**

**RTS persistence (if widget requires backend data storage):**

17. [ ] Identify RTS table family (Type A `RTSUserGrid_*` or Type B `RTSGrid_*`) — see §17.1
18. [ ] Add `int? RtsXxxId` fields to `WidgetConfig` (nullable; never default to 0)
19. [ ] Create `SaveXxxRtsCommand` + handler; use existence-check pattern for Type B — see §17.5
20. [ ] Create `DeleteXxxRtsCommand` + handler (delete root only; cascade handles children)
21. [ ] Wire `SaveXxxRtsCommand` into `SaveWidgetConfig()` using `Config.RtsXxxId ?? 0`
22. [ ] Store returned IDs back into `Config.*Id` fields (not into `PlacedWidget.GridId`)
23. [ ] Wire deferred deletion: `ConfirmDeleteWidget` → `WidgetsPendingRtsDeletion`; `SaveLayout` → delete command
24. [ ] Verify `OpenWidgetConfig` loads all RTS ID fields; template-drop resets all IDs to null
