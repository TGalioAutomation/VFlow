/**
 * VFlow — Visual-First Flagship Landing Page
 * Auto-Playing Killer Feature Showcase, Tab-Tab Shimmer & 120fps Silk Sine-Wave HUD
 */

document.addEventListener('DOMContentLoaded', () => {
  initSineWaveCanvas();
  initInteractiveDemo();
  initMenuBarBadgeToggle();
  initCopyButtons();
});

/* ==============================================================================
   1. 120fps Silk Sine-Wave Canvas Engine
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

    ctx.beginPath();
    ctx.strokeStyle = 'rgba(168, 85, 247, 0.78)';
    ctx.lineWidth = 1.4;
    for (let x = 0; x <= width; x++) {
      const y = midY + Math.sin((x * 0.12) + (phase * 1.3)) * (amplitude * 0.78);
      if (x === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.stroke();

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

  window.triggerWavePulse = function(boost = 8.0, durationMs = 320) {
    targetAmplitude = boost;
    setTimeout(() => {
      targetAmplitude = 4.5;
    }, durationMs);
  };
}

/* ==============================================================================
   2. Visual-First Interactive & Auto-Playing Showcase
   ============================================================================== */
function initInteractiveDemo() {
  const input = document.getElementById('demoInput');
  const editorBox = document.getElementById('demoEditorBox');
  const beforeBadge = document.getElementById('demoBeforeBadge');
  const afterBadge = document.getElementById('demoAfterBadge');
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
      before: '❌ Văn nói: "Hình như là cái phần giọng nói sang nhưng mà cần 1 thao tác AI"',
      after: '✅ Nhấn Tab-Tab ➔ "Sau khi nhận diện giọng nói sang text, cần một thao tác AI."',
      text: 'Hình như là sau khi nhận diện cái phần giọng nói sang nhưng mà đúng ra cần có 1 thao tác AI',
      t1: {
        key: '⇥',
        icon: '⚡',
        label: 'Sau khi nhận diện cái phần giọng nói sang text...',
        fullText: 'Sau khi nhận diện cái phần giọng nói sang text nhưng mà đúng ra cần có 1 thao tác AI.',
      },
      t2: {
        key: '⇥⇥',
        icon: '✨',
        label: 'Sau khi nhận diện giọng nói sang text, cần có một thao tác AI.',
        fullText: 'Sau khi nhận diện giọng nói sang text, cần có một thao tác AI.',
      },
      t3: {
        key: '⌥3',
        icon: '🔮',
        label: 'tự động',
        fullText: 'Sau khi nhận diện giọng nói sang text, cần có một thao tác AI tự động.',
      },
      status: '🎙️ Voice ➔ ✨ AI'
    },
    'ary': {
      before: '❌ Bộ gõ cũ: sảlảy, arổw, sẻvice, subclás',
      after: '✅ VFlow giữ nguyên: salary, arrow, service, subclass',
      text: 'const salary = calculateArrow(service, subclass);',
      t1: {
        key: '⇥',
        icon: '⚡',
        label: 'const salary = calculateArrow(service, subclass);',
        fullText: 'const salary = calculateArrow(service, subclass);',
      },
      t2: {
        key: '⇥⇥',
        icon: '✨',
        label: '🛡️ Không nhảy dấu Tiếng Anh & Code (0 cần tắt bộ gõ)',
        fullText: 'const salary = calculateArrow(service, subclass);',
      },
      t3: {
        key: '⌥3',
        icon: '🔮',
        label: 'return salary;',
        fullText: 'const salary = calculateArrow(service, subclass);\nreturn salary;',
      },
      status: '🛡️ Auto-Escape'
    },
    'en_grammar': {
      before: '❌ Gõ vội: "to dang lam viec. she dont know how to fix"',
      after: '✅ Nhấn Tab-Tab ➔ "Tôi đang làm việc. She doesn\'t know how to fix it."',
      text: 'to dang lam viec. she dont know how to fix this bug',
      t1: {
        key: '⇥',
        icon: '⚡',
        label: "tôi đang làm việc. She doesn't know how to fix",
        fullText: "tôi đang làm việc. She doesn't know how to fix this bug",
      },
      t2: {
        key: '⇥⇥',
        icon: '✨',
        label: "Tôi đang làm việc. She doesn't know how to fix this bug.",
        fullText: "Tôi đang làm việc. She doesn't know how to fix this bug.",
      },
      t3: {
        key: '⌥3',
        icon: '🔮',
        label: 'right now',
        fullText: "Tôi đang làm việc. She doesn't know how to fix this bug right now.",
      },
      status: '🇬🇧🇻🇳 Ngữ pháp'
    },
    'long_sentence': {
      before: '❌ Cũ: Gõ câu dài hoặc chấm câu "." là mất ngữ cảnh',
      after: '✅ VFlow: Giữ trọn cả đoạn dài & thu gọn "…" thông minh',
      text: 'hom nay toi da danh nhieu thoi gian kiem tra he thong. khi nghi mot lat roi go tiep',
      t1: {
        key: '⇥',
        icon: '⚡',
        label: '…khi nghỉ một lát rồi gõ tiếp',
        fullText: 'Hôm nay tôi đã dành nhiều thời gian kiểm tra hệ thống. Khi nghỉ một lát rồi gõ tiếp',
      },
      t2: {
        key: '⇥⇥',
        icon: '✨',
        label: '…Khi nghỉ một lát rồi gõ tiếp, ngữ cảnh vẫn chính xác.',
        fullText: 'Hôm nay tôi đã dành nhiều thời gian kiểm tra hệ thống. Khi nghỉ một lát rồi gõ tiếp, ngữ cảnh vẫn chính xác.',
      },
      t3: {
        key: '⌥3',
        icon: '🔮',
        label: '100%',
        fullText: 'Hôm nay tôi đã dành nhiều thời gian kiểm tra hệ thống. Khi nghỉ một lát rồi gõ tiếp, ngữ cảnh vẫn chính xác 100%.',
      },
      status: '🧠 Câu dài'
    }
  };

  let currentSuggestions = [];
  let lastTabTime = 0;
  let voiceInterval = null;
  let autoCycleTimer = null;
  let userInteracted = false;
  const scenarioOrder = ['voice_ai', 'ary', 'en_grammar', 'long_sentence'];
  let currentScenarioIndex = 0;

  function smartEllipsis(str, maxLen = 52) {
    if (!str || str.length <= maxLen) return str;
    return '…' + str.slice(-(maxLen - 1)).trimStart();
  }

  function updateSuggestions(rawText, forcedScenarioKey = null) {
    if (window.triggerWavePulse) window.triggerWavePulse();

    const trimmed = rawText.trim().toLowerCase();
    let matched = forcedScenarioKey ? demoScenarios[forcedScenarioKey] : null;

    if (!matched) {
      if (trimmed.includes('nhận diện') || trimmed.includes('giọng nói')) {
        matched = demoScenarios['voice_ai'];
      } else if (trimmed.includes('salary') || trimmed.includes('calculatearrow')) {
        matched = demoScenarios['ary'];
      } else if (trimmed.includes('she dont') || trimmed.includes('to dang')) {
        matched = demoScenarios['en_grammar'];
      } else if (trimmed.includes('nghi mot lat') || trimmed.length > 70) {
        matched = demoScenarios['long_sentence'];
      } else if (trimmed.length > 0) {
        const polished = rawText.charAt(0).toUpperCase() + rawText.slice(1) + (/[.!?]$/.test(rawText) ? '' : '.');
        matched = {
          before: '❌ Đang gõ: "' + smartEllipsis(rawText, 36) + '"',
          after: '✅ Nhấn Tab-Tab để AI chuẩn hóa câu',
          text: rawText,
          t1: { key: '⇥', icon: '⚡', label: smartEllipsis(rawText), fullText: rawText },
          t2: { key: '⇥⇥', icon: '✨', label: smartEllipsis(polished), fullText: polished },
          t3: { key: '⌥3', icon: '🔮', label: 'tiếp tục...', fullText: polished + ' ' },
          status: '⚡ Live'
        };
      }
    }

    if (!matched || trimmed.length === 0) {
      chipContainer.innerHTML = `<span style="font-size: 12px; color: #94a3b8;">Gõ thử hoặc bấm nút kịch bản phía trên...</span>`;
      currentSuggestions = [];
      return;
    }

    if (beforeBadge && matched.before) beforeBadge.textContent = matched.before;
    if (afterBadge && matched.after) afterBadge.textContent = matched.after;

    currentSuggestions = [matched.t1, matched.t2, matched.t3];

    chipContainer.innerHTML = '';
    currentSuggestions.forEach((item, index) => {
      const chip = document.createElement('div');
      chip.className = `hud-chip tier-${index + 1}`;
      chip.title = `Click để thay thế: "${item.fullText}"`;
      chip.innerHTML = `
        <span class="chip-key">${item.key}</span>
        <span>${item.icon}</span>
        <span>${item.label}</span>
      `;
      chip.addEventListener('click', () => {
        stopAutoCycle();
        applySuggestion(item, index === 1);
      });
      chipContainer.appendChild(chip);
    });

    if (statusLabel) statusLabel.textContent = matched.status;
  }

  function applySuggestion(item, withShimmer = false) {
    if (!item) return;

    if (withShimmer && editorBox && shimmerToast) {
      editorBox.classList.add('shimmer-active');
      shimmerToast.classList.add('visible');
      if (window.triggerWavePulse) window.triggerWavePulse(9.5, 450);

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
      statusLabel.textContent = '✓ Đã sửa xong';
      statusLabel.style.color = '#34d399';
      setTimeout(() => {
        statusLabel.textContent = orig;
        statusLabel.style.color = '#7dd3fc';
      }, 1200);
    }
  }

  function stopAutoCycle() {
    userInteracted = true;
    if (autoCycleTimer) {
      clearInterval(autoCycleTimer);
      autoCycleTimer = null;
    }
  }

  // Auto-cycle visual showcase until user interacts
  autoCycleTimer = setInterval(() => {
    if (userInteracted || voiceInterval) return;
    // First apply Tier 2 shimmer on current scenario, then switch scenario
    if (currentSuggestions.length >= 2) {
      applySuggestion(currentSuggestions[1], true);
    }
    setTimeout(() => {
      if (userInteracted || voiceInterval) return;
      currentScenarioIndex = (currentScenarioIndex + 1) % scenarioOrder.length;
      const nextKey = scenarioOrder[currentScenarioIndex];
      presetButtons.forEach(b => {
        b.classList.toggle('active', b.getAttribute('data-preset') === nextKey);
      });
      const sc = demoScenarios[nextKey];
      if (sc) {
        input.value = sc.text;
        updateSuggestions(sc.text, nextKey);
      }
    }, 1800);
  }, 4600);

  input.addEventListener('focus', stopAutoCycle);
  input.addEventListener('input', (e) => {
    stopAutoCycle();
    updateSuggestions(e.target.value);
  });

  input.addEventListener('keydown', (e) => {
    stopAutoCycle();
    if (e.key === 'Tab' && currentSuggestions.length >= 2) {
      e.preventDefault();
      const now = performance.now();
      if (now - lastTabTime < 450) {
        lastTabTime = 0;
        applySuggestion(currentSuggestions[1], true);
      } else {
        lastTabTime = now;
        applySuggestion(currentSuggestions[0], false);
      }
    }
  });

  presetButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      stopAutoCycle();
      if (voiceInterval) {
        clearInterval(voiceInterval);
        voiceInterval = null;
        if (voiceSimBtn) {
          voiceSimBtn.classList.remove('recording');
          voiceSimBtn.innerHTML = '<span>🎙️ Chạy thử Voice AI</span>';
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

  if (voiceSimBtn) {
    voiceSimBtn.addEventListener('click', () => {
      stopAutoCycle();
      if (voiceInterval) {
        clearInterval(voiceInterval);
        voiceInterval = null;
      }

      presetButtons.forEach(b => {
        b.classList.toggle('active', b.getAttribute('data-preset') === 'voice_ai');
      });

      const spokenChunks = [
        'Hình như là sau khi nhận diện...',
        'Hình như là sau khi nhận diện cái phần giọng nói sang… (nghỉ 2.2s)',
        'Hình như là sau khi nhận diện cái phần giọng nói sang nhưng mà đúng ra cần có 1 thao tác AI'
      ];

      let step = 0;
      input.value = '';
      voiceSimBtn.classList.add('recording');
      voiceSimBtn.innerHTML = '<span>🔴 Đang nghe (2.2s)...</span>';

      voiceInterval = setInterval(() => {
        if (window.triggerWavePulse) window.triggerWavePulse(9.0, 260);
        if (step < spokenChunks.length) {
          input.value = spokenChunks[step];
          step++;
        } else {
          clearInterval(voiceInterval);
          voiceInterval = null;
          voiceSimBtn.classList.remove('recording');
          voiceSimBtn.innerHTML = '<span>🎙️ Chạy thử Voice AI</span>';
          updateSuggestions(input.value, 'voice_ai');
          setTimeout(() => {
            if (currentSuggestions[1]) applySuggestion(currentSuggestions[1], true);
          }, 900);
        }
      }, 480);
    });
  }

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
    });
  }

  const defaultScenario = demoScenarios['voice_ai'];
  if (defaultScenario) {
    input.value = defaultScenario.text;
    updateSuggestions(defaultScenario.text, 'voice_ai');
  }
}

/* ==============================================================================
   3. Menu Bar Badge Toggle & Copy Button
   ============================================================================== */
function initMenuBarBadgeToggle() {
  const badge = document.getElementById('menuBarBadge');
  if (!badge) return;

  const states = ['[• VI·T]', '[• VI·V]', '[• EN]'];
  let idx = 0;
  badge.addEventListener('click', () => {
    idx = (idx + 1) % states.length;
    badge.textContent = states[idx];
  });
}

function initCopyButtons() {
  const copyButtons = document.querySelectorAll('.copy-btn');
  copyButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      const targetSelector = btn.getAttribute('data-copy-target');
      const targetElement = document.querySelector(targetSelector);
      if (targetElement) {
        navigator.clipboard.writeText(targetElement.textContent.trim()).then(() => {
          const orig = btn.textContent;
          btn.textContent = 'Đã sao chép!';
          setTimeout(() => { btn.textContent = orig; }, 1400);
        });
      }
    });
  });
}
