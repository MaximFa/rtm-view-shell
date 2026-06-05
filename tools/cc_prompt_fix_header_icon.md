# CC Task: Fix DayTrend settings icon position — remove editor padding in fullscreen

## Git push
Do NOT run `git push`. Commit only.

## SCOPE: ONE FILE
`src/CcDashboard.Web/wwwroot/app.css`

---

## Step 0 — Integrity check

```bash
cd "D:\Claude\Projects\RTM View Shell"
for f in $(git diff --name-only HEAD 2>/dev/null); do
    H=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    W=$(wc -l < "$f" 2>/dev/null)
    if [ "$H" -gt 5 ] && [ "$W" -lt $(( H * 90 / 100 )) ]; then
        git show HEAD:"$f" > "$f" && echo "Restored: $f"
    fi
done && sync
```

---

## Fix — app.css

Find the existing `.fullscreen-canvas .dashboard-widget` rule (or `.fullscreen-dashboard`
section — there should be fullscreen-specific overrides near line 2225).

Add this rule after the existing fullscreen widget rules:

```css
/* Fullscreen: remove editor toolbar padding from header — icon sits at right edge */
.fullscreen-dashboard .widget-header {
    padding-inline-end: var(--sp-3);
}
```

This overrides the `.widget-header { padding-inline-end: 70px }` that was added
for editor toolbar buttons (which don't exist in fullscreen/view mode).

---

## Build & verify

```bash
dotnet build src/CcDashboard.Web/CcDashboard.Web.csproj
# 0 errors

git diff --name-only
# Must show ONLY app.css
```

---

## Commit

```bash
bash tools/pre-commit-check.sh src/CcDashboard.Web/wwwroot/app.css
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add src/CcDashboard.Web/wwwroot/app.css
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "fix: remove editor padding from widget-header in fullscreen — settings icon now at right edge"
cp /tmp/cc-idx .git/index
git log --oneline -3
```

## Re-sync

```bash
git show HEAD:"src/CcDashboard.Web/wwwroot/app.css" > "src/CcDashboard.Web/wwwroot/app.css"
sync
```
