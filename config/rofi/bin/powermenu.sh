#!/usr/bin/env bash
theme="$HOME/.config/rofi/catppuccin.rasi"
small='window { width: 320px; } listview { lines: 5; }'

confirm() {
  [ "$(printf 'No\nYes\n' | rofi -dmenu -i -p "$1?" -theme "$theme" -theme-str 'window { width: 320px; } listview { lines: 2; }')" = "Yes" ]
}

choice=$(printf 'Lock\nLogout\nSuspend\nReboot\nShutdown\n' | rofi -dmenu -i -p "Power" -theme "$theme" -theme-str "$small")
case "$choice" in
  Lock)     "$HOME/.config/i3/scripts/lock.sh" ;;
  Logout)   confirm "Logout"   && i3-msg exit ;;
  Suspend)  systemctl suspend ;;
  Reboot)   confirm "Reboot"   && systemctl reboot ;;
  Shutdown) confirm "Shutdown" && systemctl poweroff ;;
esac
