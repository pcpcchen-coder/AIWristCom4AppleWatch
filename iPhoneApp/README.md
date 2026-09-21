# iPhone Companion

iPhone 是 Watch 唯一近端 Hub。開啟根目錄 `AIWristCom.xcodeproj`，選 AIWristCompanion scheme。

預設固定回覆 provider；可選測試錯誤／逾時。請先用配對 Watch 完成十次往返，再勾選驗收聲明並切換 Remote Codex。
Provider URL 使用 HTTPS，token 明確儲存至 Keychain。OAuth 僅由 provider host 的 Codex 管理。

完整 [建置與實機驗收](../docs/V0_1_ACCEPTANCE.md)。
