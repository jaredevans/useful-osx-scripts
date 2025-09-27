#!/bin/sh
# Show corresponding apps with the network connections they are listening on or actively using (macOS).

# Print header
printf '%-6s %-28s %-38s %-12s %-7s %s\n' "Proto" "Local" "Address" "State" "PID" "CMDLINE"

tab=$(printf '\t')

sudo netstat -Wav -f inet \
| awk -v OFS='\t' '
  /^Proto/ || /including/ || /Active/ || /^Proto\/ID/ { next }   # skip headers
  {
    pid = $11                 # PID is column 11 with -W
    if (pid == "" || pid == "0") next

    st = $6                   # (state) column
    if ($1 ~ /^udp/) st = (st=="" ? "-" : st)

    print $1, $4, $5, st, pid # proto, local, foreign, state, pid
  }
' \
| sort -u \
| while IFS="$(printf '\t')" read -r proto laddr faddr state pid; do
    # Truncate foreign address to 28 chars
    if [ ${#faddr} -gt 32 ]; then
      faddr="${faddr:0:32}..."
    fi

    fullcmd=$(ps -p "$pid" -o command= 2>/dev/null)
    if [ ${#fullcmd} -gt 101 ]; then
      cmdline="${fullcmd:0:101}..."
    else
      cmdline="$fullcmd"
    fi
    [ -z "$cmdline" ] && cmdline="(exited)"
    printf '%-6s %-28s %-38s %-12s %-7s %s\n' \
      "$proto" "$laddr" "$faddr" "$state" "$pid" "$cmdline"
  done \
| sort -k6
