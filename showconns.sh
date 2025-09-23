#!/bin/sh
# Show corresponding apps with the network connections they are listening on or actively using (macOS).

# Print header
printf '%-6s %-28s %-55s %-12s %-7s %s\n' "Proto" "Local" "Address" "State" "PID" "CMDLINE"

# We:
# 1) Run netstat -Wav -f inet (shows process:pid)
# 2) In awk, scan each line from the end to find the token matching /:[0-9]+$/ (the PID)
# 3) Print a clean, 5-field line: proto, local, foreign, state, pid (tab-delimited)
# 4) Read those fields and use ps to get the full command, truncated if longer than 101 chars
tab=$(printf '\t')

sudo netstat -Wav -f inet \
| awk -v OFS='\t' '
  /^Proto/ || /including/ || /Active/ || /^Proto\/ID/ { next }   # skip headers
  {
    pid = "";
    for (i = NF; i >= 1; i--) {
      if ($i ~ /:[0-9]+$/) { split($i,a,":"); pid=a[2]; break }
    }
    if (pid == "") next;                      # skip lines without a pid (just in case)
    st = $6;                                  # TCP has a state here; UDP will often have 0
    if ($1 ~ /^udp/) st = "-";                # make UDP state prettier
    print $1, $4, $5, st, pid
  }
' \
| sort -u \
| while IFS="$tab" read -r proto laddr faddr state pid; do
    fullcmd=$(ps -p "$pid" -o command= 2>/dev/null)
    if [ ${#fullcmd} -gt 101 ]; then
      cmdline="${fullcmd:0:101}..."
    else
      cmdline="$fullcmd"
    fi
    [ -z "$cmdline" ] && cmdline="(exited)"
    printf '%-6s %-28s %-55s %-12s %-7s %s\n' "$proto" "$laddr" "$faddr" "$state" "$pid" "$cmdline"
  done
