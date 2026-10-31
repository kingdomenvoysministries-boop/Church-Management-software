/* Church Care app-shell cache only. No runtime responses or personal data are stored. */
const CACHE_NAME = 'church-care-shell-v4';
const SCOPE_URL = new URL(self.registration.scope);
const SHELL_URLS = [
  new URL('./', SCOPE_URL).href,
  new URL('./manifest.webmanifest', SCOPE_URL).href,
  new URL('./church-care-icon-192.png', SCOPE_URL).href,
  new URL('./church-care-icon-512.png', SCOPE_URL).href
];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(SHELL_URLS)));
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(
      keys.filter((key) => key.startsWith('church-care-shell-') && key !== CACHE_NAME)
        .map((key) => caches.delete(key))
    )).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== SCOPE_URL.origin) return;

  // The app page itself is network-first so updates always arrive; the cached copy is only an offline fallback.
  if (url.href === new URL('./', SCOPE_URL).href) {
    event.respondWith(fetch(request).catch(() => caches.match(request)));
    return;
  }

  // The only cache-first resources are the fixed, public icon and manifest files.
  if (SHELL_URLS.includes(url.href)) {
    event.respondWith(caches.match(request).then((cached) => cached || fetch(request)));
    return;
  }

  // A navigation may use the cached shell offline, but its response is never cached.
  if (request.mode === 'navigate') {
    event.respondWith(fetch(request).catch(() => caches.match(new URL('./', SCOPE_URL).href)));
  }
});

// Tapping a notification opens the app on the Follow-Up page.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const page = (event.notification.data && event.notification.data.page) || 'followups';
  event.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
    for (const client of list) {
      if (client.url.startsWith(SCOPE_URL.origin)) {
        client.postMessage({ type: 'open-page', page });
        return client.focus();
      }
    }
    return self.clients.openWindow(new URL('./?page=' + page, SCOPE_URL).href);
  }));
});
