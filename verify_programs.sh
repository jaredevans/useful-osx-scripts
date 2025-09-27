#!/usr/bin/env bash
# check‑signatures.sh — audit running processes’ code‑signatures
#   • skips Apple‑signed binaries (Identifier starts with com.apple)
#   • writes a trimmed block for each remaining PID to codesign.log
#   • shows one readable row‑style block per PID on stdout
# -----------------------------------------------------------------

set -euo pipefail
LOG="codesign.log"
: >"$LOG"                         # overwrite on each run

echo "Gathering code‑signature information for all running processes…"
printf "Progress: "

# Keep only these lines from codesign output
KEEP_RE='^(Executable=|Identifier=|Format=|Signature size|Authority=|Timestamp=|Runtime Version=)'

# Enumerate PID and executable path (no headers, no args)
/bin/ps -axo pid=,comm= |
while read -r pid exe; do
  [[ $pid -eq 0 || $pid -eq $$ ]] && { printf '.'; continue; }  # skip kernel & self
  [[ ! -e $exe ]] &&                { printf '.'; continue; }

  # Capture codesign output (or fallback if unsigned)
  cs_out=$(/usr/bin/codesign -d --verbose=2 "$exe" 2>&1) || \
      cs_out="codesign lookup failed (likely unsigned)"

  # Extract identifier
  ident=$(printf '%s\n' "$cs_out" | awk -F= '/^Identifier=/ {print $2; exit}')

  # Omit Apple‑signed binaries entirely
  [[ $ident == com.apple.* ]] && { printf '.'; continue; }

  # Write header plus selected lines to log
  {
    echo "----- PID $pid ($exe) -----"
    printf '%s\n' "$cs_out" | grep -E "$KEEP_RE"
  } >>"$LOG"

  printf '.'
done
echo    # newline after dots

###############################################################################
# STDOUT summary — block of rows per PID (already filtered log)
###############################################################################
awk '
  /^----- PID/ {
      if (NR>1) print "";                    # blank line between PID blocks
      pid=$3
      printf "PID:            %s\n", pid
      next
  }
  /^Executable=/      { sub(/^Executable=/,"");       printf "Executable:     %s\n", $0; next }
  /^Identifier=/      { sub(/^Identifier=/,"");       printf "Identifier:     %s\n", $0; next }
  /^Format=/          { sub(/^Format=/,"");           printf "Format:         %s\n", $0; next }
  /^Signature size=/  { sub(/^Signature size=/,"");   printf "Signature size: %s\n", $0; next }
  /^Authority=/       { sub(/^Authority=/,"");        printf "Authority:      %s\n", $0; next }
  /^Timestamp=/       { sub(/^Timestamp=/,"");        printf "Timestamp:      %s\n", $0; next }
  /^Runtime Version=/ { sub(/^Runtime Version=/,"");  printf "Runtime ver.:   %s\n", $0; next }
' "$LOG"

echo
echo "Full verbose output saved to: $LOG"

