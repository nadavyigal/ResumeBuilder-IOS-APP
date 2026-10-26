// What account deletion removes, and what is kept on a schedule instead.
//
// Guest check (no account): résumé text and job text on anonymous_ats_scores
// live for 7 days, then the daily purge deletes rows that were never claimed
// (supabase/migrations/20261013105018_purge_expired_anonymous_ats_scores.sql).
//
// Account: résumé text, job text, optimizations and saved résumés stay until
// the user deletes the account. They are not expired on a timer, because the
// privacy policy keeps them for as long as the account is active. Deleting the
// account removes those rows and the files in the buckets below.

export const GUEST_CHECK_RETENTION_DAYS = 7;

/** Tables wiped by user id, children before the parents they point at. */
export const ACCOUNT_CONTENT_TABLES: Array<[table: string, column: string]> = [
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
  ["ai_consent_records", "user_id"],
  ["design_assignments", "user_id"],
  ["resume_design_assignments", "user_id"],
  ["optimization_review_runs", "user_id"],
  ["saved_resumes", "user_id"],
  ["export_unlocks", "user_id"],
  ["optimizations", "user_id"],
  ["job_descriptions", "user_id"],
  ["resumes", "user_id"],
  ["conversations", "profile_id"],
  ["plans", "profile_id"],
  ["idempotency_keys", "profile_id"],
  ["profiles", "user_id"],
  ["profiles", "auth_user_id"],
];

export const ACCOUNT_FILE_BUCKETS = [
  { bucket: "resume-uploads", folder: (userId: string) => userId },
  { bucket: "resume-exports", folder: (userId: string) => userId },
  { bucket: "applications", folder: (userId: string) => `applications/${userId}` },
] as const;

export function storageObjectPath(folder: string, name: string): string {
  return `${folder}/${name}`;
}

/** Supabase storage lists a folder with a null id. */
export function isStorageFolder(entry: { id: string | null }): boolean {
  return entry.id == null;
}
