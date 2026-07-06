// DayTrend Chart — Chart.js interop for Blazor
window.dayTrendChart = {
    _charts: {},

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
            devicePixelRatio: Math.max(2, window.devicePixelRatio || 1),
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
                        font: { size: 11 },
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
                    ticks: { font: { size: 10 } }
                },
                y: {
                    type: 'linear',
                    display: true,
                    position: 'left',
                    beginAtZero: true,
                    grid: { color: 'rgba(255,255,255,0.1)' },
                    ticks: { font: { size: 10 } }
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
                    font: { size: 10 },
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
