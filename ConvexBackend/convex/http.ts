import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";
import { internal } from "./_generated/api";

const http = httpRouter();

/**
 * Renders the group-invite landing page with PER-TRIP rich-preview (Open Graph)
 * tags, so a shared `get-catalyst.app/join/<code>` link previews as the group's
 * name + destination photo. Vercel proxies /join/:code here (see the Catalyst
 * site's vercel.json).
 *
 * Link-preview bots don't run JS, so the OG tags must be server-rendered — which
 * is the whole reason this endpoint exists rather than a static page.
 */
http.route({
  path: "/join",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const url = new URL(request.url);
    const code = (url.searchParams.get("code") || "").replace(/\D/g, "").slice(0, 5);

    const meta = code
      ? await ctx.runQuery(internal.share.shareMeta, { code })
      : null;

    // Resolve (and cache) a destination photo for the card.
    let imageUrl: string | null = meta?.shareImageUrl ?? null;
    if (meta && !imageUrl && meta.destination) {
      imageUrl = await fetchUnsplashImage(meta.destination);
      if (imageUrl) {
        await ctx.runMutation(internal.share.setShareImage, {
          groupId: meta.groupId,
          url: imageUrl,
        });
      }
    }

    return new Response(renderJoinPage(code, meta, imageUrl), {
      status: 200,
      headers: {
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "public, max-age=300",
      },
    });
  }),
});

/**
 * Renders a shared solo trip's landing page with per-trip Open Graph tags
 * (title + destination + photo), mirroring the /join route above. Vercel
 * proxies /t/:code here (see the Catalyst site's vercel.json).
 */
http.route({
  path: "/t",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const url = new URL(request.url);
    const code = (url.searchParams.get("code") || "").replace(/[^a-f0-9]/gi, "").slice(0, 32).toLowerCase();

    const meta = code
      ? await ctx.runQuery(internal.share.sharedTripMeta, { code })
      : null;

    // Prefer the photo the app already resolved while generating — usually
    // costs zero Unsplash calls. Re-parameterize its size for the OG card
    // instead of paying for a second search (the app's URL is phone-sized).
    let imageUrl: string | null = meta?.shareImageUrl ?? normalizeOgImage(meta?.imageUrl ?? null);
    if (meta && !imageUrl && meta.destination) {
      imageUrl = await fetchUnsplashImage(meta.destination);
    }
    if (meta && imageUrl && !meta.shareImageUrl) {
      await ctx.runMutation(internal.share.setSharedTripImage, {
        tripId: meta.tripId,
        url: imageUrl,
      });
    }

    return new Response(renderSharedTripPage(code, meta, imageUrl), {
      status: 200,
      headers: {
        "Content-Type": "text/html; charset=utf-8",
        // A revoked/unknown link must not stay cached as "available".
        "Cache-Control": meta ? "public, max-age=300" : "no-store",
      },
    });
  }),
});

export default http;

// MARK: - Unsplash (mirrors the app's UnsplashService) -------------------------

async function fetchUnsplashImage(query: string): Promise<string | null> {
  const key = process.env.UNSPLASH_ACCESS_KEY;
  if (!key) return null;
  try {
    const u = new URL("https://api.unsplash.com/search/photos");
    u.searchParams.set("query", query);
    u.searchParams.set("per_page", "1");
    u.searchParams.set("orientation", "landscape");
    u.searchParams.set("content_filter", "high");
    const resp = await fetch(u.toString(), {
      headers: { Authorization: `Client-ID ${key}`, "Accept-Version": "v1" },
    });
    if (!resp.ok) return null;
    const data = (await resp.json()) as {
      results?: { urls?: { raw?: string; regular?: string } }[];
    };
    const urls = data.results?.[0]?.urls;
    if (!urls) return null;
    // Prefer `raw` sized to the OG 1200x630; fall back to `regular`.
    return urls.raw ? `${urls.raw}&w=1200&h=630&fit=crop&q=80` : urls.regular ?? null;
  } catch {
    return null;
  }
}

/**
 * The app's Unsplash URL is phone-sized (`w=1080`, no crop). Unsplash serves
 * imgix, so re-parameterize it to the OG card's 1200x630 instead of paying
 * for a second Unsplash search. Any non-Unsplash URL passes through untouched
 * (returns `null` on a malformed URL rather than risk an unvalidated string
 * ending up inside a CSS `url(...)`).
 */
function normalizeOgImage(raw: string | null): string | null {
  if (!raw) return null;
  try {
    const u = new URL(raw);
    if (u.hostname !== "images.unsplash.com") return raw;
    u.searchParams.set("w", "1200");
    u.searchParams.set("h", "630");
    u.searchParams.set("fit", "crop");
    u.searchParams.set("q", "80");
    return u.toString();
  } catch {
    return null;
  }
}

// MARK: - HTML ----------------------------------------------------------------

