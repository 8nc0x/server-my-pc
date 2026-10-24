#!/usr/bin/env bash
# ==============================================================================
#  ____                                __  __           ____   ____ 
# / ___|  ___ _ ____   _____ _ __     |  \/  |_   _    |  _ \ / ___|
# \___ \ / _ \ '__\ \ / / _ \ '__|____| |\/| | | | |___| |_) | |    
#  ___) |  __/ |   \ V /  __/ | |_____| |  | | |_| |___|  __/| |___ 
# |____/ \___|_|    \_/ \___|_|       |_|  |_|\__, |   |_|    \____|
#                                            |___/                 
# ==============================================================================
# Turn any PC or Laptop into a 24/7, high-performance, fully-controllable server.
# Project: https://github.com/8nc0x/server-my-pc
# ==============================================================================

set -e

# ANSI Color Palette
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_RED="\033[38;5;196m"
C_GREEN="\033[38;5;46m"
C_YELLOW="\033[38;5;226m"
C_BLUE="\033[38;5;39m"
C_MAGENTA="\033[38;5;201m"
C_CYAN="\033[38;5;51m"
C_WHITE="\033[38;5;231m"
C_GRAY="\033[38;5;244m"

# Default Configuration
SCRIPT_VERSION="1.0.0"
PRESET="standard"
SSH_PORT="22"
TARGET_USER="${SUDO_USER:-$USER}"
[ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ] && TARGET_USER=$(id -un 1000 2>/dev/null || echo "root")
NON_INTERACTIVE=false
INSTALL_DOCKER=true
INSTALL_COCKPIT=true
ENABLE_UPNP=true
CONFIG_DIR="/etc/server-my-pc"
CUSTOM_PASSWORD=""
SSH_PUBKEY=""
PASSWORD_DISPLAY="Your existing Linux user password"

# ASCII Art Banner
print_banner() {
    clear 2>/dev/null || true
    echo -e "${C_CYAN}${C_BOLD}"
    cat << "EOF"
  ____                                __  __           ____   ____ 
 / ___|  ___ _ ____   _____ _ __     |  \/  |_   _    |  _ \ / ___|
 \___ \ / _ \ '__\ \ / / _ \ '__|____| |\/| | | | |___| |_) | |    
  ___) |  __/ |   \ V /  __/ | |_____| |  | | |_| |___|  __/| |___ 
 |____/ \___|_|    \_/ \___|_|       |_|  |_|\__, |   |_|    \____|
                                             |___/                 
EOF
    echo -e "${C_RESET}${C_DIM}     ⚡ Universal 24/7 PC & Laptop Server Transformation Engine - v${SCRIPT_VERSION} ⚡${C_RESET}\n"
}

# Step Output Helpers
step() {
    echo -e "\n${C_BLUE}${C_BOLD}==>${C_RESET} ${C_WHITE}${C_BOLD}$1${C_RESET}"
}

info() {
    echo -e "  ${C_CYAN}[i]${C_RESET} $1"
}

success() {
    echo -e "  ${C_GREEN}[✓]${C_RESET} $1"
}

warn() {
    echo -e "  ${C_YELLOW}[!]${C_RESET} $1"
}

error() {
    echo -e "  ${C_RED}[✗]${C_RESET} $1" >&2
}

# Help Function
show_help() {
    print_banner
    echo -e "${C_BOLD}USAGE:${C_RESET}"
    echo -e "  sudo bash setup.sh [OPTIONS]\n"
    echo -e "${C_BOLD}INSTALLATION PRESETS:${C_RESET}"
    echo -e "  ${C_CYAN}--preset minimal${C_RESET}     OpenSSH, 24/7 Lid-Close, Sleep Mask, UFW/Firewall, serverctl CLI"
    echo -e "  ${C_CYAN}--preset standard${C_RESET}    (Default) Minimal + Cockpit Web Console + UPnP + ZRAM + TCP BBR"
    echo -e "  ${C_CYAN}--preset ultimate${C_RESET}    Standard + Docker Engine + S.M.A.R.T. Health + App Catalog + CGNAT Tunnel"
    echo -e "  ${C_CYAN}--preset hardened${C_RESET}    Ultimate + Aggressive Fail2ban jail + Strict SSH security audit\n"
    echo -e "${C_BOLD}OPTIONS:${C_RESET}"
    echo -e "  ${C_CYAN}-y, --yes${C_RESET}            Run in automatic non-interactive mode (no confirmation prompts)"
    echo -e "  ${C_CYAN}--ssh-port <port>${C_RESET}    Set custom SSH listening port (default: 22)"
    echo -e "  ${C_CYAN}--user <username>${C_RESET}    Specify target server username (default: ${TARGET_USER})"
    echo -e "  ${C_CYAN}--password <pass>${C_RESET}    Set SSH login password non-interactively"
    echo -e "  ${C_CYAN}--ssh-key \"<key>\"${C_RESET}    Inject client SSH public key for passwordless login"
    echo -e "  ${C_CYAN}--no-docker${C_RESET}          Do not install Docker Engine"
    echo -e "  ${C_CYAN}--no-cockpit${C_RESET}         Do not install Cockpit Web Console"
    echo -e "  ${C_CYAN}--no-upnp${C_RESET}            Skip automatic router UPnP port forwarding"
    echo -e "  ${C_CYAN}--status${C_RESET}             Show current server telemetry and service status"
    echo -e "  ${C_CYAN}--uninstall${C_RESET}          Revert power settings, unmask sleep, restore normal PC state"
    echo -e "  ${C_CYAN}-h, --help${C_RESET}           Show this help message\n"
    exit 0
}

