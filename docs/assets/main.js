/**
 * VFlow — Flagship Promotional Landing Website
 * Interactive Pain-Point Resolver, Voice-to-AI Polish Simulator & 120fps Silk Sine-Wave HUD
 */

document.addEventListener('DOMContentLoaded', () => {
  initSineWaveCanvas();
  initInteractiveDemo();
  initMenuBarBadgeToggle();
  initCopyButtons();
});

/* ==============================================================================
   1. 120fps Silk Sine-Wave Canvas Engine (Prototype v8 Replica)
   Two-layer Cyan (#38BDF8) & Violet (#A855F7) undulating smooth curves
   ============================================================================== */
function initSineWaveCanvas() {
  const canvas = document.getElementById('waveCanvas');
  if (!canvas) return;

  const ctx = canvas.getContext('2d');
  let phase = 0;
  let amplitude = 4.5;
  let targetAmplitude = 4.5;

  const dpr = window.devicePixelRatio || 2;
  const width = 52;
  const height = 22;
  canvas.width = width * dpr;
  canvas.height = height * dpr;
  ctx.scale(dpr, dpr);

  function renderWave() {
    ctx.clearRect(0, 0, width, height);

    amplitude += (targetAmplitude - amplitude) * 0.12;
    const midY = height / 2;

    // Layer 1: Violet Sine Wave (Back layer)
    ctx.beginPath();
    ctx.strokeStyle = 'rgba(168, 85, 247, 0.78)';
    ctx.lineWidth = 1.4;
    for (let x = 0; x <= width; x++) {
      const y = midY + Math.sin((x * 0.12) + (phase * 1.3)) * (amplitude * 0.78);
      if (x === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.stroke();

    // Layer 2: Cyan Sine Wave (Front layer)
    ctx.beginPath();
    ctx.strokeStyle = 'rgba(56, 189, 248, 0.96)';
    ctx.lineWidth = 1.6;
    for (let x = 0; x <= width; x++) {
      const y = midY + Math.sin((x * 0.15) + phase) * amplitude;
      if (x === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.stroke();

    phase += 0.085;
    requestAnimationFrame(renderWave);
  }

  renderWave();

  window.triggerWavePulse = function(boost = 7.8, durationMs = 320) {
    targetAmplitude = boost;
    setTimeout(() => {
      targetAmplitude = 4.5;
    }, durationMs);
  };
}

/* ==============================================================================
   2. Interactive Live Typing, Voice Dictation & 3-Tier Suggestion Engine
   ============================================================================== */
function initInteractiveDemo() {
  const input = document.getElementById('demoInput');
  const editorBox = document.getElementById('demoEditorBox');
  const scenarioHint = document.getElementById('demoScenarioHint');
  const shimmerToast = document.getElementById('shimmerToast');
  const voiceSimBtn = document.getElementById('simulateVoiceBtn');
  const hudContainer = document.getElementById('simulatedHud');
  const chipContainer = document.getElementById('hudChips');
  const statusLabel = document.getElementById('hudStatus');
  const presetButtons = document.querySelectorAll('.preset-btn[data-preset]');
  const modeBadge = document.getElementById('hudMode');

  if (!input || !chipContainer) return;

  const demoScenarios = {
    'voice_ai': {
      hint: '💡 Nỗi đau #03: Đọc giọng nói tự nhiên có nhịp nghỉ 2.2s → Tự điền vào ô text → Nhấn Tab-Tab để AI chuốt lại văn nói lủng củng.',
      text: 'Hình như là sau khi anh nhận diện cái phần giọng nói sang nhưng mà đúng ra đến có 1 thao tác AI',
      t1: {
        key: '⇥',
        icon: '⚡',
        label: 'Sau khi nhận diện cái phần giọng nói sang text nhưng mà đúng ra cần có 1 thao tác AI',
        fullText: 'Sau khi nhận diện cái phần giọng nói sang text nhưng mà đúng ra cần có 1 thao tác AI.',
        kind: 'diacritic'
      },
      t2: {
        key: '⇥⇥',
        icon: '✨',
        label: '…giọng nói sang text, đúng ra cần có một thao tác AI biên tập lại.',
        fullText: 'Sau khi nhận diện giọng nói sang text, đúng ra cần có một thao tác AI biên tập lại.',
        kind: 'polish'
      },
      t3: {
        key: '⌥3',
        icon: '🔮',
        label: 'tức thì',
        fullText: 'Sau khi nhận diện giọng nói sang text, đúng ra cần có một thao tác AI biên tập lại tức thì.',
        kind: 'predict'
      },
      status: '🎙️ Voice → ✨ AI'
    },
    'long_sentence': {
      hint: '💡 Nỗi đau #02: Viết đoạn văn rất dài, có dấu chấm ngắt câu và nghỉ nhịp suy nghĩ — VFlow vẫn giữ trọn ngữ cảnh và thu gọn hiển thị thông minh.',
      text: 'hom nay toi da danh rat nhieu thoi gian de kiem tra he thong goi y cau dai tren macos. khi nguoi dung nghi mot lat roi go tiep',
      t1: {
        key: '⇥',
        icon: '⚡',
        label: '…khi người dùng nghỉ một lát rồi gõ tiếp',
        fullText: 'Hôm nay tôi đã dành rất nhiều thời gian để kiểm tra hệ thống gợi ý câu dài trên macOS. Khi người dùng nghỉ một lát rồi gõ tiếp',
        kind: 'diacritic'
      },
      t2: {
        key: '⇥⇥',
        icon: '✨',
        label: '…Khi người dùng nghỉ một lát rồi gõ tiếp, hệ thống vẫn giữ trọn ngữ cảnh.',
        fullText: 'Hôm nay tôi đã dành rất nhiều thời gian để kiểm tra hệ thống gợi ý câu dài trên macOS. Khi người dùng nghỉ một lát rồi gõ tiếp, hệ thống vẫn giữ trọn ngữ cảnh.',
        kind: 'polish'
      },
      t3: {
        key: '⌥3',
        icon: '🔮',
        label: 'mượt mà',
        fullText: 'Hôm nay tôi đã dành rất nhiều thời gian để kiểm tra hệ thống gợi ý câu dài trên macOS. Khi người dùng nghỉ một lát rồi gõ tiếp, hệ thống vẫn giữ trọn ngữ cảnh mượt mà.',
        kind: 'predict'
      },
      status: '🧠 Full Context'
    },
    'en_grammar': {
      hint: '💡 Nỗi đau #04: Gõ nhanh tiếng Anh bị sai chia động từ ("she dont know", "i goes") — Tầng 2 ✨ tự động phát hiện và sửa ngữ pháp.',
      text: 'she dont know how to fix this issue and i goes to check the server log',
      t1: {
        key: '⇥',
        icon: '⚡',
        label: "She doesn't know how to fix this issue",
        fullText: "She doesn't know how to fix this issue and I go to check the server log",
        kind: 'diacritic'
      },
      t2: {
        key: '⇥⇥',
        icon: '✨',
        label: "She doesn't know how to fix this issue, so I went to check the server logs.",
        fullText: "She doesn't know how to fix this issue, so I went to check the server logs.",
        kind: 'polish'
      },
      t3: {
        key: '⌥3',
        icon: '🔮',
        label: 'immediately',
        fullText: "She doesn't know how to fix this issue, so I went to check the server logs immediately.",
        kind: 'predict'
      },
      status: '🇬🇧 EN Grammar'
    },
    'to dang lam viec': {
      hint: '💡 Nỗi đau #04: Lỗi chính tả theo ngữ cảnh tiếng Việt ("to đang" → "tôi đang", "không cau" → "không dấu") mà bộ kiểm tra từ đơn bó tay.',
      text: 'to dang lam viec tren may mac nhung go nhanh hay bi khong cau',
      t1: {
        key: '⇥',
        icon: '⚡',
        label: 'tôi đang làm việc trên máy Mac nhưng gõ nhanh hay bị không dấu',
        fullText: 'tôi đang làm việc trên máy Mac nhưng gõ nhanh hay bị không dấu',
        kind: 'diacritic'
      },
      t2: {
        key: '⇥⇥',
        icon: '✨',
        label: 'Tôi đang làm việc trên máy Mac nhưng khi gõ nhanh thường bị mất dấu.',
        fullText: 'Tôi đang làm việc trên máy Mac nhưng khi gõ nhanh thường bị mất dấu.',
        kind: 'polish'
      },
      t3: {
        key: '⌥3',
        icon: '🔮',
        label: 'tiếng Việt',
        fullText: 'Tôi đang làm việc trên máy Mac nhưng khi gõ nhanh thường bị mất dấu tiếng Việt.',
        kind: 'predict'
      },
      status: '🇻🇳 VI Context'
    },
    'ary': {
      hint: '💡 Nỗi đau #01: Đang bật bộ gõ tiếng Việt nhưng gõ tiếng Anh & biến code ("salary", "arrow", "service", "subclass") không bị nhảy dấu.',
      text: 'const salary = calculateArrow(service, subclass, currentError);',
      t1: {
        key: '⇥',
        icon: '⚡',
        label: 'const salary = calculateArrow(service, subclass, currentError);',
        fullText: 'const salary = calculateArrow(service, subclass, currentError);',
        kind: 'diacritic'
      },
      t2: {
        key: '⇥⇥',
        icon: '✨',
        label: 'English & Code Auto-Escape: Bảo toàn 100% không nhảy dấu',
        fullText: 'const salary = calculateArrow(service, subclass, currentError);',
        kind: 'polish'
      },
      t3: {
        key: '⌥3',
        icon: '🔮',
        label: 'return salary;',
        fullText: 'const salary = calculateArrow(service, subclass, currentError);\nreturn salary;',
        kind: 'predict'
      },
      status: '🛡️ Auto-Escape'
    },
    'ko sao ca': {
      hint: '💡 Gõ tắt tốc độ cao: Tự động bung các từ viết tắt thông dụng ("ko", "dc", "trc", "mn", "ntn") thành câu lịch sự, đầy đủ dấu.',
      text: 'ko sao dc ma trc gio mn van dung ntn',
      t1: {
        key: '⇥',
        icon: '⚡',
        label: 'không sao được mà trước giờ mọi người vẫn dùng như thế nào',
        fullText: 'không sao được mà trước giờ mọi người vẫn dùng như thế nào',
        kind: 'diacritic'
      },
      t2: {
        key: '⇥⇥',
        icon: '✨',
        label: 'Không sao đâu ạ, trước giờ mọi người vẫn sử dụng như vậy mà.',
        fullText: 'Không sao đâu ạ, trước giờ mọi người vẫn sử dụng như vậy mà.',
        kind: 'polish'
      },
      t3: {
        key: '⌥3',
        icon: '🔮',
        label: 'bạn nhé',
        fullText: 'Không sao đâu ạ, trước giờ mọi người vẫn sử dụng như vậy mà bạn nhé.',
        kind: 'predict'
      },
      status: '⚡ Teencode'
    }
  };

  let currentSuggestions = [];
  let lastTabTime = 0;
  let voiceInterval = null;

  function smartEllipsis(str, maxLen = 58) {
    if (!str || str.length <= maxLen) return str;
    return '…' + str.slice(-(maxLen - 1)).trimStart();
  }

  function updateSuggestions(rawText, forcedScenarioKey = null) {
    if (window.triggerWavePulse) window.triggerWavePulse();

    const trimmed = rawText.trim().toLowerCase();
    let matched = forcedScenarioKey ? demoScenarios[forcedScenarioKey] : null;

    if (!matched) {
      if (trimmed.includes('nhận diện') || trimmed.includes('giọng nói') || trimmed.includes('thao tác ai')) {
        matched = demoScenarios['voice_ai'];
      } else if (trimmed.includes('danh rat nhieu') || trimmed.includes('nghi mot lat') || trimmed.length > 85) {
        matched = demoScenarios['long_sentence'];
      } else if (trimmed.includes('she dont') || trimmed.includes('i goes') || trimmed.includes('dont know')) {
        matched = demoScenarios['en_grammar'];
      } else if (trimmed.includes('to dang') || trimmed.includes('khong cau')) {
        matched = demoScenarios['to dang lam viec'];
      } else if (trimmed.includes('salary') || trimmed.includes('calculatearrow') || trimmed.includes('subclass')) {
        matched = demoScenarios['ary'];
      } else if (trimmed.includes('ko sao') || trimmed.includes('trc gio') || trimmed.includes('ntn')) {
        matched = demoScenarios['ko sao ca'];
      } else if (trimmed.length > 0) {
        const diacritics = autoDiacriticMock(rawText);
        const polished = polishMock(rawText);
        matched = {
          hint: '💡 Đang phân tích trực tiếp câu bạn vừa gõ (Nhấn Tab-Tab để áp dụng ✨ AI Polish).',
          text: rawText,
          t1: { key: '⇥', icon: '⚡', label: smartEllipsis(diacritics), fullText: diacritics, kind: 'diacritic' },
          t2: { key: '⇥⇥', icon: '✨', label: smartEllipsis(polished), fullText: polished, kind: 'polish' },
          t3: { key: '⌥3', icon: '🔮', label: 'tiếp tục...', fullText: polished + ' ', kind: 'predict' },
          status: '⚡ Realtime'
        };
      }
    }

    if (!matched || trimmed.length === 0) {
      chipContainer.innerHTML = `
        <span style="font-size: 12px; color: #94a3b8; font-style: italic;">
          Gõ văn bản hoặc bấm nút 🎙️ để xem gợi ý 3 tầng tức thì...
        </span>
      `;
      if (statusLabel) statusLabel.textContent = 'Ready';
      currentSuggestions = [];
      return;
    }

    if (scenarioHint && matched.hint) {
      scenarioHint.textContent = matched.hint;
    }

    currentSuggestions = [matched.t1, matched.t2, matched.t3];

    chipContainer.innerHTML = '';
    currentSuggestions.forEach((item, index) => {
      const chip = document.createElement('div');
      chip.className = `hud-chip tier-${index + 1}`;
      chip.title = `Click để thay thế bằng: "${item.fullText}"`;
      chip.innerHTML = `
        <span class="chip-key">${item.key}</span>
        <span>${item.icon}</span>
        <span>${item.label}</span>
      `;
      chip.addEventListener('click', () => applySuggestion(item, index === 1));
      chipContainer.appendChild(chip);
    });

    if (statusLabel) statusLabel.textContent = matched.status;
  }

  function applySuggestion(item, withShimmer = false) {
    if (!item) return;

    if (withShimmer && editorBox && shimmerToast) {
      editorBox.classList.add('shimmer-active');
      shimmerToast.classList.add('visible');
      if (window.triggerWavePulse) window.triggerWavePulse(9.5, 500);

      setTimeout(() => {
        input.value = item.fullText;
        editorBox.classList.remove('shimmer-active');
        shimmerToast.classList.remove('visible');
        showAppliedStatus();
      }, 420);
      return;
    }

    input.value = item.fullText;
    if (window.triggerWavePulse) window.triggerWavePulse();
    showAppliedStatus();
  }

  function showAppliedStatus() {
    if (statusLabel) {
      const orig = statusLabel.textContent;
      statusLabel.textContent = '✓ Đã thay thế';
      statusLabel.style.color = '#34d399';
      setTimeout(() => {
        statusLabel.textContent = orig;
        statusLabel.style.color = '#7dd3fc';
      }, 1300);
    }
  }

  function autoDiacriticMock(str) {
    const map = {
      'ko': 'không', 'dc': 'được', 'trc': 'trước', 'ntn': 'như thế nào',
      'mn': 'mọi người', 'to': 'tôi', 'toi': 'tôi', 'dang': 'đang', 'lam': 'làm', 'viec': 'việc',
      'thuong': 'thương', 'thuyet': 'thuyết', 'viet': 'Việt', 'nam': 'Nam',
      'rat': 'rất', 'tot': 'tốt', 'chuan': 'chuẩn', 'hom': 'hôm', 'nay': 'nay',
      'khong': 'không', 'cau': 'dấu', 'dont': "doesn't", 'goes': 'went'
    };
    return str.split(' ').map(w => map[w.toLowerCase()] || w).join(' ');
  }

  function polishMock(str) {
    let cleaned = autoDiacriticMock(str)
      .replace(/hình như là\s+/gi, '')
      .replace(/cái phần\s+/gi, '')
      .replace(/nhưng mà\s+/gi, 'nhưng ')
      .trim();
    if (!cleaned) return str;
    cleaned = cleaned.charAt(0).toUpperCase() + cleaned.slice(1);
    if (!/[.!?]$/.test(cleaned)) cleaned += '.';
    return cleaned;
  }

  // Keyboard shortcut handler in editor (supports Tab and Double-Tab / Tab-Tab)
  input.addEventListener('keydown', (e) => {
    if (e.key === 'Tab' && currentSuggestions.length >= 2) {
      e.preventDefault();
      const now = performance.now();
      if (now - lastTabTime < 450) {
        // Tab-Tab -> Tier 2 AI Polish with Shimmer Sweep!
        lastTabTime = 0;
        applySuggestion(currentSuggestions[1], true);
      } else {
        lastTabTime = now;
        applySuggestion(currentSuggestions[0], false);
      }
    } else if (e.altKey && e.key === '1' && currentSuggestions.length >= 1) {
      e.preventDefault();
      applySuggestion(currentSuggestions[0], false);
    } else if (e.altKey && e.key === '2' && currentSuggestions.length >= 2) {
      e.preventDefault();
      applySuggestion(currentSuggestions[1], true);
    } else if (e.altKey && e.key === '3' && currentSuggestions.length >= 3) {
      e.preventDefault();
      applySuggestion(currentSuggestions[2], false);
    } else if (e.key === 'Escape') {
      hudContainer.style.opacity = hudContainer.style.opacity === '0' ? '1' : '0';
    }
  });

  input.addEventListener('input', (e) => {
    updateSuggestions(e.target.value);
  });

  // Preset buttons
  presetButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      if (voiceInterval) {
        clearInterval(voiceInterval);
        voiceInterval = null;
        if (voiceSimBtn) {
          voiceSimBtn.classList.remove('recording');
          voiceSimBtn.innerHTML = '<span>🎙️ Thử đọc giọng nói (⌥Space)</span>';
        }
      }

      presetButtons.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');

      const scenarioKey = btn.getAttribute('data-preset');
      const scenario = demoScenarios[scenarioKey];
      if (scenario) {
        input.value = scenario.text;
        updateSuggestions(scenario.text, scenarioKey);
      }
    });
  });

  // Simulated Voice Dictation Button
  if (voiceSimBtn) {
    voiceSimBtn.addEventListener('click', () => {
      if (voiceInterval) {
        clearInterval(voiceInterval);
        voiceInterval = null;
      }

      presetButtons.forEach(b => {
        b.classList.toggle('active', b.getAttribute('data-preset') === 'voice_ai');
      });

      const spokenChunks = [
        'Hình như là',
        'Hình như là sau khi anh nhận diện',
        'Hình như là sau khi anh nhận diện cái phần giọng nói sang',
        'Hình như là sau khi anh nhận diện cái phần giọng nói sang… (nghỉ 1s nghĩ từ tiếng Anh)',
        'Hình như là sau khi anh nhận diện cái phần giọng nói sang nhưng mà đúng ra đến có 1 thao tác AI'
      ];

      let step = 0;
      input.value = '';
      voiceSimBtn.classList.add('recording');
      voiceSimBtn.innerHTML = '<span>🔴 Đang nghe (Chờ ngắt nói 2.2s)...</span>';
      if (statusLabel) {
        statusLabel.textContent = '🎙️ Listening...';
        statusLabel.style.color = '#f87171';
      }

      voiceInterval = setInterval(() => {
        if (window.triggerWavePulse) window.triggerWavePulse(9.0, 260);
        if (step < spokenChunks.length) {
          input.value = spokenChunks[step];
          step++;
        } else {
          clearInterval(voiceInterval);
          voiceInterval = null;
          voiceSimBtn.classList.remove('recording');
          voiceSimBtn.innerHTML = '<span>🎙️ Thử đọc giọng nói (⌥Space)</span>';
          if (statusLabel) statusLabel.style.color = '#7dd3fc';
          // Auto-fill normalized transcript & present ✨ AI Polish chip
          input.value = 'Sau khi nhận diện cái phần giọng nói sang text nhưng mà đúng ra cần có 1 thao tác AI.';
          updateSuggestions(input.value, 'voice_ai');
        }
      }, 420);
    });
  }

  // Mode badge click in HUD
  if (modeBadge) {
    modeBadge.addEventListener('click', () => {
      if (modeBadge.textContent === 'VI·T') {
        modeBadge.textContent = 'VI·V';
        modeBadge.style.color = '#c084fc';
      } else if (modeBadge.textContent === 'VI·V') {
        modeBadge.textContent = 'EN';
        modeBadge.style.color = '#94a3b8';
      } else {
        modeBadge.textContent = 'VI·T';
        modeBadge.style.color = '#38bdf8';
      }
      if (window.triggerWavePulse) window.triggerWavePulse();
    });
  }

  // Initial populate with default voice_ai scenario
  const defaultScenario = demoScenarios['voice_ai'];
  if (defaultScenario) {
    input.value = defaultScenario.text;
    updateSuggestions(defaultScenario.text, 'voice_ai');
  }
}

