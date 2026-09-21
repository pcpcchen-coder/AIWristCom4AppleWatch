#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
"$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc" \
  -swift-version 6 -warnings-as-errors -parse-as-library \
  -sdk "$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk" \
  -target arm64-apple-macosx14.0 Shared/*.swift \
  iPhoneApp/Models/GatewayModels.swift iPhoneApp/Services/LLMProvider.swift \
  tests/ProviderSmoke.swift -o .build/provider-smoke
.build/provider-smoke
