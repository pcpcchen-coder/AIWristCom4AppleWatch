# v0.1 建置與驗收

目前是可供驗收的工程版本，**尚非已通過實機驗收的 v0.1**。

2026-09-21 使用者選擇保留兩次 Double Tap，另評估 Watch 本地 STT；不改系統聽寫。
Watch 不得直接 HTTP 連 Gateway。第一階段先驗收固定文字往返，完成前不啟用真實 LLM。

## 已完成的工程內容

- 已提交可直接開啟的 `AIWristCom.xcodeproj`；iOS 18+ app 嵌入 watchOS 11+ companion app。
- `project.yml` 可由 XcodeGen 重建，Shared 純文字協定同時編入兩端，沒有網路 provider。
- Watch 主按鈕只在 idle/listening 啟用 Double Tap；preparing 防止權限提示期間重入。
- Watch 真實麥克風錄製本機 16 kHz mono PCM，第二次 Double Tap 停止；30 秒上限；背景時取消／刪除暫存音檔。
- **錄音不等於 STT**：目前 LocalTranscriber 明確回覆「尚未接入」，不捏造逐字稿，也不轉送音訊到 iPhone。
- 獨立「連線測試」按鈕使用 WCSession 發固定文字，Watch 收到正確固定回覆才累計。
- iPhone 預設 mock provider；同協定可測 error / timeout；RemoteCodexProvider 須先手動確認十次往返驗收。
- Watch 30 秒、iPhone 27 秒、HTTP 25 秒、後端完整 query 20 秒的期限；背景到期取消並只回覆一次。
- Request UUID / 空白 / 字數 / locale 檢查；Watch 核對 success 與 error 的 request_id。
- iPhone 換錶重新 activate；已儲存 device token 使用 Keychain；不保存 OAuth token。
- Swift core unit tests、Python fake-backed HTTP smoke/unit tests、架構檢查、GitHub Actions 範本（尚未啟用）。

## 建置

1. 在 Xcode 完成初次設定、授權條款及 iOS/watchOS SDK 安裝。本次主機 Xcode 27.0 的 `xcodebuild` 回報授權尚未同意；需由使用者閱讀並同意，代理未代為接受。
2. 開啟 `AIWristCom.xcodeproj`，不需先安裝 XcodeGen。若要重建才執行 `xcodegen generate`。
3. 複製 `Config/Local.xcconfig.example` 為 `Config/Local.xcconfig`，填入開發 Team ID 與唯一 `AIWRIST_BUNDLE_ID`。本地檔不提交。
4. 兩端共用 Base.xcconfig，Watch bundle ID 自動為 iPhone ID 加 `.watchkitapp`。不要只改其中一端。
5. 選 AIWristCompanion scheme，先安裝到已配對的 iPhone；再選 AIWristWatch scheme 安裝到該 Watch。兩端需開發者模式及同一簽署團隊。
6. 先開 iPhone Companion，確認 Active、Paired、Installed。Provider 保持「固定回覆」。

模擬器無簽章建置：

```sh
xcodebuild -project AIWristCom.xcodeproj -scheme AIWristCompanion -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project AIWristCom.xcodeproj -scheme AIWristWatch -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO build
swift test
scripts/test_provider.sh
python3 -m venv .venv
.venv/bin/pip install -r Server/requirements.txt pytest httpx
.venv/bin/python -m pytest -q tests/test_server.py
.venv/bin/python scripts/check_boundaries.py
```

`swift test` 只測 Shared 協定、router 與 continuation 防護，不模擬 WCSession。
`scripts/check_swift.sh` 用安裝的 SDK 做 Swift 6 warnings-as-errors 型別檢查，不等於完整 build/link/sign/install。

## 權限 / Info.plist

- Watch: `WKApplication=true`、`WKCompanionAppBundleIdentifier` 對應 iPhone、`WKRunsIndependentlyOfCompanionApp=false`。
- Watch: `NSMicrophoneUsageDescription` 已提供；首次錄音需授權。
- 不使用 Speech.framework，故目前不要求 `NSSpeechRecognitionUsageDescription`；若將來採其他有此需求的引擎再加。
- iPhone: `NSLocalNetworkUsageDescription` 已提供（開發期 host 在區網時）；僅 HTTPS provider，沒有全域 ATS 例外。
- WCSession 無需 App Groups 或自訂 entitlement；本版沒有 background audio / perpetual execution 權限。
- iPhone `beginBackgroundTask` 僅盡力延長時間，不能保證 OS 給足 27 秒；到期有明確錯誤。

