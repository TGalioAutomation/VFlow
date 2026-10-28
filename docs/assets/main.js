/**
 * VFlow — Flagship Promotional Landing Website
 * Interactive Caret HUD Simulation & 120fps Silk Sine-Wave Animation
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
  let animationFrameId;
  let phase = 0;
  let amplitude = 4.5;
  let targetAmplitude = 4.5;

  // Retina scale
  const dpr = window.devicePixelRatio || 2;
  const width = 52;
  const height = 22;
  canvas.width = width * dpr;
  canvas.height = height * dpr;
  ctx.scale(dpr, dpr);

  function renderWave() {
    ctx.clearRect(0, 0, width, height);

    // Smooth amplitude damping
    amplitude += (targetAmplitude - amplitude) * 0.1;

    const midY = height / 2;

    // Layer 1: Violet Sine Wave (Back layer)
    ctx.beginPath();
    ctx.strokeStyle = 'rgba(168, 85, 247, 0.75)';
    ctx.lineWidth = 1.4;
    for (let x = 0; x <= width; x++) {
      const y = midY + Math.sin((x * 0.12) + (phase * 1.3)) * (amplitude * 0.75);
      if (x === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.stroke();

    // Layer 2: Cyan Sine Wave (Front layer)
    ctx.beginPath();
    ctx.strokeStyle = 'rgba(56, 189, 248, 0.95)';
    ctx.lineWidth = 1.6;
    for (let x = 0; x <= width; x++) {
      const y = midY + Math.sin((x * 0.15) + phase) * amplitude;
      if (x === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.stroke();

    phase += 0.08;
    animationFrameId = requestAnimationFrame(renderWave);
  }

  renderWave();

  // Pulse wave amplitude when typing
  window.triggerWavePulse = function() {
    targetAmplitude = 7.5;
    setTimeout(() => {
      targetAmplitude = 4.5;
    }, 280);
  };
}

/* ==============================================================================
   2. Interactive Live Typing Demo & 3-Tier Suggestion Engine
   ============================================================================== */
