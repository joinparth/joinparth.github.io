#!/usr/bin/env bash
# ============================================================
#  PWA Installer — parth.social (Mac + Linux)
# ============================================================
set -euo pipefail

APP_NAME="parth.social"
APP_ID="joinparth"
APP_URL="https://joinparth.github.io"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[•]${RESET} $*"; }
success() { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[✗]${RESET} $*" >&2; exit 1; }

echo -e "${BOLD}"
echo "  ╔═══════════════════════════════════════╗"
echo "  ║         Parth Social Installer        ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "${RESET}"

# ── Detect OS ────────────────────────────────────────────────
OS="$(uname -s)"
case "$OS" in
  Linux*)  PLATFORM="linux" ;;
  Darwin*) PLATFORM="mac"   ;;
  *)       error "Unsupported OS: $OS. Use installer.ps1 on Windows." ;;
esac
info "Detected platform: $PLATFORM"

# ── Silent install helper ─────────────────────────────────────
silent_install() {
  local pkg="$1"; shift
  info "Installing dependencies…"
  "$@" &>/dev/null || error "Could not install $pkg. Please install it manually."
}

# ── Install curl if missing ───────────────────────────────────
if ! command -v curl &>/dev/null; then
  if [[ "$PLATFORM" == "mac" ]]; then
    error "curl not found. Please install Xcode Command Line Tools: xcode-select --install"
  elif command -v apt-get &>/dev/null; then
    silent_install curl sudo apt-get install -y curl
  elif command -v dnf &>/dev/null; then
    silent_install curl sudo dnf install -y curl
  elif command -v pacman &>/dev/null; then
    silent_install curl sudo pacman -S --noconfirm curl
  else
    error "curl not found and no package manager detected."
  fi
fi

# ── Install ImageMagick if missing ───────────────────────────
if ! command -v convert &>/dev/null; then
  info "Installing dependencies…"
  if [[ "$PLATFORM" == "mac" ]]; then
    if ! command -v brew &>/dev/null; then
      info "Installing Homebrew…"
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" &>/dev/null \
        || error "Homebrew installation failed."
    fi
    brew install imagemagick &>/dev/null || error "Could not install ImageMagick."
  elif command -v apt-get &>/dev/null; then
    silent_install imagemagick sudo apt-get install -y imagemagick
  elif command -v dnf &>/dev/null; then
    silent_install imagemagick sudo dnf install -y imagemagick
  elif command -v pacman &>/dev/null; then
    silent_install imagemagick sudo pacman -S --noconfirm imagemagick
  else
    error "ImageMagick not found and no package manager detected."
  fi
fi

# ── Detect / install browser ──────────────────────────────────
detect_browser() {
  if [[ "$PLATFORM" == "mac" ]]; then
    for b in \
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
      "/Applications/Chromium.app/Contents/MacOS/Chromium" \
      "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
      "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
    do
      [[ -x "$b" ]] && echo "$b" && return
    done
  else
    for b in chromium chromium-browser google-chrome google-chrome-stable \
              microsoft-edge microsoft-edge-stable brave-browser; do
      command -v "$b" &>/dev/null && echo "$b" && return
    done
  fi
  echo ""
}

BROWSER=$(detect_browser)

if [[ -z "$BROWSER" ]]; then
  info "Installing dependencies…"
  if [[ "$PLATFORM" == "mac" ]]; then
    command -v brew &>/dev/null || \
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" &>/dev/null
    brew install --cask chromium &>/dev/null || error "Could not install Chromium."
  elif command -v apt-get &>/dev/null; then
    sudo apt-get install -y chromium &>/dev/null || \
      sudo apt-get install -y chromium-browser &>/dev/null || \
      error "Could not install Chromium."
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y chromium &>/dev/null || error "Could not install Chromium."
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm chromium &>/dev/null || error "Could not install Chromium."
  else
    error "No package manager found. Please install Chrome or Chromium manually."
  fi
  BROWSER=$(detect_browser)
  [[ -z "$BROWSER" ]] && error "Browser installation failed. Please install Chrome/Chromium manually."
  success "Chromium installed."
else
  success "Found browser: $(basename "$BROWSER")"
fi

# ── Platform-specific paths ───────────────────────────────────
if [[ "$PLATFORM" == "mac" ]]; then
  ICON_DIR="$HOME/Library/Application Support/${APP_ID}"
  ICON_PATH="${ICON_DIR}/${APP_ID}.png"
  APP_DIR="/Applications/${APP_NAME}.app"
  CONTENTS="${APP_DIR}/Contents"
  MACOS_DIR="${CONTENTS}/MacOS"
  RESOURCES_DIR="${CONTENTS}/Resources"
else
  ICON_DIR="$HOME/.local/share/icons/hicolor/128x128/apps"
  DESKTOP_DIR="$HOME/.local/share/applications"
  ICON_PATH="${ICON_DIR}/${APP_ID}.png"
  DESKTOP_FILE="${DESKTOP_DIR}/${APP_ID}.desktop"
fi

