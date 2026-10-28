# VFlow v1.0.0 — Official Production Release Notes

**Release Date:** October 28, 2026  
**Version:** `1.0.0` (Build 1)  
**Target Platform:** macOS 14.0+ (Sonoma, Sequoia, Tahoe) — Apple Silicon (`arm64`)  
**Repository:** [https://github.com/TGalioAutomation/VFlow](https://github.com/TGalioAutomation/VFlow)  
**Official Release:** [https://github.com/TGalioAutomation/VFlow/releases/tag/v1.0.0](https://github.com/TGalioAutomation/VFlow/releases/tag/v1.0.0)  
**Website:** [https://tgalioautomation.github.io/VFlow/](https://tgalioautomation.github.io/VFlow/)

---

## 🚀 Executive Summary — Solving Real macOS Typing & Dictation Pain Points

We are thrilled to announce **VFlow v1.0.0**, the flagship native macOS bilingual Vietnamese-English typing engine, context-aware 3-tier suggestion & grammar assistant, and voice-to-AI polish dictation platform.

Built from the ground up in **Swift 6** exclusively for Apple Silicon, VFlow directly solves the 6 biggest daily frustrations of Vietnamese-English macOS users:
1. **No More Accidental Diacritics on English & Code**: Type `salary`, `arrow`, `error`, `service`, `class`, `subclass` seamlessly without switching input sources, or double-tap (`rr`, `ss`, `ff`) to restore raw English characters instantly.
2. **Full-Sentence Context Across Pauses & Punctuation**: Write long paragraphs, pause to think, or type `.` — VFlow retains full sentence context and smartly truncates long previews (`…`) on the Caret Pill.
3. **Voice Dictation (`⌥Space`) → Instant Auto-Fill → `Tab-Tab` AI Polish**: Speak naturally with a `2.2s` smart silence watchdog that never cuts you off mid-thought, automatically fills the focused text field (including Chrome & Electron apps), and presents a `✨` AI Polish chip on the Caret Pill so you can press `Tab-Tab` to turn spoken rambling into crisp written prose.
4. **Bilingual Vietnamese & English Grammar Checking**: Catches English subject-verb/auxiliary errors (`"she dont know"` → `"She doesn't know."`, `"i goes"` → `"I went"`) alongside contextual Vietnamese typos (`"to đang"` → `"tôi đang"`, `"không cau"` → `"không dấu"`).
5. **Zero Unwanted Popups in Browsers & 100% Reliable Text Replacement**: Deep Accessibility tree verification (`AXEditableAncestor`) ensures the Caret Pill **only** appears inside genuine editable text inputs, while hybrid `CGEvent` + `AXValue` replacement with a **Violet-Cyan Shimmer Sweep** works reliably everywhere.
6. **100% On-Device Privacy (`0 KB` Cloud)**: Sub-2ms latency on Apple Silicon Neural Engine with zero cloud network calls and zero third-party dependencies.

---

## 📦 Distributable Packages & Downloads

| Package Name | Architecture | File Size | Direct Download Link |
|---|---|---|---|
| **VFlow-v1.0.0-macOS-arm64.dmg** | Apple Silicon (`arm64`) | ~4.6 MB | [Download DMG](https://github.com/TGalioAutomation/VFlow/releases/download/v1.0.0/VFlow-v1.0.0-macOS-arm64.dmg) |
| **VFlow-v1.0.0-macOS-arm64.zip** | Apple Silicon (`arm64`) | ~4.3 MB | [Download ZIP](https://github.com/TGalioAutomation/VFlow/releases/download/v1.0.0/VFlow-v1.0.0-macOS-arm64.zip) |
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
83ce6624e6f8da011d4c681a3fe59a94d94f06c85ad2f4211d8f811768065c27  VFlow-v1.0.0-macOS-arm64.dmg
6c69b4a5cb8ff4aa67be66fe686889fb074afc8ade9f0c105e6488ca0b3e02cc  VFlow-v1.0.0-macOS-arm64.zip
```

---

## 🌟 Key Capabilities in v1.0.0

### 1. Bilingual Auto-Escape Engine (`VFlowCore`)
- **Smart English Collision Prevention**: Words like `ary` (`salary`), `arrow`, `error`, `carry`, `sorry`, `current`, `class`, `subclass`, `import`, `service`, `const`, `diff`, `off` are automatically detected and preserved.
- **UniKey-Style Double-Tap Restore**: Double-tapping tone keys (`rr`, `ss`, `ff`, `jj`, `xx`) immediately reverts accidental tone marks back to raw English characters.
- **Full Telex & VNI Modes**: High-precision finite state machine supporting both Telex and VNI input conventions with instant mode toggling (`⌥Z`).
- **Free-Order Keystroke Tone Placement**: Type tones anywhere in the word (`vieest` or `toasn`); VFlow normalizes the diacritics accurately.

### 2. 3-Tier Contextual Suggestion & Bilingual Grammar HUD (`VFlowUI`)
- **`⚡` Tier 1: Instant Diacritics & Teencode Shorthand** (`⇥ Tab` or `⌥1`):
  - Restores full accents on unsigned words and expands abbreviations (`ko` → `không`, `dc`/`đc` → `được`, `trc` → `trước`, `ntn` → `như thế nào`, `mn` → `mọi người`).
- **`✨` Tier 2: On-Device AI Polish & Bilingual Grammar** (`⇥⇥ Tab-Tab` or `⌥2`):
  - Full-sentence Vietnamese & English grammar correction, contextual pronoun/verb disambiguation, spoken filler removal, and style re-phrasing across **Natural**, **Polite**, and **Concise** tones.
  - Visual **Tab-Tab Shimmer Sweep** feedback during sentence replacement.
- **`🔮` Tier 3: Next-Word Prediction** (`⌥3`):
  - Context-aware N-gram and neural next-word prediction without duplicate word echoing.

### 3. 🎙️ Push-to-Talk & Tap-to-Talk Voice Dictation + AI Polish (`⌥Space`)
- **Smart `2.2s` Silence Watchdog**: Automatically finalizes speech after a natural `2.2s` pause while monitoring live audio energy so you are never cut off while thinking of English technical terms.
- **Guaranteed Auto-Fill**: Injects recognized text into any focused input field via `CGEvent` with automatic `55ms` `AccessibilityBridge` fallback for Electron/Web apps.
- **Post-Dictation `✨` AI Polish**: Immediately displays a refined written version of your spoken sentence on the Caret Pill — press `Tab-Tab` or click the `✨` chip to replace raw speech with polished prose.

### 4. 🫧 120fps Floating Caret HUD & Deep Focus Verification
- **Strict Editable Focus Guard**: Traverses `AXEditableAncestor` / `AXTextMarker` attributes so the HUD never pops up while passively browsing web pages in Chrome or Safari.
- **Smart Head-Tail Ellipsis**: Long sentences are cleanly formatted (`…`) within a `680pt` dynamic ceiling without overflowing screen bounds.

---

## 🧪 Forensic Quality & Verification Audit

- **178/178 Automated Tests Passing**: Unit, integration, bilingual grammar, voice silence watchdog, and focus verification suites in `Tests/VFlowTests/` pass 100% with zero failures.
- **Swift 6 Concurrency Verified**: Zero data race warnings or concurrency violations under `@MainActor` and `NSLock`.
- **Clean-Room 3-Mutant Protocol**: 100% mutant kill rate across all adversarial mutations.
- **Code Signature**: Signed with deep strict compliance (`codesign --verify --deep --strict --verbose=2`).

---
*VFlow Team — October 2026*
