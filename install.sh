#!/usr/bin/env bash
# ==============================================================================
#  Radmin VPN for Linux — Fast One-Line Installer
#  Repository: https://github.com/zloyf0nerka1459/radminvpn-on-linux
# ==============================================================================
set -euo pipefail

REPO="zloyf0nerka1459/radminvpn-on-linux"
INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/radmin-vpn-linux-app"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/radmin-vpn-linux"
BIN_DIR="${HOME}/.local/bin"
DESKTOP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICON_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/256x256/apps"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

say()  { printf "${BLUE}[*]${NC} %s\n" "$*"; }
good() { printf "${GREEN}[+]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[!]${NC} %s\n" "$*"; }
die()  { printf "${RED}[-] %s${NC}\n" "$*" >&2; exit 1; }

printf "\n${BOLD}========================================${NC}\n"
printf "   ${GREEN}Radmin VPN for Linux Installer${NC}    \n"
printf "   ${BLUE}https://github.com/%s${NC}\n" "$REPO"
printf "${BOLD}========================================${NC}\n\n"

# 1. Architecture check
ARCH="$(uname -m)"
if [ "$ARCH" != "x86_64" ]; then
    die "Only x86_64 (amd64) architecture is supported. Detected: $ARCH"
fi

# 2. Prerequisites
say "Checking prerequisites..."
MISSING=""
command -v wine       >/dev/null 2>&1 || MISSING="$MISSING wine"
command -v wineserver >/dev/null 2>&1 || MISSING="$MISSING wineserver"
command -v python3    >/dev/null 2>&1 || MISSING="$MISSING python3"
command -v ip         >/dev/null 2>&1 || MISSING="$MISSING iproute2"
command -v curl       >/dev/null 2>&1 || MISSING="$MISSING curl"
command -v sudo       >/dev/null 2>&1 || MISSING="$MISSING sudo"

if [ -n "$MISSING" ]; then
    warn "Missing dependencies:$MISSING"
    say "Please install them via your distribution package manager:"
    if command -v pacman >/dev/null 2>&1; then
        echo "  sudo pacman -S wine python iproute2 curl"
    elif command -v apt-get >/dev/null 2>&1; then
        echo "  sudo apt-get update && sudo apt-get install -y wine64 wine32 python3 iproute2 curl"
    elif command -v dnf >/dev/null 2>&1; then
        echo "  sudo dnf install -y wine python3 iproute curl"
    fi
    die "Please install missing packages and re-run installer."
fi

# Check TUN/TAP device
if [ ! -c /dev/net/tun ]; then
    say "Loading 'tun' kernel module..."
    sudo modprobe tun 2>/dev/null || true
    if [ ! -c /dev/net/tun ]; then
        warn "/dev/net/tun not found. Make sure CONFIG_TUN is enabled in your Linux kernel."
    fi
fi
good "Prerequisites satisfied."

# 3. Determine installation source
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$DESKTOP_DIR" "$ICON_DIR"

if [ -f "$SCRIPT_DIR/run.sh" ] && [ -d "$SCRIPT_DIR/src" ]; then
    say "Installing from local directory: $SCRIPT_DIR..."
    cp -ra "$SCRIPT_DIR/." "$INSTALL_DIR/"
else
    say "Downloading latest repository files from GitHub..."
    TARBALL_URL="https://github.com/${REPO}/archive/refs/heads/main.tar.gz"
    TEMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TEMP_DIR"' EXIT
    curl -fsSL "$TARBALL_URL" | tar -xz -C "$TEMP_DIR"
    cp -ra "$TEMP_DIR/radminvpn-on-linux-main/." "$INSTALL_DIR/"
fi

# 4. Build or fetch binaries
cd "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/build"

NEED_BUILD=0
for f in tap_bridge rvpnnetmp.sys adapter_hook.dll rvpn_launcher.exe netsh.exe netsh64.exe drvinst.exe; do
    if [ ! -f "$INSTALL_DIR/build/$f" ]; then
        NEED_BUILD=1
        break
    fi
done

