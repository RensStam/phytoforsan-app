// =====================================================================
// PhytoForsan Relax Plus — Mollie betaling aanmaken (Supabase Edge Function)
//
// Aanroep: vanuit de app, ingelogd (Authorization: Bearer <user-jwt>).
// Maakt een Mollie-betaling aan voor 1 jaar Plus en geeft de checkout-URL
// terug. De geheime Mollie-key staat als function secret, nooit in de app.
//
// Vereiste secrets (Supabase → Edge Functions → Secrets):
//   MOLLIE_API_KEY   test_xxx of live_xxx
//   APP_URL          bv. https://rensstam.github.io/phytoforsan-app/deploy/
//   PLUS_PRICE_EUR   optioneel, standaard 29.95
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY worden automatisch meegegeven.
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

  const mollieKey = Deno.env.get("MOLLIE_API_KEY");
  const appUrl = (Deno.env.get("APP_URL") || "").replace(/\/+$/, "");
  if (!mollieKey || !appUrl) return json({ error: "server_config" }, 500);

  // Ingelogde gebruiker vaststellen via het meegestuurde JWT
  const authHeader = req.headers.get("Authorization") || "";
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const jwt = authHeader.replace(/^Bearer\s+/i, "");
  const { data: userData, error: userErr } = await supabase.auth.getUser(jwt);
  const user = userData?.user;
  if (userErr || !user) return json({ error: "login_vereist" }, 401);

  const price = (Deno.env.get("PLUS_PRICE_EUR") || "29.95").replace(",", ".");
  const amountValue = Number(price).toFixed(2);

  // Betaling aanmaken bij Mollie
  const mollieResp = await fetch("https://api.mollie.com/v2/payments", {
    method: "POST",
    headers: { Authorization: `Bearer ${mollieKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      amount: { currency: "EUR", value: amountValue },
      description: "PhytoForsan Relax Plus — 1 jaar toegang",
      redirectUrl: `${appUrl}/?plus=return`,
      webhookUrl: `${Deno.env.get("SUPABASE_URL")}/functions/v1/mollie-webhook`,
      metadata: { user_id: user.id, product_type: "relax_plus_year" },
    }),
  });
  const payment = await mollieResp.json();
  if (!mollieResp.ok || !payment?.id) {
    console.error("Mollie create mislukt:", payment);
    return json({ error: "mollie", detail: payment?.detail || "" }, 502);
  }

  // Betaalrecord vastleggen (controle + idempotentie voor de webhook)
  await supabase.from("payment_records").insert({
    user_id: user.id,
    provider: "mollie",
    provider_payment_id: payment.id,
    amount: amountValue,
    currency: "EUR",
    product_type: "relax_plus_year",
    status: "open",
  });

  return json({ checkoutUrl: payment._links?.checkout?.href, paymentId: payment.id });
});