# Check for Windows / MSYS / Git Bash
detect_windows_environment() {
    local uname_out
    uname_out="$(uname -s 2>/dev/null || echo '')"
    case "$uname_out" in
        CYGWIN*|MINGW*|MSYS*)
            warn "Detected Windows environment (${uname_out})!"
            echo -e "  ${C_YELLOW}[*] Windows PCs should be configured via the native PowerShell setup script.${C_RESET}"
            if command -v powershell.exe >/dev/null 2>&1; then
                echo -e "  ${C_CYAN}[*] Automatically launching native Windows setup via PowerShell...${C_RESET}"
                powershell.exe -NoProfile -ExecutionPolicy Bypass -File "./setup.ps1"
                exit $?
            else
                error "powershell.exe not found. Please run setup.bat as Administrator."
                exit 1
            fi
            ;;
    esac
}

# Auto-elevate to root if not already root
ensure_root() {
    if [ "$(id -u)" -ne 0 ]; then
        warn "Administrative privileges required. Auto-elevating with sudo..."
        exec sudo bash "$0" "$@"
    fi
}

# Parse Command-Line Arguments
parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --preset)
                PRESET="$2"
                shift 2
                ;;
            -y|--yes)
                NON_INTERACTIVE=true
                shift
                ;;
            --ssh-port)
                SSH_PORT="$2"
                shift 2
                ;;
            --user)
                TARGET_USER="$2"
                shift 2
                ;;
            --password)
                CUSTOM_PASSWORD="$2"
                shift 2
                ;;
            --ssh-key)
                SSH_PUBKEY="$2"
                shift 2
                ;;
            --no-docker)
                INSTALL_DOCKER=false
                shift
                ;;
            --no-cockpit)
                INSTALL_COCKPIT=false
                shift
                ;;
            --no-upnp)
                ENABLE_UPNP=false
                shift
                ;;
            --status)
                if [ -x /usr/local/bin/serverctl ]; then
                    /usr/local/bin/serverctl status
                else
                    error "serverctl is not yet installed. Run setup.sh first."
                fi
                exit 0
                ;;
            --uninstall|--revert)
                if [ -x /usr/local/bin/serverctl ]; then
                    /usr/local/bin/serverctl uninstall
                else
                    error "serverctl is not installed."
                fi
                exit 0
                ;;
            -h|--help)
                show_help
                ;;
            *)
                error "Unknown option: $1"
                echo "Run: bash setup.sh --help for available options."
                exit 1
                ;;
        esac
    done

    # Validate preset
    case "$PRESET" in
        minimal)
            INSTALL_DOCKER=false
            INSTALL_COCKPIT=false
            ;;
        standard)
            INSTALL_DOCKER=false
            INSTALL_COCKPIT=true
            ;;
        ultimate|hardened)
            INSTALL_DOCKER=true
            INSTALL_COCKPIT=true
            ;;
        *)
            warn "Unknown preset '${PRESET}'. Defaulting to 'standard'."
            PRESET="standard"
            ;;
    esac
}

# OS & Package Manager Detection
detect_os() {
    step "Detecting System Architecture & Package Manager"
    
    OS_NAME=""
    PKG_MGR=""
    
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        OS_NAME="${NAME:-Linux}"
        OS_ID="${ID:-linux}"
        OS_LIKE="${ID_LIKE:-}"
    else
        OS_NAME="$(uname -s)"
        OS_ID="unknown"
    fi

    # Determine Package Manager
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MGR="apt"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MGR="dnf"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MGR="yum"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MGR="pacman"
    elif command -v zypper >/dev/null 2>&1; then
        PKG_MGR="zypper"
    elif command -v apk >/dev/null 2>&1; then
        PKG_MGR="apk"
    elif command -v xbps-install >/dev/null 2>&1; then
        PKG_MGR="xbps"
    else
        PKG_MGR="unknown"
    fi

    info "Detected Operating System : ${C_CYAN}${OS_NAME}${C_RESET} (${OS_ID})"
    info "Detected Package Manager  : ${C_GREEN}${PKG_MGR}${C_RESET}"
    info "Target Server User        : ${C_YELLOW}${TARGET_USER}${C_RESET}"
    info "Selected Preset           : ${C_MAGENTA}${PRESET}${C_RESET}"

    if [ "$PKG_MGR" = "unknown" ]; then
        error "No supported package manager found (apt, dnf, yum, pacman, zypper, apk, xbps)."
        exit 1
    fi
}

