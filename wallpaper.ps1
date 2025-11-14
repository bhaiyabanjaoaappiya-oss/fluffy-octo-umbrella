param(
  [string]$WallpaperUrl
)

$wall = "C:\Users\Public\Pictures\wall.jpg"
Invoke-WebRequest -Uri $WallpaperUrl -OutFile $wall -UseBasicParsing

Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value $wall
RUNDLL32.EXE USER32.DLL,UpdatePerUserSystemParameters

Write-Host "[*] Wallpaper successfully applied!"
