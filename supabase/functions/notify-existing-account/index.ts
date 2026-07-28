// =====================================================================
// PhytoForsan Relax — melding "je hebt al een account" (Supabase Edge Function)
//
// Aanroep: vanuit de app na een registratiepoging (Authorization: Bearer <anon-key>).
// Zelf checkt deze functie (met de service-role) of het e-mailadres al een
// account heeft (via public.email_has_account, zie existing-account-notify.sql).
// Zo niet: er gebeurt niets. Zo wel: er gaat een mail naar dat adres.
//
// Belangrijk: dit geeft altijd hetzelfde antwoord terug, ongeacht de uitkomst,
// zodat de aanroeper niet kan afleiden of het adres al bestond.
//
// Vereiste secrets (Supabase -> Edge Functions -> Secrets):
//   SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY worden automatisch meegegeven.
// =====================================================================
import { createClient } from "npm:@supabase/supabase-js@2";
import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

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

  let email = "";
  try {
    const body = await req.json();
    email = String(body?.email || "").trim().toLowerCase();
  } catch {
    return json({ ok: true }); // geen geldige body -> stilletjes niets doen
  }
  if (!email || !email.includes("@")) return json({ ok: true });

  const supabaseAdmin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: exists, error: rpcError } = await supabaseAdmin.rpc("email_has_account", { check_email: email });
  if (rpcError) {
    console.error("email_has_account mislukt:", rpcError);
    return json({ ok: true }); // faalt stil -- nooit meer info teruggeven dan nodig
  }

  if (exists) {
    try {
      await sendExistingAccountMail(email);
    } catch (e) {
      console.error("Versturen 'account bestaat al'-mail mislukt:", e);
    }
  }

  return json({ ok: true });
});

async function sendExistingAccountMail(email: string) {
  const client = new SMTPClient({
    connection: {
      hostname: Deno.env.get("SMTP_HOST")!,
      port: Number(Deno.env.get("SMTP_PORT") || "587"),
      tls: true,
      auth: {
        username: Deno.env.get("SMTP_USER")!,
        password: Deno.env.get("SMTP_PASS")!,
      },
    },
  });

  await client.send({
    from: Deno.env.get("SMTP_FROM") || "PhytoForsan Relax <noreply@phytoforsan.nl>",
    to: email,
    subject: "Je hebt al een account bij PhytoForsan Relax",
    content: "auto",
    html: `
      <p>Er is zojuist geprobeerd een nieuw account aan te maken met dit e-mailadres,
      maar je hebt al een account bij <strong>PhytoForsan Relax</strong>.</p>
      <p>Wachtwoord vergeten? Ga naar
      <a href="https://app.phytoforsan.nl">app.phytoforsan.nl</a> en klik op
      "Wachtwoord vergeten?".</p>
      <p>Heb jij dit zelf niet aangevraagd, dan kun je deze e-mail gewoon negeren.</p>
    `,
  });

  await client.close();
}
