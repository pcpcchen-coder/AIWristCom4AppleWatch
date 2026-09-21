# Watch 本地繁中 STT 評估（2026-09-21）

使用者要求保留兩次 Double Tap，拒絕以系統聽寫替換。以下是來源核對與實作界面，並非實機效能報告。

## 可確認的事實

本機 Xcode 27 watchOS SDK 沒有 Speech.framework。原有 `import Speech` / `SFSpeechRecognizer` 不能編譯到 Watch。
Apple 的 [系統文字輸入](https://developer.apple.com/documentation/watchkit/wkinterfacecontroller/presenttextinputcontroller(withsuggestions:allowedinputmode:completion:)) 可使用聽寫，但由系統 modal 控制；不能保證第二次 Double Tap 仍呼叫 App 的停止按鈕。因此不採用。

| 路徑 | 核對結果 | v0.1 判斷 |
|---|---|---|
| WhisperKit / Core ML | 上游 Package.swift 明列 watchOS 10；提供 multilingual tiny | 優先候選，尚未在本機 cross-build 或 Watch 推論 |
| whisper.cpp | 上游 xcframework script 有 iOS/macOS/visionOS/tvOS，沒有 watchOS slice | 需另行移植／編譯，先不採用 |
| Apple SFSpeechRecognizer | Watch SDK 無此 framework | 不能使用 |
| 系統聽寫 | Watch 支援系統輸入畫面 | 不符合使用者保留兩次 Double Tap 的選擇 |

上游來源：

- [WhisperKit Package.swift，固定 revision ea872ffd](https://github.com/argmaxinc/WhisperKit/blob/ea872ffd35705aa757f33033500b9b0d40bd38df/Package.swift)
- [WhisperKit README，模型及預設下載說明](https://github.com/argmaxinc/WhisperKit/blob/ea872ffd35705aa757f33033500b9b0d40bd38df/README.md)
- [whisper.cpp build-xcframework.sh](https://github.com/ggml-org/whisper.cpp/blob/master/build-xcframework.sh)

## 建議的最小 spike（不是已完成）

1. 先取得使用者的 Watch 型號、OS、可用儲存空間；不同晶片不可代推效能。
2. Pin WhisperKit revision，僅 link WhisperKit product，先 cross-build watchOS 11 minimum deployment。
3. 使用 **multilingual tiny**，不是 English-only tiny.en。模型與 tokenizer 隨開發包打包，明確關閉自動下載；Watch 執行時只作本地推論，不能默默變成雲端 STT。
4. 以 repo 中 `LocalTranscriber.transcribe(file:locale:)` 接入：16 kHz mono PCM WAV；停止錄音後才辨識，不 streaming。
5. 以真實繁中 5/10/30 秒錄音、安靜／噪音條件、人工逐字稿計算 CER。Whisper 的 `zh` 不保證繁體輸出；需測試提示詞效果，必要時另選本地繁簡轉換工具並驗授權。
6. 記錄冷載入、暖辨識時間、峰值記憶體、10 次電量、發熱／OS 終止；建議初始目標 10 秒音訊在停止後 10 秒內完成，這是待驗收目標而非測量值。
7. 分別測試無網路辨識、取消、空白音訊、長句、模型缺檔／損毀；不允許失敗時偷偷把原始音訊送 iPhone／host。

若 tiny 在目標 Watch 無法達成可用性，回報實測數據再決策；不擅自把 STT 移到 iPhone。
本次沒有下載模型、增加依賴或消耗訂閱推論。麥克風錄製與 adapter 邊界已準備，缺引擎時回覆明確錯誤。
