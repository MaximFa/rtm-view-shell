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
MetricType NVARCHAR(50),  -- 'Agent' | 'Queue' | etc.
TenantId UNIQUEIDENTIFIER
```

**RTS_GridMetric** — Available metrics catalog
```sql
Id INT IDENTITY PRIMARY KEY,
MetricId NVARCHAR(100),      -- e.g. 'agent_name', 'duration', 'state'
Description NVARCHAR(500),
MetricType NVARCHAR(50),     -- 'Agent' | 'Queue'
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
- `Queue` — Queue metrics (calls waiting, SLA, abandon rate, etc.)

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
MetricType NVARCHAR(50) DEFAULT 'Queue'
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

### 15.6 API Hook After DB Operations — CRITICAL

**Every widget Save/Delete command MUST call API hook AFTER database operations.**

This is a placeholder for future CC platform integration (REST or SignalR call — TBD).

**Save Command Pattern:**
```csharp
public async Task<SaveResult> Handle(SaveCommand cmd, CancellationToken ct)
{
    // 1. Database operations
    var gridId = await rtsRepository.InsertGridAsync(...);
    var columnIds = await rtsRepository.InsertColumnsAsync(...);
    // ... all DB work
    
    // 2. API hook AFTER DB — always at the end
    // TODO: replace NoOp with real REST or SignalR call to CC platform — TBD
    await apiHook.NotifyAsync("WidgetType.Saved", new
    {
        GridId = gridId,
        Title = cmd.Title,
        ColumnCount = savedColumnIds.Count,
        RowCount = savedRowIds.Count,
        // Include all IDs that external system needs
    }, ct);
    
    return result;
}
```

**Delete Command Pattern:**
```csharp
public async Task<bool> Handle(DeleteCommand cmd, CancellationToken ct)
{
    // 1. Database delete (CASCADE handles children)
    await rtsRepository.DeleteGridAsync(cmd.GridId, ct);
    
    // 2. API hook AFTER DB
    // TODO: replace NoOp with real REST or SignalR call to CC platform — TBD
    await apiHook.NotifyAsync("WidgetType.Deleted", new { GridId = cmd.GridId }, ct);
    
    return true;
}
```

**IConfigurationApiHook Interface:**
```csharp
public interface IConfigurationApiHook
{
    Task NotifyAsync(string eventType, object payload, CancellationToken ct = default);
}
```

Current implementation is `NoOpConfigurationApiHook` (logs only). Will be replaced with real HTTP/SignalR client when CC platform API is available.

### 15.7 SignalR Data Reception
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

## 17. Widget Header Color Configuration

### 17.1 Header Color Properties

Widget headers (toolbar with gear/delete icons) support custom colors for both light and dark modes:

```csharp
public class WidgetConfig
{
    // Light Mode header colors
    public string? HeaderBackgroundColor { get; set; }  // "default" = use CSS
    public string? HeaderFontColor { get; set; }        // "default" = use CSS
    
    // Dark Mode header colors
    public string? DarkHeaderBackgroundColor { get; set; }
    public string? DarkHeaderFontColor { get; set; }
}
```

### 17.2 Special "default" Value

When `HeaderBackgroundColor` or `HeaderFontColor` is `"default"`:
- **Don't apply inline style** — let CSS defaults control the appearance
- This preserves the original widget header styling from `app.css`

### 17.3 Configuration Variables (ScreenEditorPage)

```csharp
private string ConfigHeaderBackgroundColor = "default";
private string ConfigHeaderFontColor = "default";
private string ConfigDarkHeaderBackgroundColor = "default";
private string ConfigDarkHeaderFontColor = "default";
```

### 17.4 Color Palette with Default Option

Header color palettes include "Default" as the first option:

```csharp
private (string Name, string Value)[] BuildHeaderBackgroundColors()
{
    var colors = new List<(string, string)> { ("Default", "default"), ("Transparent", "transparent") };
    colors.AddRange(StandardBgColors);
    return colors.ToArray();
}

private (string Name, string Value)[] BuildHeaderFontColors()
{
    var colors = new List<(string, string)> { ("Default", "default") };
    colors.AddRange(StandardFontColors);
    return colors.ToArray();
}
```

### 17.5 GetWidgetHeaderStyle Method

Generates inline styles for the widget header, respecting "default" values:

```csharp
private string GetWidgetHeaderStyle(PlacedWidget widget)
{
    var styles = new List<string>();
    var config = widget.Config;

    // Get appropriate colors based on dark mode
    var bgColor = _darkMode ? config.DarkHeaderBackgroundColor : config.HeaderBackgroundColor;
    var fontColor = _darkMode ? config.DarkHeaderFontColor : config.HeaderFontColor;

    // Only apply if not "default" (which means use CSS defaults)
    if (!string.IsNullOrEmpty(bgColor) && !string.Equals(bgColor, "default", StringComparison.OrdinalIgnoreCase))
    {
        styles.Add($"background-color: {bgColor}");
    }

    if (!string.IsNullOrEmpty(fontColor) && !string.Equals(fontColor, "default", StringComparison.OrdinalIgnoreCase))
    {
        styles.Add($"color: {fontColor}");
    }

    return styles.Count > 0 ? string.Join("; ", styles) + ";" : "";
}
```

### 17.6 Apply Header Style in Widget Markup

```razor
<div class="widget-header widget-drag-handle"
     style="@GetWidgetHeaderStyle(widget)"
     @onmousedown="async e => await StartMove(widget.Id, e)">
    <!-- Header content (drag icon, gear, delete) -->
</div>
```

### 17.7 Configuration UI — Header Section

Add to Appearance tab, after existing color settings:

```razor
<!-- Widget Header -->
<div class="color-setting-row-dual">
    <span class="color-setting-label">Header Background</span>
    <ColorPicker @bind-Value="ConfigHeaderBackgroundColor" 
                 Palette="HeaderBackgroundColors" />
    <ColorPicker @bind-Value="ConfigDarkHeaderBackgroundColor" 
                 Palette="HeaderBackgroundColors" />
</div>
<div class="color-setting-row-dual">
    <span class="color-setting-label">Header Font</span>
    <ColorPicker @bind-Value="ConfigHeaderFontColor" 
                 Palette="HeaderFontColors" />
    <ColorPicker @bind-Value="ConfigDarkHeaderFontColor" 
                 Palette="HeaderFontColors" />
</div>
```

### 17.8 Color Swatch Display for "default"

The `GetColorStyle` method handles "default" with a special pattern:

