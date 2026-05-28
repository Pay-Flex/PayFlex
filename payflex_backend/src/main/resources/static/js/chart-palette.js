/**
 * Palette libre pour graphiques / diagrammes admin.
 * (La charte UI reste bleu sombre + doré ; les courbes et camemberts peuvent nuancer avec toutes ces teintes.)
 */
window.PF_ADMIN_CHART_PALETTE = [
  '#2563eb', '#dc2626', '#16a34a', '#d97706', '#9333ea', '#0891b2',
  '#ea580c', '#db2777', '#4f46e5', '#0d9488', '#e11d48', '#65a30d',
  '#7c3aed', '#059669', '#be123c', '#0ea5e9', '#a855f7', '#14b8a6',
  '#f43f5e', '#8b5cf6', '#22c55e', '#eab308'
];

window.pfChartColor = function (i) {
  const p = window.PF_ADMIN_CHART_PALETTE;
  return p[i % p.length];
};
