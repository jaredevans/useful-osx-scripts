#!/bin/zsh

  # Detect current default route (may be empty if none)
  local default_if default_gw
  default_if=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
  default_gw=$(route -n get default 2>/dev/null | awk '/gateway:/{print $2}')

  local ifc ip label is_default
  for ifc in $(ifconfig -l); do
    [[ "$ifc" == "lo0" ]] && continue
    ifconfig "$ifc" 2>/dev/null | awk '$1=="inet"{print $2}' | while read -r ip; do
      [[ -z "$ip" ]] && continue

      case "$ifc:$ip" in
        bridge100:10.211.55.*) label="Parallels Shared NAT (bridge100)" ;;
        bridge101:10.37.129.*) label="Parallels Host-Only  (bridge101)" ;;
        en0:*)                 label="Wifi (en0)" ;;
        en7:*)                 label="Wired (en7)" ;;
        *)                     label="$ifc" ;;
      esac

      is_default=""
      if [[ -n "$default_if" && "$ifc" == "$default_if" ]]; then
        if [[ -n "$default_gw" ]]; then
          is_default="  [default via $default_gw]"
        else
          is_default="  [default]"
        fi
      fi

      printf '%-15s -> %s%s\n' "$ip" "$label" "$is_default"
    done
  done