```csharp
private string GetColorStyle(string colorValue)
{
    if (string.Equals(colorValue, "default", StringComparison.OrdinalIgnoreCase))
    {
        // Diagonal stripe pattern indicating "use CSS default"
        return "background: linear-gradient(135deg, #e0e0e0 25%, #f5f5f5 25%, #f5f5f5 50%, #e0e0e0 50%, #e0e0e0 75%, #f5f5f5 75%) !important; background-size: 8px 8px !important;";
    }
    if (colorValue == "transparent")
        return "background: linear-gradient(45deg, #ccc 25%, transparent 25%, transparent 75%, #ccc 75%), linear-gradient(45deg, #ccc 25%, transparent 25%, transparent 75%, #ccc 75%); background-size: 8px 8px; background-position: 0 0, 4px 4px;";
    return $"background-color: {colorValue};";
}
```

---

## 18. Configuration UI Guidelines — CRITICAL

### 18.1 All Dropdowns Must Be Searchable

**Never use plain `<select>` for lists with more than 5 items.** Always use searchable dropdown pattern:

```razor
<div class="searchable-select">
    <input type="text" class="form-control" 
           placeholder="@L["Common_Search"]..."
           value="@SearchText"
           @oninput="OnSearchInput"
           @onfocus="() => DropdownOpen = true"
           @onblur="OnSearchBlur" />
    @if (DropdownOpen)
    {
        <div class="searchable-dropdown">
            <div class="dropdown-item @(SelectedValue == null ? "active" : "")"
                 @onmousedown="() => SelectItem(null)"
                 @onmousedown:preventDefault="true">
                <em>@L["Common_All"]</em>
            </div>
            @foreach (var item in FilteredItems)
            {
                <div class="dropdown-item @(SelectedValue == item.Id ? "active" : "")"
                     @onmousedown="() => SelectItem(item)"
                     @onmousedown:preventDefault="true">
                    @item.DisplayName
                </div>
            }
        </div>
    }
</div>
```

### 18.2 Metric Display — Description Only

**In all metric dropdowns and lists, show ONLY the Description field.**

```razor
<!-- CORRECT -->
@foreach (var metric in FilteredMetrics)
{
    <div class="dropdown-item">@metric.Description</div>
}

<!-- WRONG — never show MetricId to users -->
@foreach (var metric in FilteredMetrics)
{
    <option value="@metric.MetricId">@metric.MetricId (@metric.Description)</option>
}
```

The `MetricId` is internal technical identifier — users should only see human-readable `Description`.

### 18.3 CSS for Searchable Dropdowns

```css
.searchable-select {
    position: relative;
}

.searchable-dropdown {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    max-height: 200px;
    overflow-y: auto;
    background: var(--clr-surface);
    border: 1px solid var(--clr-border);
    border-radius: var(--r-sm);
    z-index: 1050;
    box-shadow: var(--shadow-md);
}

.searchable-dropdown .dropdown-item {
    padding: 0.5rem 0.75rem;
    cursor: pointer;
}

.searchable-dropdown .dropdown-item:hover,
.searchable-dropdown .dropdown-item.active {
    background: var(--clr-primary-subtle);
}
```

---

## 19. Updated Checklist for New Widget

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
14. [ ] **Add API hook calls in Save/Delete commands (after DB operations)**
15. [ ] Add localization keys to all .resx files
16. [ ] Test RTL layout
17. [ ] **Test dark mode toggle in both editor and fullscreen**
18. [ ] **All config dropdowns are searchable**
19. [ ] **Metric lists show Description only (not MetricId)**
20. [ ] **Header colors configurable with "default" option (uses CSS defaults)**


---

## 20. Chart / Analytics Widget Architecture (DayTrend Pattern)

This architecture applies to **historical data widgets** that query PostgreSQL functions
rather than connecting to a real-time SignalR hub. The canonical example is **DayTrend**
(intraday call volume chart). Use this pattern for any widget that:

- Renders historical / aggregated data (charts, KPI cards, trend lines)
- Uses `BackendEmulationDbContext` PostgreSQL functions as the data source
- Does **not** need a real-time push connection

### 20.1 Architecture Comparison

| Concern | Grid Widget (§1–19) | Chart/Analytics Widget (this section) |
|---|---|---|
| Data source | SignalR hub → `ReceiveGridData` | PostgreSQL function via `BackendEmulationDbContext` |
| Push / pull | Push (server initiates) | Pull (widget polls on a timer) |
| GridId | Required (FK to `RTSGrid_Grid`) | **Not used** |
| RTS tables | `RTSGrid_*` | None — functions only |
| Save command | `SaveXxxRtsCommand` | Not needed |
| C# data shape | `Dictionary<string, string>` per row | `IReadOnlyList<DayTrendIntervalData>` |
| Chart rendering | DOM table | Chart.js via `IJSRuntime` / `window.dayTrendChart.*` |

### 20.2 File Structure

```
src/CcDashboard.Web/Components/Widgets/
├── DayTrendWidget.razor            # Chart widget component
├── DayTrendWidget.razor.css        # Scoped styles (minimal)

src/CcDashboard.Application/Queries/Widgets/
├── DayTrendQueryHandler.cs         # MediatR handler: calls both PG functions, merges result

src/CcDashboard.Infrastructure/Persistence/Migrations/
├── YYYYMMDD_AddDayTrendFunctions.cs  # EF migration: CREATE OR REPLACE FUNCTION ...
```

### 20.3 Parameters

```csharp
// No GridId — chart widget does not use RTS tables
[Parameter] public WidgetConfig? Config { get; set; }
[Parameter] public bool DarkMode { get; set; }
// GridId deliberately omitted — use WidgetInstanceId (Guid) for localStorage key
[Parameter] public Guid WidgetInstanceId { get; set; }
```

### 20.4 Data Flow

```
OnInitializedAsync
  └─▶ ParseConfig()           // deserialize ConfigJson → local fields
  └─▶ LoadDataAsync()         // send DayTrendQuery via MediatR
        └─▶ DayTrendQueryHandler
              ├─▶ fn_daytrendinteractions(...)   → narrow rows (interval_start, metric_id, value)
              ├─▶ fn_daytrendagentstatus(...)    → narrow rows (conditional — only if agent metrics enabled)
              └─▶ merge: .Concat().GroupBy(IntervalStart) → IReadOnlyList<DayTrendIntervalData>
  └─▶ RenderChartAsync()      // JS interop: window.dayTrendChart.render(id, labels, datasets, options)

Timer (refreshIntervalSeconds > 0):
  └─▶ LoadDataAsync() → RenderChartAsync()
```

### 20.5 Key C# Records

```csharp
public record DayTrendMetricRow(DateTime IntervalStart, string MetricId, double? Value);

public record DayTrendIntervalData(
    DateTime IntervalStart,
    IReadOnlyDictionary<string, double?> Metrics);

public record DayTrendResult(
    IReadOnlyList<DayTrendIntervalData> Intervals,
    bool IsNoQueues = false)
{
    public static DayTrendResult NoQueues() =>
        new(Array.Empty<DayTrendIntervalData>(), true);
}
```

