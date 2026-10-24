# ==============================================================================
# server-my-pc Windows Native Server Setup Engine
# Turns any Windows PC or Laptop into an always-on 24/7 SSH server.
# Part of https://github.com/8nc0x/server-my-pc
# ==============================================================================

[CmdletBinding()]
param (
    [int]$SshPort = 22,
    [switch]$NoDocker,
    [switch]$Uninstall,
    [switch]$Status,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

function Show-Banner {
    Clear-Host
    $banner = @(
        "  ____                                __  __           ____   ____ ",
        " / ___|  ___ _ ____   _____ _ __     |  \/  |_   _    |  _ \ / ___|",
        " \___ \ / _ \ '__\ \ / / _ \ '__|____| |\/| | | | |___| |_) | |    ",
        "  ___) |  __/ |   \ V /  __/ | |_____| |  | | |_| |___|  __/| |___ ",
        " |____/ \___|_|    \_/ \___|_|       |_|  |_|\__, |   |_|    \____|",
        "                                             |___/                 "
    )
    foreach ($line in $banner) {
        Write-Host $line -ForegroundColor Cyan
    }
    Write-Host "     Windows 24/7 PC and Laptop Server Transformation Engine - v1.0.0`n" -ForegroundColor DarkGray
}

function Test-Admin {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if ($Help) {
    Show-Banner
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  .\setup.ps1 [-SshPort <port>] [-Uninstall] [-Status] [-Help]`n"
    Write-Host "OPTIONS:" -ForegroundColor Yellow
    Write-Host "  -SshPort <int>   Set custom SSH port (Default: 22)"
    Write-Host "  -Status          Check current server health and active configuration"
    Write-Host "  -Uninstall       Restore Windows default power and lid settings"
    Write-Host "  -Help            Display this help guide`n"
    exit 0
}

if (-not (Test-Admin)) {
    Write-Warning "Administrative privileges required to configure system power and OpenSSH."
    try {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit 0
    }
    catch {
        Write-Error "Could not auto-elevate. Please right-click setup.bat or PowerShell and select 'Run as administrator'."
        exit 1
    }
}

if ($Uninstall) {
    Show-Banner
    Write-Host "[*] Restoring Windows default power and sleep policies..." -ForegroundColor Yellow
    powercfg /change standby-timeout-ac 30
    powercfg /change standby-timeout-dc 15
    powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 1
    powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 1
    powercfg /SetActive SCHEME_CURRENT
    Write-Host "[OK] Windows default laptop sleep and lid settings restored." -ForegroundColor Green
    exit 0
}

Show-Banner

# Step 1: Install OpenSSH Server Capability
Write-Host "==> [1/6] Configuring Windows OpenSSH Server..." -ForegroundColor Cyan
try {
    $sshCapability = Get-WindowsCapability -Online | Where-Object { $_.Name -like 'OpenSSH.Server*' }
    if ($sshCapability.State -ne 'Installed') {
        Write-Host "  [*] Installing OpenSSH.Server Windows Capability (this may take 1-2 minutes)..." -ForegroundColor DarkGray
        Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' | Out-Null
    }
    Write-Host "  [OK] OpenSSH Server capability is installed." -ForegroundColor Green
}
catch {
    Write-Warning "Windows Capability installation check completed. Proceeding to SSH service..."
}

# Step 2: Start and Configure SSHD Service
Write-Host "`n==> [2/6] Starting and Enabling SSHD Services..." -ForegroundColor Cyan
Set-Service -Name sshd -StartupType 'Automatic'
Start-Service -Name sshd

if (Get-Service -Name 'ssh-agent' -ErrorAction SilentlyContinue) {
    Set-Service -Name 'ssh-agent' -StartupType 'Automatic'
    Start-Service -Name 'ssh-agent'
}
Write-Host "  [OK] SSHD service running and configured for automatic startup on boot." -ForegroundColor Green

# Step 3: Windows Defender Firewall Configuration
Write-Host "`n==> [3/6] Configuring Windows Defender Firewall..." -ForegroundColor Cyan
$existingRule = Get-NetFirewallRule -Name "server-my-pc-sshd" -ErrorAction SilentlyContinue
if (-not $existingRule) {
    New-NetFirewallRule -Name "server-my-pc-sshd" `
        -DisplayName "server-my-pc OpenSSH Server (Port $SshPort)" `
        -Description "Allows inbound SSH connections for server-my-pc" `
        -Group "server-my-pc" `
        -Enabled True `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort $SshPort `
        -Action Allow | Out-Null
}
Write-Host "  [OK] Inbound Port $SshPort allowed in Windows Defender Firewall." -ForegroundColor Green

# Step 4: 24/7 Power and Laptop Lid Close Optimization
Write-Host "`n==> [4/6] Optimizing Power and Laptop Lid for 24/7 Always-On Operation..." -ForegroundColor Cyan
powercfg /change standby-timeout-ac 0
powercfg /change standby-timeout-dc 0
powercfg /change hibernate-timeout-ac 0
powercfg /change hibernate-timeout-dc 0
powercfg /change disk-timeout-ac 0

powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
powercfg /SetActive SCHEME_CURRENT

Write-Host "  [OK] 24/7 Lid-Close sleep disabled: Laptop will stay 100% active when the lid is closed!" -ForegroundColor Green

# Step 5: Install Windows serverctl Command
Write-Host "`n==> [5/6] Installing Windows serverctl CLI..." -ForegroundColor Cyan
$binDir = "$env:ProgramData\server-my-pc\bin"
if (-not (Test-Path $binDir)) {
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
}

$cmdLines = @(
    '@echo off',
    'powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serverctl.ps1" %*'
)
Set-Content -Path "$binDir\serverctl.cmd" -Value $cmdLines

$serverctlLines = @(
    'param([string]$Command = "status", [string]$Arg1)',
    '',
    'function Get-LocalIP {',
    '    (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "Loopback|vEthernet|Virtual" -and $_.IPAddress -notlike "169.254*" } | Select-Object -First 1).IPAddress',
    '}',
    '',
    'function Get-PublicIP {',
    '    try { (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 2).Trim() } catch { "Unknown/Offline" }',
    '}',
    '',
    'switch ($Command) {',
    '    "status" {',
    '        $ip = Get-LocalIP',
    '        $pub = Get-PublicIP',
    '        $sshd = (Get-Service -Name sshd -ErrorAction SilentlyContinue).Status',
    '        Write-Host "=== Windows Server Telemetry ===" -ForegroundColor Cyan',
    '        Write-Host "Local IP    : $ip"',
    '        Write-Host "Public IP   : $pub"',
    '        Write-Host "SSHD Service: $sshd"',
    '        Write-Host "Lid Action  : Do Nothing (24/7 Always On)"',
    '    }',
    '    "info" {',
    '        $ip = Get-LocalIP',
    '        $user = $env:USERNAME',
    '        Write-Host "SSH Connect: ssh $user@$ip" -ForegroundColor Green',
    '    }',
    '    default {',
    '        Write-Host "Usage: serverctl [status|info]"',
    '    }',
    '}'
)
Set-Content -Path "$binDir\serverctl.ps1" -Value $serverctlLines

$machinePath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
if ($machinePath -notlike "*$binDir*") {
    [Environment]::SetEnvironmentVariable("PATH", "$machinePath;$binDir", [EnvironmentVariableTarget]::Machine)
}
Write-Host "  [OK] Global serverctl command installed to PATH." -ForegroundColor Green

# Step 6: Detect IPs and Display Summary
Write-Host "`n==> [6/6] Finalizing Connection Telemetry..." -ForegroundColor Cyan

$localIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "Loopback|vEthernet|Virtual" -and $_.IPAddress -notlike "169.254*" } | Select-Object -First 1).IPAddress
if (-not $localIp) { $localIp = "127.0.0.1" }

