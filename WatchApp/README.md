# WatchApp Setup

此目錄是 AIWristCom 的 watchOS 11+ SwiftUI source scaffold。

## 已實作

- Double Tap primary action
- idle → listening
- listening → stop/send
- Traditional Chinese Speech-to-Text
- FastAPI Gateway client
- AI response display
- Traditional Chinese TTS
- haptic feedback
- busy-state Double Tap guard

## 建立 Xcode project

GitHub repo 保存 source code，但 Xcode project 仍建議用 Xcode 建立，避免手寫 project.pbxproj。

1. Xcode → File → New → Project
2. watchOS → App
3. Product Name：`AIWristCom`
4. Interface：SwiftUI
5. Language：Swift
6. Deployment Target：watchOS 11+
7. 將本目錄中的 Swift files 加入 Watch target

確認只有一個 `@main`：

```
AIWristComApp.swift
```

## Privacy keys

Target → Info 加入：

```text
Privacy - Microphone Usage Description
AIWristCom 需要使用麥克風接收你的語音問題。

Privacy - Speech Recognition Usage Description
AIWristCom 需要將你的語音轉換成文字後送給 AI。
```

## Gateway key

加入：

```text
AIWRIST_GATEWAY_URL
```

例如：

```text
https://YOUR-GATEWAY/
```

開發時若後端設了 `AIWRIST_DEVICE_TOKEN`，Watch 端也可暫時設定：

```
AIWRIST_DEVICE_TOKEN
```

正式版再改 Keychain/device registration。

## Double Tap

核心在：

```swift
.handGestureShortcut(
    .primaryAction,
    isEnabled: controller.primaryActionEnabled
)
```

不要自行寫 motion-sensor classifier。

詳細設計見：

```
docs/DOUBLE_TAP_DESIGN.md
```
