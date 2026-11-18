import { createClient } from "npm:@supabase/supabase-js@2.119.0";

// Invoke on a schedule from a trusted backend. Do not expose the cleanup secret
// in Flutter. Failed objects remain queued for the next invocation.
Deno.serve(async (req) => {
  const secret = Deno.env.get("RECIPE_CLEANUP_SECRET");
  if (!secret || req.headers.get("Authorization") !== `Bearer ${secret}`) {
    return new Response("Unauthorized", { status: 401 });
  }
  if (req.method !== "POST") {
    return new Response("POST required", { status: 405 });
  }
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  const { data, error } = await admin.from("recipe_photo_cleanup")
    .select("path").order("queued_at").limit(100);
  if (error) return new Response("Queue unavailable", { status: 500 });
  let cleaned = 0;
  for (const { path } of data ?? []) {
    const { error: removeError } = await admin.storage.from("recipe-photos")
      .remove([path]);
    if (removeError) continue;
    const { error: ackError } = await admin.from("recipe_photo_cleanup")
      .delete().eq("path", path);
    if (!ackError) cleaned++;
  }
  return Response.json({ cleaned });
});
