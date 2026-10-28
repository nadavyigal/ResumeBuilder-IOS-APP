#!/bin/zsh
# usage: render.sh <dir> <outdir> <width> <height> <u>
D=$1; OUT=$2; W=$3; H=$4; U=$5
mkdir -p "$OUT"
names=(01-tailor 02-missing 03-edits 04-export 05-expert)
for i in 1 2 3 4 5; do
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=1 --window-size=$W,$H --virtual-time-budget=6000 \
    --allow-file-access-from-files --screenshot="$OUT/${names[$i]}.png" "file://$D/panel.html?slot=$i&u=$U" >/dev/null 2>&1
done
# App Store Connect rejects screenshots with an alpha channel.
python3 -c "import sys,glob;from PIL import Image;[Image.open(f).convert('RGB').save(f) for f in glob.glob(sys.argv[1]+'/*.png')]" "$OUT"
