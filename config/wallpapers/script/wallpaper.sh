#!/usr/bin/env bash
# Wallpaper carousel. "--restore" re-applies the last choice (used at login).
# Normal run: opens the rotating carousel (GTK). Falls back to a rofi row if GTK/python bindings are missing.
HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
STATE="$HOME/.config/wallpapers/script/.current"
DIRS=("$HOME/.config/wallpapers")

apply() { feh --no-fehbg --bg-fill "$1" && echo "$1" > "$STATE"; }

mapfile -t imgs < <(find "${DIRS[@]}" -maxdepth 2 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) 2>/dev/null | sort -u)

if [ "$1" = "--restore" ]; then
  if [ -r "$STATE" ] && [ -f "$(cat "$STATE")" ]; then apply "$(cat "$STATE")"
  else apply "$HOME/.config/wallpapers/pixel-car.png"; fi
  # build the small thumbnails in the background, so the carousel opens instantly later
  [ ${#imgs[@]} -gt 0 ] && [ -r "$HERE/carousel.py" ] && (nice -n 15 python3 "$HERE/carousel.py" --warm "${imgs[@]}" >/dev/null 2>&1 &)
  exit 0
fi

[ ${#imgs[@]} -eq 0 ] && { notify-send "Wallpapers" "No pictures found"; exit 1; }

cur=$(cat "$STATE" 2>/dev/null)

# --- real carousel (GTK); exit code 99 = python bindings missing -> fall back to rofi ---
if [ -r "$HERE/carousel.py" ]; then
  python3 "$HERE/carousel.py" "$cur" "${imgs[@]}"
  rc=$?
  [ $rc -ne 99 ] && exit $rc
fi

# --- fallback: rofi row ---
sel=0
for i in "${!imgs[@]}"; do [ "${imgs[$i]}" = "$cur" ] && sel=$i; done

idx=$(for f in "${imgs[@]}"; do printf '%s\0icon\x1f%s\n' "$(basename "${f%.*}")" "$f"; done |
  rofi -dmenu -i -p "Wallpaper" -show-icons -format i -selected-row "$sel" \
    -theme ~/.config/rofi/catppuccin.rasi \
    -theme-str 'window { width: 1160px; } listview { layout: horizontal; lines: 5; fixed-height: true; spacing: 12px; } element { orientation: vertical; padding: 10px; } element-icon { size: 200px; horizontal-align: 0.5; } element-text { horizontal-align: 0.5; }')

[ -n "$idx" ] && apply "${imgs[$idx]}"
