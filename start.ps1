# ============================
# Windows Start Script
# Tailscale + RDP + VNC + Wallpaper
# ============================

param(
    [string]$Username = "Sapna",
    [string]$Password = "Sapna",
    [string]$VncPassword = "Sapna",
    [string]$TailscaleAuth = $env:TAILSCALE_AUTHKEY,
    [string]$WallpaperUrl = $env:WALLPAPER_URL
)

# ---- Check Tailscale Auth Key ----
if (-not $TailscaleAuth) {
    Write-Error "Tailscale auth key missing."
    exit 1
}

# ---- Install Tailscale ----
$exe = "C:\Program Files\Tailscale\tailscale.exe"

if (-not (Test-Path $exe)) {
    Write-Host "[*] Installing Tailscale..."
    $url = "https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe"
    $dst = "$env:TEMP\ts.exe"

    Invoke-WebRequest -Uri $url -OutFile $dst -UseBasicParsing
    Start-Process $dst -ArgumentList "/quiet" -Wait
}

Start-Service Tailscale -ErrorAction SilentlyContinue

# ---- Login to Tailscale ----
$hostname = "win-full-$([guid]::NewGuid().ToString().Substring(0,6))"

Write-Host "[*] Tailscale UP..."
& $exe up `
    --authkey "$TailscaleAuth" `
    --hostname "$hostname" `
    --accept-routes `
    --accept-dns=false

$TSIP = (& $exe ip -4 | Select-Object -First 1)
Write-Host "[*] Tailscale IPv4: $TSIP"


# ---- Create User for RDP/VNC ----
$secure = ConvertTo-SecureString $Password -AsPlainText -Force

if (-not (Get-LocalUser -Name $Username -ErrorAction SilentlyContinue)) {
    Write-Host "[*] Creating user $Username"
    New-LocalUser -Name $Username -Password $secure -FullName $Username -PasswordNeverExpires
}

Add-LocalGroupMember -Group "Administrators" -Member $Username -ErrorAction SilentlyContinue


# ---- Enable RDP ----
Write-Host "[*] Enabling RDP..."
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" `
    -Name "fDenyTSConnections" -Value 0

Enable-NetFirewallRule -DisplayGroup "Remote Desktop"


# ---- Install UltraVNC ----
Write-Host "[*] Installing UltraVNC..."
$vncUrl = "https://www.uvnc.eu/download/1220/UltraVNC_1220_X64_Setup.exe"
$vncExe = "$env:TEMP\uvnc.exe"
Invoke-WebRequest $vncUrl -OutFile $vncExe

Start-Process $vncExe -ArgumentList "/silent" -Wait

# ---- Set VNC Password ----
Write-Host "[*] Setting VNC password..."

$enc = ([byte[]][char[]]$VncPassword) | ForEach-Object { $_ -bxor 0xA3 }
$hex = ($enc | ForEach-Object { $_.ToString("X2") }) -join ""

$ini = "C:\Program Files\uvnc bvba\UltraVNC\ultravnc.ini"
Set-Content $ini "[UltraVNC]"
Add-Content $ini "passwd=$hex"

Restart-Service uvnc_service -ErrorAction SilentlyContinue


# ---- Wallpaper Set (optional) ----
if ($WallpaperUrl) {
    Write-Host "[*] Setting Wallpaper..."
    $wall = "C:\Users\Public\Pictures\wall.jpg"
    Invoke-WebRequest -Uri $WallpaperUrl -OutFile $wall -UseBasicParsing

    Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value $wall
    RUNDLL32.EXE USER32.DLL,UpdatePerUserSystemParameters
}

Write-Host "========================================"
Write-Host " Windows Full Setup Complete"
Write-Host " Tailscale IP : $TSIP"
Write-Host " User         : $Username"
Write-Host " Password     : $Password"
Write-Host " VNC Pass     : $VncPassword"
Write-Host "========================================"
