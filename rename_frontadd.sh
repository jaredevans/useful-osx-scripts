#!/usr/bin/env bash
set -Eeuo pipefail

read -r -p "Prefix to add to the front of all files: " prefix
[[ -z "${prefix}" ]] && { echo "Empty prefix; aborting."; exit 1; }

echo "Renaming in: $PWD"
echo

shopt -s nullglob dotglob   # include dotfiles; remove 'dotglob' if you don't want hidden files
for f in *; do
  # skip directories; remove this 'if' if you want to rename dirs too
  [[ -d "$f" ]] && continue

  # skip if already has the prefix
  [[ "$f" == "$prefix"* ]] && continue

  new="${prefix}${f}"

  if [[ -e "$new" ]]; then
    echo "SKIP (exists): '$f' -> '$new'"
    continue
  fi

  echo "mv -- '$f' '$new'"
  mv -- "$f" "$new"
done
