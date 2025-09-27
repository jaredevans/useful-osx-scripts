#!/usr/bin/env zsh
# Show PID, listening TCP ports, IP/interface, and full command line
# macOS version – uses only lsof + ps
# Requires: lsof, ps

set -e
set -u
setopt pipefail

typeset -A ADDRS   # pid -> "127.0.0.1:80,0.0.0.0:22"
typeset -A SEEN    # dedupe pid:addr:port

add_addr_port() {
  local pid addrport key
  pid="$1"
  addrport="$2"
  key="${pid}:${addrport}"

  if [[ ${+SEEN[$key]} -eq 0 ]]; then
    SEEN[$key]=1
    if [[ ${+ADDRS[$pid]} -eq 0 || -z "${ADDRS[$pid]:-}" ]]; then
      ADDRS[$pid]="$addrport"
    else
      case ",${ADDRS[$pid]}," in
        *",$addrport,"*) ;;                          # already present
        *) ADDRS[$pid]="${ADDRS[$pid]},$addrport" ;; # append
      esac
    fi
  fi
}

# ---- From lsof (macOS): map pid -> addr:port ----
lsof_cmd_output=$(
  lsof -nP -iTCP -sTCP:LISTEN -FpFn 2>/dev/null \
  || sudo lsof -nP -iTCP -sTCP:LISTEN -FpFn 2>/dev/null
)

current_pid=""
while IFS= read -r line; do
  case "$line" in
    p*) current_pid="${line#p}" ;;
    n*)
      [[ -z "${current_pid}" ]] && continue
      addrport="${line#n}"
      port="${addrport##*:}"
      [[ "$port" == <-> ]] || continue   # ensure numeric port
      add_addr_port "$current_pid" "$addrport"
      ;;
  esac
done <<< "$lsof_cmd_output"

# ---- Print header ----
printf "%-8s  %-25s  %-s\n" "PID" "ADDR:PORT(S)" "COMMAND"
printf "%-8s  %-25s  %-s\n" "--------" "-------------------------" "----------------------------------------"

# ---- Print per PID ----
for pid in $(printf "%s\n" ${(k)ADDRS} | sort -n); do
  if cmd=$(ps -p "$pid" -o command= 2>/dev/null); then
    [[ -z "$cmd" ]] && continue
    printf "%-8s  %-25s  %-s\n" "$pid" "${ADDRS[$pid]}" "$cmd"
  fi
done
