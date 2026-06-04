# CC Task: Fix timer reset on page refresh (refreshCells uses stale elapsed instead of original datetime)

## Problem
On page refresh, timer cells (e.g. WAIT TIME in QueueGrid, DataSlot) reset to ~00:01
instead of continuing from actual elapsed time.

**Root cause (confirmed via code trace):**

1. `Grid_GridEvent` receives raw cell value `"+04/06/2026 22:00:10"` (original datetime),
   stores it in `CellData.Value2`, then processes it to elapsed `"+00:00:10"` and
   stores result in `CellData.Value`. `_allCellsData` caches `CellData` with
   `Value = "+00:00:10"` (elapsed) and `Value2 = "+04/06/2026 22:00:10"` (original).

2. `refreshCells` reads `cellValue.Value.Value` = `"+00:00:10"` (elapsed).
   The `+` check fires, tries `ParseExact("00:00:10", "dd/MM/yyyy HH:mm:ss")` → FAILS
   → catch block → `value = "&nbsp;"`.

3. Shell receives `"&nbsp;"` → no timer anchor → blank cell → next regular push
   sends fresh elapsed which appears as near-zero reset.

**Fix:** In `refreshCells`, read `Value2` (original datetime) instead of `Value` (processed
elapsed). `Value2` is set before processing in `Grid_GridEvent` and always holds the raw
metric output (`"+dd/MM/yyyy HH:mm:ss"`). `refreshCells` can then correctly compute
elapsed from `DateTime.Now - original_datetime`.

## File
`RTM/RTM/Engine.cs`

## Working directory
`D:\Claude\Projects\RTM View Shell`

## Environment rules
- CLAUDE.md §0.3 — Edit tool BANNED. All writes via Python with os.fsync()
- CLAUDE.md §0.5 — bash tools/pre-commit-check.sh before commit
- CLAUDE.md §0.6 — post-commit verification mandatory
- CLAUDE.md §37  — do NOT git push automatically

---

## Change — Engine.cs, method refreshCells (around line 1378)

Find this exact line inside `refreshCells`:
```csharp
                    string value = cellValue.Value.Value;
```

Replace with:
```csharp
                    string value = !string.IsNullOrEmpty(cellValue.Value.Value2)
                                   ? cellValue.Value.Value2   // original datetime ("+dd/MM/yyyy HH:mm:ss")
                                   : cellValue.Value.Value;   // fallback to processed value
```

This ensures `refreshCells` always works from the original datetime so it can
correctly compute the current elapsed time — identical logic to `Grid_GridEvent`.

**Context check:** the surrounding code should look like:
```csharp
foreach (var cellValue in _allCellsData.Get(gridId))
{
    int cellId = cellValue.Key;
    string value = !string.IsNullOrEmpty(cellValue.Value.Value2)  // ← changed line
                   ? cellValue.Value.Value2
                   : cellValue.Value.Value;
    CellData cell = new CellData(cellId, new GridData(gridId));

    // ================================================

    if (!string.IsNullOrWhiteSpace(value) && (value[0] == '+'))
    {
        try
        {
            char firstChr = value[0];
            value = value.Substring(1);
            DateTime signonTimeDT = DateTime.ParseExact(value, "dd/MM/yyyy HH:mm:ss", ...);
```

---

## Verification

```bash
grep -n "Value2" RTM/RTM/Engine.cs | grep -i "refresh\|cellValue\.Value"
# Must show the new line in refreshCells context
```

---

## Commit

```bash
bash tools/pre-commit-check.sh RTM/RTM/Engine.cs
# Only if exit code 0:
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add RTM/RTM/Engine.cs tools/cc_prompt_fix_refreshcells_timer.md
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix: refreshCells uses original datetime (Value2) to correctly compute elapsed on page refresh"
cp /tmp/cc-idx .git/index
```

Post-commit (§0.6):
```bash
git status --short
git log --oneline -3
```

## Git push
Do NOT run `git push` automatically. Commit only. Push will be requested separately.

---

## Re-sync from HEAD (§0.6 PD-007, mandatory last step)

```bash
for f in RTM/RTM/Engine.cs \
          tools/cc_prompt_fix_refreshcells_timer.md; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
