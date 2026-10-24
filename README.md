# ⚡ server-my-pc ⚡

> **Convert any personal PC or laptop into an always-on, 24/7 high-performance bare-metal server in a single click.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Linux Support](https://img.shields.io/badge/Linux-Ubuntu%20%7C%20Debian%20%7C%20Arch%20%7C%20Fedora%20%7C%20RHEL%20%7C%20openSUSE%20%7C%20Alpine-green.svg)](setup.sh)
[![Windows Support](https://img.shields.io/badge/Windows-10%20%7C%2011%20%7C%20Server-0078D6.svg)](setup.ps1)
[![Cockpit Ready](https://img.shields.io/badge/Web%20Console-Cockpit-red.svg)](https://cockpit-project.org/)
[![Docker Ready](https://img.shields.io/badge/Docker-Engine%20%26%20Compose-blue.svg)](https://www.docker.com/)

---

```
  ____                                __  __           ____   ____ 
 / ___|  ___ _ ____   _____ _ __     |  \/  |_   _    |  _ \ / ___|
 \___ \ / _ \ '__\ \ / / _ \ '__|____| |\/| | | | |___| |_) | |    
  ___) |  __/ |   \ V /  __/ | |_____| |  | | |_| |___|  __/| |___ 
 |____/ \___|_|    \_/ \___|_|       |_|  |_|\__, |   |_|    \____|
                                             |___/                 
```

Have an old laptop, desktop, or spare computer collecting dust? **`server-my-pc`** turns it into a full-fledged, 24/7 home/cloud server with OpenSSH, automated 24/7 lid-close sleep bypass, self-healing network watchdogs, a browser web console, Docker, firewall protection, and bare-metal telemetry.

**No cloud accounts required. No third-party lock-in. Just pure, fast, bare-metal server power.**

---

## 🚀 Quick Start (1-Click Run)

### ⚡ No Git Installed? No Problem! (Instant 1-Liner)

#### 🐧 On Linux (No Git Required):
Paste into your terminal and press Enter:
```bash
curl -sSL https://raw.githubusercontent.com/8nc0x/server-my-pc/main/setup.sh | sudo bash
```
*(Or if your machine only has `wget`: `wget -qO- https://raw.githubusercontent.com/8nc0x/server-my-pc/main/setup.sh | sudo bash`)*

#### 🪟 On Windows (No Git Required):
Open **PowerShell as Administrator** and paste:
```powershell
irm https://raw.githubusercontent.com/8nc0x/server-my-pc/main/setup.ps1 | iex
```

---

### 📦 Standard Git Clone Method

#### 🐧 Linux:
```bash
git clone https://github.com/8nc0x/server-my-pc.git
cd server-my-pc
sudo bash setup.sh
```

#### 🪟 Windows:
1. Clone or download the repository.
2. Right-click **`setup.bat`** and select **"Run as administrator"**.
   *(Or in Administrator PowerShell: `powershell -ExecutionPolicy Bypass -File .\setup.ps1`)*

---

## 🌟 What This Script Does Automatically

| Feature | Description |
|---|---|
| **🔌 24/7 Lid-Close Always-On** | Overrides `systemd-logind` and power policies. Shut your laptop lid and the server stays 100% running with zero sleep or screen blanking lockups. |
| **🛡️ OpenSSH Ready & Hardened** | Pre-configures OpenSSH Server, disables empty passwords, keeps idle connections alive, and enables key-based or password auth. |
| **👑 Full User Sudo Rights** | Grants your specified server user full administrative passwordless `sudo` privileges. |
| **🧱 Firewall & Fail2ban Defense** | Configures UFW/firewalld with default-deny inbound, allows SSH and web dashboard ports, and blocks brute-force attackers via Fail2ban. |
| **🌐 Automatic Router UPnP Port Forward** | Uses standard UPnP protocol to automatically forward SSH and Dashboard ports on your home Wi-Fi router without manual router login. |
| **🛰️ Zero-Signup CGNAT Tunnel Fallback** | Stuck behind strict mobile hotspot or ISP CGNAT where port forwarding is blocked? Run `serverctl tunnel start` for an immediate, free, encrypted public endpoint with zero accounts needed. |
| **💻 Cockpit Web Dashboard** | Gives you an instant browser-based server control panel and root terminal at `https://<server-ip>:9090` without needing an SSH client. |
| **🔄 Self-Healing Network Watchdog** | Background daemon pings your gateway every 60s. If Wi-Fi or Ethernet disconnects, it automatically recovers the network without manual intervention. |
| **🌡️ Thermal Guard & Closed-Lid Safety** | Monitors CPU package temperature; alerts if closed-lid thermals reach critical levels. |
| **🔋 Battery Swelling Protection** | Automatically limits laptop battery charging to 80% (on supported hardware) so keeping it plugged in 24/7 won't degrade or swell the battery. |
| **🚀 TCP BBR & Kernel Performance** | Activates Google BBR congestion control, enables IP forwarding (VPN/Docker ready), increases file descriptor limits (`2M+`), and sets swappiness to 10. |
| **⚡ Wake-On-LAN (WOL)** | Activates hardware Magic Packet wake-up on all Ethernet interfaces. |
| **🐳 Docker Engine & App Catalog** | Installs Docker Engine & Compose with a 1-click catalog (`serverctl apps install portainer/nginx-proxy-manager/filebrowser/uptime-kuma`). |

---

## 🎛️ Installation Presets

Choose the exact depth of installation that suits your needs:

```bash
# Standard Preset (Default: OpenSSH, 24/7 Lid, UFW, Watchdog, Cockpit Web Console, BBR)
sudo bash setup.sh --preset standard

# Minimal Preset (Only OpenSSH, 24/7 Lid, Sleep Mask, UFW, serverctl)
sudo bash setup.sh --preset minimal

# Ultimate Preset (Standard + Docker Engine & Compose + App Catalog + CGNAT Tunnel Helper)
sudo bash setup.sh --preset ultimate

# Hardened Preset (Ultimate + Aggressive Fail2ban jail + Strict SSH auditing)
sudo bash setup.sh --preset hardened
```

### CLI Options

| Flag | Description |
|---|---|
| `-y, --yes` | Run non-interactively without confirmation prompts |
| `--ssh-port <port>` | Configure a custom SSH port (e.g. `--ssh-port 2222`) |
| `--user <username>` | Specify target user for server administration |
| `--no-docker` | Skip Docker Engine installation |
| `--no-cockpit` | Skip Cockpit Web Console installation |
| `--no-upnp` | Skip automatic router UPnP port forwarding |
| `--status` | Check server health, telemetry, and service state |
| `--uninstall` | Completely revert 24/7 power settings and restore original PC defaults |

---

## 🛠️ The `serverctl` Management CLI

`setup.sh` installs a global, high-power management CLI available anywhere in your terminal:

```bash
# View comprehensive system & network telemetry
serverctl status

# Launch live, real-time interactive terminal dashboard (TUI)
serverctl dashboard

# Print ready-to-copy SSH commands, IP addresses, and Cockpit URL
serverctl info

# Open/Close firewall ports and trigger router UPnP
sudo serverctl open-port 8080 tcp
sudo serverctl close-port 8080 tcp

# 1-Click Docker App Deployments
serverctl apps list
sudo serverctl apps install portainer
sudo serverctl apps install nginx-proxy-manager
sudo serverctl apps install filebrowser
sudo serverctl apps install uptime-kuma

# Zero-Signup CGNAT Remote Access Tunnel
sudo serverctl tunnel start
serverctl tunnel status
sudo serverctl tunnel stop

# Hardware & Power Controls
sudo serverctl lid [ignore|normal|status]
serverctl battery [status|limit 80]

# Security & Fail2ban Audit
serverctl security audit
serverctl security banned
sudo serverctl security unban <ip>

# Webhook Alerting (Discord / Telegram on boot / IP change)
sudo serverctl notify setup
serverctl notify test

# 24/7 Reboot Persistence & Stickiness Telemetry
serverctl persistence
serverctl bios

# Live Log Viewer
serverctl logs ssh
serverctl logs fail2ban
serverctl logs watchdog
serverctl logs thermal

# Network Latency & Speedtest
serverctl speedtest

# Clean Uninstall & System Restoration
sudo serverctl uninstall
```

---

## 🔄 24/7 Reboot Survival & Stickiness Engine

What happens if the power goes out, or the computer is turned off and turned back on?
**Everything is 100% persistent and sticky.**

```
                                      PC BOOTS UP
                                           │
             ┌─────────────────────────────┴─────────────────────────────┐
             ▼                                                           ▼
       [Linux Systemd]                                            [Windows Services]
   server-my-pc-boot.service                                 server-my-pc-boot Task
             │                                                           │
             ├─► Re-masks sleep/suspend targets                          ├─► Re-applies 24/7 power policies
             ├─► Enforces 80% battery swelling protection                ├─► Verifies OpenSSH running
             ├─► Re-announces router UPnP port maps                      ├─► Re-applies firewall rules
             ├─► Auto-resumes CGNAT tunnel (if enabled)                  └─► Operates BEFORE user login
             ├─► Restarts Docker containers (--restart=always)
             └─► Sends Boot Alert (Discord/Telegram webhook)
```

### 1. Headless Startup Before Login
- **Linux**: Systemd units (`sshd`, `cockpit`, `docker`, `server-watchdog`, `server-my-pc-boot`) run in `multi-user.target`. They start immediately on boot **without requiring anyone to log into the desktop or terminal**.
- **Windows**: `sshd` runs as a native Windows Service under `NT AUTHORITY\SYSTEM`. The `server-my-pc-boot` Scheduled Task triggers `AtStartup` with Highest Privileges, keeping the server active even when sitting on the Windows Lock screen.

### 2. Auto-Reannouncing UPnP Port Maps
When a home router or PC reboots, the router often wipes its UPnP table. The `server-my-pc-boot` engine automatically re-announces Port 22 and Port 9090 to your Wi-Fi router on every startup, ensuring external access is never lost.

### 3. Turning ON Automatically After Power Loss (BIOS AC Recovery)
If power cuts at home and restores later, you can make your computer turn itself on automatically:
```bash
serverctl bios
```
Follow the simple steps in your motherboard's BIOS to set **"Restore on AC/Power Loss"** or **"Wake on AC"** to **Power On**. Once enabled, your machine will automatically boot up whenever plugged in, without needing anyone to press the power button!

## 📡 Remote Access & Port Forwarding Guide

When `setup.sh` finishes, it outputs your exact connection commands:

```
┌── 24/7 SERVER CONNECTION DETAILS ──────────────────────────────────────────┐
│  Local Network IP (LAN)  : 192.168.1.50                                    │
│  Public Internet IP (WAN): 203.0.113.195                                   │
│  SSH Port                : 22                                              │
│  Server User             : owner                                           │
├── READY-TO-COPY SSH COMMANDS ──────────────────────────────────────────────┤
│  Connect from Home WiFi  : ssh owner@192.168.1.50                          │
│  Connect from Outside    : ssh owner@203.0.113.195                         │
├── WEB MANAGEMENT CONSOLE (COCKPIT) ────────────────────────────────────────┤
│  Web Terminal & Admin    : https://192.168.1.50:9090                       │
└────────────────────────────────────────────────────────────────────────────┘
```

### Accessing From Anywhere (Outside Home WiFi)

1. **Option A: Automatic UPnP (Default)**
   - `setup.sh` automatically attempts to open the port on your router via UPnP. If your router supports UPnP, `ssh user@PUBLIC_IP` will work immediately!

2. **Option B: Manual Router Port Forwarding**
   - Open your router admin page (e.g. `http://192.168.1.1` or `192.168.0.1`).
   - Go to **Port Forwarding / Virtual Servers**.
   - Forward **Port 22 (TCP)** to your server's Local IP (`192.168.1.x`).
   - Optional: Forward **Port 9090 (TCP)** to access the Cockpit Web Console remotely.

3. **Option C: Zero-Signup Cloudflare Quick Tunnel (For CGNAT / Blocked Routers)**
   - If your ISP uses CGNAT or your router blocks port forwarding, run:
     ```bash
     sudo serverctl tunnel start
     ```
   - This provides an instant, zero-account encrypted public hostname that lets you SSH in from anywhere in the world!

---

## 🔄 Reverting / Uninstallation

If you ever want to turn your laptop back into a normal consumer laptop:

```bash
sudo serverctl uninstall
```

This immediately unmasks sleep targets, restores standard laptop lid-close sleep behavior, disables background watchdogs, removes sysctl kernel tuning, and cleans up configuration files without deleting your apps.

---

## 📄 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for details.
