import { createClient } from "npm:@supabase/supabase-js@2";

const MAX_BYTES = 5 * 1024 * 1024;
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ALLOWED_TYPES = new Map([
  ["image/jpeg", "jpg"],
  ["image/png", "png"],
  ["image/webp", "webp"],
]);

function corsHeaders(req: Request) {
  const origin = req.headers.get("origin") ?? "";
  const allowed =
    origin === "https://www.vrixora.com" ||
    origin === "https://vrixora.com" ||
    origin.startsWith("http://localhost:") ||
    origin.startsWith("http://127.0.0.1:");
  return {
    "access-control-allow-origin": allowed ? origin : "https://www.vrixora.com",
    "access-control-allow-headers":
      "authorization, x-client-info, apikey, content-type",
    "access-control-allow-methods": "POST, OPTIONS",
    "vary": "Origin",
  };
}

function json(req: Request, status: number, body: Record<string, unknown>) {
  return Response.json(body, { status, headers: corsHeaders(req) });
}

function isGoogleAvatarUrl(value: string) {
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    return false;
  }
  if (parsed.protocol !== "https:") return false;
  const host = parsed.hostname.toLowerCase();
  return host === "googleusercontent.com" ||
    host.endsWith(".googleusercontent.com");
}

async function fetchGoogleAvatar(initialUrl: string) {
  let current = initialUrl;

  for (let redirect = 0; redirect < 4; redirect++) {
    if (!isGoogleAvatarUrl(current)) {
      throw new Error("GOOGLE_AVATAR_NOT_AVAILABLE");
    }

    const response = await fetch(current, {
      redirect: "manual",
      headers: { "user-agent": "TUKTUK/1.0" },
    });

    if (response.status >= 300 && response.status < 400) {
      const location = response.headers.get("location");
      if (!location) throw new Error("GOOGLE_AVATAR_FETCH_FAILED");
      const next = new URL(location, current).toString();
      if (!isGoogleAvatarUrl(next)) {
        throw new Error("GOOGLE_AVATAR_FETCH_FAILED");
      }
      current = next;
      continue;
    }

    if (!response.ok) throw new Error("GOOGLE_AVATAR_FETCH_FAILED");

    const length = Number(response.headers.get("content-length") ?? "0");
    if (Number.isFinite(length) && length > MAX_BYTES) {
      throw new Error("GOOGLE_AVATAR_TOO_LARGE");
    }

    const mime = (response.headers.get("content-type") ?? "")
      .split(";")[0]
      .trim()
      .toLowerCase();
    const extension = ALLOWED_TYPES.get(mime);
    if (!extension) throw new Error("GOOGLE_AVATAR_INVALID_FORMAT");

    const bytes = new Uint8Array(await response.arrayBuffer());
    if (bytes.length < 1) throw new Error("GOOGLE_AVATAR_FETCH_FAILED");
    if (bytes.length > MAX_BYTES) throw new Error("GOOGLE_AVATAR_TOO_LARGE");

    return { bytes, mime, extension };
  }

  throw new Error("GOOGLE_AVATAR_FETCH_FAILED");
}

async function sha256Hex(bytes: Uint8Array) {
  const digest = new Uint8Array(
    await crypto.subtle.digest("SHA-256", bytes),
  );
  return Array.from(digest)
    .map((value) => value.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(req) });
  }
  if (req.method !== "POST") {
    return json(req, 405, { error: "METHOD_NOT_ALLOWED" });
  }

  const authorization = req.headers.get("authorization")?.trim();
  if (!authorization?.toLowerCase().startsWith("bearer ")) {
    return json(req, 401, { error: "AUTHENTICATION_REQUIRED" });
  }

  const accessToken = authorization.slice(7).trim();
  if (!accessToken) {
    return json(req, 401, { error: "AUTHENTICATION_REQUIRED" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  if (!supabaseUrl || !anonKey) {
    return json(req, 500, { error: "SERVICE_UNAVAILABLE" });
  }

  const client = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: authData, error: authError } =
    await client.auth.getUser(accessToken);
  const user = authData.user;
  if (authError || !user) {
    return json(req, 401, { error: "AUTHENTICATION_REQUIRED" });
  }

  const body = await req.json().catch(() => ({}));
  const idempotencyKey =
    typeof body?.idempotency_key === "string"
      ? body.idempotency_key.trim()
      : "";
  if (!UUID_RE.test(idempotencyKey)) {
    return json(req, 400, { error: "INVALID_IDEMPOTENCY_KEY" });
  }

  // The client cannot send an arbitrary avatar URL.
  // The source is read only from the authenticated identity.
  const metadata = user.user_metadata ?? {};
  const rawAvatar =
    typeof metadata.avatar_url === "string" && metadata.avatar_url.trim()
      ? metadata.avatar_url.trim()
      : typeof metadata.picture === "string" && metadata.picture.trim()
      ? metadata.picture.trim()
      : "";

  if (!rawAvatar || !isGoogleAvatarUrl(rawAvatar)) {
    return json(req, 422, { error: "GOOGLE_AVATAR_NOT_AVAILABLE" });
  }

  try {
    const image = await fetchGoogleAvatar(rawAvatar);
    const sha256 = await sha256Hex(image.bytes);

    const { data: prepared, error: prepareError } = await client.rpc(
      "prepare_my_marketplace_media_upload",
      {
        target_asset_kind: "driver_photo",
        target_mime_type: image.mime,
        target_byte_size: image.bytes.length,
        target_extension: image.extension,
        target_sha256: sha256,
        target_idempotency_key: idempotencyKey,
      },
    );

    if (prepareError || !prepared?.asset_id) {
      return json(req, 500, { error: "GOOGLE_AVATAR_PREPARE_FAILED" });
    }

    if (prepared.status === "available") {
      return json(req, 200, { data: prepared });
    }

    const bucket = prepared.storage_bucket;
    const path = prepared.storage_path;
    if (typeof bucket !== "string" || typeof path !== "string") {
      return json(req, 500, { error: "GOOGLE_AVATAR_PREPARE_FAILED" });
    }

    const { error: uploadError } = await client.storage
      .from(bucket)
      .upload(path, image.bytes, {
        contentType: image.mime,
        upsert: false,
      });

    if (uploadError) {
      const { data: recovered, error: recoveredError } = await client.rpc(
        "finalize_my_marketplace_media_upload",
        { target_asset_id: prepared.asset_id },
      );
      if (!recoveredError && recovered?.status === "available") {
        return json(req, 200, { data: recovered });
      }
      return json(req, 502, { error: "GOOGLE_AVATAR_UPLOAD_FAILED" });
    }

    const { data: finalized, error: finalizeError } = await client.rpc(
      "finalize_my_marketplace_media_upload",
      { target_asset_id: prepared.asset_id },
    );

    if (finalizeError || finalized?.status !== "available") {
      return json(req, 500, { error: "GOOGLE_AVATAR_FINALIZE_FAILED" });
    }

    return json(req, 200, { data: finalized });
  } catch (error) {
    const code = error instanceof Error ? error.message : "";
    if (
      code === "GOOGLE_AVATAR_NOT_AVAILABLE" ||
      code === "GOOGLE_AVATAR_FETCH_FAILED" ||
      code === "GOOGLE_AVATAR_TOO_LARGE" ||
      code === "GOOGLE_AVATAR_INVALID_FORMAT"
    ) {
      return json(req, 422, { error: code });
    }
    return json(req, 500, { error: "GOOGLE_AVATAR_IMPORT_FAILED" });
  }
});