### 20.6 JS Interop Contract

```javascript
// Register in wwwroot/js/day-trend-chart.js (loaded in App.razor)
window.dayTrendChart = {
    render(elementId, labels, datasets, options) { /* Chart.js init / update */ },
    destroy(elementId) { /* Chart.js destroy */ }
};
```

```csharp
// Widget component
await JS.InvokeVoidAsync("dayTrendChart.render", _chartElementId, labels, datasets, options);

public async ValueTask DisposeAsync()
{
    _timer?.Dispose();
    await JS.InvokeVoidAsync("dayTrendChart.destroy", _chartElementId);
}
```

### 20.7 PostgreSQL Function Pattern (Narrow Format)

Both functions return `(interval_start timestamptz, metric_id text, value double precision)`.
One row per metric per interval — **no C# changes when adding a metric**, only SQL UNION ALL.

**Consistency rule:** `metric_id` in every UNION ALL row **must exactly match**
`RTSGrid_Metric.MetricId` — this is the single source of truth.

**Schema trust rule:** every field in `RTSGrid_Metric.MetricParameter` is guaranteed to
exist in the source table. No pre-check needed.

See `docs/widget-specification.md §3.4` for full function bodies and §3.4.3 for the
7-step checklist to add a new metric.

### 20.8 Migration Pattern

```csharp
// In BackendEmulationDbContext migration (NOT AppDbContext)
protected override void Up(MigrationBuilder mb) =>
    mb.Sql("""
        CREATE OR REPLACE FUNCTION fn_daytrendinteractions(...) ...;
        CREATE OR REPLACE FUNCTION fn_daytrendagentstatus(...) ...;
    """);

protected override void Down(MigrationBuilder mb) =>
    mb.Sql("""
        DROP FUNCTION IF EXISTS fn_daytrendinteractions(uuid, varchar, text[], integer);
        DROP FUNCTION IF EXISTS fn_daytrendagentstatus(uuid, varchar, text[], integer);
    """);
```

### 20.9 API Hook

Chart/Analytics widgets do **not** write to `RTSGrid_*` tables, so no `SaveXxxRtsCommand`
is needed. The `IConfigurationApiHook` is called from the **dashboard widget save path**
(when the user places the widget on a screen and saves ConfigJson), not from a separate
RTS command. Pattern: same `NoOpConfigurationApiHook` as Grid widgets (§15.6).

### 20.10 Checklist for New Chart/Analytics Widget

1. [ ] Define metrics catalogue in `docs/widget-specification.md` (see §2 pattern)
2. [ ] Write SQL functions in narrow format — one UNION ALL row per metric
3. [ ] Create EF migration in `BackendEmulationDbContext` (`CREATE OR REPLACE FUNCTION`)
4. [ ] Create `DayTrendMetricRow` / result records in Application layer
5. [ ] Implement MediatR query handler (merge two function results)
6. [ ] Seed `RTSGrid_Metric` entries for all metrics (match `MetricId` exactly)
7. [ ] Seed `WidgetCatalogItem` entry
8. [ ] Create `{Name}Widget.razor` — no GridId, use `WidgetInstanceId` for localStorage
9. [ ] Wire JS interop (`window.{widgetName}.render / destroy`) in `wwwroot/js/`
10. [ ] Register in `RenderWidget.razor` — pass `DarkMode` and `WidgetInstanceId`
11. [ ] Add config modal tabs to `ScreenEditorPage.razor` (see §21)
12. [ ] Implement Dark Mode (Effective* color properties, §16)
13. [ ] No `SaveXxxRtsCommand` needed; API hook fires in dashboard save path
14. [ ] Add localization keys to all `.resx` files

---

## 21. Config Modal Tabs — All Widget Types

The configuration modal is rendered inside `ScreenEditorPage.razor` when the user
clicks the ⚙ gear icon on a widget. Tab structure depends on widget type.

### 21.1 Grid Widgets (Agent Grid, Queue Grid, DataSlot)

```
Tab: General      — DisplayName, GridId selection, BU/Queue filter
Tab: Appearance   — Background / Table BG / Font Color (Light + Dark, §16)
                    Avatar colors (Agent Grid only)
                    Header colors with "default" option (§17)
Tab: Columns      — Dual-pane selector: Available | Selected + drag-reorder
Tab: Thresholds   — Per-column rules: MatchType, From/To, BG+FG color
Tab: Filters      — Saved filter presets (optional)
Tab: Score        — Formula rules per column (Agent Grid only)
```

**Key rules:**
- All dropdowns with > 5 items must use the **searchable pattern** (§18.1)
- Metric/column lists show only `Description` — never `MetricId` (§18.2)
- Color pickers use dual-column layout (Light / Dark Mode, §16.2)
- Header colors include `"default"` option (§17.4)

### 21.2 Chart / Analytics Widgets (DayTrend)

```
Tab: General      — Title (text), Business Unit (searchable dropdown),
                    Interval (radio: 15 / 30 / 60 min),
                    Auto-refresh (dropdown: 1 / 5 / 10 min / Manual)

Tab: Appearance   — Chart type (icon buttons: Line / Bar / Area / Step)
                    Show data labels (toggle)
                    Show legend (toggle)
                    Background color (Light + Dark)
                    Font color (Light + Dark)

Tab: Call Metrics — Table: one row per interaction metric
                    Columns: [On/Off toggle] [Color picker] [Label input] [Preview swatch]
                    Drag-to-reorder rows = display order in chart + legend

Tab: Agent Metrics — Same table structure as Call Metrics
                    Preview shows dashed line (vs solid for call metrics)
                    Note: "If no agent metric enabled → agent query skipped"
```

**BU dropdown rule:** show only BUs where user's PG includes the BU in `pg_business_units`.
If `pg_business_units` is empty → show all BUs in tenant (`[PG-03]`).

**ConfigJson structure** for DayTrend (produced by saving the modal):

```json
{
  "title": "Morning Operations",
  "businessUnitId": 3,
  "intervalMinutes": 30,
  "refreshIntervalSeconds": 300,
  "chartType": "line",
  "showDataLabels": true,
  "showLegend": true,
  "backgroundColor": "#0f172a",
  "darkBackgroundColor": "#1e293b",
  "fontColor": "#f1f5f9",
  "darkFontColor": "#e2e8f0",
  "metrics": [
    { "metricId": "interaction.incoming_calls", "enabled": true,  "color": "#3b82f6", "label": "" },
    { "metricId": "interaction.answered_calls",  "enabled": true,  "color": "#22c55e", "label": "" },
    { "metricId": "interaction.abandoned_calls", "enabled": true,  "color": "#ef4444", "label": "" }
  ],
  "agentMetrics": [
    { "metricId": "statuslog.available_agents",  "enabled": false, "color": "#4ade80", "label": "" }
  ]
}
```

