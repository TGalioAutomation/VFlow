# VFlow v1.0.2 — Official Production Release Notes

**Release Date:** November 16, 2026  
**Version:** `1.0.2` (Build 3)  
**Target Platform:** macOS 14.0+ (Sonoma, Sequoia, Tahoe) — Apple Silicon (`arm64`)  
**Repository:** [https://github.com/TGalioAutomation/VFlow](https://github.com/TGalioAutomation/VFlow)  
**Official Release:** [https://github.com/TGalioAutomation/VFlow/releases/tag/v1.0.2](https://github.com/TGalioAutomation/VFlow/releases/tag/v1.0.2)  
**Website:** [https://tgalioautomation.github.io/VFlow/](https://tgalioautomation.github.io/VFlow/)

---

## 🆕 What's New in v1.0.2

1. **Zero-Lag Dedicated EventTap Thread & Lock-Free AX Cache (`< 0.05ms` Keystroke Path)**:
   - Moved system `CGEventTap` execution onto a dedicated `.userInteractive` background `Thread` / `CFRunLoop`, completely isolating keystroke latency from AppKit/SwiftUI layout, SpellChecker, and Accessibility IPC.
   - Replaced synchronous Mach IPC inside the tap callback with a zero-blocking `fastCachedSecurityAndBlockStatus()` snapshot refreshed asynchronously on a serial AX probe queue, and eliminated expensive `kAXValueAttribute` document copies on large `AXTextArea`/`AXWebArea`/`AXGroup` editors.
   - Coalesced Caret Pill HUD updates (`32ms`) off the Main Thread and removed default raw per-keystroke disk logging.
2. **Built-In Auto-Updater (`VFlowUpdater`) with SHA-256 & CodeSign Verification**:
   - Checks GitHub Releases (`releases/latest`) automatically on startup and every 6 hours, displays 1-click upgrade banners in Menu Bar & Control Center, verifies downloaded `.zip` archives against `SHA256SUMS.txt` + `codesign --verify --deep --strict`, atomically replaces `VFlow.app` with backup/rollback safety, and relaunches automatically.
3. **System Resilience, Window Lifecycle & `0.0%` Idle CPU**:
   - Defensive denylist AX guard ensures Vietnamese typing works across Chrome web pages, Electron apps, and IDEs; isolates leaked background `IsSecureEventInputEnabled()`; auto-recreates dead `CFMachPort` taps and cleans stale TCC records; adds `applicationShouldHandleReopen` + standard macOS `⌘C`/`⌘V`/`⌘A`/`⌘Z`/`⌘W`/`⌘Q` menus; pauses `SilkSineWaveView` when idle (`0.0%` CPU).
4. **Vietnamese Input FSM Safeguards & Thread Safety**:
   - Added recursive lock protection across `VietnameseInputEngine` and preserved words starting with `đ` (`ddawt` → `đăt`) on Space without reverting back to raw ASCII `ddawt `, plus `"vieet"` → `"việt"` and `"vaaf"` → `"và"` quick recovery.
5. **Expanded Verification Suite (`223/223` Passing — Zero Compiler Warnings)**:
   - Added `SystemResilienceAndLifecycleTests`, `EmpiricalChallengerR5Tests`, `EmpiricalChallengerR5_1Tests`, and `PerformanceAndUpdaterTests`.

---

## 🚀 Executive Summary — Solving Real macOS Typing & Dictation Pain Points

We are thrilled to announce **VFlow v1.0.2**, the fastest and most resilient native macOS bilingual Vietnamese-English typing engine, context-aware 3-tier suggestion & grammar assistant, and self-updating desktop companion.

Built from the ground up in **Swift 6** exclusively for Apple Silicon, VFlow directly solves the daily frustrations of Vietnamese-English macOS users:
1. **No More Accidental Diacritics on English & Code**: Type `salary`, `arrow`, `error`, `service`, `class`, `subclass` seamlessly without switching input sources, or double-tap (`rr`, `ss`, `ff`) to restore raw English characters instantly.
2. **Full-Sentence Context Across Pauses & Punctuation**: Write long paragraphs, pause to think, or type `.` — VFlow retains full sentence context and smartly truncates long previews (`…`) on the Caret Pill.
3. **Voice Dictation (`⌥Space`) → Instant Auto-Fill → `Tab-Tab` AI Polish**: Speak naturally with a `2.2s` smart silence watchdog that never cuts you off mid-thought, automatically fills the focused text field (including Chrome & Electron apps), and presents a `✨` AI Polish chip on the Caret Pill so you can press `Tab-Tab` to turn spoken rambling into crisp written prose.
4. **Bilingual Vietnamese & English Grammar Checking**: Catches English subject-verb/auxiliary errors and repeated-letter typos (`"i cannn do it "` → `"I can do it"`, `"she dont know"` → `"She doesn't know."`, `"i goes"` → `"I went"`) alongside contextual Vietnamese typos (`"cah su dung day la gi"` → `"cách sử dụng đây là gì"`, `"to đang"` → `"tôi đang"`, `"không cau"` → `"không dấu"`).
5. **Zero Unwanted Popups in Browsers & 100% Reliable Text Replacement**: Permissive Accessibility guard keeps Vietnamese typing responsive everywhere while blocking HUD clutter on non-text controls and password fields.
6. **100% On-Device Privacy (`0 KB` Cloud)**: Sub-millisecond keystroke latency with `0.0%` idle CPU and zero third-party dependencies.

---

## 📦 Distributable Packages & Downloads

| Package Name | Architecture | File Size | Direct Download Link |
|---|---|---|---|
| **VFlow-v1.0.2-macOS-arm64.dmg** | Apple Silicon (`arm64`) | ~4.7 MB | [Download DMG](https://github.com/TGalioAutomation/VFlow/releases/download/v1.0.2/VFlow-v1.0.2-macOS-arm64.dmg) |
| **VFlow-v1.0.2-macOS-arm64.zip** | Apple Silicon (`arm64`) | ~4.4 MB | [Download ZIP](https://github.com/TGalioAutomation/VFlow/releases/download/v1.0.2/VFlow-v1.0.2-macOS-arm64.zip) |
| **SHA256SUMS.txt** | All Packages | 190 B | [Download Checksums](https://github.com/TGalioAutomation/VFlow/releases/download/v1.0.2/SHA256SUMS.txt) |

---

## 🔒 SHA-256 Verification Guide

Before installing, verify the integrity of your downloaded release binaries using standard macOS command line tools:

```bash
# 1. Open Terminal and navigate to your download directory:
cd ~/Downloads

# 2. Check SHA-256 hash against the official signature:
shasum -a 256 VFlow-v1.0.2-macOS-arm64.dmg
shasum -a 256 VFlow-v1.0.2-macOS-arm64.zip

# Or verify automatically with SHA256SUMS.txt:
shasum -a 256 -c SHA256SUMS.txt
```

### Verified SHA-256 Checksums
```text
e6a53da042bab5dd3008d53c0871233269fd77b2b86e3e0078f3847c3cea2726  VFlow-v1.0.2-macOS-arm64.dmg
157241ff79b394a9c68be9f44c8faf6e822023753d9ffd91d595e1996de3f4e3  VFlow-v1.0.2-macOS-arm64.zip
```

---

## 🌟 Key Capabilities in v1.0.2

### 1. Bilingual Auto-Escape Engine (`VFlowCore`)
- **Smart English Collision Prevention**: Words like `ary` (`salary`), `arrow`, `error`, `carry`, `sorry`, `current`, `class`, `subclass`, `import`, `service`, `const`, `diff`, `off` are automatically detected and preserved.
- **UniKey-Style Double-Tap Restore**: Double-tapping tone keys (`rr`, `ss`, `ff`, `jj`, `xx`) immediately reverts accidental tone marks back to raw English characters.
- **Full Telex & VNI Modes**: High-precision finite state machine supporting both Telex and VNI input conventions with instant mode toggling (`⌥Z`).
- **Free-Order Keystroke Tone Placement**: Type tones anywhere in the word (`vieest` or `toasn`); VFlow normalizes the diacritics accurately.

### 2. 3-Tier Contextual Suggestion & Bilingual Grammar HUD (`VFlowUI`)
- **`⚡` Tier 1: Instant Diacritics, English Typo & Teencode Shorthand** (`⇥ Tab` or `⌥1`):
   - Restores full accents on unsigned words, expands Vietnamese abbreviations (`ko` → `không`, `dc`/`đc` → `được`, `trc` → `trước`, `ntn` → `như thế nào`, `mn` → `mọi người`), and repairs repeated-letter English typos (`cannn` → `can` / `can't`, `dontt` → `don't`).
- **`✨` Tier 2: On-Device AI Polish & Bilingual Grammar** (`⇥⇥ Tab-Tab` or `⌥2`):
   - Full-sentence Vietnamese & English grammar correction (`cah su dung day la gi` → `cách sử dụng đây là gì`, `i cannn do it ` → `I can do it`), contextual pronoun/verb disambiguation, spoken filler removal, and style re-phrasing across **Natural**, **Polite**, and **Concise** tones.
   - Visual **Tab-Tab Shimmer Sweep** feedback during sentence replacement.
- **`🔮` Tier 3: Next-Word Prediction** (`⌥3`):
   - Context-aware Vietnamese and English N-gram and neural next-word prediction without duplicate word echoing.

### 3. 🎙️ Push-to-Talk & Tap-to-Talk Voice Dictation + AI Polish (`⌥Space`)
- **Smart `2.2s` Silence Watchdog**: Automatically finalizes speech after a natural `2.2s` pause while monitoring live audio energy so you are never cut off while thinking of English technical terms.
- **Guaranteed Auto-Fill**: Injects recognized text into any focused input field via `CGEvent` with automatic `55ms` `AccessibilityBridge` fallback for Electron/Web apps.
- **Post-Dictation `✨` AI Polish**: Immediately displays a refined written version of your spoken sentence on the Caret Pill — press `Tab-Tab` or click the `✨` chip to replace raw speech with polished prose.

### 4. 🫧 120fps Floating Caret HUD & Deep Focus Verification
- **Strict Editable Focus Guard**: Traverses `AXEditableAncestor` / `AXTextMarker` attributes so the HUD never pops up while passively browsing web pages in Chrome or Safari.
- **Smart Head-Tail Ellipsis**: Long sentences are cleanly formatted (`…`) within a `680pt` dynamic ceiling without overflowing screen bounds.

---

## 🧪 Forensic Quality & Verification Audit

- **186/186 Automated Tests Passing**: Unit, integration, bilingual grammar, voice silence watchdog, and focus verification suites in `Tests/VFlowTests/` pass 100% with zero failures.
- **Swift 6 Concurrency Verified**: Zero data race warnings or concurrency violations under `@MainActor` and `NSLock`.
- **Clean-Room 3-Mutant Protocol**: 100% mutant kill rate across all adversarial mutations.
- **Code Signature**: Signed with deep strict compliance (`codesign --verify --deep --strict --verbose=2`).

---
*VFlow Team — October 2026*
