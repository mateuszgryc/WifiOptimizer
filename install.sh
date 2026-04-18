#!/bin/bash
# WiFi Optimizer - Decky Plugin Installer
# Usage: curl -sL https://github.com/mateuszgryc/WifiOptimizer/raw/main/install.sh -o /tmp/wifi-opt-install.sh && sudo bash /tmp/wifi-opt-install.sh

set -e

PLUGIN_NAME="WiFi Optimizer"
REPO_SLUG="mateuszgryc/WifiOptimizer"
INSTALL_URL="https://github.com/$REPO_SLUG/raw/main/install.sh"
SELECTED_REF="${WIFI_OPTIMIZER_REF:-latest}"

# Check for root (needed to write to plugin dir and restart service)
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run with sudo."
    echo "Run: sudo bash $0"
    exit 1
fi

# Resolve the real user's home directory (same method as Decky's own installer)
DECK_USER="${SUDO_USER:-deck}"
USER_HOME="$(getent passwd "$DECK_USER" | cut -d: -f6)"
if [ -z "$USER_HOME" ]; then
    USER_HOME="/home/deck"
fi

PLUGIN_BASE="$USER_HOME/homebrew/plugins"
PLUGIN_DIR="$PLUGIN_BASE/$PLUGIN_NAME"

# Check Decky is installed
if [ ! -d "$PLUGIN_BASE" ]; then
    echo "Error: Decky Loader not found at $PLUGIN_BASE"
    echo "Install it first: https://decky.xyz"
    exit 1
fi

if [ "$SELECTED_REF" = "latest" ]; then
    echo "Checking for latest release..."
    LATEST_TAG=$(curl -sL "https://api.github.com/repos/$REPO_SLUG/releases/latest" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')

    if [ -z "$LATEST_TAG" ]; then
        echo "Warning: Couldn't fetch latest release, falling back to main branch"
        SELECTED_REF="main"
    else
        echo "Latest release: $LATEST_TAG"
        SELECTED_REF="$LATEST_TAG"
    fi
fi

if [ "$SELECTED_REF" = "main" ]; then
    REPO_URL="https://github.com/$REPO_SLUG/archive/refs/heads/main.tar.gz"
    DIR_NAME="WifiOptimizer-main"
    DISPLAY_REF="main"
else
    REPO_URL="https://github.com/$REPO_SLUG/archive/refs/tags/${SELECTED_REF}.tar.gz"
    DIR_NAME="WifiOptimizer-${SELECTED_REF#v}"
    DISPLAY_REF="$SELECTED_REF"
fi

TMP_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "Installing $PLUGIN_NAME..."

# Download and extract
echo "Downloading..."
curl -sL "$REPO_URL" -o "$TMP_DIR/plugin.tar.gz"
tar xzf "$TMP_DIR/plugin.tar.gz" -C "$TMP_DIR"

SRC="$TMP_DIR/$DIR_NAME"
if [ ! -f "$SRC/plugin.json" ]; then
    echo "Error: Download failed or repo structure changed."
    exit 1
fi

# Install
if [ -d "$PLUGIN_DIR" ]; then
    echo "Upgrading existing installation..."
    UPGRADING=true
else
    echo "Installing to $PLUGIN_DIR..."
    UPGRADING=false
fi
rm -rf "$PLUGIN_DIR"
mkdir -p "$PLUGIN_DIR/dist" "$PLUGIN_DIR/defaults" "$PLUGIN_DIR/py_modules"

cp "$SRC/plugin.json" "$PLUGIN_DIR/"
cp "$SRC/package.json" "$PLUGIN_DIR/"
cp "$SRC/main.py" "$PLUGIN_DIR/"
cp "$SRC/decky.pyi" "$PLUGIN_DIR/"
cp "$SRC/dist/index.js" "$PLUGIN_DIR/dist/"
cp "$SRC/dist/index.js.map" "$PLUGIN_DIR/dist/" 2>/dev/null || true
cp "$SRC/defaults/dispatcher.sh.tmpl" "$PLUGIN_DIR/defaults/"
touch "$PLUGIN_DIR/py_modules/.keep"

# Install a local manual-update helper and Desktop launcher for the deck user.
USER_BIN_DIR="$USER_HOME/.local/bin"
APPLICATIONS_DIR="$USER_HOME/.local/share/applications"
DESKTOP_DIR="$USER_HOME/Desktop"
HELPER_PATH="$USER_BIN_DIR/wifi-optimizer-update"
LAUNCHER_NAME="Update WiFi Optimizer.desktop"

mkdir -p "$USER_BIN_DIR" "$APPLICATIONS_DIR" "$DESKTOP_DIR"

sed \
    -e "s|__REPO_SLUG__|$REPO_SLUG|g" \
    -e "s|__INSTALL_URL__|$INSTALL_URL|g" \
    -e "s|__PLUGIN_DIR__|$PLUGIN_DIR|g" \
    "$SRC/support/update-helper.sh.tmpl" > "$HELPER_PATH"
chmod 755 "$HELPER_PATH"
chown "$DECK_USER":"$DECK_USER" "$HELPER_PATH"

for launcher_target in "$APPLICATIONS_DIR/$LAUNCHER_NAME" "$DESKTOP_DIR/$LAUNCHER_NAME"; do
    sed -e "s|__HELPER_PATH__|$HELPER_PATH|g" \
        "$SRC/support/update-launcher.desktop.tmpl" > "$launcher_target"
    chmod 755 "$launcher_target"
    chown "$DECK_USER":"$DECK_USER" "$launcher_target"
done

# Restart Decky
echo "Restarting Decky Loader..."
systemctl restart plugin_loader 2>/dev/null || true

echo ""
if [ "$UPGRADING" = true ]; then
    echo "WiFi Optimizer updated to $DISPLAY_REF! Your settings have been preserved."
else
    echo "WiFi Optimizer installed from $DISPLAY_REF! Open the Quick Access Menu to configure."
fi
echo "Desktop launcher installed: $DESKTOP_DIR/$LAUNCHER_NAME"
