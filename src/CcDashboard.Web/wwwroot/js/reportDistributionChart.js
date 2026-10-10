// Report Distribution Chart — Chart.js interop for Blazor report widgets
window.reportDistributionChart = {
    _charts: {},

    render: function (elementId, segments, options) {
        if (typeof Chart === 'undefined') {
            console.error('reportDistributionChart: Chart.js is not loaded.');
            return;
        }

        if (this._charts[elementId]) {
            this._charts[elementId].destroy();
        }

        const canvas = document.getElementById(elementId);
        if (!canvas) {
            console.warn('reportDistributionChart: canvas element not found:', elementId);
            return;
        }

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
            responsive: true,
            maintainAspectRatio: false,
            devicePixelRatio: Math.max(2, window.devicePixelRatio || 1),
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
                    ticks: { color: tickColor }
                },
                y: {
                    beginAtZero: true,
                    grid: { color: 'rgba(128,128,128,0.2)' },
                    ticks: { color: tickColor }
                }
            }
        };

        if (indexAxis === 'y') {
            chartOptions.scales = {
                y: {
                    grid: { display: false },
                    ticks: { color: tickColor }
                },
                x: {
                    beginAtZero: true,
                    grid: { color: 'rgba(128,128,128,0.2)' },
                    ticks: { color: tickColor }
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
