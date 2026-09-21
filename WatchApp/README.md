# Watch App

使用 repo 根目錄的 `AIWristCom.xcodeproj`，選 AIWristWatch scheme；它是 iPhone app 內嵌的 companion，不能建立 standalone Watch-only app。

保留 watchOS 11+ Double Tap primary action、錄音、UI、haptic、TTS 與 WCSession。
本地 STT 尚未接入；原有 SFSpeechRecognizer 不支援 Watch 已移除，不能把錄音誤認為辨識完成。

先使用「連線測試」完成真實 WCSession 固定文字往返十次。
詳細建置、權限與驗收見 [V0_1_ACCEPTANCE](../docs/V0_1_ACCEPTANCE.md)。
引擎評估見 [WATCH_LOCAL_STT_EVALUATION](../docs/WATCH_LOCAL_STT_EVALUATION.md)。