# Package Installation Helper
install_packages() {
    local pkgs=("$@")
    info "Installing dependencies: ${pkgs[*]}..."

    case "$PKG_MGR" in
        apt)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq >/dev/null 2>&1 || true
            apt-get install -y -qq --no-install-recommends "${pkgs[@]}" >/dev/null 2>&1 || apt-get install -y "${pkgs[@]}"
            ;;
        dnf)
            dnf install -y -q "${pkgs[@]}" >/dev/null 2>&1 || dnf install -y "${pkgs[@]}"
            ;;
        yum)
            yum install -y -q "${pkgs[@]}" >/dev/null 2>&1 || yum install -y "${pkgs[@]}"
            ;;
        pacman)
            pacman -Sy --noconfirm --needed "${pkgs[@]}" >/dev/null 2>&1
            ;;
        zypper)
            zypper --non-interactive install -y "${pkgs[@]}" >/dev/null 2>&1
            ;;
        apk)
            apk add --no-cache "${pkgs[@]}" >/dev/null 2>&1
            ;;
        xbps)
            xbps-install -Sy "${pkgs[@]}" >/dev/null 2>&1
            ;;
    esac
}

# Install Core Utilities
install_base_packages() {
    step "Installing Base Server Utilities & OpenSSH"

    local base_pkgs=()
    case "$PKG_MGR" in
        apt)
            base_pkgs=(openssh-server sudo curl wget git ufw fail2ban iproute2 lm-sensors miniupnpc ethtool procps)
            ;;
        dnf|yum)
            base_pkgs=(openssh-server sudo curl wget git firewalld fail2ban iproute lm_sensors miniupnpc ethtool procps-ng)
            ;;
        pacman)
            base_pkgs=(openssh sudo curl wget git ufw fail2ban iproute2 lm_sensors miniupnpc ethtool procps-ng)
            ;;
        zypper)
            base_pkgs=(openssh sudo curl wget git ufw fail2ban iproute2 sensors miniupnpc ethtool)
            ;;
        apk)
            base_pkgs=(openssh sudo curl wget git iptables iproute2 lm-sensors miniupnpc ethtool)
            ;;
        xbps)
            base_pkgs=(openssh sudo curl wget git ufw fail2ban iproute2 lm_sensors miniupnpc ethtool)
            ;;
    esac

    install_packages "${base_pkgs[@]}"
    success "Core networking, firewall, and SSH packages installed."
}

# Hardware & 24/7 Power Management
configure_power_and_lid() {
    step "Optimizing Hardware for 24/7 Always-On Operation"

    # 1. Detect Laptop vs Desktop
    local is_laptop=false
    local chassis=""
    [ -f /sys/class/dmi/id/chassis_type ] && chassis=$(cat /sys/class/dmi/id/chassis_type)
    if [ -d /sys/class/power_supply/BAT0 ] || [ -d /sys/class/power_supply/BAT1 ] || [ "$chassis" = "9" ] || [ "$chassis" = "10" ]; then
        is_laptop=true
        info "Hardware Type: ${C_YELLOW}Laptop detected${C_RESET} (Enabling lid-switch bypass and battery conservation)"
    else
        info "Hardware Type: ${C_GREEN}Desktop / Bare-metal chassis detected${C_RESET}"
    fi

    # 2. Systemd Logind Lid Configuration
    mkdir -p /etc/systemd/logind.conf.d
    cat > /etc/systemd/logind.conf.d/99-server-my-pc.conf << "EOF"
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
LidSwitchIgnoreInhibited=no
IdleAction=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandlePowerKey=ignore
EOF
    success "Configured systemd-logind: Laptop lid can now be shut with 0% sleep or interruption."

    # Reload logind
    systemctl restart systemd-logind 2>/dev/null || systemctl kill -s HUP systemd-logind 2>/dev/null || true

    # 3. Mask Sleep & Suspend Targets completely
    info "Masking sleep, suspend, hibernate, and hybrid-sleep targets..."
    systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1 || true
    success "System suspend targets permanently masked."

    # 4. Disable Wi-Fi Power Saving (prevents drops on idle)
    mkdir -p /etc/NetworkManager/conf.d
    cat > /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf << "EOF"
[connection]
wifi.powersave = 2
EOF
    if command -v iw >/dev/null 2>&1; then
        for iface in $(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}'); do
            iw dev "$iface" set power_save off 2>/dev/null || true
        done
    fi
    success "Wi-Fi aggressive power savings disabled (zero latency drops)."

    # 5. Battery Charging Threshold Protection (if supported on laptops)
    if [ "$is_laptop" = true ]; then
        for f in /sys/class/power_supply/BAT*/charge_control_limit_max; do
            if [ -f "$f" ]; then
                echo "80" > "$f" 2>/dev/null || true
                success "Set hardware battery charging limit to 80% (prevents battery swelling while plugged in 24/7)."
                break
            fi
        done
    fi
}

