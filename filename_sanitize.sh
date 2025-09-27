#!/opt/homebrew/bin/bash
# sanitize_filenames.sh — normalize filenames safely on macOS (Brew bash 5+).
# - Replaces [space - , ! ' # ; & [ ] ( )] with underscores
# - Collapses multiple underscores and trims leading/trailing underscores
# - Optional --lower to lowercase
# - Handles macOS case-only renames via a temp hop
# - Avoids collisions by suffixing _1, _2, ...
# - Works top-level-only (default) or --recursive
# - NUL-safe iteration; DEBUG logging; robust to set -euo pipefail

set -euo pipefail
set -o errtrace
trap 'rc=$?; echo "ERROR rc=$rc line=$LINENO cmd=${BASH_COMMAND}" >&2; exit $rc' ERR

usage() {
  cat <<'EOF'
Usage: sanitize_filenames.sh [--dir PATH] [--recursive] [--lower] [--dry-run] [--verbose] [--list-only] [--debug]

Options:
  --dir PATH     Root directory to process (default: .)
  --recursive    Recurse into subdirectories (default: top-level only)
  --lower        Lowercase the entire filename after cleanup
  --dry-run      Show what would change; do not rename
  --verbose      Extra logging (prints each file seen)
  --list-only    Only list files seen; do not rename
  --debug        Shell tracing (set -x) with PS4 markers
  -h, --help     Show this help
EOF
}

# -------------------- flags --------------------
DIR="."
RECURSIVE=0
DRY_RUN=0
LOWER=0
VERBOSE=0
LIST_ONLY=0
DEBUG_FLAG=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)       DIR="${2:-}"; shift 2 ;;
    --recursive) RECURSIVE=1; shift ;;
    --lower)     LOWER=1; shift ;;
    --dry-run)   DRY_RUN=1; shift ;;
    --verbose)   VERBOSE=1; shift ;;
    --list-only) LIST_ONLY=1; shift ;;
    --debug)     DEBUG_FLAG=1; shift ;;
    -h|--help)   usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

[[ -d "$DIR" ]] || { echo "Error: directory not found: $DIR" >&2; exit 1; }
DIR="$(cd "$DIR" && pwd -P)"

# Optional shell tracing
if (( DEBUG_FLAG )); then
  export PS4='TRACE:${BASH_SOURCE##*/}:${LINENO}: '
  set -x
fi

# -------------------- helpers --------------------
is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }
to_lower() { LC_ALL=C tr '[:upper:]' '[:lower:]' <<<"$1"; }

sanitize_name() {
  local name="$1"

  # Replace disallowed chars with underscores
  name="${name//[[:space:]]/_}"
  name="${name//-/_}"
  name="${name//,/_}"
  name="${name//\!/_}"
  name="${name//\'/_}"
  name="${name//#/_}"
  name="${name//;/_}"
  name="${name//&/_}"
  name="${name//\[/_}"
  name="${name//\]/_}"
  name="${name//\(/_}"
  name="${name//\)/_}"

  # Collapse multiple underscores
  name="$(printf '%s' "$name" | sed -E 's/_+/_/g')"

  # Trim leading/trailing underscores overall
  name="${name##_}"; name="${name%%_}"

  # If there's an extension, also trim trailing underscores from the stem specifically
  if [[ "$name" == *.* ]]; then
    local stem="${name%.*}"
    local ext="${name##*.}"
    # remove ALL trailing underscores from the stem
    stem="$(printf '%s' "$stem" | sed -E 's/_+$//')"
    name="${stem}.${ext}"
  else
    # no extension: ensure no trailing underscores remain
    name="$(printf '%s' "$name" | sed -E 's/_+$//')"
  fi

  (( LOWER )) && name="$(to_lower "$name")"

  # DEBUG
  printf '%s' "$name"
}


reserve_collision() {
  local dir="$1" base="$2" try=0 cand ext stem
  if [[ "$base" == *.* ]]; then ext="${base##*.}"; stem="${base%.*}"; else ext=""; stem="$base"; fi
  cand="$base"
  while [[ -e "$dir/$cand" ]]; do
    (( ++try ))
    if [[ -n "$ext" ]]; then cand="${stem}_$try.$ext"; else cand="${stem}_$try"; fi
  done
  printf '%s' "$cand"
}

safe_mv() {
  local src="$1" dst="$2"
  if (( DRY_RUN )); then
    echo "[DRY] $src -> $dst"
    return 0
  fi
  if is_macos; then
    local srcb="${src##*/}" dstb="${dst##*/}"
    if [[ "$srcb" != "$dstb" && "$(to_lower "$srcb")" == "$(to_lower "$dstb")" ]]; then
      # case-only rename hop for case-insensitive APFS/HFS+
      local dir="${src%/*}" tmp="$dir/.__rename_tmp_$$.$RANDOM"
      mv -- "$src" "$tmp"
      mv -- "$tmp" "$dst"
      return 0
    fi
  fi
  mv -- "$src" "$dst"
}

process_file() {
  local f="$1"
  [[ -e "$f" ]] || { echo "DEBUG: missing '$f' (skipped)" >&2 || true; return 1; }

  (( VERBOSE )) && echo "SEE: $f"
  (( LIST_ONLY )) && return 1

  local d="${f%/*}"
  local b="${f##*/}"
  local newb; newb="$(sanitize_name "$b")"

  if [[ "$b" == "$newb" ]]; then
    return 1
  fi

  local final="$newb"
  [[ -e "$d/$final" ]] && final="$(reserve_collision "$d" "$newb")"

  local dst="$d/$final"
  echo "Renaming: $f -> $dst"
  safe_mv "$f" "$dst"
  return 0
}

# Yield absolute, NUL-delimited paths for files to process.
file_stream() {
  if (( RECURSIVE )); then
    # recursive under DIR
    find "$DIR" -type f -print0
  else
    # top-level only: cd into DIR, prune subdirs, prefix to absolute (done in Bash; BSD awk can’t read NUL)
    (
      cd "$DIR" || exit 0
      while IFS= read -r -d $'\0' rel; do
        printf '%s\0' "$DIR/${rel#./}"
      done < <(find . \( -type d ! -name . -prune \) -o -type f -print0)
    )
  fi
}

# -------------------- main loop --------------------
export LC_ALL=C

pass=0
total_changes=0

echo "INFO: DIR='$DIR'  mode=$([[ $RECURSIVE -eq 1 ]] && echo recursive || echo top-level)  dry_run=$DRY_RUN lower=$LOWER"

while : ; do
  (( ++pass ))

  scanned_this_pass=0
  changes_this_pass=0

  # NUL-safe stream; append '|| true' so a find warning can't abort under -e
  while IFS= read -r -d $'\0' f; do
    (( ++scanned_this_pass ))
    if process_file "$f"; then
      (( ++changes_this_pass ))
      (( ++total_changes ))
    fi
  done < <(file_stream || true)

  # If we're in dry-run mode, do just one pass to avoid looping forever
  if (( DRY_RUN )); then
    echo "DRY-RUN: single pass complete (no files actually renamed)."
    break
  fi
  if (( changes_this_pass == 0 )); then
    break
  fi
done

echo "Done. Total changes: $total_changes over $pass pass(es)."
