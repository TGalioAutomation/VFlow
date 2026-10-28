# VFlow v1.0.0 — Official Production Release Notes

**Release Date:** October 28, 2026  
**Version:** `1.0.0` (Build 1)  
**Target Platform:** macOS 14.0+ (Sonoma, Sequoia, Tahoe) — Apple Silicon (`arm64`)  
**Repository:** [https://github.com/TGalioAutomation/VFlow](https://github.com/TGalioAutomation/VFlow)  
**Official Release:** [https://github.com/TGalioAutomation/VFlow/releases/tag/v1.0.0](https://github.com/TGalioAutomation/VFlow/releases/tag/v1.0.0)

---

## 🚀 Executive Summary

We are thrilled to announce the general availability of **VFlow v1.0.0**, the flagship native macOS bilingual Vietnamese-English typing engine, context-aware 3-tier suggestion assistant, and push-to-talk voice dictation platform.

Designed from the ground up in **Swift 6** exclusively for Apple Silicon, VFlow eliminates the age-old frustrations of Vietnamese typing on macOS: diacritic conflicts with English words, key swallowing in browsers, lagging UI, and intrusive cloud telemetry. VFlow operates with sub-2-millisecond latency, zero third-party dependencies, an ultra-smooth 120fps live Caret HUD pill, and a 100% on-device AI architecture.

---

## 📦 Distributable Packages & Downloads

| Package Name | Architecture | File Size | Direct Download Link |
|---|---|---|---|
| **VFlow-v1.0.0-macOS-arm64.dmg** | Apple Silicon (`arm64`) | ~4.7 MB | [Download DMG](https://github.com/TGalioAutomation/VFlow/releases/download/v1.0.0/VFlow-v1.0.0-macOS-arm64.dmg) |
| **VFlow-v1.0.0-macOS-arm64.zip** | Apple Silicon (`arm64`) | ~4.2 MB | [Download ZIP](https://github.com/TGalioAutomation/VFlow/releases/download/v1.0.0/VFlow-v1.0.0-macOS-arm64.zip) |
| **SHA256SUMS.txt** | All Packages | 190 B | [Download Checksums](https://github.com/TGalioAutomation/VFlow/releases/download/v1.0.0/SHA256SUMS.txt) |

---

## 🔒 SHA-256 Verification Guide

Before installing, verify the integrity of your downloaded release binaries using standard macOS command line tools:

```bash
# 1. Open Terminal and navigate to your download directory:
cd ~/Downloads

# 2. Check SHA-256 hash against the official signature:
shasum -a 256 VFlow-v1.0.0-macOS-arm64.dmg
shasum -a 256 VFlow-v1.0.0-macOS-arm64.zip

# Or verify automatically with SHA256SUMS.txt:
shasum -a 256 -c SHA256SUMS.txt
```

### Verified SHA-256 Checksums
```text
e4fa6e44f0a62b30e416b96ca8c19c4aaad5dcfac01bc3e6290b16d1d0c251e7  VFlow-v1.0.0-macOS-arm64.dmg
4aac3a5d92122055ba1fe5bebfd63adca84aab173bdbff3a1cc6d4d3922f2038  VFlow-v1.0.0-macOS-arm64.zip
```

---

## 🌟 What's New in v1.0.0

### 1. Bilingual Auto-Escape Engine (`VFlowCore`)
- **Smart English Collision Prevention**: No more mangled code or accidental diacritics. Words like `ary` (`salary`), `arrow`, `error`, `carry`, `sorry`, `current`, `class`, `subclass`, `import`, `service`, `const`, `diff`, `off` are automatically detected and preserved.
- **Full Telex & VNI Modes**: High-precision finite state machine supporting both Telex and VNI input conventions with instant mode toggling (`⌥Z`).
- **Free-Order Keystroke Tone Placement**: Type tones anywhere in the word (`vieest` or `toasn`); VFlow normalizes the diacritics correctly without false reversion.
- **Orthographic Accuracy**: Strict implementation of Vietnamese vowel and tone placement laws (e.g. `thuở`, `huơ`, `khuỷu`, `quyết`, `toán`).
- **Instant Tone Removal**: Clear tone marks instantly with `z` (Telex) or `0` (VNI) even after backspacing into a word.

### 2. 3-Tier Contextual Suggestion HUD (`VFlowUI`)
- **`⚡` Tier 1: Instant Diacritics & Teencode Shorthand**:
  - Restores full accents on unsigned words on word boundary.
  - Automatically expands abbreviations: `ko` → `không`, `dc`/`đc` → `được`, `trc` → `trước`, `ntn` → `như thế nào`, `mn` → `mọi người`.
  - Accept with `⇥ Tab` or `⌥1`.
- **`✨` Tier 2: On-Device AI Typo & Grammar Polish**:
  - Contextual typo resolution: detects pronouns before verbs (`"to đang"` → `"tôi đang"`), fixes bigram typo pairs (`"không cau"` → `"không dấu"`, `"thaat sư"` → `"thật sự"`).
  - Cleans verbal filler words (*"à"*, *"ừm"*, *"thì là mà"*).
  - Style re-phrasing across 3 tones: **Natural**, **Polite**, and **Concise**.
  - Accept with `⌥2`.
- **`🔮` Tier 3: Next-Word Prediction**:
  - N-gram Vietnamese collocation prediction anticipating your next thought.
  - Accept with `⌥3`.

### 3. 🫧 120fps Floating Caret HUD (Prototype v8 Liquid Glass)
- **Ultra-low latency AppKit floating panel**: Height `40px`, non-activating (`.nonActivatingPanel`), zero focus-stealing.
- **Smooth 120fps Silk Sine-Wave Canvas**: Real-time rendering of two-layer Cyan (`#38BDF8`) & Violet (`#A855F7`) silk wave.
- **Smart Cursor Tethering**: Follows caret bounds across all macOS applications via Accessibility APIs with dynamic multi-display clamping and automatic screen-edge flipping.

### 4. 🎙️ Push-to-Talk Voice Dictation (`⌥Space`)
- **Hold-to-Talk / Tap-to-Talk**: Press and hold `⌥Space` to dictate text in Vietnamese.
- **Streaming Live Transcription**: Powered by native `SFSpeechRecognizer` with real-time waveform feedback.
- **Intelligent Speech Cleanup**: Automatically trims filler pauses, normalizes capitalization, and injects directly into the target application.

### 5. 🎛️ Bento Control Center & Retina Menu Bar
- **Retina Menu Bar Capsule Badge**: Live indicator (`[• VI·T]`, `[• VI·V]`, `[• EN]`).
- **Bento Settings Window**: 4 organized panels for Dashboard statistics, Input & custom macros, AI Model Hub, and HUD visual configuration.
- **Interactive Live Sandbox**: In-app test area to try out typing, suggestions, and tone transformations before daily use.

### 6. 🛡️ 100% On-Device Privacy Architecture
- **Zero Cloud Network Calls**: No outbound network requests are made. Everything executes locally on your Apple Silicon chip.
- **Zero Third-Party Dependencies**: Pure native Swift codebase (`dependencies: []` in `Package.swift`).
- **Memory-Only Processing**: Keystrokes are evaluated in volatile memory and never logged to disk or external analytics.

---

## 🛠️ System Compatibility & Hardware Requirements

- **Supported macOS Versions**:
  - macOS 15.0+ (Sequoia / Tahoe)
  - macOS 14.0+ (Sonoma)
- **Supported Architecture**:
  - Apple Silicon (`arm64`): M1, M2, M3, M4 and their Pro, Max, and Ultra variants.
- **Xcode & Swift Compatibility**:
  - Swift 6.0+ / Xcode 15.0+ / 16.0+

---

## 📋 Installation & Permissions Walkthrough

1. **Mount & Install**:
   - Double-click `VFlow-v1.0.0-macOS-arm64.dmg`.
   - Drag **VFlow** into `/Applications`.
2. **First Launch**:
   - Launch **VFlow** from `/Applications` or Spotlight (`⌘Space` → "VFlow").
   - Click **Open** if prompted by macOS Gatekeeper.
3. **Grant Required Permissions**:
   - **Accessibility**: Required for tracking text cursor coordinates and text injection. Open **System Settings** → **Privacy & Security** → **Accessibility** and enable **VFlow**.
   - **Input Monitoring**: Required for global keystroke interception via `CGEventTap`. Open **System Settings** → **Privacy & Security** → **Input Monitoring** and enable **VFlow**.
   - **Microphone & Speech Recognition**: Required only if using Push-to-Talk voice dictation (`⌥Space`). Prompted on first use.

---

## 🧪 Forensic Quality & Verification Audit

The v1.0.0 release has undergone two comprehensive multi-agent bug discovery and adversarial remediation rounds:
- **171 Automated Tests Passing**: Unit, integration, boundary, and adversarial stress suites in `Tests/VFlowTests/` pass 100% with zero failures.
- **Swift 6 Concurrency Verified**: Zero data race warnings or concurrency violations under `@MainActor` and `NSLock` thread synchronization.
- **Clean-Room 3-Mutant Protocol**: 100% mutant kill rate across all adversarial mutations.
- **Code Signature**: Signed with deep strict compliance (`codesign --verify --deep --strict --verbose=2`).
- **Linker Inspection**: `otool -L` confirms zero third-party or local user dynamic library references.

---

## 🙏 Acknowledgements

We express our gratitude to the Vietnamese developer community, modern macOS open-source tool authors, and the automated AI testing frameworks that helped subject VFlow to rigorous adversarial stress testing.

For bug reports, feature suggestions, or source code contributions, please visit our GitHub repository:  
[https://github.com/TGalioAutomation/VFlow](https://github.com/TGalioAutomation/VFlow)

---
*VFlow Team — October 2026*