### 21.3 Adding Config Modal for a New Widget

1. Add a new `case` in `ScreenEditorPage.razor` modal tab switch matching the widget's
   `WidgetCatalogItem.Name` (or `Category + Name` combo).
2. Declare `Config{Widget}*` fields for each editable parameter.
3. On modal open: populate `Config*` fields from `widget.Config` (deserialize from JSON).
4. On **Save**: serialize all `Config*` fields → `widget.Config` → trigger grid layout save.
5. Follow tab structure from §21.1 or §21.2 depending on widget architecture.

---

## 22. Template Creation Pattern

A **Widget Template** is a named snapshot of a fully-configured widget (`ConfigJson`
bound to a `WidgetCatalogItemId`). Templates let users pre-configure a widget once
and reuse it across multiple dashboards.

### 22.1 Domain Model

```csharp
// src/CcDashboard.Domain/Domain/WidgetTemplate.cs
public class WidgetTemplate
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }          // Multi-tenant (GQF applied)
    public string Name { get; set; }            // User-chosen template name
    public Guid WidgetCatalogItemId { get; set; } // Which widget type
    public string? ConfigJson { get; set; }     // Snapshot of widget configuration
    public Guid CreatedByUserId { get; set; }
    public DateTime CreatedAt { get; set; }

    public Tenant? Tenant { get; set; }
    public WidgetCatalogItem? CatalogItem { get; set; }
}
```

### 22.2 Application Layer

```
CreateWidgetTemplateCommand(Name, WidgetCatalogItemId, ConfigJson)
  → saves WidgetTemplate entity, returns WidgetTemplateDto

DeleteWidgetTemplateCommand(Id)
  → soft- or hard-delete

GetWidgetTemplatesQuery()
  → returns IReadOnlyList<WidgetTemplateDto> for current tenant, ordered by Name
```

`WidgetTemplateDto`:
```csharp
public record WidgetTemplateDto(
    Guid Id,
    string Name,
    Guid WidgetCatalogItemId,
    string? WidgetCategory,   // from CatalogItem.Category
    string? WidgetName,       // from CatalogItem.Name
    string? ConfigJson,
    DateTime CreatedAt);
```

### 22.3 UX Flow

**Saving a template ("Save as Template"):**
1. User opens widget config modal ⚙ and configures the widget.
2. Clicks **"Save as Template"** button in the modal footer.
3. Prompted for template name (inline input or small secondary modal).
4. `CreateWidgetTemplateCommand` is dispatched — stores `ConfigJson` snapshot + `WidgetCatalogItemId`.

**Using a template ("Add Widget from Template"):**
1. In "Add Widget" dialog, user switches to **"From Template"** tab.
2. Shows list of templates for the current widget category (filtered by `WidgetCatalogItemId`).
3. User picks a template → `ConfigJson` is pre-populated into the new widget.
4. Modal opens pre-filled — user can further adjust before placing on the screen.

**Managing templates:**
- Template list accessible from Admin → Widget Templates (or from within the "Add Widget" dialog).
- Administrator and Editor can manage templates within their tenant.
- Templates are tenant-scoped (Global Query Filter on `TenantId`).

### 22.4 Config Modal Footer — Template Button

```razor
<!-- Inside widget config modal, after Save / Cancel buttons -->
<button class="btn btn-outline-secondary btn-sm"
        @onclick="SaveAsTemplate"
        title="Save current configuration as a reusable template">
    @L["Widget_SaveAsTemplate"]
</button>

@if (_showTemplateNameInput)
{
    <div class="mt-2 d-flex gap-2">
        <input type="text" class="form-control form-control-sm"
               placeholder="@L["Widget_TemplateName"]"
               @bind="_templateName" />
        <button class="btn btn-primary btn-sm" @onclick="ConfirmSaveTemplate">
            @L["Common_Save"]
        </button>
        <button class="btn btn-link btn-sm" @onclick="() => _showTemplateNameInput = false">
            @L["Common_Cancel"]
        </button>
    </div>
}
```

```csharp
private bool _showTemplateNameInput;
private string _templateName = "";

private void SaveAsTemplate() => _showTemplateNameInput = true;

private async Task ConfirmSaveTemplate()
{
    if (string.IsNullOrWhiteSpace(_templateName)) return;
    var configJson = SerializeCurrentConfig(); // build ConfigJson from current Config* fields
    await Mediator.Send(new CreateWidgetTemplateCommand(
        _templateName.Trim(),
        _editingWidget!.CatalogItemId,
        configJson));
    _showTemplateNameInput = false;
    _templateName = "";
}
```

### 22.5 Template Localization Keys

```
Widget_SaveAsTemplate       = Save as Template
Widget_TemplateName         = Template name...
Widget_FromTemplate         = From Template
Widget_NoTemplates          = No saved templates
Widget_TemplateApplied      = Template applied
```

---

## 23. Widget Development Methodology — End-to-End Process

Reference path based on the **DayTrend** widget implementation.
Use this as the standard process for every new widget.

### Step 1 — Specification (Cowork, docs/)

Write `docs/widget-specification.md` section for the new widget. Required subsections:

| Subsection | Content |
|---|---|
| Overview | Purpose, data source, widget type (Grid vs Chart) |
| Visual layout | Description or ASCII mockup |
| Configuration options | §3.3-style tables: General / Appearance / metric arrays |
| Data query | SQL function bodies in narrow format; metric catalogue |
| Methodology (§3.4.3) | 7-step checklist for adding a new metric |
| Rendering requirements | Chart type, Y-axes, formatting rules |
| ConfigJson schema | Full JSON schema with defaults |
| Config modal (§3.7) | Tab-by-tab description of the settings UI |
| Access control | Role × permission matrix |
| Seed entries | `WidgetCatalogItem` + `RTSGrid_Metric` seed code |
| Implementation notes | Timezone, dual Y-axis, performance, known limitations |

### Step 2 — Backend Task (Cowork, docs/backend-tasks.md)

Write a `CC-NNN` task entry with:
- Deliverables list (migration, handler, component, seed, JS file)
- Full C# record/class definitions (so CC doesn't need to infer them)
- SQL function bodies (copy from widget-specification.md)
- JS interop contract
- Acceptance criteria
- Reference to this skill: **`.claude/skills/widget-creator/widget-creator.md`**
  (specify relevant sections: e.g. §20 for Chart widgets, §21–22 for config modal + templates)

### Step 3 — SQL Functions (CC, BackendEmulationDbContext migration)

