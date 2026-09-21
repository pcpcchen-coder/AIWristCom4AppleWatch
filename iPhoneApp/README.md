# iPhone Companion App

The iPhone companion is the runtime hub for AIWristCom.

## Xcode project shape

Create **one iOS app project with a Watch App companion target**, not a standalone Watch-only project.

Recommended targets:

```text
AIWristCom
├─ AIWristCompanion       (iOS target)
└─ AIWristWatch           (watchOS companion target)
```

Add:

```text
iPhoneApp/*
```

to the iOS target.

Add:

```text
WatchApp/*
```

to the Watch target.

## Communication

The Watch sends:

```text
{
  type: "query",
  request_id: "...",
  text: "...",
  locale: "zh-TW"
}
```

through `WCSession.sendMessage`.

The iPhone returns:

```text
{
  request_id: "...",
  reply: "..."
}
```

through the WatchConnectivity reply handler.

## Important

The iPhone app should activate `WCSession` as early as possible. The Watch's live message path is designed to wake the companion iOS app in the background.

## v0.1 provider screen

The iPhone UI currently stores:

- Gateway URL
- optional device token
- paired Watch status
- last Watch request
- last AI reply
- last error

The Gateway settings exist on the iPhone only.

The Watch must never contain the remote Gateway address or OAuth/token configuration.

## Current provider

`RemoteCodexProvider` is the first provider implementation.

It lets the iPhone call the existing Codex Gateway while preserving the correct Apple architecture:

```text
Watch
→ iPhone Companion
→ RemoteCodexProvider
→ Codex Gateway
→ ChatGPT OAuth
```

Later, replace `RemoteCodexProvider` without changing the Watch code.
