const CACHE = "relax-breathing-humming-v161";

self.addEventListener("install", e => {
  // Niet automatisch skipWaiting: de nieuwe versie wacht tot de gebruiker
  // op "Herladen" klikt (zie de update-melding in de app).
});

// De app vraagt om over te schakelen naar de nieuwe versie.
self.addEventListener("message", e => {
  if (e.data === "skipWaiting") self.skipWaiting();
});

self.addEventListener("activate", e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(key => key !== CACHE).map(key => caches.delete(key))))
      .then(() => clients.claim())
  );
});

// Netwerk-eerst: altijd de actuele versie tonen wanneer online; offline terugvallen op cache.
// Dit voorkomt dat oude (gecachte) HTML/JS blijft draaien na een update.
self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  e.respondWith(
    fetch(req)
      .then(res => {
        if (res && res.status === 200 && (res.type === "basic" || res.type === "default")) {
          const copy = res.clone();
          caches.open(CACHE).then(c => c.put(req, copy)).catch(() => {});
        }
        return res;
      })
      .catch(() => caches.match(req).then(r => r || caches.match("/")))
  );
});
