#!/usr/bin/env bash

# ==============================================================================
# Missions Installer / Updater Script
# ==============================================================================
# Builds the Flutter release version of Missions for Linux and installs
# it into the user local directories (~/.local/share and ~/.local/bin)
# and registers a desktop launcher menu entry.
# ==============================================================================

set -e

# Configuration
APP_NAME="missions"
DISPLAY_NAME="Missions"
INSTALL_DIR="$HOME/.local/share/$APP_NAME"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
BUNDLE_DIR="build/linux/x64/release/bundle"

# 1. Prerequisite checks
echo "=== 1. Checking Prerequisites ==="
if ! command -v flutter &> /dev/null; then
    echo "Error: Flutter SDK is not installed or not available in your PATH."
    echo "Please install Flutter before running this installer."
    exit 1
fi

if [ ! -f "pubspec.yaml" ] || [ ! -d "linux" ]; then
    echo "Error: This script must be run from the root of the project directory."
    exit 1
fi

# 2. Fetch Dependencies
echo "=== 2. Fetching Dependencies ==="
flutter pub get

# 3. Build Release Bundle
echo "=== 3. Building Linux Desktop App (Release Mode) ==="
flutter build linux --release

if [ ! -d "$BUNDLE_DIR" ] || [ ! -f "$BUNDLE_DIR/$APP_NAME" ]; then
    echo "Error: Build completed but binary bundle was not found at $BUNDLE_DIR/$APP_NAME."
    exit 1
fi

# 4. Install / Update App Bundle
echo "=== 4. Installing Application files ==="
if [ -d "$INSTALL_DIR" ]; then
    echo "Updating existing installation at $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR"
fi

mkdir -p "$INSTALL_DIR"
cp -r "$BUNDLE_DIR"/* "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/$APP_NAME"
echo "Installed application bundle to $INSTALL_DIR"

# 5. Set up CLI Launcher
echo "=== 5. Setting up CLI Launcher ==="
mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/$APP_NAME" "$BIN_DIR/$APP_NAME"
echo "Created command-line runner at $BIN_DIR/$APP_NAME"

# 6. Set up Desktop Entry Launcher
echo "=== 6. Registering Desktop Application ==="
mkdir -p "$DESKTOP_DIR"

cat <<EOF > "$DESKTOP_DIR/$APP_NAME.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=$DISPLAY_NAME
Comment=A gamified, tactical life-management and productivity tracker
Exec=$INSTALL_DIR/$APP_NAME
Icon=$INSTALL_DIR/data/missions.png
Terminal=false
Categories=Utility;Office;
StartupWMClass=$APP_NAME
EOF

chmod +x "$DESKTOP_DIR/$APP_NAME.desktop"

# Refresh desktop database if utility exists
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$DESKTOP_DIR" &> /dev/null || true
fi
echo "Registered desktop entry at $DESKTOP_DIR/$APP_NAME.desktop"

# 7. Success & Warnings
echo ""
echo "============================================="
echo " $DISPLAY_NAME Installation Successful!"
echo "============================================="
echo "You can launch the app by running:"
echo "  $APP_NAME"
echo "or via your application menu launcher."
echo ""

# Check if ~/.local/bin is in user PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "WARNING: $BIN_DIR is not in your current PATH environment variable."
    echo "To run '$APP_NAME' from terminal anywhere, add it to your PATH."
    echo "For example, append this to your ~/.bashrc or ~/.zshrc:"
    echo "  export PATH=\"\$PATH:\$HOME/.local/bin\""
    echo ""
fi
echo "============================================="
