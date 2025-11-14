$TSIP = (tailscale ip -4 | Select-Object -First 1)

Write-Host "==============================="
Write-Host " Windows Remote Info"
Write-Host "-------------------------------"
Write-Host " Tailscale IP : $TSIP"
Write-Host " User         : Sapna"
Write-Host " Password     : Sapna"
Write-Host " VNC Pass     : Sapna"
Write-Host " Port (VNC)   : 5900"
Write-Host "==============================="
