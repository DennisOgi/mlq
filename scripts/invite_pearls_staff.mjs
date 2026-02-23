// Minimal Node script to bulk invite staff to Pearls Garden via Supabase RPC
// Usage (PowerShell):
//   $env:SUPABASE_URL = "https://hcvyumbkonrisrxbjnst.supabase.co"
//   $env:SERVICE_ROLE_KEY = "<YOUR_SERVICE_ROLE_KEY>"
//   node scripts/invite_pearls_staff.mjs

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error("Missing SUPABASE_URL or SERVICE_ROLE_KEY env vars.");
  process.exit(1);
}

// Pearls Garden org ID discovered from DB
const ORG_ID = "21221ec1-9390-4760-bfb1-818f929b94e1";

// Staff emails to invite
const emails = [
  "pearlsgardenschool@gmail.com",
  "o.anitae@pearlsgardenhub.africa",
  "grace.d@pearlsgardenhub.africa",
  "precious.e@pearlsgardenhub.africa",
  "victory.u@pearlsgardenhub.africa",
  "mary.a@pearlsgardenhub.africa",
  "precious.i@pearlsgardenhub.africa",
  "olufemi.a@pearlsgardenhub.africa",
  // Provided address has a likely typo (perals vs pearls); keeping exactly as provided
  "deborah.a@peralsgardenhub.africa",
  "chinwendu.i@pearlsgardenhub.africa",
  "paul.n@pearlsgardenhub.africa",
];

async function main() {
  try {
    const url = `${SUPABASE_URL}/rest/v1/rpc/admin_bulk_invite`;
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": `Bearer ${SERVICE_ROLE_KEY}`,
      },
      body: JSON.stringify({
        p_organization_id: ORG_ID,
        p_emails: emails,
      }),
    });

    const text = await res.text();
    let json;
    try { json = JSON.parse(text); } catch { json = text; }

    if (!res.ok) {
      console.error("Failed to invite:", res.status, json);
      process.exit(2);
    }

    console.log("✅ Invite call succeeded.");
    console.log(JSON.stringify(json, null, 2));
    if (json && json.invitations && Array.isArray(json.invitations)) {
      console.log("\nInvitation codes:");
      json.invitations.forEach((i, idx) => {
        console.log(`${idx + 1}. email=${i.email ?? "?"} code=${i.code ?? "?"}`);
      });
    }
  } catch (e) {
    console.error("Error:", e);
    process.exit(3);
  }
}

main();
