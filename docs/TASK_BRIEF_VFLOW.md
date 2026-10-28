# Task Brief: VFlow — Native macOS Anywhere Vietnamese Input & AI Text Polish Engine

**Document Version**: 1.0.0-GA  
**Target Architecture**: Apple Silicon (arm64, macOS 14.0+ / macOS 15+)  
**Implementation Toolchain**: Swift 6.4 / Swift 5.10 + SwiftUI + AppKit (`NSPanel`)  
**Package Manager**: Swift Package Manager (`Package.swift`) + Standalone App Bundle Builder (`scripts/build_app.sh`)  
**Delegation Target**: `clean-room-builder` (Model Tier: `pro`) & `clean-room-tester` (Model Tier: `flash`)  
**OpenRouter Policy**: STRICT ZERO USAGE (100% Native Antigravity Execution)

---

## 1. Objective & Strategic Intent
Xây dựng ứng dụng macOS native **VFlow** hoạt động thường trực dưới thanh Menu Bar (Background Agent) kết hợp giao diện viên thuốc nổi siêu nhỏ gọn (**Caret Pill HUD Prototype v8 — Clean Minimal Wave**, `38px` height) hiển thị sát con trỏ đang gõ ở **bất kỳ ứng dụng nào** (Zalo, Chrome, Safari, Slack, Cursor, Notes, Terminal...).

VFlow tích hợp 4 trụ cột công nghệ đột phá:
1. **Bộ gõ Tiếng Việt Hoàn Hảo (`VietnameseInputEngine`)**: Bắt phím hệ thống qua `CGEventTap`, FSM Telex & VNI toàn diện, Smart Auto-English Restore (tự phục hồi từ tiếng Anh), Instant Typo/Tone Auto-Correction (<2ms), Safari/Spotlight Autocomplete Bypass, và Smart Per-App Mode (`VI`/`EN`).
2. **Gõ ở mọi nơi & Caret Pill HUD (`AnywhereTextBridge` + `CaretPillHUD`)**: Định vị con trỏ qua `AXUIElement` với thuật toán tự động lật mép màn hình, cửa sổ `NSPanel` `.nonActivatingPanel` không bao giờ cướp focus, dải sóng lụa Cyan & Violet `52x22px` 120fps, chữ mượt không bị sóng che, và cơ chế Direct Text Injection.
3. **Sửa từ sai & Viết lại câu lủng củng (`LocalAIRuntime` & `VietnameseTextPolisher`)**: Bộ quy tắc Offline Fast Vietnamese Grammar Polisher (dọn từ đệm *"à ừm"*, sửa viết tắt teencode, 3 tone văn: Tự nhiên, Lịch sự, Ngắn gọn) + Kiến trúc Model Hub 1-Click tải và suy luận Local LLM (MLX / GGUF / CoreML).
4. **Push-to-Talk Voice Dictation (`VoiceDictationService`)**: Giữ phím tắt (`Fn` hoặc `Option + Space`) thu âm Tiếng Việt qua `SFSpeechRecognizer` / Whisper CoreML, hiển thị trực tiếp lên nhãn `Transcript`, thả phím chuyển `Working` làm mượt và điền thẳng vào ô nhập.

---

## 2. Context & Assets Available
- **Vị trí Workspace**: `/Users/apexdev/Desktop/app-ho-tro-go-text-anywhere`
- **Bộ 3D Assets đã chuẩn bị sẵn** tại `/Users/apexdev/Desktop/app-ho-tro-go-text-anywhere/assets/`:
  - `app_icon_nobg.png`: 3D Crystal Fluid Glass Orb (biểu tượng ứng dụng VFlow).
  - `voice_orb_nobg.png`: Futuristic Glowing Liquid Glass Mic Orb (trạng thái thu âm).
  - `neural_core_nobg.png`: Isometric Glowing Purple & Gold Neural Core (trạng thái AI Processing / Model Hub).
