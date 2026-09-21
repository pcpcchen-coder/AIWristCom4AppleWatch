#!/bin/bash
set -euo pipefail

LABEL="com.aiwrist.gateway"
SERVER_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_UVICORN="$SERVER_DIR/.venv/bin/uvicorn"
CODEX_BIN="$(command -v codex || true)"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG_DIR="$HOME/Library/Logs"

if [[ ! -x "$VENV_UVICORN" ]]; then
  echo "ERROR: $VENV_UVICORN not found."
  echo "Create the venv first:"
  echo "  cd $SERVER_DIR"
  echo "  python3 -m venv .venv"
  echo "  source .venv/bin/activate"
  echo "  pip install -r requirements.txt"
  exit 1
fi

if [[ -z "$CODEX_BIN" ]]; then
  echo "ERROR: codex not found in PATH."
  echo "Install the official Codex CLI and complete 'codex login' first."
  exit 1
fi

CODEX_DIR="$(dirname "$CODEX_BIN")"
mkdir -p "$HOME/Library/LaunchAgents" "$LOG_DIR"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>

    <key>ProgramArguments</key>
    <array>
        <string>$VENV_UVICORN</string>
        <string>main:app</string>
        <string>--host</string>
        <string>0.0.0.0</string>
        <string>--port</string>
        <string>8000</string>
    </array>

    <key>WorkingDirectory</key>
    <string>$SERVER_DIR</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>$CODEX_DIR:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>ProcessType</key>
    <string>Background</string>

    <key>StandardOutPath</key>
    <string>$LOG_DIR/AIWristCom.gateway.log</string>

    <key>StandardErrorPath</key>
    <string>$LOG_DIR/AIWristCom.gateway.error.log</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$UID/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID" "$PLIST"
launchctl kickstart -k "gui/$UID/$LABEL"

echo "Installed and started: $LABEL"
echo "Plist: $PLIST"
echo "Health: curl http://127.0.0.1:8000/health"
echo "Logs:"
echo "  $LOG_DIR/AIWristCom.gateway.log"
echo "  $LOG_DIR/AIWristCom.gateway.error.log"
