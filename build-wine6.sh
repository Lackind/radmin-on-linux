#!/usr/bin/env bash
# ==============================================================================
#  build-wine6.sh — Compile wine 6.0 (32+64 bit) on old systems (RHEL 7 / CentOS 7).
#
#  Why: Radmin VPN is a 32-bit program, but EPEL 7's wine 4.0.4 is 64-bit only
#  and cannot run it. This script compiles wine 6.0 (both 32- and 64-bit) from
#  source and installs it to /usr/local.
#
#  Usage: sudo bash build-wine6.sh
#  Time:  ~30-60 minutes depending on the machine.
#  Requires: access to dl.winehq.org (wine source) and a yum mirror.
#  Tuning:  JOBS=2 sudo bash build-wine6.sh   # limit parallel jobs on low-RAM hosts
# ==============================================================================
set -euo pipefail

WINE_VER="6.0.4"
SRC_URL="https://dl.winehq.org/wine/source/6.0/wine-${WINE_VER}.tar.xz"
WORK="/root"
SRC_DIR="$WORK/wine-${WINE_VER}"
BUILD64="$WORK/wine64-build"
BUILD32="$WORK/wine32-build"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 2)}"

log()  { echo -e "\033[1;34m[*]\033[0m $*"; }
good() { echo -e "\033[1;32m[+]\033[0m $*"; }
warn() { echo -e "\033[1;33m[!]\033[0m $*"; }
die()  { echo -e "\033[1;31m[-]\033[0m $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Run as root"
[ "$(uname -m)" = "x86_64" ] || die "Only x86_64 is supported"

# ---- 0. Skip if a working 32-bit wine already exists ----
if command -v wine >/dev/null 2>&1; then
    if wine cmd /c echo __wine32ok__ 2>/dev/null | grep -q __wine32ok__; then
        good "A working 32-bit wine already exists ($(wine --version 2>/dev/null)) — skipping"
        exit 0
    fi
fi

command -v yum >/dev/null 2>&1 || die "Only yum-based distros are supported (RHEL 7 / CentOS 7)"
command -v curl >/dev/null 2>&1 || die "curl not found"

# ---- 1. 64-bit build dependencies ----
log "Installing 64-bit build dependencies..."
yum install -y \
    gcc gcc-c++ make flex bison \
    glibc-devel libgcc zlib-devel \
    libX11-devel libXext-devel libXrender-devel libXcursor-devel libXrandr-devel \
    libXi-devel libXfixes-devel libXcomposite-devel libXinerama-devel libXxf86vm-devel \
    freetype-devel fontconfig-devel \
    libxml2-devel libxslt-devel ncurses-devel

# ---- 2. 32-bit build dependencies (with multilib conflict handling) ----
log "Installing 32-bit build dependencies..."
DEPS32="glibc-devel.i686 libgcc.i686 zlib-devel.i686 \
        libX11-devel.i686 libXext-devel.i686 libXrender-devel.i686 libXcursor-devel.i686 \
        libXrandr-devel.i686 libXi-devel.i686 libXfixes-devel.i686 libXcomposite-devel.i686 \
        libXinerama-devel.i686 libXxf86vm-devel.i686 \
        freetype-devel.i686 fontconfig-devel.i686 \
        libxml2-devel.i686 libxslt-devel.i686 ncurses-devel.i686"

install_32bit_deps() {
    if yum install -y --setopt=protected_multilib=false $DEPS32; then
        return 0
    fi
    # Usually a libstdc++.i686 printers.pyc/.pyo file conflict (a known CentOS 7 multilib bug)
    warn "Detected libstdc++.i686 file conflict — force-installing with --replacefiles..."
    yum install -y glibc.i686 libgcc.i686 || true
    mkdir -p /tmp/wine-deps
    yum install -y --downloadonly --downloaddir=/tmp/wine-deps libstdc++.i686 2>/dev/null || true
    local rpm_file
    rpm_file=$(find /tmp/wine-deps /var/cache/yum -name 'libstdc++-*.i686.rpm' 2>/dev/null | head -1)
    [ -n "$rpm_file" ] && rpm -Uvh --replacefiles "$rpm_file" || true
    yum install -y --setopt=protected_multilib=false $DEPS32
}
install_32bit_deps

# ---- 3. Download source ----
if [ ! -f "$SRC_DIR/configure" ]; then
    log "Downloading wine $WINE_VER source..."
    curl -fL -o "$WORK/wine.tar.xz" "$SRC_URL" || die "Download failed: $SRC_URL"
    tar -xf "$WORK/wine.tar.xz" -C "$WORK"
    rm -f "$WORK/wine.tar.xz"
fi
[ -f "$SRC_DIR/configure" ] || die "Source directory missing: $SRC_DIR"

# ---- 4. Build 64-bit ----
log "Configuring 64-bit (configure --enable-win64)..."
rm -rf "$BUILD64"; mkdir -p "$BUILD64"
( cd "$BUILD64" && "$SRC_DIR/configure" --enable-win64 > "$WORK/configure64.log" 2>&1 ) || true
grep -q 'Finished' "$WORK/configure64.log" || die "64-bit configure failed — see $WORK/configure64.log"

log "Building 64-bit (make -j$JOBS, ~20-30 min)..."
( cd "$BUILD64" && make -j"$JOBS" > "$WORK/make64.log" 2>&1 ) || true
grep -q 'Wine build complete' "$WORK/make64.log" || die "64-bit make failed — see $WORK/make64.log"
good "64-bit build complete"

# ---- 5. Build 32-bit ----
log "Configuring 32-bit (configure --with-wine64=$BUILD64)..."
rm -rf "$BUILD32"; mkdir -p "$BUILD32"
( cd "$BUILD32" && "$SRC_DIR/configure" --with-wine64="$BUILD64" > "$WORK/configure32.log" 2>&1 ) || true
grep -q 'Finished' "$WORK/configure32.log" || die "32-bit configure failed — see $WORK/configure32.log"

log "Building 32-bit (make -j$JOBS, ~20-30 min)..."
( cd "$BUILD32" && make -j"$JOBS" > "$WORK/make32.log" 2>&1 ) || true
grep -q 'Wine build complete' "$WORK/make32.log" || die "32-bit make failed — see $WORK/make32.log"
good "32-bit build complete"

# ---- 6. Install ----
log "Installing wine (64-bit then 32-bit)..."
( cd "$BUILD64" && make install > "$WORK/install64.log" 2>&1 )
( cd "$BUILD32" && make install > "$WORK/install32.log" 2>&1 )

# ---- 7. Verify ----
log "Verifying 32-bit wine..."
wine cmd /c echo __wine32ok__ 2>/dev/null | grep -q __wine32ok__ \
    && good "wine $(wine --version 2>/dev/null) 32-bit verified" \
    || die "32-bit verification failed — see $WORK/install32.log"

echo ""
good "wine 6.0 (32+64 bit) compiled and installed to /usr/local"
echo "    Any existing system wine 4.0.4 in /usr/bin is now shadowed by /usr/local/bin/wine"
