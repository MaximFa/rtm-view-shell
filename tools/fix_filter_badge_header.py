#!/usr/bin/env python3
"""Move active filters badge into widget header."""
import os

# === Step 1: AgentGridWidget.razor ===
agent_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Widgets\AgentGridWidget.razor"
with open(agent_path, "r", encoding="utf-8") as f:
    agent_text = f.read()

# 1a. Add parameter after DarkMode
old_params = '''    [Parameter] public WidgetConfig? Config { get; set; }
    [Parameter] public int GridId { get; set; }
    [Parameter] public bool DarkMode { get; set; }'''

new_params = '''    [Parameter] public WidgetConfig? Config { get; set; }
    [Parameter] public int GridId { get; set; }
    [Parameter] public bool DarkMode { get; set; }
    [Parameter] public EventCallback<int> ActiveFilterCountChanged { get; set; }'''

if old_params not in agent_text:
    print("ERROR: AgentGrid params block not found")
    exit(1)
agent_text = agent_text.replace(old_params, new_params)

# 1b. Remove the active filters toolbar
old_toolbar = '''            @* Active filters toolbar - P1 *@
            @if (activeFilterCount > 0)
            {
                <div class="d-flex align-items-center gap-2 px-2 py-1 border-bottom small" style="@GetTableStyle(); border-color: currentColor !important; opacity: 0.9;">
                    <span class="badge rounded-pill" style="@GetBadgeInvertStyle()">@activeFilterCount</span>
                    <span>@L["Widget_ActiveFilters"]</span>
                    <button class="btn btn-link btn-sm p-0 ms-auto"
                            style="@GetFontColorStyle() text-decoration: none;"
                            @onclick="ClearAllFilters"
                            aria-label="@L["Widget_ClearAllFilters"]">
                        @L["Widget_ClearAllFilters"]
                    </button>
                </div>
            }

            <table'''

new_toolbar = '''            <table'''

if old_toolbar not in agent_text:
    print("ERROR: AgentGrid toolbar block not found")
    exit(1)
agent_text = agent_text.replace(old_toolbar, new_toolbar)

# 1c. Add invoke in OnAfterRenderAsync
old_after_render = '''    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (firstRender)
        {
            await ConnectAsync();
            _ = StartTickLoopAsync();
            if (GridId != 0 && !_stateLoaded)
            {
                _stateLoaded = true;
                await LoadWidgetStateAsync();
                StateHasChanged();
            }
        }
    }'''

new_after_render = '''    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (firstRender)
        {
            await ConnectAsync();
            _ = StartTickLoopAsync();
            if (GridId != 0 && !_stateLoaded)
            {
                _stateLoaded = true;
                await LoadWidgetStateAsync();
                StateHasChanged();
            }
            await ActiveFilterCountChanged.InvokeAsync(GetActiveFilterCount());
        }
    }'''

if old_after_render not in agent_text:
    print("ERROR: AgentGrid OnAfterRenderAsync not found")
    exit(1)
agent_text = agent_text.replace(old_after_render, new_after_render)

# 1d. Add invoke after ClearAllFilters
old_clear_all = '''    private async Task ClearAllFilters()
    {
        _columnFilters.Clear();
        _activeFilterColumn = null;
        _listDropdownOpen = null;
        _currentPage = 1;
        await SaveWidgetStateAsync();
    }'''

new_clear_all = '''    private async Task ClearAllFilters()
    {
        _columnFilters.Clear();
        _activeFilterColumn = null;
        _listDropdownOpen = null;
        _currentPage = 1;
        await SaveWidgetStateAsync();
        await ActiveFilterCountChanged.InvokeAsync(GetActiveFilterCount());
    }'''

if old_clear_all not in agent_text:
    print("ERROR: AgentGrid ClearAllFilters not found")
    exit(1)
agent_text = agent_text.replace(old_clear_all, new_clear_all)

# 1e. Add invoke after ClearFilter
old_clear_filter = '''    private async Task ClearFilter(string metricId)
    {
        if (_columnFilters.ContainsKey(metricId))
        {
            _columnFilters[metricId] = new ColumnFilter();
        }
        _activeFilterColumn = null;
        _listDropdownOpen = null;
        _currentPage = 1;
        await SaveWidgetStateAsync();
    }'''

new_clear_filter = '''    private async Task ClearFilter(string metricId)
    {
        if (_columnFilters.ContainsKey(metricId))
        {
            _columnFilters[metricId] = new ColumnFilter();
        }
        _activeFilterColumn = null;
        _listDropdownOpen = null;
        _currentPage = 1;
        await SaveWidgetStateAsync();
        await ActiveFilterCountChanged.InvokeAsync(GetActiveFilterCount());
    }'''

