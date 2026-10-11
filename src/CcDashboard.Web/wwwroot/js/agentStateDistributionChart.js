// Agent State Distribution Chart — Chart.js interop for Blazor
// UNIT14: legends and centre number moved to markup; centerTextPlugin removed
window.agentStateDistributionChart = {
    _charts: {},
    _pendingRenders: {},  // Track pending retry timers by elementId
    _observers: {},       // ResizeObservers per elementId

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

    // Read page font from --font-family token
    _getPageFont: function () {
        return getComputedStyle(document.documentElement).getPropertyValue('--font-family').trim() || undefined;
    },

// Compute relative luminance (WCAG formula) and return appropriate text color
    _getContrastColor: function (hexColor) {
        if (!hexColor || hexColor.length < 4) return '#fff';
        let hex = hexColor.replace('#', '');
        if (hex.length === 3) {
            hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
        }
        const r = parseInt(hex.substring(0, 2), 16);
        const g = parseInt(hex.substring(2, 4), 16);
        const b = parseInt(hex.substring(4, 6), 16);
        // Relative luminance: 0.299*R + 0.587*G + 0.114*B
        const luminance = 0.299 * r + 0.587 * g + 0.114 * b;
        // Threshold 140: slightly above 128 for better readability
        return luminance > 140 ? '#333' : '#fff';
    },

    // Wait for canvas element to appear, then call callback. Timeout after ~10s.
    _waitForCanvas: function (elementId, callback, startTime) {
        if (!startTime) startTime = Date.now();
        const elapsed = Date.now() - startTime;
        // Timeout after 10 seconds — the widget was probably removed
        if (elapsed > 10000) {
            console.warn('agentStateDistributionChart: timeout waiting for canvas:', elementId);
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
            console.error('agentStateDistributionChart: Chart.js is not loaded.');
            return;
        }

        if (this._charts[elementId]) {
            this._charts[elementId].destroy();
            delete this._charts[elementId];
        }

        // Cancel any pending retry for this element
        this._cancelPending(elementId);

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
        // Lock canvas to current container size before creating chart to prevent geometry jump
        const container = canvas.parentElement;
        if (container) {
            const rect = container.getBoundingClientRect();
            canvas.style.width = rect.width + 'px';
            canvas.style.height = rect.height + 'px';
        }

        const ctx = canvas.getContext('2d');
        if (!ctx) return;

        const labels = segments.map(s => s.label);
        const data = segments.map(s => s.value);
        const colors = segments.map(s => s.color);
        const total = data.reduce((a, b) => a + b, 0);
        const self = this;

        const showPercentages = options?.valueDisplay === 'percentages';

        let chartType = options?.chartType || 'doughnut';
        let indexAxis = undefined;

        if (chartType === 'horizontalbar') {
            chartType = 'bar';
            indexAxis = 'y';
        }

        const isDoughnut = chartType === 'doughnut';
        const fontColor = options?.fontColor || '#333';

        // Create customData BEFORE chart construction so plugins can access it during first draw
        const customData = {
            total: total,
            fontColor: fontColor,
            isDoughnut: isDoughnut,
            showPercentages: showPercentages,
            showValueLabels: options?.showValueLabels ?? true
        };

        const chartOptions = {
            responsive: true,
            maintainAspectRatio: false,
            animation: false,
            devicePixelRatio: this._getDensity(),
            indexAxis: indexAxis,
            // Store customData in options so it's available during chart construction
            _customData: customData,
            plugins: {
                // Legend always hidden — we use markup legend
                legend: { display: false },
                tooltip: {
                    enabled: true,
                    callbacks: {
                        label: function (context) {
                            const chart = context.chart;
                            // Read from chart.options._customData
                            const cd = chart.options._customData || {};
                            const currentTotal = cd.total ?? 0;
                            const rawValue = chartType === 'bar'
                                ? (indexAxis === 'y' ? context.parsed.x : context.parsed.y)
                                : context.parsed;
                            const pct = currentTotal > 0 ? Math.round((rawValue / currentTotal) * 100) : 0;
                            const showPct = cd.showPercentages ?? false;
                            return showPct
                                ? `${context.label}: ${pct}% (${rawValue})`
                                : `${context.label}: ${rawValue} (${pct}%)`;
                        }
                    }
                }
            }
        };

        // Configure data labels on segments with adaptive color
        if (options?.showValueLabels) {
            chartOptions.plugins.datalabels = {
                color: function (ctx) {
                    const bgColors = ctx.dataset.backgroundColor;
                    const segmentColor = Array.isArray(bgColors) ? bgColors[ctx.dataIndex] : bgColors;
                    return self._getContrastColor(segmentColor);
                },
                font: { weight: 'bold', size: 12 },
                formatter: function (value, ctx) {
                    if (value === 0) return '';
                    // Read from chart.options._customData (current state, not closure)
                    const cd = ctx.chart.options._customData || {};
                    const currentTotal = cd.total ?? 0;
                    const showPct = cd.showPercentages ?? false;
                    if (showPct && currentTotal > 0) {
                        const pct = Math.round((value / currentTotal) * 100);
                        return pct + '%';
                    }
                    return value;
                },
                display: function (ctx) {
                    return ctx.dataset.data[ctx.dataIndex] > 0;
                }
            };
        }

        // Bar chart specific options
        if (chartType === 'bar') {
            const tickColor = fontColor;
            // Vertical bar: X = category, Y = value
            chartOptions.scales = {
                x: {
                    grid: { display: false },
                    ticks: { color: tickColor, font: { family: this._getPageFont() } }
                },
                y: {
                    beginAtZero: true,
                    grid: { color: 'rgba(128,128,128,0.2)' },
                    ticks: { color: tickColor, font: { family: this._getPageFont() } }
                }
            };
            // Horizontal bar: Y = category, X = value
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
        }

        const chartData = chartType === 'bar'
            ? {
                labels: labels,
                datasets: [{
                    label: '',
                    data: data,
                    backgroundColor: colors,
                    borderColor: colors.map(c => c),
                    borderWidth: 1
                }]
            }
            : {
                labels: labels,
                datasets: [{
                    data: data,
                    backgroundColor: colors,
                    borderColor: colors.map(c => c),
                    borderWidth: 2,
                    hoverOffset: 4
                }]
            };

        // Apply initial hidden indices if provided
        const hiddenIndices = options?.hiddenIndices || [];

        const chart = new Chart(ctx, {
            type: chartType,
            data: chartData,
            options: chartOptions,
            plugins: []  // centerTextPlugin removed — centre number is now markup
        });

        // Apply hidden state after chart creation
        hiddenIndices.forEach(idx => {
            if (idx >= 0 && idx < labels.length) {
                chart.toggleDataVisibility(idx);
            }
        });
        if (hiddenIndices.length > 0) {
            chart.update('none');
        }

        this._charts[elementId] = chart;

        // Observe container for resize — calls chart.resize() when container size changes.
        // Debounced to avoid firing on every drag frame.
        this._observeContainer(elementId, canvas);
    },

    // Set up ResizeObserver on the chart's container
    _observeContainer: function (elementId, canvas) {
        // Disconnect any existing observer
        if (this._observers[elementId]) {
            this._observers[elementId].disconnect();
            delete this._observers[elementId];
        }

        const container = canvas.parentElement;
        if (!container) return;

        const chart = this._charts[elementId];
        if (!chart) return;

        let resizeTimeout = null;
        const observer = new ResizeObserver(() => {
            // Debounce: coalesce rapid resize events (e.g., during drag)
            if (resizeTimeout) clearTimeout(resizeTimeout);
            resizeTimeout = setTimeout(() => {
                const c = this._charts[elementId];
                if (c && document.body.contains(canvas)) {
                    c.resize();
                }
            }, 50);
        });

        observer.observe(container);
        this._observers[elementId] = observer;
    },

    // Toggle segment visibility (called from Blazor legend click)
    toggleSegment: function (elementId, index) {
        const chart = this._charts[elementId];
        if (!chart) return;
        chart.toggleDataVisibility(index);
        chart.update('none');
    },

    // Rebuild all charts (called on scale change)
    rebuildAll: function () {
        Object.keys(this._charts).forEach(elementId => {
            const chart = this._charts[elementId];
            if (!chart) return;
            const canvas = document.getElementById(elementId);
            if (!canvas || !document.body.contains(canvas)) return;
            // Extract current data and options from chart
            const cd = chart.options._customData || {};
            const segments = (chart.data.labels || []).map((label, i) => ({
                label: label,
                value: chart.data.datasets[0].data[i],
                color: Array.isArray(chart.data.datasets[0].backgroundColor)
                    ? chart.data.datasets[0].backgroundColor[i]
                    : chart.data.datasets[0].backgroundColor
            }));
            const options = {
                chartType: chart.config.type === 'bar' && chart.options.indexAxis === 'y' ? 'horizontalbar' : chart.config.type,
                fontColor: cd.fontColor,
                showLegend: false,
                showValueLabels: cd.showValueLabels,
                valueDisplay: cd.showPercentages ? 'percentages' : 'values'
            };
            // Destroy and rebuild
            chart.destroy();
            delete this._charts[elementId];
            this.render(elementId, segments, options);
        });
    },

    update: function (elementId, segments, options) {
        const chart = this._charts[elementId];

        // A: Verify the chart's canvas is the element we're asked for AND is still in the document
        if (chart) {
            const currentCanvas = document.getElementById(elementId);
            if (!currentCanvas || chart.canvas !== currentCanvas || !document.body.contains(currentCanvas)) {
                // Canvas was replaced or removed — full rebuild
                this.destroy(elementId);
                this.render(elementId, segments, options);
                return;
            }
        }

        if (!chart) {
            this.render(elementId, segments, options);
            return;
        }

        // B: Settings change detection — any visual setting change means full rebuild
        const cd = chart.options._customData || {};
        const newFontColor = options?.fontColor || '#333';
        const newShowValueLabels = options?.showValueLabels ?? true;
        const newValueDisplay = options?.valueDisplay || 'values';

        if (cd.fontColor !== newFontColor ||
            cd.showValueLabels !== newShowValueLabels ||
            (cd.showPercentages ? 'percentages' : 'values') !== newValueDisplay) {
            // Settings changed — full rebuild to apply new axis colors etc.
            this.destroy(elementId);
            this.render(elementId, segments, options);
            return;
        }

        // Data-only update path
        const labels = segments.map(s => s.label);
        const data = segments.map(s => s.value);
        const colors = segments.map(s => s.color);
        const total = data.reduce((a, b) => a + b, 0);

        chart.data.labels = labels;
        chart.data.datasets[0].data = data;
        chart.data.datasets[0].backgroundColor = colors;
        chart.data.datasets[0].borderColor = colors;

        // C: Reset hidden state on all segments so clicked legend rows become visible again
        // For doughnut/pie, legend clicks use toggleDataVisibility — reset via the chart API
        for (let i = 0; i < labels.length; i++) {
            if (!chart.getDataVisibility(i)) chart.toggleDataVisibility(i);
        }
        if (!chart.isDatasetVisible(0)) chart.setDatasetVisibility(0, true);

        // Update customData in chart.options._customData for plugins to read current state
        cd.total = total;
        if (options?.fontColor !== undefined) cd.fontColor = options.fontColor;
        if (options?.valueDisplay !== undefined) cd.showPercentages = options.valueDisplay === 'percentages';
        chart.options._customData = cd;

        chart.update('none');
    },

    destroy: function (elementId) {
        this._cancelPending(elementId);
        // Disconnect ResizeObserver to prevent leaks
        if (this._observers[elementId]) {
            this._observers[elementId].disconnect();
            delete this._observers[elementId];
        }
        if (this._charts[elementId]) {
            this._charts[elementId].destroy();
            delete this._charts[elementId];
        }
    }
};
