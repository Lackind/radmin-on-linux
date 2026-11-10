# Third-Party Notices

This project is licensed under the **GNU General Public License v3.0** (see `LICENSE`).

It bundles the following third-party components:

## noVNC — bundled in `novnc/`

- **License:** Mozilla Public License 2.0 (MPL-2.0)
- **Upstream:** <https://github.com/novnc/noVNC>
- **Copyright:** The noVNC Authors
- **License text:** `novnc/LICENSE.txt`

Bundled so the browser GUI (`run_datacenter.sh`) works on old systems where the
distro's noVNC is too old to connect.

## websockify — bundled in `websockify/`

- **License:** GNU Lesser General Public License v3.0 (LGPL-3.0)
- **Upstream:** <https://github.com/novnc/websockify>
- **Copyright:** The websockify Authors
- **License text:** `websockify/COPYING`

Bundled for the same reason as noVNC.

## Microsoft Visual C++ Redistributable runtime DLLs — bundled in `prebuilt/vc/`

- **Components:** `msvcp140.dll`, `msvcp140_1.dll`, `msvcp140_2.dll`,
  `msvcp140_atomic_wait.dll`, `msvcp140_codecvt_ids.dll`, `vcruntime140.dll`,
  `vcruntime140_threads.dll`, `concrt140.dll`, `vccorlib140.dll`
- **License:** Microsoft Visual C++ 2015-2019 Redistributable terms (redistribution permitted)
- **Copyright:** Microsoft Corporation

These are Microsoft's redistributable runtime files, needed because wine 6.0's
built-in `msvcp140_1.dll` lacks `_Aligned_get_default_resource` (used by Radmin's
Qt GUI). Redistribution of these runtime DLLs is permitted by Microsoft's
redistributable terms.

## Windows PE bridge binaries — bundled in `prebuilt/`

- **Components:** `rvpnnetmp.sys`, `adapter_hook.dll`, `rvpn_launcher.exe`,
  `netsh.exe`, `netsh64.exe`, `drvinst.exe`
- **License:** GPL-3.0 (built from this repository's `src/` sources)

These are built by the original project's CI from the GPL-3.0 source and shipped
pre-built so old systems don't need to install mingw-w64.
