const CACHE = "relax-breathing-humming-v180";

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

// Afbeeldingen uit Supabase Storage (de protocoltegels) staan op een ander domein.
// Een gewoon <img>-verzoek is no-cors en levert een 'opaque' antwoord: status 0 —
// ook bij een fout — dus niet te valideren, en het blaast het cachequota op.
// Daarom halen we ze hier expliciet met CORS op: dan klopt de status wel en kunnen
// we ze veilig bewaren, zodat de tegels ook offline blijven werken.
function isStorageImage(req, url) {
  // Alleen <img>: audio bewust niet, want dat gebruikt Range-verzoeken om te
  // kunnen spoelen en die zouden hier sneuvelen.
  return req.destination === "image"
    && url.hostname.endsWith(".supabase.co")
    && url.pathname.includes("/storage/v1/object/public/");
}

// Stale-while-revalidate: meteen uit de cache tonen, op de achtergrond verversen.
async function storageImage(event, req) {
  const cache = await caches.open(CACHE);
  const cached = await cache.match(req.url);
  const fromNetwork = fetch(req.url, { mode: "cors", credentials: "omit" })
    .then(res => {
      const ct = res.headers.get("content-type") || "";
      if (res.status === 200 && ct.startsWith("image/")) {
        cache.put(req.url, res.clone()).catch(() => {});
      }
      return res;
    })
    .catch(() => null);
  if (cached) {
    event.waitUntil(fromNetwork);
    return cached;
  }
  return (await fromNetwork) || Response.error();
}

// Netwerk-eerst: altijd de actuele versie tonen wanneer online; offline terugvallen op cache.
// Dit voorkomt dat oude (gecachte) HTML/JS blijft draaien na een update.
self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (isStorageImage(req, url)) { e.respondWith(storageImage(e, req)); return; }
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
