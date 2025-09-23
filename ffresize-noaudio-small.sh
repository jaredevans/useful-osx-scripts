#!/usr/bin/env bash
# Batch resize to 720x480 H.264 MP4, preserve aspect ratio with letterbox, remove audio.

set -euo pipefail

MAX_WIDTH=720
MAX_HEIGHT=480
OUT_SUFFIX="_mobile.mp4"

# Extensions to include (case-insensitive)
ext_pat='\( -iname "*.mpg" -o -iname "*.vob" -o -iname "*.m4v" -o -iname "*.mov" -o -iname "*.avi" -o -iname "*.mp4" -o -iname "*.wmv" -o -iname "*.flv" -o -iname "*.mpeg" -o -iname "*.mkv" \)'

echo "$(date)"
echo "Scanning for videos…"

# Dry run preview
while IFS= read -r -d '' f; do
  base="${f%.*}"
  out="${base}${OUT_SUFFIX}"
  echo "Will convert to: ${out}"
done < <(eval "find . -maxdepth 1 -type f ${ext_pat} -not -iname '*${OUT_SUFFIX}' -print0")

echo
echo "Starting conversions…"
echo

# Actual conversion loop
while IFS= read -r -d '' f; do
  pretty="${f#./}"
  base="${f%.*}"
  out="${base}${OUT_SUFFIX}"

  echo "Resizing: ${pretty}"
  nice -n 20 ffmpeg -y -hide_banner -loglevel error \
    -i "$f" \
    -pix_fmt yuv420p \
    -c:v libx264 -preset medium -crf 23 \
    -vf "scale=iw*sar*min(${MAX_WIDTH}/(iw*sar)\,${MAX_HEIGHT}/ih):ih*min(${MAX_WIDTH}/(iw*sar)\,${MAX_HEIGHT}/ih),pad=${MAX_WIDTH}:${MAX_HEIGHT}:(ow-iw)/2:(oh-ih)/2,setsar=1/1" \
    -r 30000/1001 \
    -movflags +faststart \
    -an \
    -f mp4 \
    "$out"

  touch -r "$f" "$out"   # preserve timestamps
  echo "  -> Done: ${out}"
  echo
done < <(eval "find . -maxdepth 1 -type f ${ext_pat} -not -iname '*${OUT_SUFFIX}' -print0")

echo "All done at $(date)"
