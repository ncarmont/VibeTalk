<div align="center">

# 🎙️ VibeTalk

**Free, private, on-device voice dictation for macOS.**  
Press a hotkey from any app. Speak. Your words appear instantly.

[![Website](https://img.shields.io/badge/Website-vibe--talk.fun-8b5cf6?logo=safari&logoColor=white)](https://vibe-talk.fun/)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift&logoColor=white)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-Support%20this%20project-ff5f5f?logo=ko-fi&logoColor=white)](https://ko-fi.com/kiki_ai)

</div>

---

Stop typing your prompts. Press `fn+Space` from anywhere on your Mac, speak naturally, and your words are pasted instantly — **free, on-device, no subscription**.

No cloud. No API key. No usage limits. Ever.

---

## ✨ Features

| Feature | Details |
|---|---|
| **Global hotkey** | `fn+Space` or `Ctrl+Shift+Space` — works from any app |
| **Auto-paste** | Transcribed text lands directly in the focused text field |
| **11 languages** | English, Spanish, French, German, Japanese, Chinese, Portuguese, Italian, Korean, and more |
| **Screenshot paste** | `fn+i` to instantly paste your latest desktop screenshot |
| **Multiple AI engines** | Apple Speech, Whisper, NVIDIA Parakeet, Mistral Voxtral |
| **Floating pill UI** | Draggable, always-on-top — gets out of your way |
| **Recording history** | Review and re-paste previous dictations |
| **100% private** | Audio never leaves your machine |
| **Free forever** | No accounts, no limits, no telemetry |

---

## 🚀 Quick Start

1. **Download** `VibeTalk.zip` from [vibe-talk.fun](https://vibe-talk.fun/) or [build from source](#building-from-source)
2. **Move** `VibeTalk.app` to `/Applications`
3. **Launch** and grant permissions when prompted (Microphone, Speech Recognition, Accessibility, Input Monitoring)
4. **Click** into any text field in any app
5. **Press** `fn+Space`, speak, then press `fn+Space` again to paste

That's it. No setup, no account, no API key.

---

## 🤖 Speech Models

VibeTalk ships with multiple engines. Pick based on your tradeoff between speed, accuracy, and download size.

### Built-in (no download)

| Model | Language | Speed | Accuracy | Notes |
|---|---|---|---|---|
| **Apple Speech (On-Device)** | EN, ES, FR, DE, JA, ZH, PT, IT, KO | ⚡⚡⚡⚡⚡ | ★★★ | Live transcription, zero latency, 11 locales |
| **Apple Speech (Server)** | EN | ⚡⚡⚡⚡⚡ | ★★★★ | May use Apple's servers, better accuracy |

### Whisper.cpp (via Homebrew)

Install with: `brew install whisper-cpp`

| Model | Size | Speed | Accuracy | Best For |
|---|---|---|---|---|
| Whisper Tiny EN | 32 MB | ⚡⚡⚡⚡⚡ | ★★ | Ultra-fast, rougher accuracy |
| Whisper Base EN | 60 MB | ⚡⚡⚡⚡ | ★★★ | Best small English balance |
| Whisper Small EN | 190 MB | ⚡⚡⚡ | ★★★★ | Accurate, still light |
| Whisper Medium EN | 539 MB | ⚡⚡⚡ | ★★★★ | Strong English before Large |
| Whisper Medium (Multilingual) | 539 MB | ⚡⚡⚡ | ★★★★ | Balanced multilingual |
| **Whisper Large-v3 Turbo** | 574 MB | ⚡⚡⚡ | ★★★★★ | Latest fast flagship |
| Whisper Large-v2 | 1.08 GB | ⚡⚡ | ★★★★★ | Max accuracy |
| Whisper Large-v3 | 1.08 GB | ⚡⚡ | ★★★★★ | Max accuracy, multilingual |

### NVIDIA Parakeet (via Homebrew)

Install with: `brew install lucataco/tap/parakeet-cli`

| Model | Size | Speed | Accuracy | Notes |
|---|---|---|---|---|
| **Parakeet TDT 0.6B INT8** | 670 MB | ⚡⚡⚡⚡ | ★★★★★ | State-of-the-art English WER |
| Parakeet TDT 0.6B FP16 | 1.3 GB | ⚡⚡⚡ | ★★★★★ | Highest local quality |

### Mistral Voxtral MLX

Install with: `uv tool install voxmlx`

| Model | Size | Speed | Accuracy | Notes |
|---|---|---|---|---|
| **Voxtral Mini 4B (6-bit)** | 3.62 GB | ⚡⚡⚡ | ★★★★★ | Realtime-capable MLX, multilingual |

---

## 🛠 Building from Source

### Prerequisites

- macOS 13 Ventura or later (Apple Silicon or Intel)
- Xcode Command Line Tools

```bash
xcode-select --install
```

### Build the macOS App

```bash
git clone https://github.com/your-username/vibetalk.git
cd vibetalk/macos-app
bash build.sh
open build/VibeTalk.app
```

### Build the Website (optional)

```bash
cd vibetalk
npm install
npm run dev      # http://localhost:3000
npm run build    # Static export to out/
```

---

## 🔐 Permissions

VibeTalk requires four macOS permissions to function fully:

| Permission | Why | Where to grant |
|---|---|---|
| **Microphone** | Record your voice | System Settings → Privacy → Microphone |
| **Speech Recognition** | Transcribe with Apple's framework | System Settings → Privacy → Speech Recognition |
| **Accessibility** | Create a global keyboard event tap | System Settings → Privacy → Accessibility |
| **Input Monitoring** | Global hotkey fallback monitors | System Settings → Privacy → Input Monitoring |

> **Tip:** If `fn+Space` doesn't work from other apps, open VibeTalk Settings and check the **Input Monitoring** row — this is the most common reason global hotkeys fail on macOS Ventura+.

---

## 🏗 Tech Stack

**macOS App**
- Swift 5, Cocoa, AppKit
- `AVFoundation` — audio capture
- `Speech` framework — Apple on-device ASR
- `CGEvent` tap + `NSEvent` monitors — global hotkeys
- whisper.cpp, parakeet-cli, voxmlx — external model runtimes

**Website**
- Next.js 15, React 19, TypeScript
- Tailwind CSS
- Static export (zero server)

---

## 📁 Project Structure

```
vibetalk/
├── macos-app/
│   ├── Sources/            # Swift app source
│   │   ├── AppDelegate.swift
│   │   ├── HotkeyManager.swift
│   │   ├── TranscriptionEngine.swift
│   │   ├── TranscriptionModels.swift
│   │   ├── PillWindowController.swift
│   │   ├── MainWindowController.swift
│   │   └── ...
│   ├── build.sh            # Build script (ad-hoc signed)
│   ├── Info.plist
│   └── Entitlements.plist
├── src/app/                # Next.js website
│   ├── page.tsx
│   └── ...
└── public/                 # Static assets
```

---

## ☕ Support

VibeTalk is free and always will be. If it's saved you from typing, consider buying me a coffee — it helps keep the project alive.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/kiki_ai)

---

## 📄 License

MIT — see [LICENSE](LICENSE) for details.

---

<div align="center">

Made with ♥ for people who think faster than they type.

</div>
