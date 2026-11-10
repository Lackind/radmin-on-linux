#!/usr/bin/env bash
# ==============================================================================
#  install-old.sh — Radmin VPN one-click installer (old machines edition).
#
#  For RHEL 7 / CentOS 7 (glibc 2.17). Radmin VPN is a 32-bit program, but
#  EPEL 7 only ships a 64-bit wine 4.0.4. This script automates:
#    1. Compile wine 6.0 (32+64 bit) from source  — ~30-60 min
#    2. Recompile the project's native binaries for the old glibc
#    3. Install the Windows PE files (prebuilt/)
#    4. Silently install Radmin VPN under Xvfb
#    5. Optionally install a systemd auto-start service
#
#  Usage:
#    sudo bash install-old.sh                          # auto-find the Radmin installer
#    sudo bash install-old.sh --installer /path/Radmin_VPN_2.1.4951.1.exe
#    sudo bash install-old.sh --no-systemd             # skip the systemd service
#
#  Requires: access to dl.winehq.org (wine source) + a yum mirror; plus a Radmin
#  installer (2.1.4951.1 or 2.0.4899.9, from https://www.radmin-vpn.com/).
#
#  ⚠  WARNING — THIS SCRIPT MAKES SYSTEM-WIDE CHANGES:
#     - installs wine 6.0 into /usr/local (shadows any system wine)
#     - installs packages via yum
#     - installs & enables a systemd service (radmin-vpn.service) — auto-start on boot
#     - creates a TAP device (radminvpn0) and adds a 26.0.0.0/8 route while running
# ==============================================================================
set -euo pipefail

# sudo's secure_path omits /usr/local/bin, where wine 6.0 is installed. Prepend it
# so every child (build-wine6.sh, run_vps.sh) sees our wine instead of the
# distro's 64-bit-only wine 4.0.4.
export PATH="/usr/local/bin:${PATH}"

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALLER=""
NO_SYSTEMD=0

for arg in "$@"; do
    case "$arg" in
        --installer) shift; INSTALLER="$1"; shift ;;
        --installer=*) INSTALLER="${arg#*=}" ;;
        --no-systemd) NO_SYSTEMD=1 ;;
    esac
done