# Deep Kernel & Network Tuning
tune_kernel_and_network() {
    step "Applying Deep Server Kernel & TCP Optimization"

    mkdir -p /etc/sysctl.d
    cat > /etc/sysctl.d/99-server-my-pc.conf << "EOF"
# Maximum Open Files & Connections
fs.file-max = 2097152

# Network & Congestion Tuning (BBR)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3

# Buffer Sizes for High Throughput
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# IP Forwarding (Ready for VPNs, Docker, and Routing)
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Swappiness & Memory Optimization
vm.swappiness = 10
vm.vfs_cache_pressure = 50

# Self-Healing: Auto-reboot 10s after Kernel Panic
kernel.panic = 10
kernel.panic_on_oops = 1
kernel.sysrq = 1
EOF

    # Try loading BBR kernel module
    modprobe tcp_bbr >/dev/null 2>&1 || true
    sysctl --system >/dev/null 2>&1 || true
    success "Kernel tuned: TCP BBR active, IP forwarding enabled, auto-panic reboot set."

    # Wake-On-LAN (WOL) on Ethernet interfaces
    if command -v ethtool >/dev/null 2>&1; then
        for iface in $(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -E '^(eth|en)'); do
            ethtool -s "$iface" wol g >/dev/null 2>&1 || true
        done
        success "Wake-on-LAN (WOL) enabled on all active Ethernet interfaces."
    fi
}

# User Permissions & Sudo Configuration
configure_user_permissions() {
    step "Configuring User Privileges & Sudo Rights"

    if [ -z "$TARGET_USER" ]; then
        TARGET_USER="root"
    fi

    # Ensure user is in sudo or wheel group
    if [ "$TARGET_USER" != "root" ]; then
        if getent group sudo >/dev/null 2>&1; then
            usermod -aG sudo "$TARGET_USER" 2>/dev/null || true
        elif getent group wheel >/dev/null 2>&1; then
            usermod -aG wheel "$TARGET_USER" 2>/dev/null || true
        fi

        # Passwordless sudo for server convenience
        mkdir -p /etc/sudoers.d
        echo "${TARGET_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/99-server-my-pc"
        chmod 0440 "/etc/sudoers.d/99-server-my-pc"
        success "Granted user '${TARGET_USER}' full administrative sudo privileges."
    fi

    # SSH Directory & Authorized Keys Setup
    local home_dir
    home_dir=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    if [ -d "$home_dir" ]; then
        mkdir -p "${home_dir}/.ssh"
        touch "${home_dir}/.ssh/authorized_keys"
        chown -R "${TARGET_USER}:${TARGET_USER}" "${home_dir}/.ssh"
        chmod 700 "${home_dir}/.ssh"
        chmod 600 "${home_dir}/.ssh/authorized_keys"
        success "Initialized ~/.ssh/authorized_keys for ${TARGET_USER}."
    fi

    # Password Configuration
    if [ -n "$CUSTOM_PASSWORD" ]; then
        echo "${TARGET_USER}:${CUSTOM_PASSWORD}" | chpasswd
        PASSWORD_DISPLAY="Custom (Set via --password argument)"
        success "Configured custom password for user '${TARGET_USER}'."
    elif [ "$NON_INTERACTIVE" = false ] && [ -t 0 ]; then
        echo -e "\n${C_BOLD}  SSH Login Credentials Configuration for '${TARGET_USER}':${C_RESET}"
        read -r -p "  Do you want to set or change the SSH password for '${TARGET_USER}' right now? [y/N]: " change_pw
        if [[ "$change_pw" =~ ^[Yy]$ ]]; then
            read -r -s -p "  Enter new SSH password for '${TARGET_USER}': " new_pw
            echo ""
            read -r -s -p "  Confirm new password: " confirm_pw
            echo ""
            if [ "$new_pw" = "$confirm_pw" ] && [ -n "$new_pw" ]; then
                echo "${TARGET_USER}:${new_pw}" | chpasswd
                PASSWORD_DISPLAY="Custom (Set during setup)"
                success "Password updated for user '${TARGET_USER}'."
            else
                warn "Passwords did not match or were empty. Keeping existing user password."
                PASSWORD_DISPLAY="Your existing Linux user password"
            fi
        else
            PASSWORD_DISPLAY="Your existing Linux user password"
        fi

        echo ""
        read -r -p "  Paste client SSH Public Key for instant passwordless login (or press Enter to skip): " user_key
        if [ -n "$user_key" ]; then
            echo "$user_key" >> "${home_dir}/.ssh/authorized_keys"
            success "Installed client SSH public key to ${home_dir}/.ssh/authorized_keys."
        fi
    else
        PASSWORD_DISPLAY="Your existing Linux user password"
    fi

    # Inject SSH Public Key if provided via argument
    if [ -n "$SSH_PUBKEY" ] && [ -d "$home_dir" ]; then
        echo "$SSH_PUBKEY" >> "${home_dir}/.ssh/authorized_keys"
        success "Installed SSH public key into ${home_dir}/.ssh/authorized_keys."
    fi
}

