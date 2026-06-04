# CC Task: Widget resize from all sides + modal drag by full header

## Goals
1. Widgets: add resize handles for all 8 directions (currently only e, s, se).
   N/W handles must update BOTH size AND position (top/left).
2. Configurator modal: make entire header row draggable (not just the grip icon).

## Files to change
1. `src/CcDashboard.Web/wwwroot/js/widget-resize.js`
2. `src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor`
3. `src/CcDashboard.Web/wwwroot/app.css`

## Working directory
`D:\Claude\Projects\RTM View Shell`

## Rules
- CLAUDE.md §0.3 — Edit tool BANNED. All writes via Python with os.fsync()
- CLAUDE.md §0.5 — pre-commit-check.sh before commit
- CLAUDE.md §0.6 — post-commit verification mandatory
- CLAUDE.md §37  — do NOT git push automatically

---

## Change 1 — widget-resize.js

### 1a. startResize — also save startLeft/startTop
Find:
```javascript
    startResize: function (widgetId, handle, coords) {
        const widget = document.querySelector(`[data-widget-id="${widgetId}"]`);
        if (!widget) return;

        this.activeWidget = { id: widgetId, element: widget, handle: handle };
        this.mode = 'resize';
        this.startX = coords.clientX;
        this.startY = coords.clientY;
        this.startWidth = widget.offsetWidth;
        this.startHeight = widget.offsetHeight;
```
Replace with:
```javascript
    startResize: function (widgetId, handle, coords) {
        const widget = document.querySelector(`[data-widget-id="${widgetId}"]`);
        if (!widget) return;

        const style = window.getComputedStyle(widget);
        this.activeWidget = { id: widgetId, element: widget, handle: handle };
        this.mode = 'resize';
        this.startX = coords.clientX;
        this.startY = coords.clientY;
        this.startWidth = widget.offsetWidth;
        this.startHeight = widget.offsetHeight;
        this.startLeft = parseInt(style.left) || 0;
        this.startTop = parseInt(style.top) || 0;
```

### 1b. onMouseMove — add n/w resize logic
Find:
```javascript
        if (this.mode === 'resize') {
            const handle = this.activeWidget.handle;
            let newWidth = this.startWidth;
            let newHeight = this.startHeight;

            if (handle.includes('e')) newWidth = Math.max(150, this.startWidth + deltaX);
            if (handle.includes('s')) newHeight = Math.max(100, this.startHeight + deltaY);

            // Snap to grid (10px)
            newWidth = Math.round(newWidth / 10) * 10;
            newHeight = Math.round(newHeight / 10) * 10;

            widget.style.width = newWidth + 'px';
            widget.style.height = newHeight + 'px';
```
Replace with:
```javascript
        if (this.mode === 'resize') {
            const handle = this.activeWidget.handle;
            let newWidth = this.startWidth;
            let newHeight = this.startHeight;
            let newLeft = this.startLeft;
            let newTop = this.startTop;

            if (handle.includes('e')) newWidth = Math.max(150, this.startWidth + deltaX);
            if (handle.includes('s')) newHeight = Math.max(100, this.startHeight + deltaY);
            if (handle.includes('w')) {
                newWidth = Math.max(150, this.startWidth - deltaX);
                newLeft = this.startLeft + (this.startWidth - newWidth);
            }
            if (handle.includes('n')) {
                newHeight = Math.max(100, this.startHeight - deltaY);
                newTop = this.startTop + (this.startHeight - newHeight);
            }

            // Snap to grid (10px)
            newWidth = Math.round(newWidth / 10) * 10;
            newHeight = Math.round(newHeight / 10) * 10;
            newLeft = Math.round(newLeft / 10) * 10;
            newTop = Math.round(newTop / 10) * 10;
            newLeft = Math.max(0, newLeft);
            newTop = Math.max(0, newTop);

            widget.style.width = newWidth + 'px';
            widget.style.height = newHeight + 'px';
            widget.style.left = newLeft + 'px';
            widget.style.top = newTop + 'px';
```