info "Creating directories…"
if [[ "$PLATFORM" == "mac" ]]; then
  mkdir -p "$ICON_DIR" "$MACOS_DIR" "$RESOURCES_DIR"
else
  mkdir -p "$ICON_DIR" "$DESKTOP_DIR"
fi

# ── Download & convert favicon ────────────────────────────────
info "Fetching favicon…"

TMP_ICO=$(mktemp /tmp/${APP_ID}-XXXXXX.ico)
TMP_PNG=$(mktemp /tmp/${APP_ID}-XXXXXX.png)

FETCHED=false
for fav in \
  "https://joinparth.github.io/favicon.ico" \
  "https://joinparth.github.io/favicon.png" \
  "https://joinparth.github.io/apple-touch-icon.png" \
  "https://joinparth.github.io/logo.png"
do
  HTTP_CODE=$(curl -sL -o "$TMP_ICO" -w "%{http_code}" "$fav" 2>/dev/null || echo "000")
  if [[ "$HTTP_CODE" == "200" ]] && [[ -s "$TMP_ICO" ]]; then
    FETCHED=true; break
  fi
done

if [[ "$FETCHED" == "false" ]]; then
  warn "Could not download favicon — generating placeholder icon."
  convert -size 128x128 xc:'#0f172a' \
    -fill '#38bdf8' -font DejaVu-Sans-Bold -pointsize 52 \
    -gravity Center -annotate 0 'P' "$TMP_PNG" 2>/dev/null || TMP_PNG=""
else
  convert "${TMP_ICO}[0]" -resize 128x128 "$TMP_PNG" 2>/dev/null || \
    cp "$TMP_ICO" "$TMP_PNG" 2>/dev/null || TMP_PNG=""
fi

if [[ -n "$TMP_PNG" ]] && [[ -s "$TMP_PNG" ]]; then
  cp "$TMP_PNG" "$ICON_PATH"
  success "Icon saved."
else
  warn "No icon — using system default."
fi

rm -f "$TMP_ICO" "$TMP_PNG"

# ── Create shortcut ───────────────────────────────────────────
if [[ "$PLATFORM" == "mac" ]]; then
  # Convert PNG → ICNS for macOS
  ICNS_PATH="${RESOURCES_DIR}/${APP_ID}.icns"
  if [[ -f "$ICON_PATH" ]]; then
    ICONSET=$(mktemp -d /tmp/${APP_ID}-XXXXXX.iconset)
    sips -z 128 128 "$ICON_PATH" --out "${ICONSET}/icon_128x128.png" &>/dev/null || true
    iconutil -c icns "$ICONSET" -o "$ICNS_PATH" &>/dev/null || cp "$ICON_PATH" "$ICNS_PATH"
    rm -rf "$ICONSET"
  fi

  # Write launcher script
  LAUNCHER="${MACOS_DIR}/${APP_NAME}"
  cat > "$LAUNCHER" <<EOF
#!/usr/bin/env bash
exec "${BROWSER}" --app=${APP_URL} --class=${APP_ID} "\$@"
EOF
  chmod +x "$LAUNCHER"

  # Write Info.plist
  cat > "${CONTENTS}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>        <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key> <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>  <string>io.github.joinparth</string>
  <key>CFBundleVersion</key>     <string>1.0</string>
  <key>CFBundleExecutable</key>  <string>${APP_NAME}</string>
  <key>CFBundleIconFile</key>    <string>${APP_ID}</string>
  <key>CFBundlePackageType</key> <string>APPL</string>
</dict>
</plist>
EOF

  success ".app bundle created at ${APP_DIR}"

  # Register with macOS
  if command -v lsregister &>/dev/null; then
    lsregister -f "$APP_DIR" &>/dev/null || true
  fi
  touch "$APP_DIR"   # nudge Finder/Spotlight

  LAUNCH_CMD="open '${APP_DIR}'"

else
  # ── Linux: .desktop file ─────────────────────────────────────
  EXEC_LINE="${BROWSER} --app=${APP_URL} --class=${APP_ID}"

  # Clean up ImageMagick stray desktops
  find "$DESKTOP_DIR" -maxdepth 1 -name "display-im*.desktop" -delete 2>/dev/null || true

  ICON_LINE="Icon=${ICON_PATH}"
  [[ ! -f "$ICON_PATH" ]] && ICON_LINE="Icon=web-browser"

  cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=${APP_NAME}
Comment=Parth's personal portfolio — installed as a PWA
Exec=${EXEC_LINE}
${ICON_LINE}
Terminal=false
Categories=Network;WebApplication;
StartupWMClass=${APP_ID}
StartupNotify=true
Keywords=portfolio;parth;developer;
EOF

  chmod +x "$DESKTOP_FILE"
  success ".desktop file written."

  command -v update-desktop-database &>/dev/null && \
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
  command -v gtk-update-icon-cache &>/dev/null && \
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

  LAUNCH_CMD="$EXEC_LINE"
fi

# ── Done ──────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}  Installation complete!${RESET}"
echo -e "  ${APP_NAME} has been added to your application menu."
echo -e "  Launch it with: ${CYAN}${LAUNCH_CMD}${RESET}"
echo ""