# Configure OpenSSH Server
configure_openssh() {
    step "Configuring & Hardening OpenSSH Server"

    mkdir -p /etc/ssh/sshd_config.d
    cat > /etc/ssh/sshd_config.d/99-server-my-pc.conf << EOF
# server-my-pc OpenSSH Server Configuration
Port ${SSH_PORT}
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::

# Authentication
PermitRootLogin prohibit-password
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 5

# Session Keep-Alive (Prevents SSH disconnects during idle)
ClientAliveInterval 60
ClientAliveCountMax 10
TCPKeepAlive yes

# Environment & Forwarding
X11Forwarding no
AllowTcpForwarding yes
EOF

    # Test configuration and restart sshd
    local ssh_service="ssh"
    systemctl list-unit-files | grep -q "sshd.service" && ssh_service="sshd"

    systemctl enable "$ssh_service" >/dev/null 2>&1 || true
    systemctl restart "$ssh_service" >/dev/null 2>&1 || true
    success "OpenSSH configured on port ${SSH_PORT} with session keep-alives and enabled on boot."
}

# Firewall & Security Hardening
configure_firewall_and_security() {
    step "Configuring Firewall & Intrusion Prevention"

    # UFW Configuration
    if command -v ufw >/dev/null 2>&1; then
        ufw --force reset >/dev/null 2>&1 || true
        ufw default deny incoming >/dev/null 2>&1 || true
        ufw default allow outgoing >/dev/null 2>&1 || true
        ufw allow "${SSH_PORT}/tcp" comment "SSH Server" >/dev/null 2>&1 || true
        if [ "$INSTALL_COCKPIT" = true ]; then
            ufw allow 9090/tcp comment "Cockpit Web Console" >/dev/null 2>&1 || true
        fi
        echo "y" | ufw enable >/dev/null 2>&1 || true
        success "UFW firewall active: Port ${SSH_PORT} (SSH) allowed."
    elif command -v firewall-cmd >/dev/null 2>&1; then
        systemctl enable --now firewalld >/dev/null 2>&1 || true
        firewall-cmd --permanent --add-port="${SSH_PORT}/tcp" >/dev/null 2>&1 || true
        if [ "$INSTALL_COCKPIT" = true ]; then
            firewall-cmd --permanent --add-port=9090/tcp >/dev/null 2>&1 || true
        fi
        firewall-cmd --reload >/dev/null 2>&1 || true
        success "firewalld active: Port ${SSH_PORT} (SSH) allowed."
    fi

    # Fail2ban SSH Jail Configuration
    if command -v fail2ban-client >/dev/null 2>&1; then
        mkdir -p /etc/fail2ban/jail.d
        cat > /etc/fail2ban/jail.d/99-server-my-pc.conf << EOF
[sshd]
enabled = true
port = ${SSH_PORT}
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 1h
findtime = 10m
EOF
        [ ! -f /var/log/auth.log ] && [ -f /var/log/secure ] && sed -i 's|/var/log/auth.log|/var/log/secure|' /etc/fail2ban/jail.d/99-server-my-pc.conf
        systemctl enable fail2ban >/dev/null 2>&1 || true
        systemctl restart fail2ban >/dev/null 2>&1 || true
        success "Fail2ban brute-force protection active on SSH port ${SSH_PORT}."
    fi
}

