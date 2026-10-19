// Offline support: serve the app shell from cache, refresh it in the background.
// Bump VERSION whenever you ship changes so every file updates together.
const VERSION = 'willist-v1';
const SHELL = [
  './', 'index.html', 'styles.css', 'manifest.webmanifest',
  'icons/icon.svg', 'icons/icon-192.png', 'icons/icon-512.png', 'icons/apple-touch-icon.png',
  'src/app.js', 'src/agenda.js', 'src/coach.js', 'src/components.js', 'src/dates.js', 'src/focus.js',
  'src/ics.js', 'src/parse.js', 'src/plan.js', 'src/reminders.js', 'src/sample.js', 'src/store.js', 'src/ui.js',
  'src/views/editor.js', 'src/views/goals.js', 'src/views/planview.js', 'src/views/radar.js',
  'src/views/today.js', 'src/views/tools.js',
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys()
    .then((keys) => Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET' || new URL(req.url).origin !== location.origin) return;
  e.respondWith(caches.open(VERSION).then(async (cache) => {
    const cached = await cache.match(req, { ignoreSearch: true });
    const network = fetch(req).then((res) => {
      if (res.ok) cache.put(req, res.clone());
      return res;
    }).catch(() => cached || cache.match('index.html'));
    return cached || network;
  }));
});

self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  e.waitUntil(self.clients.matchAll({ type: 'window' }).then((wins) => {
    const win = wins[0];
    return win ? win.focus() : self.clients.openWindow('./');
  }));
});
