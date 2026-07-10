// =====================================================================
// PhytoForsan Relax Plus — Mollie webhook (Supabase Edge Function)
//
// Mollie stuurt hier alleen een payment-id naartoe; we vertrouwen de
// aanroep nooit blind maar halen de betaling zelf op bij Mollie.
// Verwerking is idempotent: dezelfde webhook twee keer geeft nooit
// twee keer toegang (processed_at op payment_records is de grendel).
//
// Belangrijk bij deployen: JWT-verificatie UIT voor deze functie
// (Mollie stuurt geen Supabase-JWT):
//   supabase functions deploy mollie-webhook --no-verify-jwt
//
// Vereiste secrets: MOLLIE_API_KEY (SUPABASE_URL/SERVICE_ROLE automatisch).
// =====================================================================
import { createClient } from "npm:@supabase/supabase-js@2";

const ok = () => new Response("OK", { status: 200 });

Deno.serve(async (req) => {
  if (req.method !== "POST") return ok();

  // Mollie stuurt application/x-www-form-urlencoded met id=tr_xxx
  let paymentId = "";
  try {
    const body = await req.text();
    paymentId = new URLSearchParams(body).get("id") || "";
  } catch { /* leeg laten */ }
  if (!paymentId) return ok();   // altijd 200, anders blijft Mollie herhalen

  const mollieKey = Deno.env.get("MOLLIE_API_KEY");
  if (!mollieKey) { console.error("MOLLIE_API_KEY ontbreekt"); return ok(); }

  // 1. Actuele betaling bij Mollie zelf ophalen (bron van waarheid)
  const resp = await fetch(`https://api.mollie.com/v2/payments/${encodeURIComponent(paymentId)}`, {
    headers: { Authorization: `Bearer ${mollieKey}` },
  });
  if (!resp.ok) { console.error("Mollie ophalen mislukt", resp.status); return ok(); }
  const payment = await resp.json();

  const userId = payment?.metadata?.user_id;
  const productType = payment?.metadata?.product_type || "relax_plus_year";
  const status = payment?.status || "unknown";

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // 2. Betaalrecord bijwerken (of aanmaken als het ontbreekt)
  const { data: record } = await supabase
    .from("payment_records")
    .select("*")
    .eq("provider_payment_id", payment.id)
    .maybeSingle();

  if (record) {
    await supabase.from("payment_records")
      .update({ status, updated_at: new Date().toISOString() })
      .eq("id", record.id);
  } else if (userId) {
    await supabase.from("payment_records").insert({
      user_id: userId,
      provider: "mollie",
      provider_payment_id: payment.id,
      amount: payment?.amount?.value || null,
      currency: payment?.amount?.currency || "EUR",
      product_type: productType,
      status,
    });
  }

  // 3. Alleen verwerken bij betaald + geldige metadata + nog niet verwerkt
  if (status !== "paid" || !userId) return ok();
  if (record?.processed_at) return ok();   // idempotent: al verwerkt

  // Verwerkingsgrendel claimen vóór het entitlement (voorkomt dubbele verwerking
  // bij twee gelijktijdige webhooks): alleen de aanroep die de rij van
  // processed_at=null naar nu bijwerkt, mag doorgaan.
  const { data: claimed } = await supabase
    .from("payment_records")
    .update({ processed_at: new Date().toISOString(), status: "paid", updated_at: new Date().toISOString() })
    .eq("provider_payment_id", payment.id)
    .is("processed_at", null)
    .select("id");
  if (!claimed || claimed.length === 0) return ok();   // ander proces was eerder

  // 4. Entitlement aanmaken; bij bestaande actieve Plus verlengen vanaf ends_at
  const { data: bestaand } = await supabase
    .from("user_entitlements")
    .select("ends_at")
    .eq("user_id", userId)
    .eq("entitlement_type", "premium")
    .eq("source", "mollie_payment")
    .eq("status", "active")
    .gt("ends_at", new Date().toISOString())
    .order("ends_at", { ascending: false })
    .limit(1);

  const start = (bestaand && bestaand[0]?.ends_at) ? new Date(bestaand[0].ends_at) : new Date();
  const einde = new Date(start);
  einde.setFullYear(einde.getFullYear() + 1);

  const { error: entErr } = await supabase.from("user_entitlements").insert({
    user_id: userId,
    entitlement_type: "premium",
    source: "mollie_payment",
    starts_at: start.toISOString(),
    ends_at: einde.toISOString(),
    status: "active",
    reference_id: payment.id,
  });
  if (entErr) {
    // Grendel terugdraaien zodat een volgende webhook het opnieuw kan proberen
    console.error("Entitlement aanmaken mislukt:", entErr);
    await supabase.from("payment_records")
      .update({ processed_at: null, updated_at: new Date().toISOString() })
      .eq("provider_payment_id", payment.id);
  }

  return ok();
});
