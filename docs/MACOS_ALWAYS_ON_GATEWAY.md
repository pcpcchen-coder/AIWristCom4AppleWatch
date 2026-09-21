# Optional Codex Host on macOS

> 此文件不是 Apple Watch ↔ iPhone 架構的一部分。
>
> 正確近端資料路徑永遠是：
>
> ```text
> Apple Watch → paired iPhone Companion
> ```
>
> 本文件只描述「如果 v0.1 想利用 ChatGPT/Codex OAuth 而不走 API billing」，可以暫時讓 Mac 擔任 **RemoteCodexProvider 的 host**。

## 為什麼需要

Apple Watch Double Tap 只能啟動 Watch App 當前畫面的 primary action。

如果 FastAPI/Codex backend 根本沒有執行：

```text
Double Tap
→ Watch records / local STT
→ WCSession to iPhone
→ iPhone POST Gateway
→ connection failed
```

因此 v0.1 的使用體驗設計是：

```text
Mac login
→ launchd 自動啟動 FastAPI + Codex App Server
→ 平常不用人工啟動後端

Apple Watch
→ iPhone Companion
→ HTTPS to optional Mac Codex host
→ reply to iPhone
→ reply to Watch
```

## 安裝

先完成：

```bash
cd Server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
codex login
```

然後：

```bash
chmod +x install_launchd.sh uninstall_launchd.sh
./install_launchd.sh
```

確認：

```bash
curl http://127.0.0.1:8000/health
```

## launchd 行為

設定：

```text
RunAtLoad = true
KeepAlive = true
```

代表：

- 登入 macOS 後自動啟動。
- Gateway 意外退出時 launchd 會重新拉起。
- 不需要每次使用 Apple Watch 前手動開 Terminal。

## Log

```text
~/Library/Logs/AIWristCom.gateway.log
~/Library/Logs/AIWristCom.gateway.error.log
```

## 移除

```bash
cd Server
./uninstall_launchd.sh
```

## 注意

這不是遠端 Wake-on-LAN。

如果 Mac：

- 關機
- 深度睡眠且網路不可達
- 不在 iPhone 能連到的網路

iPhone 將無法存取 provider，並透過 WCSession 回覆 Watch 錯誤。

v0.1 建議先在同一個 Wi-Fi/LAN 完成測試。

iPhone 連 provider 必須使用受控的 HTTPS endpoint；Watch 仍只使用 WCSession，不支援直接經 cellular 連 Gateway。