### 1c. onMouseUp — report position when n/w handle used
Find:
```javascript
            if (this.dotNetRef) {
                if (this.mode === 'resize') {
                    this.dotNetRef.invokeMethodAsync('OnWidgetResized', widgetId, widget.offsetWidth, widget.offsetHeight);
                } else if (this.mode === 'move') {
```
Replace with:
```javascript
            if (this.dotNetRef) {
                if (this.mode === 'resize') {
                    this.dotNetRef.invokeMethodAsync('OnWidgetResized', widgetId, widget.offsetWidth, widget.offsetHeight);
                    // For n/w handles: also update position
                    const handle = this.activeWidget.handle;
                    if (handle.includes('n') || handle.includes('w')) {
                        const s = window.getComputedStyle(widget);
                        this.dotNetRef.invokeMethodAsync('OnWidgetMoved', widgetId, parseInt(s.left) || 0, parseInt(s.top) || 0);
                    }
                } else if (this.mode === 'move') {
```

### 1d. setupModalDragResize — attach drag to whole modal-header
Find:
```javascript
        const dragHandle = document.querySelector('.editor-modal .modal-drag-handle');
        const resizeHandle = document.querySelector('.editor-modal .modal-resize-handle');

        if (dragHandle && !dragHandle._dragSetup) {
            dragHandle._dragSetup = true;
            dragHandle.addEventListener('mousedown', (e) => {
                e.preventDefault();
                this.startModalMove(e);
            });
        }
```
Replace with:
```javascript
        const dragHandle = document.querySelector('.editor-modal .modal-header');
        const resizeHandle = document.querySelector('.editor-modal .modal-resize-handle');

        if (dragHandle && !dragHandle._dragSetup) {
            dragHandle._dragSetup = true;
            dragHandle.addEventListener('mousedown', (e) => {
                // Don't drag if clicking close button or interactive elements
                if (e.target.closest('.btn-close, button, input, select, textarea')) return;
                e.preventDefault();
                this.startModalMove(e);
            });
        }
```

---

## Change 2 — ScreenEditorPage.razor

### 2a. Add 5 new resize handles after existing 3
Find:
```razor
                        <div class="resize-handle resize-e" @onmousedown="e => StartResizeE(widget.Id, e)" @onmousedown:stopPropagation="true"></div>
                        <div class="resize-handle resize-s" @onmousedown="e => StartResizeS(widget.Id, e)" @onmousedown:stopPropagation="true"></div>
                        <div class="resize-handle resize-se" @onmousedown="e => StartResizeSE(widget.Id, e)" @onmousedown:stopPropagation="true"></div>
```
Replace with:
```razor
                        <div class="resize-handle resize-e"  @onmousedown="e => StartResizeE(widget.Id, e)"  @onmousedown:stopPropagation="true"></div>
                        <div class="resize-handle resize-s"  @onmousedown="e => StartResizeS(widget.Id, e)"  @onmousedown:stopPropagation="true"></div>
                        <div class="resize-handle resize-se" @onmousedown="e => StartResizeSE(widget.Id, e)" @onmousedown:stopPropagation="true"></div>
                        <div class="resize-handle resize-n"  @onmousedown="e => StartResizeN(widget.Id, e)"  @onmousedown:stopPropagation="true"></div>
                        <div class="resize-handle resize-w"  @onmousedown="e => StartResizeW(widget.Id, e)"  @onmousedown:stopPropagation="true"></div>
                        <div class="resize-handle resize-nw" @onmousedown="e => StartResizeNW(widget.Id, e)" @onmousedown:stopPropagation="true"></div>
                        <div class="resize-handle resize-ne" @onmousedown="e => StartResizeNE(widget.Id, e)" @onmousedown:stopPropagation="true"></div>
                        <div class="resize-handle resize-sw" @onmousedown="e => StartResizeSW(widget.Id, e)" @onmousedown:stopPropagation="true"></div>
```

### 2b. Add C# helper methods for new handles
Find:
```csharp
    private Task StartResizeE(Guid widgetId, MouseEventArgs e) => StartResize(widgetId, "e", e);
    private Task StartResizeS(Guid widgetId, MouseEventArgs e) => StartResize(widgetId, "s", e);
    private Task StartResizeSE(Guid widgetId, MouseEventArgs e) => StartResize(widgetId, "se", e);
```
Replace with:
```csharp
    private Task StartResizeE(Guid widgetId, MouseEventArgs e)  => StartResize(widgetId, "e",  e);
    private Task StartResizeS(Guid widgetId, MouseEventArgs e)  => StartResize(widgetId, "s",  e);
    private Task StartResizeSE(Guid widgetId, MouseEventArgs e) => StartResize(widgetId, "se", e);
    private Task StartResizeN(Guid widgetId, MouseEventArgs e)  => StartResize(widgetId, "n",  e);
    private Task StartResizeW(Guid widgetId, MouseEventArgs e)  => StartResize(widgetId, "w",  e);
    private Task StartResizeNW(Guid widgetId, MouseEventArgs e) => StartResize(widgetId, "nw", e);
    private Task StartResizeNE(Guid widgetId, MouseEventArgs e) => StartResize(widgetId, "ne", e);
    private Task StartResizeSW(Guid widgetId, MouseEventArgs e) => StartResize(widgetId, "sw", e);
```

