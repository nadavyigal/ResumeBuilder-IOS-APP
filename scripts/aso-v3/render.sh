#!/bin/zsh
set -euo pipefail
# usage: render.sh <dir> <outdir> <width> <height> <u>
D=$1; OUT=$2; W=$3; H=$4; U=$5
CHROME=${CHROME_BIN:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}
mkdir -p "$OUT"
PROFILE=$(mktemp -d "$OUT/.chrome-profile.XXXXXX")
trap 'rm -rf "$PROFILE"' EXIT
names=(01-tailor 02-missing 03-edits 04-export 05-expert)
PANEL=panel.html
if [[ ${ASO_RELEASE:-0} == 1 ]]; then
  PANEL=release-panel.html
  names=(01-tailor 02-missing 03-edits 04-review)
fi
for name in $names; do
  rm -f "$OUT/$name.png"
done
for ((i=1; i<=${#names}; i++)); do
  "$CHROME" --user-data-dir="$PROFILE" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 --window-size=$W,$H --virtual-time-budget=6000 \
    --allow-file-access-from-files --screenshot="$OUT/${names[$i]}.png" "file://$D/$PANEL?slot=$i&u=$U&w=$W&h=$H" >/dev/null
  [[ -s "$OUT/${names[$i]}.png" ]]
done
# App Store Connect rejects screenshots with an alpha channel.
python3 -c "import sys,glob;from PIL import Image;[Image.open(f).convert('RGB').save(f) for f in glob.glob(sys.argv[1]+'/*.png')]" "$OUT"
