#!/bin/zsh
set -euo pipefail

# Renders the App Store creative asset (product page header + search results)
# from dist/app-store-creative-assets/source/creative.html, then writes:
#   resumely-universal-5244x2950.png  one image for both placements (16:9)
#   resumely-header-3840x1646.png     dedicated header (21:9 centre crop)
#   resumely-search-3840x2560.png     dedicated search results (3:2 centre crop)
# Needs the iPhone 6.3-inch screenshot set in app-store-v2/ (the phones in the image).

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${1:-$ROOT/dist/app-store-creative-assets}"
SOURCE="$OUTPUT/source/creative.html"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
WORK="$(mktemp -d)"
RAW="$WORK/raw.png"
REPORT="$OUTPUT/validation-report.txt"

# Guideline 2.3.14: no unverifiable claims, no pricing. Same ATS rule as CopyClaimsTests.
for banned in "ATS" "Free" "free" "\\\$" "%" "price" "Price" "guarantee" "Guarantee" "#1" "best" "Best" "score" "Score"; do
  if sed -n '/<body>/,/<\/body>/p' "$SOURCE" | sed -e 's/<[^>]*>//g' | grep -q -- "$banned"; then
    echo "Banned copy \"$banned\" in $SOURCE" >&2
    exit 1
  fi
done

# Headless Chrome writes the screenshot but may not exit on its own, so wait for
# the file, then stop it.
"$CHROME" \
  --headless=new \
  --user-data-dir="$WORK/profile" \
  --no-first-run \
  --disable-gpu \
  --hide-scrollbars \
  --allow-file-access-from-files \
  --force-device-scale-factor=1 \
  --window-size=5244,2950 \
  --screenshot="$RAW" \
  "$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).as_uri())' "$SOURCE")" >/dev/null 2>&1 &
CHROME_PID=$!
for _ in {1..90}; do
  [[ -s "$RAW" ]] && break
  sleep 1
done
sleep 2
kill "$CHROME_PID" 2>/dev/null || true
wait "$CHROME_PID" 2>/dev/null || true
if [[ ! -s "$RAW" ]]; then
  echo "Chrome did not write $RAW within 90 seconds" >&2
  exit 1
fi

python3 - "$RAW" "$OUTPUT" <<'PY'
import sys
from pathlib import Path
from PIL import Image

raw, out = Path(sys.argv[1]), Path(sys.argv[2])
with Image.open(raw) as image:
    universal = image.convert("RGB")
if universal.size != (5244, 2950):
    raise SystemExit(f"Chrome rendered {universal.size}, expected (5244, 2950)")

def centre_crop(image, ratio_w, ratio_h):
    width, height = image.size
    if width * ratio_h > height * ratio_w:
        new_width = round(height * ratio_w / ratio_h)
        left = (width - new_width) // 2
        return image.crop((left, 0, left + new_width, height))
    new_height = round(width * ratio_h / ratio_w)
    top = (height - new_height) // 2
    return image.crop((0, top, width, top + new_height))

universal.save(out / "resumely-universal-5244x2950.png")
centre_crop(universal, 21, 9).resize((3840, 1646), Image.Resampling.LANCZOS).save(
    out / "resumely-header-3840x1646.png")
centre_crop(universal, 3, 2).resize((3840, 2560), Image.Resampling.LANCZOS).save(
    out / "resumely-search-3840x2560.png")
PY

check() {
  local file="$1" width="$2" height="$3"
  local w h alpha
  w=$(sips -g pixelWidth "$file" | awk '/pixelWidth/ {print $2}')
  h=$(sips -g pixelHeight "$file" | awk '/pixelHeight/ {print $2}')
  alpha=$(sips -g hasAlpha "$file" | awk '/hasAlpha/ {print $2}')
  if [[ "$w" != "$width" || "$h" != "$height" || "$alpha" != "no" ]]; then
    echo "$(basename "$file"): FAIL - ${w}x${h}, alpha $alpha" >&2
    return 1
  fi
  echo "$(basename "$file"): PASS - opaque RGB PNG at ${width}x${height}"
}

{
  echo "Resumely App Store Creative Asset Validation"
  echo "Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "Copy check: PASS - no ATS, price, free, score, guarantee or ranking words"
  check "$OUTPUT/resumely-universal-5244x2950.png" 5244 2950
  check "$OUTPUT/resumely-header-3840x1646.png" 3840 1646
  check "$OUTPUT/resumely-search-3840x2560.png" 3840 2560
} | tee "$REPORT"
