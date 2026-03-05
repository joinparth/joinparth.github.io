#!/usr/bin/env bash
set -euo pipefail

APP_NAME="parth.social"
APP_ID="joinparth"
APP_URL="https://joinparth.github.io"

ICON_DIR="$HOME/.local/share/icons/hicolor/128x128/apps"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_PATH="$ICON_DIR/${APP_ID}.png"
DESKTOP_FILE="$DESKTOP_DIR/${APP_ID}.desktop"

# ── Colour helpers ────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[•]${RESET} $*"; }
success() { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[✗]${RESET} $*" >&2; exit 1; }

# ── Banner ────────────────────────────────────────────────────
echo -e "${BOLD}"
echo "  ╔═══════════════════════════════════════╗"
echo "  ║         Parth Social Installer        ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "${RESET}"

# ── Dependency checks ─────────────────────────────────────────
info "Checking dependencies…"

silent_install() {
  # $1 = package manager command + args (as array), $2 = friendly name
  info "Installing dependencies…"
  if ! "$@" &>/dev/null; then
    error "Could not install $2. Please install it manually."
  fi
}

need_cmd() {
  if ! command -v "$1" &>/dev/null; then
    if command -v apt-get &>/dev/null; then
      silent_install sudo apt-get install -y "$2" "$2"
    elif command -v dnf &>/dev/null; then
      silent_install sudo dnf install -y "$2" "$2"
    elif command -v pacman &>/dev/null; then
      silent_install sudo pacman -S --noconfirm "$2" "$2"
    else
      error "'$1' is required but not installed, and no known package manager found."
    fi
  fi
}

need_cmd curl curl
need_cmd convert imagemagick

# ── Ensure Chromium is installed ──────────────────────────────
detect_browser() {
  for b in chromium chromium-browser google-chrome google-chrome-stable microsoft-edge microsoft-edge-stable brave-browser; do
    if command -v "$b" &>/dev/null; then
      echo "$b"; return
    fi
  done
  echo ""
}

BROWSER=$(detect_browser)

if [[ -z "$BROWSER" ]]; then
  info "Installing dependencies…"
  if command -v apt-get &>/dev/null; then
    sudo apt-get install -y chromium &>/dev/null || sudo apt-get install -y chromium-browser &>/dev/null || error "Could not install Chromium."
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y chromium &>/dev/null || error "Could not install Chromium."
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm chromium &>/dev/null || error "Could not install Chromium."
  else
    error "Could not install Chromium — no known package manager found. Please install Chrome/Chromium manually."
  fi
  BROWSER=$(detect_browser)
  [[ -z "$BROWSER" ]] && error "Chromium installation failed. Please install it manually."
  success "Chromium installed: $BROWSER"
else
  success "Found browser: $BROWSER"
fi

EXEC_LINE="${BROWSER} --app=${APP_URL} --class=${APP_ID}"

# ── Create directories ────────────────────────────────────────
info "Creating directories…"
mkdir -p "$ICON_DIR" "$DESKTOP_DIR"

# ── Download favicon and convert to PNG ──────────────────────
info "Fetching favicon from ${APP_URL}…"

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
    info "Downloaded favicon from $fav"
    FETCHED=true
    break
  fi
done

if [[ "$FETCHED" == "false" ]]; then
  warn "Could not download favicon — generating a placeholder icon."
  convert -size 128x128 xc:'#0f172a' \
    -fill '#38bdf8' \
    -font DejaVu-Sans-Bold -pointsize 52 \
    -gravity Center -annotate 0 'P' \
    "$TMP_PNG" 2>/dev/null || {
      warn "ImageMagick placeholder also failed. Using default icon."
      TMP_PNG=""
    }
else
  info "Converting icon to PNG…"
  if convert "${TMP_ICO}[0]" -resize 128x128 "$TMP_PNG" 2>/dev/null; then
    success "Icon converted successfully."
  else
    warn "Conversion failed — trying direct copy."
    cp "$TMP_ICO" "$TMP_PNG" 2>/dev/null || TMP_PNG=""
  fi
fi

if [[ -n "$TMP_PNG" ]] && [[ -s "$TMP_PNG" ]]; then
  cp "$TMP_PNG" "$ICON_PATH"
  success "Icon saved to $ICON_PATH"
  ICON_LINE="Icon=${ICON_PATH}"
else
  warn "No icon available — desktop shortcut will use default."
  ICON_LINE="Icon=web-browser"
fi

# Cleanup temp files
rm -f "$TMP_ICO" "$TMP_PNG"

# ── Remove any stray .desktop files created by ImageMagick ───
info "Cleaning up stray .desktop files…"
find "$DESKTOP_DIR" -maxdepth 1 -name "display-im*.desktop" -delete 2>/dev/null || true
for stray in \
  "$DESKTOP_DIR/display-im6.q16.desktop" \
  "$DESKTOP_DIR/display-im6.q16hdri.desktop" \
  "$DESKTOP_DIR/display-im7.desktop"
do
  [[ -f "$stray" ]] && rm -f "$stray" && info "Removed stray: $(basename "$stray")"
done

# ── Write .desktop file ───────────────────────────────────────
info "Writing .desktop file…"

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
success ".desktop file written to $DESKTOP_FILE"

# ── Refresh desktop database ──────────────────────────────────
if command -v update-desktop-database &>/dev/null; then
  update-desktop-database "$DESKTOP_DIR" 2>/dev/null && info "Desktop database refreshed."
fi

if command -v gtk-update-icon-cache &>/dev/null; then
  gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null && info "Icon cache updated."
fi

# ── Done ──────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}  Installation complete!${RESET}"
echo -e "  ${APP_NAME} has been added to your application menu."
echo -e "  You can also launch it with:"
echo -e "  ${CYAN}${EXEC_LINE}${RESET}"
echo ""
