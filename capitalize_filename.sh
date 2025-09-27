#!/usr/bin/env zsh
# Capitalize each word in filenames, treating underscores, periods, and hyphens as boundaries.
# Keeps original separators and handles case-only renames on macOS. Safe with collisions.

set -eu

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

# Capitalize tokens while preserving separators; leave pure numbers unchanged.
cap_words() {
  perl -pe '
    s{([^_.\-]+)}{
      ($w=$1) =~ /^[0-9]+$/ ? $w :
      ucfirst(lc($w))
    }ge
  '
}

# Extract final extension (treat .tar.gz as a unit)
get_ext() {
  # if it looks like .tar.gz, preserve both; else last suffix
  [[ "$1" =~ \.tar\.gz$ ]] && { print -r -- "tar.gz"; return; }
  print -r -- "${1##*.}"
}

# Strip final extension (aware of .tar.gz)
strip_ext() {
  [[ "$1" =~ \.tar\.gz$ ]] && { print -r -- "${1%.tar.gz}"; return; }
  print -r -- "${1%.*}"
}

for f in *.*; do
  [[ -f "$f" ]] || continue

  base=$(strip_ext "$f")
  ext=$(get_ext "$f")

  new_base=$(printf "%s" "$base" | cap_words)
  new_name="${new_base}.${ext}"

  [[ "$f" = "$new_name" ]] && continue

  # On macOS, avoid clobber + case-only rename issues
  if [[ -e "$new_name" && "${f:l}" != "${new_name:l}" ]]; then
    echo "Skip (exists): $new_name"
    continue
  fi

  echo "Renaming: $f -> $new_name"
  if (( DRY_RUN )); then
    continue
  fi

  tmp=".__rename_tmp_${RANDOM}_$$.${ext}"
  mv -- "$f" "$tmp"
  mv -n -- "$tmp" "$new_name"
done
