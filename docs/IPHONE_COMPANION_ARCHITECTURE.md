# iPhone-Centered Architecture

## 1. Correct system boundary

AIWristCom is an Apple Watch + iPhone companion system.

The Apple Watch is **not** responsible for Internet LLM access.

The paired iPhone is the runtime hub:

```text
Apple Watch
  ├─ Double Tap
  ├─ microphone / Speech-to-Text
  └─ WatchConnectivity
        ↓
Paired iPhone Companion
  ├─ receives Watch request
  ├─ wakes in background for immediate message
  ├─ selects LLM provider
  ├─ performs network/auth work
  └─ returns reply
        ↓
Apple Watch
  ├─ display
  └─ TTS
```

Apple's `WCSession` is specifically the communication object between a Watch app and its companion iOS app.

For interactive voice requests, the Watch uses:

```swift
WCSession.default.sendMessage(...)
```

When the Watch app is active, this immediate message can wake the corresponding iOS app in the background so it can process the request and reply.

## 2. v0.1 data flow

```text
Double Tap #1
  ↓
Watch starts listening
  ↓
Double Tap #2
  ↓
Watch STT produces text
  ↓
WCSession.sendMessage
  ↓
iPhone companion wakes
  ↓
CompanionLLMRouter
  ↓
configured provider
  ↓
replyHandler
  ↓
Watch displays + speaks answer
```

The Watch never stores:

- LLM API keys
- ChatGPT OAuth tokens
- server credentials
- remote provider configuration

## 3. ChatGPT OAuth limitation

The desired goal is:

```text
Watch + iPhone only
+ ChatGPT account subscription
+ no API billing
```

At present, OpenAI documents ChatGPT subscription authentication for Codex clients / Codex App Server.

OpenAI also documents an experimental `chatgptAuthTokens` mode for host applications that already manage a user's ChatGPT authentication lifecycle.

However, there is no documented general-purpose public iOS SDK that allows an arbitrary third-party iPhone app to sign in to ChatGPT and directly consume ChatGPT subscription inference as an embedded LLM API.

Therefore v0.1 must distinguish two layers:

### Near-device architecture

This is fixed:

```text
Watch → iPhone
```

### LLM provider

This is replaceable:

```text
iPhone
  ├─ Remote Codex Host      ← current ChatGPT OAuth route
  ├─ OpenAI API             ← optional paid route
  ├─ Local/on-device model  ← future no-API route
  └─ other provider
```

## 4. Current ChatGPT OAuth route

For the current no-extra-API-billing experiment:

```text
Apple Watch
  ↓ WatchConnectivity
iPhone Companion
  ↓ HTTPS
Codex Gateway Host
  ↓ local Codex App Server
  ↓ ChatGPT managed OAuth
OpenAI model
```

The Codex host can be:

- development Mac
- always-on home machine
- compatible Linux host
- another controlled server environment

The important correction is that the **Watch does not know or care where that host is**.

Only the iPhone companion knows the provider endpoint.

## 5. Why the Mac is no longer part of the Watch architecture

Wrong:

```text
Watch → Mac → LLM
```

Correct:

```text
Watch → iPhone → LLM provider
```

A Mac may temporarily implement one provider because Codex App Server currently needs an environment where the Codex runtime can run.

It is not the Watch's paired runtime and is not part of WatchConnectivity.

## 6. Interactive transport choice

For a live voice question, use:

```swift
sendMessage(_:replyHandler:errorHandler:)
```

Do not use `transferUserInfo` for the normal request path because background transfers are opportunistic and not guaranteed to be immediate.

`transferUserInfo` can be added later for non-interactive queued tasks.

## 7. iPhone responsibilities

The companion app owns:

- Watch session activation
- Watch reachability / pairing status
- LLM provider selection
- provider URL
- provider credentials
- ChatGPT/Codex gateway communication
- future local-model routing
- future Calendar / Home / FamilyRecorder actions
- diagnostics and usage status

This makes the iPhone the natural Agent Router.

## 8. Watch responsibilities

The Watch owns only:

- Double Tap UI
- microphone permission
- speech recognition
- display state
- WatchConnectivity request/reply
- haptic feedback
- TTS

Keep it thin.

## 9. Failure behavior

### iPhone unavailable

Watch displays:

```text
找不到 iPhone
請確認手機在附近並已開啟 Companion
```

### iPhone available but provider unavailable

iPhone returns a structured error to Watch.

### provider timeout

iPhone stops waiting and returns:

```text
AI 服務暫時沒有回應
```

Watch returns to idle after presenting the error.

## 10. Next architecture milestone

After WatchConnectivity works reliably, choose one of these provider paths:

### Path A — keep ChatGPT subscription

```text
iPhone → remote Codex host → ChatGPT OAuth
```

No OpenAI API billing, but requires a Codex-capable host.

### Path B — Watch + iPhone only

```text
iPhone → on-device model
```

No external host and no API billing, but the model is not ChatGPT.

### Path C — pure cloud API

```text
iPhone → your HTTPS backend → OpenAI API
```

Simplest commercial architecture, but uses API billing.

The Watch/iPhone protocol remains identical whichever provider is chosen.
