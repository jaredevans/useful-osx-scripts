#!/bin/bash
# Transcribe/translate using whisper-cli (ggml models with Metal GPU).
# Usage: ./transcribe.sh <video_file> [language]
#   <video_file> : Path to video/audio file
#   [language]   : Optional source language code:
#                    - "auto" → auto-detect then transcribe/translate
#                    - "en"   → transcribe English with medium.en
#                    - other  → translate that language into English
#
# Env overrides:
#   MODEL_DIR        default: $HOME/.models/whisper
#   MODEL_MEDIUM_EN  default: $MODEL_DIR/ggml-medium.en.bin
#   MODEL_LARGE_V2   default: $MODEL_DIR/ggml-large-v2.bin
#   WHISPER_BIN      default: whisper-cli (on PATH)
#   WCLI_THREADS     default: all CPUs
#
# Requires: ffmpeg, whisper-cli
#
# Example:
#   transcribe.sh clip.mp4 en       # English transcription
#   transcribe.sh clip.mp4 fr       # French → English translation
#   transcribe.sh clip.mp4 auto     # Detect language, then choose model

set -euo pipefail

# --- Args ---
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Usage: $0 <video_file> [language]" >&2
  exit 1
fi
VIDEO_FILE="$1"
LANGUAGE="${2:-}"

if [ ! -f "$VIDEO_FILE" ]; then
  echo "Error: File '$VIDEO_FILE' not found." >&2
  exit 1
fi

# --- Binaries ---
WHISPER_BIN="${WHISPER_BIN:-whisper-cli}"
if ! command -v "$WHISPER_BIN" >/dev/null 2>&1; then
  echo "Error: '$WHISPER_BIN' not found on PATH." >&2
  echo "Install via Homebrew:  brew install whisper-cpp" >&2
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Error: 'ffmpeg' not found on PATH." >&2
  echo "Install via Homebrew:  brew install ffmpeg" >&2
  exit 1
fi

# --- Models ---
MODEL_DIR="${MODEL_DIR:-$HOME/.models/whisper}"
MODEL_MEDIUM_EN="${MODEL_MEDIUM_EN:-$MODEL_DIR/ggml-medium.en.bin}"
MODEL_LARGE_V2="${MODEL_LARGE_V2:-$MODEL_DIR/ggml-large-v2.bin}"

# --- Threads ---
if command -v sysctl >/dev/null 2>&1; then
  DEFAULT_THREADS="$(sysctl -n hw.ncpu)"
else
  DEFAULT_THREADS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
fi
WCLI_THREADS="${WCLI_THREADS:-$DEFAULT_THREADS}"

# --- Paths ---
BASENAME="$(basename "$VIDEO_FILE" | sed 's/\.[^.]*$//')"
DIRNAME="$(dirname "$VIDEO_FILE")"
OUTPUT_SRT="$DIRNAME/$BASENAME.srt"
TEMP_AUDIO="/tmp/${BASENAME}_temp_audio.wav"
OUT_PREFIX="/tmp/${BASENAME}_temp_audio"
TEMP_SRT="${OUT_PREFIX}.srt"

# --- Audio extraction ---
echo "Extracting audio from '$VIDEO_FILE' -> '$TEMP_AUDIO'..."
if ! ffmpeg -y -i "$VIDEO_FILE" -vn -acodec pcm_s16le -ar 16000 -ac 1 "$TEMP_AUDIO" >/dev/null 2>&1; then
  echo "Error: Failed to extract audio." >&2
  rm -f "$TEMP_AUDIO"
  exit 1
fi

# --- Ensure model exists ---
need_model=""
case "$LANGUAGE" in
  ""|"en") [ -f "$MODEL_MEDIUM_EN" ] || need_model="medium.en" ;;
  "auto"|*) [ -f "$MODEL_LARGE_V2" ] || need_model="large-v2" ;;
esac

if [ -n "$need_model" ]; then
  echo "Error: Required model not found: $need_model" >&2
  echo "Download to $MODEL_DIR, e.g.:" >&2
  echo "  mkdir -p \"$MODEL_DIR\"" >&2
  if [ "$need_model" = "medium.en" ]; then
    echo "  curl -L -o \"$MODEL_MEDIUM_EN\" https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin" >&2
  else
    echo "  curl -L -o \"$MODEL_LARGE_V2\" https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v2.bin" >&2
  fi
  rm -f "$TEMP_AUDIO"
  exit 1
fi

# --- Transcribe/translate ---
set +e
status=0

if [ -z "$LANGUAGE" ] || [ "$LANGUAGE" = "en" ]; then
  echo "Transcribing English with medium.en -> '$OUTPUT_SRT' ..."
  "$WHISPER_BIN" \
    -m "$MODEL_MEDIUM_EN" \
    -f "$TEMP_AUDIO" \
    -l en \
    -osrt \
    -of "$OUT_PREFIX" \
    -t "$WCLI_THREADS"
  status=$?

elif [ "$LANGUAGE" = "auto" ]; then
  echo "Auto-detecting language..."
  DET_LINE="$("$WHISPER_BIN" -m "$MODEL_LARGE_V2" -dl -f "$TEMP_AUDIO" -t "$WCLI_THREADS" -np 2>&1 \
             | tee /dev/stderr \
             | sed -n 's/.*auto-detected language: \([a-z][a-z]\) (p = \([0-9.]*\)).*/\1 \2/p')"
  DET_LANG="$(printf '%s\n' "$DET_LINE" | awk '{print $1}')"
  DET_PROB="$(printf '%s\n' "$DET_LINE" | awk '{print $2}')"

  if [ -z "${DET_LANG:-}" ]; then
    echo "Warn: could not parse detected language; defaulting to translate -> English." >&2
    DET_LANG="auto"
  else
    echo "Detected language: $DET_LANG (p=$DET_PROB)"
  fi

  if [ "$DET_LANG" = "en" ]; then
    echo "Source is English; transcribing with medium.en -> '$OUTPUT_SRT' ..."
    "$WHISPER_BIN" \
      -m "$MODEL_MEDIUM_EN" \
      -f "$TEMP_AUDIO" \
      -l en \
      -osrt \
      -of "$OUT_PREFIX" \
      -t "$WCLI_THREADS"
    status=$?
  else
    echo "Translating from '$DET_LANG' -> English with large-v2 -> '$OUTPUT_SRT' ..."
    "$WHISPER_BIN" \
      -m "$MODEL_LARGE_V2" \
      -f "$TEMP_AUDIO" \
      -l "$DET_LANG" \
      -tr \
      -osrt \
      -of "$OUT_PREFIX" \
      -t "$WCLI_THREADS"
    status=$?
  fi

else
  echo "Translating from '$LANGUAGE' -> English with large-v2 -> '$OUTPUT_SRT' ..."
  "$WHISPER_BIN" \
    -m "$MODEL_LARGE_V2" \
    -f "$TEMP_AUDIO" \
    -l "$LANGUAGE" \
    -tr \
    -osrt \
    -of "$OUT_PREFIX" \
    -t "$WCLI_THREADS"
  status=$?
fi
set -e

if [ $status -ne 0 ]; then
  echo "Error: whisper-cli failed (exit $status)." >&2
  rm -f "$TEMP_AUDIO"
  exit $status
fi

# --- Move SRT into place ---
if [ -f "$TEMP_SRT" ]; then
  mv -f "$TEMP_SRT" "$OUTPUT_SRT"
  echo "SRT created: $OUTPUT_SRT"
else
  echo "Error: Expected SRT not found at $TEMP_SRT" >&2
fi

# --- Cleanup ---
rm -f "$TEMP_AUDIO"
echo "Done."