function initInteractiveDemo() {
  const input = document.getElementById('demoInput');
  const hudContainer = document.getElementById('simulatedHud');
  const chipContainer = document.getElementById('hudChips');
  const statusLabel = document.getElementById('hudStatus');
  const presetButtons = document.querySelectorAll('.preset-btn');
  const modeBadge = document.getElementById('hudMode');

  if (!input || !chipContainer) return;

  // Corpus database for demo suggestions
  const demoScenarios = {
    'to dang lam viec': {
      text: 'to dang lam viec',
      t1: { key: '⇥', icon: '⚡', text: 'tôi đang làm việc', kind: 'diacritic' },
      t2: { key: '⌥2', icon: '✨', text: 'Tôi đang làm việc rất hiệu quả.', kind: 'polish' },
      t3: { key: '⌥3', icon: '🔮', text: 'hôm nay', kind: 'predict' },
      status: '✨ AI Polish'
    },
    'ary': {
      text: 'salary dictionary secondary',
      t1: { key: '⇥', icon: '⚡', text: 'salary', kind: 'diacritic' },
      t2: { key: '⌥2', icon: '✨', text: 'English Escape: "ary" preserved', kind: 'polish' },
      t3: { key: '⌥3', icon: '🔮', text: 'increase', kind: 'predict' },
      status: '🛡️ EN Auto-Escape'
    },
    'thuong thuyet': {
      text: 'thuong thuyet',
      t1: { key: '⇥', icon: '⚡', text: 'thương thuyết', kind: 'diacritic' },
      t2: { key: '⌥2', icon: '✨', text: 'tiến hành thương thuyết', kind: 'polish' },
      t3: { key: '⌥3', icon: '🔮', text: 'với đối tác', kind: 'predict' },
      status: '✨ Suggestion'
    },
    'ko sao ca': {
      text: 'ko sao ca',
      t1: { key: '⇥', icon: '⚡', text: 'không sao cả', kind: 'diacritic' },
      t2: { key: '⌥2', icon: '✨', text: 'Dạ không sao cả ạ!', kind: 'polish' },
      t3: { key: '⌥3', icon: '🔮', text: 'đâu bạn nhé', kind: 'predict' },
      status: '⚡ Teencode'
    },
    'vieest dduocj': {
      text: 'vieest dduocj',
      t1: { key: '⇥', icon: '⚡', text: 'viết được', kind: 'diacritic' },
      t2: { key: '⌥2', icon: '✨', text: 'viết được tiếng Việt', kind: 'polish' },
      t3: { key: '⌥3', icon: '🔮', text: 'dễ dàng', kind: 'predict' },
      status: '⚡ Free-Order'
    },
    'subclass': {
      text: 'class Point extends Node',
      t1: { key: '⇥', icon: '⚡', text: 'class Point', kind: 'diacritic' },
      t2: { key: '⌥2', icon: '✨', text: 'Code keyword: zero conflict', kind: 'polish' },
      t3: { key: '⌥3', icon: '🔮', text: '{ constructor }', kind: 'predict' },
      status: '🛡️ Dev Mode'
    }
  };

  let currentSuggestions = [];

  function updateSuggestions(rawText) {
    if (window.triggerWavePulse) window.triggerWavePulse();

    const trimmed = rawText.trim().toLowerCase();

    // Check if matching any pre-built scenario
    let matched = null;
    if (trimmed.includes('to dang') || trimmed.includes('tooi dang') || trimmed === 'to' || trimmed === 'to dang lam viec') {
      matched = demoScenarios['to dang lam viec'];
    } else if (trimmed.includes('ary') || trimmed.includes('salary')) {
      matched = demoScenarios['ary'];
    } else if (trimmed.includes('thuong thuyet') || trimmed.includes('thuong')) {
      matched = demoScenarios['thuong thuyet'];
    } else if (trimmed.includes('ko sao') || trimmed.includes('ko') || trimmed.includes('dc')) {
      matched = demoScenarios['ko sao ca'];
    } else if (trimmed.includes('vieest') || trimmed.includes('dduocj')) {
      matched = demoScenarios['vieest dduocj'];
    } else if (trimmed.includes('class') || trimmed.includes('subclass') || trimmed.includes('const')) {
      matched = demoScenarios['subclass'];
    } else if (trimmed.length > 0) {
      // Dynamic fallback based on words
      matched = {
        text: rawText,
        t1: { key: '⇥', icon: '⚡', text: autoDiacriticMock(rawText), kind: 'diacritic' },
        t2: { key: '⌥2', icon: '✨', text: polishMock(rawText), kind: 'polish' },
        t3: { key: '⌥3', icon: '🔮', text: 'tiếp tục...', kind: 'predict' },
        status: '⚡ Realtime'
      };
    }

    if (!matched || trimmed.length === 0) {
      chipContainer.innerHTML = `
        <span style="font-size: 12px; color: #94a3b8; font-style: italic;">
          Gõ văn bản để xem gợi ý tức thì...
        </span>
      `;
      if (statusLabel) statusLabel.textContent = 'Ready';
      currentSuggestions = [];
      return;
    }

    currentSuggestions = [matched.t1, matched.t2, matched.t3];

    // Render chips
    chipContainer.innerHTML = '';
    currentSuggestions.forEach((item, index) => {
      const chip = document.createElement('div');
      chip.className = `hud-chip tier-${index + 1}`;
      chip.innerHTML = `
        <span class="chip-key">${item.key}</span>
        <span>${item.icon}</span>
        <span>${item.text}</span>
      `;
      chip.addEventListener('click', () => applySuggestion(item));
      chipContainer.appendChild(chip);
    });

    if (statusLabel) statusLabel.textContent = matched.status;
  }

  function applySuggestion(item) {
    if (!item) return;
    input.value = item.text;
    if (window.triggerWavePulse) window.triggerWavePulse();

    // Visual feedback
    if (statusLabel) {
      const orig = statusLabel.textContent;
      statusLabel.textContent = '✓ Đã điền';
      statusLabel.style.color = '#34d399';
      setTimeout(() => {
        statusLabel.textContent = orig;
        statusLabel.style.color = '#7dd3fc';
      }, 1200);
    }

    updateSuggestions(input.value);
  }

  function autoDiacriticMock(str) {
    const map = {
      'ko': 'không', 'dc': 'được', 'trc': 'trước', 'ntn': 'như thế nào',
      'mn': 'mọi người', 'to': 'tôi', 'dang': 'đang', 'lam': 'làm', 'viec': 'việc',
      'thuong': 'thương', 'thuyet': 'thuyết', 'viet': 'Việt', 'nam': 'Nam',
      'rat': 'rất', 'tot': 'tốt', 'chuan': 'chuẩn', 'hoa': 'hòa'
    };
    return str.split(' ').map(w => map[w.toLowerCase()] || w).join(' ');
  }

  function polishMock(str) {
    const diacritics = autoDiacriticMock(str);
    if (!diacritics.endsWith('.')) {
      return diacritics.charAt(0).toUpperCase() + diacritics.slice(1) + '.';
    }
    return diacritics;
  }

  // Keyboard shortcut handler in editor
  input.addEventListener('keydown', (e) => {
    // Tab or Option+1 / Alt+1 -> Select Tier 1
    if ((e.key === 'Tab' || (e.altKey && e.key === '1')) && currentSuggestions.length >= 1) {
      e.preventDefault();
      applySuggestion(currentSuggestions[0]);
    } else if (e.altKey && e.key === '2' && currentSuggestions.length >= 2) {
      e.preventDefault();
      applySuggestion(currentSuggestions[1]);
    } else if (e.altKey && e.key === '3' && currentSuggestions.length >= 3) {
      e.preventDefault();
      applySuggestion(currentSuggestions[2]);
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
      presetButtons.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');

      const scenarioKey = btn.getAttribute('data-preset');
      const scenario = demoScenarios[scenarioKey];
      if (scenario) {
        input.value = scenario.text;
        updateSuggestions(scenario.text);
      }
    });
  });

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

  // Initial populate with default scenario
  const defaultScenario = demoScenarios['to dang lam viec'];
  if (defaultScenario) {
    input.value = defaultScenario.text;
    updateSuggestions(defaultScenario.text);
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
          btn.textContent = 'Copied!';
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
