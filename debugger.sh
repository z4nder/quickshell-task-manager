#!/usr/bin/env bash
# debugger.sh — run quickshell with logging to file + live tail
# Usage: ./debugger.sh [config-path]
#   config-path defaults to ~/projects/nixos/nixos-setup/modules/hyprland/quickshell/config

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="${1:-$HOME/projects/nixos/nixos-setup/modules/hyprland/quickshell/config}"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/debug.log"

mkdir -p "$LOG_DIR"

echo "[debugger] Config: $CONFIG_PATH"
echo "[debugger] Log:    $LOG_FILE"
echo ""

# Kill any existing quickshell instance
pkill quickshell 2>/dev/null && echo "[debugger] Killed existing quickshell" || true
sleep 0.3

# Rotate log (keep last 500 lines if file exists)
if [[ -f "$LOG_FILE" ]]; then
    tail -n 500 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi

echo "[debugger] Starting quickshell... (Ctrl+C to stop)" | tee -a "$LOG_FILE"
echo "─────────────────────────────────────────────────────" | tee -a "$LOG_FILE"

# Run quickshell — stdout+stderr go to terminal AND log file
quickshell -p "$CONFIG_PATH" 2>&1 | tee -a "$LOG_FILE"
