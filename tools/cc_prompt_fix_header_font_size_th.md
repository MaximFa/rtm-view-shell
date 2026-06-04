# CC Task: Fix Header Font Size — apply to <th> cells, not just <thead>

## Problem
`GetTheadStyle()` sets `font-size` on `<thead>` but Bootstrap's CSS resets `font-size`
on `<th>` elements, preventing inheritance. The `<th>` cells use `GetTheadCellStyle()`
which does not include `font-size`, so Header Font Size has no visible effect.

## Fix
Add `font-size` to `GetTheadCellStyle()` in both QueueGridWidget and AgentGridWidget.

## Files
1. `src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor`
2. `src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor`

## Working directory
`D:\Claude\Projects\RTM View Shell`

## Rules
- CLAUDE.md §0.3 — Edit tool BANNED. All writes via Python with os.fsync()
- CLAUDE.md §0.5 — pre-commit-check.sh before commit
- CLAUDE.md §0.6 — post-commit verification mandatory
- CLAUDE.md §37  — do NOT git push automatically

---

## Change 1 — QueueGridWidget.razor

Find:
```csharp
    private string GetTheadCellStyle()
    {
        var color = !string.IsNullOrEmpty(EffectiveFontColor) ? EffectiveFontColor : "#ffffff";
        return $"white-space: nowrap; color: {color};";
    }
```

Replace with:
```csharp
    private string GetTheadCellStyle()
    {
        var color = !string.IsNullOrEmpty(EffectiveFontColor) ? EffectiveFontColor : "#ffffff";
        var headerFs = !string.IsNullOrEmpty(_headerFontSize) ? _headerFontSize : _fontSize;
        var fs = ResolveFontSizePx(headerFs);
        return $"white-space: nowrap; color: {color}; font-size: {fs};";
    }
```

## Change 2 — AgentGridWidget.razor

Find:
```csharp
    private string GetTheadCellStyle()
    {
        var color = !string.IsNullOrEmpty(EffectiveFontColor) ? EffectiveFontColor : "#ffffff";
        return $"white-space: nowrap; color: {color};";
    }
```

Replace with:
```csharp
    private string GetTheadCellStyle()
    {
        var color = !string.IsNullOrEmpty(EffectiveFontColor) ? EffectiveFontColor : "#ffffff";
        var headerFs = !string.IsNullOrEmpty(_headerFontSize) ? _headerFontSize : _fontSize;
        var fs = ResolveFontSizePx(headerFs);
        return $"white-space: nowrap; color: {color}; font-size: {fs};";
    }
```

---

## Verification

```bash
grep -A 4 "GetTheadCellStyle" \
  src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
  src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor | grep "font-size"
# Must show 2 matches
```

---

## Commit

```bash
bash tools/pre-commit-check.sh \
  src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
  src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor
# Only if exit code 0:
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
  src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
  src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor \
  tools/cc_prompt_fix_header_font_size_th.md
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix: apply Header Font Size to <th> cells via GetTheadCellStyle (was only on <thead>)"
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
for f in src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor \
          src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor \
          tools/cc_prompt_fix_header_font_size_th.md; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
