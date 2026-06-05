# CC Task: DayTrend local view config — split modal into 3 tabs (General / Queue Metrics / Agent Metrics)

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md  ← see L-34 for localization verification
Read file: .claude/skills/widget-creator/widget-creator.md

## Git push
Do NOT run `git push`. Commit only.

---

## Change: `src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor`

### 1 — Add tab state field

After `private bool _showViewConfig;` add:
```csharp
private string _viewTab = "general";  // "general" | "queue" | "agent"
```

In `OpenLocalConfigAsync()`, reset tab on open:
```csharp
_viewTab = "general";
```

### 2 — Replace modal-body content

Find the entire `<div class="modal-body">...</div>` block (lines ~71–127) and replace with:

```razor
<div class="modal-body p-0">
    <!-- Tab nav -->
    <ul class="nav nav-tabs px-3 pt-2">
        <li class="nav-item">
            <button class="nav-link @(_viewTab == "general" ? "active" : "")"
                    @onclick='() => _viewTab = "general"'>
                @L["DayTrend_TabGeneral"]
            </button>
        </li>
        <li class="nav-item">
            <button class="nav-link @(_viewTab == "queue" ? "active" : "")"
                    @onclick='() => _viewTab = "queue"'>
                @L["DayTrend_TabQueueMetrics"]
            </button>
        </li>
        <li class="nav-item">
            <button class="nav-link @(_viewTab == "agent" ? "active" : "")"
                    @onclick='() => _viewTab = "agent"'>
                @L["DayTrend_TabAgentMetrics"]
            </button>
        </li>
    </ul>

    <div class="tab-content p-3" style="max-height: 420px; overflow-y: auto;">

        @* Tab: General *@
        @if (_viewTab == "general")
        {
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
            <!-- Chart type -->
            <div class="mb-3">
                <label class="form-label fw-semibold">@L["DayTrend_ChartType"]</label>
                <select class="form-select form-select-sm" @bind="_viewChartType">
                    <option value="line">@L["DayTrend_ChartLine"]</option>
                    <option value="bar">@L["DayTrend_ChartBar"]</option>
                    <option value="area">@L["DayTrend_ChartArea"]</option>
                    <option value="step">@L["DayTrend_ChartStep"]</option>
                </select>
            </div>
        }

        @* Tab: Queue Metrics *@
        @if (_viewTab == "queue")
        {
            @foreach (var m in _metrics)
            {
                var metric = m;
                <div class="form-check form-check-sm mb-2">
                    <input class="form-check-input" type="checkbox" id="vm_@metric.MetricId"
                           checked="@metric.Enabled"
                           @onchange="e => { var idx = _metrics.FindIndex(x => x.MetricId == metric.MetricId); if(idx>=0) _metrics[idx] = metric with { Enabled = (bool)e.Value! }; }" />
                    <label class="form-check-label" for="vm_@metric.MetricId">
                        @GetDisplayLabel(metric)
                    </label>
                </div>
            }
        }

        @* Tab: Agent Metrics *@
        @if (_viewTab == "agent")
        {
            @if (_agentMetrics.Any())
            {
                @foreach (var m in _agentMetrics)
                {
                    var metric = m;
                    <div class="form-check form-check-sm mb-2">
                        <input class="form-check-input" type="checkbox" id="vm_@metric.MetricId"
                               checked="@metric.Enabled"
                               @onchange="e => { var idx = _agentMetrics.FindIndex(x => x.MetricId == metric.MetricId); if(idx>=0) _agentMetrics[idx] = metric with { Enabled = (bool)e.Value! }; }" />
                        <label class="form-check-label" for="vm_@metric.MetricId">
                            @GetDisplayLabel(metric)
                        </label>
                    </div>
                }
            }
            else
            {
                <p class="text-muted small">@L["DayTrend_NoAgentMetrics"]</p>
            }
        }

    </div>
</div>
```

---

## Add 4 new localization keys to all 3 .resx files

### en-US
```xml
  <data name="DayTrend_TabGeneral" xml:space="preserve">
    <value>General</value>
  </data>
  <data name="DayTrend_TabQueueMetrics" xml:space="preserve">
    <value>Queue Metrics</value>
  </data>
  <data name="DayTrend_TabAgentMetrics" xml:space="preserve">
    <value>Agent Metrics</value>
  </data>
  <data name="DayTrend_NoAgentMetrics" xml:space="preserve">
    <value>No agent metrics available</value>
  </data>
```

### ru-RU
```xml
  <data name="DayTrend_TabGeneral" xml:space="preserve">
    <value>Общие</value>
  </data>
  <data name="DayTrend_TabQueueMetrics" xml:space="preserve">
    <value>Метрики очередей</value>
  </data>
  <data name="DayTrend_TabAgentMetrics" xml:space="preserve">
    <value>Метрики агентов</value>
  </data>
  <data name="DayTrend_NoAgentMetrics" xml:space="preserve">
    <value>Метрики агентов недоступны</value>
  </data>
```

### he-IL
```xml
  <data name="DayTrend_TabGeneral" xml:space="preserve">
    <value>כללי</value>
  </data>
  <data name="DayTrend_TabQueueMetrics" xml:space="preserve">
    <value>מדדי תורים</value>
  </data>
  <data name="DayTrend_TabAgentMetrics" xml:space="preserve">
    <value>מדדי סוכנים</value>
  </data>
  <data name="DayTrend_NoAgentMetrics" xml:space="preserve">
    <value>אין מדדי סוכנים זמינים</value>
  </data>
```

---

## Mandatory L-34 verification

```bash
grep -Po '(?<=@L\[")[^"]+' src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor | sort -u > /tmp/razor_keys.txt
grep -Po '(?<=<data name=")[^"]+' src/CcDashboard.Web/Resources/SharedResources.en-US.resx | sort -u > /tmp/resx_keys.txt
echo "=== Missing from en-US.resx ==="
comm -23 /tmp/razor_keys.txt /tmp/resx_keys.txt
```
Output must be EMPTY. If any key appears — fix before committing.

---

## Implementation steps

1. Read skill files (L-34 mandatory)
2. `git status --short` + integrity check
3. Python atomic write + fsync for DayTrendWidget.razor (replace modal-body, add _viewTab field)
4. Python atomic write + fsync for all 3 .resx files (add 4 new keys)
5. Run L-34 verification — must be empty
6. `dotnet build CcDashboard.sln` — 0 errors
7. `bash tools/pre-commit-check.sh`
8. Commit: `feat: DayTrend local view config — 3-tab layout (General / Queue / Agent Metrics)`
9. Re-sync from HEAD

---

## Re-sync block (§0.6 PD-007)

```bash
for f in \
  "src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor" \
  "src/CcDashboard.Web/Resources/SharedResources.en-US.resx" \
  "src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx" \
  "src/CcDashboard.Web/Resources/SharedResources.he-IL.resx"; do
  git show HEAD:"$f" > "$f"
  echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
