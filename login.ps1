$tsExe = "C:\Program Files\Tailscale\tailscale.exe"
if (Test-Path $tsExe) {
  $tsIp = (& $tsExe ip -4 | Select-Object -First 1)
} else {
  $tsIp = "<tailscale.exe not found>"
}

$Username = $env:RDP_USER
if (-not $Username) { $Username = "Sapna" }

$Password = $env:RDP_PASS
if (-not $Password) { $Password = "Sapna@12345Love!_987" }

Write-Host "========================================"
Write-Host "   Windows RDP via Tailscale — Info"
Write-Host "========================================"
Write-Host "  Tailscale IP : $tsIp"
Write-Host "  RDP User     : $Username"
Write-Host "  RDP Pass     : $Password"
Write-Host "========================================"
