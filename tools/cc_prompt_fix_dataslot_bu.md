# CC Task: Fix DataSlot Business Unit — not saved to RTS Row (UnionId=NULL)

## Problem
DataSlot widgets never receive data from RTM because RTM Engine silently skips
cells whose Row.UnionId is not in UnionList. Root cause: two bugs in Shell.

**Bug 1 — SelectBusinessUnit doesn't update ConfigDataSlotBusinessUnitId**
`SelectBusinessUnit(bu)` only sets `ConfigBusinessUnit` (string) and `BuSearchText`.
It does NOT set `ConfigDataSlotBusinessUnitId` (int?). So `SaveDataSlotRtsCommand`
always receives `BusinessUnitId = null` → RTSGrid_Row gets `UnionId = NULL` →
RTM Engine: `UnionList.ContainsKey(NULL→0)` → false → cell skipped → no data.

**Bug 2 — Load DataSlot doesn't restore BU dropdown state**
When editing an existing DataSlot widget, `ConfigDataSlotBusinessUnitId` is loaded
from `widget.Config` but `ConfigBusinessUnit` (the string shown in the BU dropdown)
and `BuSearchText` (the display text) are NOT set. The BU dropdown appears empty.

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

## Change 1 — SelectBusinessUnit (around line 4003)

Find:
```csharp
    private void SelectBusinessUnit(BusinessUnitDto? bu)
    {
        ConfigBusinessUnit = bu?.BusinessUnitId.ToString();
        BuSearchText = bu?.BusinessUnitName ?? "";
        BuDropdownOpen = false;
    }
```

Replace with:
```csharp
    private void SelectBusinessUnit(BusinessUnitDto? bu)
    {
        ConfigBusinessUnit = bu?.BusinessUnitId.ToString();
        BuSearchText = bu?.BusinessUnitName ?? "";
        BuDropdownOpen = false;
        // Sync to DataSlot-specific field so SaveDataSlotRtsCommand gets correct UnionId
        ConfigDataSlotBusinessUnitId = bu?.BusinessUnitId;
    }
```

---

## Change 2 — Load DataSlot config (around line 3273)

Find:
```csharp
        // Data Slot specific
        ConfigDataSlotTitle = widget.Config.DataSlotTitle ?? "";
        ConfigDataSlotMetricId = widget.Config.DataSlotMetricId;
        ConfigDataSlotBusinessUnitId = widget.Config.DataSlotBusinessUnitId;
```

Replace with:
```csharp
        // Data Slot specific
        ConfigDataSlotTitle = widget.Config.DataSlotTitle ?? "";
        ConfigDataSlotMetricId = widget.Config.DataSlotMetricId;
        ConfigDataSlotBusinessUnitId = widget.Config.DataSlotBusinessUnitId;
        // Restore BU dropdown display state
        ConfigBusinessUnit = widget.Config.DataSlotBusinessUnitId?.ToString();
        if (widget.Config.DataSlotBusinessUnitId.HasValue)
        {
            var savedBu = BusinessUnits.FirstOrDefault(b => b.BusinessUnitId == widget.Config.DataSlotBusinessUnitId.Value);
            BuSearchText = savedBu?.BusinessUnitName ?? "";
        }
```

---

## Verification

```bash
grep -n "ConfigDataSlotBusinessUnitId = bu" \
  src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor
# Must return 1 line in SelectBusinessUnit

grep -n "Restore BU dropdown" \
  src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor
# Must return 1 line
```

---

## Commit

```bash
bash tools/pre-commit-check.sh \
  src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor
# Only if exit code 0:
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
  src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor \
  tools/cc_prompt_fix_dataslot_bu.md
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix: DataSlot BU not saved to RTS Row (UnionId=NULL) — SelectBusinessUnit now updates ConfigDataSlotBusinessUnitId"
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
          tools/cc_prompt_fix_dataslot_bu.md; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
