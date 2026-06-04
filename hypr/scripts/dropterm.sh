#!/bin/bash
# Logical resolution (physical / scale)
MON_W=$(hyprctl monitors -j | jq '(.[0].width / .[0].scale) | floor')
MON_H=$(hyprctl monitors -j | jq '(.[0].height / .[0].scale) | floor')

WIN_W=$(( MON_W * 75 / 100 ))
WIN_H=$(( MON_H * 45 / 100 ))
WIN_X=$(( (MON_W - WIN_W) / 2 ))
WIN_Y=0

count=$(hyprctl clients -j | jq '[.[] | select(.class == "kitty-dropdown")] | length')
if [ "$count" -eq 0 ]; then
    kitty --class kitty-dropdown &
    sleep 0.3
    hyprctl dispatch resizewindowpixel exact ${WIN_W} ${WIN_H},class:kitty-dropdown
    hyprctl dispatch movewindowpixel exact ${WIN_X} ${WIN_Y},class:kitty-dropdown
fi

hyprctl dispatch togglespecialworkspace term
