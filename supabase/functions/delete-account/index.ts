import { createClient } from "npm:@supabase/supabase-js@2.119.0";

const headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};
const reply = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers });
  if (req.method !== "POST") return reply(405, { error: "POST required" });
  const token = req.headers.get("Authorization")?.match(/^Bearer (.+)$/i)?.[1];
  if (!token) return reply(401, { error: "Login required" });
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  // Never accept a caller-provided user ID or trust unverified JWT contents.
  const { data: { user }, error: authError } = await admin.auth.getUser(token);
  if (authError || !user) return reply(401, { error: "Invalid session" });
  let body;
  try {
    body = await req.json();
  } catch {
    return reply(400, { error: "Invalid JSON" });
  }
  if (
    body?.confirmation !== "DELETE" || typeof body?.keepPublished !== "boolean"
  ) {
    return reply(400, {
      error: "Confirm DELETE and choose keepPublished explicitly",
    });
  }
  const { error } = await admin.rpc("delete_snapchef_account", {
    p_user_id: user.id,
    p_keep_published: body.keepPublished,
  });
  if (error) {
    console.error("Account deletion failed", error.code);
    return reply(500, { error: "Account deletion failed. Please retry." });
  }
  return reply(200, { deleted: true });
});