- **Môi trường Swift**: `Apple Swift version 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1)`, arm64 macOS 27.0.0 (Darwin Kernel).

---

## 3. Scope Boundaries

### 3.1 In-Scope (Bắt buộc thực thi)
1. **Module `VFlowCore`**:
   - `VietnameseInputEngine`: Finite State Machine cho Telex & VNI. Quản lý âm tiết tiếng Việt chuẩn, xử lý dấu thanh (sắc, huyền, hỏi, ngã, nặng), dấu mũ (â, ê, ô), móc (ơ, ư), chữ đ (`dd`), xóa dấu (`z`/`0`), đặt dấu tự do cuối từ.
   - `English syllables & dictionary detector`: Nhận diện các từ tiếng Anh thông dụng (`window`, `safari`, `react`, `function`, `status`, `const`, `import`, `service`...) hoặc quy tắc cấu trúc phụ âm tiếng Anh không hợp lệ trong tiếng Việt -> Tự động phục hồi nguyên bản khi gõ phím trắng (`Space`).
   - `TypoToneCorrector`: Sửa lỗi gõ lặp dấu (`toanfs` -> `toán`, `hoocj` -> `học`), tự động chuẩn hóa vị trí dấu theo quy tắc mới/cũ (`hòa` vs `hoà`).
   - `PerAppStateManager`: Quản lý `VI`/`EN` riêng biệt theo bundle identifier của ứng dụng đang kích hoạt (`NSWorkspace.shared.frontmostApplication`).
   - `VietnameseTextPolisher`: Fast offline rule-based polisher:
     - Lọc filler words: *"à"*, *"ừm"*, *"kiểu như là"*, *"thì là mà"*, *"nói chung là"*.
     - Chuẩn hóa teencode & viết tắt: *"ko/k" -> "không"*, *"đc/dc" -> "được"*, *"j" -> "gì"*, *"ntn" -> "như thế nào"*, *"mn" -> "mọi người"*, *"cx" -> "cũng"*, *"vs" -> "với"*, *"thg" -> "thường"*, *"kb" -> "không biết"*.
     - Điều chỉnh phong cách câu: `natural` (Tự nhiên), `polite` (Lịch sự, công sở), `concise` (Ngắn gọn, súc tích).
   - `LocalLLMProvider`: Protocol trừu tượng hóa cho cả Rule-based engine và On-device Neural Model (CoreML / MLX connector) kèm mock/stub sẵn sàng cho unit testing.
2. **Module `VFlowPlatform`**:
   - `EventTapHook`: Bắt và can thiệp phím qua `CGEvent.tapCreate` (`kCGHIDEventTap` / `kCGSessionEventTap`).
   - `AccessibilityBridge`: Kết nối `AXUIElementCreateSystemWide`, lấy phần tử focus `kAXFocusedUIElementAttribute`, tính tọa độ caret `kAXBoundsForRangeParameterizedAttribute`, lấy/đặt text `kAXSelectedTextAttribute` / `kAXValueAttribute`.
   - `AutocompleteGuard`: Kiểm tra heuristic trường autocomplete (URL bar Safari/Chrome, Spotlight, Raycast) để điều chỉnh buffer và timing sự kiện, triệt tiêu lỗi nuốt ký tự đầu.
   - `ClipboardInjector`: Cơ chế fallback bơm văn bản an toàn: Lưu tạm clipboard hiện tại -> Gán text mới -> Phát `Cmd + V` (`CGEvent`) -> Phục hồi clipboard cũ sau 50ms.
   - `PushToTalkMonitor`: Lắng nghe phím tắt toàn cục (`Fn` tap/hold hoặc `Option + Space`) độc lập với trạng thái phím gõ.
