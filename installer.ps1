# ============================================================
#  PWA Installer — parth.social (Windows)
#  Run in PowerShell: irm https://joinparth.github.io/installer.ps1 | iex
# ============================================================

$ErrorActionPreference = "Stop"

$APP_NAME = "parth.social"
$APP_ID   = "joinparth"
$APP_URL  = "https://joinparth.github.io"

function Info    { param($m) Write-Host "  [*] $m" -ForegroundColor Cyan }
function Success { param($m) Write-Host "  [+] $m" -ForegroundColor Green }
function Warn    { param($m) Write-Host "  [!] $m" -ForegroundColor Yellow }
function Err     { param($m) Write-Host "  [x] $m" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "  +---------------------------------------+" -ForegroundColor White
Write-Host "  |       Parth Social Installer          |" -ForegroundColor White
Write-Host "  +---------------------------------------+" -ForegroundColor White
Write-Host ""

# ── Detect Chromium-based browser ────────────────────────────
function Find-Browser {
  $candidates = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe",
    "$env:LocalAppData\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles\Chromium\Application\chrome.exe",
    "$env:ProgramFiles(x86)\Chromium\Application\chrome.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe",
    "$env:LocalAppData\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe",
    "$env:LocalAppData\BraveSoftware\Brave-Browser\Application\brave.exe"
  )
  foreach ($path in $candidates) {
    if (Test-Path $path) { return $path }
  }
  return $null
}

$Browser = Find-Browser

if (-not $Browser) {
  Info "No Chromium-based browser found — installing Chromium via winget…"
  $winget = Get-Command winget -ErrorAction SilentlyContinue
  if ($winget) {
    winget install -e --id Chromium.Chromium --silent --accept-package-agreements --accept-source-agreements 2>$null | Out-Null
  } else {
    # Fallback: download Chromium installer directly
    Info "Installing dependencies…"
    $tmpInstaller = "$env:TEMP\ChromeSetup.exe"
    Invoke-WebRequest -Uri "https://dl.google.com/chrome/install/latest/chrome_installer.exe" `
      -OutFile $tmpInstaller -UseBasicParsing
    Start-Process $tmpInstaller -ArgumentList "/silent", "/install" -Wait
    Remove-Item $tmpInstaller -Force -ErrorAction SilentlyContinue
  }
  $Browser = Find-Browser
  if (-not $Browser) { Err "Browser installation failed. Please install Chrome/Chromium manually." }
  Success "Browser installed: $(Split-Path $Browser -Leaf)"
} else {
  Success "Found browser: $(Split-Path $Browser -Leaf)"
}

# ── Download favicon ──────────────────────────────────────────
Info "Fetching favicon…"

$IconDir  = "$env:APPDATA\${APP_ID}"
$IconPath = "$IconDir\${APP_ID}.ico"
New-Item -ItemType Directory -Force -Path $IconDir | Out-Null

$favicons = @(
  "https://joinparth.github.io/favicon.ico",
  "https://joinparth.github.io/favicon.png",
  "https://joinparth.github.io/apple-touch-icon.png",
  "https://joinparth.github.io/logo.png"
)

$fetched = $false
foreach ($fav in $favicons) {
  try {
    Invoke-WebRequest -Uri $fav -OutFile $IconPath -UseBasicParsing -ErrorAction Stop
    if ((Get-Item $IconPath).Length -gt 0) { $fetched = $true; break }
  } catch { }
}

if (-not $fetched) {
  Warn "Could not fetch favicon — shortcut will use default browser icon."
  $IconPath = $null
}

# ── Create Start Menu shortcut ────────────────────────────────
Info "Creating Start Menu shortcut…"

$StartMenuDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
$ShortcutPath = "$StartMenuDir\${APP_NAME}.lnk"

$WshShell   = New-Object -ComObject WScript.Shell
$Shortcut   = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath       = $Browser
$Shortcut.Arguments        = "--app=$APP_URL --class=$APP_ID"
$Shortcut.Description      = "Parth's personal portfolio — installed as a PWA"
$Shortcut.WorkingDirectory = Split-Path $Browser
if ($IconPath -and (Test-Path $IconPath)) {
  $Shortcut.IconLocation = "$IconPath,0"
}
$Shortcut.Save()

Success "Start Menu shortcut created."

# ── Also pin a Desktop shortcut ───────────────────────────────
$DesktopPath = "$env:USERPROFILE\Desktop\${APP_NAME}.lnk"
$Shortcut2   = $WshShell.CreateShortcut($DesktopPath)
$Shortcut2.TargetPath       = $Browser
$Shortcut2.Arguments        = "--app=$APP_URL --class=$APP_ID"
$Shortcut2.Description      = "Parth's personal portfolio — installed as a PWA"
$Shortcut2.WorkingDirectory = Split-Path $Browser
if ($IconPath -and (Test-Path $IconPath)) {
  $Shortcut2.IconLocation = "$IconPath,0"
}
$Shortcut2.Save()

Success "Desktop shortcut created."

# ── Done ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Installation complete!" -ForegroundColor Green
Write-Host "  $APP_NAME has been added to your Start Menu and Desktop."
Write-Host "  Launch: `"$Browser`" --app=$APP_URL"
Write-Host ""
