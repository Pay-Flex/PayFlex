/* PayFlex — activation Web Push pour les postes admin / support.
   Gère : détection de support, bouton cloche, abonnement/désabonnement,
   enregistrement de l'abonnement côté backend. Dégrade proprement si le
   navigateur ne supporte pas le push ou si les clés VAPID ne sont pas configurées. */
(function () {
  'use strict';

  var CONFIG_URL = '/admin/web-push/config';
  var SUBSCRIBE_URL = '/admin/web-push/subscribe';
  var UNSUBSCRIBE_URL = '/admin/web-push/unsubscribe';
  var SW_URL = '/sw.js';

  var btn = document.getElementById('pf-push-bell');
  if (!btn) {
    return;
  }

  var supported = 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
  if (!supported) {
    btn.style.display = 'none';
    return;
  }

  var vapidPublicKey = null;
  var swRegistration = null;

  function urlBase64ToUint8Array(base64String) {
    var padding = '='.repeat((4 - (base64String.length % 4)) % 4);
    var base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
    var rawData = window.atob(base64);
    var outputArray = new Uint8Array(rawData.length);
    for (var i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  }

  function setBell(state) {
    // state: 'on' | 'off' | 'blocked' | 'unavailable'
    btn.setAttribute('data-push-state', state);
    var icon = btn.querySelector('i');
    if (state === 'on') {
      btn.title = 'Notifications activées — cliquez pour désactiver';
      if (icon) { icon.className = 'fa-solid fa-bell'; }
      btn.classList.add('pf-push-bell--on');
    } else if (state === 'blocked') {
      btn.title = 'Notifications bloquées par le navigateur (autorisez-les dans les paramètres du site)';
      if (icon) { icon.className = 'fa-solid fa-bell-slash'; }
      btn.classList.remove('pf-push-bell--on');
    } else if (state === 'unavailable') {
      btn.style.display = 'none';
    } else {
      btn.title = 'Activer les notifications sur ce poste';
      if (icon) { icon.className = 'fa-solid fa-bell-slash'; }
      btn.classList.remove('pf-push-bell--on');
    }
  }

  function postJson(url, body) {
    return fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'same-origin',
      body: JSON.stringify(body || {})
    });
  }

  function subscribe() {
    if (!vapidPublicKey || !swRegistration) {
      return;
    }
    if (Notification.permission === 'denied') {
      setBell('blocked');
      return;
    }
    Notification.requestPermission().then(function (permission) {
      if (permission !== 'granted') {
        setBell(permission === 'denied' ? 'blocked' : 'off');
        return;
      }
      swRegistration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(vapidPublicKey)
      }).then(function (sub) {
        var json = sub.toJSON();
        return postJson(SUBSCRIBE_URL, {
          endpoint: sub.endpoint,
          keys: { p256dh: json.keys.p256dh, auth: json.keys.auth }
        });
      }).then(function () {
        setBell('on');
      }).catch(function () {
        setBell('off');
      });
    });
  }

  function unsubscribe() {
    if (!swRegistration) {
      setBell('off');
      return;
    }
    swRegistration.pushManager.getSubscription().then(function (sub) {
      if (!sub) {
        setBell('off');
        return;
      }
      var endpoint = sub.endpoint;
      sub.unsubscribe().finally(function () {
        postJson(UNSUBSCRIBE_URL, { endpoint: endpoint }).finally(function () {
          setBell('off');
        });
      });
    });
  }

  function refreshState() {
    swRegistration.pushManager.getSubscription().then(function (sub) {
      if (sub && Notification.permission === 'granted') {
        setBell('on');
        // Re-synchronise l'abonnement côté serveur (au cas où purgé).
        var json = sub.toJSON();
        postJson(SUBSCRIBE_URL, {
          endpoint: sub.endpoint,
          keys: { p256dh: json.keys.p256dh, auth: json.keys.auth }
        });
      } else if (Notification.permission === 'denied') {
        setBell('blocked');
      } else {
        setBell('off');
      }
    });
  }

  btn.addEventListener('click', function () {
    var state = btn.getAttribute('data-push-state');
    if (state === 'on') {
      unsubscribe();
    } else if (state === 'blocked') {
      alert('Les notifications sont bloquées pour ce site. Autorisez-les dans les paramètres du navigateur (icône cadenas dans la barre d\'adresse).');
    } else {
      subscribe();
    }
  });

  fetch(CONFIG_URL, { credentials: 'same-origin' })
    .then(function (r) { return r.ok ? r.json() : null; })
    .then(function (cfg) {
      if (!cfg || !cfg.enabled || !cfg.publicKey) {
        // Web Push non configuré côté serveur : masquer la cloche.
        setBell('unavailable');
        return;
      }
      vapidPublicKey = cfg.publicKey;
      navigator.serviceWorker.register(SW_URL).then(function (reg) {
        swRegistration = reg;
        refreshState();
      }).catch(function () {
        setBell('unavailable');
      });
    })
    .catch(function () {
      setBell('unavailable');
    });
})();
