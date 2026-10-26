#!/usr/bin/env bash
# Lock screen: i3lock-color, Catppuccin Mocha. Falls back to a plain solid-colour lock with plain i3lock.
# -n : stay in the foreground (needed by xss-lock) ; -e : ignore empty password
#
# Quick tweaks:
BLUR=1          # 1 = blurred screenshot of your desktop as background, 0 = solid Mocha colour
RADIUS=120      # ring size
RING_WIDTH=14   # ring thickness

pgrep -x i3lock >/dev/null && exit 0

if i3lock --version 2>&1 | grep -qE 'Cassandra Fox|Raymond Li|[0-9]\.c\.[0-9]'; then
  if [ "$BLUR" = "1" ]; then BG=(--blur 9); else BG=(-c 1e1e2e); fi

  # idle ring is dim, so the segments that light up while you type (lavender / green) and the
  # separators (mauve) stand out clearly; wrong password flashes red.
  exec i3lock -n -e "${BG[@]}" \
    --inside-color=1e1e2ecc   --ring-color=45475aff   --line-uses-ring \
    --keyhl-color=b4befeff    --bshl-color=f38ba8ff   --separator-color=cba6f7ff \
    --insidever-color=1e1e2ecc --ringver-color=89b4faff \
    --insidewrong-color=1e1e2ecc --ringwrong-color=f38ba8ff \
    --time-color=cdd6f4ff --date-color=a6adc8ff --verif-color=89b4faff --wrong-color=f38ba8ff \
    --layout-color=a6adc8ff \
    --clock --indicator --time-str='%H:%M' --date-str='%A %d %B' \
    --time-size=44 --date-size=16 \
    --verif-text="Checking..." --wrong-text="Wrong password" --noinput-text="" \
    --radius "$RADIUS" --ring-width "$RING_WIDTH" \
    --pass-media-keys
else
  exec i3lock -n -e -c 1e1e2e
fi
