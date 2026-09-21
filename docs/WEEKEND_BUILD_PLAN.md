# Weekend Build Plan

目標：一個週末做出 v0.1 可操作 MVP。

## Day 1 — Watch 端

### Step 1
建立 Xcode watchOS App。

驗收：
- simulator 可跑
- 實體 Watch 可跑

### Step 2
建立 AppState。

驗收：
- idle / listening / sending / speaking / error 可人工切換

### Step 3
完成 UI。

驗收：
- 五種狀態畫面都能顯示
- 小螢幕不爆版

### Step 4
完成語音輸入。

驗收：
- 中文 10 秒語音可轉文字
- 拒絕 microphone permission 時不 crash

## Day 2 — Backend + End-to-End

### Step 5
建立最小 HTTP Server。

先固定回覆，不接 AI。

驗收：

```bash
curl -X POST http://localhost:8000/api/v1/query \
  -H "Content-Type: application/json" \
  -d '{"text":"hello","device":"apple_watch","locale":"zh-TW"}'
```

回傳標準 JSON。

### Step 6
Watch 呼叫 Server。

驗收：
- Watch 送 text
- Server terminal 能看到 request
- Watch 顯示 reply

### Step 7
接第一個 LLM。

驗收：
- 使用者說「幫我用一句話介紹鋰電池 BMS」
- AI reply 正常回到 Watch

### Step 8
加 TTS。

驗收：
- reply 可從 Watch 喇叭朗讀

### Step 9
做失敗測試。

至少測：

1. 關 Server
2. 錯 URL
3. timeout
4. 空白輸入
5. API 回 500
6. 無網路

### Step 10
連續測 10 次。

只要完整流程連續 10 次成功，v0.1 即完成。

## 不要在第一個週末做

- Calendar
- FamilyRecorder
- Siri
- Complication
- 多 Agent
- streaming
- login system
- fancy animation

那些全部等 v0.1 Pass 後再加。
