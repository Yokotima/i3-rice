#!/usr/bin/env bash
# Lance la barre polybar (thème "forest" d'adi1090x, palette Catppuccin Mocha)
dir="$HOME/.config/polybar/forest"

killall -q polybar
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 0.5; done

# moniteur principal (ou le premier disponible)
MONITOR=$(polybar --list-monitors | grep -i primary | cut -d: -f1)
[ -z "$MONITOR" ] && MONITOR=$(polybar --list-monitors | head -n1 | cut -d: -f1)
export MONITOR

# interface réseau utilisée par la route par défaut
NET_IFACE=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
[ -z "$NET_IFACE" ] && NET_IFACE=$(ls /sys/class/net | grep -v '^lo$' | head -n1)
export NET_IFACE

polybar -q main -c "$dir/config.ini" &
