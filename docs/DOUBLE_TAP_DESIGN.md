# Apple Watch Double Tap Design

## 1. 目標

AIWristCom v0.1 將 Apple Watch 的官方 Double Tap 手勢設為語音互動的 primary action。

使用流程：

```text
AIWristCom 畫面在前景
        ↓
拇指 + 食指 Double Tap
        ↓
開始錄音 / STT
        ↓
使用者說話
        ↓
再次 Double Tap
        ↓
停止錄音
        ↓
Speech-to-Text
        ↓
FastAPI Gateway
        ↓
Codex App Server + ChatGPT OAuth
        ↓
AI answer
        ↓
Apple Watch 顯示 + 朗讀
```

## 2. Apple 官方 API

watchOS 11+：

```swift
Button {
    controller.handlePrimaryAction()
} label: {
    Label("開始說話", systemImage: "mic.fill")
}
.handGestureShortcut(
    .primaryAction,
    isEnabled: controller.primaryActionEnabled
)
```

Double Tap 由系統辨識，不需要自行讀取 accelerometer 或建立手勢分類器。

## 3. 很重要的系統限制

Double Tap **不是第三方 App 的 global hotkey**。

也就是：

```text
Watch Face
   ↓ Double Tap
X 不能由 AIWristCom 全域攔截並直接開啟麥克風
```

Apple 的 primary-action Double Tap 只有在：

1. App scene 已經在前景。
2. 被指定為 primary action 的 buttonlike control 在螢幕上。

才會觸發該 control。

因此 v0.1 不承諾：

```text
在任何畫面 Double Tap → 自動 launch AIWristCom → 開始錄音
```

## 4. 我們的狀態設計

### idle

Primary action：

```text
Double Tap → Start Listening
```

### listening

同一個 Button 改成：

```text
Double Tap → Stop + Send
```

### transcribing

```text
Double Tap disabled
```

### sending

```text
Double Tap disabled
```

### speaking

```text
Double Tap disabled
```

### error

顯示一般「重設」按鈕，但不把 error recovery 設為 Double Tap primary action。

原因：避免使用者在錯誤訊息還沒看清楚時誤觸。

## 5. 為什麼主頁不用 ScrollView

Apple 對 Double Tap 有預設行為：

1. primary action
2. ScrollView/List scrolling
3. vertical tab pagination

Apple HIG 也建議，不要在主要依靠 ScrollView/List 的畫面同時塞入會造成衝突的 primary action。

因此 voice main scene 刻意設計成：

```text
VStack
  ├─ Status
  ├─ transcript / reply preview
  └─ Primary Button
```

不使用 ScrollView。

較長的 conversation/history 之後放到另一個非 voice-primary scene。

## 6. Haptic feedback

使用者不用一直看螢幕也可以知道目前狀態：

```text
Double Tap #1
  → .start haptic
  → listening

Double Tap #2
  → .click haptic
  → stop/send

AI reply ready
  → .success haptic

Error
  → .failure haptic
```

## 7. Xcode Target

建議：

```text
Deployment Target: watchOS 11.0+
```

Double Tap primary-action API 由 watchOS 11 正式提供給第三方 App。

硬體也必須支援 Apple Watch Double Tap，而且使用者需在系統設定中啟用 Double Tap。

## 8. Required privacy descriptions

Watch target 的 Info 設定至少加入：

```text
Privacy - Microphone Usage Description
NSMicrophoneUsageDescription

用途：
「AIWristCom 需要使用麥克風接收你的語音問題。」

Privacy - Speech Recognition Usage Description
NSSpeechRecognitionUsageDescription

用途：
「AIWristCom 需要將你的語音轉換成文字後送給 AI。」
```

若缺少 microphone usage description，系統可能直接終止 App。

## 9. Gateway configuration

Watch target 增加 custom Info key：

```text
AIWRIST_GATEWAY_URL
```

例如：

```text
https://aiwrist.example.com/
```

開發 LAN 測試可以先使用可從 Watch 存取的 Mac LAN address，但正式版應使用 HTTPS。

可選：

```text
AIWRIST_DEVICE_TOKEN
```

僅作個人 MVP 使用。

正式產品不要把長期 bearer secret 當成不可抽取的祕密放在 App bundle；後續應改成 device registration + Keychain credential。

## 10. 實體驗收

### Test DT-01 — Start

Given：

```text
App = foreground
State = idle
Double Tap enabled
```

When：

```text
Double Tap
```

Then：

```text
state = listening
.start haptic
mic active
UI shows waveform
```

### Test DT-02 — Stop and send

Given：

```text
state = listening
user already spoke
```

When：

```text
Double Tap
```

Then：

```text
state = transcribing
→ sending
→ speaking
```

### Test DT-03 — Busy guard

Given：

```text
state = sending
```

When：

```text
Double Tap
```

Then：

```text
No second request is created.
```

### Test DT-04 — Same behavior as screen tap

Physical screen tap and Double Tap must call exactly the same function:

```swift
controller.handlePrimaryAction()
```

不能維護兩套 interaction logic。

### Test DT-05 — 10-cycle test

連續完成十次：

```text
Double Tap
→ Speak
→ Double Tap
→ AI reply
→ TTS
→ idle
```

全部成功才算 Double Tap v0.1 Pass。

## 11. 從 Watch Face 更快進入的下一階段

因為 global Double Tap 不開放，後續可做三條快速入口。

### A. Complication

```text
Watch Face
→ tap AIWrist complication
→ AIWristCom foreground
→ Double Tap
→ talk
```

這會是最實用的下一步。

### B. Smart Stack Widget

watchOS 11 的 Widget/Live Activity 也能指定 primary action。

可以用來把 AIWristCom 的入口放進 Smart Stack。

注意：背景 Widget action 不應直接偷偷啟動 microphone；語音錄音仍應切到前景 App 並清楚顯示 recording state。

### C. Apple Watch Ultra Action Button

若使用 Ultra，也可另外用 App Intent 把 Action Button 配成 AIWristCom 快速入口。

這是 Double Tap 之外的補充，不影響目前架構。