if old_clear_filter not in agent_text:
    print("ERROR: AgentGrid ClearFilter not found")
    exit(1)
agent_text = agent_text.replace(old_clear_filter, new_clear_filter)

# 1f. Add invoke after ApplyValueFilter
old_apply_value = '''    private async Task ApplyValueFilter(string metricId)
    {
        var filter = GetOrCreateFilter(metricId);
        if (!string.IsNullOrEmpty(filter.TextValue))
        {
            filter.Mode = "value";
            filter.SelectedValues.Clear(); // Clear List when Value is applied
        }
        _activeFilterColumn = null;
        _listDropdownOpen = null;
        _currentPage = 1;
        await SaveWidgetStateAsync();
    }'''

new_apply_value = '''    private async Task ApplyValueFilter(string metricId)
    {
        var filter = GetOrCreateFilter(metricId);
        if (!string.IsNullOrEmpty(filter.TextValue))
        {
            filter.Mode = "value";
            filter.SelectedValues.Clear(); // Clear List when Value is applied
        }
        _activeFilterColumn = null;
        _listDropdownOpen = null;
        _currentPage = 1;
        await SaveWidgetStateAsync();
        await ActiveFilterCountChanged.InvokeAsync(GetActiveFilterCount());
    }'''

if old_apply_value not in agent_text:
    print("ERROR: AgentGrid ApplyValueFilter not found")
    exit(1)
agent_text = agent_text.replace(old_apply_value, new_apply_value)

with open(agent_path, "w", encoding="utf-8") as f:
    f.write(agent_text)
    f.flush()
    os.fsync(f.fileno())
print(f"Fixed AgentGridWidget.razor ({len(agent_text.splitlines())} lines)")


# === Step 2: QueueGridWidget.razor ===
queue_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Widgets\QueueGridWidget.razor"
with open(queue_path, "r", encoding="utf-8") as f:
    queue_text = f.read()

# 2a. Add parameter after DarkMode
old_q_params = '''    [Parameter] public WidgetConfig? Config { get; set; }
    [Parameter] public int GridId { get; set; }
    [Parameter] public bool DarkMode { get; set; }'''

new_q_params = '''    [Parameter] public WidgetConfig? Config { get; set; }
    [Parameter] public int GridId { get; set; }
    [Parameter] public bool DarkMode { get; set; }
    [Parameter] public EventCallback<int> ActiveFilterCountChanged { get; set; }'''

if old_q_params not in queue_text:
    print("ERROR: QueueGrid params block not found")
    exit(1)
queue_text = queue_text.replace(old_q_params, new_q_params)

# 2b. Remove the active filters toolbar
old_q_toolbar = '''            @* Active filters toolbar *@
            @if (activeFilterCount > 0)
            {
                <div class="d-flex align-items-center gap-2 px-2 py-1 border-bottom small" style="@GetTableStyle(); border-color: currentColor !important; opacity: 0.9;">
                    <span class="badge rounded-pill" style="@GetBadgeInvertStyle()">@activeFilterCount</span>
                    <span>@L["Widget_ActiveFilters"]</span>
                    <button class="btn btn-link btn-sm p-0 ms-auto"
                            style="@GetFontColorStyle() text-decoration: none;"
                            @onclick="ClearAllFilters"
                            aria-label="@L["Widget_ClearAllFilters"]">
                        @L["Widget_ClearAllFilters"]
                    </button>
                </div>
            }

            <table'''

new_q_toolbar = '''            <table'''

if old_q_toolbar not in queue_text:
    print("ERROR: QueueGrid toolbar block not found")
    exit(1)
queue_text = queue_text.replace(old_q_toolbar, new_q_toolbar)

with open(queue_path, "w", encoding="utf-8") as f:
    f.write(queue_text)
    f.flush()
    os.fsync(f.fileno())
print(f"Fixed QueueGridWidget.razor ({len(queue_text.splitlines())} lines)")


# === Step 3: RenderWidget.razor ===
render_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Dashboard\RenderWidget.razor"
with open(render_path, "r", encoding="utf-8") as f:
    render_text = f.read()

# 3a. Update AgentGridWidget line
render_text = render_text.replace(
    '<AgentGridWidget @key="Widget.GridId" Config="Widget.Config" GridId="Widget.GridId" DarkMode="DarkMode" />',
    '<AgentGridWidget @key="Widget.GridId" Config="Widget.Config" GridId="Widget.GridId" DarkMode="DarkMode" ActiveFilterCountChanged="ActiveFilterCountChanged" />'
)

