#!/bin/zsh

  setopt localoptions null_glob

  # Allow custom output name: videomerge [output.mp4]
  local out=${1:-merged.mp4}

  # Collect .mp4 files (sorted by name). Adjust glob/sort as you like.
  local -a files
  files=(*.mp4(N))   # (N) = null_glob behavior in array context
  if (( ${#files[@]} < 2 )); then
    print -r -- "Need at least 2 .mp4 files in the current directory."
    return 1
  fi

  # BSD mktemp: use -t with a prefix; it returns a unique path.
  # (No .txt suffix — concat demuxer doesn't care about extension.)
  local listfile
  listfile=$(mktemp -t videomerge) || { print -r -- "mktemp failed"; return 1; }

  # Write concat list, escaping single quotes for ffmpeg's concat demuxer
  {
    local f esc
    for f in "${files[@]}"; do
      # Absolute path & escape any single quotes: ' => '\''
      esc=${PWD}/${f}
      esc=${esc//\'/\'\\\'\'}   # zsh substitution
      print -r -- "file '$esc'"
    done
  } > "$listfile"

  # Run ffmpeg concat (stream copy). Add -safe 0 for absolute paths.
  ffmpeg -hide_banner -loglevel error \
         -f concat -safe 0 -i "$listfile" -c copy "$out"
  local rc=$?

  rm -f -- "$listfile"

  if (( rc == 0 )); then
    print -r -- "Created: $out"
  else
    print -r -- "ffmpeg failed (exit $rc)."
  fi
  return $rc