// Neutral travel image (airplane wing over clouds) — deliberately NOT a
// recognizable landmark, so a missing key / failed lookup never implies a
// specific (wrong) destination.
const FALLBACK_IMAGE =
  "https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=1200&h=630&fit=crop&q=80";

type Meta = {
  groupId: string;
  name: string;
  destination: string;
  status: string;
  shareImageUrl: string | null;
} | null;

function esc(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function renderJoinPage(code: string, meta: Meta, imageUrl: string | null): string {
  const hasTrip = !!meta && meta.name.length > 0;
  const ogImage = imageUrl || FALLBACK_IMAGE;
  const title = hasTrip ? esc(meta!.name) : "You're invited on a group trip ✈️";
  const dest = hasTrip ? esc(meta!.destination) : "";
  const desc = hasTrip
    ? `You're invited — plan a trip to ${dest} together on Wanderlust ✈️`
    : "Swipe your travel style and plan one trip together with your group on Wanderlust.";

  const heroStyle = imageUrl
    ? `background-image: linear-gradient(180deg, rgba(40,20,80,0.10), rgba(40,20,80,0.45)), url('${esc(imageUrl)}'); background-size: cover; background-position: center;`
    : "background: linear-gradient(135deg, #7C83FF 0%, #9A7CE0 55%, #C08CE0 100%);";

  const heading = hasTrip ? esc(meta!.name) : "You're invited on a group trip";
  const sub = hasTrip
    ? `Plan a trip to <b>${dest}</b> together — Wanderlust blends everyone's picks into one itinerary.`
    : "Swipe your travel style and plan one trip together — Wanderlust blends everyone's picks into a single itinerary.";

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${title} · Wanderlust</title>
  <meta name="robots" content="noindex" />
  <meta property="og:type" content="website" />
  <meta property="og:site_name" content="Wanderlust" />
  <meta property="og:title" content="${title}" />
  <meta property="og:description" content="${esc(desc)}" />
  <meta property="og:image" content="${esc(ogImage)}" />
  <meta property="og:image:width" content="1200" />
  <meta property="og:image:height" content="630" />
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${title}" />
  <meta name="twitter:description" content="${esc(desc)}" />
  <meta name="twitter:image" content="${esc(ogImage)}" />
  <style>
    :root { color-scheme: light dark; }
    * { box-sizing: border-box; }
    body { margin:0; min-height:100vh; display:grid; place-items:center;
      font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",system-ui,sans-serif; color:#1b1b1f;
      background:
        radial-gradient(900px 500px at 15% -10%, rgba(91,91,214,0.20), transparent 60%),
        radial-gradient(800px 500px at 110% 20%, rgba(180,150,255,0.18), transparent 55%),
        radial-gradient(700px 600px at 50% 120%, rgba(255,205,120,0.22), transparent 55%),
        #f6f7fb; }
    @media (prefers-color-scheme: dark) {
      body { color:#f2f2f7; background:
        radial-gradient(900px 500px at 15% -10%, rgba(91,91,214,0.30), transparent 60%),
        radial-gradient(800px 500px at 110% 20%, rgba(120,90,200,0.22), transparent 55%),
        radial-gradient(700px 600px at 50% 120%, rgba(120,90,40,0.30), transparent 55%),
        #0e0e12; }
      .card { background: rgba(28,28,34,0.72) !important; }
      .muted { color:#a0a0aa !important; } }
    .card { width:min(92vw,400px); margin:24px; border-radius:26px; overflow:hidden;
      background:rgba(255,255,255,0.80); backdrop-filter:blur(16px);
      box-shadow:0 24px 70px rgba(70,70,140,0.18); border:1px solid rgba(255,255,255,0.5); }
    .hero { height:150px; display:grid; place-items:center; font-size:52px; ${heroStyle} }
    .body { padding:26px 26px 30px; text-align:center; }
    h1 { font-size:22px; margin:0 0 6px; letter-spacing:-0.2px; }
    .muted { color:#6b6b76; line-height:1.5; margin:0; font-size:15px; }
    .code-label { margin:22px 0 6px; font-size:12px; text-transform:uppercase; letter-spacing:1.5px; color:#8a8a94; }
    .code { display:inline-block; padding:10px 18px; border-radius:12px; background:rgba(91,91,214,0.10);
      color:#5B5BD6; font-weight:700; font-size:26px; letter-spacing:8px; font-variant-numeric:tabular-nums; }
    .btn { display:block; margin:24px 0 0; padding:15px; border-radius:15px; background:#5B5BD6; color:#fff;
      text-decoration:none; font-weight:650; font-size:16px; }
    .hint { margin:16px 0 0; font-size:13px; color:#8a8a94; line-height:1.5; }
  </style>
</head>
<body>
  <div class="card">
    <div class="hero">${imageUrl ? "" : "✈️"}</div>
    <div class="body">
      <h1>${heading}</h1>
      <p class="muted">${sub}</p>
      <div class="code-label">Invite ID</div>
      <div class="code">${esc(code) || "&mdash;"}</div>
      <a class="btn" href="wanderlust://join/${encodeURIComponent(code)}">Open in Wanderlust</a>
      <p class="hint">Don't have the app yet? Install Wanderlust, then tap <b>Start or join group trip &rarr; Join Trip</b> and enter the invite ID above.</p>
    </div>
  </div>
</body>
</html>`;
}

type SharedTripMeta = {
  tripId: string;
  title: string;
  destination: string;
  startMonth: string;
  durationDays: number;
  imageUrl: string | null;
  shareImageUrl: string | null;
} | null;

function renderSharedTripPage(code: string, meta: SharedTripMeta, imageUrl: string | null): string {
  const ogImage = imageUrl || FALLBACK_IMAGE;
  const title = meta ? esc(meta.title) : "A trip shared with you";
  const dest = meta ? esc(meta.destination) : "";
  const desc = meta
    ? `A ${meta.durationDays}-day trip to ${dest}, planned with Wanderlust ✈️`
    : "This trip link isn't available anymore.";

  const heroStyle = imageUrl
    ? `background-image: linear-gradient(180deg, rgba(40,20,80,0.10), rgba(40,20,80,0.45)), url('${esc(imageUrl)}'); background-size: cover; background-position: center;`
    : "background: linear-gradient(135deg, #7C83FF 0%, #9A7CE0 55%, #C08CE0 100%);";

  const heading = meta ? esc(meta.title) : "This trip link isn't available";
  const sub = meta
    ? `A ${meta.durationDays}-day trip to <b>${dest}</b>, shared with you on Wanderlust.`
    : "It may have been shared incorrectly, or the link is malformed.";

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${title} · Wanderlust</title>
  <meta name="robots" content="noindex" />
  <meta property="og:type" content="website" />
  <meta property="og:site_name" content="Wanderlust" />
  <meta property="og:title" content="${title}" />
  <meta property="og:description" content="${esc(desc)}" />
  <meta property="og:image" content="${esc(ogImage)}" />
  <meta property="og:image:width" content="1200" />
  <meta property="og:image:height" content="630" />
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${title}" />
  <meta name="twitter:description" content="${esc(desc)}" />
  <meta name="twitter:image" content="${esc(ogImage)}" />
  <style>
    :root { color-scheme: light dark; }
    * { box-sizing: border-box; }
    body { margin:0; min-height:100vh; display:grid; place-items:center;
      font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",system-ui,sans-serif; color:#1b1b1f;
      background:
        radial-gradient(900px 500px at 15% -10%, rgba(91,91,214,0.20), transparent 60%),
        radial-gradient(800px 500px at 110% 20%, rgba(180,150,255,0.18), transparent 55%),
        radial-gradient(700px 600px at 50% 120%, rgba(255,205,120,0.22), transparent 55%),
        #f6f7fb; }
    @media (prefers-color-scheme: dark) {
      body { color:#f2f2f7; background:
        radial-gradient(900px 500px at 15% -10%, rgba(91,91,214,0.30), transparent 60%),
        radial-gradient(800px 500px at 110% 20%, rgba(120,90,200,0.22), transparent 55%),
        radial-gradient(700px 600px at 50% 120%, rgba(120,90,40,0.30), transparent 55%),
        #0e0e12; }
      .card { background: rgba(28,28,34,0.72) !important; }
      .muted { color:#a0a0aa !important; } }
    .card { width:min(92vw,400px); margin:24px; border-radius:26px; overflow:hidden;
      background:rgba(255,255,255,0.80); backdrop-filter:blur(16px);
      box-shadow:0 24px 70px rgba(70,70,140,0.18); border:1px solid rgba(255,255,255,0.5); }
    .hero { height:150px; display:grid; place-items:center; font-size:52px; ${heroStyle} }
    .body { padding:26px 26px 30px; text-align:center; }
    h1 { font-size:22px; margin:0 0 6px; letter-spacing:-0.2px; }
    .muted { color:#6b6b76; line-height:1.5; margin:0; font-size:15px; }
    .btn { display:block; margin:24px 0 10px; padding:15px; border-radius:15px; background:#5B5BD6; color:#fff;
      text-decoration:none; font-weight:650; font-size:16px; }
    .btn-secondary { display:block; padding:13px; border-radius:15px; background:transparent; color:#5B5BD6;
      text-decoration:none; font-weight:600; font-size:15px; border:1.5px solid rgba(91,91,214,0.3); }
  </style>
</head>
<body>
  <div class="card">
    <div class="hero">${imageUrl ? "" : "✈️"}</div>
    <div class="body">
      <h1>${heading}</h1>
      <p class="muted">${sub}</p>
      <a class="btn" href="wanderlust://t/${encodeURIComponent(code)}">Open in Wanderlust</a>
      <a class="btn-secondary" href="https://apps.apple.com/app/wanderlust">Get the app</a>
    </div>
  </div>
</body>
</html>`;
}
