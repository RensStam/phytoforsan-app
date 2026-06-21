// =====================================================================
// PhytoForsan Relax — gedeelde configuratie (app + backend)
//
// Vul hieronder je Supabase-gegevens in. DEZELFDE waarden gelden voor zowel
// de lokale versie als de live (deploy) versie — daardoor lezen/schrijven beide
// naar één gedeelde database en zijn wijzigingen overal hetzelfde.
//
// Gebruik NOOIT de service-role key hier; alleen de publieke "anon" key.
// Beveiliging loopt via Supabase RLS (zie supabase/schema.sql).
//
// Zolang deze velden leeg zijn (of met VUL_… beginnen) draait alles in
// lokale testmodus (browseropslag) en synchroniseert er niets tussen apparaten.
// =====================================================================
window.CONFIG = {
  supabaseUrl: "VUL_SUPABASE_URL_IN",        // bv. https://xxxx.supabase.co
  supabaseAnonKey: "VUL_SUPABASE_ANON_KEY_IN"
};

function _phytoConfigured() {
  const c = window.CONFIG || {};
  return !!(c.supabaseUrl && c.supabaseAnonKey && !/^VUL/i.test(c.supabaseUrl) && !/^VUL/i.test(c.supabaseAnonKey));
}

// Eén actieve configuratie. useBackend is automatisch waar zodra Supabase is ingevuld.
window.getActiveConfig = function () {
  return {
    useBackend: _phytoConfigured(),
    supabaseUrl: window.CONFIG.supabaseUrl,
    supabaseAnonKey: window.CONFIG.supabaseAnonKey
  };
};

// Label voor de badge in het backend ("supabase" of "mock").
window.APP_ENV = _phytoConfigured() ? "supabase" : "mock";

// Maakt (indien geconfigureerd) een Supabase-client. Vereist de supabase-js CDN.
// Geeft null terug in testmodus of als de gegevens ontbreken.
window.createSupabaseClient = function () {
  if (!_phytoConfigured()) return null;
  if (!window.supabase) return null;
  try {
    return window.supabase.createClient(window.CONFIG.supabaseUrl, window.CONFIG.supabaseAnonKey);
  } catch (e) {
    console.warn("Supabase-client kon niet worden aangemaakt:", e);
    return null;
  }
};
