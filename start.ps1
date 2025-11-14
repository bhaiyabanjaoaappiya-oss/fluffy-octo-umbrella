# ============================
# start.ps1
# Windows + Tailscale + RDP + (optional) wallpaper
# ============================

param(
    [string]$Username      = $env:RDP_USER,
    [string]$Password      = $env:RDP_PASS,
    [string]$TailscaleAuth = $env:TAILSCALE_AUTHKEY,
    [string]$WallpaperUrl  = $env:WALLPAPER_URL
)

Write-Host "=== Windows Tailscale RDP setup starting ==="

# ----- defaults (strong password to avoid InvalidPasswordException) -----
if (-not $Username -or $Username.Trim() -eq "") { $Username = "Sapna" }
if (-not $Password -or $Password.Trim() -eq "") { $Password = "Sapna@12345Love!" }

if (-not $TailscaleAuth) {
    Write-Error "ERROR: TAILSCALE_AUTHKEY is missing."
    exit 1
}

Write-Host "[*] Using local user: $Username"
Write-Host "[*] Installing / starting Tailscale..."

# ----- Install Tailscale if missing -----
$tsExe = "C:\Program Files\Tailscale\tailscale.exe"

if (-not (Test-Path $tsExe)) {
    $url = "https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe"
    $dst = "$env:TEMP\tailscale-setup.exe"

    Write-Host "[*] Downloading Tailscale from $url"
    Invoke-WebRequest -Uri $url -OutFile $dst -UseBasicParsing
    Start-Process -FilePath $dst -ArgumentList "/quiet" -Wait
} else {
    Write-Host "[*] Tailscale already installed."
}

# Make sure service running
Start-Service Tailscale -ErrorAction SilentlyContinue

if (-not (Test-Path $tsExe)) {
    Write-Error "tailscale.exe not found after install."
    exit 1
}

# ----- Tailscale up -----
$hostName = "win-rdp-$($env:GITHUB_RUN_ID)"
Write-Host "[*] Running: tailscale up (hostname: $hostName)"

& $tsExe up `
  --authkey "$TailscaleAuth" `
  --hostname "$hostName" `
  --accept-routes `
  --accept-dns=false

if ($LASTEXITCODE -ne 0) {
    Write-Error "❌ tailscale up failed."
    & $tsExe status || $true
    exit 1
}

$tsIp = (& $tsExe ip -4 | Select-Object -First 1)
if ($tsIp) {
    Write-Host "[*] Tailscale IPv4: $tsIp"
} else {
    Write-Warning "tailscale ip -4 returned empty."
}

# Export IP for GitHub Actions env
if ($env:GITHUB_ENV) {
    "CONNECTION_IP=$tsIp" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
    "CONNECTION_TYPE=Windows-RDP-Tailscale" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
}

# ----- Create local user for RDP -----
Write-Host "[*] Creating local user (if missing)..."

$secure = ConvertTo-SecureString $Password -AsPlainText -Force

if (-not (Get-LocalUser -Name $Username -ErrorAction SilentlyContinue)) {
    New-LocalUser -Name $Username -Password $secure -FullName $Username -PasswordNeverExpires -AccountNeverExpires | Out-Null
    Write-Host "[*] User $Username created."
} else {
    Write-Host "[*] User $Username already exists."
}

# Add to Administrators
Add-LocalGroupMember -Group "Administrators" -Member $Username -ErrorAction SilentlyContinue

# ----- Enable RDP + firewall -----
Write-Host "[*] Enabling Remote Desktop (RDP)..."

# Allow RDP connections
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
    -Name "fDenyTSConnections" -Value 0

# Enable NLA (optional but recommended)
New-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" `
    -Name "UserAuthentication" -PropertyType DWord -Value 1 -Force | Out-Null

# Open firewall group
Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue

# ----- Optional Wallpaper -----
if ($WallpaperUrl -and $WallpaperUrl.Trim() -ne "") {
    try {
        Write-Host "[*] Downloading wallpaper from: $WallpaperUrl"
        $wallPath = "C:\Users\Public\Pictures\wallpaper.jpg"
        Invoke-WebRequest -Uri $WallpaperUrl -OutFile $wallPath -UseBasicParsing

        Write-Host "[*] Applying wallpaper..."
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value $wallPath
        RUNDLL32.EXE USER32.DLL,UpdatePerUserSystemParameters
    } catch {
        Write-Warning "Failed to set wallpaper: $_"
    }
}

Write-Host ""
Write-Host "========================================"
Write-Host " Windows RDP over Tailscale READY ✅"
Write-Host "----------------------------------------"
Write-Host "  Tailscale IP : $tsIp"
Write-Host "  RDP User     : $Username"
Write-Host "  RDP Pass     : $Password"
Write-Host "  Protocol     : RDP (port 3389)"
Write-Host "========================================"
Write-Host ""
