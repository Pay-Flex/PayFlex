/**
 * Liste déroulante catégorie avec recherche (formulaires produits admin).
 */
(function (global) {
  const pickers = new Map();

  function normalize(s) {
    return (s || '')
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '');
  }

  function mount(root, categories) {
    if (!root || pickers.has(root)) {
      return pickers.get(root);
    }
    const hidden = root.querySelector('input[type="hidden"]');
    const trigger = root.querySelector('.pf-cat-picker-trigger');
    const labelEl = root.querySelector('.pf-cat-picker-label');
    const panel = root.querySelector('.pf-cat-picker-panel');
    const search = root.querySelector('.pf-cat-picker-search');
    const list = root.querySelector('.pf-cat-picker-list');
    if (!hidden || !trigger || !labelEl || !panel || !search || !list) {
      return null;
    }
    const cats = Array.isArray(categories) ? categories : [];

    function close() {
      root.classList.remove('pf-cat-picker-open');
    }

    function open() {
      root.classList.add('pf-cat-picker-open');
      search.value = '';
      render('');
      setTimeout(() => search.focus(), 0);
    }

    function select(cat) {
      hidden.value = String(cat.id);
      labelEl.textContent = cat.label;
      labelEl.classList.remove('text-slate-400');
      labelEl.classList.add('text-slate-800');
      close();
      hidden.dispatchEvent(new Event('change', { bubbles: true }));
    }

    function render(filter) {
      const q = normalize(filter);
      list.innerHTML = '';
      const matches = cats.filter((c) => !q || normalize(c.label).includes(q));
      if (matches.length === 0) {
        const empty = document.createElement('li');
        empty.className = 'pf-cat-picker-empty px-3 py-2 text-sm text-slate-500';
        empty.textContent = cats.length === 0
          ? 'Aucune catégorie — créez-en une dans Catégories'
          : 'Aucune catégorie trouvée';
        list.appendChild(empty);
        return;
      }
      matches.forEach((c) => {
        const li = document.createElement('li');
        li.className = 'pf-cat-picker-option';
        li.setAttribute('role', 'option');
        li.textContent = c.label;
        li.addEventListener('click', () => select(c));
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
        const first = list.querySelector('.pf-cat-picker-option');
        if (first) first.click();
      }
    });

    document.addEventListener('click', (e) => {
      if (!root.contains(e.target)) close();
    });

    const api = {
      setValue(id) {
        const cat = cats.find((c) => String(c.id) === String(id));
        if (cat) select(cat);
        else {
          hidden.value = id ? String(id) : '';
          labelEl.textContent = id ? 'Catégorie #' + id : 'Choisir une catégorie…';
        }
      },
      getValue() {
        return hidden.value;
      },
      validate() {
        if (!hidden.value) {
          labelEl.classList.add('text-red-600');
          open();
          return false;
        }
        return true;
      },
    };

    pickers.set(root, api);
    return api;
  }

  function initAll(categories) {
    document.querySelectorAll('.pf-category-picker').forEach((el) => mount(el, categories));
  }

  global.PfCategoryPicker = { mount, initAll };
})(window);
