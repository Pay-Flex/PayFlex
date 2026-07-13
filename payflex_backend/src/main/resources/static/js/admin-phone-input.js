/**
 * Champs téléphone admin : drapeaux + indicatif pays (Togo par défaut).
 * Marquer les inputs avec la classe {@code pf-intl-phone}.
 */
(() => {
  const instances = new WeakMap();

  function initPhoneInputs(root) {
    if (!window.intlTelInput) return;
    const scope = root || document;
    scope.querySelectorAll('input.pf-intl-phone').forEach((input) => {
      if (instances.has(input)) return;
      const iti = window.intlTelInput(input, {
        initialCountry: 'tg',
        preferredCountries: ['tg', 'bj', 'ci', 'gh', 'sn', 'fr'],
        separateDialCode: true,
        nationalMode: true,
        autoPlaceholder: 'aggressive',
        formatOnDisplay: true,
      });
      instances.set(input, iti);
      const raw = (input.value || '').trim();
      if (raw) {
        try {
          iti.setNumber(raw);
        } catch (_) {
          /* valeur locale sans indicatif */
        }
      }
    });
  }

  function bindForms(root) {
    const scope = root || document;
    scope.querySelectorAll('form').forEach((form) => {
      if (form.dataset.pfPhoneBound === '1') return;
      if (!form.querySelector('input.pf-intl-phone')) return;
      form.dataset.pfPhoneBound = '1';
      form.addEventListener('submit', () => {
        form.querySelectorAll('input.pf-intl-phone').forEach((input) => {
          const iti = instances.get(input);
          if (!iti) return;
          const e164 = iti.getNumber();
          if (e164) {
            input.value = e164;
          }
        });
      });
    });
  }

  function boot(root) {
    initPhoneInputs(root);
    bindForms(root);
  }

  window.pfSetAdminPhoneNumber = function (inputEl, raw) {
    if (!inputEl) return;
    let iti = instances.get(inputEl);
    if (!iti && window.intlTelInput) {
      initPhoneInputs(inputEl.closest('form') || document);
      iti = instances.get(inputEl);
    }
    const v = (raw || '').trim();
    if (iti && v) {
      try {
        iti.setNumber(v);
      } catch (_) {
        inputEl.value = v;
      }
    } else {
      inputEl.value = v;
    }
  };

  document.addEventListener('DOMContentLoaded', () => boot(document));
  window.pfInitAdminPhoneInputs = boot;
})();
