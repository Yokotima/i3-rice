#!/usr/bin/env bash
theme="$HOME/.config/rofi/catppuccin.rasi"
dir="$HOME/Pictures/Screenshots"; mkdir -p "$dir"
file="$dir/shot-$(date +%Y%m%d-%H%M%S).png"
small='window { width: 360px; } listview { lines: 4; }'

save() { tee "$file" | xclip -selection clipboard -t image/png && notify-send "Screenshot saved" "$file (and copied)"; }

choice=$(printf 'Full screen\nSelect area\nActive window\nFull screen in 3s\n' | rofi -dmenu -i -p "Screenshot" -theme "$theme" -theme-str "$small")
case "$choice" in
  "Full screen")        sleep 0.4; maim -u | save ;;
  "Select area")        maim -u -s -b 2 | save ;;
  "Active window")      sleep 0.4; maim -u -i "$(xdotool getactivewindow)" | save ;;
  "Full screen in 3s")  sleep 3; maim -u | save ;;
esac
