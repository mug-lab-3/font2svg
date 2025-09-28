importScripts('./version.js');

const version = self.version;
const PRECACHE_NAME  = `precache-${version}`;
const FONT_CACHE_NAME = `fontcache-${version}`;
const BASE_PATH = new URL('./', self.location).pathname.replace(/\/$/, '');
const PRECACHE_URLS  = [
  `${BASE_PATH}/index.html`,
  `${BASE_PATH}/manifest.webmanifest`,
  `${BASE_PATH}/version.js`,
  `${BASE_PATH}/assets/favicon-32.png`,
  `${BASE_PATH}/assets/favicon-64.png`,
  `${BASE_PATH}/assets/favicon-128.png`,
  `${BASE_PATH}/assets/favicon-192.png`,
  `${BASE_PATH}/assets/favicon-256.png`,
  `${BASE_PATH}/assets/favicon-512.png`,
  'https://cdn.jsdelivr.net/npm/opentype.js@1.3.4/dist/opentype.min.js',
  'https://cdn.jsdelivr.net/npm/jszip@3.10.1/dist/jszip.min.js',
  'https://unavatar.io/github/mug-lab-3'
];
// ===============================================================

// install: pre-cache assets and activate new worker immediately
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(PRECACHE_NAME)
      .then(c => c.addAll(PRECACHE_URLS))
      .then(() => self.skipWaiting())
  );
});

// activate: 古いプレキャッシュは全削除（無限増殖を防止）
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(
      names
        .filter(n => (
          (n.startsWith('precache-') && n !== PRECACHE_NAME) ||
          (n.startsWith('fontcache-') && n !== FONT_CACHE_NAME)
        ))
        .map(n => caches.delete(n))
    );
    await self.clients.claim();
  })());
});


self.addEventListener('fetch', (event) => {
  const req = event.request;
  const url = new URL(req.url);

  // HTML
  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(req).then(res => {
        const copy = res.clone();
        caches.open(PRECACHE_NAME).then(c => c.put(`${BASE_PATH}/index.html`, copy));
        return res;
      }).catch(() => caches.match(`${BASE_PATH}/index.html`) /* オフライン時フォールバック */)
    );
    return;
  }

  // Google Fonts をキャッシュ
  if (url.origin === 'https://fonts.googleapis.com' || url.origin === 'https://fonts.gstatic.com') {
    event.respondWith(
      caches.open(FONT_CACHE_NAME).then(cache =>
        cache.match(req).then(cached => {
          const fetchPromise = fetch(req).then(res => {
            cache.put(req, res.clone());
            return res;
          });
          return cached || fetchPromise;
        })
      )
    );
    return;
  }

  // プレキャッシュ対象だけキャッシュ優先
  if (PRECACHE_URLS.includes(req.url) || PRECACHE_URLS.includes(url.pathname)) {
    event.respondWith(
      caches.match(req).then(cached => cached || fetch(req))
    );
  }
  // それ以外は素通り（保存しない）
});
