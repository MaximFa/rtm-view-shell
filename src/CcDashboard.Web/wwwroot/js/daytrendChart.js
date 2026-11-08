// DayTrend Chart — Chart.js interop for Blazor
// UNIT14: legend moved to markup
window.dayTrendChart = {
    _charts: {},
    _pendingRenders: {},  // Track pending retry timers by elementId
    _lastRenderArgs: {},  // Store last render args for rebuild
    _observers: {},       // ResizeObservers per elementId

    // Compute canvas density: max(2, dpr) * max(1, s), ceiling 4.
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
        const raw = Math.max(3, dpr) * Math.max(1, s);
        return Math.min(raw, 4);  // ceiling 4 -> ~10.6 MB on 853x345
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

    // Seconds as mm:ss; with withHours, an hour or more as h:mm:ss (Queue Trend: "mm:ss / hh:mm:ss", operator 2026-11-08 18:21).
    _formatSeconds: function (value, withHours) {
        const total = Math.round(value);
        const pad = n => n.toString().padStart(2, '0');
        if (withHours && total >= 3600)
            return Math.floor(total / 3600) + ':' + pad(Math.floor((total % 3600) / 60)) + ':' + pad(total % 60);
        return pad(Math.floor(total / 60)) + ':' + pad(total % 60);
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
            responsive: false,   // size owned by _applyCanvasSize (see its comment)
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
                            let label = context.dataset.metric || context.dataset.label || '';
                            if (label) label += ': ';
                            if (context.parsed.y !== null && options?.percent) {
                                // percent (Agent State Trend): one decimal and the sign
                                label += context.parsed.y.toFixed(1) + '%';
                            } else if (context.parsed.y !== null) {
                                // Format time metrics as mm:ss (hh:mm:ss for an hour or more, when the caller asks)
                                if (context.dataset.isTimeMetric) {
                                    label += window.dayTrendChart._formatSeconds(context.parsed.y, options?.timeHours);
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
                    ticks: { font: { size: options?.fontSize || 11, family: this._getPageFont() }, color: options?.fontColor || undefined }
                },
                y: {
                    type: 'linear',
                    display: true,
                    position: 'left',
                    beginAtZero: true,
                    grid: { color: this._hexToRgba(options?.fontColor, 0.12) },
                    ticks: { font: { size: options?.fontSize || 11, family: this._getPageFont() }, color: options?.fontColor || undefined }
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
                    font: { size: options?.fontSize || 11, family: this._getPageFont() },
                    color: options?.fontColor || undefined,
                    callback: function (value) {
                        return window.dayTrendChart._formatSeconds(value, options?.timeHours);
                    }
                }
            };
        }

        // FEAT-REPORT-QUEUE-TREND-COMPARE-01 (Queue Trend, operator 2026-11-08 18:08 / 18:17 / 18:20 / 18:21), all OPT-IN - DayTrend
        // passes none of these and draws as before:
        //   compareLabels - the comparison period's interval labels on a second X axis at the top (interval i over interval i);
        //   periodLabels  - the main period's labels, for the tooltip title; a point's title is the date of ITS period.
        if (options?.compareLabels) {
            const tick = { font: { size: options?.fontSize || 11, family: this._getPageFont() }, color: options?.fontColor || undefined };
            defaultOptions.scales.x2 = { position: 'top', labels: options.compareLabels, grid: { display: false }, ticks: tick };
        }
        //   percent       - every line is a share of 100 (Agent State Trend): the Y axis is 0..100 with a % sign.
        if (options?.percent) {
            defaultOptions.scales.y.max = 100;
            defaultOptions.scales.y.ticks.callback = function (value) { return value + '%'; };
        }
        if (options?.periodLabels) {
            const main = options.periodLabels, compare = options.compareLabels || [];
            defaultOptions.interaction = { mode: 'nearest', intersect: false };
            defaultOptions.plugins.tooltip.callbacks.title = function (items) {
                if (!items.length) return '';
                const i = items[0].dataIndex;
                return (items[0].dataset.period === 'compare' ? compare : main)[i] || '';
            };
        }

        // Merge with provided options
        const chartOptions = { ...defaultOptions, ...options };

        // Configure datasets
        const configuredDatasets = datasets.map(ds => {
            const baseConfig = {
                label: ds.label,
                // A missing value is drawn as 0 - for DayTrend as always, and for both report trends too (operator 2026-11-08
                // 23:21, PR234-V4-TREND-GAPS-AND-OVERSHOOT-01: zeros, not gaps). The tooltip still shows the value as 0.
                data: ds.data.map(v => (v === null || v === undefined) ? 0 : v),
                borderColor: ds.color,
                backgroundColor: ds.color + '40',
                borderWidth: ds.isAgentMetric ? 2 : 2,
                borderDash: ds.isAgentMetric ? [5, 5] : (ds.dashed ? [6, 4] : []),
                fill: options?.chartType === 'area',
                tension: 0.3,
                // monotone (report trends, PR234-V4-TREND-GAPS-AND-OVERSHOOT-01): the curve never leaves the range of its
                // points - "Other" went below 0 % between two zero-ish points. DayTrend passes nothing and keeps its curve.
                cubicInterpolationMode: options?.monotone ? 'monotone' : 'default',
                pointRadius: options?.showDataLabels ? 4 : 2,
                pointHoverRadius: 6,
                yAxisID: ds.isTimeMetric ? 'y1' : 'y',
                isTimeMetric: ds.isTimeMetric,
                metric: ds.metric,    // the metric's own name for the tooltip (Queue Trend)
                period: ds.period     // 'main' | 'compare' (Queue Trend)
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

        // responsive is false — apply the real container size now
        this._applyCanvasSize(elementId, canvas);

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
                    // responsive is false: the size is ours to apply, chart.resize() alone
                    // would re-measure nothing and keep the stale size
                    this._applyCanvasSize(elementId, canvas);
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
            // Drop our inline size: the rebuild measures the container itself
            this._clearCanvasSize(canvas);
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
        // Reset the inline size this module wrote on the canvas
        this._clearCanvasSize(document.getElementById(elementId));
    }
};
