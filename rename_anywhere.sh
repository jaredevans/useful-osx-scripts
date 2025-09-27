#!/opt/homebrew/bin/bash
# rename_any.sh — replace ANY occurrence of OLD → NEW in basenames
# NUL-safe stream; multi-pass unless NEW contains OLD (then single pass).
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
read -r -p "what to replace: " OLD
read -r -p "what to use instead: " NEW
[[ -z "$OLD" || -z "$NEW" ]] && { echo "Both OLD and NEW must be non-empty."; exit 1; }

# Normalize DIR to absolute
[[ "$DIR" = /* ]] || DIR="$(cd "$DIR" && pwd)"

# If NEW contains OLD, a multi-pass would grow names forever → force single pass
SINGLE_PASS=0
if [[ "$NEW" == *"$OLD"* ]]; then
  SINGLE_PASS=1
fi

# -------------------- helpers --------------------
process_file() {
  local path=$1
  local base=${path##*/}
  local dir=${path%/*}
  [[ $dir == "$path" ]] && dir="."

  if [[ $base == *"$OLD"* ]]; then
    local newbase=${base//"$OLD"/"$NEW"}   # replace ALL occurrences (basename only)
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


  # Stop after first pass if DRY_RUN or SINGLE_PASS is set
  if (( DRY_RUN || SINGLE_PASS )); then
    (( DRY_RUN )) && echo "DRY-RUN: single pass complete."
    (( SINGLE_PASS )) && echo "SINGLE-PASS: prevented name growth (NEW contains OLD)."
    break
  fi

  (( changes_this_pass == 0 )) && break
done

echo
echo "Done. Total changes: $total_changes"