3. **Module `VFlowUI`**:
   - `CaretPillWindow`: Kế thừa `NSPanel`, cấu hình `.nonActivatingPanel`, style mask `.borderless`, floating level `.floating` / `.statusBar`, nền trong suốt, không bao giờ lấy key focus.
   - `CleanMinimalWaveHUD` (Prototype v8):
     - Kích thước: Cao cố định `38px`, Max Width `385px`, bo góc `19px`.
     - Visual: Deep Obsidian `#0D1324` (96% opacity + Material UltraThin/HUD Blur), Border `1px` `rgba(56, 189, 248, 0.28)`.
     - Layout 3 khối biệt lập:
       - **Trái (`52x22px`)**: SwiftUI `TimelineView` + `Canvas` 120fps vẽ Filled Silk Sine-Wave 2 tầng (Cyan `#38BDF8` & Violet `#A855F7`), tự động giảm biên độ phẳng khi nghỉ hoặc khi hoàn tất.
       - **Giữa**: Text label hiển thị mượt mà, chuyển động text transition ngân nhẹ `0.8s` (`cubic-bezier(0.16, 1, 0.3, 1)`).
       - **Phải**: Divider dọc `1px`, nhãn trạng thái `Transcript` (`#7DD3FC`), `Working` (`#A5B4FC`), hoặc `✓ Đã điền` kèm các chip thao tác nhanh `⌘Z Hoàn tác`, `⇥ Đổi giọng`.
   - `MenuBarController`: Icon Menu Bar với popup Bento Menu: Chuyển nhanh chế độ gõ (Telex/VNI/EN), chuyển giọng văn, bật/tắt Push-to-Talk, phím tắt Cài đặt.
   - `BentoSettingsView`: Giao diện Cài đặt phong cách Bento Grid hiện đại (hiển thị 3D asset `app_icon_nobg.png`, `voice_orb_nobg.png`, `neural_core_nobg.png`), tải model AI 1-click.
4. **Tooling & Build System**:
   - `Package.swift`: Khai báo các targets rõ ràng, độc lập, không phụ thuộc thư viện bên ngoài nặng.
   - `scripts/build_app.sh`: Biên dịch `swift build -c release`, cấu trúc `VFlow.app/Contents/MacOS`, tạo `Info.plist` với quyền `NSSpeechRecognitionUsageDescription`, `NSMicrophoneUsageDescription`, `LSUIElement = true` (Background Agent), copy Assets.
   - `Tests/VFlowTests`: Bộ unit tests đầy đủ cho FSM Telex/VNI, Tone placement, English restore, Polisher rules, và Autocomplete guard.

### 3.2 Out-of-Scope (Tuyệt đối không làm)
- Không gọi bất kỳ API bên thứ ba trả phí nào (OpenAI API, OpenRouter, Anthropic Cloud API). Toàn bộ xử lý AI là Local / Rule-based / CoreML.
- Không phát triển phiên bản iOS/iPadOS/Windows/Linux (chỉ tối ưu macOS native Apple Silicon).
- Không nhúng các thư viện C++ nặng hoặc binary không rõ nguồn gốc gây phình bundle.

---

## 4. Execution Rules (MUST & NEVER)

### MUST:
1. **MUST** giữ app chạy ngầm không cướp focus: Mọi cửa sổ HUD phải sử dụng `NSPanel` với cờ `NSWindow.StyleMask.nonActivatingPanel` và `canBecomeKey = false`, `canBecomeMain = false`.
2. **MUST** phản hồi gõ tức thì (<2ms): Thuật toán xử lý phím tiếng Việt trong `CGEventTap` phải là pure memory O(1) state lookup, không được block event tap runloop.
3. **MUST** xử lý an toàn quyền Accessibility (`AXIsProcessTrustedWithOptions`): Khi chưa được cấp quyền, hiển thị onboarding popup hướng dẫn cấp quyền rõ ràng và không crash.
4. **MUST** khôi phục clipboard nguyên vẹn: Khi sử dụng cơ chế fallback Clipboard Injection, phải backup nội dung pasteboard hiện tại và khôi phục lại ngay sau khi paste.
5. **MUST** hỗ trợ cả bàn phím Telex và VNI với tính năng sửa dấu cuối từ và xóa dấu `z`/`0`.
6. **MUST** chạy thành công `swift test` và `swift build` trực tiếp trên hệ thống mà không phát sinh cảnh báo Swift 6 concurrency lỗi thời.