- Migration class in `CcDashboard.Infrastructure/Persistence/Migrations/`
- Targets `BackendEmulationDbContext` — not `AppDbContext`
- `Up()`: `CREATE OR REPLACE FUNCTION` for each function
- `Down()`: `DROP FUNCTION IF EXISTS` with full signature
- Functions return narrow format: `(interval_start, metric_id, value)`

### Step 4 — C# Handler (CC, Application layer)

- MediatR query: `GetDayTrendQuery(Guid TenantId, int BusinessUnitId, DateTime Date, int IntervalMin)`
- Handler in `CcDashboard.Application/Queries/Widgets/`
- Uses `BackendEmulationDbContext` (not AppDbContext)
- Conditional second query: only if `agentMetrics` has ≥1 enabled entry
- Returns `DayTrendResult`

### Step 5 — Blazor Component (CC, Web layer)

- `{Name}Widget.razor` — no GridId, no SignalR
- Uses `WidgetInstanceId` (Guid) as localStorage key
- `ApplyConfig()` → `LoadDataAsync()` → `RenderChartAsync()` pattern
- Timer-based refresh (`refreshIntervalSeconds`)
- Dark Mode via `Effective*` color properties (§16.5)
- `IAsyncDisposable` — destroy chart on dispose

### Step 6 — Seed Data (CC, Infrastructure/Persistence/Seed)

- `RTSGrid_Metric` rows: one per metric, `MetricId` = exact value used in UNION ALL
- `WidgetCatalogItem`: category, name, description, icon URL

### Step 7 — Config Modal + Template (CC, ScreenEditorPage.razor)

- Add tab case in modal switch for the new widget type
- Follow §21.2 tab structure (Chart) or §21.1 (Grid)
- Add "Save as Template" button per §22.4
- Localization keys in all `.resx` files

### Adding a New Metric to an Existing Widget (7-Step Checklist)

> From `docs/widget-specification.md §3.4.3`