/* ==============================================================================
   3. Menu Bar Status Badge Toggle Simulation
   ============================================================================== */
function initMenuBarBadgeToggle() {
  const badge = document.getElementById('menuBarBadge');
  if (!badge) return;

  const states = ['[• VI·T]', '[• VI·V]', '[• EN]'];
  let idx = 0;

  badge.addEventListener('click', () => {
    idx = (idx + 1) % states.length;
    badge.textContent = states[idx];
    if (idx === 0) {
      badge.style.color = '#38bdf8';
      badge.style.borderColor = 'rgba(56, 189, 248, 0.4)';
    } else if (idx === 1) {
      badge.style.color = '#c084fc';
      badge.style.borderColor = 'rgba(192, 132, 252, 0.4)';
    } else {
      badge.style.color = '#94a3b8';
      badge.style.borderColor = 'rgba(148, 163, 184, 0.3)';
    }
  });
}

/* ==============================================================================
   4. Copy to Clipboard Utility
   ============================================================================== */
function initCopyButtons() {
  const copyButtons = document.querySelectorAll('.copy-btn');
  copyButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      const targetSelector = btn.getAttribute('data-copy-target');
      const targetElement = document.querySelector(targetSelector);
      if (targetElement) {
        const textToCopy = targetElement.textContent.trim();
        navigator.clipboard.writeText(textToCopy).then(() => {
          const originalText = btn.textContent;
          btn.textContent = 'Đã sao chép!';
          btn.style.color = '#34d399';
          setTimeout(() => {
            btn.textContent = originalText;
            btn.style.color = '';
          }, 1500);
        });
      }
    });
  });
}