### 2c. Modal header — make entire header draggable
Find:
```razor
                <div class="modal-header">
                    <div class="modal-drag-handle" title="@L["Common_DragToMove"]">
                        <i class="bi bi-grip-vertical"></i>
                    </div>
                    <h5 class="modal-title" id="widget-config-title">
                        @L["Widgets_Configure"]: @ConfiguringWidget.Name
                    </h5>
                    <button type="button" class="btn-close" @onclick="CloseWidgetConfig"></button>
                </div>
```
Replace with:
```razor
                <div class="modal-header modal-drag-header">
                    <i class="bi bi-grip-vertical me-2 text-muted" style="font-size: 1rem; flex-shrink: 0;"></i>
                    <h5 class="modal-title" id="widget-config-title">
                        @L["Widgets_Configure"]: @ConfiguringWidget.Name
                    </h5>
                    <button type="button" class="btn-close ms-auto" @onclick="CloseWidgetConfig"></button>
                </div>
```

---

## Change 3 — app.css

### 3a. Add CSS for new resize handles (n, w, nw, ne, sw)
After the existing `.resize-handle.resize-se::after { ... }` block, add:

```css
.resize-handle.resize-n {
    inset-inline-start: 8px;
    inset-block-start: 0;
    width: calc(100% - 16px);
    height: 8px;
    cursor: ns-resize;
}

.resize-handle.resize-w {
    inset-inline-start: 0;
    inset-block-start: 0;
    width: 8px;
    height: 100%;
    cursor: ew-resize;
}

.resize-handle.resize-nw {
    inset-inline-start: 0;
    inset-block-start: 0;
    width: 16px;
    height: 16px;
    cursor: nwse-resize;
}

.resize-handle.resize-ne {
    inset-inline-end: 0;
    inset-block-start: 0;
    width: 16px;
    height: 16px;
    cursor: nesw-resize;
}

.resize-handle.resize-sw {
    inset-inline-start: 0;
    inset-block-end: 0;
    width: 16px;
    height: 16px;
    cursor: nesw-resize;
}
```

### 3b. Update modal-drag-handle CSS — make header draggable
Find:
```css
/* Drag handle in header */
.editor-modal .modal-drag-handle {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    padding: 0;
    margin-inline-end: var(--sp-2);
    background: var(--clr-overlay);
    color: var(--clr-text-muted);
    cursor: move;
    border-radius: var(--r-sm);
    transition: background-color var(--dur-fast), color var(--dur-fast);
    flex-shrink: 0;
}

.editor-modal .modal-drag-handle:hover {
    background: var(--clr-border-md);
    color: var(--clr-text);
}

.editor-modal .modal-drag-handle i {
    font-size: 16px;
}
```
Replace with:
```css
/* Drag handle — entire modal header is draggable */
.editor-modal .modal-header.modal-drag-header {
    cursor: move;
    user-select: none;
}

.editor-modal .modal-header.modal-drag-header:active {
    cursor: grabbing;
}
```

---

## Verification

```bash
# New handles in razor
grep -c "resize-n\|resize-w\|resize-nw\|resize-ne\|resize-sw" \
  src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor

# JS updated
grep -c "includes('n')\|includes('w')" \
  src/CcDashboard.Web/wwwroot/js/widget-resize.js

# Modal header
grep "modal-drag-header" \
  src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor \
  src/CcDashboard.Web/wwwroot/app.css
```

---

## Commit

```bash
bash tools/pre-commit-check.sh \
  src/CcDashboard.Web/wwwroot/js/widget-resize.js \
  src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor \
  src/CcDashboard.Web/wwwroot/app.css
# Only if exit code 0:
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
  src/CcDashboard.Web/wwwroot/js/widget-resize.js \
  src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor \
  src/CcDashboard.Web/wwwroot/app.css \
  tools/cc_prompt_resize_drag_improvements.md
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "feat: resize widgets from all 8 sides; drag configurator modal by full header"
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
for f in src/CcDashboard.Web/wwwroot/js/widget-resize.js \
          src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor \
          src/CcDashboard.Web/wwwroot/app.css \
          tools/cc_prompt_resize_drag_improvements.md; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
