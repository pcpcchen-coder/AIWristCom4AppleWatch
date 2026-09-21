#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
COMPILER="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
"$COMPILER" -typecheck -swift-version 6 -warnings-as-errors \
  -sdk "$DEVELOPER_DIR/Platforms/WatchOS.platform/Developer/SDKs/WatchOS.sdk" \
  -target arm64_32-apple-watchos11.0 -module-name AIWristWatch \
  Shared/*.swift WatchApp/*.swift WatchApp/Models/*.swift WatchApp/Services/*.swift
"$COMPILER" -typecheck -swift-version 6 -warnings-as-errors \
  -sdk "$DEVELOPER_DIR/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk" \
  -target arm64-apple-ios18.0 -module-name AIWristCompanion \
  Shared/*.swift iPhoneApp/*.swift iPhoneApp/Models/*.swift iPhoneApp/Services/*.swift iPhoneApp/Views/*.swift
