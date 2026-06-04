# CC Task: Fix DataSlot GridId — preassignedGridId not set from RTSGrid result

## Problem
For DataSlot widgets, `preassignedGridId` is never set after the RTS save.
This causes `SaveDashboardWidgetCommand` to auto-generate `dashboard_widgets.GridId`
from the DB identity sequence instead of using the actual `RTSGrid_Grid.GridId`.
Result: the configurator shows a wrong GridId (e.g. 92 from dashboard_widgets)
while the actual RTSGrid GridId is different (e.g. 37).

QueueGrid has the identical fix on line 4148:
```csharp
preassignedGridId = queueGridId;  // Sync dashboard_widgets.GridId with RTSGrid_Grid.GridId
```

## Fix — one line in ScreenEditorPage.razor

Find (around line 4290):
```csharp
                _dataSlotGridId = rtsResult.GridId;
                _dataSlotColumnId = rtsResult.ColumnId;
                _dataSlotRowId = rtsResult.RowId;
                _dataSlotCellId = rtsResult.CellId;
```

Replace with:
```csharp
                _dataSlotGridId = rtsResult.GridId;
                preassignedGridId = _dataSlotGridId;  // Sync dashboard_widgets.GridId with RTSGrid_Grid.GridId
                _dataSlotColumnId = rtsResult.ColumnId;
                _dataSlotRowId = rtsResult.RowId;
                _dataSlotCellId = rtsResult.CellId;
```

## File
`src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor`

## Working directory
`D:\Claude\Projects\RTM View Shell`

## Rules
- CLAUDE.md §0.3 — Edit tool BANNED. All writes via Python with os.fsync()
- CLAUDE.md §0.5 — pre-commit-check.sh before commit
- CLAUDE.md §0.6 — post-commit verification mandatory
- CLAUDE.md §37  — do NOT git push automatically

---

## Verification

```bash
grep -n "preassignedGridId = _dataSlotGridId" \
  src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor
# Must return 1 line
```

---

## Commit

```bash
bash tools/pre-commit-check.sh \
  src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
  src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor \
  tools/cc_prompt_fix_dataslot_gridid.md
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix: DataSlot preassignedGridId not set — dashboard_widgets.GridId now synced to RTSGrid_Grid.GridId"
cp /tmp/cc-idx .git/index
```

Post-commit (§0.6):
```bash
git status --short
git log --oneline -3
```

## Git push
Do NOT run `git push` automatically.

---

## Re-sync from HEAD (§0.6 PD-007)

```bash
for f in src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor \
          tools/cc_prompt_fix_dataslot_gridid.md; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
