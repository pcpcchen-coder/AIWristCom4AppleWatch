#!/bin/bash
set -euo pipefail

LABEL="com.aiwrist.gateway"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$UID/$LABEL" 2>/dev/null || true
rm -f "$PLIST"

echo "Removed: $LABEL"
