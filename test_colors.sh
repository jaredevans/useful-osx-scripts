#!/bin/bash

echo "=== TEXT STYLES DEMO ==="

styles=(0 1 2 3 4 5 7)
style_names=("Normal" "Bold" "Dim" "Italic" "Underline" "Blink" "Inverse")

echo "ANSI Escape Sequence: "
for idx in "${!styles[@]}"; do
  code=${styles[$idx]}
  name=${style_names[$idx]}
  printf "\e[%sm%-12s\e[0m " "$code" "$name"
done
echo

echo "tput:"
for idx in "${!styles[@]}"; do
  code=${styles[$idx]}
  name=${style_names[$idx]}
  # Map style codes to tput commands
  case $code in
    0) tput_code="$(tput sgr0)" ;;
    1) tput_code="$(tput bold)" ;;
    2) tput_code="$(tput dim)" ;;
    3) tput_code="$(tput sitm 2>/dev/null || true)" ;;   # 'sitm' for italics, not always available
    4) tput_code="$(tput smul)" ;;
    5) tput_code="$(tput blink)" ;;
    7) tput_code="$(tput rev)" ;;
    *) tput_code="" ;;
  esac
  printf "%s%-12s%s " "$tput_code" "$name" "$(tput sgr0)"
done
echo -e "\n"

echo "=== 256 COLORS DEMO (FOREGROUND) ==="
echo "ANSI Escape Sequence:"
for i in {0..255}; do
  printf "\e[38;5;%sm%3d\e[0m " "$i" "$i"
  (( (i+1) % 16 == 0 )) && echo
done

# Check for 256 color support
if [[ "$(tput colors)" -lt 256 ]]; then
  echo "Your terminal does not support 256 colors (tput colors = $(tput colors))."
  echo "Try running: export TERM=xterm-256color"
  exit 1
fi

echo -e "\n"
echo "tput 256 color palette (foreground):"
for i in {0..255}; do
  printf "$(tput setaf $i)%3d$(tput sgr0) " "$i"
  (( (i+1) % 16 == 0 )) && echo
done

echo -e "\n"

echo "tput 256 color palette (background):"
for i in {0..255}; do
  printf "$(tput setab $i)%3d$(tput sgr0) " "$i"
  (( (i+1) % 16 == 0 )) && echo
done


echo -e "\n"
echo "=== STYLE + COLOR COMBOS ==="
echo "ANSI Escape Sequence:"
printf "  \e[1;4;38;5;196mBold Underline Red\e[0m\n"
printf "  \e[3;48;5;33mItalic on blue background\e[0m\n"

echo "tput:"
bold=$(tput bold)
italic=$(tput sitm)
underline=$(tput smul)
red_fg=$(tput setaf 197)
blue_bg=$(tput setab 33)
reset=$(tput sgr0)
printf "  %s%s%sBold Underline Red%s\n" "$bold" "$underline" "$red_fg" "$reset"
# Italic support in tput is iffy; we'll skip that for tput.
printf "  %s%sItalic on blue background%s\n" "$italic" "$blue_bg" "$reset"

echo
echo "Done!"

