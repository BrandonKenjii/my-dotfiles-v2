#!/bin/bash
# SWWW Wallpaper Selector - Rofi popup with imv preview
# Enter: preview | Ctrl+Enter: apply | Escape: cancel

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
IMV_TITLE="wallpaper-preview"
IMV_RULE_FLOAT="float,title:^(${IMV_TITLE})$"
IMV_RULE_SIZE="size 420 500,title:^(${IMV_TITLE})$"
IMV_RULE_MOVE="move 250 155,title:^(${IMV_TITLE})$"

cleanup() {
    pkill -f "imv.*${IMV_TITLE}" 2>/dev/null
    hyprctl keyword windowrulev2 "unset,$IMV_RULE_FLOAT" &>/dev/null
    hyprctl keyword windowrulev2 "unset,$IMV_RULE_SIZE" &>/dev/null
    hyprctl keyword windowrulev2 "unset,$IMV_RULE_MOVE" &>/dev/null
}
trap cleanup EXIT

# Build wallpaper list
mapfile -t WALLPAPERS < <(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" -o -name "*.gif" \) -printf "%f\n" | sort)

if [ ${#WALLPAPERS[@]} -eq 0 ]; then
    notify-send "Wallpaper Error" "No wallpapers found in $WALLPAPER_DIR" -u critical
    exit 1
fi

# Get current wallpaper
CURRENT_PATH=$(swww query 2>/dev/null | sed -n 's/.*image: //p' | head -n1)
CURRENT=$(basename -- "$CURRENT_PATH" 2>/dev/null)
[ -z "$CURRENT" ] && CURRENT="${WALLPAPERS[0]}"

# Monitor dimensions
eval "$(hyprctl monitors -j | jq -r '.[0] | "MON_W=\(.width) MON_H=\(.height)"')"

# Layout: compact centered pair (preview left, rofi right)
PREVIEW_W=$((MON_W * 25 / 100))
PREVIEW_H=$((MON_H * 50 / 100))
ROFI_W=$((MON_W * 20 / 100))
GAP=$((MON_W * 15 / 1000))

TOTAL_W=$((PREVIEW_W + GAP + ROFI_W))
START_X=$(((MON_W - TOTAL_W) / 2))
CENTER_Y=$(((MON_H - PREVIEW_H) / 2))

# Rofi x-offset from screen center
ROFI_CENTER_X=$((START_X + PREVIEW_W + GAP + ROFI_W / 2))
ROFI_OFFSET=$((ROFI_CENTER_X - MON_W / 2))

# Temporary window rules for the dedicated imv preview window only
IMV_RULE_SIZE="size $PREVIEW_W $PREVIEW_H,title:^(${IMV_TITLE})$"
IMV_RULE_MOVE="move $START_X $CENTER_Y,title:^(${IMV_TITLE})$"
hyprctl keyword windowrulev2 "$IMV_RULE_FLOAT"
hyprctl keyword windowrulev2 "$IMV_RULE_SIZE"
hyprctl keyword windowrulev2 "$IMV_RULE_MOVE"

# Start imv with current wallpaper
imv -W "$IMV_TITLE" -s shrink "$WALLPAPER_DIR/$CURRENT" &
sleep 0.2

# Find current wallpaper's row index
ROW=0
for i in "${!WALLPAPERS[@]}"; do
    [ "${WALLPAPERS[$i]}" = "$CURRENT" ] && ROW=$i && break
done

# Rofi dmenu loop
APPLIED=false
while true; do
    SELECTED=$(printf "%s\n" "${WALLPAPERS[@]}" | rofi -dmenu \
        -i \
        -p " Wallpaper" \
        -no-custom \
        -selected-row "$ROW" \
        -mesg "Enter: preview | Ctrl+Enter: apply" \
        -kb-accept-custom "" \
        -kb-custom-1 "Control+Return" \
        -theme-str "window { width: ${ROFI_W}px; location: center; x-offset: ${ROFI_OFFSET}px; }" \
        -theme-str "listview { lines: 12; scrollbar: true; }")
    EXIT_CODE=$?

    case $EXIT_CODE in
        0)
            # Enter: update preview
            [ -z "$SELECTED" ] && continue
            for i in "${!WALLPAPERS[@]}"; do
                [ "${WALLPAPERS[$i]}" = "$SELECTED" ] && ROW=$i && break
            done
            imv-msg "$IMV_TITLE" close all 2>/dev/null
            imv-msg "$IMV_TITLE" open "$WALLPAPER_DIR/$SELECTED" 2>/dev/null
            ;;
        10)
            # Ctrl+Enter: apply wallpaper
            APPLIED=true
            break
            ;;
        *)
            # Escape: cancel
            break
            ;;
    esac
done

# Apply selected wallpaper
if $APPLIED && [ -n "$SELECTED" ]; then
    swww img "$WALLPAPER_DIR/$SELECTED" \
        --transition-type grow \
        --transition-pos center \
        --transition-duration 1.5 \
        --transition-fps 60 \
        --transition-bezier 0.65,0,0.35,1

    notify-send "Wallpaper Set" "$SELECTED" -i "$WALLPAPER_DIR/$SELECTED" -t 3000
fi
