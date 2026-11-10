#!/usr/bin/env bash
# ==============================================================================
#  build-native.sh — Recompile Radmin VPN's native Linux binaries on this host.
#
#  Why: the official release tarball's tap_bridge / rvpn_dnsfix.so / rvpn_reuseport.so
#  are built by CI on ubuntu-latest (glibc 2.39) and fail on older glibc
#  (e.g. RHEL 7's 2.17) with "version `GLIBC_2.xx' not found".
#
#  This script recompiles the three pure-C native binaries with the host gcc
#  (-std=gnu99 for gcc 4.8 compatibility). The Windows PE files
#  (rvpnnetmp.sys / adapter_hook.dll / *.exe) run inside Wine and do NOT depend
#  on the host glibc, so the ones in prebuilt/ are used as-is.
#
#  Usage: bash build-native.sh
#  Requires: gcc + glibc-devel (RHEL 7: yum install gcc glibc-devel)
# ==============================================================================
set -euo pipefail

cd "$(dirname "$0")"
[ -f src/tap_bridge.c ] || { echo "[-] Run this script from the repository root" >&2; exit 1; }
command -v gcc >/dev/null || { echo "[-] gcc not found. Install it first: yum install gcc glibc-devel" >&2; exit 1; }

mkdir -p build
echo "[*] Compiler: $(gcc --version | head -n1)"

# -std=gnu99: gcc 4.8 defaults to gnu90, but the source uses C99 for(int i=...) declarations
CFLAGS="-Wall -O2 -std=gnu99"

gcc $CFLAGS -o build/tap_bridge src/tap_bridge.c -lpthread
gcc $CFLAGS -shared -fPIC -o build/rvpn_dnsfix.so    src/rvpn_dnsfix.c    -ldl
gcc $CFLAGS -shared -fPIC -o build/rvpn_reuseport.so src/rvpn_reuseport.c -ldl

# rvpn_filter_ui needs GTK4 (unavailable on old systems) and is only used with
# --filter-ui. Remove it to avoid a glibc mismatch.
rm -f build/rvpn_filter_ui

echo "[+] Done. tap_bridge / rvpn_dnsfix.so / rvpn_reuseport.so rebuilt for this host's glibc."
echo "    The Windows PE files don't need rebuilding — use the ones in prebuilt/."
