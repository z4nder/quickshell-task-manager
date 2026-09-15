#!/usr/bin/env bash
# install.sh — installs focus-notch on any Linux distro with Quickshell
# Requirements: cargo (Rust), quickshell (must be installed separately)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
BIN_DIR="${HOME}/.local/bin"
SRC_CONFIG="$REPO_DIR/quickshell/config"
DST_ICONS="$QS_DIR/focus-icons"

echo "==> Building focusctl..."
cargo build --release -p focusctl --manifest-path "$REPO_DIR/Cargo.toml"

echo "==> Installing binary to $BIN_DIR..."
mkdir -p "$BIN_DIR"
cp "$REPO_DIR/target/release/focusctl" "$BIN_DIR/focusctl"

echo "==> Deploying Quickshell QML components to $QS_DIR..."
mkdir -p "$QS_DIR"

# All Focus*.qml components
for f in "$SRC_CONFIG"/Focus*.qml; do
    [ -f "$f" ] && cp "$f" "$QS_DIR/"
done

# JS theme file and themes JSON
cp "$SRC_CONFIG/FocusTheme.js" "$QS_DIR/FocusTheme.js"
cp "$SRC_CONFIG/themes.json"   "$QS_DIR/themes.json"

echo "==> Deploying icons to $DST_ICONS..."
mkdir -p "$DST_ICONS"

# Icons are already processed with correct fills — copy directly
for f in "$SRC_CONFIG/focus-icons/"*.svg; do
    [ -f "$f" ] && cp "$f" "$DST_ICONS/"
done

echo ""
echo "Done!"
echo ""
echo "  Binary : $BIN_DIR/focusctl"
echo "  Config : $QS_DIR/"
echo "  Icons  : $DST_ICONS/"
echo ""
echo "Make sure $BIN_DIR is in your PATH."
echo ""
echo "To use with an existing Quickshell bar, import and add FocusWidget."
echo "Or use the bundled shell as a starting point:"
echo "  quickshell -p $REPO_DIR/quickshell/shell.qml"
echo ""
echo "For NixOS/home-manager, use the flake module instead:"
echo "  programs.focus-notch.enable = true;"
