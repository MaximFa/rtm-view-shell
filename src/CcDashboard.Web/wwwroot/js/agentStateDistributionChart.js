// Agent State Distribution Chart — Chart.js interop for Blazor
window.agentStateDistributionChart = {
    _charts: {},

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

    render: function (elementId, segments, options) {
        if (typeof Chart === 'undefined') {
            console.error('agentStateDistributionChart: Chart.js is not loaded.');
            return;
        }

        if (this._charts[elementId]) {
            this._charts[elementId].destroy();
            delete this._charts[elementId];
        }

        const canvas = document.getElementById(elementId);
        if (!canvas) {
            console.warn('agentStateDistributionChart: canvas element not found:', elementId);
            return;
        }

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
        const centerLabel = options?.centerLabel || 'Agents';
        const fontColor = options?.fontColor || '#333';

        // Create customData BEFORE chart construction so plugins can access it during first draw
        const customData = {
            total: total,
            centerLabel: centerLabel,
            fontColor: fontColor,
            isDoughnut: isDoughnut,
            showPercentages: showPercentages,
            showLegend: options?.showLegend ?? true,
            showValueLabels: options?.showValueLabels ?? true
        };

        const chartOptions = {
            responsive: true,
            maintainAspectRatio: false,
            animation: false,
            devicePixelRatio: Math.max(2, window.devicePixelRatio || 1),
            indexAxis: indexAxis,
            // Store customData in options so it's available during chart construction
            _customData: customData,
            plugins: {
                legend: {
                    display: chartType === 'bar' ? false : (options?.showLegend ?? true),
                    position: 'bottom',
                    align: 'start',
                    labels: {
                        usePointStyle: true,
                        padding: 8,
                        font: { size: 11 },
                        color: fontColor,
                        generateLabels: function (chart) {
                            const ds = chart.data.datasets[0];
                            const chartData = ds.data;
                            // Read from chart.options._customData (available during first draw)
                            const cd = chart.options._customData || {};
                            const dataTotal = chartData.reduce((a, b) => a + b, 0);
                            const showPct = cd.showPercentages ?? false;
                            return (chart.data.labels || []).map((lbl, i) => {
                                const clr = Array.isArray(ds.backgroundColor) ? ds.backgroundColor[i] : ds.backgroundColor;
                                const rawValue = chartData[i] || 0;
                                const pct = dataTotal > 0 ? Math.round((rawValue / dataTotal) * 100) : 0;
                                // Format matching tooltip: percentages -> "Label: N% (count)", values -> "Label: count (N%)"
                                const labelText = showPct
                                    ? `${lbl}: ${pct}% (${rawValue})`
                                    : `${lbl}: ${rawValue} (${pct}%)`;
                                return {
                                    text: labelText,
                                    fillStyle: clr + '40',
                                    strokeStyle: clr,
                                    lineWidth: 2,
                                    pointStyle: 'circle',
                                    fontColor: cd.fontColor || '#333',
                                    hidden: !chart.isDatasetVisible(0) ? true : chart.getDatasetMeta(0).data[i]?.hidden,
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
                    ticks: { color: tickColor }
                },
                y: {
                    beginAtZero: true,
                    grid: { color: 'rgba(128,128,128,0.2)' },
                    ticks: { color: tickColor }
                }
            };
            // Horizontal bar: Y = category, X = value
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

        // Center text plugin for doughnut — reads from chart.options._customData so it's available during first draw
        const centerTextPlugin = {
            id: 'centerText',
            afterDraw: function (chart) {
                // Read from chart.options._customData (available during construction)
                const cd = chart.options._customData || {};
                if (!cd.isDoughnut) return;
                const ctx = chart.ctx;
                const { width, height } = chart.chartArea || chart;
                const centerX = chart.chartArea ? (chart.chartArea.left + chart.chartArea.right) / 2 : width / 2;
                const centerY = chart.chartArea ? (chart.chartArea.top + chart.chartArea.bottom) / 2 : height / 2;
                const currentTotal = cd.total ?? 0;
                const currentLabel = cd.centerLabel || 'Agents';
                const currentFontColor = cd.fontColor || '#333';

                ctx.save();
                // Draw total number
                ctx.font = 'bold 24px sans-serif';
                ctx.fillStyle = currentFontColor;
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                ctx.fillText(currentTotal.toString(), centerX, centerY - 8);
                // Draw label below
                ctx.font = '12px sans-serif';
                ctx.fillStyle = currentFontColor;
                ctx.fillText(currentLabel, centerX, centerY + 14);
                ctx.restore();
            }
        };

        const chart = new Chart(ctx, {
            type: chartType,
            data: chartData,
            options: chartOptions,
            plugins: [centerTextPlugin]
        });

        this._charts[elementId] = chart;
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
        const newShowLegend = options?.showLegend ?? true;
        const newShowValueLabels = options?.showValueLabels ?? true;
        const newValueDisplay = options?.valueDisplay || 'values';

        if (cd.fontColor !== newFontColor ||
            cd.showLegend !== newShowLegend ||
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
        const meta = chart.getDatasetMeta(0);
        if (meta && meta.data) {
            for (let i = 0; i < meta.data.length; i++) {
                if (meta.data[i]) {
                    meta.data[i].hidden = false;
                }
            }
        }

        // Update customData in chart.options._customData for plugins to read current state
        cd.total = total;
        if (options?.centerLabel !== undefined) cd.centerLabel = options.centerLabel;
        if (options?.fontColor !== undefined) cd.fontColor = options.fontColor;
        if (options?.valueDisplay !== undefined) cd.showPercentages = options.valueDisplay === 'percentages';
        chart.options._customData = cd;

        chart.update('none');
    },

    destroy: function (elementId) {
        if (this._charts[elementId]) {
            this._charts[elementId].destroy();
            delete this._charts[elementId];
        }
    }
};
