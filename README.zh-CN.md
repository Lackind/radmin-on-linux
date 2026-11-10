<div align="center">

[**English**](README.md) · **简体中文**

</div>

<div align="center">
  <h1>Radmin VPN on Linux</h1>
  <p>通过 Wine 在 Linux 上运行 <a href="https://www.radmin-vpn.com/">Radmin VPN</a> —— 同时支持 <b>新系统（Wine 11）</b>和 <b>老系统（RHEL 7 / glibc 2.17）</b>。</p>
</div>

> 基于 [zloyf0nerka1459/radminvpn-on-linux](https://github.com/zloyf0nerka1459/radminvpn-on-linux) 的维护分支，新增老系统支持，同时保留原版新系统路线。

## 工作原理

Radmin VPN 是 32 位 Windows 程序。它的 Windows 服务通过一个 NDIS 迷你端口驱动来操作虚拟网卡。Wine 不支持 NDIS，所以本项目用自己的实现替换了驱动，把它桥接到 Linux 的 TAP 设备上：

```
Linux 应用 ← TAP (radminvpn0) ← tap_bridge ← FIFO ← rvpnnetmp.sys (Wine 驱动) ← RvControlSvc.exe
```

## 选择你的路线

根据你的系统**选一条**路线，然后从上到下依次执行：

| 你的系统 | 路线 |
|---|---|
| 新系统（能装 Wine ≥ 11） | **[路线 A](#路线-a新系统-wine--11)** |
| 老系统（RHEL 7 / CentOS 7，glibc 2.17） | **[路线 B](#路线-b老系统-rhel-7--centos-7)** |

---

## 路线 A：新系统（Wine ≥ 11）

### 第 1 步 — 安装 Wine 11（含 32 位支持）

```bash
# Ubuntu / Debian
sudo apt install wine64 wine32

# Arch
sudo pacman -S wine
```

*效果：装好能跑 32 位 Radmin 的 Wine。*

### 第 2 步 — 安装本项目

```bash
curl -fsSL https://raw.githubusercontent.com/Lackind/Radmin-on-linux/main/install.sh | bash
```

*效果：把项目装到 `~/.local/share/radmin-vpn-linux-app`，创建 `radmin-vpn` 启动命令和桌面入口。*

### 第 3 步 — 启动并加入网络

```bash
radmin-vpn
```

*效果：启动服务 + GUI。在 GUI 里创建或加入网络，成员关系会被保存，VPN 随即连上。*

以后每次想用 VPN 就运行 `radmin-vpn` 即可。

---

## 路线 B：老系统（RHEL 7 / CentOS 7）

### 第 0 步 — 准备 Radmin 安装器

从 <https://www.radmin-vpn.com/> 下载 **`Radmin_VPN_2.1.4951.1.exe`**（或 `2.0.4899.9`），放到仓库目录（或 `~/Downloads`）。`install-old.sh` 会在这两个位置自动找到它。

### 第 1 步 — 一键安装（30–60 分钟）

⚠ **这一步会做以下系统级修改：**

| 修改 | 影响 |
|---|---|
| 编译并安装 **wine 6.0 → `/usr/local`** | **覆盖系统原有 wine**（如 4.0.4）的 PATH 优先级 |
| **`yum install`** 装包（Xvfb、x11vnc、中文字体） | 新增系统软件包 |
| 安装并**启用 systemd 服务**（`radmin-vpn.service`） | **开机自动启动 Radmin VPN** |
| 创建 **TAP 网卡**（`radminvpn0`）+ `26.0.0.0/8` 路由 | 运行时改动网络 |

```bash
sudo bash install-old.sh
```

*效果：编译 wine 6.0、装依赖、重编原生二进制、安装 Radmin VPN、启用 systemd 服务，然后**校验安装并退出**。不会留下任何运行中的东西。*

### 第 2 步 — 启动并加入网络（一次性）

这一步才是真正启动：`run_datacenter.sh` 会**同时启动 Radmin GUI 和 VNC 服务**，让你能从另一台机器加入网络。先运行它，再用**下面两种方式之一**连上去：

```bash
bash run_datacenter.sh
```

**方式 A：浏览器（noVNC）—— 端口 `6080`，默认局域网可访问**

在同一网络的浏览器里直接打开：

```
http://<服务器IP>:6080/vnc_lite.html
```

> ⚠ noVNC 是**无密码、root 权限**的桌面，默认就在局域网开放。在不完全可信的网络上，加 `--vnc-password <密码>`，或用 `--web-bind 127.0.0.1` 只监听本机（再走 SSH 隧道：`ssh -L 6080:localhost:6080 root@<服务器IP>`）。

**方式 B：VNC 客户端 —— 端口 `5900`（老系统上更可靠）**

```bash
# SSH 隧道：
ssh -L 5900:localhost:5900 root@<服务器IP>
# 然后用 VNC 客户端（如 TigerVNC）连：
localhost:5900
```

在 GUI 里创建或加入网络。加完后，在那个终端按 **Ctrl+C** 停掉 GUI——成员关系已存进 wineprefix，下一步 `run_vps.sh`（headless）会自动重连。

### 第 3 步 — 日常运行

第 2 步 Ctrl+C 之后 VPN 是**停的**——加入网络只是"登记"，并不会让隧道一直跑。这一步才真正启动 VPN，headless、轻量（无 GUI/VNC），自动连回你加入的网络：

```bash
systemctl start radmin-vpn      # 后台运行，失败自动重启，SSH 断开也不死
# 或前台观察：
bash run_vps.sh
```

*效果：服务起来并连上你加入的网络。systemd 单元也已 enable，每次开机自动启动——现在跑一次只是让它立刻生效。*

---

## 参考

偶尔才需要看的内容——不属于上面的操作流程。

### 启动器

| 启动器 | 何时用 |
|---|---|
| `run_vps.sh` | **日常** —— headless 服务，无 GUI |
| `run_datacenter.sh` | **一次性** —— 浏览器 GUI，用于加入网络 |
| `run.sh` | GUI + 服务（需要显示器） |

### 命令行参数

| 参数 | 说明 |
|---|---|
| `--installer <路径>` | 指定 `Radmin_VPN_*.exe` 安装器（仅首次） |
| `--no-ui` | 只跑服务，不启动 GUI |
| `--update` | 原地升级 Radmin，保留 prefix/RID |
| `--no-broadcast-routes` | 跳过广播/组播 → TAP 的路由 |
| `--filter-ui` | 启动可选的 GTK4 数据包过滤界面 |
| `--fix-chat` | 修补 Qt 的 `qwindows.dll` 修复聊天崩溃 |

`run_datacenter.sh` 额外支持：

| 参数 | 默认 | 说明 |
|---|---|---|
| `--vnc-port <n>` | `5900` | x11vnc 服务端口 |
| `--web-port <n>` | `6080` | noVNC 网页端口 |
| `--vnc-password <pw>` | *(无)* | VNC / 网页密码 |
| `--web-bind <addr>` | `0.0.0.0` | noVNC 监听地址（默认局域网可访问；不可信网络请加 `--vnc-password`，或设 `127.0.0.1` 只走 SSH 隧道） |

### 从源码编译

**前提**（新系统路线）：`gcc`、`make`，以及 `mingw-w64` 交叉编译器（`i686-w64-mingw32-gcc`、`x86_64-w64-mingw32-gcc`），可选的 GTK4 开发库。

```bash
# Ubuntu / Debian
sudo apt install gcc-mingw-w64 libgtk-4-dev
# Arch
sudo pacman -S mingw-w64-gcc gtk4
```

**新系统路线** —— 编译所有产物：

```bash
make          # 编译所有产物到 build/
make clean    # 清理
```

产物：

| 产物 | 说明 |
|---|---|
| `build/rvpnnetmp.sys` | Wine 内核驱动（64 位 PE） |
| `build/adapter_hook.dll` | 钩子 DLL（32 位 PE） |
| `build/rvpn_launcher.exe` | DLL 注入器（32 位 PE） |
| `build/netsh.exe` / `build/netsh64.exe` | netsh 替换（32/64 位 PE） |
| `build/drvinst.exe` | 空壳，替换 Radmin 真正的驱动安装器 |
| `build/tap_bridge` | 原生 Linux TAP 桥接 |
| `build/rvpn_dnsfix.so` | 原生 LD_PRELOAD 垫片（反向 DNS 修复） |
| `build/rvpn_reuseport.so` | 原生 LD_PRELOAD 垫片（SO_REUSEPORT 修复） |
| `build/rvpn_filter_ui` | 可选 GTK4 数据包过滤界面 |

**老系统路线** —— PE 文件已随仓库在 `prebuilt/`，只需编译原生二进制：

```bash
bash build-wine6.sh     # 编译 wine 6.0 (32+64) → /usr/local
bash build-native.sh    # 重编原生二进制 → build/
cp -a prebuilt/. build/ # 装入 PE 文件
```

**构建 AppImage**（新系统路线，需 `curl` + ImageMagick）：

```bash
make
./packaging/build-appimage.sh    # → packaging/dist/RadminVPN-Linux-x86_64.AppImage
```

首次运行会下载 Kron4ek Wine-Staging `amd64-wow64` 和 `appimagetool`。

### 常见问题

- **运行 tap_bridge 报 `GLIBC_2.xx not found`** → 运行 `bash build-native.sh` 针对本机 glibc 重编。
- **32 位依赖装不上（libstdc++.i686 冲突）** → CentOS 7 已知 multilib bug，`build-wine6.sh` 已处理。
- **安装器卡在 "Running installer..."** → 没设 `DISPLAY`：`Xvfb :99 -screen 0 1024x768x24 &` 然后 `export DISPLAY=:99`。
- **安装器弹"错误"对话框** → `xwininfo -root -tree -display :99` 看窗口标题。
- **GUI 里全是方块** → 缺中文字体：`yum install -y wqy-microhei-fonts cjkuni-uming-fonts`。
- **报 `unimplemented function msvcp140_1.dll...`** → 原生 DLL 随仓库在 `prebuilt/vc/`，自动安装。
- **noVNC 报 "connection is closed"** → 自动使用打包的 noVNC 1.5 + websockify 0.12。
- **服务刚启动就报"died"** → 检查已改为同时匹配 `RvControlSvc|rvpn_launcher`，给它几秒 spawn。
- **编译内存不足被 kill** → `JOBS=2 sudo bash build-wine6.sh`。

### 已知限制

- 一次只能跑一个实例（共享 `/tmp/` 下的 FIFO）
- 运行时 `26.0.0.0/8` 的 on-link 路由影响整个系统（退出时清理）
- 广播/组播路由被指向 VPN（用 `--no-broadcast-routes` 关闭）
- 可选的 `rv_net_enum.exe`（自定义网络枚举器）**不在本仓库**

## 目录说明

| 路径 | 作用 |
|---|---|
| `install.sh` / `install-old.sh` | 一键安装（新 / 老） |
| `run.sh` / `run_vps.sh` / `run_datacenter.sh` | GUI / headless / 浏览器 启动器 |
| `lib.sh` | 共享库 |
| `build-wine6.sh` / `build-native.sh` | 老系统编译脚本 |
| `prebuilt/` | Windows PE 文件 + VC++ 运行库 DLL |
| `novnc/` + `websockify/` | 打包的新版浏览器 GUI |
| `radmin-vpn.service` | systemd 单元模板 |
| `src/` + `Makefile` | 项目源码 |

## 第三方声明

见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。

## 致谢

原始逆向工程和 NDIS→TAP 架构归功于 [baptisterajaut/radmin-vpn-linux](https://github.com/baptisterajaut/radmin-vpn-linux)；Wine 11 修复和一键安装器归功于 [zloyf0nerka1459/radminvpn-on-linux](https://github.com/zloyf0nerka1459/radminvpn-on-linux)。本仓库新增老系统支持。

## 许可证

GPL-3.0。见 [LICENSE](LICENSE)。Radmin VPN 是 Famatech Corp. 的专有软件，本仓库只提供互操作工具。
