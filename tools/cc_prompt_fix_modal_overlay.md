# CC Task: Fix DayTrend view config modal — use inline styles to escape overflow:hidden clipping

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md

## Git push
Do NOT run `git push`. Commit only.

---

## Problem

The local view settings modal renders INSIDE the widget area instead of full-screen.
Root cause: `.dashboard-widget` and `.widget-content` have `overflow: hidden` which clips
`position: fixed` descendants in Chromium. The scoped CSS class `.daytrendview-modal-overlay`
is affected by this clipping.

## Fix — `src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor`

Find the modal overlay div:
```razor
<div class="daytrendview-modal-overlay" @onclick="() => _showViewConfig = false" @onclick:stopPropagation="true">
```

Replace with inline styles (bypasses CSS scoping and `overflow: hidden` clipping):
```razor
<div style="position: fixed !important; inset: 0; z-index: 9999; background: rgba(0,0,0,0.5); display: flex; align-items: center; justify-content: center;"
     @onclick="() => _showViewConfig = false" @onclick:stopPropagation="true">
```

Also update `DayTrendWidget.razor.css` — remove the now-unused `.daytrendview-modal-overlay` rule
(the style is now inline). Keep only the settings button styles if any remain.

---

## Implementation steps

1. Read skill files
2. `git status --short` + integrity check
3. Python atomic write + fsync (Edit tool BANNED)
4. `dotnet build CcDashboard.sln` — 0 errors
5. `bash tools/pre-commit-check.sh`
6. Commit: `fix: DayTrend view config modal uses inline position:fixed to escape overflow:hidden clipping`
7. Re-sync from HEAD

---

## Re-sync block (§0.6 PD-007)

```bash
for f in \
  "src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor" \
  "src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor.css"; do
  git show HEAD:"$f" > "$f"
  echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
