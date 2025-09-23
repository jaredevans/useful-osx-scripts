#!/bin/zsh

# This script displays information about the system's network connections,
# including public and private IP addresses, and network interfaces.

# Check for public internet connectivity by fetching the public IP address.
# It uses curl with a short timeout to avoid long waits.
if curl -s --max-time 1 https://api.ipify.org >/tmp/pubip 2>/dev/null; then
  echo "Connected to public Internet: $(cat /tmp/pubip)"
else
  echo "Not connected to public Internet."
fi

# Remove any existing alias for net-show-inet4 to ensure the function is defined correctly.
unalias net-show-inet4 2>/dev/null

# This function lists all IPv4 addresses associated with the system's network interfaces.
net-show-inet4() {
  # Detect the current default route to identify the primary network interface.
  # The 'route' command is used to get the default route information.
  local default_if default_gw
  default_if=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
  default_gw=$(route -n get default 2>/dev/null | awk '/gateway:/{print $2}')

  local ifc ip label is_default
  # Loop through all network interfaces listed by 'ifconfig -l'.
  for ifc in $(ifconfig -l); do
    # Skip the loopback interface 'lo0' as it's not relevant for external connectivity.
    [[ "$ifc" == "lo0" ]] && continue
    # For each interface, get its IPv4 address.
    ifconfig "$ifc" 2>/dev/null | awk '$1=="inet"{print $2}' | while read -r ip; do
      # Skip if the IP address is empty.
      [[ -z "$ip" ]] && continue

      # Assign a human-readable label to the interface based on its name and IP address.
      case "$ifc:$ip" in
        bridge100:10.211.55.*) label="Parallels Shared NAT (bridge100)" ;;
        bridge101:10.37.129.*) label="Parallels Host-Only  (bridge101)" ;;
        en0:*)                 label="Wifi (en0)" ;;
        en7:*)                 label="Wired (en7)" ;;
        *)                     label="$ifc" ;;
      esac

      is_default=""
      # Check if the current interface is the default one.
      if [[ -n "$default_if" && "$ifc" == "$default_if" ]]; then
        # If it is, mark it as the default route and show the gateway if available.
        if [[ -n "$default_gw" ]]; then
          is_default="  [default via $default_gw]"
        else
          is_default="  [default]"
        fi
      fi

      # Print the formatted output showing the IP address, label, and default route status.
      printf '%-15s -> %s%s\n' "$ip" "$label" "$is_default"
    done
  done
}

echo "Private: "
net-show-inet4