if [ "$NEED_BUILD" -eq 1 ]; then
    if command -v i686-w64-mingw32-gcc >/dev/null 2>&1 && command -v make >/dev/null 2>&1; then
        say "Building binaries with mingw-w64..."
        make
        good "Binaries built successfully."
    else
        say "Fetching prebuilt binaries from GitHub release..."
        LATEST_TAG=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null \
            | grep '"tag_name":' | head -n1 | cut -d'"' -f4 || echo "")
        
        if [ -n "$LATEST_TAG" ]; then
            BIN_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}/radmin-vpn-linux-${LATEST_TAG}.tar.gz"
            curl -fsSL "$BIN_URL" | tar -xz -C "$INSTALL_DIR/build/" || true
        fi
        
        # If release binaries not available, check if local copy exists in Applications
        if [ ! -f "$INSTALL_DIR/build/adapter_hook.dll" ] && [ -f "$HOME/Applications/radmin-vpn-appdir/usr/lib/radmin-vpn/adapter_hook.dll" ]; then
            say "Using installed local binaries..."
            cp -ra "$HOME/Applications/radmin-vpn-appdir/usr/lib/radmin-vpn/." "$INSTALL_DIR/build/"
        fi
    fi
fi

# Verify core binaries exist
if [ ! -f "$INSTALL_DIR/build/adapter_hook.dll" ] || [ ! -f "$INSTALL_DIR/build/tap_bridge" ]; then
    # Fallback to local copy if available
    if [ -f "$HOME/Applications/radmin-vpn-appdir/usr/lib/radmin-vpn/adapter_hook.dll" ]; then
        cp -ra "$HOME/Applications/radmin-vpn-appdir/usr/lib/radmin-vpn/." "$INSTALL_DIR/build/"
    else
        die "Binary build failed or missing mingw-w64 cross compiler. Install 'mingw-w64-gcc' and 'make'."
    fi
fi
good "Binaries verified."

# 5. Create bin launcher
cat > "$BIN_DIR/radmin-vpn" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/radmin-vpn-linux-app"
export BUILD_DIR="$INSTALL_DIR/build"
export WINEPREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/radmin-vpn-linux/wineprefix"
exec bash "$INSTALL_DIR/run.sh" "$@"
EOF
chmod +x "$BIN_DIR/radmin-vpn"
good "Created launcher: $BIN_DIR/radmin-vpn"

# 6. Install desktop entry and icon
if [ -f "$INSTALL_DIR/packaging/radmin-vpn.svg" ]; then
    cp -f "$INSTALL_DIR/packaging/radmin-vpn.svg" "$ICON_DIR/radmin-vpn.svg" 2>/dev/null || true
fi
if [ -f "$HOME/.local/share/icons/hicolor/256x256/apps/radmin-vpn.png" ]; then
    cp -f "$HOME/.local/share/icons/hicolor/256x256/apps/radmin-vpn.png" "$ICON_DIR/radmin-vpn.png"
fi

cat > "$DESKTOP_DIR/radmin-vpn.desktop" << EOF
[Desktop Entry]
Name=Radmin VPN
GenericName=Virtual LAN Gaming VPN
Comment=Connect to Radmin VPN gaming networks on Linux
Exec=$BIN_DIR/radmin-vpn
Icon=radmin-vpn
Terminal=true
Type=Application
Categories=Network;Game;
Keywords=vpn;radmin;lan;gaming;
StartupNotify=true
EOF
chmod +x "$DESKTOP_DIR/radmin-vpn.desktop"
good "Created desktop entry: $DESKTOP_DIR/radmin-vpn.desktop"

# Refresh icon & desktop database if tools are present
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
command -v gtk-update-icon-cache   >/dev/null 2>&1 && gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

printf "\n${GREEN}${BOLD}====================================================${NC}\n"
printf "  ${GREEN}Radmin VPN for Linux has been installed successfully!${NC}\n"
printf "${GREEN}${BOLD}====================================================${NC}\n\n"
echo "To run Radmin VPN:"
echo "  1. From terminal:     radmin-vpn"
echo "  2. From applications: search 'Radmin VPN'"
echo ""
echo "Note: Make sure '$BIN_DIR' is in your PATH."
echo ""
