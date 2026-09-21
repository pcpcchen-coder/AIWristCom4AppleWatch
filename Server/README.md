> 先完成 [Watch↔iPhone 固定回覆十次驗收](../docs/V0_1_ACCEPTANCE.md)，才啟用此 provider。後端測試用 fake 不代表 OAuth 或硬體驗收完成。

# v0.1 Backend — ChatGPT OAuth via Codex App Server

v0.1 不使用 OpenAI API key。

後端採用官方 Codex App Server，並用 ChatGPT OAuth / device-code flow 登入。登入憑證由 Codex 自己保存與更新，Apple Watch 不接觸 OAuth token。

## 架構

```text
Apple Watch
  ↓ WatchConnectivity
Paired iPhone Companion
  ↓ HTTPS JSON
FastAPI Gateway
  ↓ local stdio / JSON-RPC
codex app-server
  ↓ ChatGPT OAuth session
OpenAI model available to the signed-in ChatGPT/Codex account
```

## 這代表什麼

- 不需要另外購買 OpenAI API credits。
- 使用量計入 ChatGPT/Codex 方案的可用額度與 rate limits。
- 這不是一般 OpenAI Responses API；它走 Codex App Server。
- 可使用的模型要用 `model/list` 動態查詢，不能假設每個帳號都相同。
- v0.1 每一個 Watch query 都建立新的 Codex thread，不保留多輪上下文。

## 先決條件

1. 安裝官方 Codex CLI。
2. 確認：
   ```bash
   codex --version
   ```
3. Python 3.11+。

## 方法 A：先在 Terminal 登入（最簡單）

```bash
codex login
```

瀏覽器完成「使用 ChatGPT 登入」後：

```bash
codex login status
```

然後啟動 Gateway。

## 方法 B：使用本專案 device-code endpoint

啟動 Gateway 後：

```bash
curl -X POST http://127.0.0.1:8000/api/v1/auth/device/start
```

會得到：

```json
{
  "ok": true,
  "verification_url": "https://auth.openai.com/codex/device",
  "user_code": "ABCD-1234",
  "login_id": "..."
}
```

開啟 verification_url，輸入 user_code 並完成 ChatGPT 登入。

再確認：

```bash
curl http://127.0.0.1:8000/api/v1/auth/status
```

## 啟動 FastAPI

在 `Server/`：

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 127.0.0.1 --port 8000
```

Windows PowerShell 啟用 venv：

```powershell
.\.venv\Scripts\Activate.ps1
```

## 測試

健康檢查：

```bash
curl http://127.0.0.1:8000/health
```

模型詢問：

```bash
curl -X POST http://127.0.0.1:8000/api/v1/query \
  -H "Content-Type: application/json" \
  -d '{"text":"請用一句話介紹 BMS","device":"apple_watch","locale":"zh-TW"}'
```

預期：

```json
{
  "ok": true,
  "request_id": "req_...",
  "reply": "...",
  "intent": "general_chat",
  "speak": true,
  "provider": "codex_chatgpt_oauth",
  "model": "..."
}
```

## iPhone 對 provider 連線設定

開發初期可先只在 LAN 測試。

iPhone 連接 provider host 時：

- FastAPI 前面一定要放 HTTPS reverse proxy。
- 設定 `AIWRIST_DEVICE_TOKEN`。
- iPhone 以 `Authorization: Bearer <token>` 呼叫 Gateway。
- 不要把 `~/.codex/auth.json` 放進 repo、Log 或 Watch。
- 不要直接把 Codex App Server WebSocket 暴露到 Internet；v0.1 固定使用本機 stdio，由 FastAPI 包住。

## Rate limit

```bash
curl http://127.0.0.1:8000/api/v1/limits
```

這個 endpoint 回傳 ChatGPT/Codex account 的 rate-limit 狀態，可在未來 Watch UI 顯示剩餘狀態。

## v0.1 驗收

- [ ] `codex --version` 成功
- [ ] ChatGPT OAuth 登入成功
- [ ] `/api/v1/auth/status` 顯示 authenticated=true
- [ ] `/api/v1/query` 可回覆繁中
- [ ] 不需要 `OPENAI_API_KEY`
- [ ] API billing 未被使用
- [ ] rate-limit 用盡時後端可回明確錯誤，而不是 crash


## 建議：讓 Gateway 自動常駐

Double Tap 不應該依賴你每次先開 Terminal。

完成 venv 與 `codex login` 後：

```bash
chmod +x install_launchd.sh uninstall_launchd.sh
./install_launchd.sh
```

之後 macOS 登入時會自動啟動 Gateway，process 異常退出也會由 launchd 重新拉起。

詳細說明：

```
docs/MACOS_ALWAYS_ON_GATEWAY.md
```
