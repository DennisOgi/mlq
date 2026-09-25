import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const FLW_SECRET_KEY = Deno.env.get("FLW_SECRET_KEY");

type InitPayload = {
  tx_ref: string;
  amount: string | number;
  currency: string;
  redirect_url: string;
  email: string;
  name: string;
  phone_number?: string;
  payment_options?: string;
  meta?: Record<string, unknown>;
};

function isNonEmptyString(v: unknown): v is string {
  return typeof v === "string" && v.trim().length > 0;
}

Deno.serve(async (req: Request) => {
  try {
    if (!FLW_SECRET_KEY) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "FLW_SECRET_KEY not configured",
        }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    const payload = (await req.json()) as Partial<InitPayload>;

    if (!isNonEmptyString(payload.tx_ref)) throw new Error("missing_tx_ref");
    if (!isNonEmptyString(payload.currency)) throw new Error("missing_currency");
    if (!isNonEmptyString(payload.redirect_url)) {
      throw new Error("missing_redirect_url");
    }
    if (!isNonEmptyString(payload.email)) throw new Error("missing_email");
    if (!isNonEmptyString(payload.name)) throw new Error("missing_name");
    if (payload.amount === undefined || payload.amount === null) {
      throw new Error("missing_amount");
    }

    const flwPayload = {
      tx_ref: payload.tx_ref,
      amount: String(payload.amount),
      currency: payload.currency,
      // card + bank transfer + USSD + direct debit. Dashboard "Payment Methods"
      // must also have Bank Transfer enabled, or Flutterwave will hide it.
      payment_options: payload.payment_options ??
        "card,banktransfer,ussd,account",
      redirect_url: payload.redirect_url,
      customer: {
        email: payload.email,
        name: payload.name,
        phonenumber: payload.phone_number ?? "",
      },
      customizations: {
        title: "My Leadership Quest",
        description: "Payment for coins/subscription",
        logo: "https://mlq.app/logo.png",
      },
      meta: payload.meta ?? {},
    };

    const resp = await fetch("https://api.flutterwave.com/v3/payments", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${FLW_SECRET_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(flwPayload),
    });

    const text = await resp.text();
    let body: any = null;
    try {
      body = JSON.parse(text);
    } catch {
      body = { raw: text };
    }

    if (!resp.ok) {
      return new Response(
        JSON.stringify({
          success: false,
          error: body?.message ?? `Flutterwave API error: ${resp.status}`,
        }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    if (body?.status !== "success" || !body?.data?.link) {
      return new Response(
        JSON.stringify({
          success: false,
          error: body?.message ?? "Payment initialization failed",
          data: body,
        }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        link: body.data.link,
        data: body.data,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({
        success: false,
        error: String(e),
      }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }
});
