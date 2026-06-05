# CC Task: DayTrend local view settings — split into 3 tabs (General / Queue Metrics / Agent Metrics)

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md

## Git push
Do NOT run `git push`. Commit only.

---

## Step 0 — Mandatory integrity check (§0.6a)

```bash
cd "D:\Claude\Projects\RTM View Shell"
for f in $(git diff --name-only HEAD 2>/dev/null); do
    H=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    W=$(wc -l < "$f" 2>/dev/null)
    if [ "$H" -gt 5 ] && [ "$W" -lt $(( H * 90 / 100 )) ]; then
        echo "TRUNCATED: $f (HEAD=$H wt=$W) — restoring"
        git show HEAD:"$f" > "$f"
    fi
done && sync && echo "=== Integrity OK ==="
```

---

## Step 0a — Commit pending docs changes first

```bash
cd "D:\Claude\Projects\RTM View Shell"
git diff --name-only HEAD
```

If `.claude/skills/widget-planner/widget-planner.md` or `CLAUDE.md` or `tools/` files appear as M:

```bash
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add .claude/ CLAUDE.md tools/pre-commit-check.sh tools/integrity-check-block.md tools/cc_prompt_modal_tabs_v2.md 2>/dev/null || true
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "docs: widget-planner L-32..L-35, CLAUDE.md §0.6a integrity check, pre-commit threshold 10%"
cp /tmp/cc-idx .git/index
```

Verify: `git log --oneline -2`

---

## Change — `src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor`

### 1 — Add `_viewTab` field

After `private bool _showViewConfig;` add:
```csharp
private string _viewTab = "general";
```

In `OpenLocalConfigAsync()`, add before `_showViewConfig = true;`:
```csharp
_viewTab = "general";
```

### 2 — Replace `<div class="modal-body" ...>` block

Find the entire `<div class="modal-body" style="max-height: 70vh; overflow-y: auto;">...</div>` block
and replace with:

```razor
<div class="modal-body p-0">
    <ul class="nav nav-tabs px-3 pt-2 border-bottom">
        <li class="nav-item">
            <button class="nav-link @(_viewTab=="general"?"active":"")" @onclick='()=>_viewTab="general"'>
                @L["DayTrend_TabGeneral"]
            </button>
        </li>
        <li class="nav-item">
            <button class="nav-link @(_viewTab=="queue"?"active":"")" @onclick='()=>_viewTab="queue"'>
                @L["DayTrend_TabQueueMetrics"]
            </button>
        </li>
        <li class="nav-item">
            <button class="nav-link @(_viewTab=="agent"?"active":"")" @onclick='()=>_viewTab="agent"'>
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

### 3 — Add missing localization keys

Check if these keys exist in all 3 .resx files. Add if missing:

**en-US:** `DayTrend_TabGeneral`=General, `DayTrend_TabQueueMetrics`=Queue Metrics, `DayTrend_TabAgentMetrics`=Agent Metrics, `DayTrend_NoAgentMetrics`=No agent metrics available

**ru-RU:** `DayTrend_TabGeneral`=Общие, `DayTrend_TabQueueMetrics`=Метрики очередей, `DayTrend_TabAgentMetrics`=Метрики агентов, `DayTrend_NoAgentMetrics`=Метрики агентов недоступны

**he-IL:** `DayTrend_TabGeneral`=כללי, `DayTrend_TabQueueMetrics`=מדדי תורים, `DayTrend_TabAgentMetrics`=מדדי סוכנים, `DayTrend_NoAgentMetrics`=אין מדדי סוכנים זמינים

### 4 — L-34 verification (MANDATORY)

```bash
grep -Po '(?<=@L\[")[^"]+' src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor | sort -u > /tmp/razor_keys.txt
grep -Po '(?<=<data name=")[^"]+' src/CcDashboard.Web/Resources/SharedResources.en-US.resx | sort -u > /tmp/resx_keys.txt
comm -23 /tmp/razor_keys.txt /tmp/resx_keys.txt
# Output must be EMPTY
```

---

## Implementation steps

1. Read skill files
2. Step 0 integrity check
3. Python atomic write + fsync for DayTrendWidget.razor (Edit BANNED)
4. Python atomic write + fsync for .resx files if keys missing
5. L-34 verification — must be empty
6. `dotnet build CcDashboard.sln` — 0 errors
7. `bash tools/pre-commit-check.sh`
8. Commit: `feat: DayTrend local view settings — 3-tab layout (General/Queue/Agent)`
9. Re-sync from HEAD

---

## Re-sync (§0.6 PD-007)

```bash
for f in \
  "src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor" \
  "src/CcDashboard.Web/Resources/SharedResources.en-US.resx" \
  "src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx" \
  "src/CcDashboard.Web/Resources/SharedResources.he-IL.resx"; do
  git show HEAD:"$f" > "$f" && echo "Re-synced: $f"
done && sync
```
