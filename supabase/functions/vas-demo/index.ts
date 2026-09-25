/// Lightweight HTML landing for telcos while Flutter `/vas` is loading.
/// Prefer sending reviewers to: https://myleadershipquest.app/vas?demo=1
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const PORTAL =
  Deno.env.get("MLQ_VAS_PORTAL_URL") ??
  "https://myleadershipquest.app/vas?demo=1";

Deno.serve((req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>MLQ · Shortcode 7089 Demo</title>
  <style>
    body{margin:0;font-family:system-ui,-apple-system,Segoe UI,sans-serif;background:#faf7fb;color:#1f1a22}
    .wrap{max-width:520px;margin:0 auto;padding:32px 20px}
    h1{color:#9D0389;font-size:28px;margin:0 0 8px}
    .card{background:#fff;border-radius:16px;padding:20px;box-shadow:0 8px 24px rgba(0,0,0,.06);margin:16px 0}
    .muted{color:#5c5560;line-height:1.5;font-size:14px}
    a.btn{display:block;text-align:center;background:#9D0389;color:#fff;text-decoration:none;padding:14px 16px;border-radius:12px;font-weight:700;margin-top:20px}
    .pill{display:inline-block;background:#f8eaf5;color:#9D0389;font-size:12px;font-weight:700;padding:4px 10px;border-radius:999px}
    ul{padding-left:18px;margin:8px 0;color:#5c5560;font-size:14px;line-height:1.5}
  </style>
</head>
<body>
  <div class="wrap">
    <span class="pill">Demo · billing not active</span>
    <h1>My Leadership Quest</h1>
    <p class="muted">Telco VAS preview for Shortcode <strong>7089</strong> · ₦100/day airtime.</p>
    <div class="card">
      <strong>User journey</strong>
      <ul>
        <li>Opt in: text <strong>MLQ</strong> to 7089</li>
        <li>Daily SMS with a leadership prompt + link</li>
        <li>Create a profile → Goals, Gratitude, global leaderboard</li>
        <li>Other features: visible, upgrade to full MLQ</li>
        <li>Victory Wall: schools &amp; registered communities only</li>
      </ul>
    </div>
    <a class="btn" href="${PORTAL}">Open interactive demo</a>
    <p class="muted" style="margin-top:16px;font-size:12px;text-align:center">Opens the branded portal at myleadershipquest.app/vas</p>
  </div>
</body>
</html>`;

  return new Response(html, {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
});