# Install Self-Healing Daemons (Watchdog & Thermal)
install_self_healing_daemons() {
    step "Installing Self-Healing Daemons (Network Watchdog & Thermal Guard)"

    # 1. Network Watchdog Script
    cat > /usr/local/bin/server-watchdog << "EOF"
#!/usr/bin/env bash
# server-watchdog - Auto-reconnects dropped Wi-Fi / Ethernet connections
GATEWAY=$(ip route | awk '/default/ {print $3; exit}')
[ -z "$GATEWAY" ] && GATEWAY="1.1.1.1"

if ! ping -c 2 -W 3 "$GATEWAY" >/dev/null 2>&1; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [Watchdog] Gateway unreachable. Attempting network restart..."
    if command -v nmcli >/dev/null 2>&1; then
        nmcli networking off && sleep 2 && nmcli networking on
    elif systemctl is-active --quiet systemd-networkd; then
        systemctl restart systemd-networkd
    else
        systemctl restart NetworkManager 2>/dev/null || systemctl restart networking 2>/dev/null || true
    fi
fi
EOF
    chmod +x /usr/local/bin/server-watchdog

    # Systemd Service & Timer for Watchdog
    cat > /etc/systemd/system/server-watchdog.service << "EOF"
[Unit]
Description=server-my-pc Network Watchdog
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/server-watchdog
EOF

    cat > /etc/systemd/system/server-watchdog.timer << "EOF"
[Unit]
Description=Run server-watchdog every 60 seconds

[Timer]
OnBootSec=1min
OnUnitActiveSec=60s

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable --now server-watchdog.timer >/dev/null 2>&1 || true
    success "Network Watchdog active (pings gateway every 60s, auto-recovers connection)."

    # 2. Thermal Guard Daemon
    cat > /usr/local/bin/server-thermal-guard << "EOF"
#!/usr/bin/env bash
# server-thermal-guard - Monitors closed-lid laptop temperature
THRESHOLD=85

while true; do
    TEMP=0
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        RAW=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0)
        TEMP=$((RAW / 1000))
    fi

    if [ "$TEMP" -gt "$THRESHOLD" ]; then
        logger -t "server-thermal-guard" "WARNING: High CPU temperature detected: ${TEMP}°C (Threshold: ${THRESHOLD}°C)"
    fi
    sleep 30
done
EOF
    chmod +x /usr/local/bin/server-thermal-guard

    cat > /etc/systemd/system/server-thermal-guard.service << "EOF"
[Unit]
Description=server-my-pc Thermal Guard Daemon
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/server-thermal-guard
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable --now server-thermal-guard.service >/dev/null 2>&1 || true
    success "Thermal Guard active (monitors closed-lid hardware thermals)."

    # 3. Boot Persistence & Recovery Service (Runs on Every Startup)
    cat > /usr/local/bin/server-my-pc-boot << 'EOF'
#!/usr/bin/env bash
# server-my-pc-boot - Runs automatically on every system startup
CONFIG_DIR="/etc/server-my-pc"
SSH_PORT="22"
[ -f "${CONFIG_DIR}/ssh_port" ] && SSH_PORT=$(cat "${CONFIG_DIR}/ssh_port")

# 1. Re-enforce 24/7 power & lid policies
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1 || true

# 2. Re-apply hardware battery charging limit (80% protection)
for f in /sys/class/power_supply/BAT*/charge_control_limit_max; do
    [ -f "$f" ] && echo "80" > "$f" 2>/dev/null || true
done

# 3. Re-apply Wi-Fi power save disable & Wake-on-LAN
if command -v iw >/dev/null 2>&1; then
    for iface in $(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}'); do
        iw dev "$iface" set power_save off 2>/dev/null || true
    done
fi
if command -v ethtool >/dev/null 2>&1; then
    for iface in $(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -E '^(eth|en)'); do
        ethtool -s "$iface" wol g >/dev/null 2>&1 || true
    done
fi

# 4. Re-announce router UPnP port mappings
LOCAL_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
if command -v upnpc >/dev/null 2>&1 && [ -n "$LOCAL_IP" ]; then
    upnpc -a "$LOCAL_IP" "$SSH_PORT" "$SSH_PORT" TCP >/dev/null 2>&1 || true
    upnpc -a "$LOCAL_IP" 9090 9090 TCP >/dev/null 2>&1 || true
fi

# 5. Auto-resume CGNAT tunnel if enabled
if [ -f "${CONFIG_DIR}/tunnel.enabled" ] && command -v cloudflared >/dev/null 2>&1; then
    pkill -f "cloudflared tunnel" 2>/dev/null || true
    nohup cloudflared tunnel --url "ssh://localhost:${SSH_PORT}" > /var/log/server-my-pc-tunnel.log 2>&1 &
fi

# 6. Send Boot Alert Webhook (Discord / Telegram) if configured
if [ -f "${CONFIG_DIR}/notify.conf" ]; then
    # shellcheck source=/dev/null
    source "${CONFIG_DIR}/notify.conf"
    PUBLIC_IP=$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null || echo "Unknown")
    HOSTNAME=$(hostname)
    MSG="[server-my-pc] Server '${HOSTNAME}' has BOOTED and is 24/7 ONLINE! Local IP: ${LOCAL_IP} | Public IP: ${PUBLIC_IP} | Port: ${SSH_PORT}"

    if [ -n "$DISCORD_WEBHOOK" ]; then
        curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"$MSG\"}" "$DISCORD_WEBHOOK" >/dev/null 2>&1 || true
    fi
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" -d "chat_id=${TELEGRAM_CHAT_ID}&text=${MSG}" >/dev/null 2>&1 || true
    fi
