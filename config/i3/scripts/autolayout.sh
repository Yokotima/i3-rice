#!/usr/bin/env bash
# Relance i3-autolayout (tiling en spirale). Ne fait rien si le binaire n'est pas installé.
command -v i3-autolayout >/dev/null 2>&1 || exit 0
killall -q i3-autolayout
while pgrep -u "$(id -u)" -x i3-autolayout >/dev/null; do sleep 1; done
i3-autolayout autolayout &
