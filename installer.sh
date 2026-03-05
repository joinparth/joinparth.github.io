#!/usr/bin/env bash
# ============================================================
#  PWA Installer — joinparth.github.io
#  Creates a .desktop shortcut with the site's favicon as icon
# ============================================================

set -euo pipefail

APP_NAME="Parth's Portfolio"
APP_ID="joinparth-portfolio"
APP_URL="https://joinparth.github.io"
FAVICON_URL="https://joinparth.github.io/favicon.ico"

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
echo "  ║   PWA Installer · joinparth.github.io  ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "${RESET}"

# ── Dependency checks ─────────────────────────────────────────
info "Checking dependencies…"

need_cmd() {
  if ! command -v "$1" &>/dev/null; then
    warn "'$1' not found — attempting to install…"
    if command -v apt-get &>/dev/null; then
      sudo apt-get install -y "$2" || error "Could not install $2. Please install it manually."
    elif command -v dnf &>/dev/null; then
      sudo dnf install -y "$2" || error "Could not install $2. Please install it manually."
    elif command -v pacman &>/dev/null; then
      sudo pacman -S --noconfirm "$2" || error "Could not install $2. Please install it manually."
    else
      error "'$1' is required but not installed, and no known package manager found."
    fi
  fi
}

need_cmd curl   curl
need_cmd wget   wget
need_cmd convert imagemagick   # ImageMagick for .ico → .png conversion

# Detect browser — prefer Chromium-based for PWA support
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
  warn "No Chromium-based browser found."
  warn "PWAs need Chrome/Chromium/Edge/Brave for full install support."
  warn "Falling back to a generic browser shortcut (xdg-open)."
  BROWSER_CMD="xdg-open"
  EXEC_LINE="xdg-open ${APP_URL}"
  NODISPLAY=""
else
  success "Found browser: $BROWSER"
  EXEC_LINE="${BROWSER} --app=${APP_URL} --class=${APP_ID}"
  NODISPLAY=""
fi

# ── Create directories ────────────────────────────────────────
info "Creating directories…"
mkdir -p "$ICON_DIR" "$DESKTOP_DIR"

# ── Download favicon and convert to PNG ──────────────────────
info "Fetching favicon from ${APP_URL}…"

TMP_ICO=$(mktemp /tmp/${APP_ID}-XXXXXX.ico)
TMP_PNG=$(mktemp /tmp/${APP_ID}-XXXXXX.png)

# Try multiple favicon locations
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
  # Create a simple coloured placeholder with ImageMagick
  convert -size 128x128 xc:'#0f172a' \
    -fill '#38bdf8' \
    -font DejaVu-Sans-Bold -pointsize 52 \
    -gravity Center -annotate 0 'P' \
    "$TMP_PNG" 2>/dev/null || {
      warn "ImageMagick placeholder generation also failed. Using no icon."
      TMP_PNG=""
    }
else
  # Convert .ico / any format → 128×128 PNG
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

# ── Write .desktop file ───────────────────────────────────────
info "Writing .desktop file…"

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=${APP_NAME}
Comment=Parth's personal portfolio — installed as a PWA
${EXEC_LINE:+Exec=${EXEC_LINE}}
${ICON_LINE}
Terminal=false
Categories=Network;WebApplication;
StartupWMClass=${APP_ID}
StartupNotify=true
Keywords=portfolio;parth;developer;
EOF

# Overwrite Exec cleanly (here-doc variable expansion can be tricky)
sed -i "s|^Exec=.*|Exec=${EXEC_LINE}|" "$DESKTOP_FILE"

chmod +x "$DESKTOP_FILE"
success ".desktop file written to $DESKTOP_FILE"

# ── Refresh desktop database ──────────────────────────────────
if command -v update-desktop-database &>/dev/null; then
  update-desktop-database "$DESKTOP_DIR" 2>/dev/null && \
    info "Desktop database refreshed."
fi

if command -v gtk-update-icon-cache &>/dev/null; then
  gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null && \
    info "Icon cache updated."
fi

# ── (Optional) install as PWA via Chrome/Chromium if available ──
if [[ -n "$BROWSER" ]]; then
  echo ""
  echo -e "${BOLD}  ── PWA Installation ──────────────────────────${RESET}"
  echo -e "  To fully install as a PWA, run:"
  echo -e "  ${CYAN}${BROWSER} --app=${APP_URL}${RESET}"
  echo -e "  Then click the ${BOLD}install icon${RESET} (⊕) in the address bar."
  echo -e "  ${BOLD}──────────────────────────────────────────────${RESET}"
fi

# ── Done ──────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}  Installation complete!${RESET}"
echo -e "  ${APP_NAME} has been added to your application menu."
echo -e "  You can also launch it with:"
echo -e "  ${CYAN}${EXEC_LINE}${RESET}"
echo ""

