#!/usr/bin/env bash
# Desktop Integration Verification Script
# Usage: ./verify-desktop-integration.sh [app-name]

set -euo pipefail

APP_NAME="${1:-}"

if [[ -z "$APP_NAME" ]]; then
    echo "Usage: $0 <app-name>"
    echo "Example: $0 bitwarden"
    exit 1
fi

echo "=== Desktop Integration Verification for: ${APP_NAME} ==="
echo

# Check desktop files
echo "1. Checking for desktop files..."
DESKTOP_FILES=$(find /usr/share/applications -name "*${APP_NAME}*.desktop" 2>/dev/null)
if [[ -n "$DESKTOP_FILES" ]]; then
    echo "✓ Found desktop file(s):"
    echo "$DESKTOP_FILES"
    echo
    for file in $DESKTOP_FILES; do
        echo "--- Content of $file ---"
        cat "$file"
        echo

        # Validate desktop file
        if command -v desktop-file-validate &>/dev/null; then
            echo "--- Validation ---"
            if desktop-file-validate "$file" 2>&1; then
                echo "✓ Desktop file is valid"
            else
                echo "✗ Desktop file has validation errors"
            fi
            echo
        fi
    done
else
    echo "✗ No desktop files found"
fi

# Check icons
echo "2. Checking for icons..."
ICONS=$(find /usr/share/icons/hicolor -name "*${APP_NAME}*.png" 2>/dev/null | head -5)
if [[ -n "$ICONS" ]]; then
    echo "✓ Found icon(s):"
    echo "$ICONS"
    echo
else
    echo "✗ No icons found"
fi

# Check AppImage in /opt
echo "3. Checking for AppImage in /opt..."
OPT_DIR=$(find /opt -maxdepth 1 -type d -name "*${APP_NAME}*" 2>/dev/null)
if [[ -n "$OPT_DIR" ]]; then
    echo "✓ Found installation directory:"
    echo "$OPT_DIR"
    ls -la "$OPT_DIR"
    echo
else
    echo "✗ No installation directory found in /opt"
fi

# Check symlink
echo "4. Checking for symlink in /usr/sbin..."
SYMLINK=$(find /usr/sbin -name "*${APP_NAME}*" 2>/dev/null)
if [[ -n "$SYMLINK" ]]; then
    echo "✓ Found symlink:"
    ls -la $SYMLINK
    echo
else
    echo "✗ No symlink found"
fi

# Check desktop environment
echo "5. Desktop Environment Information..."
echo "XDG_CURRENT_DESKTOP: ${XDG_CURRENT_DESKTOP:-not set}"
echo "DESKTOP_SESSION: ${DESKTOP_SESSION:-not set}"
echo

# Check database files
echo "6. Checking desktop database..."
if [[ -f /usr/share/applications/mimeinfo.cache ]]; then
    if grep -q "${APP_NAME}" /usr/share/applications/mimeinfo.cache; then
        echo "✓ Found in mimeinfo.cache"
    else
        echo "✗ Not found in mimeinfo.cache"
    fi
else
    echo "✗ mimeinfo.cache not found"
fi
echo

# Manual refresh commands
echo "=== Manual Refresh Commands ==="
echo "If the app still doesn't appear, try these commands:"
echo
echo "# Update desktop database:"
echo "sudo update-desktop-database /usr/share/applications/"
echo
echo "# Update icon cache:"
echo "sudo gtk-update-icon-cache -f -t /usr/share/icons/hicolor/"
echo
echo "# For KDE users:"
echo "kbuildsycoca5  # or kbuildsycoca6"
echo
echo "# For XFCE users:"
echo "xfce4-panel --restart"
echo
echo "# Or simply log out and log back in"
echo

echo "=== Verification Complete ==="
