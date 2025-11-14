param(
    [string]$Username      = $env:RDP_USER,
    [string]$Password      = $env:RDP_PASS,
    [string]$TailscaleAuth = $env:TAILSCALE_AUTHKEY,
    [string]$WallpaperUrl  = $env:WALLPAPER_URL
)

Write-Host "=== Windows Tailscale RDP setup starting ==="

if (-not $Username -or $Username.Trim() -eq "") { $Username = "Sapna" }
if (-not $Password -or $Password.Trim() -eq "") { $Password = "Sapna@12345Love!_987" }

if (-not $TailscaleAuth) {
    Write-Error "ERROR: TAILSCALE_AUTHKEY is missing."
    exit 1
}

Write-Host "[*] Using local user: $Username"

# ----- Tailscale install -----
$tsExe = "C:\Program Files\Tailscale\tailscale.exe"

if (-not (Test-Path $tsExe)) {
    $url = "https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe"
    $dst = "$env:TEMP\tailscale-setup.exe"
    Write-Host "[*] Downloading Tailscale..."
    Invoke-WebRequest -Uri $url -OutFile $dst -UseBasicParsing
    Start-Process -FilePath $dst -ArgumentList "/quiet" -Wait
} else {
    Write-Host "[*] Tailscale already installed."
}

Start-Service Tailscale -ErrorAction SilentlyContinue

if (-not (Test-Path $tsExe)) {
    Write-Error "tailscale.exe not found after install."
    exit 1
}

# ----- tailscale up -----
$hostName = "win-rdp-$($env:GITHUB_RUN_ID)"
Write-Host "[*] tailscale up (hostname: $hostName)"

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
Write-Host "[*] Tailscale IPv4: $tsIp"

if ($env:GITHUB_ENV) {
    "CONNECTION_IP=$tsIp" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
    "CONNECTION_TYPE=Windows-RDP-Tailscale" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
}

# ----- create local user -----
Write-Host "[*] Creating local user (if needed)..."

$secure = ConvertTo-SecureString $Password -AsPlainText -Force

if (-not (Get-LocalUser -Name $Username -ErrorAction SilentlyContinue)) {
    New-LocalUser -Name $Username -Password $secure -FullName $Username -PasswordNeverExpires -AccountNeverExpires | Out-Null
    Write-Host "[*] User $Username created."
} else {
    Write-Host "[*] User $Username already exists."
}

Add-LocalGroupMember -Group "Administrators" -Member $Username -ErrorAction SilentlyContinue

# ----- enable RDP -----
Write-Host "[*] Enabling RDP..."
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
New-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthentication" -PropertyType DWord -Value 1 -Force | Out-Null
Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue

# ----- optional wallpaper -----
if ($WallpaperUrl -and $WallpaperUrl.Trim() -ne "") {
    try {
        Write-Host "[*] Setting wallpaper..."
        $wall = "C:\Users\Public\Pictures\wallpaper.jpg"
        Invoke-WebRequest -Uri $WallpaperUrl -OutFile $wall -UseBasicParsing
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value $wall
        RUNDLL32.EXE USER32.DLL,UpdatePerUserSystemParameters
    } catch {
        Write-Warning "Wallpaper failed: $_"
    }
}

Write-Host ""
Write-Host "========================================"
Write-Host "  Windows RDP via Tailscale READY ✅"
Write-Host "  Tailscale IP : $tsIp"
Write-Host "  User         : $Username"
Write-Host "  Pass         : $Password"
Write-Host "========================================"
