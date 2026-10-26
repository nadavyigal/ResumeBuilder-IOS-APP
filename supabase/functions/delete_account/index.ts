import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  ACCOUNT_CONTENT_TABLES,
  ACCOUNT_FILE_BUCKETS,
  isStorageFolder,
  storageObjectPath,
} from "./account-deletion.ts";

// Account deletion endpoint required by App Store Guideline 5.1.1(v).
// Validates the caller's JWT, removes the user's uploaded files, removes the
// rows that hold the résumé and job text, then deletes the auth user.
// Guest checks without an account are not handled here; they expire after 7 days.

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

  async function listFiles(bucket: string, folder: string, depth: number): Promise<string[]> {
    if (depth > 4) return [];
    const paths: string[] = [];
    let offset = 0;
    for (;;) {
      const { data, error } = await admin.storage.from(bucket).list(folder, { limit: 100, offset });
      if (error) {
        failures.push(`${bucket}: ${error.message}`);
        return paths;
      }
      if (!data || data.length === 0) return paths;
      for (const entry of data) {
        const path = storageObjectPath(folder, entry.name);
        if (isStorageFolder(entry)) {
          paths.push(...await listFiles(bucket, path, depth + 1));
        } else {
          paths.push(path);
        }
      }
      if (data.length < 100) return paths;
      offset += data.length;
    }
  }

  for (const location of ACCOUNT_FILE_BUCKETS) {
    const paths = await listFiles(location.bucket, location.folder(userId), 0);
    for (let start = 0; start < paths.length; start += 100) {
      const batch = paths.slice(start, start + 100);
      const { error } = await admin.storage.from(location.bucket).remove(batch);
      if (error) failures.push(`${location.bucket}: ${error.message}`);
    }
  }

  if (failures.length > 0) {
    console.error("[delete_account] file removal failed", { userId, failures });
    return jsonResponse(500, { error: "Some account files could not be deleted. Please try again." });
  }

  async function wipe(table: string, column: string) {
    const { error } = await admin.from(table).delete().eq(column, userId);
    // Ignore "relation does not exist" so schema drift never blocks the rest.
    if (error && error.code !== "42P01") {
      failures.push(`${table}.${column}: ${error.message}`);
    }
  }

  const userTables = ACCOUNT_CONTENT_TABLES;
  for (const [table, column] of userTables) {
    await wipe(table, column);
  }

  if (failures.length > 0) {
    console.error("[delete_account] partial failure", { userId, failures });
    return jsonResponse(500, {
      error: "Some account data could not be deleted. Please try again.",
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
