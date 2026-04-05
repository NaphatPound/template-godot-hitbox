#!/usr/bin/env bash
# Run Boss Rush in Godot DEBUG mode
# Usage: ./run_debug.sh

GODOT_CMD="godot"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Try to find Godot executable
if ! command -v godot &>/dev/null; then
    for candidate in \
        "/c/Program Files/Godot/Godot_v4.6*.exe" \
        "/c/Users/$USER/AppData/Local/Programs/Godot/Godot*.exe" \
        "/c/tools/godot/Godot*.exe"; do
        found=$(ls $candidate 2>/dev/null | head -1)
        if [ -n "$found" ]; then
            GODOT_CMD="$found"
            break
        fi
    done
fi

echo "=== Boss Rush — DEBUG Run ==="
echo "Project: $PROJECT_DIR"
echo "Using Godot: $GODOT_CMD"
echo ""

"$GODOT_CMD" --path "$PROJECT_DIR" --debug
