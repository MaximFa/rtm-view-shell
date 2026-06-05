# CC Task: DayTrend — null values show as 0 + draggable modal header

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md

## Git push
Do NOT run `git push`. Commit only.

## SCOPE: 3 files only
- `src/CcDashboard.Web/wwwroot/js/daytrendChart.js`
- `src/CcDashboard.Web/wwwroot/js/app.js`
- `src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor`

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

## Fix 1 — daytrendChart.js: null values → 0

In `configuredDatasets.map(ds => ...)`, find where `data: ds.data` is set and replace:

```javascript
// BEFORE
data: ds.data,
```

```javascript
// AFTER — map null/undefined to 0 so gaps show as flat zero line
data: ds.data.map(v => (v === null || v === undefined) ? 0 : v),
```

---

## Fix 2 — app.js: add makeModalDraggable and resetModalPosition

At the END of `app.js`, add:

```javascript
window.ccApp = window.ccApp || {};

window.ccApp.makeModalDraggable = function (header, dialog) {
    if (!header || !dialog) return;
    var offsetX = 0, offsetY = 0, startX = 0, startY = 0;
    header.style.cursor = 'move';
    header.onmousedown = function (e) {
        e.preventDefault();
        startX = e.clientX - offsetX;
        startY = e.clientY - offsetY;
        document.onmouseup = function () {
            document.onmousemove = null;
            document.onmouseup = null;
        };
        document.onmousemove = function (e) {
            offsetX = e.clientX - startX;
            offsetY = e.clientY - startY;
            dialog.style.transform = 'translate(' + offsetX + 'px, ' + offsetY + 'px)';
        };
    };
};

window.ccApp.resetModalPosition = function (dialog) {
    if (dialog) dialog.style.transform = '';
};
```

---

## Fix 3 — DayTrendWidget.razor: draggable modal

### 3a — Add ElementReference fields

After `private bool _showViewConfig;` add:
```csharp
private ElementReference _modalHeader;
private ElementReference _modalDialog;
```

### 3b — Add CloseModal method

Add after `ApplyViewConfigAsync()`:
```csharp
private async Task CloseModal()
{
    _showViewConfig = false;
    try { await JS.InvokeVoidAsync("ccApp.resetModalPosition", _modalDialog); }
    catch { }
}
```

### 3c — Add OnAfterRenderAsync

Add after `CloseModal()`:
```csharp
protected override async Task OnAfterRenderAsync(bool firstRender)
{
    if (_showViewConfig)
    {
        try { await JS.InvokeVoidAsync("ccApp.makeModalDraggable", _modalHeader, _modalDialog); }
        catch { }
    }
}
```

### 3d — Add @ref to modal dialog and header

In the modal HTML, find:
```razor
<div class="modal-dialog modal-lg" @onclick:stopPropagation="true">
    <div class="modal-content">
        <div class="modal-header py-2">
```

Replace with:
```razor
<div class="modal-dialog modal-lg" @ref="_modalDialog" @onclick:stopPropagation="true">
    <div class="modal-content">
        <div class="modal-header py-2" @ref="_modalHeader">
```

### 3e — Replace all close handlers with CloseModal

Replace every occurrence of:
```razor
@onclick="() => _showViewConfig = false"
```
With:
```razor
@onclick="CloseModal"
```
(There should be 2-3 occurrences: X button, backdrop click, Cancel button)

---

## Verification

```bash
# null→0 fix
grep "map(v =>" src/CcDashboard.Web/wwwroot/js/daytrendChart.js

# draggable functions
grep "makeModalDraggable\|resetModalPosition" src/CcDashboard.Web/wwwroot/js/app.js

# refs and CloseModal
grep "_modalHeader\|_modalDialog\|CloseModal" src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor

# only 3 files changed
git diff --name-only
```

Build: `dotnet build src/CcDashboard.Web/CcDashboard.Web.csproj` — 0 errors.

---

## Commit

```bash
bash tools/pre-commit-check.sh \
  src/CcDashboard.Web/wwwroot/js/daytrendChart.js \
  src/CcDashboard.Web/wwwroot/js/app.js \
  src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
  src/CcDashboard.Web/wwwroot/js/daytrendChart.js \
  src/CcDashboard.Web/wwwroot/js/app.js \
  src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "feat: DayTrend — null values show as 0; draggable modal by header (L-36)"
cp /tmp/cc-idx .git/index
git log --oneline -3
```

---

## Re-sync (§0.6 PD-007)

```bash
for f in \
  "src/CcDashboard.Web/wwwroot/js/daytrendChart.js" \
  "src/CcDashboard.Web/wwwroot/js/app.js" \
  "src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor"; do
  git show HEAD:"$f" > "$f" && echo "Re-synced: $f"
done && sync
```
