# CC Task: DayTrend modal — split into 3 tabs (General / Queue Metrics / Agent Metrics)

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md

## Git push
Do NOT run `git push`. Commit only.

## SCOPE: ONE FILE ONLY
Only `src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor` may be changed.
Do NOT touch: LogoutPage.razor, App.razor, any .resx file, any .cs file, any other .razor file.
The localization keys DayTrend_TabGeneral / DayTrend_TabQueueMetrics / DayTrend_TabAgentMetrics
already exist in all .resx files — do not add or change them.

---

## Step 0 — Mandatory integrity check (§0.6a)

```bash
cd "D:\Claude\Projects\RTM View Shell"
for f in $(git diff --name-only HEAD 2>/dev/null); do
    H=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    W=$(wc -l < "$f" 2>/dev/null)
    if [ "$H" -gt 5 ] && [ "$W" -lt $(( H * 90 / 100 )) ]; then
        echo "TRUNCATED: $f — restoring"; git show HEAD:"$f" > "$f"
    fi
done && sync && echo "=== Integrity OK ==="
```

---

## Change — DayTrendWidget.razor

### 1 — Add `_viewTab` field

After `private bool _showViewConfig;` add:
```csharp
private string _viewTab = "general";
```

In `OpenLocalConfigAsync()`, add before `_showViewConfig = true;`:
```csharp
_viewTab = "general";
```

### 2 — Replace modal-body

Find:
```razor
<div class="modal-body" style="max-height: 70vh; overflow-y: auto;">
```
...down to and including its closing `</div>`.

Replace the entire block with:

```razor
<div class="modal-body p-0">
    <ul class="nav nav-tabs px-3 pt-2 border-bottom">
        <li class="nav-item">
            <button class="nav-link @(_viewTab=="general"?"active":"")"
                    @onclick='()=>_viewTab="general"'>
                @L["DayTrend_TabGeneral"]
            </button>
        </li>
        <li class="nav-item">
            <button class="nav-link @(_viewTab=="queue"?"active":"")"
                    @onclick='()=>_viewTab="queue"'>
                @L["DayTrend_TabQueueMetrics"]
            </button>
        </li>
        <li class="nav-item">
            <button class="nav-link @(_viewTab=="agent"?"active":"")"
                    @onclick='()=>_viewTab="agent"'>
                @L["DayTrend_TabAgentMetrics"]
            </button>
        </li>
    </ul>
    <div style="max-height: 55vh; overflow-y: auto; padding: 1rem;">

        @if (_viewTab == "general")
        {
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

        @if (_viewTab == "queue")
        {
            @foreach (var m in _metrics)
            {
                var metric = m;
                <div class="form-check form-check-sm mb-2">
                    <input class="form-check-input" type="checkbox" id="vm_@metric.MetricId"
                           checked="@metric.Enabled"
                           @onchange="e => { var idx = _metrics.FindIndex(x => x.MetricId == metric.MetricId); if(idx>=0) _metrics[idx] = metric with { Enabled = (bool)e.Value! }; }" />
                    <label class="form-check-label" for="vm_@metric.MetricId">@GetDisplayLabel(metric)</label>
                </div>
            }
        }

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
                        <label class="form-check-label" for="vm_@metric.MetricId">@GetDisplayLabel(metric)</label>
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

## Verification

### L-34: check localization keys
```bash
grep -Po '(?<=@L\[")[^"]+' src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor | sort -u > /tmp/razor_keys.txt
grep -Po '(?<=<data name=")[^"]+' src/CcDashboard.Web/Resources/SharedResources.en-US.resx | sort -u > /tmp/resx_keys.txt
comm -23 /tmp/razor_keys.txt /tmp/resx_keys.txt
```
Output MUST be empty. If not — DO NOT commit, report the missing keys.

### Build
```bash
dotnet build CcDashboard.sln
```
Must be 0 errors.

### Check only ONE file changed
```bash
git diff --name-only
```
Must show ONLY `src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor`.

---

## Commit

```bash
bash tools/pre-commit-check.sh src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor
```
Exit code 0 only, then:
```bash
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "feat: DayTrend view config — 3-tab modal (General/Queue/Agent)"
cp /tmp/cc-idx .git/index
git log --oneline -3
```

---

## Re-sync (§0.6 PD-007)

```bash
git show HEAD:"src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor" \
  > "src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor"
sync
echo "Re-synced: $(wc -l < src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor) lines"
```
