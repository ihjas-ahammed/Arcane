#!/usr/bin/env bash
# ==============================================================================
#  Arcane Linux (x86_64) Installer
#  Usage: curl -sSL https://raw.githubusercontent.com/ihjas-ahammed/Arcane/revive2/scripts/install-linux.sh | bash
# ==============================================================================
set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
AMBER='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}------------------------------------------------------------${NC}"
echo -e "${CYAN}  ⚡ Arcane System Tactical Terminal // Linux Installer${NC}"
echo -e "${CYAN}------------------------------------------------------------${NC}"

# Check OS and Architecture
OS="$(uname -s)"
ARCH="$(uname -m)"

if [ "$OS" != "Linux" ]; then
  echo -e "${RED}[ERROR] This installer is for Linux only (detected $OS).${NC}"
  exit 1
fi

if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "amd64" ]; then
  echo -e "${RED}[ERROR] Arcane currently targets x86_64 Linux (detected $ARCH).${NC}"
  exit 1
fi

# Check required commands
for cmd in tar gzip; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] Required tool '$cmd' is not installed.${NC}"
    exit 1
  fi
done

DOWNLOADER=""
if command -v curl >/dev/null 2>&1; then
  DOWNLOADER="curl"
elif command -v wget >/dev/null 2>&1; then
  DOWNLOADER="wget"
else
  echo -e "${RED}[ERROR] Neither 'curl' nor 'wget' was found.${NC}"
  exit 1
fi

fetch_text() {
  local url="$1"
  if [ "$DOWNLOADER" = "curl" ]; then
    curl -fsSL -H "Cache-Control: no-cache" "$url"
  else
    wget -qO- --no-cache "$url"
  fi
}

download_file() {
  local url="$1"
  local dest="$2"
  if [ "$DOWNLOADER" = "curl" ]; then
    curl -fSL --progress-bar -H "Cache-Control: no-cache" "$url" -o "$dest"
  else
    wget --progress=bar:force -O "$dest" "$url"
  fi
}

echo -e "${CYAN}[1/5] Checking latest Arcane release metadata...${NC}"

METADATA_URLS=(
  "https://raw.githubusercontent.com/ihjas-ahammed/Arcane/revive2/builds/update_info.json"
  "https://raw.githubusercontent.com/ihjas-ahammed/Arcane/main/builds/update_info.json"
  "https://raw.githubusercontent.com/ihjas-ahammed/Arcane/revive2/builds/latest.json"
)

METADATA=""
for u in "${METADATA_URLS[@]}"; do
  METADATA=$(fetch_text "$u?t=$(date +%s)" 2>/dev/null || true)
  if [ -n "$METADATA" ]; then
    break
  fi
done

if [ -z "$METADATA" ]; then
  echo -e "${RED}[ERROR] Failed to fetch update metadata from repository.${NC}"
  exit 1
fi

# Parse version and linux archive URL
VERSION_NAME=$(echo "$METADATA" | grep -o '"version_name": *"[^"]*"' | head -1 | cut -d'"' -f4)
VERSION_CODE=$(echo "$METADATA" | grep -o '"version_code": *[0-9]*' | head -1 | awk '{print $2}')
LINUX_URL=$(echo "$METADATA" | grep -o '"linux_url": *"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$LINUX_URL" ]; then
  # Fallback to direct naming convention
  LINUX_URL="https://raw.githubusercontent.com/ihjas-ahammed/Arcane/revive2/builds/missions-v${VERSION_NAME}-b${VERSION_CODE}-linux-x86_64.tar.gz"
fi

echo -e "      Found version: ${GREEN}v${VERSION_NAME}${NC} (Build #${VERSION_CODE})"
echo -e "${CYAN}[2/5] Downloading Linux bundle (${ARCH})...${NC}"

TMP_DIR="$(mktemp -d /tmp/arcane_install_XXXXXX)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

ARCHIVE_PATH="$TMP_DIR/arcane-linux.tar.gz"
download_file "$LINUX_URL?t=$(date +%s)" "$ARCHIVE_PATH"

if [ ! -s "$ARCHIVE_PATH" ]; then
  echo -e "${RED}[ERROR] Downloaded archive is empty or failed.${NC}"
  exit 1
fi

echo -e "${CYAN}[3/5] Extracting into installation directory...${NC}"
INSTALL_DIR="${ARCANE_INSTALL_DIR:-$HOME/.local/share/arcane}"
BIN_DIR="${ARCANE_BIN_DIR:-$HOME/.local/bin}"
APPS_DIR="$HOME/.local/share/applications"
ICONS_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"

mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$APPS_DIR" "$ICONS_DIR"

# Clean prior application bundle binaries
rm -rf "$INSTALL_DIR/missions" "$INSTALL_DIR/lib" "$INSTALL_DIR/data" "$INSTALL_DIR/arcane.desktop"

tar -xzf "$ARCHIVE_PATH" -C "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/missions"

echo -e "${CYAN}[4/5] Setting up desktop shortcuts and commands...${NC}"

# Symlinks in ~/.local/bin
ln -sf "$INSTALL_DIR/missions" "$BIN_DIR/arcane"
ln -sf "$INSTALL_DIR/missions" "$BIN_DIR/missions"

# Install application icon
if [ -f "$INSTALL_DIR/data/missions.png" ]; then
  cp -f "$INSTALL_DIR/data/missions.png" "$ICONS_DIR/arcane.png"
  cp -f "$INSTALL_DIR/data/missions.png" "$INSTALL_DIR/missions.png"
fi

# Desktop Entry File
cat > "$APPS_DIR/arcane.desktop" <<EOF
[Desktop Entry]
Name=Arcane
Comment=Focus, Missions & Well-being Tactical Terminal
Exec=$INSTALL_DIR/missions
Icon=$ICONS_DIR/arcane.png
Terminal=false
Type=Application
Categories=Utility;Office;ProjectManagement;
StartupWMClass=missions
Keywords=productivity;missions;tracker;focus;tactical;
EOF
chmod +x "$APPS_DIR/arcane.desktop"

# Refresh desktop caches if utilities are available
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
fi

echo -e "${CYAN}[5/5] Verifying environment...${NC}"

echo -e "${GREEN}------------------------------------------------------------${NC}"
echo -e "${GREEN}  ✓ Arcane v${VERSION_NAME} (Build #${VERSION_CODE}) is successfully installed!${NC}"
echo -e "${GREEN}------------------------------------------------------------${NC}"
echo -e "  Location: ${CYAN}$INSTALL_DIR${NC}"
echo -e "  Command:  ${CYAN}arcane${NC} (or missions)"
echo -e "  Launcher: Appears in your application launcher menu"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    echo -e "\n${AMBER}[NOTE] Add ~/.local/bin to your PATH to run 'arcane' from any terminal:${NC}"
    echo -e "       echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc # or ~/.zshrc\n"
    ;;
esac
