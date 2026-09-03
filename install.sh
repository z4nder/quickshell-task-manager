#!/usr/bin/env bash
# install.sh — installs focus-notch on any Linux distro
# Requirements: cargo (Rust), quickshell (must be installed separately)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
BIN_DIR="${HOME}/.local/bin"
ICONS_SRC="$REPO_DIR/assets"
ICONS_DST="$QS_DIR/focus-icons"

echo "==> Building focusctl..."
cargo build --release -p focusctl --manifest-path "$REPO_DIR/Cargo.toml"

echo "==> Installing binary to $BIN_DIR..."
mkdir -p "$BIN_DIR"
cp "$REPO_DIR/target/release/focusctl" "$BIN_DIR/focusctl"

echo "==> Deploying Quickshell config to $QS_DIR..."
mkdir -p "$QS_DIR"
for f in "$REPO_DIR"/quickshell/config/Focus*.qml \
         "$REPO_DIR"/quickshell/config/FocusWidget.qml; do
    [ -f "$f" ] && cp "$f" "$QS_DIR/"
done

echo "==> Processing and deploying icons to $ICONS_DST..."
mkdir -p "$ICONS_DST"

process_icon() {
    local name="$1" color="$2" src_file="$3"
    sed "s/currentColor/$color/g" "$REPO_DIR/assets/${src_file}.svg" \
        > "$ICONS_DST/${name}.svg"
}

process_icon check                "#e53935" check
process_icon play                 "#ffffff"  play
process_icon play-accent          "#e53935"  play
process_icon pause                "#e53935"  pause
process_icon trash                "#48484a"  trash
process_icon arrows-up-down       "#8e8e93"  arrows-up-down
process_icon arrows-pointing-out  "#8e8e93"  arrows-pointing-out
process_icon cog-6-tooth          "#8e8e93"  cog-6-tooth
process_icon chevron-left         "#8e8e93"  chevron-left
process_icon chevron-right        "#8e8e93"  chevron-right
process_icon pencil-square        "#8e8e93"  pencil-square

echo "==> Deploying FocusTheme.js..."
cp "$REPO_DIR/quickshell/config/FocusTheme.js" "$QS_DIR/FocusTheme.js"

echo ""
echo "Done! focusctl installed to $BIN_DIR/focusctl"
echo ""
echo "Make sure $BIN_DIR is in your PATH, then add to your Quickshell bar:"
echo "  FocusWidget { barWindow: root }"
echo ""
echo "If using NixOS/home-manager, use the flake module instead:"
echo "  programs.focus-notch.enable = true;"
