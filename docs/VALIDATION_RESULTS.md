# v0.1 驗證結果 — 2026-09-21

基線：38d2af4。以下為本次執行的結果，不能取代配對裝置驗收。

| 驗證 | 結果 | 範圍 |
|---|---|---|
| Watch Swift 6 / warnings-as-errors | PASS | Xcode 27 watchOS SDK，arm64_32、最低 watchOS 11 |
| iPhone Swift 6 / warnings-as-errors | PASS | Xcode 27 iOS SDK，arm64、最低 iOS 18 |
| Swift XCTest | 6 tests / 0 failures | Shared contract、10 次 fake router、錯誤、reply correlation、once-only continuation、提前取消 |
| Swift provider smoke | 12 cases PASS | 實際 RemoteCodexProvider + URLProtocol stub；200 / malformed / ok=false / empty / 401 / 429 / 500 / 504；4 種錯誤 URL |
| Python pytest | 12 passed | fake Codex 的 HTTP 10 次、auth、validation、error mapping、deadline cleanup、跨 thread event isolation / EOF |
| 架構檢查 | PASS | Watch / Shared 無 HTTP client / credentials / Speech import；companion Info 與 embedding |
| plist / pbxproj 語法 | PASS | plutil -lint |
| 完整 Xcode build/list | BLOCKED | 主機尚未同意 Xcode 授權；未代使用者接受 |
| 實體 Watch↔iPhone 10 次 | 未執行 | 需要配對設備 |
| Double Tap / mic / haptic / TTS | 未實機驗收 | 不等同 Swift 型別檢查 |
| 本地繁中 STT | 未完成 | LocalTranscriber placeholder 明確拋出不可用錯誤 |
| ChatGPT OAuth / 真模型 | 未執行 | 遵守 mock 十次先行 |

## 重現說明

執行 `scripts/check_swift.sh`、`scripts/test_provider.sh`、`python scripts/check_boundaries.py` 與 `python -m pytest -q tests/test_server.py`。

本機 SwiftPM 預設 build 在 Documents 受 Finder metadata 影響簽章，改用暫存 scratch path 後 test bundle 編譯／link／簽章成功。
本機測試 runner 仍缺 XCTest runtime 搜尋路徑，曾報 0 tests；該輸出**不計為成功**。
最後使用 Xcode 的 `usr/bin/xctest`，搭配 `DYLD_FRAMEWORK_PATH=<Developer>/Platforms/MacOSX.platform/Developer/Library/Frameworks` 與 `DYLD_LIBRARY_PATH=<Developer>/Platforms/MacOSX.platform/Developer/usr/lib`，直接執行產出的 `AIWristCoreTests.xctest`：6 tests、0 failures。

正常已完成首次設定的 Xcode 環境應先使用 `swift test` 或 Xcode Test action。
Python 測試有 2 個上游 Starlette/httpx deprecation warnings，不影響 12 項結果。

GitHub 憑證缺少 workflow scope，新增 workflow 的推送遭拒；改保留 `scripts/ci.yml.example` 範本。未執行遠端 CI，不能宣稱 CI 已通過。要啟用時由有權限者將範本放至 `.github/workflows/ci.yml`。