## 第一階段：真正 Watch → iPhone → Watch 十次

先不開 Gateway、不登入／呼叫 LLM。以下每次都必須看到 Watch 的固定回覆與 TTS，並回到 idle。

1. iPhone provider 選「固定回覆」。
2. Watch 在前景，按「連線測試」，預期回覆「iPhone 已收到你的訊息」。
3. 等待朗讀結束再做下一次。Watch 計數只在固定回覆匹配時增加，失敗或 Watch 進背景歸零。
4. 第 1–5 次 iPhone 前景；第 6–10 次將 iPhone 回主畫面／鎖定，驗證背景喚醒。不要刻意 force-quit iPhone app 當正常條件。
5. 任一次失敗，修復後從 1 重來。iPhone 送出計數不能證明 Watch 已收到。

| 次數 | Watch 顯示正確 | TTS/回 idle | iPhone 前景或鎖定 | 耗時 | 結果 |
|---|---|---|---|---|---|
| 1 | 待測 | 待測 | 前景 | — | 未執行 |
| 2 | 待測 | 待測 | 前景 | — | 未執行 |
| 3 | 待測 | 待測 | 前景 | — | 未執行 |
| 4 | 待測 | 待測 | 前景 | — | 未執行 |
| 5 | 待測 | 待測 | 前景 | — | 未執行 |
| 6 | 待測 | 待測 | 背景／鎖定 | — | 未執行 |
| 7 | 待測 | 待測 | 背景／鎖定 | — | 未執行 |
| 8 | 待測 | 待測 | 背景／鎖定 | — | 未執行 |
| 9 | 待測 | 待測 | 背景／鎖定 | — | 未執行 |
| 10 | 待測 | 待測 | 背景／鎖定 | — | 未執行 |

記錄 iPhone/Watch 型號、OS、commit、日期、測試者。此表未填即未驗收。

## 第二階段：兩次 Double Tap / 本地 STT

- [ ] 支援 Double Tap 的實體 Watch，在系統設定啟用；App 與主按鈕在前景。
- [ ] 第一次手勢開始錄音／start haptic，第二次停止／click haptic；快速連點不得啟動第二段錄音。
- [ ] 權限拒絕、沒有聲音、音訊中斷、30 秒上限、切背景均不 crash 或持續錄音。
- [ ] **目前第二次停止後會顯示 STT 引擎尚未接入；這是阻擋項，不算語音流程通過。**
- [ ] 依 `WATCH_LOCAL_STT_EVALUATION.md` 選引擎與模型，注入 `LocalTranscriber`。
- [ ] 繁中人工參考逐字稿、效能、記憶體、電量與十次連續運作通過。

## 第三階段：LLM（第一階段通過後才做）

1. iPhone 勾選已在 Watch 確認十次，選 Remote Codex。此為使用者驗收聲明，不是自動認證；每次重啟預設 mock。
2. 在受控 provider host 建立 Python 環境、設定 `AIWRIST_DEVICE_TOKEN`、以 ChatGPT 登入 Codex。不要設定 OPENAI_API_KEY。
3. Gateway 僅在 iPhone 後方。iPhone 設定 HTTPS base URL 與 token，按儲存至鑰匙圈；Watch 不接觸這些資訊。
4. 完成 auth/status、limits、HTTP smoke。再使用已接入的本地 STT 跑完整語音流程十次。
5. 訂閱用量／OAuth 實測尚未執行；本版沒有用付費 API 替代。

## 故障驗收

- [ ] 未安裝 Companion、未 activated、iPhone 不可達，各有可恢復錯誤。
- [ ] mockError 回傳錯誤；mockTimeout 約 27 秒回錯誤，Watch 最長等待 30 秒；重設後 mock 成功。
- [ ] busy 狀態連按／Double Tap 不會建立新請求。
- [ ] 401、429、500、504、不合法 JSON、ok=false、空回覆處理。
- [ ] TTS 音訊路由／繁中 voice／45 秒 watchdog／再播放。
- [ ] 換錶、iPhone 背景到期、Watch 背景取消、晚到 callback 不污染下一次 UI。

## 已知限制與下一個最小項目

完整 v0.1 尚未完成：缺本地 STT、完整 Xcode build/sign、硬體十次往返與 OAuth 實測。
下一個最小工作是完成 Xcode 首次設定，在配對設備執行上述固定回覆十次；之後進行 multilingual tiny 的 Watch STT 實機 spike。
Calendar、FamilyRecorder、Home Assistant、Siri、Complication、多 Agent、streaming 均未擴充。
