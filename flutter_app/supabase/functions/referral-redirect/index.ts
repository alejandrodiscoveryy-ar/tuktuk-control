import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const PLAY_BASE = "https://play.google.com/store/apps/details?id=com.alejandrocruz.tuktukcontrol";
const APP_BASE = "https://www.vrixora.com/tuktuk/app/";

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

Deno.serve((req: Request) => {
  const url = new URL(req.url);
  const rawRef = (url.searchParams.get("ref") ?? "").trim().toUpperCase();
  const validRef = /^[A-Z0-9_-]{3,64}$/.test(rawRef) ? rawRef : "";

  const appUrl = validRef
    ? `${APP_BASE}?ref=${encodeURIComponent(validRef)}`
    : APP_BASE;
  const installReferrer = validRef ? `ref=${validRef}` : "";
  const playUrl = installReferrer
    ? `${PLAY_BASE}&referrer=${encodeURIComponent(installReferrer)}`
    : PLAY_BASE;

  const intentUrl = validRef
    ? `intent://www.vrixora.com/tuktuk/app/?ref=${encodeURIComponent(validRef)}#Intent;scheme=https;package=com.alejandrocruz.tuktukcontrol;S.browser_fallback_url=${encodeURIComponent(playUrl)};end`
    : `intent://www.vrixora.com/tuktuk/app/#Intent;scheme=https;package=com.alejandrocruz.tuktukcontrol;S.browser_fallback_url=${encodeURIComponent(playUrl)};end`;

  const safeRef = escapeHtml(validRef);
  const safePlay = escapeHtml(playUrl);
  const safeApp = escapeHtml(appUrl);
  const safeIntent = escapeHtml(intentUrl);

  const html = `<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <meta name="robots" content="noindex,nofollow" />
  <title>Invitación a TUKTUK Control</title>
  <style>
    *{box-sizing:border-box}body{margin:0;background:#0b0f14;color:#f5f7fa;font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;min-height:100vh;display:grid;place-items:center;padding:24px}.card{width:min(440px,100%);background:#121821;border:1px solid #28313d;border-radius:22px;padding:28px;box-shadow:0 18px 60px rgba(0,0,0,.35)}h1{font-size:26px;margin:0 0 10px}p{color:#b8c0cc;line-height:1.5;margin:0 0 22px}.btn{display:block;width:100%;text-align:center;text-decoration:none;border-radius:14px;padding:15px 18px;font-weight:800;margin-top:12px}.primary{background:#f5f7fa;color:#0b0f14}.secondary{border:1px solid #3b4655;color:#f5f7fa}.code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;color:#dce3ec;font-size:13px;margin-top:18px;text-align:center}.hint{font-size:12px;color:#7f8a99;margin-top:16px;text-align:center}</style>
</head>
<body>
  <main class="card">
    <h1>Únete a TUKTUK Control</h1>
    <p>Abre la aplicación si ya la tienes instalada o instálala desde Google Play. Tu invitación se conservará durante la instalación.</p>
    <a id="smartOpen" class="btn primary" href="${safeIntent}">Continuar</a>
    <a class="btn secondary" href="${safePlay}">Instalar en Google Play</a>
    <a class="btn secondary" href="${safeApp}">Abrir versión web</a>
    ${validRef ? `<div class="code">Código de invitación: ${safeRef}</div>` : ""}
    <div class="hint">No cierres esta pantalla hasta abrir o instalar la app.</div>
  </main>
  <script>
    const ua = navigator.userAgent || "";
    if (!/Android/i.test(ua)) {
      document.getElementById("smartOpen").href = ${JSON.stringify(appUrl)};
    }
  </script>
</body>
</html>`;

  return new Response(html, {
    status: 200,
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "no-store, max-age=0",
      "x-content-type-options": "nosniff",
      "referrer-policy": "no-referrer",
    },
  });
});
