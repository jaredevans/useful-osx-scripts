#!/bin/sh
# Show corresponding apps with the network connections they are listening on or actively using (macOS).

# Print header
printf '%-6s %-28s %-55s %-12s %-7s %s\n' "Proto" "Local" "Address" "State" "PID" "CMDLINE"

tab=$(printf '\t')

sudo netstat -Wav -f inet \
| awk -v OFS='\t' '
  /^Proto/ || /including/ || /Active/ || /^Proto\/ID/ { next }   # skip headers
  {
    pid = "";
    for (i = NF; i >= 1; i--) {
      if ($i ~ /:[0-9]+$/) { split($i,a,":"); pid=a[2]; break }
    }
    if (pid == "") next;
    st = $6;
    if ($1 ~ /^udp/) st = "-";
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
    printf '%-6s %-28s %-55s %-12s %-7s %s\n' \
      "$proto" "$laddr" "$faddr" "$state" "$pid" "$cmdline"
  done \
| sort -k6
