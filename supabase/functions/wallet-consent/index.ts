// LeadWallet parent consent: send activation email + handle approve/reject links
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const FROM_EMAIL = Deno.env.get("REPORTS_FROM_EMAIL") ?? "noreply@myleadershipquest.app";
const POSTMARK_TOKEN = Deno.env.get("POSTMARK_SERVER_TOKEN");
const APP_URL = Deno.env.get("MLQ_APP_URL") ?? "https://myleadershipquest.app";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function htmlPage(title: string, body: string) {
  return `<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title>
  <style>body{font-family:Arial,sans-serif;background:#f5f7fa;margin:0;padding:24px}.card{max-width:520px;margin:40px auto;background:#fff;border-radius:16px;padding:32px;box-shadow:0 8px 24px rgba(0,0,0,.08)}h1{color:#1a365d;margin:0 0 12px}p{color:#4a5568;line-height:1.6}.ok{color:#276749;font-size:48px}.err{color:#c53030;font-size:48px}</style></head><body><div class="card">${body}</div></body></html>`;
}

async function sendPostmark(to: string, subject: string, html: string) {
  if (!POSTMARK_TOKEN) throw new Error("POSTMARK_SERVER_TOKEN not configured");
  const res = await fetch("https://api.postmarkapp.com/email", {
    method: "POST",
    headers: {
      "X-Postmark-Server-Token": POSTMARK_TOKEN,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      From: FROM_EMAIL,
      To: to,
      Subject: subject,
      HtmlBody: html,
      MessageStream: Deno.env.get("POSTMARK_MESSAGE_STREAM") ?? "outbound",
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Postmark error: ${res.status} ${err}`);
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false },
  });

  try {
    const url = new URL(req.url);
    const token = url.searchParams.get("token");
    const action = url.searchParams.get("action");

    // Public GET: parent clicks approve/reject link in email
    if (req.method === "GET" && token && action) {
      const ip = req.headers.get("x-forwarded-for") ?? "unknown";
      const rpc =
        action === "approve"
          ? "approve_wallet_consent_by_token"
          : action === "reject"
          ? "reject_wallet_consent_by_token"
          : null;

      if (!rpc) {
        return new Response(htmlPage("Error", "<p>Invalid action.</p>"), {
          status: 400,
          headers: { "Content-Type": "text/html" },
        });
      }

      const { data, error } = await supabase.rpc(rpc, {
        p_token: token,
        p_ip_address: ip,
      });

      if (error || !data?.success) {
        return new Response(
          htmlPage(
            "Unable to Process",
            `<div class="err">✕</div><h1>Link expired or invalid</h1><p>${data?.error ?? error?.message ?? "Please ask your child to send a new activation request from the MLQ app."}</p>`,
          ),
          { status: 400, headers: { "Content-Type": "text/html" } },
        );
      }

      if (action === "approve") {
        return new Response(
          htmlPage(
            "LeadWallet Approved",
            `<div class="ok">✓</div><h1>LeadWallet activated</h1><p>You approved your child's LeadWallet on My Leadership Quest. They can now receive approved cash rewards and request withdrawals to a verified bank account.</p><p><a href="${APP_URL}">Open My Leadership Quest</a></p>`,
          ),
          { headers: { "Content-Type": "text/html" } },
        );
      }

      return new Response(
        htmlPage(
          "Request Declined",
          `<h1>Activation declined</h1><p>The LeadWallet activation request was declined. Your child can submit a new request from the app when ready.</p>`,
        ),
        { headers: { "Content-Type": "text/html" } },
      );
    }

    // Authenticated POST: student requests activation email
    if (req.method === "POST") {
      const authHeader = req.headers.get("Authorization");
      if (!authHeader) {
        return new Response(JSON.stringify({ error: "Unauthorized" }), {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const userClient = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_ANON_KEY")!, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data: userData, error: userErr } = await userClient.auth.getUser();
      if (userErr || !userData.user) {
        return new Response(JSON.stringify({ error: "Unauthorized" }), {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const body = await req.json();
      const parentEmail = (body.parent_email as string)?.trim().toLowerCase();
      if (!parentEmail) {
        return new Response(JSON.stringify({ error: "parent_email required" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const { data: result, error: rpcErr } = await userClient.rpc(
        "request_wallet_activation",
        { p_parent_email: parentEmail },
      );

      if (rpcErr || !result?.success) {
        return new Response(
          JSON.stringify({ error: rpcErr?.message ?? "Failed to create consent" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      // Token is no longer returned by the RPC (student self-approve risk).
      // Load it server-side with the service role using consent_id.
      const consentId = result.consent_id as string;
      const studentName = result.student_name as string;
      const { data: consentRow, error: tokenErr } = await supabase
        .from("wallet_consent")
        .select("consent_token")
        .eq("id", consentId)
        .eq("consent_type", "wallet_activation")
        .eq("status", "pending")
        .maybeSingle();

      if (tokenErr || !consentRow?.consent_token) {
        return new Response(
          JSON.stringify({ error: "Consent created but email token unavailable" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const consentToken = consentRow.consent_token as string;
      const fnBase = `${SUPABASE_URL}/functions/v1/wallet-consent`;
      const approveUrl = `${fnBase}?token=${consentToken}&action=approve`;
      const rejectUrl = `${fnBase}?token=${consentToken}&action=reject`;

      const emailHtml = `
        <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto">
          <div style="background:#1a365d;padding:28px;border-radius:12px 12px 0 0;text-align:center">
            <h1 style="color:#fff;margin:0">My Leadership Quest</h1>
            <p style="color:#cbd5e0;margin:8px 0 0">LeadWallet activation request</p>
          </div>
          <div style="background:#fff;padding:28px;border:1px solid #e2e8f0;border-top:none;border-radius:0 0 12px 12px">
            <p>Hello,</p>
            <p><strong>${studentName}</strong> has requested to activate their <strong>LeadWallet</strong> — a rewards balance for earning real money through leadership goals and achievements on MLQ.</p>
            <p>By approving, you give one-time consent for LeadWallet. That means:</p>
            <ul>
              <li>Your child can receive approved cash rewards in their LeadWallet</li>
              <li>They can request withdrawals to a verified Nigerian bank account</li>
              <li>Each withdrawal is still reviewed by MLQ admin before payout</li>
            </ul>
            <p style="margin:28px 0">
              <a href="${approveUrl}" style="background:#276749;color:#fff;padding:14px 24px;border-radius:8px;text-decoration:none;font-weight:bold;margin-right:12px">Approve LeadWallet</a>
              <a href="${rejectUrl}" style="color:#c53030;text-decoration:none">Decline</a>
            </p>
            <p style="color:#718096;font-size:13px">This link expires in 7 days. MLQ stores rewards as an approved balance; withdrawals are processed via Flutterwave to your child's verified bank account.</p>
          </div>
        </div>`;

      await sendPostmark(
        parentEmail,
        `Approve ${studentName}'s LeadWallet — My Leadership Quest`,
        emailHtml,
      );

      return new Response(
        JSON.stringify({ success: true, parent_email: parentEmail }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(JSON.stringify({ hint: "POST to send email, GET ?token=&action=approve|reject" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("wallet-consent error:", e);
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
