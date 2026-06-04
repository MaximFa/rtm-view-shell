# CC Task: Restore truncated working tree files from HEAD + push

## MANDATORY RULES (CLAUDE.md §0)
§0.2 — session-resume integrity check: git status + tail -3 on every M file.
§0.3 — Edit tool BANNED. Use `git show HEAD:"$f" > "$f"` for restoration.

---

## ANALYSIS (Cowork pre-checked — do NOT re-investigate)

Commit `6259977` already has the correct code in HEAD:
- `feat(widgets): time ticker for QueueGrid + DataSlot RowNumber fix + MetricFormat pipeline`

All 6 M files in working tree are TRUNCATED (Cowork mount partial-write, PD-005 pattern).
The application compiles from WT source → truncated files → fixes not active at runtime.

Truncation table:
```
src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor   WT=512  HEAD=533
src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor  WT=1288 HEAD=1387
tools/SignalRSimulator/Generators/MetricDataGenerator.cs       WT=144  HEAD=161
tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs                 WT=312  HEAD=314
tools/SignalRSimulator/Models/GridModels.cs                    WT=61   HEAD=63
tools/SignalRSimulator/Services/DbMetricService.cs             WT=227  HEAD=233
```

---

## Step 1 — Restore all truncated files from HEAD

```bash
cd "$(git rev-parse --show-toplevel)"

for f in \
  "src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor" \
  "src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor" \
  "tools/SignalRSimulator/Generators/MetricDataGenerator.cs" \
  "tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs" \
  "tools/SignalRSimulator/Models/GridModels.cs" \
  "tools/SignalRSimulator/Services/DbMetricService.cs"; do
    git show HEAD:"$f" > "$f"
    wt=$(wc -l < "$f")
    hd=$(git show HEAD:"$f" | wc -l)
    last=$(tail -1 "$f")
    echo "WT=$wt HEAD=$hd last='$last'  $f"
done
```

Expected results:
```
WT=533  HEAD=533  last='}'  DataSlotWidget.razor
WT=1387 HEAD=1387 last='}'  QueueGridWidget.razor
WT=161  HEAD=161  last='}'  MetricDataGenerator.cs
WT=314  HEAD=314  last='}'  RtmSimulatorHub.cs
WT=63   HEAD=63   last='}'  GridModels.cs
WT=233  HEAD=233  last='}'  DbMetricService.cs
```

If any WT != HEAD — STOP and report. Do NOT proceed to Step 2.

---

## Step 2 — Verify working tree is clean

```bash
cd "$(git rev-parse --show-toplevel)"
git status --short | grep -E "^M (src|tools)"
```

Expected: no output (all 6 restored files match HEAD → no longer M).
If any still show M → `git diff HEAD -- <file>` to investigate.

---

## Step 3 — Verify key fix is present in MetricDataGenerator.cs

```bash
grep -n "DataType.*Time.*OrdinalIgnoreCase" tools/SignalRSimulator/Generators/MetricDataGenerator.cs
```

Expected: at least one match in `GenerateNumberValue` method.
If no match — the restore failed. Re-run Step 1.

---

## Step 4 — Verify RowNumber fix in DbMetricService.cs

```bash
grep -n "RowNumber" tools/SignalRSimulator/Services/DbMetricService.cs
```

Expected: no output (the `AND r."RowNumber" > 1` filter was removed in commit `6259977`).
If output shows RowNumber — the restore failed. Re-run Step 1.

---

## Step 5 — Push to origin

```bash
cd "$(git rev-parse --show-toplevel)"
git push origin v2
git log --oneline -3
```

Expected: push succeeds and log shows `6259977` as one of the top 3 commits.

---

## Step 6 — Re-sync working tree from HEAD (CLAUDE.md §0.6 PD-007)

Cowork asynchronously writes its file cache back to disk after the CC session ends,
overwriting files with truncated content. Re-sync all files from HEAD as the final
step to maximise the window before Cowork's write-back occurs.

```bash
cd "$(git rev-parse --show-toplevel)"
for f in   "src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor"   "src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor"   "tools/SignalRSimulator/Generators/MetricDataGenerator.cs"   "tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs"   "tools/SignalRSimulator/Models/GridModels.cs"   "tools/SignalRSimulator/Services/DbMetricService.cs"; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```

Final check — all line counts must match HEAD:
```bash
for f in   "src/CcDashboard.Web/Components/Widgets/DataSlotWidget.razor"   "src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor"   "tools/SignalRSimulator/Generators/MetricDataGenerator.cs"   "tools/SignalRSimulator/Hubs/RtmSimulatorHub.cs"   "tools/SignalRSimulator/Models/GridModels.cs"   "tools/SignalRSimulator/Services/DbMetricService.cs"; do
  wt=$(wc -l < "$f")
  hd=$(git show HEAD:"$f" | wc -l)
  [ "$wt" -eq "$hd" ] && echo "OK  WT=$wt  $f" || echo "FAIL WT=$wt HEAD=$hd  $f"
done
```

All lines must show OK. If any FAIL — re-run the git show loop for that file.