### NEVER:
1. **NEVER** gọi OpenRouter hoặc các cloud LLM endpoint.
2. **NEVER** vẽ sóng âm đè dưới chữ hoặc tạo background visual gây nhiễu chữ (tuân thủ nghiêm ngặt Prototype v8: sóng chỉ nằm trong ô `52x22px` ở góc trái).
3. **NEVER** làm nháy mắt hoặc giật lag con trỏ khi đang gõ.
4. **NEVER** nuốt ký tự đầu tiên khi gõ vào thanh URL Safari hoặc Spotlight.

---

## 5. Architectural Modules & File Breakdown

```
app-ho-tro-go-text-anywhere/
├── Package.swift
├── scripts/
│   ├── build_app.sh
│   └── run_dev.sh
├── Sources/
│   ├── VFlowCore/                      # Thuật toán thuần túy (Pure Swift, 0 AppKit dependency)
│   │   ├── Engine/
│   │   │   ├── VietnameseInputEngine.swift
│   │   │   ├── InputMethod.swift       # Telex, VNI, Off
│   │   │   ├── SyllableParser.swift    # Phân tích âm tiết Tiếng Việt
│   │   │   ├── ToneRules.swift         # Quy tắc đặt dấu chuẩn (hòa vs hoà)
│   │   │   └── EnglishDetector.swift   # Nhận diện từ Tiếng Anh & Smart Restore
│   │   ├── Polish/
│   │   │   ├── VietnameseTextPolisher.swift
│   │   │   ├── PolishTone.swift        # Natural, Polite, Concise
│   │   │   └── TeencodeDictionary.swift
│   │   ├── AI/
│   │   │   ├── LocalLLMProvider.swift  # Protocol cho on-device AI
│   │   │   ├── RuleBasedLLMStub.swift  # Bộ AI offline tốc độ cao
│   │   │   └── ModelHubConfig.swift    # Cấu hình tải Qwen / Whisper
│   │   └── State/
│   │       ├── PerAppStateManager.swift
│   │       └── TypingBuffer.swift
│   │
│   ├── VFlowPlatform/                  # macOS System Hooks & Accessibility
│   │   ├── EventTap/
│   │   │   ├── EventTapHook.swift      # CGEventTap listener
│   │   │   └── KeyCodeMap.swift
│   │   ├── Accessibility/
│   │   │   ├── AccessibilityBridge.swift
│   │   │   ├── CaretLocator.swift      # Tìm tọa độ con trỏ màn hình
│   │   │   └── AutocompleteDetector.swift
│   │   ├── Injection/
│   │   │   ├── DirectTextInjector.swift
│   │   │   └── ClipboardFallback.swift
│   │   └── Voice/
│   │       ├── VoiceDictationService.swift
│   │       └── PushToTalkMonitor.swift
│   │
│   ├── VFlowUI/                        # SwiftUI & AppKit Floating Window
│   │   ├── CaretPill/
│   │   │   ├── CaretPillWindow.swift   # NSPanel non-activating
│   │   │   ├── CaretPillView.swift     # Container 38px
│   │   │   ├── SilkSineWaveView.swift  # 52x22px Canvas 120fps Wave
│   │   │   └── PillActionControls.swift# Undo ⌘Z, Switch Tone ⇥
│   │   ├── MenuBar/
│   │   │   ├── MenuBarCoordinator.swift
│   │   │   └── BentoMenuView.swift
│   │   └── Settings/
│   │       ├── BentoSettingsWindow.swift
│   │       └── ModelHubView.swift
│   │
│   └── VFlowApp/                       # App Entry Point & Coordinator
│       ├── main.swift
│       └── AppDelegate.swift
│
├── Tests/
│   └── VFlowTests/
│       ├── VietnameseEngineTests.swift # Test Telex/VNI, Tone, Đ, Delete
│       ├── EnglishDetectorTests.swift  # Test Auto-English Restore
│       ├── TextPolisherTests.swift     # Test Teencode & Voice Polishing
│       └── CaretLocatorTests.swift     # Mock Caret positioning logic
│
└── assets/                             # 3D Assets đã có sẵn
    ├── app_icon_nobg.png
    ├── voice_orb_nobg.png
    └── neural_core_nobg.png
```

