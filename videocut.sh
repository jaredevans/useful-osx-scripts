#!/bin/zsh

  if [[ $# -lt 2 ]]; then
    echo "Usage: videocut START_TIME [END_TIME] INPUT_FILE"
    echo "Examples:"
    echo "  videocut 00:01:23 myvideo.mp4"
    echo "  videocut 00:01:23 00:02:45 myvideo.mp4"
    return 1
  fi

  local start_time="$1"
  local end_time=""
  local input=""
  local base ext output

  # case: 2 args (start + input)
  if [[ $# -eq 2 ]]; then
    input="$2"
  elif [[ $# -eq 3 ]]; then
    end_time="$2"
    input="$3"
  else
    echo "Too many arguments"
    return 1
  fi

  base="${input%.*}"
  ext="${input##*.}"

  # clean times for filename (remove colons)
  local clean_start="${start_time//:/}"
  if [[ -n "$end_time" ]]; then
    local clean_end="${end_time//:/}"
    output="${base}_${clean_start}-${clean_end}.${ext}"
    ffmpeg -ss "$start_time" -to "$end_time" -i "$input" -c copy "$output"
  else
    output="${base}_${clean_start}-end.${ext}"
    ffmpeg -ss "$start_time" -i "$input" -c copy "$output"
  fi

  echo "Created: $output"
