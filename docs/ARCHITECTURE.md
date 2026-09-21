# Architecture

## 1. System Boundary

AIWristCom v0.1 是 **Apple Watch + paired iPhone companion** 架構。

```text
Apple Watch
  ↓ WatchConnectivity
iPhone Companion
  ↓ replaceable LLM provider
LLM
```

Watch 不直接連 Internet LLM endpoint，也不保存遠端 provider credentials。

## 2. Watch responsibilities

- Double Tap primary action
- microphone / Traditional Chinese STT
- UI state machine
- WatchConnectivity request/reply
- haptic feedback
- TTS

Watch 使用 `WCSession.sendMessage` 對配對 iPhone 發立即訊息。

## 3. iPhone responsibilities

- activate `WCSession`
- receive Watch requests
- run in background long enough to handle the live request
- own provider settings
- route requests through `CompanionLLMRouter`
- return AI reply through WatchConnectivity reply handler
- future Calendar / Home / FamilyRecorder agent actions

## 4. LLM provider boundary

The iPhone owns the provider interface.

Current v0.1:

```text
iPhone
  ↓ HTTPS
Codex Gateway Host
  ↓ stdio
codex app-server
  ↓ ChatGPT managed OAuth
OpenAI model
```

The Codex host is **not** the Watch hub.

It is only one provider implementation because current ChatGPT-subscription OAuth is documented around Codex clients/App Server.

Future provider implementations can replace it without changing Watch code.

## 5. WatchConnectivity transport

Interactive voice request:

```swift
sendMessage(_:replyHandler:errorHandler:)
```

Background queued/non-interactive work can later use `transferUserInfo`.

## 6. API boundary

The existing FastAPI Gateway remains useful only behind the iPhone:

```text
Watch
  X  no direct HTTP
  ↓
iPhone
  ↓ HTTPS
FastAPI Gateway
```

## 7. Authentication boundary

Watch:

```text
No OAuth token
No API key
No Gateway URL
```

iPhone:

```text
Provider URL
Device credential
Provider selection
```

Codex host:

```text
ChatGPT OAuth session
Codex App Server
```

## 8. Timeout budget

Recommended:

- Watch → iPhone message request: interactive
- iPhone provider timeout: 30 s
- Watch STT utterance: 30 s max for MVP

## 9. Failure modes

### Watch cannot reach iPhone

Return a local Watch error immediately.

### iPhone cannot reach provider

iPhone returns an error through the same WatchConnectivity reply handler.

### Provider auth expired

Provider returns auth-required; iPhone UI owns remediation.

## 10. Reference docs

- `docs/IPHONE_COMPANION_ARCHITECTURE.md`
- `docs/DOUBLE_TAP_DESIGN.md`
- `docs/CHATGPT_OAUTH_BACKEND.md`