---

## 6. Verification & Quality Gates

### 6.1 Unit Test Verification (`clean-room-tester`)
- **Bộ gõ Telex**:
  - Gõ `t-o-a-n-s` -> `toán`
  - Gõ `h-o-a-f` -> `hoà` / `hòa` (theo cấu hình)
  - Gõ `d-d-u-w-o-w-n-g-f` -> `đường`
  - Gõ `w-i-n-d-o-w-Space` -> khôi phục `window ` (không bị thành `wỉndow`)
  - Gõ `s-a-f-a-r-i-Space` -> khôi phục `safari `
  - Gõ `t-o-a-n-s-z` -> `toan` (xóa dấu)
- **Bộ gõ VNI**:
  - Gõ `t-o-a-n-1` -> `toán`
  - Gõ `d-9-u-7-o-7-n-g-2` -> `đường`
  - Gõ `t-o-a-n-1-0` -> `toan` (xóa dấu)
- **Polisher**:
  - Input: *"à ừm ko biết ntn có đc ko"*
  - Output Natural: *"không biết như thế nào có được không"*
  - Output Polite: *"Tôi xin phép hỏi tình hình hiện tại thế nào có được không ạ"*
  - Output Concise: *"Chưa rõ tình hình có được không"*
- **Mutation Testing (`clean-room-tester`)**:
  - Tạo 3 đột biến phá vỡ:
    - `mutant-1`: Đảo ngược logic xóa dấu `z`.
    - `mutant-2`: Bỏ qua Auto-English restore.
    - `mutant-3`: Trả về nil khi phát hiện autocomplete trường URL.
  - Điều kiện đạt: Bản chính PASS 100%, cả 3 mutant đều FAIL 100%.

### 6.2 App & HUD Verification
- Biên dịch thành công với `swift build` (0 lỗi, 0 cảnh báo).
- Thực thi script `scripts/build_app.sh` tạo thành công `build/VFlow.app`.
- Kiểm tra tính non-activating của `CaretPillWindow` qua code và headless unit tests.

---

## 7. Stop Conditions
1. DỪNG LẠI và thông báo nếu có đề xuất tích hợp API key đám mây bên ngoài.
2. DỪNG LẠI nếu có file cần sửa đổi nằm ngoài cây thư mục dự án `/Users/apexdev/Desktop/app-ho-tro-go-text-anywhere`.
3. DỪNG LẠI nếu quá trình kiểm thử mutation cho thấy bất kỳ mutant nào vượt qua bài test.

---

## 8. Done When Criteria
1. File `Package.swift` được cấu hình chuẩn, build thành công với `swift build`.
2. Toàn bộ các module `VFlowCore`, `VFlowPlatform`, `VFlowUI`, `VFlowApp` được triển khai đầy đủ tính năng theo đặc tả.
3. Bộ test `Tests/VFlowTests` pass 100% khi chạy `swift test`.
4. Script `scripts/build_app.sh` tạo ra file `VFlow.app` chạy được độc lập trên macOS.
5. Cả 3 mutant tests do `clean-room-tester` tạo ra đều FAIL chính xác.
