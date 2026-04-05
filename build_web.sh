#!/usr/bin/env bash
# Build Boss Rush for Web (HTML5) and serve locally
# Usage: ./build_web.sh

set -e

GODOT_CMD="godot"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXPORT_DIR="$PROJECT_DIR/export/web"
PORT=8080

echo "=== Boss Rush — Web Build ==="
echo "Project: $PROJECT_DIR"
echo "Export:  $EXPORT_DIR"

# Create export dir
mkdir -p "$EXPORT_DIR"

# Try to find Godot executable
if ! command -v godot &>/dev/null; then
    # Common Windows Godot paths via Git Bash
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

echo "Using Godot: $GODOT_CMD"

# Export
echo "Exporting..."
"$GODOT_CMD" --headless --path "$PROJECT_DIR" --export-release "Web" "$EXPORT_DIR/index.html"

echo ""
echo "Build complete! Files in: $EXPORT_DIR"
echo ""
echo "Starting local server at http://localhost:$PORT"
echo "Press Ctrl+C to stop."
cd "$EXPORT_DIR"
python3 -m http.server $PORT
