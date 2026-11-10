<div align="center">

**English** · [**简体中文**](README.zh-CN.md)

</div>

<div align="center">
  <h1>Radmin VPN on Linux</h1>
  <p>Run <a href="https://www.radmin-vpn.com/">Radmin VPN</a> on Linux via Wine — supports both <b>modern systems (Wine 11)</b> and <b>old systems (RHEL 7 / glibc 2.17)</b>.</p>
</div>

> A maintained fork of [zloyf0nerka1459/radminvpn-on-linux](https://github.com/zloyf0nerka1459/radminvpn-on-linux) that adds old-system support while keeping the original modern-system route intact.

## How it works

Radmin VPN is a 32-bit Windows program. Its Windows service talks to an NDIS miniport driver for the virtual network adapter. Wine doesn't support NDIS, so this project replaces the driver with its own implementation that bridges to a Linux TAP device:

```
Linux app ← TAP (radminvpn0) ← tap_bridge ← FIFO ← rvpnnetmp.sys (Wine driver) ← RvControlSvc.exe
```

## Choose your route

Pick **one** route based on your system, then follow it from top to bottom:

| Your system | Route |
|---|---|
| Modern (Wine ≥ 11 available) | **[Route A](#route-a-modern-systems-wine--11)** |
| Old (RHEL 7 / CentOS 7, glibc 2.17) | **[Route B](#route-b-old-systems-rhel-7--centos-7)** |

---

## Route A: Modern systems (Wine ≥ 11)

### Step 1 — Install Wine 11 (32-bit capable)

```bash
# Ubuntu / Debian
sudo apt install wine64 wine32

# Arch
sudo pacman -S wine
```

*Effect: installs a Wine that can run 32-bit Radmin.*

### Step 2 — Install this project

```bash
curl -fsSL https://raw.githubusercontent.com/Lackind/Radmin-on-linux/main/install.sh | bash
```

*Effect: installs the project to `~/.local/share/radmin-vpn-linux-app`, creates the `radmin-vpn` launcher and a desktop entry.*

### Step 3 — Launch and join a network

```bash
radmin-vpn
```

*Effect: starts the service + GUI. Create or join a network in the GUI — the membership is saved, and the VPN connects.*

That's it. Run `radmin-vpn` whenever you want the VPN up.

---

## Route B: Old systems (RHEL 7 / CentOS 7)

### Step 0 — Get a Radmin installer

Download **`Radmin_VPN_2.1.4951.1.exe`** (or `2.0.4899.9`) from <https://www.radmin-vpn.com/> and put it in the repo directory (or `~/Downloads`). `install-old.sh` auto-detects it from either location.

### Step 1 — One-click install (30–60 min)

⚠ **This step makes these system-wide changes:**

| Change | Impact |
|---|---|
| Compiles & installs **wine 6.0 → `/usr/local`** | **Shadows any system wine** (e.g. 4.0.4) via PATH priority |
| **`yum install`** packages (Xvfb, x11vnc, CJK fonts) | Adds system packages |
| Installs & **enables a systemd service** (`radmin-vpn.service`) | **Auto-starts Radmin VPN on boot** |
| Creates a **TAP device** (`radminvpn0`) + `26.0.0.0/8` route | Changes network while running |

```bash
sudo bash install-old.sh
```

*Effect: compiles wine 6.0, installs dependencies, recompiles native binaries, installs Radmin VPN, enables the systemd service, then **verifies everything and exits**. Nothing is left running.*

### Step 2 — Start it and join a network (one-time)

This is where the VPN actually starts: `run_datacenter.sh` launches the Radmin GUI **and a VNC server** together, so you can join a network from another machine. Run it, then connect **one of two ways**:

```bash
bash run_datacenter.sh
```

**A) Browser (noVNC) — port `6080`, LAN-accessible by default**

Open in a browser on the same network:

```
http://<server-ip>:6080/vnc_lite.html
```

> ⚠ noVNC is an **unauthenticated, root-capable desktop**, reachable on the LAN by default. On any network you don't fully trust, add `--vnc-password <pw>`, or keep it host-only with `--web-bind 127.0.0.1` (then use an SSH tunnel: `ssh -L 6080:localhost:6080 root@<server-ip>`).

**B) VNC client — port `5900` (more reliable on old systems)**

```bash
# SSH tunnel:
ssh -L 5900:localhost:5900 root@<server-ip>
# Then connect a VNC client (e.g. TigerVNC) to:
localhost:5900
```

Create or join a network in the GUI. When done, press **Ctrl+C** in that terminal to stop the GUI — the membership is saved in the wineprefix, so `run_vps.sh` (headless) reconnects automatically in the next step.

### Step 3 — Run it (daily)

Step 2's Ctrl+C left the VPN **stopped** — joining a network only records it; it doesn't keep a tunnel running. This step starts the VPN for real, headless and lightweight (no GUI/VNC), reconnecting to the network you joined:

```bash
systemctl start radmin-vpn      # background, auto-restarts on failure, survives SSH disconnect
# or, to watch it in the foreground:
bash run_vps.sh
```

*Effect: the service is up and connected to your joined network. The systemd unit is also enabled, so it auto-starts on every boot — you only run this now to bring it up immediately.*

---

## Reference

Details you only need occasionally — not part of the walkthrough above.

### Launchers

| Launcher | When to use |
|---|---|
| `run_vps.sh` | **Daily** — headless service, no GUI |
| `run_datacenter.sh` | **Once** — browser GUI to join a network |
| `run.sh` | GUI + service (needs a display) |

### Command-line flags

| Flag | Description |
|---|---|
| `--installer <path>` | Path to the `Radmin_VPN_*.exe` installer (first run only) |
| `--no-ui` | Run the service without the GUI |
| `--update` | Upgrade Radmin in place, keeping the prefix/RID |
| `--no-broadcast-routes` | Skip the broadcast/multicast → TAP routes |
| `--filter-ui` | Launch the optional GTK4 packet-filter UI |
| `--fix-chat` | Patch Qt's `qwindows.dll` to fix the chat crash |

`run_datacenter.sh` additionally:

| Flag | Default | Description |
|---|---|---|
| `--vnc-port <n>` | `5900` | x11vnc server port |
| `--web-port <n>` | `6080` | noVNC web port |
| `--vnc-password <pw>` | *(none)* | VNC / web password |
| `--web-bind <addr>` | `0.0.0.0` | noVNC listen address (LAN-accessible by default; use `--vnc-password` on untrusted networks, or `127.0.0.1` for SSH-tunnel-only) |

### Build from source

**Prerequisites** (modern route): `gcc`, `make`, and the `mingw-w64` cross-compilers (`i686-w64-mingw32-gcc`, `x86_64-w64-mingw32-gcc`), plus GTK4 dev for the optional filter UI.

```bash
# Ubuntu / Debian
sudo apt install gcc-mingw-w64 libgtk-4-dev
# Arch
sudo pacman -S mingw-w64-gcc gtk4
```

**Modern route** — build everything:

```bash
make          # build everything to build/
make clean    # remove build artifacts
```

Produces:

| Artifact | Description |
|---|---|
| `build/rvpnnetmp.sys` | Wine kernel driver (64-bit PE) |
| `build/adapter_hook.dll` | Hook DLL (32-bit PE) |
| `build/rvpn_launcher.exe` | DLL injector (32-bit PE) |
| `build/netsh.exe` / `build/netsh64.exe` | netsh replacements (32/64-bit PE) |
| `build/drvinst.exe` | no-op stub replacing Radmin's real driver installer |
| `build/tap_bridge` | native Linux TAP bridge |
| `build/rvpn_dnsfix.so` | native LD_PRELOAD shim (reverse-DNS fix) |
| `build/rvpn_reuseport.so` | native LD_PRELOAD shim (SO_REUSEPORT fix) |
| `build/rvpn_filter_ui` | optional GTK4 packet-filter UI |

**Old route** — the PE files ship pre-built in `prebuilt/`, so only the native binaries are compiled:

```bash
bash build-wine6.sh     # compile wine 6.0 (32+64) → /usr/local
bash build-native.sh    # recompile native binaries → build/
cp -a prebuilt/. build/ # copy the PE files
```

**Build the AppImage** (modern route; needs `curl` + ImageMagick):

```bash
make
./packaging/build-appimage.sh    # → packaging/dist/RadminVPN-Linux-x86_64.AppImage
```

Downloads the Kron4ek Wine-Staging `amd64-wow64` build and `appimagetool` on first run.

### Troubleshooting

- **`GLIBC_2.xx not found` running tap_bridge** → run `bash build-native.sh` to rebuild for the host glibc.
- **32-bit deps fail (libstdc++.i686 conflict)** → known CentOS 7 multilib bug; `build-wine6.sh` handles it.
- **Installer stuck at "Running installer..."** → `DISPLAY` not set: `Xvfb :99 -screen 0 1024x768x24 &` then `export DISPLAY=:99`.
- **Installer pops an "Error" dialog** → `xwininfo -root -tree -display :99` to see the title.
- **GUI shows square glyphs** → missing CJK fonts: `yum install -y wqy-microhei-fonts cjkuni-uming-fonts`.
- **`unimplemented function msvcp140_1.dll...`** → native DLLs ship in `prebuilt/vc/` and install automatically.
- **noVNC "connection is closed"** → bundled noVNC 1.5 + websockify 0.12 are used automatically.
- **Service reports "died" right after start** → the check now matches `RvControlSvc|rvpn_launcher`, giving it time to spawn.
- **Out of memory during compile** → `JOBS=2 sudo bash build-wine6.sh`.

### Known limitations

- One instance at a time (shared FIFOs in `/tmp/`)
- `26.0.0.0/8` on-link route affects the whole system while running (removed on exit)
- Broadcast/multicast routes are steered to the VPN (disable with `--no-broadcast-routes`)
- The optional `rv_net_enum.exe` (custom network enumerator) is **not shipped**

## Repository layout

| Path | Purpose |
|---|---|
| `install.sh` / `install-old.sh` | one-click installers (modern / old) |
| `run.sh` / `run_vps.sh` / `run_datacenter.sh` | GUI / headless / browser launchers |
| `lib.sh` | shared library |
| `build-wine6.sh` / `build-native.sh` | old-system build scripts |
| `prebuilt/` | Windows PE files + VC++ runtime DLLs |
| `novnc/` + `websockify/` | bundled modern browser GUI |
| `radmin-vpn.service` | systemd unit template |
| `src/` + `Makefile` | project source |

## Third-party notices

See [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

## Credits

Original reverse-engineering and NDIS-to-TAP architecture by [baptisterajaut/radmin-vpn-linux](https://github.com/baptisterajaut/radmin-vpn-linux); Wine 11 fixes and the one-line installer by [zloyf0nerka1459/radminvpn-on-linux](https://github.com/zloyf0nerka1459/radminvpn-on-linux). This fork adds old-system support.

## License

GPL-3.0. See [LICENSE](LICENSE). Radmin VPN is proprietary software by Famatech Corp.; this project ships interoperability tools only.
