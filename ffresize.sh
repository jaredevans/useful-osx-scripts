#!/usr/bin/env bash
# Resize/transcode videos to MAX_W×MAX_H MP4 (WITH audio) as *_mobile.mp4
# Default: macOS hardware encoding (h264_videotoolbox) @ 29.97fps.
# Safe with spaces; skips existing outputs unless --overwrite.

set -Eeuo pipefail

# ---- defaults ----
MAX_W=960
MAX_H=540
FPS="30000/1001"          # default: force 29.97 fps
CODEC="h264_videotoolbox" # default macOS HW encode
BITRATE="2500k"           # video target bitrate (HW encoders don't use CRF)
AUDIO_MODE="aac"          # aac | copy
AUDIO_BR="160k"           # aac bitrate when AUDIO_MODE=aac
SUFFIX="_mobile"          # output suffix before .mp4
OVERWRITE=0
DRYRUN=0

# ---- parse args ----
while [[ $# -gt 0 ]]; do
  case "$1" in
    --width)     MAX_W="${2:?}"; shift 2 ;;
    --height)    MAX_H="${2:?}"; shift 2 ;;
    --fps)       FPS="${2:?}";   shift 2 ;;
    --bitrate)   BITRATE="${2:?}"; shift 2 ;;
    --codec)     CODEC="${2:?}"; shift 2 ;; # h264_videotoolbox | libx264
    --audio-copy) AUDIO_MODE="copy"; shift ;;
    --audio-aac)  AUDIO_MODE="aac";  shift ;;
    --audio-br)   AUDIO_BR="${2:?}"; shift 2 ;;
    --suffix)     SUFFIX="${2:?}";   shift 2 ;;
    --dry-run)    DRYRUN=1; shift ;;
    --overwrite)  OVERWRITE=1; shift ;;
    -h|--help)
      cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --width N        Max width (default $MAX_W)
  --height N       Max height (default $MAX_H)
  --fps N          Force constant frame rate (default $FPS)
  --bitrate N      Video target bitrate (default $BITRATE, for HW encode)
  --codec NAME     h264_videotoolbox (default) or libx264
  --audio-copy     Copy source audio stream (no transcode; may fail for non-MP4-safe codecs)
  --audio-aac      Transcode audio to AAC (default) with --audio-br
  --audio-br N     AAC bitrate, e.g. 128k/160k/192k (default $AUDIO_BR)
  --suffix STR     Output suffix before .mp4 (default "$SUFFIX")
  --dry-run        Show ffmpeg commands only
  --overwrite      Overwrite existing *\${SUFFIX}.mp4 outputs
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
  local out="${base}${SUFFIX}.mp4"

  if [[ "$in" == *"${SUFFIX}.mp4" ]]; then
    log "SKIP (already *${SUFFIX}.mp4): $in"
    return
  fi
  if [[ -e "$out" && $OVERWRITE -eq 0 ]]; then
    log "SKIP (exists, use --overwrite): $out"
    return
  fi

  # Scale to fit, pad to box, fix SAR
  local vf="scale=${MAX_W}:${MAX_H}:force_original_aspect_ratio=decrease,\
pad=${MAX_W}:${MAX_H}:(ow-iw)/2:(oh-ih)/2,setsar=1"

  # Video codec
  local vcodec=()
  if [[ "$CODEC" == "h264_videotoolbox" ]]; then
    vcodec=(-c:v h264_videotoolbox -b:v "$BITRATE" -pix_fmt yuv420p)
  else
    vcodec=(-c:v libx264 -preset slow -crf 23 -pix_fmt yuv420p)
  fi

  # Audio codec
  local acodec=()
  if [[ "$AUDIO_MODE" == "copy" ]]; then
    acodec=(-c:a copy)
  else
    acodec=(-c:a aac -b:a "$AUDIO_BR")
  fi

  # FPS (always applied; default is 29.97fps)
  local fps_opts=(-r "$FPS" -vsync cfr)

  log "IN : $in"
  log "OUT: $out"
  log "VF : $vf"
  log "VID: $CODEC @ ${BITRATE}, FPS=$FPS"
  log "AUD: ${AUDIO_MODE}${AUDIO_MODE/aac/ (AAC $AUDIO_BR)}"

  if [[ $DRYRUN -eq 1 ]]; then
    echo "DRYRUN: ffmpeg -hide_banner -loglevel error -stats -i $(quote "$in") -map 0:v:0 -map 0:a? -vf \"$vf\" ${vcodec[*]} ${acodec[*]} -movflags +faststart -threads 0 ${fps_opts[*]} -y $(quote "$out")"
    return
  fi

  nice -n 20 ffmpeg -hide_banner -loglevel error -stats \
    -i "$in" \
    -map 0:v:0 -map 0:a? \
    -vf "$vf" \
    "${vcodec[@]}" \
    "${acodec[@]}" \
    -movflags +faststart -threads 0 \
    "${fps_opts[@]}" \
    -y "$out"

  log "DONE: $out"
}

log "Start resize (MAX=${MAX_W}x${MAX_H}, codec=${CODEC}, fps=$FPS, audio=${AUDIO_MODE})"

# ---- find inputs (single regex, macOS-friendly) ----
find -E . -maxdepth 1 -type f \
  -iregex '.*/.*\.(mpg|vob|m4v|mov|avi|mp4|wmv|flv|rmvb|mpeg|mkv)$' \
  ! -iname "*${SUFFIX}.mp4" \
  -print0 \
| while IFS= read -r -d '' f; do
    transcode_one "${f#./}"
  done

log "All done."
