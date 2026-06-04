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

    init: function (dotNetRef) {
        this.dotNetRef = dotNetRef;
        this._onMouseMove = this.onMouseMove.bind(this);
        this._onMouseUp = this.onMouseUp.bind(this);
        document.addEventListener('mousemove', this._onMouseMove);
        document.addEventListener('mouseup', this._onMouseUp);

        // Watch for modal appearing and set up drag/resize
        const observer = new MutationObserver(() => {
            this.setupModalDragResize();
        });
        observer.observe(document.body, { childList: true, subtree: true });
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

        widget.classList.add('moving');
        document.body.style.cursor = 'move';
        document.body.style.userSelect = 'none';
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

            widget.style.left = newLeft + 'px';
            widget.style.top = newTop + 'px';
        }
    },

    onMouseUp: function (event) {
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
                const style = window.getComputedStyle(widget);
                const left = parseInt(style.left) || 0;
                const top = parseInt(style.top) || 0;
                this.dotNetRef.invokeMethodAsync('OnWidgetMoved', widgetId, left, top);
            }
        }

        this.activeWidget = null;
        this.mode = null;
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
        this.dotNetRef = null;
        this.activeWidget = null;
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
