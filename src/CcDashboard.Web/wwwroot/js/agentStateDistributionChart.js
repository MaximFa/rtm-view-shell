// Agent State Distribution Chart — Chart.js interop for Blazor
window.agentStateDistributionChart = {
    _charts: {},

    render: function (elementId, segments, options) {
        if (typeof Chart === 'undefined') {
            console.error('agentStateDistributionChart: Chart.js is not loaded.');
            return;
        }

        if (this._charts[elementId]) {
            this._charts[elementId].destroy();
        }

        const canvas = document.getElementById(elementId);
        if (!canvas) {
            console.warn('agentStateDistributionChart: canvas element not found:', elementId);
            return;
        }

        const ctx = canvas.getContext('2d');
        if (!ctx) return;

        const labels = segments.map(s => s.label);
        const data = segments.map(s => s.value);
        const colors = segments.map(s => s.color);
        const total = data.reduce((a, b) => a + b, 0);

        const showPercentages = options?.valueDisplay === 'percentages';

        let chartType = options?.chartType || 'doughnut';
        let indexAxis = undefined;

        if (chartType === 'horizontalbar') {
            chartType = 'bar';
            indexAxis = 'y';
        }

        const chartOptions = {
            responsive: true,
            maintainAspectRatio: false,
            indexAxis: indexAxis,
            plugins: {
                legend: {
                    display: options?.showLegend ?? true,
                    position: 'bottom',
                    labels: {
                        usePointStyle: true,
                        padding: 10,
                        font: { size: 11 },
                        color: options?.fontColor,
                        // Unified per-segment legend for all chart types (pie, doughnut, bar, horizbar).
                        // Chart.defaults.plugins.legend.labels.generateLabels is the GLOBAL (bar/line)
                        // default — calling it from pie/doughnut yields one 'undefined' item.
                        // Single implementation covers all types consistently.
                        generateLabels: function (chart) {
                            const ds = chart.data.datasets[0];
                            return (chart.data.labels || []).map((lbl, i) => {
                                const clr = Array.isArray(ds.backgroundColor) ? ds.backgroundColor[i] : ds.backgroundColor;
                                return {
                                    text: lbl,
                                    fillStyle: clr + '40', // 25% opacity — matches DayTrend
                                    strokeStyle: clr,      // solid border
                                    lineWidth: 2,
                                    pointStyle: 'circle',
                                    hidden: false,
                                    index: i
                                };
                            });
                        }
                    }
                },
                tooltip: {
                    enabled: true,
                    callbacks: {
                        label: function (context) {
                            const value = context.parsed;
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
            }
        };

        // Configure data labels on segments
        if (options?.showValueLabels) {
            chartOptions.plugins.datalabels = {
                color: '#fff',
                font: { weight: 'bold', size: 12 },
                formatter: function (value, ctx) {
                    if (value === 0) return '';
                    if (showPercentages && total > 0) {
                        const pct = Math.round((value / total) * 100);
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
            chartOptions.scales = {
                x: {
                    grid: { display: false },
                    ticks: { display: false }
                },
                y: {
                    beginAtZero: true,
                    grid: { color: 'rgba(128,128,128,0.2)' },
                    ticks: {}
                }
            };
            if (indexAxis === 'y') {
                chartOptions.scales = {
                    y: {
                        grid: { display: false },
                        ticks: { display: false }
                    },
                    x: {
                        beginAtZero: true,
                        grid: { color: 'rgba(128,128,128,0.2)' },
                        ticks: {}
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

        this._charts[elementId] = new Chart(ctx, {
            type: chartType,
            data: chartData,
            options: chartOptions
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
        if (this._charts[elementId]) {
            this._charts[elementId].destroy();
            delete this._charts[elementId];
        }
    }
};