# 3b. Update QueueGridWidget line
render_text = render_text.replace(
    '<QueueGridWidget @key="Widget.GridId" Config="Widget.Config" GridId="Widget.GridId" DarkMode="DarkMode" />',
    '<QueueGridWidget @key="Widget.GridId" Config="Widget.Config" GridId="Widget.GridId" DarkMode="DarkMode" ActiveFilterCountChanged="ActiveFilterCountChanged" />'
)

# 3c. Add parameter
old_render_code = '''@code {
    [Parameter, EditorRequired] public PlacedWidget Widget { get; set; } = null!;
    [Parameter] public bool DarkMode { get; set; }
}'''

new_render_code = '''@code {
    [Parameter, EditorRequired] public PlacedWidget Widget { get; set; } = null!;
    [Parameter] public bool DarkMode { get; set; }
    [Parameter] public EventCallback<int> ActiveFilterCountChanged { get; set; }
}'''

if old_render_code not in render_text:
    print("ERROR: RenderWidget code block not found")
    exit(1)
render_text = render_text.replace(old_render_code, new_render_code)

with open(render_path, "w", encoding="utf-8") as f:
    f.write(render_text)
    f.flush()
    os.fsync(f.fileno())
print(f"Fixed RenderWidget.razor ({len(render_text.splitlines())} lines)")


# === Step 4: ScreenEditorPage.razor ===
screen_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Dashboard\ScreenEditorPage.razor"
with open(screen_path, "r", encoding="utf-8") as f:
    screen_text = f.read()

# 4a. Add state dictionary - find a good place in the code section
# Add after _dropdownRects dictionary
old_dropdown_state = '''    // Dropdown positioning (fixed + flip)
    private record DropdownRect(double Top, double Left, double Width, bool OpenUpward);
    private Dictionary<string, DropdownRect?> _dropdownRects = new();'''

new_dropdown_state = '''    // Dropdown positioning (fixed + flip)
    private record DropdownRect(double Top, double Left, double Width, bool OpenUpward);
    private Dictionary<string, DropdownRect?> _dropdownRects = new();

    // Widget filter badge state
    private Dictionary<Guid, int> _widgetFilterCounts = new();'''

if old_dropdown_state not in screen_text:
    print("ERROR: ScreenEditorPage dropdown state not found")
    exit(1)
screen_text = screen_text.replace(old_dropdown_state, new_dropdown_state)

# 4b. Update RenderWidget usage to pass callback
old_render_usage = '<RenderWidget Widget="widget" DarkMode="_darkMode" />'
new_render_usage = '<RenderWidget Widget="widget" DarkMode="_darkMode" ActiveFilterCountChanged="count => { _widgetFilterCounts[widget.Id] = count; InvokeAsync(StateHasChanged); }" />'

if old_render_usage not in screen_text:
    print("ERROR: ScreenEditorPage RenderWidget usage not found")
    exit(1)
screen_text = screen_text.replace(old_render_usage, new_render_usage)

# 4c. Update widget-header to show badge
old_header = '''                            <div class="widget-header widget-drag-handle"
                                 @onmousedown="e => StartMove(widget.Id, e)"
                                 @onmousedown:stopPropagation="true">
                                <i class="bi bi-grip-horizontal me-1"></i>@widget.Name'''

new_header = '''                            <div class="widget-header widget-drag-handle d-flex align-items-center"
                                 @onmousedown="e => StartMove(widget.Id, e)"
                                 @onmousedown:stopPropagation="true">
                                <i class="bi bi-grip-horizontal me-1"></i>
                                <span>@widget.Name</span>
                                @if (_widgetFilterCounts.GetValueOrDefault(widget.Id) > 0)
                                {
                                    <span class="badge rounded-pill bg-primary ms-1" style="font-size: 10px; padding: 2px 6px;">
                                        @_widgetFilterCounts[widget.Id]
                                    </span>
                                }'''

if old_header not in screen_text:
    print("ERROR: ScreenEditorPage widget-header not found")
    exit(1)
screen_text = screen_text.replace(old_header, new_header)

with open(screen_path, "w", encoding="utf-8") as f:
    f.write(screen_text)
    f.flush()
    os.fsync(f.fileno())
print(f"Fixed ScreenEditorPage.razor ({len(screen_text.splitlines())} lines)")
