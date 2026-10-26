import assert from "node:assert/strict";
import { test } from "node:test";
import {
  ACCOUNT_CONTENT_TABLES,
  ACCOUNT_FILE_BUCKETS,
  GUEST_CHECK_RETENTION_DAYS,
  isStorageFolder,
  storageObjectPath,
} from "./account-deletion.ts";

function indexOf(table: string): number {
  return ACCOUNT_CONTENT_TABLES.findIndex(([name]) => name === table);
}

test("a guest check is kept for 7 days", () => {
  assert.equal(GUEST_CHECK_RETENTION_DAYS, 7);
});

test("deleting an account removes résumé text, job text and saved résumés", () => {
  for (const table of ["resumes", "job_descriptions", "optimizations", "saved_resumes", "anonymous_ats_scores", "ai_consent_records"]) {
    assert.ok(indexOf(table) >= 0, table);
  }
  assert.ok(indexOf("saved_resumes") < indexOf("optimizations"));
  assert.ok(indexOf("job_descriptions") > indexOf("optimizations"));
});

test("deleting an account removes the uploaded files, not only the rows", () => {
  const userId = "user-1";
  const folders = ACCOUNT_FILE_BUCKETS.map((location) => [location.bucket, location.folder(userId)]);
  assert.deepEqual(folders, [
    ["resume-uploads", "user-1"],
    ["resume-exports", "user-1"],
    ["applications", "applications/user-1"],
  ]);
  assert.equal(storageObjectPath("user-1", "resume.pdf"), "user-1/resume.pdf");
  assert.equal(isStorageFolder({ id: null }), true);
  assert.equal(isStorageFolder({ id: "file-1" }), false);
});
