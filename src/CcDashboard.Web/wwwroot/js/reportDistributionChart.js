// Report Distribution Chart — Chart.js interop for Blazor report widgets
window.reportDistributionChart = {
    _charts: {},
    _observers: {},       // ResizeObservers per elementId
    _pendingRenders: {},  // Track pending retry timers by elementId
    _lastRenderArgs: {},  // Store last render args for rebuild

    // Compute canvas density: max(2, dpr) * max(1, s), ceiling 4
    _getDensity: function () {
        const dpr = window.devicePixelRatio || 1;
        let s = 1;
        if (window.viewerScale && window.viewerScale.designEl) {
            const transform = window.viewerScale.designEl.style.transform;
            const match = transform && transform.match(/scale\(([\d.]+)\)/);
            if (match) s = parseFloat(match[1]) || 1;
        }
        const raw = Math.max(2, dpr) * Math.max(1, s);
        return Math.min(raw, 4);
    },


    // Size the canvas from its container's LAYOUT box (clientWidth/clientHeight), never
    // from getBoundingClientRect. The viewer shrinks the whole design layer with
    // transform: scale(s), and a rect already has s applied, so Chart.js's own
    // responsive sizing (which reads the rect) made the canvas s times too small in
    // design coordinates and the layer then shrank it a SECOND time. Measured
    // 2026-10-11 in the viewer: canvas.client / container.client = 0.6347 against a
    // layer scale of 0.6342, identically in DayTrend and ASD; chart.resize() did not
    // help, because the source of the measurement was wrong, not the notification.
    // That is why responsive is false here and this function owns the size.
    // IDENTICAL helper in the other chart modules — keep them in sync.
    _applyCanvasSize: function (elementId, canvas) {
        const container = canvas && canvas.parentElement;
        if (!container) return false;
        const w = container.clientWidth;
        const h = container.clientHeight;
        if (w <= 0 || h <= 0) return false;   // not laid out yet — leave as is
        canvas.style.width = w + 'px';
        canvas.style.height = h + 'px';
        const chart = this._charts[elementId];
        if (chart) chart.resize(w, h);        // sets the backing store via devicePixelRatio
        return true;
    },

    // Drop the inline size this module wrote, so a later owner of the canvas starts clean
    _clearCanvasSize: function (canvas) {
        if (!canvas) return;
        canvas.style.width = '';
        canvas.style.height = '';
    },

    // Read page font from --font-family token
    _getPageFont: function () {
        return getComputedStyle(document.documentElement).getPropertyValue('--font-family').trim() || undefined;
    },

    // Wait for canvas element to appear, then call callback. Timeout after ~10s.
    _waitForCanvas: function (elementId, callback, startTime) {
        if (!startTime) startTime = Date.now();
        const elapsed = Date.now() - startTime;
        // Timeout after 10 seconds — the widget was probably removed
        if (elapsed > 10000) {
            console.warn('reportDistributionChart: timeout waiting for canvas:', elementId);
            delete this._pendingRenders[elementId];
            return;
        }
        const canvas = document.getElementById(elementId);
        if (canvas) {
            delete this._pendingRenders[elementId];
            callback(canvas);
        } else {
            // Schedule retry on next animation frame
            this._pendingRenders[elementId] = requestAnimationFrame(() => {
                this._waitForCanvas(elementId, callback, startTime);
            });
        }
    },

    // Cancel any pending render for this element
    _cancelPending: function (elementId) {
        if (this._pendingRenders[elementId]) {
            cancelAnimationFrame(this._pendingRenders[elementId]);
            delete this._pendingRenders[elementId];
        }
    },

render: function (elementId, segments, options) {
        if (typeof Chart === 'undefined') {
            console.error('reportDistributionChart: Chart.js is not loaded.');
            return;
        }

        if (this._charts[elementId]) {
            this._charts[elementId].destroy();
        }

        // Cancel any pending retry for this element
        this._cancelPending(elementId);

        // Store render args for rebuild on scale change
        this._lastRenderArgs[elementId] = { segments, options };

        const canvas = document.getElementById(elementId);
        if (!canvas) {
            // Canvas not in DOM yet — wait and retry
            this._waitForCanvas(elementId, (c) => {
                this._doRender(elementId, c, segments, options);
            });
            return;
        }

        this._doRender(elementId, canvas, segments, options);
    },

    // Internal render implementation (canvas guaranteed to exist)
    _doRender: function (elementId, canvas, segments, options) {
        const ctx = canvas.getContext('2d');
        if (!ctx) return;

        const labels = segments.map(s => s.label);
        const data = segments.map(s => s.value);
        const colors = segments.map(s => s.color);
        const total = data.reduce((a, b) => a + b, 0);

        const showPercentages = options?.valueDisplay === 'percentages';
        let chartType = options?.chartType || 'bar';
        let indexAxis = undefined;

        if (chartType === 'horizontalbar') {
            chartType = 'bar';
            indexAxis = 'y';
        }

        const tickColor = options?.fontColor || undefined;

        const chartOptions = {
            responsive: false,   // size owned by _applyCanvasSize (see its comment)
            maintainAspectRatio: false,
            devicePixelRatio: this._getDensity(),
            indexAxis: indexAxis,
            plugins: {
                legend: {
                    display: options?.showLegend ?? false,
                    position: 'bottom',
                    labels: {
                        color: tickColor
                    }
                },
                tooltip: {
                    enabled: true,
                    callbacks: {
                        label: function (context) {
                            const rawValue = chartType === 'bar'
                                ? (indexAxis === 'y' ? context.parsed.x : context.parsed.y)
                                : context.parsed;
                            const pct = total > 0 ? Math.round((rawValue / total) * 100) : 0;
                            return showPercentages
                                ? `${context.label}: ${pct}% (${rawValue})`
                                : `${context.label}: ${rawValue} (${pct}%)`;
                        }
                    }
                }
            },
            scales: {
                x: {
                    grid: { display: false },
                    ticks: { color: tickColor, font: { family: this._getPageFont() } }
                },
                y: {
                    beginAtZero: true,
                    grid: { color: 'rgba(128,128,128,0.2)' },
                    ticks: { color: tickColor, font: { family: this._getPageFont() } }
                }
            }
        };

        if (indexAxis === 'y') {
            chartOptions.scales = {
                y: {
                    grid: { display: false },
                    ticks: { color: tickColor, font: { family: this._getPageFont() } }
                },
                x: {
                    beginAtZero: true,
                    grid: { color: 'rgba(128,128,128,0.2)' },
                    ticks: { color: tickColor, font: { family: this._getPageFont() } }
                }
            };
        }

        const chartData = {
            labels: labels,
            datasets: [{
                label: '',
                data: data,
                backgroundColor: colors,
                borderColor: colors.map(c => c),
                borderWidth: 1
            }]
        };

        this._charts[elementId] = new Chart(ctx, {
            type: chartType,
            data: chartData,
            options: chartOptions
        });

        // responsive is false — apply the real container size now, then follow the container
        this._applyCanvasSize(elementId, canvas);
        this._observeContainer(elementId, canvas);
    },

    // Follow the container's layout size (this module had no observer before)
    _observeContainer: function (elementId, canvas) {
        if (this._observers[elementId]) {
            this._observers[elementId].disconnect();
            delete this._observers[elementId];
        }
        const container = canvas.parentElement;
        if (!container) return;
        let resizeTimeout = null;
        const observer = new ResizeObserver(() => {
            if (resizeTimeout) clearTimeout(resizeTimeout);
            resizeTimeout = setTimeout(() => {
                if (this._charts[elementId] && document.body.contains(canvas)) {
                    this._applyCanvasSize(elementId, canvas);
                }
            }, 50);
        });
        observer.observe(container);
        this._observers[elementId] = observer;
    },

    // Rebuild all charts (called on scale change)
    rebuildAll: function () {
        Object.keys(this._charts).forEach(elementId => {
            const chart = this._charts[elementId];
            if (!chart) return;
            const canvas = document.getElementById(elementId);
            if (!canvas || !document.body.contains(canvas)) return;
            const args = this._lastRenderArgs[elementId];
            if (!args) return;
            // Destroy and rebuild with stored args
            chart.destroy();
            delete this._charts[elementId];
            // Drop our inline size: the rebuild measures the container itself
            this._clearCanvasSize(canvas);
            this.render(elementId, args.segments, args.options);
        });
    },

    update: function (elementId, segments, options) {
        const chart = this._charts[elementId];
        if (!chart) {
            this.render(elementId, segments, options);
            return;
        }

        const labels = segments.map(s => s.label);
        const data = segments.map(s => s.value);
        const colors = segments.map(s => s.color);

        chart.data.labels = labels;
        chart.data.datasets[0].data = data;
        chart.data.datasets[0].backgroundColor = colors;
        chart.data.datasets[0].borderColor = colors;
        chart.update('none');
    },

    destroy: function (elementId) {
        this._cancelPending(elementId);
        delete this._lastRenderArgs[elementId];
        if (this._charts[elementId]) {
            this._charts[elementId].destroy();
            delete this._charts[elementId];
        }
        // Reset the inline size this module wrote on the canvas
        this._clearCanvasSize(document.getElementById(elementId));
    }
};
