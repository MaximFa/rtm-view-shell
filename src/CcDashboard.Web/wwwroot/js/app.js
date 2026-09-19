// App-wide JavaScript interop functions

window.setupModalEscape = function (modalElement, dotNetRef) {
    if (!modalElement) return;

    const handler = function (e) {
        if (e.key === 'Escape') {
            e.preventDefault();
            dotNetRef.invokeMethodAsync('HandleEscapeKey');
        }
    };

    modalElement._escapeHandler = handler;
    document.addEventListener('keydown', handler);

    // Focus first focusable element in modal
    const focusable = modalElement.querySelectorAll(
        'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    if (focusable.length > 0) {
        focusable[0].focus();
    }
};

window.cleanupModalEscape = function (modalElement) {
    if (modalElement && modalElement._escapeHandler) {
        document.removeEventListener('keydown', modalElement._escapeHandler);
        delete modalElement._escapeHandler;
    }
};

window.focusElement = function (element) {
    if (element) {
        element.focus();
    }
};

window.getElementPosition = function (element) {
    if (!element) return null;
    const rect = element.getBoundingClientRect();
    return {
        top: rect.top,
        left: rect.left,
        bottom: rect.bottom,
        right: rect.right,
        width: rect.width,
        height: rect.height
    };
};

// localStorage security — clear all cc: prefixed keys on logout (CLAUDE.md §41)
window.ccApp = window.ccApp || {};

window.ccApp.clearLocalStorage = function () {
    const keys = Object.keys(localStorage).filter(k => k.startsWith('cc:'));
    keys.forEach(k => localStorage.removeItem(k));
    console.debug(`ccApp.clearLocalStorage: removed ${keys.length} key(s)`);
};
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

window.ccApp.downloadFile = function (base64, fileName, contentType) {
    var bin = atob(base64);
    var len = bin.length;
    var bytes = new Uint8Array(len);
    for (var i = 0; i < len; i++) {
        bytes[i] = bin.charCodeAt(i);
    }
    var blob = new Blob([bytes], { type: contentType });
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = fileName;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
};

// Filter popup edge fit (PR234-FILTER-POPUP-EDGE-01, path (a)).
// Measures the open popup on render and shifts it back inside the grid using the LOGICAL
// margin-inline-start. No physical left/right is ever assigned.
window.ccPopupFit = {
    fit: function () {
        var pop = document.querySelector('.filter-dropdown');
        if (!pop) return 0;
        // Always re-measure from a clean state: a stale margin would be measured as if it were layout.
        pop.style.marginInlineStart = '';
        var box = pop.parentElement;
        while (box && box !== document.body) {
            var ox = getComputedStyle(box).overflowX;
            if (ox === 'auto' || ox === 'scroll') break;
            box = box.parentElement;
        }
        if (!box || box === document.body) return 0;
        var br = box.getBoundingClientRect();
        var vw = document.documentElement.clientWidth;
        var refL = Math.max(br.left, 0);
        var refR = Math.min(br.right, vw);
        var pr = pop.getBoundingClientRect();
        // dx is PHYSICAL: positive means "move right".
        var dx = 0;
        if (pr.left < refL) dx = refL - pr.left;
        else if (pr.right > refR) dx = refR - pr.right;
        if (dx === 0) return 0;
        // Convert the physical delta into the logical axis. This single direction read is a UNIT
        // CONVERSION, not CSS branching by direction: the property written stays logical.
        var rtl = getComputedStyle(pop).direction === 'rtl';
        pop.style.marginInlineStart = (rtl ? -dx : dx) + 'px';
        return dx;
    }
};
