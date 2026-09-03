#!/usr/bin/env bash
# watch-logs.sh — tail the focus-notch debug log with optional filter
# Usage: ./watch-logs.sh [grep-pattern]
#   ./watch-logs.sh              → all logs
#   ./watch-logs.sh FocusService → only [FocusService] lines
#   ./watch-logs.sh "warn\|error" → warnings and errors

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/debug.log"

if [[ ! -f "$LOG_FILE" ]]; then
    echo "Log file not found: $LOG_FILE"
    echo "Run ./debugger.sh first."
    exit 1
fi

PATTERN="${1:-}"

echo "[watch-logs] Tailing: $LOG_FILE"
[[ -n "$PATTERN" ]] && echo "[watch-logs] Filter:  $PATTERN"
echo "─────────────────────────────────────────────────────"

if [[ -n "$PATTERN" ]]; then
    tail -f "$LOG_FILE" | grep --line-buffered -i "$PATTERN"
else
    tail -f "$LOG_FILE"
fi
