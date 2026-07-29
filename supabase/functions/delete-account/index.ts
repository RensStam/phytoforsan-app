// =====================================================================
// PhytoForsan — account verwijderen (Supabase Edge Function)
//
// Aanroep: vanuit de app, ingelogd (Authorization: Bearer <user-jwt>).
// Verwijdert het account van de INGELOGDE gebruiker en al zijn persoons-
// gegevens. Betaalregels blijven bewaard voor de administratie; hun NAW komt
// er als snapshot op te staan zodat de factuur compleet blijft.
//
// Wat er gebeurt:
//   1. factuurgegevens (naam/adres/e-mail) uit het profiel kopiëren naar de
//      betaalregels van deze gebruiker (billing_* kolommen, zie delete-account.sql);
//   2. user_entitlements van de gebruiker verwijderen (geen FK-cascade);
//   3. de auth-gebruiker verwijderen → cascadeert profiel, user_state, user_access.
//
// Vereist: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY (worden automatisch meegegeven).
// =====================================================================
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, apikey, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const authHeader = req.headers.get("Authorization") || "";
  const jwt = authHeader.replace(/^Bearer\s+/i, "");
  if (!jwt) return json({ error: "login_vereist" }, 401);

  // 1) Ingelogde gebruiker vaststellen aan de hand van het meegestuurde JWT.
  const authClient = createClient(url, serviceKey, { global: { headers: { Authorization: authHeader } } });
  const { data: userData, error: userErr } = await authClient.auth.getUser(jwt);
  const user = userData?.user;
  if (userErr || !user) return json({ error: "login_vereist" }, 401);

  // Aparte service-role client zónder user-header: volledige rechten voor de
  // privileged bewerkingen (snapshot, verwijderen, auth-user wissen).
  const admin = createClient(url, serviceKey);

  try {
    // 2) Factuur-snapshot: NAW uit het profiel naar de betaalregels kopiëren,
    //    zodat de administratie compleet blijft nadat het profiel verdwijnt.
    const { data: prof } = await admin.from("profiles")
      .select("first_name,last_name,street,house_number,postal_code,city,country")
      .eq("id", user.id).maybeSingle();
    if (prof) {
      const billingName = [prof.first_name, prof.last_name].filter(Boolean).join(" ").trim();
      const billingAddress = [
        [prof.street, prof.house_number].filter(Boolean).join(" ").trim(),
        [prof.postal_code, prof.city].filter(Boolean).join(" ").trim(),
        prof.country,
      ].filter((v) => v && String(v).trim() !== "").join(", ");
      await admin.from("payment_records").update({
        billing_name: billingName || null,
        billing_address: billingAddress || null,
        billing_email: user.email || null,
        billing_snapshot_at: new Date().toISOString(),
      }).eq("user_id", user.id);
    }

    // 3) Rechten van de gebruiker verwijderen (geen FK-cascade op user_entitlements).
    await admin.from("user_entitlements").delete().eq("user_id", user.id);

    // 4) Auth-gebruiker verwijderen → cascadeert profiel, user_state en user_access.
    const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
    if (delErr) {
      console.error("deleteUser mislukt:", delErr);
      return json({ error: "delete_failed", detail: delErr.message }, 500);
    }

    return json({ ok: true });
  } catch (e) {
    console.error("delete-account fout:", e);
    return json({ error: "server", detail: String(e?.message || e) }, 500);
  }
});
