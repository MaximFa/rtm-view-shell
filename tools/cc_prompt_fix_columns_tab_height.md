# Task: Remove fixed-height scroll boxes from widget configurator modals

## Problem

The AgentGrid configurator Columns tab has a hard-coded
`style="height: 400px; overflow-y: scroll;"` on the column list container.
This creates a redundant inner scrollbar while the modal body (`height: 700px;
overflow-y: auto`) already handles overflow. The list stops at 400px even though
the modal has more space available.

## File: src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor

### Fix 1 — AgentGrid Columns tab (main issue)

Find:
```html
<div class="columns-table-body" style="height: 400px; overflow-y: scroll;" @onscroll="CloseMetricDropdown">
```

Replace with:
```html
<div class="columns-table-body" @onscroll="CloseMetricDropdown">
```

### Fix 2 — Score formula list

Find:
```html
<div class="score-formula-list border rounded p-2" style="max-height: 300px; overflow-y: auto;">
```

Replace with:
```html
<div class="score-formula-list border rounded p-2">
```

## File: src/CcDashboard.Web/wwwroot/app.css

### Fix 3 — .columns-table-body CSS

Find `.columns-table-body` block and remove `padding-bottom: 200px`:

```css
.columns-table-body {
    border: 1px solid var(--clr-border);
    border-radius: var(--r-md);
    overflow-x: hidden;
}
```

### Fix 4 — .columns-tab CSS

Find `.columns-tab` block and remove `min-height: 350px`:

```css
.columns-tab {
    overflow-x: hidden;
}
```

## Do NOT change

- Dropdown menus: `max-height: 200px; overflow-y: auto; position: absolute` — keep as-is
- `modal-body` style — keep as-is
- Any `overflow-x: hidden` declarations

## Verification

```bash
dotnet build src/CcDashboard.Web --no-restore
```

After deploy: Columns tab fills the modal to the bottom with no inner scrollbar.

## Git push
Do NOT run `git push` automatically. Commit only.

## Mandatory pre-commit check

```bash
bash tools/pre-commit-check.sh
```

## Commit message

```
fix: remove fixed height scroll boxes from configurator modals

columns-table-body had height: 400px; overflow-y: scroll creating redundant
inner scroll frame. score-formula-list had max-height: 300px. Both removed;
modal-body overflow handles the scrolling naturally.
```
