#!/usr/bin/env bash
# Wi-Fi menu (rofi, Catppuccin) built on nmcli. Same look as the Mod+P power menu.
theme="$HOME/.config/rofi/catppuccin.rasi"

menu() {   # menu PROMPT LINES [extra rofi args...]   (items on stdin, prints the chosen index)
  local prompt="$1" lines="$2"; shift 2
  rofi -dmenu -i -format i -p "$prompt" -theme "$theme" \
    -theme-str "window { width: 520px; } listview { lines: $lines; }" "$@"
}

command -v nmcli >/dev/null || { notify-send "Wi-Fi" "nmcli (NetworkManager) not found"; exit 1; }

# --- Wi-Fi switched off: only offer to turn it on
if [ "$(nmcli radio wifi)" = "disabled" ]; then
  c=$(printf '%s\n' "󰖩  Turn Wi-Fi on" | menu "Wi-Fi" 1)
  [ "$c" = "0" ] && nmcli radio wifi on && notify-send "Wi-Fi" "Turned on"
  exit 0
fi

# --- list networks (strongest first, one line per SSID)
declare -A seen
items=(); ssids=(); secure=(); active=()
while IFS=: read -r inuse signal sec ssid; do
  ssid=${ssid//\\:/:}
  [ -z "$ssid" ] && continue
  [ -n "${seen[$ssid]}" ] && continue
  seen[$ssid]=1
  icon="󰤟"
  [ "${signal:-0}" -ge 40 ] && icon="󰤢"
  [ "${signal:-0}" -ge 60 ] && icon="󰤥"
  [ "${signal:-0}" -ge 80 ] && icon="󰤨"
  lock=""; sc=0
  if [ -n "$sec" ] && [ "$sec" != "--" ]; then lock="  󰌾"; sc=1; fi
  mark="  "; ac=0
  if [ "$inuse" = "*" ]; then mark="󰄬 "; ac=1; fi
  items+=("$mark$icon  $ssid$lock"); ssids+=("$ssid"); secure+=("$sc"); active+=("$ac")
done < <(nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID dev wifi list 2>/dev/null | sort -t: -k2 -nr)

count=${#items[@]}
actions=("󰑐  Rescan" "󰖪  Turn Wi-Fi off" "󰒓  Advanced settings")
lines=$((count + 3)); [ $lines -gt 10 ] && lines=10

sel=$(printf '%s\n' "${items[@]}" "${actions[@]}" | sed '/^$/d' | menu "Wi-Fi" "$lines")
[ -z "$sel" ] && exit 0

# --- actions (after the networks)
if [ "$sel" -ge "$count" ]; then
  case $((sel - count)) in
    0) nmcli dev wifi rescan >/dev/null 2>&1; sleep 2; exec "$0" ;;
    1) nmcli radio wifi off; notify-send "Wi-Fi" "Turned off" ;;
    2) exec kitty --class nmtui-float -e nmtui ;;
  esac
  exit 0
fi

ssid="${ssids[$sel]}"

# --- already connected: offer to disconnect
if [ "${active[$sel]}" = "1" ]; then
  c=$(printf '%s\n' "󰖪  Disconnect" "󰆴  Forget this network" "󰜺  Cancel" | menu "$ssid" 3)
  case "$c" in
    0) nmcli con down id "$ssid" >/dev/null 2>&1 && notify-send "Wi-Fi" "Disconnected from $ssid" ;;
    1) nmcli con delete id "$ssid" >/dev/null 2>&1 && notify-send "Wi-Fi" "Forgot $ssid" ;;
  esac
  exit 0
fi

# --- known network: just bring it up
if nmcli -t -f NAME con show 2>/dev/null | grep -Fxq "$ssid"; then
  if nmcli con up id "$ssid" >/dev/null 2>&1; then notify-send "Wi-Fi" "Connected to $ssid"
  else notify-send "Wi-Fi" "Could not connect to $ssid"; fi
  exit 0
fi

# --- new network: ask for the password if it is secured
if [ "${secure[$sel]}" = "1" ]; then
  pw=$(rofi -dmenu -password -p "Password" -theme "$theme" \
        -theme-str 'window { width: 520px; } mainbox { children: [ inputbar ]; }' < /dev/null)
  [ -z "$pw" ] && exit 0
  out=$(nmcli dev wifi connect "$ssid" password "$pw" 2>&1)
else
  out=$(nmcli dev wifi connect "$ssid" 2>&1)
fi
if [ $? -eq 0 ]; then notify-send "Wi-Fi" "Connected to $ssid"
else notify-send "Wi-Fi" "Failed: ${out:0:120}"; fi
