# Task: Move active filters badge into widget header

## Goal

Show the active filter count badge ("1 active filters") in the widget header
(next to the title) instead of as a separate bar inside the widget body.
Apply to AgentGrid and QueueGrid.

## Step 1 — AgentGridWidget.razor

Add parameter and invoke it when filter count changes:

```csharp
[Parameter] public EventCallback<int> ActiveFilterCountChanged { get; set; }
```

Find the private method that currently computes `activeFilterCount` (likely
`GetActiveFilterCount()`). After every operation that changes filters
(ApplyFilter, ClearFilter, ClearAllFilters, OnParametersSetAsync), add:

```csharp
await ActiveFilterCountChanged.InvokeAsync(GetActiveFilterCount());
```

Also call it in `OnAfterRenderAsync(firstRender)` after config is applied:
```csharp
if (firstRender)
    await ActiveFilterCountChanged.InvokeAsync(GetActiveFilterCount());
```

**Remove** the separate active filters toolbar div from inside `agent-grid-body`
(the `@if (activeFilterCount > 0) { <div class="d-flex...border-bottom..."> }` block).

Keep the "no matching agents" empty state with its "Clear filters" button.

## Step 2 — QueueGridWidget.razor

Same changes as Step 1:
- Add `[Parameter] public EventCallback<int> ActiveFilterCountChanged { get; set; }`
- Invoke after every filter change and in `OnAfterRenderAsync(firstRender)`
- Remove the active filters toolbar div from inside `queue-grid-body`

## Step 3 — RenderWidget.razor

Add parameter and pass it to AgentGrid and QueueGrid:

```razor
[Parameter] public EventCallback<int> ActiveFilterCountChanged { get; set; }
```

In the switch/case:
```razor
case var n when n.Contains("agent") && n.Contains("grid"):
    <AgentGridWidget @key="Widget.GridId" Config="Widget.Config"
        GridId="Widget.GridId" DarkMode="DarkMode"
        ActiveFilterCountChanged="ActiveFilterCountChanged" />
    break;
case var n when n.Contains("queue") && n.Contains("grid"):
    <QueueGridWidget @key="Widget.GridId" Config="Widget.Config"
        GridId="Widget.GridId" DarkMode="DarkMode"
        ActiveFilterCountChanged="ActiveFilterCountChanged" />
    break;
```

## Step 4 — ScreenEditorPage.razor

### 4a — Add state

```csharp
private Dictionary<Guid, int> _widgetFilterCounts = new();
```

### 4b — Pass callback to RenderWidget

Find `<RenderWidget Widget="widget" DarkMode="_darkMode" />` and change to:

```razor
<RenderWidget Widget="widget" DarkMode="_darkMode"
    ActiveFilterCountChanged="count => { _widgetFilterCounts[widget.Id] = count; InvokeAsync(StateHasChanged); }" />
```

### 4c — Show badge in widget-header

Find the widget-header div:
```html
<div class="widget-header widget-drag-handle" ...>
    <i class="bi bi-grip-horizontal me-1"></i>@widget.Name
</div>
```

Change to:
```html
<div class="widget-header widget-drag-handle d-flex align-items-center gap-2" ...>
    <i class="bi bi-grip-horizontal me-1"></i>
    <span>@widget.Name</span>
    @if (_widgetFilterCounts.GetValueOrDefault(widget.Id) > 0)
    {
        <span class="badge rounded-pill bg-primary ms-1"
              style="font-size: 10px; padding: 2px 6px;">
            @_widgetFilterCounts[widget.Id]
        </span>
    }
</div>
```

## Verification

```bash
dotnet build src/CcDashboard.Web --no-restore
```

After deploy: filter badge appears in widget title bar next to name.
No separate bar inside the widget body.

## Git push
Do NOT run `git push` automatically. Commit only.

## Mandatory pre-commit check

```bash
bash tools/pre-commit-check.sh
```

## Commit message

```
feat: move active filters badge into widget header

Active filter count bubbles up via EventCallback<int> from AgentGrid/QueueGrid
through RenderWidget to ScreenEditorPage. Badge shown next to widget title.
Removed separate filter toolbar from widget body.
```