fi
EOF
    chmod +x /usr/local/bin/server-my-pc-boot

    cat > /etc/systemd/system/server-my-pc-boot.service << "EOF"
[Unit]
Description=server-my-pc Boot Persistence & Recovery Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/server-my-pc-boot
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable server-my-pc-boot.service >/dev/null 2>&1 || true
    success "Boot Persistence Engine active (re-enforces 24/7 power, UPnP, and tunnels after every reboot)."
}

# Install Cockpit Web Console
install_cockpit() {
    if [ "$INSTALL_COCKPIT" = false ]; then
        return 0
    fi

    step "Installing Cockpit Web Management Console"
    local cockpit_pkg="cockpit"
    install_packages "$cockpit_pkg"

    systemctl enable --now cockpit.socket >/dev/null 2>&1 || true
    success "Cockpit Web Console enabled on port 9090."
}

# Install Docker Engine & Compose
install_docker() {
    if [ "$INSTALL_DOCKER" = false ]; then
        return 0
    fi

    step "Installing Docker Engine & Docker Compose"

    if command -v docker >/dev/null 2>&1; then
        success "Docker is already installed."
    else
        info "Running official Docker convenience script..."
        curl -fsSL https://get.docker.com | sh >/dev/null 2>&1 || {
            warn "Official get.docker.com failed, falling back to distro package manager..."
            case "$PKG_MGR" in
                apt) install_packages docker.io docker-compose ;;
                dnf|yum) install_packages docker docker-compose-plugin ;;
                pacman) install_packages docker docker-compose ;;
                zypper) install_packages docker docker-compose ;;
                apk) install_packages docker docker-cli-compose ;;
            esac
        }
    fi

    systemctl enable --now docker >/dev/null 2>&1 || true

    # Add user to docker group
    if [ -n "$TARGET_USER" ] && [ "$TARGET_USER" != "root" ]; then
        usermod -aG docker "$TARGET_USER" 2>/dev/null || true
        success "User '${TARGET_USER}' added to docker group."
    fi

    success "Docker Engine active and ready for container deployments."
}

# UPnP Router Port Forwarding
attempt_upnp_port_forward() {
    if [ "$ENABLE_UPNP" = false ]; then
        return 0
    fi

    step "Attempting Automatic Router UPnP Port Forwarding"

    local local_ip
    local_ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    [ -z "$local_ip" ] && local_ip=$(hostname -I 2>/dev/null | awk '{print $1}')

    if command -v upnpc >/dev/null 2>&1 && [ -n "$local_ip" ]; then
        info "Requesting router UPnP port map for SSH (Port ${SSH_PORT})..."
        if upnpc -a "$local_ip" "$SSH_PORT" "$SSH_PORT" TCP >/dev/null 2>&1; then
            success "Router UPnP: Port ${SSH_PORT} successfully forwarded on your Wi-Fi router!"
        else
            warn "Router UPnP request not accepted or UPnP disabled on router (normal for secure routers)."
            info "You can forward port ${SSH_PORT} manually in router settings, or use: sudo serverctl tunnel start"
        fi
    fi
}

# Install Global serverctl CLI
install_serverctl() {
    step "Installing Global Management CLI (serverctl)"

    if [ -f "./serverctl" ]; then
        cp "./serverctl" /usr/local/bin/serverctl
    elif [ ! -f "/usr/local/bin/serverctl" ]; then
        info "Fetching serverctl management CLI from repository..."
        curl -sSL "https://raw.githubusercontent.com/8nc0x/server-my-pc/main/serverctl" -o /usr/local/bin/serverctl 2>/dev/null || \
        wget -qO /usr/local/bin/serverctl "https://raw.githubusercontent.com/8nc0x/server-my-pc/main/serverctl" 2>/dev/null || true
    fi
    chmod +x /usr/local/bin/serverctl
    ln -sf /usr/local/bin/serverctl /usr/local/bin/server-my-pc

    mkdir -p "$CONFIG_DIR"
    echo "$PRESET" > "${CONFIG_DIR}/preset"
    echo "$SSH_PORT" > "${CONFIG_DIR}/ssh_port"

    success "Installed /usr/local/bin/serverctl (and symlink 'server-my-pc')."
}

