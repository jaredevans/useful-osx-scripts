#!/opt/homebrew/bin/bash
# rename_start.sh — rename files whose basename starts with OLD → NEW
# Supports top-level or recursive mode, NUL-safe multi-pass loop.

set -Eeuo pipefail

# -------------------- defaults / flags --------------------
RECURSIVE=0
DRY_RUN=0
DIR="$PWD"

usage() {
  echo "Usage: $(basename "$0") [-r] [-n] [-C DIR]" >&2
  exit 1
}

while getopts ":rnC:" opt; do
  case "$opt" in
    r) RECURSIVE=1 ;;
    n) DRY_RUN=1 ;;
    C) DIR=$OPTARG ;;
    *) usage ;;
  esac
done
shift $((OPTIND-1))

# -------------------- interactive prompts --------------------
read -r -p "starting name to replace: " OLD
read -r -p "starting name to use instead: " NEW
[[ -z "$OLD" || -z "$NEW" ]] && { echo "Both OLD and NEW must be non-empty."; exit 1; }

# Normalize DIR to absolute
if [[ ! "$DIR" = /* ]]; then
  DIR="$(cd "$DIR" && pwd)"
fi

# -------------------- helpers --------------------
process_file() {
  local path=$1
  local base=${path##*/}   # basename
  local dir=${path%/*}
  [[ $dir == "$path" ]] && dir="."

  if [[ $base == "$OLD"* ]]; then
    local newbase=${base/#$OLD/$NEW}
    local newpath="$dir/$newbase"

    [[ "$newpath" == "$path" ]] && return 1
    if [[ -e "$newpath" ]]; then
      echo "SKIP (exists): '$path' -> '$newpath'"
      return 1
    fi

    if (( DRY_RUN )); then
      echo "[DRY] mv '$path' '$newpath'"
    else
      echo "mv '$path' '$newpath'"
      mv "$path" "$newpath"
    fi
    return 0
  fi
  return 1
}

file_stream() {
  if (( RECURSIVE )); then
    find "$DIR" -type f -print0
  else
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

echo

while : ; do
  (( ++pass ))
  scanned_this_pass=0
  changes_this_pass=0

  while IFS= read -r -d $'\0' f; do
    (( ++scanned_this_pass ))
    if process_file "$f"; then
      (( ++changes_this_pass, ++total_changes ))
    fi
  done < <(file_stream || true)


  (( DRY_RUN )) && { echo "DRY-RUN: single pass complete."; break; }
  (( changes_this_pass == 0 )) && break
done

echo
echo "Done. Total changes: $total_changes"
