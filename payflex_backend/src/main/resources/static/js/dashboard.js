/* global Chart, weekly, topProducts, topClients, monthlyCollections, revenueBreakdown */

(function () {
  const P = () => (typeof window.PF_ADMIN_CHART_PALETTE !== 'undefined'
    ? window.PF_ADMIN_CHART_PALETTE
    : ['#2563eb', '#dc2626', '#16a34a', '#ca8a04', '#9333ea', '#0891b2', '#ea580c', '#db2777']);

  const cAt = (i) => (typeof window.pfChartColor === 'function' ? window.pfChartColor(i) : P()[i % P().length]);

  const labels = (weekly || []).map((p) => p.day);
  const data = (weekly || []).map((p) => p.amount);

  const canvas = document.getElementById('paymentsChart');
  if (canvas) {
    if (window.paymentsChartInstance) {
      window.paymentsChartInstance.destroy();
    }

    const chart = new Chart(canvas, {
      type: 'line',
      data: {
        labels,
        datasets: [{
          label: 'FCFA collectés',
          data,
          borderColor: '#475569',
          borderWidth: 2,
          backgroundColor: 'rgba(37, 99, 235, 0.08)',
          tension: 0.3,
          fill: true,
          pointRadius: 5,
          pointHoverRadius: 7,
          pointBackgroundColor: labels.map((_, i) => cAt(i)),
          pointBorderColor: '#ffffff',
          pointBorderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        resizeDelay: 200,
        animation: { duration: 450 },
        plugins: { legend: { display: false } }
      }
    });

    window.paymentsChartInstance = chart;
  }

  function renderDashboardChart(canvasId, chartType, lbls, values) {
    const el = document.getElementById(canvasId);
    if (!el) return;

    const existing = Chart.getChart(el);
    if (existing) existing.destroy();

    const n = lbls.length;
    const colors = Array.from({ length: n }, (_, i) => cAt(i));

    const dataset = {
      data: values,
      borderWidth: chartType === 'bar' ? 0 : 2
    };

    if (chartType === 'bar') {
      dataset.backgroundColor = colors;
      dataset.borderColor = colors.map((hex) => hex);
    } else if (chartType === 'doughnut') {
      dataset.backgroundColor = colors;
      dataset.borderColor = '#ffffff';
      dataset.borderWidth = 2;
      dataset.hoverOffset = 6;
    } else if (chartType === 'line') {
      dataset.label = 'FCFA';
      dataset.borderColor = '#64748b';
      dataset.backgroundColor = 'rgba(100, 116, 139, 0.12)';
      dataset.tension = 0.35;
      dataset.fill = true;
      dataset.pointRadius = 5;
      dataset.pointHoverRadius = 7;
      dataset.pointBackgroundColor = colors;
      dataset.pointBorderColor = '#fff';
      dataset.pointBorderWidth = 2;
    }

    new Chart(el, {
      type: chartType,
      data: {
        labels: lbls,
        datasets: [dataset]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: chartType === 'doughnut',
            position: 'bottom',
            labels: { boxWidth: 12, padding: 8, font: { size: 11 } }
          }
        }
      }
    });
  }

  renderDashboardChart(
    'topProductsChart',
    'bar',
    (topProducts || []).map((x) => x.label),
    (topProducts || []).map((x) => x.value)
  );

  renderDashboardChart(
    'topClientsChart',
    'doughnut',
    (topClients || []).map((x) => x.label),
    (topClients || []).map((x) => x.value)
  );

  renderDashboardChart(
    'monthlyCollectionsChart',
    'line',
    (monthlyCollections || []).map((x) => x.label),
    (monthlyCollections || []).map((x) => x.value)
  );

  (function renderRevenueChart() {
    const el = document.getElementById('revenueChart');
    const rows = revenueBreakdown || [];
    if (!el || !rows.length) return;

    const existing = Chart.getChart(el);
    if (existing) existing.destroy();

    const labels = rows.map((r) => r.label);
    const adhesion = rows.map((r) => Number(r.adhesionRevenueFcfa || 0));
    const bonus = rows.map((r) => Number(r.bonusDayRevenueFcfa || 0));

    new Chart(el, {
      type: 'bar',
      data: {
        labels,
        datasets: [
          {
            label: 'Adhésions',
            data: adhesion,
            backgroundColor: '#2563eb',
            borderRadius: 4,
            stack: 'rev'
          },
          {
            label: 'Jour hors plan',
            data: bonus,
            backgroundColor: '#d97706',
            borderRadius: 4,
            stack: 'rev'
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: true,
            position: 'bottom',
            labels: { boxWidth: 10, padding: 6, font: { size: 10 } }
          }
        },
        scales: {
          x: { stacked: true, ticks: { font: { size: 10 } } },
          y: { stacked: true, ticks: { font: { size: 10 } } }
        }
      }
    });
  })();
})();
