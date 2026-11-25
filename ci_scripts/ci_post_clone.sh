#!/bin/sh
# Xcode Cloud runs this right after it clones the repo.
# It writes the gitignored Secrets.xcconfig from the workflow's environment
# variables, so a cloud archive gets the same keys as a local one.
#
# Set all four in App Store Connect > Xcode Cloud > Manage Workflows >
# (workflow) > Environment > Environment Variables, each marked Secret:
#   POSTHOG_API_KEY, SUPABASE_ANON_KEY,
#   INTERNAL_TESTER_EMAILS, INTERNAL_TESTER_USER_IDS
# Never echo a value here: only secret variables are masked in the build log.
set -eu

if [ -z "${CI_PRIMARY_REPOSITORY_PATH:-}" ]; then
  echo "error: CI_PRIMARY_REPOSITORY_PATH is not set. This script only runs on Xcode Cloud." >&2
  exit 1
fi

missing=""
for name in POSTHOG_API_KEY SUPABASE_ANON_KEY INTERNAL_TESTER_EMAILS INTERNAL_TESTER_USER_IDS; do
  eval "value=\${$name:-}"
  if [ -z "$(printf '%s' "$value" | tr -d '[:space:]')" ]; then
    missing="$missing $name"
  fi
  case "$value" in
    *'$'*) unsafe="${unsafe:-} $name" ;;
  esac
done
# xcconfig expands $(NAME), so a $ in a value would silently change it.
if [ -n "${unsafe:-}" ]; then
  echo "error: these Xcode Cloud variables contain a \$ character, which xcconfig would expand:$unsafe" >&2
  exit 1
fi
if [ -n "$missing" ]; then
  echo "error: missing Xcode Cloud environment variables:$missing" >&2
  exit 1
fi

# Supabase key rotation: the app ships the publishable key only, never the legacy
# anon JWT (eyJ...). Fail early so a wrong secret never reaches TestFlight.
case "$SUPABASE_ANON_KEY" in
  sb_publishable_*) ;;
  *)
    echo "error: SUPABASE_ANON_KEY must be the sb_publishable_ key, not the legacy anon JWT." >&2
    exit 1
    ;;
esac

# xcconfig reads // as the start of a comment, so write it as /$()/.
# One pass leaves a pair in runs of 3+ slashes (/// -> /$()//), so repeat until
# no literal // is left. $() has no slash, so each pass shrinks the work.
escape() {
  value=$1
  while :; do
    case "$value" in
      *//*) value=$(printf '%s' "$value" | sed 's#//#/$()/#g') ;;
      *) break ;;
    esac
  done
  printf '%s' "$value"
}

target="$CI_PRIMARY_REPOSITORY_PATH/Secrets.xcconfig"
{
  echo "// Written by ci_scripts/ci_post_clone.sh on Xcode Cloud. Not committed."
  echo "POSTHOG_API_KEY = $(escape "$POSTHOG_API_KEY")"
  echo "SUPABASE_ANON_KEY = $(escape "$SUPABASE_ANON_KEY")"
  echo "INTERNAL_TESTER_EMAILS = $(escape "$INTERNAL_TESTER_EMAILS")"
  echo "INTERNAL_TESTER_USER_IDS = $(escape "$INTERNAL_TESTER_USER_IDS")"
} > "$target"

echo "Wrote Secrets.xcconfig with 4 keys (values hidden)."