1. Add `RTSGrid_Metric` seed entry (§2.4 in widget-specification.md)
2. Add predicate key to §2.1 if it requires a new SQL filter
3. Add column to `agg` / `status_summary` CTE in the function (comment: `MetricId | predicate_key`)
4. Add UNION ALL row: `SELECT interval_start, 'metric.id', column_name::double precision FROM agg`
5. Deploy with `CREATE OR REPLACE FUNCTION` (no EF migration change, no C# change)
6. Add entry to `ConfigJson` `metrics` / `agentMetrics` default set in spec and in seed
7. Add row to §3.3.3 / §3.3.4 default metric table in widget-specification.md

---

*Widget Creator Skill — sections §20–23 added 2026-05-27. Covers Chart/Analytics widget architecture (DayTrend pattern), config modal tabs for all widget types, Template creation flow, and end-to-end widget development methodology.*

---

## §24 DayTrend-специфичные паттерны (lessons from production polish)

> Паттерны из финальной шлифовки DayTrend виджета. Применять ко всем Chart/Analytics виджетам.

### §24.1 Config modal — скрывать неприменимые табы

DayTrend не использует Thresholds. Скрывать таб условно:

```razor
@if (!IsDayTrendWidget(ConfiguringWidget))
{
    <li class="nav-item">
        <button class="nav-link @(ConfigTab == "thresholds" ? "active" : "")"
                @onclick='() => ConfigTab = "thresholds"'>Thresholds</button>
    </li>
}
```

Паттерн `IsDayTrendWidget(w)` — проверка по `WidgetCatalogItem.Name` или `WidgetType` enum.
Применять для любого таба, не имеющего смысла для данного типа виджета.

### §24.2 Metric config UI — не показывать MetricId пользователю

В табах Call Metrics и Agent Metrics показывать только: **toggle + color picker + label input**.
`MetricId` — техническое поле, не отображать:

```razor
@* Правильно: *@
<td><InputCheckbox @bind-Value="metric.Enabled" /></td>
<td><input type="color" @bind="metric.Color" /></td>
<td><InputText @bind-Value="metric.Label" placeholder="@metric.MetricId" /></td>

@* Неправильно — убрать: *@
@* <td>@metric.MetricId</td> *@
```

### §24.3 Chart.js dataset — явно копировать кастомные свойства

Любые кастомные свойства (например `isTimeMetric`, `isAgentMetric`) должны явно передаваться в `configuredDatasets`, иначе tooltip callback их не увидит:

```javascript
const baseConfig = {
    label:           ds.label,
    data:            ds.data,
    borderColor:     ds.borderColor,
    backgroundColor: ds.backgroundColor,
    // ОБЯЗАТЕЛЬНО — кастомные свойства для tooltip/formatting:
    isTimeMetric:    ds.isTimeMetric,
    isAgentMetric:   ds.isAgentMetric,
};
```

### §24.4 Tooltip mode для multi-line chart

Для графиков с множеством серий использовать `nearest + intersect: true` — показывает только значение под курсором:

```javascript
interaction: {
    mode: 'nearest',
    intersect: true
}
```

Избегать `mode: 'index'` (показывает все серии) на загруженных графиках с 10+ метриками.

### §24.5 Time formatting в tooltip и Y-axis

Время хранится в **секундах** (или миллисекундах — зависит от метрики). Форматировать как `mm:ss`:

```javascript
// В tooltip callback:
function formatTime(seconds) {
    const m = Math.floor(seconds / 60);
    const s = Math.round(seconds % 60);
    return `${m}:${s.toString().padStart(2, '0')}`;
}

// В ticks callback Y-axis:
ticks: {
    callback: (val) => isTimeMetric ? formatTime(val) : val
}
```

Флаг `isTimeMetric` берётся из dataset (§24.3).

### §24.6 Parameter change tracking — отслеживать ВСЕ параметры

В `OnParametersSetAsync` отслеживать **все** параметры, влияющие на данные (не только BU):

```csharp
private Guid   _lastBusinessUnitId;
private int    _lastIntervalMinutes;

protected override async Task OnParametersSetAsync()
{
    if (_businessUnitId != _lastBusinessUnitId ||
        _intervalMinutes != _lastIntervalMinutes)
    {
        _lastBusinessUnitId   = _businessUnitId;
        _lastIntervalMinutes  = _intervalMinutes;
        await LoadDataAsync();
    }
}
```

Если добавляется новый параметр фильтрации — сразу добавлять `_last*` поле.

### §24.7 Label fallback — форматировать MetricId в читаемый вид

Всегда иметь fallback для пустых `Label`. Паттерн `GetDisplayLabel`:

```csharp
private static string GetDisplayLabel(DayTrendMetricConfig metric)
{
    if (!string.IsNullOrEmpty(metric.Label))
        return metric.Label;
    // "interaction.incoming_calls" → "Incoming Calls"
    var parts = metric.MetricId.Split('.');
    if (parts.Length > 1)
        return string.Join(" ", parts[1].Split('_')
            .Select(p => char.ToUpper(p[0]) + p[1..]));
    return metric.MetricId;
}
```

Применять во всех Chart виджетах где пользователь может оставить Label пустым.

---

*§24 добавлен 2026-05-27 по результатам финальной шлифовки DayTrend виджета.*

### §24.8 Searchable dropdown — очищать поиск при открытии

**Симптом:** Searchable dropdown показывает только 1 элемент (текущий выбранный) вместо полного списка.

**Причина:** Поле поиска предзаполнено именем выбранного элемента. При открытии фильтр уже активен → список фильтруется до одного совпадения.

**Решение** — добавить `@onfocus` который очищает поиск:

```razor
<input type="text" class="form-control"
       placeholder="@L["Common_Search"]..."
       value="@SearchText"
       @oninput="e => SearchText = e.Value?.ToString() ?? string.Empty"
       @onfocus="() => SearchText = string.Empty"
       @onblur="() => { Task.Delay(150).ContinueWith(_ => InvokeAsync(() => {
           DropdownOpen = false;
           SearchText = Items.FirstOrDefault(x => x.Id == SelectedId)?.Name ?? string.Empty;
           StateHasChanged();
       })); }" />
```

**Паттерн `@onblur`:** при потере фокуса — закрыть dropdown И восстановить имя выбранного элемента в поле (чтобы показывать текущий выбор когда dropdown закрыт).

**Применять везде** где searchable dropdown отображает предвыбранное значение в поле ввода.


---

## §25 ASD-сессия: паттерны real-time Grid виджетов с BU-фильтрацией (CC-007, 2026-05-28)

> Инсайты из отладки AgentStateDistribution виджета. Применять ко всем Grid виджетам,
> которые фильтруют SignalR данные по `UnionId` (BU-привязанные виджеты).

---

### §25.1 DashboardWidget.GridId ≠ RTSGrid_Grid.GridId — обязательно читать

Два независимых auto-increment из разных таблиц:

- **`Widget.GridId`** = `dashboard_widgets.GridId` — передаётся как `[Parameter] int GridId`
- **`Config.GridId`** = `RTSGrid_Grid.GridId` — хранится в `WidgetConfig.GridId` → `ConfigJson`

`preassignedGridId` в `SaveWidgetConfig` всегда `null` → `DashboardWidget.GridId` никогда не
совпадает с `RTSGrid_Grid.GridId` (разные счётчики).

**Обязательный паттерн для BU-фильтрованных виджетов — добавить helper:**

```csharp
// Use RTSGrid_Grid.GridId (Config.GridId), NOT DashboardWidget.GridId (GridId parameter)
private int RtsGridId => Config?.GridId ?? GridId;
```

Использовать `RtsGridId` везде: в URL хаба, в guard-условиях, в markup.

```csharp
// ConnectAsync():
var fullUrl = $"{simulatorUrl}/hubs/queue-grid?gridId={RtsGridId}";

// Guards:
if (RtsGridId == 0 || _businessUnitId == 0) return;
if (RtsGridId != 0 && _previousRtsGridId == 0 && _hub is null && _businessUnitId > 0) ...

// Markup:
@if (RtsGridId == 0 || _businessUnitId == 0)  // show "save config first"
```

**Почему Queue Grid работает без этого фикса:**
Queue Grid не фильтрует строки по UnionId — показывает все строки из симулятора включая
random fallback. Симулятор возвращает строки с `UnionId=null` при wrong gridId → Queue Grid
показывает их, ASD — нет (фильтрует по `r.UnionId == _businessUnitId`).

---

### §25.2 Симулятор: GetRowsForGridAsync должен получать RTSGrid_Grid.GridId

Симулятор (`QueueDataGenerator.GenerateAsync`) вызывает:
```csharp
var dbRows = await _metricService.GetRowsForGridAsync(gridId, ct);
```

Запрос: `SELECT RowId, UnionId FROM RTSGrid_Row WHERE GridId = @gridId AND RowNumber > 1`.

Если передать `DashboardWidget.GridId` (неправильный) → 0 строк → random fallback
с `UnionId=null` → BU-фильтрованный виджет не находит совпадений → пустой рендер.

**Для корректной работы BU-фильтрованного виджета:**
1. Виджет передаёт `Config.GridId` в URL хаба
2. Симулятор получает корректный `RTSGrid_Grid.GridId`
3. `GetRowsForGridAsync` находит строки с правильным `UnionId`
4. Виджет находит `r.UnionId == _businessUnitId` → получает метрики

---

### §25.3 SignalR десериализация — поля local record должны совпадать с JSON

Виджет объявляет local record для десериализации:
```csharp
private record GridUpdate(int GridId, List<GridRowUpdate> Rows);
private record GridRowUpdate(string RowId, int? UnionId, Dictionary<string, string> Metrics);
```

SignalR десериализует JSON по именам полей. Если симулятор отправляет
`{ "rowId": "...", "metrics": {...} }` без поля `unionId` — `UnionId` будет `null`.

**Правило:** при добавлении нового поля в симулятор (e.g. `UnionId`) — одновременно обновить
local record в виджете И модель в симуляторе (`GridRowData`). Иначе поле молча игнорируется.

**Чеклист при добавлении поля в GridRowData симулятора:**
- [ ] `Models/GridRowData` — добавить поле
- [ ] `QueueDataGenerator.GenerateAsync` — заполнить поле
- [ ] Виджет local record `GridRowUpdate` — добавить поле с тем же именем
- [ ] Виджет обработчик `QueueGridUpdate` — использовать поле

---

### §25.4 Симулятор: GetMetricsForGridAsync — метрики из RTSGrid_Cell

**Проблема:** `GetQueueMetricsAsync` фильтрует только метрики с Description "QM - " или
"Agent Group - ". Новый тип виджета может использовать метрики с другим префиксом.

**Решение — `GetMetricsForGridAsync(int gridId)`:**
```sql
SELECT DISTINCT c."Value"
FROM "RTSGrid_Cell" c
JOIN "RTSGrid_Row" r ON c."RowId" = r."RowId"
WHERE r."GridId" = @gridId AND c."CellType" = 'Data' AND c."Value" IS NOT NULL
```

Возвращает MetricId-ы, фактически используемые в ячейках этого грида.
Затем фильтрует `GetAllMetricsAsync` по найденным MetricId.

**Fallback:** если возвращает пустой список → `GetQueueMetricsAsync`.

Использовать для любого виджета с нестандартными метриками.

---

### §25.5 Начальное состояние виджета = ConnectionState.Connecting

```csharp
private ConnectionState _connectionState = ConnectionState.Connecting;  // INITIAL VALUE
```

Виджет показывает "Connecting..." при инициализации **до того как** `ConnectAsync` вызван.
Это нормально. Но если `ConnectAsync` не вызывается вообще (из-за гарда `GridId == 0` или
`_businessUnitId == 0`), UI застревает на "Connecting..." навсегда.

**Диагностика — проверить логи:**
- Если есть `"AgentStateDistributionWidget: Starting connection for GridId X"` → ConnectAsync вызван
- Если нет → проверить гарды (GridId, BusinessUnitId)
- После подключения: если `"0 agents"` → добавить лог в handler:
  ```csharp
  Logger.LogDebug("ASD update: gridId={G}, rows={R}, buId={B}",
      update.GridId, update.Rows.Count,
      string.Join(",", update.Rows.Select(r => r.UnionId?.ToString() ?? "null")));
  ```

---

### §25.6 Workflow отладки "виджет подключился но пустой"

При `ConnectionState.Connected` + пустые данные:

1. **Логи** — ищи `"Starting connection for GridId X"`. Какой X? Это `RtsGridId` или `DashboardWidget.GridId`?
2. **GridId правильный?** — открой DB, проверь: есть ли строки в `RTSGrid_Row` с `GridId = X`?
   Если нет — виджет использует неправильный GridId (DashboardWidget.GridId вместо RTSGrid_Grid.GridId).
3. **UnionId совпадает?** — добавь лог в `QueueGridUpdate` handler. Какие `UnionId` приходят?
   Совпадают ли с `_businessUnitId`?
4. **Метрики есть?** — после получения строки проверь `buRow.Metrics.Count > 0`.
   Если 0 — симулятор не генерирует нужные метрики (см. §25.4).

---

### §25.7 SaveQueueGridRtsCommand для ASD — ColumnId: null это нормально

ASD использует фиксированные 6 колонок. При каждом сохранении конфига передаются
`ColumnId: null` для всех колонок:
```csharp
new QueueGridColumnInput("asd-c1", null, "Available", "QueueLoginDataNumAvailableUsers", 1)
//                                  ^^^^ null = каждый раз пересоздать
```

Обработчик `SaveQueueGridRtsCommand` удалит старые колонки и создаст новые. Это "churn"
но приемлемо для ASD — колонки всегда одинаковые. GridId сохраняется между сохранениями
(передаётся `ConfiguringWidget.Config?.GridId`).

**Альтернатива** — хранить `ColumnId` каждой ASD колонки в Config. Более эффективно,
но усложняет код. Применять если частые пересохранения станут проблемой производительности.

---

### §25.8 BU dropdown в config modal — обязательный паттерн

**Симптом:** при повторном открытии dropdown показывает только 1 элемент (текущий выбранный).

**Причина:** `BuSearchText` предзаполнен именем выбранного BU → фильтр сразу активен.

**Паттерн (из §24.8, подтверждён на ASD):**
```razor
@onfocus="() => { BuSearchText = string.Empty; BuDropdownOpen = true; }"
@onblur="OnBuSearchBlur"   // async: delay 150ms, close, restore selected name
```

`GetBusinessUnitName(ConfigBusinessUnit)` — получает имя BU по ID строке.
`ConfigBusinessUnit` хранит `BusinessUnitId.ToString()`, не имя.

**Применять к каждому BU dropdown** в config modal для любого нового виджета.

---

*§25 добавлен 2026-05-28 по результатам CC-007 ASD widget debug session.*
*4 итерации фиксов: SaveQueueGridRtsCommand → BusinessUnitId save → UnionId в симуляторе → Config.GridId для URL хаба.*
---

## §26 PostgreSQL jsonb — DO NOT use .Contains() or LIKE

### §26.1 Problem: jsonb column with LINQ .Contains()

**Symptom:** PostgreSQL error:
```
42883: operator does not exist: jsonb ~~ jsonb
```
or
```
42883: function pg_catalog.like_escape(jsonb, unknown) does not exist
```

**Cause:** EF Core translates `.Contains(string)` and `EF.Functions.ILike()` to SQL `LIKE`/`ILIKE`, but PostgreSQL does not support these operators on `jsonb` columns directly.

**Wrong:**
```csharp
// FAILS — jsonb ~~ jsonb error
var results = await db.DashboardWidgets
    .Where(w => w.ConfigJson != null && w.ConfigJson.Contains(idString))
    .ToListAsync(ct);

// ALSO FAILS — like_escape(jsonb, unknown) error
var results = await db.DashboardWidgets
    .Where(w => w.ConfigJson != null && EF.Functions.ILike(w.ConfigJson, "%" + idString + "%"))
    .ToListAsync(ct);
```

### §26.2 Solution: Raw SQL with ::text cast

**Correct — use SqlQueryRaw with explicit cast:**
```csharp
var dashboardNames = await db.Database
    .SqlQueryRaw<string>(
        @"SELECT DISTINCT d.""Name"" FROM dashboard_widgets w 
          JOIN dashboards d ON w.""DashboardId"" = d.""Id"" 
          WHERE w.""ConfigJson""::text ILIKE {0}",
        $"%{idString}%")
    .ToListAsync(ct);
```

Key points:
- `::text` casts jsonb to text, enabling ILIKE
- Use `{0}` parameter placeholder for SQL injection safety
- Double-quote column names for PostgreSQL case sensitivity

### §26.3 When this applies

This issue occurs when:
1. Entity property is `string?` in C# (e.g., `public string? ConfigJson { get; set; }`)
2. But mapped to `jsonb` in PostgreSQL: `.HasColumnType("jsonb")`
3. And you use `.Contains()`, `.StartsWith()`, `EF.Functions.Like/ILike` in LINQ

**Common in widget code:** searching for widget placement by checking if `ConfigJson` contains a specific ID.

---

*§26 added 2026-05-29 after CC-010 Info Slot Widget — jsonb search fix.*

---

## §27 Blazor Server + EF Core — Concurrent DbContext Access

### §27.1 Problem: "A command is already in progress"

**Symptom:** `NpgsqlOperationInProgressException: A command is already in progress`

**Cause:** In Blazor Server, multiple components can call `OnInitializedAsync` simultaneously during SSR prerendering. If they all use the same scoped `AppDbContext`, concurrent async queries on the same connection cause this error.

**Impact:** Unhandled exception crashes the Blazor circuit → all widgets lose connection → "Connecting..." state forever.

### §27.2 Solution: IDbContextFactory + Explicit TenantId Filter

For widget query handlers that may run concurrently with other queries:

```csharp
public class GetWidgetDataQueryHandler(
    IDbContextFactory<AppDbContext> dbFactory,    // Isolated context per call
    ICurrentUserAccessor currentUser)             // TenantId from scoped service
    : IRequestHandler<GetWidgetDataQuery, WidgetDataDto?>
{
    public async Task<WidgetDataDto?> Handle(GetWidgetDataQuery query, CancellationToken ct)
    {
        var tenantId = currentUser.TenantId!.Value;
        await using var db = await dbFactory.CreateDbContextAsync(ct);
        
        // IgnoreQueryFilters() bypasses automatic tenant filter
        // Explicit TenantId filter maintains security
        var data = await db.SomeTable
            .IgnoreQueryFilters()
            .Where(x => x.Id == query.Id && x.TenantId == tenantId)
            .FirstOrDefaultAsync(ct);
        
        return data;
    }
}
```

**Pattern:**
- `IDbContextFactory<AppDbContext>` — creates isolated DbContext (no concurrent access)
- `ICurrentUserAccessor` — TenantId from scoped service (still available)
- `IgnoreQueryFilters()` — bypasses automatic filter (since we filter manually)
- Explicit `TenantId == tenantId` — security preserved

### §27.3 Hub Connection — Fire-and-Forget with Error Handling

Widget hub connections that fail should NOT crash the circuit:

```csharp
protected override async Task OnAfterRenderAsync(bool firstRender)
{
    if (firstRender && Config?.SomeId is not null)
    {
        StartTimer();
        _ = ConnectHubAsync();  // Fire and forget — errors handled inside
    }
}

private async Task ConnectHubAsync()
{
    try
    {
        var hubUrl = Navigation.ToAbsoluteUri("/hubs/my-hub");
        _hub = new HubConnectionBuilder()
            .WithUrl(hubUrl)
            .WithAutomaticReconnect()
            .Build();

        _hub.On<MyDto>("EventName", dto => { ... });

        await _hub.StartAsync();
        await _hub.InvokeAsync("JoinGroup", Config.SomeId.Value);
    }
    catch
    {
        // Hub connection failed — widget still works with initial data
        // No live updates, but no circuit crash
    }
}
```

**Key points:**
- `_ = ConnectHubAsync()` — fire-and-forget, doesn't block render
- Full `try-catch` around ALL hub operations
- Widget degrades gracefully: initial data loads, just no real-time updates

### §27.4 When to Use This Pattern

Use `IDbContextFactory` + explicit tenant filter for:
- Widget data query handlers called during SSR
- Any handler that may run concurrently with other DB queries
- Handlers for components that render on pages with multiple widgets

Use fire-and-forget hub connection for:
- Any widget that connects to internal SignalR hub
- Widgets that can function (degraded) without real-time updates

---

*§27 added 2026-05-29 after CC-010 Info Slot Widget — concurrent DbContext + hub connection patterns.*

---

## §28 Build Process — Always Stop Running Processes First

### §28.1 Problem: File Lock Errors During Build

When running `dotnet build` while the web app or simulator is running, the build fails with:

```
error MSB3027: Could not copy "...CcDashboard.Infrastructure.dll" to "...". 
Exceeded retry count of 10. Failed. The file is locked by: "CcDashboard.Web (PID)"
```

### §28.2 Solution: Stop All dotnet Processes Before Build

**Always run this before `dotnet build`:**

```powershell
Get-Process -Name dotnet -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
dotnet build CcDashboard.sln --no-restore
```

**Why `Start-Sleep`:** File handles may not release immediately after process termination. A 2-second delay ensures all locks are cleared.

### §28.3 Background Processes

If you started web/simulator with `run_in_background`, they're still running. The build will fail until you stop them:

```powershell
# Find and stop all dotnet processes (web, simulator, watch)
Get-Process -Name dotnet -ErrorAction SilentlyContinue | Stop-Process -Force
```

After a successful build, restart the services as needed.

### §28.4 Service URLs

| Service | URL |
|---------|-----|
| Web App | https://localhost:5239/ |
| SignalR Simulator | https://localhost:5054/ |

**Start both services:**

```powershell
Start-Process -FilePath "dotnet" -ArgumentList "run", "--project", "src/CcDashboard.Web" -WindowStyle Hidden
Start-Process -FilePath "dotnet" -ArgumentList "run", "--project", "tools/SignalRSimulator" -WindowStyle Hidden
```

---

*§28 added 2026-05-29 — build process best practice after repeated file lock issues.*

---

## §29 Multi-Tenant Tables — Superadmin UI Requirements

### §29.1 Rule: All Admin Tables Must Support Tenant Context

For **Superadmin** users, every admin/list table must include:

1. **Tenant Selector** in the header (top-right) — dropdown to filter by tenant or "All Tenants"
2. **Tenant Column** in the table — shows which tenant each row belongs to

### §29.2 Implementation Pattern

```razor
@* Header with tenant selector *@
<div class="d-flex justify-content-between align-items-center mb-3">
    <h1 class="h4 mb-0">@L["Page_Title"]</h1>
    <AuthorizeView Roles="Superadmin">
        <div class="d-flex align-items-center gap-2">
            <label class="form-label mb-0 small text-muted">@L["PG_Tenant"]</label>
            <select class="form-select form-select-sm" style="width:auto"
                    value="@SelectedTenantId" @onchange="OnTenantChanged">
                <option value="">@L["Audit_AllTenants"]</option>
                @foreach (var t in Tenants)
                {
                    <option value="@t.Id">@t.Name</option>
                }
            </select>
        </div>
    </AuthorizeView>
</div>

@* Table with Tenant column for Superadmin *@
<table class="table table-hover">
    <thead>
        <tr>
            <AuthorizeView Roles="Superadmin">
                <th>@L["PG_Tenant"]</th>
            </AuthorizeView>
            <th>Name</th>
            @* ... other columns *@
        </tr>
    </thead>
    <tbody>
        @foreach (var item in Items)
        {
            <tr>
                <AuthorizeView Roles="Superadmin">
                    <td>@GetTenantName(item.TenantId)</td>
                </AuthorizeView>
                <td>@item.Name</td>
            </tr>
        }
    </tbody>
</table>
```

### §29.3 DTO Requirements

DTOs for list queries must include `TenantId` so Superadmin can see/filter by tenant:

```csharp
public record ItemListDto(
    Guid Id,
    Guid TenantId,  // Required for Superadmin tenant column
    string Name,
    // ...
);
```

### §29.4 Applies To

- User Management (`/admin/users`)
- Permission Groups (`/admin/permission-groups`)
- Info Slots (`/info-slots`)
- Dashboards/Screens (`/screens`)
- Audit Log (`/admin/audit`)
- Any other admin list page

---

*§29 added 2026-05-29 — Superadmin must see Tenant selector + Tenant column in all tables.*
