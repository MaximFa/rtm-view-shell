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
