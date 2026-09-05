#!/bin/zsh
# Fail when the repo's MARKETING_VERSION is not what the App Store is serving.
#
# This repo has drifted from its own shipped binary three times (2026-07-16,
# 2026-08-14, 2026-09-02). Each time the version bump happened somewhere that
# was never committed, and `main` went on describing an older release while the
# public ran a newer one. Nobody noticed because nothing looked.
#
# So something looks. The live version comes from a cache-busted Apple lookup,
# never from `tasks/progress.md` and never from a repo claim: repo status has
# been the wrong answer every one of those three times.
#
# Usage:
#   scripts/validate-store-version.sh                 # check this repo
#   scripts/validate-store-version.sh path/to/project.pbxproj
#
# Exit 0 = repo and store agree. Exit 1 = drift (or the file is unreadable).
# Exit 2 = the lookup itself failed, which is not a verdict about the repo.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PBXPROJ="${1:-$ROOT/ResumeBuilder IOS APP.xcodeproj/project.pbxproj}"
BUNDLE_ID="Resumebuilder-IOS.ResumeBuilder-IOS-APP"

if [[ ! -f "$PBXPROJ" ]]; then
  echo "FAIL: no project file at $PBXPROJ" >&2
  exit 1
fi

# Every build configuration must agree, or "the" marketing version is a fiction.
repo_versions=$(grep -oE "MARKETING_VERSION = [^;]+;" "$PBXPROJ" \
  | sed -E 's/MARKETING_VERSION = (.*);/\1/' | sort -u)
repo_count=$(printf "%s\n" "$repo_versions" | grep -c . || true)

if [[ "$repo_count" -eq 0 ]]; then
  echo "FAIL: no MARKETING_VERSION in $PBXPROJ" >&2
  exit 1
fi
if [[ "$repo_count" -gt 1 ]]; then
  echo "FAIL: build configurations disagree on MARKETING_VERSION:" >&2
  printf "       %s\n" ${(f)repo_versions} >&2
  exit 1
fi
repo_version="$repo_versions"

cache_buster=$(date -u '+%Y%m%d%H%M%S')
lookup=$(curl -sS --max-time 30 -H 'Cache-Control: no-cache' \
  "https://itunes.apple.com/lookup?bundleId=${BUNDLE_ID}&country=us&_cb=${cache_buster}") || {
  echo "SKIP: Apple lookup failed (network). This is not a verdict about the repo." >&2
  exit 2
}

store_version=$(printf "%s" "$lookup" | python3 -c '
import json, sys
results = json.load(sys.stdin).get("results") or []
print(results[0].get("version", "") if results else "")
')
store_released=$(printf "%s" "$lookup" | python3 -c '
import json, sys
results = json.load(sys.stdin).get("results") or []
print(results[0].get("currentVersionReleaseDate", "") if results else "")
')

if [[ -z "$store_version" ]]; then
  echo "SKIP: Apple lookup returned no version for ${BUNDLE_ID}." >&2
  exit 2
fi

echo "repo  MARKETING_VERSION : $repo_version"
echo "store live version      : $store_version  (released $store_released)"

if [[ "$repo_version" != "$store_version" ]]; then
  cat >&2 <<EOF
FAIL: version drift. The repository says $repo_version; the App Store is serving $store_version.
      \`main\` cannot name the binary the public is running. Set MARKETING_VERSION
      to $store_version and CURRENT_PROJECT_VERSION to that release's confirmed build,
      then diff the sorted set of build-setting lines to prove nothing else moved.
EOF
  exit 1
fi

echo "PASS: the repository names the shipped version ($repo_version)."
