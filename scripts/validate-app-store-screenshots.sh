#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${1:-$ROOT/dist/app-store-screenshots/app-store-v1}"
REPORT="$OUTPUT/validation-report.txt"

validate_set() {
  local directory="$1"
  local expected_width="$2"
  local expected_height="$3"
  local label="$4"
  local files=("$directory"/*.png(N))

  if [[ "${#files[@]}" -ne 10 ]]; then
    echo "$label: expected 10 PNGs, found ${#files[@]}" >&2
    return 1
  fi

  local width=""
  local height=""
  local has_alpha=""
  local hashes=()
  for file in "${files[@]}"; do
    width=$(sips -g pixelWidth "$file" | awk '/pixelWidth/ {print $2}')
    height=$(sips -g pixelHeight "$file" | awk '/pixelHeight/ {print $2}')
    has_alpha=$(sips -g hasAlpha "$file" | awk '/hasAlpha/ {print $2}')

    if [[ "$width" != "$expected_width" || "$height" != "$expected_height" ]]; then
      echo "$label: wrong dimensions for $file: ${width}x${height}" >&2
      return 1
    fi

    if [[ "$has_alpha" != "no" ]]; then
      echo "$label: alpha channel detected in $file" >&2
      return 1
    fi

    hashes+=("$(shasum -a 256 "$file" | awk '{print $1}')")
  done

  local unique_count
  unique_count=$(printf "%s\n" "${hashes[@]}" | sort -u | wc -l | tr -d ' ')
  if [[ "$unique_count" -ne 10 ]]; then
    echo "$label: duplicate screenshots detected" >&2
    return 1
  fi

  echo "$label: PASS - 10 unique opaque RGB PNGs at ${expected_width}x${expected_height}"
}

{
  echo "Resumely App Store Screenshot Validation"
  echo "Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  validate_set "$OUTPUT/iphone-6.5-1242x2688" 1242 2688 "iPhone 6.5-inch"
  if [[ "${2:-}" != "--iphone-only" ]]; then
    validate_set "$OUTPUT/ipad-13" 2064 2752 "iPad 13-inch"
  fi
} | tee "$REPORT"
