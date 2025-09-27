#!/usr/bin/env bash
#
# heic2png.sh – Convert all HEIC images in a directory to PNG.
#
# Usage:
#   ./heic2png.sh /path/to/folder          # keep HEICs
#   ./heic2png.sh -r /path/to/folder       # recurse into sub-folders
#   ./heic2png.sh -d /path/to/folder       # delete HEICs after conversion
#   ./heic2png.sh -rd /path/to/folder      # recurse + delete
#
# The script will skip any file that already has a .png counterpart.

set -euo pipefail

RECURSIVE=false
DELETE=false
USAGE="Usage: $(basename "$0") [-r] [-d] <directory>"

while getopts ":rd" opt; do
  case $opt in
    r) RECURSIVE=true ;;
    d) DELETE=true ;;
    *) echo "$USAGE" >&2; exit 1 ;;
  esac
done
shift $((OPTIND-1))

if [ $# -ne 1 ]; then
  echo "$USAGE" >&2
  exit 1
fi

TARGET_DIR=$1
if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: Directory '$TARGET_DIR' does not exist." >&2
  exit 1
fi

if ! command -v sips >/dev/null 2>&1; then
  echo "Error: 'sips' not found. It ships with macOS." >&2
  exit 1
fi

echo "Converting HEIC to PNG in: $TARGET_DIR"

# Build the find command (BSD/macOS compatible)
if [ "$RECURSIVE" = true ]; then
  # Recursive: just find all files matching case-insensitively
  FIND_CMD=(find "$TARGET_DIR" -type f \( -iname '*.heic' -o -iname '*.heif' \) -print0)
else
  # Non-recursive: prune subdirectories (BSD find has no -maxdepth)
  FIND_CMD=(find "$TARGET_DIR" \
    -type d -mindepth 1 -prune -o \
    -type f \( -iname '*.heic' -o -iname '*.heif' \) -print0)
fi

# Read with NUL delimiter to handle any filename safely
while IFS= read -r -d '' heic_file; do
  png_file="${heic_file%.*}.png"

  if [ -e "$png_file" ]; then
    echo "Skipping (PNG already exists): $heic_file"
    continue
  fi

  echo "Converting: $heic_file → $png_file"
  if ! sips -s format png "$heic_file" --out "$png_file" >/dev/null; then
    echo "❌ Failed to convert: $heic_file" >&2
    continue
  fi

  if [ "$DELETE" = true ]; then
    echo "Deleting original: $heic_file"
    rm -f -- "$heic_file"
  fi
done < <("${FIND_CMD[@]}")

echo "Done."