log()  { echo -e "\033[1;34m[*]\033[0m $*"; }
good() { echo -e "\033[1;32m[+]\033[0m $*"; }
warn() { echo -e "\033[1;33m[!]\033[0m $*"; }
die()  { echo -e "\033[1;31m[-]\033[0m $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Run as root: sudo bash install-old.sh"
[ "$(uname -m)" = "x86_64" ] || die "Only x86_64 is supported"
[ -f "$REPO_DIR/run_vps.sh" ] || die "Run this script from the repository root"

echo ""
echo "======================================================"
echo "  Radmin VPN one-click install (RHEL 7 / CentOS 7)"
echo "======================================================"
echo ""
warn "This will: compile+install wine 6.0 to /usr/local, install packages via yum,"
warn "install a systemd service (auto-start on boot), and create a TAP device + routes."
echo ""

# ---- 1. wine 6.0 (32+64) ----
log "Step 1/5: Compile wine 6.0 (32+64 bit) — skipped if already present..."
bash "$REPO_DIR/build-wine6.sh"

# ---- 2. System dependencies ----
log "Step 2/5: Install system dependencies (Xvfb + x11vnc + CJK fonts)..."
yum install -y xorg-x11-server-Xvfb x11vnc wqy-microhei-fonts wqy-zenhei-fonts cjkuni-uming-fonts

# ---- 3. Native binaries ----
log "Step 3/5: Recompile native binaries for the old glibc..."
bash "$REPO_DIR/build-native.sh"

# ---- 4. PE files ----
log "Step 4/5: Install Windows PE files..."
[ -d "$REPO_DIR/prebuilt" ] || die "prebuilt/ directory not found"
cp -a "$REPO_DIR/prebuilt/." "$REPO_DIR/build/"
good "PE files copied to build/"

# ---- 5. Locate the Radmin installer ----
log "Step 5/5: Locate the Radmin installer..."
if [ -z "$INSTALLER" ] || [ ! -f "$INSTALLER" ]; then
    INSTALLER=$(find "$REPO_DIR" "$HOME/Downloads" -maxdepth 1 \
        \( -name 'Radmin_VPN_*.exe' -o -name 'Radmin_LAN_*.exe' \) -print -quit 2>/dev/null || true)
fi

# ---- systemd (optional) ----
if [ "$NO_SYSTEMD" -eq 0 ]; then
    log "Installing the systemd service (auto-start on boot + auto-restart on failure)..."
    sed "s|__REPO_DIR__|$REPO_DIR|g" "$REPO_DIR/radmin-vpn.service" \
        > /etc/systemd/system/radmin-vpn.service
    systemctl daemon-reload
    systemctl enable radmin-vpn.service 2>/dev/null || warn "systemd enable failed (not a systemd system?) — skipping"
    good "systemd service installed: radmin-vpn.service"
fi

echo ""

# ---- Install Radmin VPN (does NOT start the service) ----
if [ -n "$INSTALLER" ] && [ -f "$INSTALLER" ]; then
    log "Installing Radmin VPN (silent install under Xvfb, ~1-2 min)..."
    pgrep -f 'Xvfb :99' >/dev/null 2>&1 || nohup Xvfb :99 -screen 0 1024x768x24 >/tmp/xvfb.log 2>&1 &
    sleep 1
    export DISPLAY=:99
    echo ""
    bash "$REPO_DIR/run_vps.sh" --install-only --installer "$INSTALLER"
    # Remove the temporary Xvfb that was only needed for the installer
    pkill -f 'Xvfb :99' 2>/dev/null || true
else
    warn "No Radmin installer found. Download one, place it in $REPO_DIR or ~/Downloads, then run:"
    warn "    export DISPLAY=:99"
    warn "    bash $REPO_DIR/run_vps.sh --install-only --installer /path/to/Radmin_VPN_2.1.4951.1.exe"
    warn ""
    warn "  Supported versions: 2.1.4951.1 or 2.0.4899.9"
    warn "  Download: https://www.radmin-vpn.com/"
    die "Radmin installer not found — nothing to install"
fi

# ---- Verify the installation ----
log "Verifying installation..."
VERIFY_FAIL=0
WP="$REPO_DIR/wineprefix"
check_ok()   { good "$1"; }
check_bad()  { warn "MISSING: $1"; VERIFY_FAIL=1; }

for f in tap_bridge rvpnnetmp.sys adapter_hook.dll rvpn_launcher.exe netsh.exe netsh64.exe drvinst.exe; do
    [ -f "$REPO_DIR/build/$f" ] && check_ok "build/$f" || check_bad "build/$f"
done

if [ -f "$WP/drive_c/Program Files (x86)/Radmin VPN/RvControlSvc.exe" ] || \
   [ -f "$WP/drive_c/Program Files (x86)/Radmin LAN/RvControlSvc.exe" ]; then
    check_ok "Radmin VPN installed in the wineprefix"
else
    check_bad "Radmin VPN (RvControlSvc.exe) in the wineprefix"
fi

if wine --version 2>/dev/null | grep -qE '^wine-([6-9]|[1-9][0-9])\.'; then
    check_ok "wine $(wine --version 2>/dev/null) (32-bit capable)"
else
    check_bad "a 32-bit-capable wine (got: $(wine --version 2>/dev/null || echo none))"
fi

[ -f /etc/systemd/system/radmin-vpn.service ] \
    && check_ok "systemd unit radmin-vpn.service" \
    || warn "systemd unit not installed (fine if --no-systemd was used)"

echo ""
if [ "$VERIFY_FAIL" -eq 0 ]; then
    good "Installation verified. Nothing is running — proceed to start it."
    echo ""
    echo "  Next:"
    echo "    1) Start it and join a network (once):  bash run_datacenter.sh"
    echo "    2) Then run headless daily:             bash run_vps.sh   (or: systemctl start radmin-vpn)"
else
    warn "Installation is incomplete — see MISSING above."
    exit 1
fi
