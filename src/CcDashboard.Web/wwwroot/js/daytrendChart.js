// DayTrend Chart — Chart.js interop for Blazor
// UNIT14: legend moved to markup
window.dayTrendChart = {
    _charts: {},
    _pendingRenders: {},  // Track pending retry timers by elementId
    _lastRenderArgs: {},  // Store last render args for rebuild
    _observers: {},       // ResizeObservers per elementId

    // Compute canvas density. Compensates for compression, not for nothing.
    // s = viewer scale (< 1 when compressed to fit; >= 1 in actual-size / zoom).
    // IDENTICAL FORMULA in agentStateDistributionChart.js — keep them in sync.
    _getDensity: function (dprOverride, sOverride) {
        const dpr = dprOverride ?? (window.devicePixelRatio || 1);
        let s = sOverride ?? 1;
        // Read current viewer scale from transform if present (when not overridden)
        if (sOverride === undefined && window.viewerScale && window.viewerScale.designEl) {
            const transform = window.viewerScale.designEl.style.transform;
            const match = transform && transform.match(/scale\(([\d.]+)\)/);
            if (match) s = parseFloat(match[1]) || 1;
        }
        // No compression (s >= 1): density = dpr — pixel for pixel, no downscale.
        // Compressed (s < 1): density = dpr / s — the drawing matches the physical
        // pixels the smaller CSS box occupies.
        const raw = s >= 1 ? dpr : dpr / s;
        // Floor 1, ceiling 4
        return Math.max(1, Math.min(raw, 4));
    },

    // Read page font from --font-family token
    _getPageFont: function () {
        return getComputedStyle(document.documentElement).getPropertyValue('--font-family').trim() || undefined;
    },

    // Convert hex color to rgba with given opacity
    _hexToRgba: function (hex, opacity) {
        if (!hex || typeof hex !== 'string') return `rgba(128,128,128,${opacity})`;
        hex = hex.replace('#', '');
        if (hex.length === 3) hex = hex.split('').map(c => c + c).join('');
        const parse = s => { const n = parseInt(s, 16); return Number.isNaN(n) ? 128 : n; };
        const r = parse(hex.substring(0, 2));
        const g = parse(hex.substring(2, 4));
        const b = parse(hex.substring(4, 6));
        return `rgba(${r},${g},${b},${opacity})`;
    },

    // Wait for canvas element to appear, then call callback. Timeout after ~10s.
    _waitForCanvas: function (elementId, callback, startTime) {
        if (!startTime) startTime = Date.now();
        const elapsed = Date.now() - startTime;
        // Timeout after 10 seconds — the widget was probably removed
        if (elapsed > 10000) {
            console.warn('dayTrendChart: timeout waiting for canvas:', elementId);
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

    render: function (elementId, labels, datasets, options) {
        // Check if Chart.js is loaded
        if (typeof Chart === 'undefined') {
            console.error('dayTrendChart: Chart.js is not loaded. Make sure CDN is accessible.');
            return;
        }

        if (this._charts[elementId]) {
            this._charts[elementId].destroy();
        }

        // Cancel any pending retry for this element
        this._cancelPending(elementId);

        // Store render args for rebuild on scale change
        this._lastRenderArgs[elementId] = { labels, datasets, options };

        const canvas = document.getElementById(elementId);
        if (!canvas) {
            // Canvas not in DOM yet — wait and retry
            this._waitForCanvas(elementId, (c) => {
                this._doRender(elementId, c, labels, datasets, options);
            });
            return;
        }

        this._doRender(elementId, canvas, labels, datasets, options);
    },

    // Internal render implementation (canvas guaranteed to exist)
    _doRender: function (elementId, canvas, labels, datasets, options) {
        const ctx = canvas.getContext('2d');
        if (!ctx) return;

        // Default options
        const defaultOptions = {
            responsive: true,
            maintainAspectRatio: false,
            animation: false,
            devicePixelRatio: this._getDensity(),
            interaction: {
                mode: 'nearest',
                intersect: true
            },
            plugins: {
                // Legend always hidden — we use markup legend
                legend: { display: false },
                tooltip: {
                    enabled: true,
                    callbacks: {
                        label: function (context) {
                            let label = context.dataset.label || '';
                            if (label) label += ': ';
                            if (context.parsed.y !== null) {
                                // Format time metrics as mm:ss
                                if (context.dataset.isTimeMetric) {
                                    const totalSeconds = Math.round(context.parsed.y);
                                    const mins = Math.floor(totalSeconds / 60);
                                    const secs = totalSeconds % 60;
                                    label += mins.toString().padStart(2, '0') + ':' + secs.toString().padStart(2, '0');
                                } else {
                                    label += context.parsed.y.toLocaleString();
                                }
                            }
                            return label;
                        }
                    }
                }
            },
            scales: {
                x: {
                    grid: { display: false },
                    ticks: { font: { size: 11, family: this._getPageFont() }, color: options?.fontColor || undefined }
                },
                y: {
                    type: 'linear',
                    display: true,
                    position: 'left',
                    beginAtZero: true,
                    grid: { color: this._hexToRgba(options?.fontColor, 0.12) },
                    ticks: { font: { size: 11, family: this._getPageFont() }, color: options?.fontColor || undefined }
                }
            }
        };

        // Add secondary Y-axis if needed (for time metrics)
        const hasTimeMetrics = datasets.some(d => d.isTimeMetric);
        if (hasTimeMetrics) {
            defaultOptions.scales.y1 = {
                type: 'linear',
                display: true,
                position: 'right',
                beginAtZero: true,
                grid: { drawOnChartArea: false },
                ticks: {
                    font: { size: 11, family: this._getPageFont() },
                    color: options?.fontColor || undefined,
                    callback: function (value) {
                        const mins = Math.floor(value / 60);
                        const secs = value % 60;
                        return mins.toString().padStart(2, '0') + ':' + secs.toString().padStart(2, '0');
                    }
                }
            };
        }

        // Merge with provided options
        const chartOptions = { ...defaultOptions, ...options };

        // Configure datasets
        const configuredDatasets = datasets.map(ds => {
            const baseConfig = {
                label: ds.label,
                data: ds.data.map(v => (v === null || v === undefined) ? 0 : v),
                borderColor: ds.color,
                backgroundColor: ds.color + '40',
                borderWidth: ds.isAgentMetric ? 2 : 2,
                borderDash: ds.isAgentMetric ? [5, 5] : [],
                fill: options?.chartType === 'area',
                tension: 0.3,
                pointRadius: options?.showDataLabels ? 4 : 2,
                pointHoverRadius: 6,
                yAxisID: ds.isTimeMetric ? 'y1' : 'y',
                isTimeMetric: ds.isTimeMetric
            };
            return baseConfig;
        });

        // Determine chart type
        let chartType = options?.chartType || 'line';
        let isBar = chartType === 'bar';
        if (chartType === 'area') chartType = 'line';
        if (chartType === 'step') {
            chartType = 'line';
            configuredDatasets.forEach(ds => ds.stepped = true);
        }
        if (isBar) {
            chartType = 'bar';
            configuredDatasets.forEach(ds => {
                ds.backgroundColor = ds.borderColor + '99';
                ds.borderWidth = 1;
                delete ds.tension;
                delete ds.fill;
                delete ds.pointRadius;
                delete ds.pointHoverRadius;
            });
        }

        const chart = new Chart(ctx, {
            type: chartType,
            data: { labels, datasets: configuredDatasets },
            options: chartOptions
        });

        // Apply hidden state after chart creation
        const hiddenDatasets = options?.hiddenDatasets || [];
        hiddenDatasets.forEach(idx => {
            if (idx >= 0 && idx < configuredDatasets.length) {
                chart.setDatasetVisibility(idx, false);
            }
        });
        if (hiddenDatasets.length > 0) {
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

    // Toggle dataset visibility (called from Blazor legend click)
    toggleDataset: function (elementId, datasetIndex) {
        const chart = this._charts[elementId];
        if (!chart) return;
        const currentlyVisible = chart.isDatasetVisible(datasetIndex);
        chart.setDatasetVisibility(datasetIndex, !currentlyVisible);
        chart.update('none');
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
            this.render(elementId, args.labels, args.datasets, args.options);
        });
    },

    update: function (elementId, labels, datasets) {
        const chart = this._charts[elementId];
        if (!chart) {
            console.warn('dayTrendChart: chart not found for update:', elementId);
            return;
        }

        chart.data.labels = labels;
        datasets.forEach((ds, idx) => {
            if (chart.data.datasets[idx]) {
                chart.data.datasets[idx].data = ds.data;
            }
        });

        // Reset all datasets to visible on data update
        for (let i = 0; i < chart.data.datasets.length; i++) {
            if (!chart.isDatasetVisible(i)) {
                chart.setDatasetVisibility(i, true);
            }
        }

        chart.update('none');
    },

    destroy: function (elementId) {
        this._cancelPending(elementId);
        delete this._lastRenderArgs[elementId];
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
