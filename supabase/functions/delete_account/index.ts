import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Account deletion endpoint required by App Store Guideline 5.1.1(v).
// Validates the caller's JWT, removes all rows owned by the user across
// public tables (children cascade from their parents), then deletes the
// auth user itself via the admin API.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(500, { error: "Server configuration missing" });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "");
  if (!token) {
    return jsonResponse(401, { error: "Missing access token" });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData?.user) {
    return jsonResponse(401, { error: "Invalid or expired access token" });
  }
  const userId = userData.user.id;

  const failures: string[] = [];

  async function wipe(table: string, column: string) {
    const { error } = await admin.from(table).delete().eq(column, userId);
    // Ignore "relation does not exist" so schema drift never blocks the rest.
    if (error && error.code !== "42P01") {
      failures.push(`${table}.${column}: ${error.message}`);
    }
  }

  // Order matters only loosely: most children cascade from these parents.
  const userTables: Array<[string, string]> = [
    ["device_tokens", "user_id"],
    ["events", "user_id"],
    ["credit_transactions", "user_id"],
    ["agent_shadow_logs", "user_id"],
    ["anonymous_ats_scores", "user_id"],
    ["applications", "user_id"],
    ["expert_workflow_runs", "user_id"],
    ["application_expert_reports", "user_id"],
    ["chat_sessions", "user_id"],
    ["content_modifications", "user_id"],
    ["style_customization_history", "user_id"],
    ["ai_threads", "user_id"],
    ["design_assignments", "user_id"],
    ["resume_design_assignments", "user_id"],
    ["optimization_review_runs", "user_id"],
    ["optimizations", "user_id"],
    ["job_descriptions", "user_id"],
    ["resumes", "user_id"],
    ["conversations", "profile_id"],
    ["plans", "profile_id"],
    ["idempotency_keys", "profile_id"],
    ["profiles", "user_id"],
    ["profiles", "auth_user_id"],
  ];
  for (const [table, column] of userTables) {
    await wipe(table, column);
  }

  if (failures.length > 0) {
    console.error("[delete_account] partial failure", { userId, failures });
    return jsonResponse(500, {
      error: "Some account data could not be deleted. Please try again.",
      details: failures,
    });
  }

  const { error: deleteUserError } = await admin.auth.admin.deleteUser(userId);
  if (deleteUserError) {
    console.error("[delete_account] auth user deletion failed", deleteUserError);
    return jsonResponse(500, { error: "Account data was removed but the account could not be deleted. Please try again." });
  }

  console.log("[delete_account] account deleted", { userId });
  return jsonResponse(200, { success: true });
});
