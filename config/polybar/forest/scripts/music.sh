#!/usr/bin/env bash
# Prev / play-pause / next buttons + "Artist - Title". Hidden when no player is running.
prev="%{A1:playerctl previous:}󰒮%{A}"
next="%{A1:playerctl next:}󰒭%{A}"
while true; do
  playerctl --follow metadata --format '{{status}}|{{artist}}|{{title}}' 2>/dev/null |
  while IFS='|' read -r status artist title; do
    case "$status" in
      Playing) icon="󰏤" ;;
      Paused)  icon="󰐊" ;;
      *) echo ""; continue ;;
    esac
    txt="${artist:+$artist - }$title"
    [ ${#txt} -gt 40 ] && txt="${txt:0:39}…"
    echo "  %{F#f5c2e7}$prev  %{A1:playerctl play-pause:}$icon%{A}  $next%{F-}   $txt"
  done
  echo ""; sleep 2
done
