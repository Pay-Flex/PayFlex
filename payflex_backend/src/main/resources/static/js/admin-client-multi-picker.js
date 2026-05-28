/**
 * Sélecteur clients multi avec recherche (message groupé chat admin).
 */
(function (global) {
  function normalize(s) {
    return (s || '')
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '');
  }

  function clientsFromSelect(select) {
    if (!select) return [];
    return Array.from(select.options).map((opt) => {
      const label = (opt.textContent || '').trim();
      const phone = opt.getAttribute('data-phone') || '';
      const zone = opt.getAttribute('data-zone') || '';
      return {
        id: String(opt.value),
        label,
        phone,
        zone,
        searchKey: normalize(label + ' ' + phone + ' ' + zone),
      };
    });
  }

  function mount(root) {
    if (!root || root.dataset.mounted === '1') return;
    const select = root.querySelector('select[name="userIds"]');
    const trigger = root.querySelector('.pf-cat-picker-trigger');
    const summaryEl = root.querySelector('.pf-client-picker-summary');
    const panel = root.querySelector('.pf-cat-picker-panel');
    const search = root.querySelector('.pf-cat-picker-search');
    const list = root.querySelector('.pf-cat-picker-list');
    const chips = root.querySelector('.pf-client-picker-chips');
    if (!select || !trigger || !summaryEl || !panel || !search || !list || !chips) return;

    const clients = clientsFromSelect(select);
    const selected = new Set();

    function close() {
      root.classList.remove('pf-cat-picker-open');
    }

    function open() {
      root.classList.add('pf-cat-picker-open');
      search.value = '';
      render('');
      setTimeout(() => search.focus(), 0);
    }

    function syncSelect() {
      Array.from(select.options).forEach((opt) => {
        opt.selected = selected.has(String(opt.value));
      });
    }

    function updateSummary() {
      const n = selected.size;
      if (n === 0) {
        summaryEl.textContent = 'Rechercher et sélectionner des clients…';
        summaryEl.classList.add('text-slate-400');
        summaryEl.classList.remove('text-slate-800');
      } else if (n === 1) {
        const id = [...selected][0];
        const c = clients.find((x) => x.id === id);
        summaryEl.textContent = c ? c.label : '1 client sélectionné';
        summaryEl.classList.remove('text-slate-400');
        summaryEl.classList.add('text-slate-800');
      } else {
        summaryEl.textContent = n + ' client(s) sélectionné(s)';
        summaryEl.classList.remove('text-slate-400');
        summaryEl.classList.add('text-slate-800');
      }
    }

    function renderChips() {
      chips.innerHTML = '';
      selected.forEach((id) => {
        const c = clients.find((x) => x.id === id);
        if (!c) return;
        const chip = document.createElement('span');
        chip.className = 'pf-client-picker-chip';
        chip.innerHTML =
          '<span class="truncate max-w-[200px]">' +
          escapeHtml(c.label.split('·')[0].trim()) +
          '</span>' +
          '<button type="button" class="pf-client-picker-chip-remove" aria-label="Retirer">&times;</button>';
        chip.querySelector('button').addEventListener('click', (e) => {
          e.preventDefault();
          selected.delete(id);
          syncSelect();
          updateSummary();
          renderChips();
          render(search.value);
        });
        chips.appendChild(chip);
      });
    }

    function escapeHtml(s) {
      return s
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
    }

    function toggleClient(c) {
      if (selected.has(c.id)) selected.delete(c.id);
      else selected.add(c.id);
      syncSelect();
      updateSummary();
      renderChips();
      render(search.value);
    }

    function render(filter) {
      const q = normalize(filter);
      list.innerHTML = '';
      const matches = clients.filter((c) => !q || c.searchKey.includes(q));
      if (matches.length === 0) {
        const empty = document.createElement('li');
        empty.className = 'pf-cat-picker-empty px-3 py-2 text-sm text-slate-500';
        empty.textContent = clients.length === 0 ? 'Aucun client disponible' : 'Aucun client trouvé';
        list.appendChild(empty);
        return;
      }
      matches.forEach((c) => {
        const li = document.createElement('li');
        const on = selected.has(c.id);
        li.className = 'pf-cat-picker-option pf-client-picker-option' + (on ? ' pf-client-picker-option--on' : '');
        li.setAttribute('role', 'option');
        li.setAttribute('aria-selected', on ? 'true' : 'false');
        li.innerHTML =
          '<span class="pf-client-picker-check"><i class="fa-solid fa-check text-[10px]"></i></span>' +
          '<span class="min-w-0 flex-1">' +
          '<span class="block font-medium text-slate-800 truncate">' +
          escapeHtml(c.label) +
          '</span>' +
          (c.zone
            ? '<span class="block text-xs text-slate-500 truncate">' + escapeHtml(c.zone) + '</span>'
            : '') +
          '</span>';
        li.addEventListener('click', () => toggleClient(c));
        list.appendChild(li);
      });
    }

    trigger.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      if (root.classList.contains('pf-cat-picker-open')) close();
      else open();
    });

    panel.addEventListener('click', (e) => e.stopPropagation());

    search.addEventListener('input', () => render(search.value));

    search.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        close();
        trigger.focus();
      }
      if (e.key === 'Enter') {
        e.preventDefault();
        const first = list.querySelector('.pf-client-picker-option:not(.pf-cat-picker-empty)');
        if (first) first.click();
      }
    });

    document.addEventListener('click', (e) => {
      if (!root.contains(e.target)) close();
    });

    root.dataset.mounted = '1';
    root.pfClientPicker = {
      getSelectedIds: () => [...selected],
      validate: () => {
        if (selected.size === 0) {
          summaryEl.classList.add('text-red-600');
          open();
          return false;
        }
        return true;
      },
    };
  }

  function initAll() {
    document.querySelectorAll('.pf-client-multi-picker').forEach((el) => mount(el));
  }

  global.PfClientMultiPicker = { mount, initAll };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initAll);
  } else {
    initAll();
  }
})(window);
