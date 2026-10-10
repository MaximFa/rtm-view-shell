// DayTrend Chart — Chart.js interop for Blazor
window.dayTrendChart = {
    _charts: {},

    // Compute canvas density: max(2, dpr) * max(1, s), ceiling 4
    // s = viewer scale (< 1 when compressed to fit; 1 in actual-size mode)
    _getDensity: function () {
        const dpr = window.devicePixelRatio || 1;
        let s = 1;
        // Read current viewer scale from transform if present
        if (window.viewerScale && window.viewerScale.designEl) {
            const transform = window.viewerScale.designEl.style.transform;
            const match = transform && transform.match(/scale\(([\d.]+)\)/);
            if (match) s = parseFloat(match[1]) || 1;
        }
        const raw = Math.max(2, dpr) * Math.max(1, s);
        return Math.min(raw, 4);  // ceiling 4 -> ~10.6 MB on 853x345
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

    render: function (elementId, labels, datasets, options) {
        // Check if Chart.js is loaded
        if (typeof Chart === 'undefined') {
            console.error('dayTrendChart: Chart.js is not loaded. Make sure CDN is accessible.');
            return;
        }

        if (this._charts[elementId]) {
            this._charts[elementId].destroy();
        }

        const canvas = document.getElementById(elementId);
        if (!canvas) {
            console.warn('dayTrendChart: canvas element not found:', elementId);
            return;
        }

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
                legend: {
                    display: options?.showLegend ?? true,
                    position: 'bottom',
                    labels: {
                        usePointStyle: true,
                        padding: 12,
                        font: { size: 11, family: this._getPageFont() },
                        color: options?.fontColor || undefined
                    }
                },
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

        this._charts[elementId] = new Chart(ctx, {
            type: chartType,
            data: { labels, datasets: configuredDatasets },
            options: chartOptions
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
        chart.update('none');
    },

    destroy: function (elementId) {
        if (this._charts[elementId]) {
            this._charts[elementId].destroy();
            delete this._charts[elementId];
        }
    }
};
