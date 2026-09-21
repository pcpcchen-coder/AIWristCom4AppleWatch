# Architecture

## 1. System Boundary

Apple Watch 僅負責四件事：

1. Capture voice
2. Speech-to-text
3. Send request
4. Present / speak response

其他能力全部放在後端 Gateway。

## 2. Components

### WatchApp

#### ContentView
依 AppState 決定畫面。

#### AudioRecorder
處理 microphone permission、start、stop。

#### SpeechRecognizer
將語音轉成文字。

#### AgentClient
負責 HTTPS request、timeout、JSON decode。

#### SpeechOutput
把 reply 朗讀出來。

### Server

#### main.py
HTTP entry point。

#### router.py
根據 intent 決定要呼叫哪個 agent/provider。

#### providers/*
統一封裝不同 LLM。

Provider interface 建議：

```python
class LLMProvider:
    async def generate(self, text: str, context: dict | None = None) -> str:
        ...
```

## 3. API Versioning

API 一開始就使用：

```
/api/v1/query
```

未來 breaking change 才能開 /api/v2。

## 4. Timeouts

建議：

- Watch HTTP timeout: 30 s
- Gateway provider timeout: 25 s
- STT max utterance for MVP: 30 s

## 5. Logging

Server 每次 request 至少記：

```
timestamp
request_id
device
intent
provider
latency_ms
success
error_code
```

不要記 API key。

若要記完整 user query，請做成可關閉設定。

## 6. Future Streaming

MVP 不做 streaming。

之後可考慮：

```
Watch
  ↕ WebSocket
Gateway
  ↕ streaming provider API
```

但 watchOS 背景生命週期與網路中斷處理會複雜很多，所以不放在 v0.1。
