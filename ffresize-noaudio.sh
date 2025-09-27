#!/usr/bin/env bash
# Resize/transcode videos to MAX_W×MAX_H MP4 (no audio) as *_noaudio.mp4
# Default: macOS hardware encoding (h264_videotoolbox).
# Safe with spaces; skips existing outputs unless --overwrite.

set -Eeuo pipefail

# ---- defaults ----
MAX_W=960
MAX_H=540
FPS=""                    # keep source FPS by default; set e.g. --fps 30 to force CFR
CODEC="h264_videotoolbox" # default macOS HW encode
BITRATE="2500k"           # target bitrate (HW encoders don't use CRF)
OVERWRITE=0
DRYRUN=0

# ---- parse args ----
while [[ $# -gt 0 ]]; do
  case "$1" in
    --width)   MAX_W="${2:?}"; shift 2 ;;
    --height)  MAX_H="${2:?}"; shift 2 ;;
    --fps)     FPS="${2:?}";   shift 2 ;;
    --bitrate) BITRATE="${2:?}"; shift 2 ;;
    --codec)   CODEC="${2:?}"; shift 2 ;; # override if needed
    --dry-run) DRYRUN=1; shift ;;
    --overwrite) OVERWRITE=1; shift ;;
    -h|--help)
      cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --width N      Max width (default $MAX_W)
  --height N     Max height (default $MAX_H)
  --fps N        Force constant frame rate (keep source if omitted)
  --bitrate N    Target bitrate (default $BITRATE, only for HW encode)
  --codec NAME   h264_videotoolbox (default) or libx264
  --dry-run      Show ffmpeg commands only
  --overwrite    Overwrite existing *_noaudio.mp4 outputs
EOF
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

log()   { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
quote() { printf '%q' "$1"; }

transcode_one() {
  local in="$1"
  local base="${in%.*}"
  local out="${base}_noaudio.mp4"

  if [[ "$in" == *_noaudio.mp4 ]]; then
    log "SKIP (already *_noaudio): $in"
    return
  fi
  if [[ -e "$out" && $OVERWRITE -eq 0 ]]; then
    log "SKIP (exists, use --overwrite): $out"
    return
  fi

  # Scale to fit, pad to box, fix SAR
  local vf="scale=${MAX_W}:${MAX_H}:force_original_aspect_ratio=decrease,\
pad=${MAX_W}:${MAX_H}:(ow-iw)/2:(oh-ih)/2,setsar=1"

  local ff_codec=()
  if [[ "$CODEC" == "h264_videotoolbox" ]]; then
    ff_codec=(-c:v h264_videotoolbox -b:v "$BITRATE" -pix_fmt yuv420p)
  else
    ff_codec=(-c:v libx264 -preset slow -crf 23 -pix_fmt yuv420p)
  fi

  local fps_opts=()
  if [[ -n "$FPS" ]]; then
    fps_opts=(-r "$FPS" -vsync cfr)
  fi

  log "IN : $in"
  log "OUT: $out"
  log "VF : $vf"
  log "ENC: $CODEC ${FPS:+(CFR ${FPS}fps)}"

  if [[ $DRYRUN -eq 1 ]]; then
    echo "DRYRUN: ffmpeg -hide_banner -loglevel error -stats -i $(quote "$in") -map 0:v:0 -an -vf \"$vf\" ${ff_codec[*]} -movflags +faststart -threads 0 ${fps_opts[*]} -y $(quote "$out")"
    return
  fi

  nice -n 20 ffmpeg -hide_banner -loglevel error -stats \
    -i "$in" -map 0:v:0 -an \
    -vf "$vf" "${ff_codec[@]}" \
    -movflags +faststart -threads 0 \
    "${fps_opts[@]}" \
    -y "$out"

  log "DONE: $out"
}

log "Start resize (MAX=${MAX_W}x${MAX_H}, codec=${CODEC}, fps=${FPS:-keep})"

# ---- find inputs (single regex, macOS-friendly) ----
find -E . -maxdepth 1 -type f \
  -iregex '.*/.*\.(mpg|vob|m4v|mov|avi|mp4|wmv|flv|mpeg|mkv)$' \
  ! -iname '*_noaudio.mp4' \
  -print0 \
| while IFS= read -r -d '' f; do
    transcode_one "${f#./}"
  done

log "All done."
