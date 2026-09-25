// Landing page after Flutterwave checkout.
// mlq.app/redirect currently returns HTTP 500, which breaks in-app WebView
// completion. Point Flutterwave redirect_url here instead.

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const status = (url.searchParams.get("status") ?? "").toLowerCase();
  const txRef = url.searchParams.get("tx_ref") ?? "";
  const transactionId = url.searchParams.get("transaction_id") ??
    url.searchParams.get("id") ??
    "";

  const ok = status === "successful" || status === "success" ||
    (txRef.length > 0 && transactionId.length > 0);

  const title = ok ? "Payment received" : "Payment status";
  const message = ok
    ? "You can return to the My Leadership Quest app. We are confirming your payment."
    : "If you completed payment, return to the app — we will confirm it shortly.";

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${title}</title>
  <style>
    body { font-family: system-ui, sans-serif; background: #0f172a; color: #f8fafc;
      display: flex; min-height: 100vh; align-items: center; justify-content: center; margin: 0; }
    main { max-width: 28rem; padding: 2rem; text-align: center; }
    h1 { font-size: 1.5rem; margin-bottom: 0.75rem; }
    p { line-height: 1.5; color: #cbd5e1; }
    code { font-size: 0.75rem; color: #94a3b8; word-break: break-all; }
  </style>
</head>
<body>
  <main>
    <h1>${title}</h1>
    <p>${message}</p>
    <p><code>status=${status || "n/a"}</code></p>
  </main>
</body>
</html>`;

  return new Response(html, {
    status: 200,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
});