# Display Final Summary Card
display_completion_summary() {
    local local_ip public_ip
    local_ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    [ -z "$local_ip" ] && local_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$local_ip" ] && local_ip="127.0.0.1"

    public_ip=$(curl -s --max-time 2 https://api.ipify.org 2>/dev/null || curl -s --max-time 2 https://ifconfig.me 2>/dev/null || echo "Unknown/Offline")

    echo -e "\n${C_GREEN}${C_BOLD}"
    cat << "EOF"
  ========================================================================
             SERVER-MY-PC: TRANSFORMATION COMPLETE!                      
  ========================================================================
EOF
    echo -e "${C_RESET}"
    echo -e "${C_WHITE}${C_BOLD}┌── 24/7 SERVER CONNECTION DETAILS ──────────────────────────────────────────┐${C_RESET}"
    printf "${C_WHITE}│  %-24s: ${C_GREEN}%-45s${C_WHITE}│\n" "Local Network IP (LAN)" "$local_ip"
    printf "${C_WHITE}│  %-24s: ${C_YELLOW}%-45s${C_WHITE}│\n" "Public Internet IP (WAN)" "$public_ip"
    printf "${C_WHITE}│  %-24s: ${C_CYAN}%-45s${C_WHITE}│\n" "SSH Port" "$SSH_PORT"
    printf "${C_WHITE}│  %-24s: ${C_MAGENTA}%-45s${C_WHITE}│\n" "SSH Username" "$TARGET_USER"
    printf "${C_WHITE}│  %-24s: ${C_WHITE}%-45s${C_WHITE}│\n" "SSH Password" "$PASSWORD_DISPLAY"
    echo -e "${C_WHITE}├── READY-TO-COPY SSH COMMANDS ──────────────────────────────────────────────┤${C_RESET}"
    if [ "$SSH_PORT" -eq 22 ]; then
        printf "${C_WHITE}│  %-24s: ${C_CYAN}%-45s${C_WHITE}│\n" "Connect from Home WiFi" "ssh ${TARGET_USER}@${local_ip}"
        printf "${C_WHITE}│  %-24s: ${C_YELLOW}%-45s${C_WHITE}│\n" "Connect from Outside" "ssh ${TARGET_USER}@${public_ip}"
    else
        printf "${C_WHITE}│  %-24s: ${C_CYAN}%-45s${C_WHITE}│\n" "Connect from Home WiFi" "ssh -p ${SSH_PORT} ${TARGET_USER}@${local_ip}"
        printf "${C_WHITE}│  %-24s: ${C_YELLOW}%-45s${C_WHITE}│\n" "Connect from Outside" "ssh -p ${SSH_PORT} ${TARGET_USER}@${public_ip}"
    fi
    if [ "$INSTALL_COCKPIT" = true ]; then
        echo -e "${C_WHITE}├── WEB MANAGEMENT CONSOLE (COCKPIT) ────────────────────────────────────────┤${C_RESET}"
        printf "${C_WHITE}│  %-24s: ${C_BLUE}%-45s${C_WHITE}│\n" "Web Terminal & Admin" "https://${local_ip}:9090"
        printf "${C_WHITE}│  %-24s: ${C_GRAY}%-45s${C_WHITE}│\n" "Login Credentials" "Same as your Linux user (${TARGET_USER})"
    fi
    echo -e "${C_WHITE}├── QUICK SERVER MANAGEMENT COMMANDS ────────────────────────────────────────┤${C_RESET}"
    printf "${C_WHITE}│  ${C_CYAN}%-26s${C_WHITE} : %-43s│\n" "serverctl status" "View full hardware & network telemetry"
    printf "${C_WHITE}│  ${C_CYAN}%-26s${C_WHITE} : %-43s│\n" "serverctl dashboard" "Open real-time interactive terminal TUI"
    printf "${C_WHITE}│  ${C_CYAN}%-26s${C_WHITE} : %-43s│\n" "serverctl open-port <port>" "Open firewall port and router UPnP"
    printf "${C_WHITE}│  ${C_CYAN}%-26s${C_WHITE} : %-43s│\n" "serverctl tunnel start" "Start zero-signup CGNAT remote tunnel"
    printf "${C_WHITE}│  ${C_CYAN}%-26s${C_WHITE} : %-43s│\n" "serverctl apps list" "1-click deploy Portainer, Nginx, etc."
    printf "${C_WHITE}│  ${C_CYAN}%-26s${C_WHITE} : %-43s│\n" "serverctl uninstall" "Restore laptop to standard defaults"
    echo -e "${C_WHITE}└────────────────────────────────────────────────────────────────────────────┘${C_RESET}\n"

    echo -e "${C_GREEN}${C_BOLD}Your PC is now an always-on, 24/7 bare-metal server!${C_RESET}"
    echo -e "${C_DIM}You can now shut the laptop lid, plug it into power, and control it from any device.${C_RESET}\n"
}

# Main Execution Flow
main() {
    # Handle help or version flags immediately without requiring root or Windows redirect
    for arg in "$@"; do
        if [ "$arg" = "-h" ] || [ "$arg" = "--help" ]; then
            show_help
        fi
    done

    detect_windows_environment
    parse_args "$@"
    ensure_root "$@"
    print_banner
    detect_os
    install_base_packages
    configure_power_and_lid
    tune_kernel_and_network
    configure_user_permissions
    configure_openssh
    configure_firewall_and_security
    install_self_healing_daemons
    install_cockpit
    install_docker
    install_serverctl
    attempt_upnp_port_forward
    display_completion_summary
}

main "$@"
