#!/bin/bash
# Rofi wallpaper modi script with imv preview window side-by-side

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
PREVIEW_FILE="/tmp/wallpaper-preview.jpg"
IMV_TITLE="wallpaper-preview"

# Start imv preview window if not already running
start_preview() {
    if ! pgrep -f "imv.*$IMV_TITLE" > /dev/null 2>&1; then
        # Get first wallpaper for initial preview
        local first
        first=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" -o -name "*.gif" \) | sort | head -1)
        if [ -n "$first" ]; then
            cp "$first" "$PREVIEW_FILE"
        fi
        imv -W "$IMV_TITLE" -s shrink "$PREVIEW_FILE" &
        sleep 0.3
    fi
}

update_preview() {
    local img="$WALLPAPER_DIR/$1"
    if [ -f "$img" ]; then
        cp "$img" "$PREVIEW_FILE"
        # Tell imv to reload the file
        imv-msg "$IMV_TITLE" close all 2>/dev/null
        imv-msg "$IMV_TITLE" open "$PREVIEW_FILE" 2>/dev/null
    fi
}

cleanup_preview() {
    pkill -f "imv.*$IMV_TITLE" 2>/dev/null
    rm -f "$PREVIEW_FILE"
}

if [ -z "$@" ]; then
    # Initial call - start preview and list wallpapers
    start_preview
    # Clean up imv when rofi exits
    ( while pgrep -x rofi > /dev/null 2>&1; do sleep 0.5; done; cleanup_preview ) &
    find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" -o -name "*.gif" \) -printf "%f\n" | sort
else
    # Selection made
    SELECTED="$@"

    # Check if Enter (preview) or Ctrl+Enter (apply)
    if [ -n "$ROFI_RETV" ] && [ "$ROFI_RETV" -eq 1 ]; then
        # Custom keybind (Ctrl+Enter) - apply wallpaper
        cleanup_preview
        swww img "$WALLPAPER_DIR/$SELECTED" \
            --transition-type grow \
            --transition-pos center \
            --transition-duration 1.5 \
            --transition-fps 60 \
            --transition-bezier 0.65,0,0.35,1 &
        notify-send "Wallpaper Set" "$SELECTED" -i "$WALLPAPER_DIR/$SELECTED" -t 3000
    else
        # Enter - preview only, re-list wallpapers
        update_preview "$SELECTED"
        find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" -o -name "*.gif" \) -printf "%f\n" | sort
    fi
fi
