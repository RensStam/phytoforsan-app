// =====================================================================
// PhytoForsan Relax — gedeelde configuratie (publieke app + admin)
// Vul je Supabase-gegevens in en zet APP_ENV op "local_supabase" of "production".
// Gebruik NOOIT de service-role key hier; alleen de anon key. Beveiliging via RLS.
// =====================================================================
window.APP_ENV = "local_mock"; // local_mock | local_supabase | production

window.CONFIG = {
  local_mock: {
    useBackend: false,
    supabaseUrl: "",
    supabaseAnonKey: ""
  },
  local_supabase: {
    useBackend: true,
    supabaseUrl: "VUL_SUPABASE_TEST_URL_IN",
    supabaseAnonKey: "VUL_SUPABASE_TEST_ANON_KEY_IN"
  },
  production: {
    useBackend: true,
    supabaseUrl: "VUL_SUPABASE_PRODUCTIE_URL_IN",
    supabaseAnonKey: "VUL_SUPABASE_PRODUCTIE_ANON_KEY_IN"
  }
};

window.getActiveConfig = function () {
  return window.CONFIG[window.APP_ENV] || window.CONFIG.local_mock;
};

// Maakt (indien geconfigureerd) een Supabase-client. Vereist dat de supabase-js
// CDN-bundel is geladen (window.supabase). Geeft null terug in local_mock.
window.createSupabaseClient = function () {
  const cfg = window.getActiveConfig();
  if (!cfg.useBackend) return null;
  if (!window.supabase || !cfg.supabaseUrl || cfg.supabaseUrl.startsWith("VUL_")) return null;
  try {
    return window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseAnonKey);
  } catch (e) {
    console.warn("Supabase-client kon niet worden aangemaakt:", e);
    return null;
  }
};
