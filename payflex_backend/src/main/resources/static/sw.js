/* PayFlex — Service Worker Web Push (postes admin / support).
   Servi à la racine (/sw.js) : scope « / » couvrant tout l'espace /admin.
   Reçoit les événements push même quand l'onglet est fermé (navigateur ouvert). */

self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('push', function (event) {
  var data = { title: 'PayFlex', body: '', url: '/admin' };
  if (event.data) {
    try {
      data = Object.assign(data, event.data.json());
    } catch (e) {
      data.body = event.data.text();
    }
  }
  var options = {
    body: data.body || '',
    icon: '/img/logo.png',
    badge: '/img/logo.png',
    tag: data.tag || 'payflex-admin',
    renotify: true,
    data: { url: data.url || '/admin' }
  };
  event.waitUntil(self.registration.showNotification(data.title || 'PayFlex', options));
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  var target = (event.notification.data && event.notification.data.url) || '/admin';
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (clientList) {
      for (var i = 0; i < clientList.length; i++) {
        var client = clientList[i];
        if ('focus' in client) {
          client.focus();
          if ('navigate' in client) {
            try { client.navigate(target); } catch (e) { /* ignore */ }
          }
          return;
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(target);
      }
    })
  );
});
