/**
 * PayFlex Admin — navigation mobile, utilitaires UI partagés.
 */
(() => {
  const sidebar = document.getElementById('pf-admin-sidebar');
  const overlay = document.getElementById('pf-nav-overlay');
  const toggle = document.getElementById('pf-nav-toggle');
  const closeBtn = document.getElementById('pf-nav-close');
  const collapseBtn = document.getElementById('pf-sidebar-collapse-toggle');
  const COLLAPSED_KEY = 'pf-admin-sidebar-collapsed';

  const isDesktop = () => window.innerWidth >= 1024;

  function openNavMobile() {
    if (!sidebar) return;
    sidebar.classList.remove('-translate-x-full');
    sidebar.classList.add('translate-x-0');
    overlay?.classList.remove('hidden');
    document.body.classList.add('overflow-hidden', 'lg:overflow-auto');
  }

  function closeNavMobile() {
    if (!sidebar) return;
    sidebar.classList.add('-translate-x-full');
    sidebar.classList.remove('translate-x-0');
    overlay?.classList.add('hidden');
    document.body.classList.remove('overflow-hidden');
  }

  function setSidebarCollapsed(collapsed) {
    document.body.classList.toggle('pf-sidebar-collapsed', collapsed);
    if (collapseBtn) {
      const icon = collapseBtn.querySelector('i');
      if (icon) {
        icon.className = collapsed ? 'fa-solid fa-chevron-right' : 'fa-solid fa-chevron-left';
      }
      collapseBtn.setAttribute('aria-label', collapsed ? 'Étendre le menu' : 'Réduire le menu');
      collapseBtn.setAttribute('title', collapsed ? 'Étendre le menu' : 'Réduire le menu');
    }
    if (isDesktop()) {
      try {
        localStorage.setItem(COLLAPSED_KEY, collapsed ? '1' : '0');
      } catch (_) {
        /* ignore */
      }
    }
  }

  function toggleSidebarDesktop() {
    setSidebarCollapsed(!document.body.classList.contains('pf-sidebar-collapsed'));
  }

  toggle?.addEventListener('click', () => {
    if (isDesktop()) {
      toggleSidebarDesktop();
      return;
    }
    openNavMobile();
  });

  closeBtn?.addEventListener('click', closeNavMobile);
  overlay?.addEventListener('click', closeNavMobile);

  collapseBtn?.addEventListener('click', toggleSidebarDesktop);

  window.addEventListener('resize', () => {
    if (isDesktop()) {
      closeNavMobile();
    } else {
      document.body.classList.remove('pf-sidebar-collapsed');
    }
  });

  if (document.body.classList.contains('pf-admin') && isDesktop()) {
    try {
      if (localStorage.getItem(COLLAPSED_KEY) === '1') {
        setSidebarCollapsed(true);
      }
    } catch (_) {
      /* ignore */
    }
  }

  /**
   * Confirmation SweetAlert avant envoi d'un formulaire (remplace window.confirm).
   * @param {Event} event
   * @param {string|object} opts - texte simple ou { title, text, html, icon, confirmButtonText, cancelButtonText }
   */
  window.pfConfirmSubmit = function pfConfirmSubmit(event, opts) {
    event.preventDefault();
    const form = event.target;
    const o = typeof opts === 'string' ? { text: opts } : opts || {};
    const title = o.title || 'Confirmation';
    const text = o.text || 'Confirmer cette action ?';
    const html = o.html;
    const icon = o.icon || 'question';
    const confirmButtonText = o.confirmButtonText || 'Confirmer';
    const cancelButtonText = o.cancelButtonText || 'Annuler';
    if (typeof Swal === 'undefined') {
      if (window.confirm(text)) form.submit();
      return false;
    }
    Swal.fire({
      icon,
      title,
      text: html ? undefined : text,
      html,
      showCancelButton: true,
      confirmButtonText,
      cancelButtonText,
      confirmButtonColor: o.confirmButtonColor || 'var(--pf-admin-blue, #1d4ed8)',
      cancelButtonColor: '#64748b',
      reverseButtons: true,
      focusCancel: true,
    }).then((r) => {
      if (r.isConfirmed) form.submit();
    });
    return false;
  };

  window.pfConfirmDelete = function pfConfirmDelete(event, text) {
    return window.pfConfirmDeleteWithReason(event, text, false);
  };

  window.pfConfirmDeleteWithReason = function pfConfirmDeleteWithReason(event, text, _legacyRequiresReason) {
    event.preventDefault();
    const form = event.target;
    const adminFull = !!(
      document.querySelector('[data-admin-full="true"]')
      || document.querySelector('[data-admin-full=true]')
    );
    const gestionnaire = !!(
      document.querySelector('[data-admin-gestionnaire="true"]')
      || document.querySelector('[data-admin-gestionnaire=true]')
    );
    // Admin principal : simple confirmation. Gestionnaire : motif obligatoire + validation admin.
    const needReason = gestionnaire && !adminFull;
    if (typeof Swal === 'undefined') {
      if (!needReason && window.confirm(text)) form.submit();
      return false;
    }
    if (!needReason) {
      Swal.fire({
        icon: 'warning',
        title: 'Confirmation',
        text,
        showCancelButton: true,
        confirmButtonText: 'Oui, supprimer',
        cancelButtonText: 'Annuler',
      }).then((r) => {
        if (r.isConfirmed) form.submit();
      });
      return false;
    }
    Swal.fire({
      icon: 'warning',
      title: 'Demande de suppression',
      html:
        '<p class="text-sm text-slate-600 mb-3">' +
        text +
        '</p><p class="text-xs text-amber-800 mb-2">La suppression sera définitive seulement après validation de l\'administrateur principal.</p>' +
        '<textarea id="pf-del-reason" class="swal2-textarea w-full" rows="3" placeholder="Motif obligatoire (min. 5 caractères)…"></textarea>',
      showCancelButton: true,
      confirmButtonText: 'Envoyer la demande',
      cancelButtonText: 'Annuler',
      preConfirm: () => {
        const v = document.getElementById('pf-del-reason')?.value?.trim() || '';
        if (v.length < 5) {
          Swal.showValidationMessage('Indiquez un motif d\'au moins 5 caractères.');
          return false;
        }
        return v;
      },
    }).then((r) => {
      if (!r.isConfirmed) return;
      let input = form.querySelector('input[name="reason"]');
      if (!input) {
        input = document.createElement('input');
        input.type = 'hidden';
        input.name = 'reason';
        form.appendChild(input);
      }
      input.value = r.value;
      form.submit();
    });
    return false;
  };

  function pfShowAdhesionUrgencyAlert() {
    const grid = document.querySelector('[data-adhesion-urgencies]');
    if (!grid || typeof Swal === 'undefined') return;
    const count = parseInt(grid.getAttribute('data-adhesion-urgencies') || '0', 10);
    if (!count || count < 1) return;
    const key = 'pf_adhesion_urgency_shown';
    const last = sessionStorage.getItem(key);
    const now = Date.now();
    if (last && now - parseInt(last, 10) < 120000) return;
    sessionStorage.setItem(key, String(now));
    Swal.fire({
      icon: 'error',
      title: 'Urgence adhésion',
      html:
        '<p class="text-sm"><strong>' +
        count +
        '</strong> signalement(s) : client(s) ayant payé 250 FCFA en espèces sans passage au statut <em>Adhérent</em>.</p>',
      confirmButtonText: 'Voir les clients',
      showCancelButton: true,
      cancelButtonText: 'Plus tard',
      customClass: { popup: 'pf-swal-urgence-adhesion' },
      allowOutsideClick: false,
    }).then((r) => {
      if (r.isConfirmed) {
        window.location.href = '/admin/clients?adhesion=dispute';
      }
    });
  }

  document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('form.pf-confirm-submit').forEach((form) => {
      form.addEventListener('submit', (event) => {
        pfConfirmSubmit(event, {
          title: form.dataset.confirmTitle || 'Confirmation',
          text: form.dataset.confirmText || 'Confirmer cette action ?',
          icon: form.dataset.confirmIcon || 'question',
          confirmButtonText: form.dataset.confirmYes || 'Confirmer',
          cancelButtonText: form.dataset.confirmNo || 'Annuler',
        });
      });
    });

    pfShowAdhesionUrgencyAlert();
    const root = document.querySelector('[data-admin-gestionnaire="true"]')
      || document.querySelector('[data-admin-gestionnaire=true]');
    if (!root) return;
    document.querySelectorAll('form.pf-track-change').forEach((form) => {
      form.addEventListener('submit', (e) => {
        const ta = form.querySelector('textarea[name="changeReason"]');
        if (!ta) return;
        if (ta.value.trim().length < 5) {
          e.preventDefault();
          if (typeof Swal !== 'undefined') {
            Swal.fire({
              icon: 'warning',
              title: 'Motif requis',
              text: 'En tant que gestionnaire, indiquez pourquoi vous modifiez (au moins 5 caractères).',
            });
          } else {
            alert('Motif de modification requis (min. 5 caractères).');
          }
        }
      });
    });
  });

  window.pfFlashFromParams = function pfFlashFromParams(map) {
    if (typeof Swal === 'undefined' || !map) return;
    if (map.success) {
      Swal.fire({
        icon: 'success',
        title: 'Action réussie',
        text: map.successText || 'Mise à jour effectuée.',
        timer: map.successTimer || 1800,
        showConfirmButton: false,
      });
    }
    if (map.error) {
      Swal.fire({
        icon: 'error',
        title: map.errorTitle || 'Action impossible',
        text: map.errorText || 'Vérifiez les informations saisies.',
      });
    }
    if (map.forbidden) {
      Swal.fire({
        icon: 'warning',
        title: 'Action réservée',
        text: map.forbidden,
      });
    }
  };

  function pfResolveCsrf() {
    const metaToken = document.querySelector('meta[name="_csrf"]');
    const metaParam = document.querySelector('meta[name="_csrf_parameter"]');
    if (metaToken && metaToken.content) {
      return {
        name: (metaParam && metaParam.content) || '_csrf',
        token: metaToken.content,
      };
    }
    const input = document.querySelector('input[name="_csrf"]');
    if (input && input.value) {
      return { name: input.name || '_csrf', token: input.value };
    }
    return null;
  }

  async function pfAskAdminPassword() {
    if (typeof Swal !== 'undefined') {
      const result = await Swal.fire({
        title: 'Mot de passe administrateur',
        input: 'password',
        inputLabel: 'Confirmez votre identité pour afficher les accès client',
        inputAttributes: { autocapitalize: 'off', autocorrect: 'off', autocomplete: 'current-password' },
        showCancelButton: true,
        confirmButtonText: 'Afficher',
        cancelButtonText: 'Annuler',
        inputValidator: (value) => {
          if (!value || !String(value).trim()) {
            return 'Saisissez votre mot de passe administrateur.';
          }
          return undefined;
        },
      });
      if (!result.isConfirmed) return null;
      return String(result.value || '').trim();
    }
    const fallback = window.prompt('Mot de passe administrateur :');
    return fallback && fallback.trim() ? fallback.trim() : null;
  }

  window.pfAdminRevealClientCredential = async function pfAdminRevealClientCredential(clientId, field) {
    const cid = Number(clientId);
    if (!cid || cid <= 0) {
      if (typeof Swal !== 'undefined') {
        Swal.fire({ icon: 'error', title: 'Erreur', text: 'Client introuvable sur cette fiche.' });
      }
      return;
    }
    const csrf = pfResolveCsrf();
    if (!csrf || !csrf.token) {
      if (typeof Swal !== 'undefined') {
        Swal.fire({
          icon: 'error',
          title: 'Session expirée',
          text: 'Rechargez la page puis réessayez.',
        });
      }
      return;
    }
    const adminPassword = await pfAskAdminPassword();
    if (!adminPassword) return;

    const body = new URLSearchParams();
    body.set(csrf.name, csrf.token);
    body.set('adminPassword', adminPassword);

    try {
      const res = await fetch('/admin/clients/' + cid + '/credentials/reveal', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          Accept: 'application/json',
        },
        credentials: 'same-origin',
        body: body.toString(),
      });
      let data = {};
      const contentType = res.headers.get('content-type') || '';
      const raw = await res.text();
      if (contentType.includes('application/json')) {
        try {
          data = raw ? JSON.parse(raw) : {};
        } catch (parseErr) {
          throw new Error('Réponse JSON invalide du serveur.');
        }
      } else if (raw.trim().startsWith('<')) {
        throw new Error(
          res.status === 403
            ? 'Accès refusé. Rechargez la page ou reconnectez-vous.'
            : 'Le serveur a renvoyé une page HTML au lieu des identifiants. Rechargez la page puis réessayez.'
        );
      } else if (!res.ok) {
        throw new Error('Réponse serveur invalide (' + res.status + ').');
      }
      if (!res.ok || data.error) {
        if (typeof Swal !== 'undefined') {
          Swal.fire({
            icon: 'error',
            title: 'Accès refusé',
            text: data.error || 'Mot de passe administrateur incorrect ou session expirée.',
          });
        }
        return;
      }
      const pinEl = document.getElementById('pfCredPin');
      const passEl = document.getElementById('pfCredPassword');
      const pinValue = data.pin && data.pin !== '—' ? data.pin : '—';
      const passValue = data.accountPassword && data.accountPassword !== '—' ? data.accountPassword : '—';
      if (field === 'pin' || field === 'accountPassword') {
        if (field === 'pin' && pinEl) pinEl.textContent = pinValue;
        if (field === 'accountPassword' && passEl) passEl.textContent = passValue;
      } else {
        if (pinEl) pinEl.textContent = pinValue;
        if (passEl) passEl.textContent = passValue;
      }
      const hint = field === 'pin' ? data.pinHint : data.passwordHint;
      if (hint && typeof Swal !== 'undefined') {
        Swal.fire({ icon: 'info', title: 'Identifiant non archivé', text: hint });
      }
      if (field === 'pin' && pinEl) pinEl.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
      if (field === 'accountPassword' && passEl) passEl.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    } catch (err) {
      if (typeof Swal !== 'undefined') {
        Swal.fire({
          icon: 'error',
          title: 'Échec',
          text: err && err.message ? err.message : 'Impossible d’afficher les identifiants.',
        });
      }
    }
  };

  function pfBindCredentialRevealButtons() {
    document.querySelectorAll('[data-pf-reveal-cred]').forEach((btn) => {
      if (btn.dataset.pfRevealBound === '1') return;
      btn.dataset.pfRevealBound = '1';
      btn.addEventListener('click', (ev) => {
        ev.preventDefault();
        const clientId = btn.getAttribute('data-pf-client-id');
        const field = btn.getAttribute('data-pf-reveal-cred');
        if (typeof window.pfAdminRevealClientCredential === 'function') {
          window.pfAdminRevealClientCredential(clientId, field);
        }
      });
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', pfBindCredentialRevealButtons);
  } else {
    pfBindCredentialRevealButtons();
  }
})();
