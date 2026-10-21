#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${1:-$ROOT/dist/app-store-screenshots/app-store-v2}"
EXPECTED="${2:-5}"
REPORT="$OUTPUT/validation-report.txt"

validate_set() {
  local directory="$1"
  local expected_width="$2"
  local expected_height="$3"
  local label="$4"
  local files=("$directory"/*.png(N))

  if [[ "${#files[@]}" -ne "$EXPECTED" ]]; then
    echo "$label: expected $EXPECTED PNGs, found ${#files[@]}" >&2
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
  if [[ "$unique_count" -ne "$EXPECTED" ]]; then
    echo "$label: duplicate screenshots detected" >&2
    return 1
  fi

  echo "$label: PASS - $EXPECTED unique opaque RGB PNGs at ${expected_width}x${expected_height}"
}

{
  echo "Resumely App Store Screenshot Validation"
  echo "Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  if [[ ! -d "$OUTPUT/iphone-6.5-1242x2688" && ! -d "$OUTPUT/iphone-6.3-1206x2622" ]]; then
    echo "No iPhone screenshot folder in $OUTPUT" >&2
    exit 1
  fi
  if [[ -d "$OUTPUT/iphone-6.5-1242x2688" ]]; then
    validate_set "$OUTPUT/iphone-6.5-1242x2688" 1242 2688 "iPhone 6.5-inch (Face ID, large display)"
  fi
  if [[ -d "$OUTPUT/iphone-6.3-1206x2622" ]]; then
    validate_set "$OUTPUT/iphone-6.3-1206x2622" 1206 2622 "iPhone 6.3-inch (Dynamic Island, medium display)"
  fi
  if [[ "${3:-}" != "--iphone-only" ]]; then
    validate_set "$OUTPUT/ipad-13" 2064 2752 "iPad 13-inch"
  fi
} | tee "$REPORT"
