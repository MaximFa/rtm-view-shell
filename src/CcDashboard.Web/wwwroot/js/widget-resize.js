// Widget resize and move functionality
window.widgetResize = {
    activeWidget: null,
    activeModal: null,
    mode: null, // 'resize' or 'move' or 'modal-resize' or 'modal-move'
    startX: 0,
    startY: 0,
    startWidth: 0,
    startHeight: 0,
    startLeft: 0,
    startTop: 0,
    dotNetRef: null,
    alignTargets: null,      // Cached rects of other widgets + canvas for alignment
    guideV: null,            // Vertical guide line element
    guideH: null,            // Horizontal guide line element
    ALIGN_THRESHOLD: 6,      // Snap threshold in pixels
    SNAP_ENABLED: true,      // Enable snap-to-guide
    selectedWidgets: new Set(), // Multi-select: widget IDs currently selected
    
    // Marquee (rubber-band) selection state
    marquee: null,           // { startX, startY, element, widgetRects, shiftKey }
    MARQUEE_THRESHOLD: 5,    // px movement before a mousedown becomes a marquee (vs click)

    init: function (dotNetRef) {
        this.dotNetRef = dotNetRef;
        this._onMouseMove = this.onMouseMove.bind(this);
        this._onMouseUp = this.onMouseUp.bind(this);
        this._onMouseDown = this.onMouseDown.bind(this);
        document.addEventListener('mousemove', this._onMouseMove);
        document.addEventListener('mouseup', this._onMouseUp);
        document.addEventListener('mousedown', this._onMouseDown);

        // Create alignment guide lines (reusable, hidden by default)
        this.guideV = document.createElement('div');
        this.guideV.className = 'widget-align-guide vertical';
        this.guideH = document.createElement('div');
        this.guideH.className = 'widget-align-guide horizontal';

        // Watch for modal appearing and set up drag/resize
        const observer = new MutationObserver(() => {
            this.setupModalDragResize();
        });
        observer.observe(document.body, { childList: true, subtree: true });
    },


    // Handle mousedown for marquee start (real DOM event, not Blazor-routed)
    onMouseDown: function (e) {
        // Ignore if already in a mode (move/resize/modal)
        if (this.activeWidget || this.activeModal || this.marquee) return;
        
        // Find canvas grid
        const canvas = e.target.closest('.dashboard-canvas-grid');
        if (!canvas) return;
        
        // Only start marquee if click is on empty canvas, NOT on a widget
        if (e.target.closest('.dashboard-widget')) return;
        
        // Start marquee with real DOM event
        this.startMarquee(e, canvas);
    },

    // Toggle widget in multi-selection (Ctrl/Cmd-click)
    toggleSelection: function (widgetId, add) {
        if (add) {
            if (this.selectedWidgets.has(widgetId)) {
                this.selectedWidgets.delete(widgetId);
            } else {
                this.selectedWidgets.add(widgetId);
            }
        } else {
            // Normal click - clear set and select only this one
            this.selectedWidgets.clear();
            this.selectedWidgets.add(widgetId);
        }
        this.updateSelectionClasses();
    },

    // Clear all selections (click on empty canvas)
    clearSelection: function () {
        this.selectedWidgets.clear();
        this.updateSelectionClasses();
    },

    // Update .selected class on all widgets
    updateSelectionClasses: function () {
        const canvas = document.querySelector('.dashboard-canvas-grid');
        if (!canvas) return;
        canvas.querySelectorAll('.dashboard-widget').forEach(w => {
            const id = w.dataset.widgetId;
            if (this.selectedWidgets.has(id)) {
                w.classList.add('selected');
            } else {
                w.classList.remove('selected');
            }
        });
    },

    // Check if widget is in selection set
    isSelected: function (widgetId) {
        return this.selectedWidgets.has(widgetId);
    },

    // Get all selected widget IDs
    getSelectedIds: function () {
        return Array.from(this.selectedWidgets);
    },


    // Start marquee selection on empty canvas mousedown (called from real DOM listener)
    startMarquee: function (e, canvasElement) {
        const canvasRect = canvasElement.getBoundingClientRect();
        const startX = e.clientX - canvasRect.left;
        const startY = e.clientY - canvasRect.top;
        
        // Create marquee element (hidden until threshold met)
        const marqueeEl = document.createElement('div');
        marqueeEl.className = 'widget-marquee';
        marqueeEl.style.display = 'none';
        canvasElement.appendChild(marqueeEl);
        
        // Cache widget rects for intersection testing
        const widgetRects = [];
        canvasElement.querySelectorAll('.dashboard-widget').forEach(w => {
            const rect = w.getBoundingClientRect();
            widgetRects.push({
                id: w.dataset.widgetId,
                element: w,
                left: rect.left - canvasRect.left,
                top: rect.top - canvasRect.top,
                right: rect.right - canvasRect.left,
                bottom: rect.bottom - canvasRect.top
            });
        });
        
        this.marquee = {
            startX: startX,
            startY: startY,
            currentX: startX,
            currentY: startY,
            element: marqueeEl,
            canvas: canvasElement,
            canvasRect: canvasRect,
            widgetRects: widgetRects,
            shiftKey: e.shiftKey,
            active: false  // becomes true after threshold
        };
        
        document.body.style.userSelect = 'none';
        return true;
    },
    
    // Update marquee during drag
    updateMarquee: function (e) {
        if (!this.marquee) return;
        
        const canvasRect = this.marquee.canvasRect;
        this.marquee.currentX = e.clientX - canvasRect.left;
        this.marquee.currentY = e.clientY - canvasRect.top;
        
        const dx = Math.abs(this.marquee.currentX - this.marquee.startX);
        const dy = Math.abs(this.marquee.currentY - this.marquee.startY);
        
        // Activate after threshold
        if (!this.marquee.active && (dx > this.MARQUEE_THRESHOLD || dy > this.MARQUEE_THRESHOLD)) {
            this.marquee.active = true;
            this.marquee.element.style.display = 'block';
        }
        
        if (!this.marquee.active) return;
        
        // Calculate rect (handle all drag directions)
        const left = Math.min(this.marquee.startX, this.marquee.currentX);
        const top = Math.min(this.marquee.startY, this.marquee.currentY);
        const width = Math.abs(this.marquee.currentX - this.marquee.startX);
        const height = Math.abs(this.marquee.currentY - this.marquee.startY);
        
        // Position the marquee element
        this.marquee.element.style.left = left + 'px';
        this.marquee.element.style.top = top + 'px';
        this.marquee.element.style.width = width + 'px';
        this.marquee.element.style.height = height + 'px';
        
        // Find intersecting widgets and mark as candidates
        const marqueeRect = { left, top, right: left + width, bottom: top + height };
        this.marquee.widgetRects.forEach(wr => {
            const intersects = !(wr.right < marqueeRect.left || wr.left > marqueeRect.right ||
                                 wr.bottom < marqueeRect.top || wr.top > marqueeRect.bottom);
            if (intersects) {
                wr.element.classList.add('marquee-candidate');
            } else {
                wr.element.classList.remove('marquee-candidate');
            }
        });
    },
    
    // Finalize marquee selection
    finalizeMarquee: function () {
        if (!this.marquee) return null;
        
        const wasActive = this.marquee.active;
        const shiftKey = this.marquee.shiftKey;
        
        // Calculate final rect
        const left = Math.min(this.marquee.startX, this.marquee.currentX);
        const top = Math.min(this.marquee.startY, this.marquee.currentY);
        const width = Math.abs(this.marquee.currentX - this.marquee.startX);
        const height = Math.abs(this.marquee.currentY - this.marquee.startY);
        const marqueeRect = { left, top, right: left + width, bottom: top + height };
        
        // Collect selected widget IDs
        const selectedIds = [];
        this.marquee.widgetRects.forEach(wr => {
            wr.element.classList.remove('marquee-candidate');
            if (wasActive) {
                const intersects = !(wr.right < marqueeRect.left || wr.left > marqueeRect.right ||
                                     wr.bottom < marqueeRect.top || wr.top > marqueeRect.bottom);
                if (intersects) {
                    selectedIds.push(wr.id);
                }
            }
        });
        
        // Remove marquee element
        if (this.marquee.element && this.marquee.element.parentNode) {
            this.marquee.element.parentNode.removeChild(this.marquee.element);
        }
        
        // Update selection
        if (wasActive && selectedIds.length > 0) {
            if (shiftKey) {
                // Add to existing selection
                selectedIds.forEach(id => this.selectedWidgets.add(id));
            } else {
                // Replace selection
                this.selectedWidgets.clear();
                selectedIds.forEach(id => this.selectedWidgets.add(id));
            }
            this.updateSelectionClasses();
        } else if (wasActive && selectedIds.length === 0 && !shiftKey) {
            // Marquee dragged but nothing selected -> clear
            this.selectedWidgets.clear();
            this.updateSelectionClasses();
        }
        // If not active (was just a click, not a drag) -> handled by clearSelection in onclick
        
        document.body.style.userSelect = '';
        const result = wasActive ? Array.from(this.selectedWidgets) : null;
        this.marquee = null;
        return result;
    },

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

        widget.classList.add('resizing');
        document.body.style.cursor = this.getCursor(handle);
        document.body.style.userSelect = 'none';
    },

    startMove: function (widgetId, coords) {
        const widget = document.querySelector(`[data-widget-id="${widgetId}"]`);
        if (!widget) return;

        // Get current position from style or computed style
        const style = window.getComputedStyle(widget);
        const left = parseInt(style.left) || 0;
        const top = parseInt(style.top) || 0;

        this.activeWidget = { id: widgetId, element: widget };
        this.mode = 'move';
        this.startX = coords.clientX;
        this.startY = coords.clientY;
        this.startLeft = left;
        this.startTop = top;

        // If dragged widget is in selection set (multi-select), capture all selected positions
        this.groupMove = null;
        if (this.selectedWidgets.has(widgetId) && this.selectedWidgets.size > 1) {
            this.groupMove = [];
            this.selectedWidgets.forEach(id => {
                const w = document.querySelector(`[data-widget-id="${id}"]`);
                if (w) {
                    const s = window.getComputedStyle(w);
                    this.groupMove.push({
                        id: id,
                        element: w,
                        startLeft: parseInt(s.left) || 0,
                        startTop: parseInt(s.top) || 0
                    });
                    w.classList.add('moving');
                }
            });
        } else {
            widget.classList.add('moving');
        }
        document.body.style.cursor = 'move';
        document.body.style.userSelect = 'none';

        // Cache alignment targets (other widgets + canvas edges/centre)
        this.cacheAlignTargets(widget);
    },

    // Cache rects of other widgets and canvas for alignment checks
    cacheAlignTargets: function (draggedWidget) {
        const canvas = document.querySelector('.dashboard-canvas-grid');
        if (!canvas) { this.alignTargets = null; return; }

        const canvasRect = canvas.getBoundingClientRect();
        const targets = [];

        // Canvas edges and centre
        targets.push({
            type: 'canvas',
            left: 0,
            centreX: canvasRect.width / 2,
            right: canvasRect.width,
            top: 0,
            centreY: canvasRect.height / 2,
            bottom: canvasRect.height
        });

        // Other widgets
        canvas.querySelectorAll('.dashboard-widget').forEach(w => {
            if (w === draggedWidget) return;
            const r = w.getBoundingClientRect();
            const cRect = canvas.getBoundingClientRect();
            targets.push({
                type: 'widget',
                left: r.left - cRect.left,
                centreX: r.left - cRect.left + r.width / 2,
                right: r.right - cRect.left,
                top: r.top - cRect.top,
                centreY: r.top - cRect.top + r.height / 2,
                bottom: r.bottom - cRect.top
            });
        });

        this.alignTargets = targets;

        // Append guides to canvas if not already
        if (!this.guideV.parentNode) canvas.appendChild(this.guideV);
        if (!this.guideH.parentNode) canvas.appendChild(this.guideH);
    },

    // Setup modal drag/resize - called via MutationObserver
    setupModalDragResize: function () {
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

        if (resizeHandle && !resizeHandle._resizeSetup) {
            resizeHandle._resizeSetup = true;
            resizeHandle.addEventListener('mousedown', (e) => {
                e.preventDefault();
                this.startModalResize(e);
            });
        }
    },

    // Modal drag start
    startModalMove: function (e) {
        const modal = document.querySelector('.editor-modal .modal-dialog');
        if (!modal) return;

        const rect = modal.getBoundingClientRect();

        // Switch to fixed positioning at current visual position
        modal.classList.add('modal-dragging');
        modal.style.left = rect.left + 'px';
        modal.style.top = rect.top + 'px';
        modal.style.width = rect.width + 'px';

        this.activeModal = { element: modal };
        this.mode = 'modal-move';
        this.startX = e.clientX;
        this.startY = e.clientY;
        this.startLeft = rect.left;
        this.startTop = rect.top;

        document.body.style.cursor = 'move';
        document.body.style.userSelect = 'none';
    },

    // Modal resize start (width only - height is auto based on content)
    startModalResize: function (e) {
        const modal = document.querySelector('.editor-modal .modal-dialog');
        if (!modal) return;

        const rect = modal.getBoundingClientRect();

        // Switch to fixed positioning at current visual position
        modal.classList.add('modal-dragging');
        modal.style.left = rect.left + 'px';
        modal.style.top = rect.top + 'px';
        modal.style.width = rect.width + 'px';
        // Don't set height - let it be auto based on content

        this.activeModal = { element: modal, handle: 'e' }; // Width only
        this.mode = 'modal-resize';
        this.startX = e.clientX;
        this.startY = e.clientY;
        this.startWidth = rect.width;
        this.startLeft = rect.left;

        document.body.style.cursor = 'ew-resize';
        document.body.style.userSelect = 'none';
    },

    onMouseMove: function (event) {
        // Handle marquee selection
        if (this.marquee) {
            this.updateMarquee(event);
            return;
        }
        
        // Handle modal operations
        if (this.activeModal) {
            const deltaX = event.clientX - this.startX;
            const deltaY = event.clientY - this.startY;
            const modal = this.activeModal.element;

            if (this.mode === 'modal-move') {
                let newLeft = this.startLeft + deltaX;
                let newTop = this.startTop + deltaY;

                // Constrain to viewport
                const maxLeft = window.innerWidth - modal.offsetWidth - 20;
                const maxTop = window.innerHeight - modal.offsetHeight - 20;
                newLeft = Math.max(20, Math.min(newLeft, maxLeft));
                newTop = Math.max(20, Math.min(newTop, maxTop));

                modal.style.left = newLeft + 'px';
                modal.style.top = newTop + 'px';
            } else if (this.mode === 'modal-resize') {
                // Width only - height is auto based on content
                let newWidth = Math.max(450, this.startWidth + deltaX);
                newWidth = Math.min(newWidth, window.innerWidth - 40);
                modal.style.width = newWidth + 'px';
            }
            return;
        }

        if (!this.activeWidget) return;

        const deltaX = event.clientX - this.startX;
        const deltaY = event.clientY - this.startY;
        const widget = this.activeWidget.element;

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
        } else if (this.mode === 'move') {
            let newLeft = this.startLeft + deltaX;
            let newTop = this.startTop + deltaY;

            // Snap to grid (10px)
            newLeft = Math.round(newLeft / 10) * 10;
            newTop = Math.round(newTop / 10) * 10;

            // Constrain to canvas
            newLeft = Math.max(0, newLeft);
            newTop = Math.max(0, newTop);

            // Check alignment and show guides (for primary widget)
            const alignResult = this.checkAlignment(widget, newLeft, newTop);
            if (alignResult.snapLeft !== null && this.SNAP_ENABLED) newLeft = alignResult.snapLeft;
            if (alignResult.snapTop !== null && this.SNAP_ENABLED) newTop = alignResult.snapTop;

            widget.style.left = newLeft + 'px';
            widget.style.top = newTop + 'px';

            // Group move: apply same delta to all selected widgets
            if (this.groupMove && this.groupMove.length > 1) {
                const actualDeltaX = newLeft - this.startLeft;
                const actualDeltaY = newTop - this.startTop;
                this.groupMove.forEach(g => {
                    if (g.id !== this.activeWidget.id) {
                        let gLeft = g.startLeft + actualDeltaX;
                        let gTop = g.startTop + actualDeltaY;
                        gLeft = Math.max(0, gLeft);
                        gTop = Math.max(0, gTop);
                        g.element.style.left = gLeft + 'px';
                        g.element.style.top = gTop + 'px';
                    }
                });
            }
        }
    },

    onMouseUp: function (event) {
        // Handle marquee selection finalize
        if (this.marquee) {
            const selectedIds = this.finalizeMarquee();
            // Notify Blazor to sync SelectedWidgetIds
            if (selectedIds !== null && this.dotNetRef) {
                this.dotNetRef.invokeMethodAsync('OnMarqueeSelect', selectedIds);
            }
            return;
        }
        
        // Handle modal operations - keep modal-dragging class to maintain position
        if (this.activeModal) {
            document.body.style.cursor = '';
            document.body.style.userSelect = '';
            this.activeModal = null;
            this.mode = null;
            return;
        }

        if (!this.activeWidget) return;

        const widget = this.activeWidget.element;
        const widgetId = this.activeWidget.id;

        widget.classList.remove('resizing', 'moving');
        document.body.style.cursor = '';
        document.body.style.userSelect = '';

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
                // Group move: batch commit all moved widgets
                if (this.groupMove && this.groupMove.length > 1) {
                    const movedWidgets = this.groupMove.map(g => {
                        const s = window.getComputedStyle(g.element);
                        g.element.classList.remove('moving');
                        return { id: g.id, left: parseInt(s.left) || 0, top: parseInt(s.top) || 0 };
                    });
                    this.dotNetRef.invokeMethodAsync('OnWidgetsMoved', movedWidgets);
                } else {
                    const style = window.getComputedStyle(widget);
                    const left = parseInt(style.left) || 0;
                    const top = parseInt(style.top) || 0;
                    this.dotNetRef.invokeMethodAsync('OnWidgetMoved', widgetId, left, top);
                }
            }
        }

        this.hideGuides();
        this.activeWidget = null;
        this.groupMove = null;
        this.mode = null;
    },

    // Check alignment with other widgets/canvas and show guides
    checkAlignment: function (widget, newLeft, newTop) {
        const result = { snapLeft: null, snapTop: null };
        if (!this.alignTargets) return result;

        const w = widget.offsetWidth;
        const h = widget.offsetHeight;
        const draggedLeft = newLeft;
        const draggedCentreX = newLeft + w / 2;
        const draggedRight = newLeft + w;
        const draggedTop = newTop;
        const draggedCentreY = newTop + h / 2;
        const draggedBottom = newTop + h;

        let bestV = null, bestVDist = this.ALIGN_THRESHOLD + 1;
        let bestH = null, bestHDist = this.ALIGN_THRESHOLD + 1;

        for (const t of this.alignTargets) {
            // Vertical alignment (X axis): left-left, centre-centre, right-right, left-right, right-left
            const vChecks = [
                { dragged: draggedLeft, target: t.left, snap: t.left },
                { dragged: draggedLeft, target: t.centreX, snap: t.centreX },
                { dragged: draggedLeft, target: t.right, snap: t.right },
                { dragged: draggedCentreX, target: t.left, snap: t.left - w / 2 },
                { dragged: draggedCentreX, target: t.centreX, snap: t.centreX - w / 2 },
                { dragged: draggedCentreX, target: t.right, snap: t.right - w / 2 },
                { dragged: draggedRight, target: t.left, snap: t.left - w },
                { dragged: draggedRight, target: t.centreX, snap: t.centreX - w },
                { dragged: draggedRight, target: t.right, snap: t.right - w }
            ];
            for (const c of vChecks) {
                const dist = Math.abs(c.dragged - c.target);
                if (dist <= this.ALIGN_THRESHOLD && dist < bestVDist) {
                    bestVDist = dist;
                    bestV = { x: c.target, snap: c.snap };
                }
            }

            // Horizontal alignment (Y axis)
            const hChecks = [
                { dragged: draggedTop, target: t.top, snap: t.top },
                { dragged: draggedTop, target: t.centreY, snap: t.centreY },
                { dragged: draggedTop, target: t.bottom, snap: t.bottom },
                { dragged: draggedCentreY, target: t.top, snap: t.top - h / 2 },
                { dragged: draggedCentreY, target: t.centreY, snap: t.centreY - h / 2 },
                { dragged: draggedCentreY, target: t.bottom, snap: t.bottom - h / 2 },
                { dragged: draggedBottom, target: t.top, snap: t.top - h },
                { dragged: draggedBottom, target: t.centreY, snap: t.centreY - h },
                { dragged: draggedBottom, target: t.bottom, snap: t.bottom - h }
            ];
            for (const c of hChecks) {
                const dist = Math.abs(c.dragged - c.target);
                if (dist <= this.ALIGN_THRESHOLD && dist < bestHDist) {
                    bestHDist = dist;
                    bestH = { y: c.target, snap: c.snap };
                }
            }
        }

        // Show/hide guides
        if (bestV) {
            this.guideV.style.left = bestV.x + 'px';
            this.guideV.classList.add('visible');
            result.snapLeft = bestV.snap;
        } else {
            this.guideV.classList.remove('visible');
        }

        if (bestH) {
            this.guideH.style.top = bestH.y + 'px';
            this.guideH.classList.add('visible');
            result.snapTop = bestH.snap;
        } else {
            this.guideH.classList.remove('visible');
        }

        return result;
    },

    // Hide alignment guides
    hideGuides: function () {
        if (this.guideV) this.guideV.classList.remove('visible');
        if (this.guideH) this.guideH.classList.remove('visible');
    },

    getCursor: function (handle) {
        const cursors = {
            'e': 'ew-resize',
            'w': 'ew-resize',
            's': 'ns-resize',
            'n': 'ns-resize',
            'se': 'nwse-resize',
            'nw': 'nwse-resize',
            'sw': 'nesw-resize',
            'ne': 'nesw-resize'
        };
        return cursors[handle] || 'default';
    },

    dispose: function () {
        if (this._onMouseMove) document.removeEventListener('mousemove', this._onMouseMove);
        if (this._onMouseUp) document.removeEventListener('mouseup', this._onMouseUp);
        // Remove guide elements
        if (this.guideV && this.guideV.parentNode) this.guideV.parentNode.removeChild(this.guideV);
        if (this.guideH && this.guideH.parentNode) this.guideH.parentNode.removeChild(this.guideH);
        this.dotNetRef = null;
        this.activeWidget = null;
        this.alignTargets = null;
    },

    getDropPosition: function (clientX, clientY) {
        const canvas = document.querySelector('.dashboard-canvas-grid');
        if (!canvas) return { x: 0, y: 0 };

        const rect = canvas.getBoundingClientRect();
        let x = clientX - rect.left;
        let y = clientY - rect.top;

        // Snap to 10px grid
        x = Math.round(x / 10) * 10;
        y = Math.round(y / 10) * 10;

        // Ensure non-negative
        x = Math.max(0, x);
        y = Math.max(0, y);

        return { x: x, y: y };
    },

    applyWidgetPosition: function (widgetId, x, y, width, height) {
        const widget = document.querySelector(`[data-widget-id="${widgetId}"]`);
        if (!widget) return;

        widget.style.position = 'absolute';
        widget.style.left = x + 'px';
        widget.style.top = y + 'px';
        widget.style.width = width + 'px';
        widget.style.height = height + 'px';
    },

    applyAllWidgetPositions: function (widgets) {
        if (!widgets || !widgets.length) return;

        widgets.forEach(w => {
            this.applyWidgetPosition(w.id, w.x, w.y, w.width, w.height);
        });
    }
};