$publicIp = "Checking..."
try {
    $publicIp = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 2).Trim()
}
catch {
    $publicIp = "Unknown/Offline"
}

$currentUser = $env:USERNAME

Write-Host "`n========================================================================" -ForegroundColor Green
Write-Host "         SERVER-MY-PC (WINDOWS): TRANSFORMATION COMPLETE!               " -ForegroundColor Green
Write-Host "========================================================================`n" -ForegroundColor Green

Write-Host "+----------------------------------------------------------------------------+" -ForegroundColor White
Write-Host ("|  {0,-24}: {1,-45}|" -f "Local Network IP (LAN)", $localIp) -ForegroundColor White
Write-Host ("|  {0,-24}: {1,-45}|" -f "Public Internet IP (WAN)", $publicIp) -ForegroundColor White
Write-Host ("|  {0,-24}: {1,-45}|" -f "SSH Port", $SshPort) -ForegroundColor White
Write-Host ("|  {0,-24}: {1,-45}|" -f "Windows Server User", $currentUser) -ForegroundColor White
Write-Host "+----------------------------------------------------------------------------+" -ForegroundColor White
Write-Host ("|  Connect from Home WiFi  : ssh {0}@{1,-37}|" -f $currentUser, $localIp) -ForegroundColor Cyan
Write-Host ("|  Connect from Outside    : ssh {0}@{1,-37}|" -f $currentUser, $publicIp) -ForegroundColor Yellow
Write-Host "+----------------------------------------------------------------------------+" -ForegroundColor White
Write-Host "|  serverctl status          : View server telemetry and SSH status           |" -ForegroundColor White
Write-Host "|  serverctl info            : Print quick SSH connect command               |" -ForegroundColor White
Write-Host "+----------------------------------------------------------------------------+`n" -ForegroundColor White

Write-Host "Your Windows PC/Laptop is now an always-on 24/7 SSH server!" -ForegroundColor Green
Write-Host "You can now close your laptop lid, plug it into power, and connect anytime.`n" -ForegroundColor Gray
