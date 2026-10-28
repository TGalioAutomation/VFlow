#!/usr/bin/env python3
"""
VFlow Demo & Tutorial Video Generator
Production 1080p Video + Poster + GIF for VFlow
"""

import os
import sys
import math
import subprocess
import wave
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

WIDTH = 1920
HEIGHT = 1080
FPS = 30
DURATION_SEC = 31.0
TOTAL_FRAMES = int(FPS * DURATION_SEC)  # 930 frames

WORKSPACE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(WORKSPACE_DIR, "docs", "assets")
SCRIPTS_DIR = os.path.join(WORKSPACE_DIR, "scripts")

# Fonts
FONT_SFNS = "/System/Library/Fonts/SFNS.ttf"
FONT_ARIAL_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_ARIAL = "/System/Library/Fonts/Supplemental/Arial.ttf"
FONT_MENLO = "/System/Library/Fonts/Menlo.ttc"

# Glyph sanitizer to guarantee 0 missing-glyph boxes (tofu) in Arial / Menlo
_GLYPH_MAP = {
    "⇥ Tab": "Phím Tab",
    "⌥ Option": "Option",
    "⇥⇥": "Tab-Tab",
    "⇥": "Tab",
    "⌥Space": "Opt+Space",
    "⌥⌘T": "Opt+Cmd+T",
    "⌥⌘V": "Opt+Cmd+V",
    "⌥⌘E": "Opt+Cmd+E",
    "⌥3": "Opt+3",
    "⌥": "Opt",
    "⌘": "Cmd+",
    "": "Mac",
    "➔": "→",
    "▶": "►",
    "✓": "•",
    "🔒": "•",
    "📁": "►",
    "♿": "•",
    "🎙️": "•",
    "🎙": "•",
    "⚙️": "•",
    "🚪": "→",
    "❌": "[X]",
    "✅": "[OK]",
    "⚠️": "[!]",
    "✨": "►",
    "⚡": "►",
    "💡": "•",
    "🔮": "►",
    "⏱️": "•",
    "🛡️": "•",
    "📰": "•",
    "🚀": "►",
}

def clean_str(s):
    if not isinstance(s, str):
        return s
    for k, v in _GLYPH_MAP.items():
        if k in s:
            s = s.replace(k, v)
    return s

_orig_draw_text = ImageDraw.ImageDraw.text
def _safe_draw_text(self, xy, text, *args, **kwargs):
    return _orig_draw_text(self, xy, clean_str(text), *args, **kwargs)
ImageDraw.ImageDraw.text = _safe_draw_text

_orig_getbbox = ImageFont.FreeTypeFont.getbbox
def _safe_getbbox(self, text, *args, **kwargs):
    return _orig_getbbox(self, clean_str(text), *args, **kwargs)
ImageFont.FreeTypeFont.getbbox = _safe_getbbox

def get_font(path, size, index=0):
    try:
        return ImageFont.truetype(path, size, index=index)
    except Exception:
        return ImageFont.load_default()

font_cache = {}
def f(name, size):
    key = (name, size)
    if key in font_cache:
        return font_cache[key]
    if name == "bold":
        res = get_font(FONT_ARIAL_BOLD, size)
    elif name == "mono":
        res = get_font(FONT_MENLO, size)
    elif name == "title":
        res = get_font(FONT_ARIAL_BOLD, size)
    else:
        res = get_font(FONT_ARIAL, size)
    font_cache[key] = res
    return res

# Colors
BG_PRIMARY = (6, 9, 15, 255)
CYAN = (56, 189, 248)
CYAN_BRIGHT = (125, 211, 252)
VIOLET = (168, 85, 247)
VIOLET_BRIGHT = (216, 180, 254)
EMERALD = (16, 185, 129)
RED = (248, 113, 113)
WHITE = (248, 250, 252)
MUTED = (148, 163, 184)
DIM = (100, 116, 139)

# Load Icons
app_icon_path = os.path.join(ASSETS_DIR, "app_icon_nobg.png")
voice_orb_path = os.path.join(ASSETS_DIR, "voice_orb_nobg.png")
neural_core_path = os.path.join(ASSETS_DIR, "neural_core_nobg.png")

img_app_icon = Image.open(app_icon_path).convert("RGBA") if os.path.exists(app_icon_path) else None
img_voice_orb = Image.open(voice_orb_path).convert("RGBA") if os.path.exists(voice_orb_path) else None
img_neural_core = Image.open(neural_core_path).convert("RGBA") if os.path.exists(neural_core_path) else None


# ==============================================================================
# AUDIO GENERATION
# ==============================================================================
def synthesize_audio(wav_path):
    print("Synthesizing studio-grade stereo audio track (31s, 44.1kHz)...")
    sr = 44100
    total_samples = int(sr * DURATION_SEC)
    t = np.linspace(0, DURATION_SEC, total_samples, endpoint=False)
    audio_l = np.zeros(total_samples, dtype=np.float32)
    audio_r = np.zeros(total_samples, dtype=np.float32)

    # 1. Ambient Background Music (Soft Apple Keynote Pad)
    # Chords: Fmaj7 (F, A, C, E), Dm7 (D, F, A, C), Bbmaj7 (Bb, D, F, A), Gm7 (G, Bb, D, F), Fmaj7
    chord_timeline = [
        (0.0, 5.0, [174.61, 220.00, 261.63, 329.63]),      # F3, A3, C4, E4
        (5.0, 12.0, [146.83, 174.61, 220.00, 261.63]),     # D3, F3, A3, C4
        (12.0, 19.0, [116.54, 146.83, 174.61, 220.00]),    # Bb2, D3, F3, A3
        (19.0, 26.0, [98.00, 116.54, 146.83, 174.61]),     # G2, Bb2, D3, F3
        (26.0, 31.0, [174.61, 220.00, 261.63, 349.23]),    # F3, A3, C4, F4
    ]

    for start_t, end_t, freqs in chord_timeline:
        s_idx = int(start_t * sr)
        e_idx = int(end_t * sr)
        t_chord = t[s_idx:e_idx] - start_t
        duration = end_t - start_t
        # Smooth envelope (fade in / out)
        env = np.ones_like(t_chord)
        fade_len = int(0.6 * sr)
        if len(env) > 2 * fade_len:
            env[:fade_len] = np.linspace(0, 1, fade_len)
            env[-fade_len:] = np.linspace(1, 0, fade_len)

        for i, freq in enumerate(freqs):
            # Rich warm synth wave (fundamental + soft harmonics + slight detuning)
            detune = 1.001 if i % 2 == 0 else 0.999
            wave_note = (
                0.6 * np.sin(2 * np.pi * freq * t_chord) +
                0.25 * np.sin(2 * np.pi * freq * detune * t_chord) +
                0.15 * np.sin(2 * np.pi * freq * 2 * t_chord)
            ) * env * 0.08
            pan = 0.4 + 0.2 * (i / len(freqs))  # Stereo spread
            audio_l[s_idx:e_idx] += wave_note * (1.0 - pan)
            audio_r[s_idx:e_idx] += wave_note * pan

    # Subtle pulsating rhythmic bass arpeggiator (modern tech pulse)
    arp_freqs = [87.31, 110.0, 130.81, 146.83]  # F2, A2, C3, D3
    beat_interval = 0.25  # 120 bpm eighth notes
    for bt in np.arange(0.5, 30.0, beat_interval):
        idx = int(bt * sr)
        arp_dur = int(0.12 * sr)
        if idx + arp_dur < total_samples:
            sub_t = np.linspace(0, 0.12, arp_dur)
            freq = arp_freqs[int(bt / beat_interval) % len(arp_freqs)]
            plk = np.sin(2 * np.pi * freq * sub_t) * np.exp(-sub_t * 30.0) * 0.04
            audio_l[idx:idx+arp_dur] += plk * 0.5
            audio_r[idx:idx+arp_dur] += plk * 0.5

    # Helper: Add mechanical click
    def add_click(at_time, vol=0.25):
        c_idx = int(at_time * sr)
        c_dur = int(0.025 * sr)
        if c_idx + c_dur < total_samples:
            c_t = np.linspace(0, 0.025, c_dur)
            decay = np.exp(-c_t * 260.0)
            noise = np.random.uniform(-1, 1, c_dur) * decay * 0.6
            tone = (np.sin(2 * np.pi * 1400 * c_t) + 0.5 * np.sin(2 * np.pi * 3200 * c_t)) * decay * 0.4
            snd = (noise + tone) * vol
            audio_l[c_idx:c_idx+c_dur] += snd * 0.5
            audio_r[c_idx:c_idx+c_dur] += snd * 0.5

    # Helper: Add chime / bell sweep
    def add_chime(at_time, freqs, vol=0.3, stagger=0.04):
        for i, fr in enumerate(freqs):
            ch_idx = int((at_time + i * stagger) * sr)
            ch_dur = int(1.2 * sr)
            if ch_idx + ch_dur < total_samples:
                ch_t = np.linspace(0, 1.2, ch_dur)
                decay = np.exp(-ch_t * 4.0)
                harm = (
                    0.7 * np.sin(2 * np.pi * fr * ch_t) +
                    0.25 * np.sin(2 * np.pi * fr * 2.756 * ch_t) +
                    0.15 * np.sin(2 * np.pi * fr * 5.404 * ch_t)
                ) * decay * vol
                pan = 0.3 + 0.4 * (i / max(1, len(freqs)-1))
                audio_l[ch_idx:ch_idx+ch_dur] += harm * (1.0 - pan)
                audio_r[ch_idx:ch_idx+ch_dur] += harm * pan

    # Helper: Add whoosh / sweep
    def add_whoosh(at_time, dur=0.6, vol=0.2):
        w_idx = int(at_time * sr)
        w_dur = int(dur * sr)
        if w_idx + w_dur < total_samples:
            w_t = np.linspace(0, dur, w_dur)
            env = np.sin(np.pi * w_t / dur)
            noise = np.random.uniform(-1, 1, w_dur) * env * vol
            audio_l[w_idx:w_idx+w_dur] += noise * 0.5
            audio_r[w_idx:w_idx+w_dur] += noise * 0.5

    # --- Chapter 1 SFX: Cài đặt (0 - 5s) ---
    add_click(2.0, vol=0.3)  # Permissions toggle 1
    add_click(2.6, vol=0.3)  # Permissions toggle 2
    add_click(3.8, vol=0.35) # Menu bar click

    # --- Chapter 2 SFX: Gõ code Auto-Escape (5 - 12s) ---
    # Mechanical clicks during typing "const salary = calculateArrow(service, subclass);"
    code_typing_times = np.linspace(6.2, 10.8, 48)
    for ct in code_typing_times:
        add_click(ct, vol=0.18 + 0.08 * np.random.rand())

    # --- Chapter 3 SFX: Sửa ngữ pháp Tab-Tab (12 - 19s) ---
    # Typing raw sentence
    raw_typing_times = np.linspace(12.8, 15.0, 35)
    for rt in raw_typing_times:
        add_click(rt, vol=0.18 + 0.08 * np.random.rand())

    # Two prominent Tab-Tab presses at 15.8s and 16.1s
    add_click(15.8, vol=0.45)
    add_click(16.1, vol=0.48)

    # Shimmer sweep magical chime at 16.25s
    add_chime(16.25, [880.0, 1046.5, 1318.5, 1568.0, 2093.0, 2637.0], vol=0.25, stagger=0.06)

    # --- Chapter 4 SFX: Giọng nói ⌥Space (19 - 26s) ---
    # Voice Activation Chime at 19.5s (D5 -> A5)
    add_chime(19.5, [587.33, 880.00], vol=0.4, stagger=0.14)
    # Speech stream ambient hum
    sp_idx = int(20.0 * sr)
    sp_dur = int(3.2 * sr)
    if sp_idx + sp_dur < total_samples:
        sp_t = np.linspace(0, 3.2, sp_dur)
        voice_hum = np.sin(2 * np.pi * 180 * sp_t) * (0.5 + 0.5 * np.sin(2 * np.pi * 3 * sp_t)) * 0.02
        audio_l[sp_idx:sp_idx+sp_dur] += voice_hum
        audio_r[sp_idx:sp_idx+sp_dur] += voice_hum
    # Silence watchdog finish chime at 23.4s
    add_chime(23.4, [1760.0, 2093.0], vol=0.35, stagger=0.08)
    # Post-polish inject click
    add_click(24.2, vol=0.3)

    # --- Chapter 5 SFX: Outro & Tự ẩn (26 - 31s) ---
    add_whoosh(26.0, dur=0.5, vol=0.15)
    add_chime(28.0, [523.25, 659.25, 783.99, 1046.5], vol=0.3, stagger=0.1)

    # Global normalization with headroom
    peak = max(np.max(np.abs(audio_l)), np.max(np.abs(audio_r)))
    if peak > 0:
        audio_l = (audio_l / peak) * 0.88
        audio_r = (audio_r / peak) * 0.88

    # Convert to 16-bit PCM
    audio_l_int = (audio_l * 32767).astype(np.int16)
    audio_r_int = (audio_r * 32767).astype(np.int16)
    stereo_interleaved = np.empty((total_samples * 2,), dtype=np.int16)
    stereo_interleaved[0::2] = audio_l_int
    stereo_interleaved[1::2] = audio_r_int

    with wave.open(wav_path, "wb") as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        wf.writeframes(stereo_interleaved.tobytes())

    print(f"Audio file saved: {wav_path} ({os.path.getsize(wav_path):,} bytes)")


# ==============================================================================
# DRAWING HELPERS
# ==============================================================================
def draw_rounded_card(img, bbox, fill_rgba, border_rgba=None, radius=18, border_width=2):
    """Draws a smooth rounded card with optional border onto an RGBA image."""
    card = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(card)
    d.rounded_rectangle(bbox, radius=radius, fill=fill_rgba, outline=border_rgba, width=border_width)
    img.alpha_composite(card)

def draw_window_chrome(img, x, y, width, height, title="", border_color=CYAN):
    """Draws macOS Sequoia dark window with traffic lights and glowing border."""
    draw_rounded_card(img, [x, y, x + width, y + height], (13, 19, 36, 235), border_rgba=(*border_color[:3], 140), radius=16, border_width=2)
    # Header bar
    head_h = 44
    head_card = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(head_card)
    hd.rounded_rectangle([x, y, x + width, y + head_h + 10], radius=16, fill=(20, 29, 52, 230))
    hd.rectangle([x, y + head_h, x + width, y + head_h + 10], fill=(20, 29, 52, 230))
    hd.line([x, y + head_h, x + width, y + head_h], fill=(255, 255, 255, 30), width=1)
    img.alpha_composite(head_card)

    d = ImageDraw.Draw(img)
    # Traffic lights
    d.ellipse([x + 18, y + 15, x + 32, y + 29], fill=(255, 95, 86, 255))
    d.ellipse([x + 38, y + 15, x + 52, y + 29], fill=(255, 189, 46, 255))
    d.ellipse([x + 58, y + 15, x + 72, y + 29], fill=(39, 201, 63, 255))

    if title:
        font_t = f("bold", 18)
        bb = font_t.getbbox(title)
        tw = bb[2] - bb[0]
        tx = x + (width - tw) // 2
        d.text((tx, y + 12), title, font=font_t, fill=(203, 213, 225, 255))

def draw_top_nav(img, current_ch_idx, progress_in_ch):
    """Draws top navigation bar showing 5 chapters with active pill glow."""
    d = ImageDraw.Draw(img)
    # Left VFlow pill
    draw_rounded_card(img, [50, 24, 195, 68], (15, 23, 42, 240), border_rgba=(*CYAN, 180), radius=22, border_width=2)
    d.ellipse([68, 41, 78, 51], fill=CYAN)
    d.text((88, 34), "VI · T", font=f("bold", 20), fill=WHITE)

    # 5 Chapters Breadcrumbs
    chapters = [
        ("01", "Cài Đặt 30s"),
        ("02", "Auto-Escape Code"),
        ("03", "Sửa Câu ⇥⇥"),
        ("04", "Giọng Nói ⌥Space"),
        ("05", "Tự Ẩn On-Device"),
    ]
    start_x = 230
    total_w = 1380
    pill_w = 260
    gap = 18

    for idx, (num, title) in enumerate(chapters):
        px = start_x + idx * (pill_w + gap)
        py = 24
        is_active = (idx == current_ch_idx)
        is_passed = (idx < current_ch_idx)

        if is_active:
            # Active glowing pill
            draw_rounded_card(img, [px, py, px + pill_w, py + 44], (30, 58, 95, 220), border_rgba=(*CYAN, 240), radius=22, border_width=2)
            d.text((px + 16, py + 11), f"▶ {num}", font=f("bold", 17), fill=CYAN_BRIGHT)
            d.text((px + 62, py + 12), title, font=f("bold", 16), fill=WHITE)
            # Progress line underneath
            line_w = int((pill_w - 32) * progress_in_ch)
            if line_w > 0:
                d.line([px + 16, py + 38, px + 16 + line_w, py + 38], fill=CYAN_BRIGHT, width=3)
        elif is_passed:
            # Completed pill
            draw_rounded_card(img, [px, py, px + pill_w, py + 44], (15, 23, 42, 180), border_rgba=(*EMERALD, 140), radius=22, border_width=1)
            d.text((px + 16, py + 11), f"✓ {num}", font=f("bold", 16), fill=EMERALD)
            d.text((px + 62, py + 12), title, font=f("regular", 16), fill=MUTED)
        else:
            # Upcoming pill
            draw_rounded_card(img, [px, py, px + pill_w, py + 44], (12, 17, 30, 140), border_rgba=(255, 255, 255, 25), radius=22, border_width=1)
            d.text((px + 16, py + 12), num, font=f("bold", 16), fill=DIM)
            d.text((px + 52, py + 12), title, font=f("regular", 16), fill=DIM)

    # Right badge
    draw_rounded_card(img, [1660, 24, 1870, 68], (15, 23, 42, 220), border_rgba=(*EMERALD, 140), radius=22, border_width=1)
    d.text((1678, 34), "🔒 100% On-Device", font=f("bold", 17), fill=EMERALD)

def draw_header_banner(img, badge_text, subtitle_text, accent=CYAN):
    """Draws chapter main title banner."""
    d = ImageDraw.Draw(img)
    # Badge
    font_badge = f("bold", 28)
    bb = font_badge.getbbox(badge_text)
    bw = bb[2] - bb[0] + 50
    bx = (WIDTH - bw) // 2
    draw_rounded_card(img, [bx, 96, bx + bw, 150], (15, 28, 55, 240), border_rgba=(*accent, 220), radius=27, border_width=2)
    d.text((bx + 25, 106), badge_text, font=font_badge, fill=WHITE)

    # Subtitle
    font_sub = f("regular", 21)
    sbb = font_sub.getbbox(subtitle_text)
    sw = sbb[2] - sbb[0]
    sx = (WIDTH - sw) // 2
    d.text((sx, 162), subtitle_text, font=font_sub, fill=MUTED)

def draw_caret_pill_hud(img, x, y, t_anim, selected_chip=1):
    """Draws VFlow Caret Pill HUD with animated sine ribbon and 3 suggestion chips."""
    pill_w = 680
    pill_h = 56
    # Liquid glass base
    draw_rounded_card(img, [x, y, x + pill_w, y + pill_h], (11, 16, 32, 245), border_rgba=(*CYAN, 200), radius=28, border_width=2)
    d = ImageDraw.Draw(img)

    # Animated sine wave ribbon (52px width)
    wave_x = x + 18
    wave_y = y + pill_h // 2
    pts = []
    for px in range(46):
        py = math.sin((px * 0.25) + t_anim * 8.0) * 10.0
        pts.append((wave_x + px, wave_y + py))
    if len(pts) > 1:
        d.line(pts, fill=CYAN, width=3)

    # Divider
    d.line([x + 72, y + 12, x + 72, y + pill_h - 12], fill=(255, 255, 255, 40), width=1)

    # Chip 1: [⇥] ⚡ tôi đang...
    c1_x = x + 82
    draw_rounded_card(img, [c1_x, y + 8, c1_x + 130, y + pill_h - 8], (20, 32, 58, 200), border_rgba=(255, 255, 255, 30), radius=14, border_width=1)
    d.text((c1_x + 10, y + 15), "[⇥] ⚡ tôi đang...", font=f("mono", 14), fill=MUTED)

    # Chip 2: [⇥⇥] ✨ Tôi đang làm việc. She doesn't... (SELECTED)
    c2_x = x + 222
    c2_w = 340
    c2_border = (*EMERALD, 240) if selected_chip == 1 else (255, 255, 255, 40)
    c2_bg = (16, 50, 40, 240) if selected_chip == 1 else (20, 32, 58, 200)
    draw_rounded_card(img, [c2_x, y + 7, c2_x + c2_w, y + pill_h - 7], c2_bg, border_rgba=c2_border, radius=14, border_width=2)
    d.text((c2_x + 12, y + 14), "[⇥⇥] ✨ Tôi đang làm việc...", font=f("bold", 15), fill=WHITE)

    # Chip 3: [⌥3]
    c3_x = x + 572
    draw_rounded_card(img, [c3_x, y + 8, c3_x + 90, y + pill_h - 8], (20, 32, 58, 200), border_rgba=(255, 255, 255, 30), radius=14, border_width=1)
    d.text((c3_x + 10, y + 15), "[⌥3] 🔮", font=f("mono", 14), fill=MUTED)

def draw_keycap(img, x, y, width, height, text, is_pressed=False):
    """Draws realistic 3D Apple Keyboard keycap."""
    d = ImageDraw.Draw(img)
    bg = (40, 55, 85, 250) if is_pressed else (20, 30, 50, 240)
    border = (*CYAN_BRIGHT, 255) if is_pressed else (255, 255, 255, 60)
    draw_rounded_card(img, [x, y, x + width, y + height], bg, border_rgba=border, radius=12, border_width=2 if is_pressed else 1)
    font_k = f("bold", 20 if len(text) > 4 else 22)
    bb = font_k.getbbox(text)
    tw = bb[2] - bb[0]
    th = bb[3] - bb[1]
    tx = x + (width - tw) // 2
    ty = y + (height - th) // 2 - 2
    d.text((tx, ty), text, font=font_k, fill=WHITE if is_pressed else (226, 232, 240, 255))

def draw_shimmer_beam(img, x1, y1, x2, y2, progress):
    """Draws sweeping crystalline light beam across rectangular area."""
    if progress < 0.0 or progress > 1.0:
        return
    shimmer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(shimmer)
    beam_x = x1 + int((x2 - x1) * progress)
    beam_w = 120
    # Gradient bands
    for offset in range(-beam_w // 2, beam_w // 2):
        alpha = int(140 * math.cos(math.pi * offset / beam_w))
        d.line([beam_x + offset, y1, beam_x + offset + 30, y2], fill=(255, 255, 255, alpha), width=2)
    img.alpha_composite(shimmer)


# ==============================================================================
# CHAPTER RENDERERS
# ==============================================================================

def render_chapter_1(frame_idx):
    """Chapter 1 (00:00 - 00:05): Cài Đặt Trong 30 Giây"""
    img = Image.new("RGBA", (WIDTH, HEIGHT), BG_PRIMARY)
    t_ch = frame_idx / FPS  # 0.0 to 5.0
    prog = min(1.0, max(0.0, t_ch / 5.0))

    draw_top_nav(img, 0, prog)
    draw_header_banner(img, "HƯỚNG DẪN #1: CÀI ĐẶT TRONG 30 GIÂY", "Ba bước siêu tốc để sở hữu bộ gõ tiếng Việt thông minh nhất macOS", CYAN)

    d = ImageDraw.Draw(img)

    card_y = 210
    card_h = 750
    card_w = 540

    # --- CARD 1: KÉO VÀO APPLICATIONS ---
    c1_x = 70
    draw_window_chrome(img, c1_x, card_y, card_w, card_h, "1. Kéo thả vào /Applications", CYAN)
    # Inner box
    draw_rounded_card(img, [c1_x + 25, card_y + 70, c1_x + card_w - 25, card_y + card_h - 110], (8, 13, 25, 200), (255, 255, 255, 25), radius=14)
    # Animated drag
    drag_p = min(1.0, max(0.0, (t_ch - 0.5) / 2.0))
    # Icons: App Icon -> Applications
    start_app_x = c1_x + 60
    end_app_x = c1_x + 220
    cur_app_x = int(start_app_x + (end_app_x - start_app_x) * drag_p)

    if img_app_icon:
        icon_thumb = img_app_icon.resize((150, 150), Image.Resampling.LANCZOS)
        img.alpha_composite(icon_thumb, (cur_app_x, card_y + 160))

    # Applications Folder target
    app_folder_x = c1_x + 320
    draw_rounded_card(img, [app_folder_x, card_y + 160, app_folder_x + 150, card_y + 310], (14, 165, 233, 50), (*CYAN, 180), radius=20, border_width=2)
    d.text((app_folder_x + 38, card_y + 195), "📁", font=f("bold", 50), fill=WHITE)
    d.text((app_folder_x + 18, card_y + 265), "Applications", font=f("bold", 18), fill=CYAN_BRIGHT)

    # Dotted arrow
    arrow_pts = [(c1_x + 180, card_y + 235), (c1_x + 300, card_y + 235)]
    d.line(arrow_pts, fill=(*CYAN, 180), width=3)
    d.polygon([(c1_x + 315, card_y + 235), (c1_x + 295, card_y + 225), (c1_x + 295, card_y + 245)], fill=CYAN)

    # Text descriptions
    d.text((c1_x + 50, card_y + 390), "• Mở file VFlow-v1.0.0.dmg", font=f("bold", 20), fill=WHITE)
    d.text((c1_x + 50, card_y + 440), "• Kéo VFlow.app vào Applications", font=f("bold", 20), fill=CYAN_BRIGHT)
    d.text((c1_x + 50, card_y + 490), "• Mở từ Spotlight hoặc Launchpad", font=f("regular", 19), fill=MUTED)

    # Bottom badge
    draw_rounded_card(img, [c1_x + 35, card_y + card_h - 85, c1_x + card_w - 35, card_y + card_h - 30], (16, 50, 40, 220), (*EMERALD, 180), radius=14)
    d.text((c1_x + 120, card_y + card_h - 68), "✓ Dung lượng siêu nhẹ < 25MB", font=f("bold", 18), fill=EMERALD)

    # --- CARD 2: CẤP QUYỀN HỆ THỐNG ---
    c2_x = 690
    draw_window_chrome(img, c2_x, card_y, card_w, card_h, "2. Cấp quyền Hệ Thống", VIOLET)
    # Row 1: Accessibility (Trợ năng)
    t1_on = (t_ch > 2.0)
    draw_rounded_card(img, [c2_x + 25, card_y + 80, c2_x + card_w - 25, card_y + 210], (20, 28, 48, 220), (255, 255, 255, 30), radius=14)
    d.text((c2_x + 45, card_y + 105), "♿ Quyền Trợ Năng (Accessibility)", font=f("bold", 20), fill=WHITE)
    d.text((c2_x + 45, card_y + 145), "Bắt phím gõ tiếng Việt siêu tốc < 2ms", font=f("regular", 17), fill=MUTED)
    # Switch 1
    sw1_bg = (*EMERALD, 240) if t1_on else (60, 70, 90, 240)
    draw_rounded_card(img, [c2_x + card_w - 110, card_y + 120, c2_x + card_w - 45, card_y + 160], sw1_bg, radius=20)
    sw1_thumb_x = (c2_x + card_w - 75) if t1_on else (c2_x + card_w - 105)
    d.ellipse([sw1_thumb_x, card_y + 123, sw1_thumb_x + 32, card_y + 157], fill=WHITE)

    # Row 2: Microphone
    t2_on = (t_ch > 2.6)
    draw_rounded_card(img, [c2_x + 25, card_y + 230, c2_x + card_w - 25, card_y + 360], (20, 28, 48, 220), (255, 255, 255, 30), radius=14)
    d.text((c2_x + 45, card_y + 255), "🎙️ Quyền Microphone", font=f("bold", 20), fill=WHITE)
    d.text((c2_x + 45, card_y + 295), "Nhận diện giọng nói Offline Whisper CoreML", font=f("regular", 17), fill=MUTED)
    # Switch 2
    sw2_bg = (*EMERALD, 240) if t2_on else (60, 70, 90, 240)
    draw_rounded_card(img, [c2_x + card_w - 110, card_y + 270, c2_x + card_w - 45, card_y + 310], sw2_bg, radius=20)
    sw2_thumb_x = (c2_x + card_w - 75) if t2_on else (c2_x + card_w - 105)
    d.ellipse([sw2_thumb_x, card_y + 273, sw2_thumb_x + 32, card_y + 307], fill=WHITE)

    # Explanation
    d.text((c2_x + 45, card_y + 400), "• Chuẩn bảo mật khắt khe của macOS", font=f("bold", 19), fill=WHITE)
    d.text((c2_x + 45, card_y + 445), "• Không thu thập phím bấm cá nhân", font=f("regular", 18), fill=MUTED)
    d.text((c2_x + 45, card_y + 490), "• 100% Offline, không kết nối server", font=f("regular", 18), fill=MUTED)

    draw_rounded_card(img, [c2_x + 35, card_y + card_h - 85, c2_x + card_w - 35, card_y + card_h - 30], (16, 50, 40, 220), (*EMERALD, 180), radius=14)
    d.text((c2_x + 95, card_y + card_h - 68), "✓ An toàn & Riêng tư tuyệt đối", font=f("bold", 18), fill=EMERALD)

    # --- CARD 3: MENU BAR MACOS ---
    c3_x = 1310
    draw_window_chrome(img, c3_x, card_y, card_w, card_h, "3. Biểu tượng Menu Bar", EMERALD)

    # Mock Menu Bar strip
    mb_y = card_y + 80
    draw_rounded_card(img, [c3_x + 25, mb_y, c3_x + card_w - 25, mb_y + 54], (25, 35, 60, 240), (255, 255, 255, 40), radius=12)
    d.text((c3_x + 45, mb_y + 15), "  File  Edit  Window", font=f("bold", 17), fill=MUTED)
    # Menu item glowing pill
    draw_rounded_card(img, [c3_x + card_w - 150, mb_y + 8, c3_x + card_w - 40, mb_y + 46], (15, 40, 70, 240), (*CYAN, 240), radius=16, border_width=2)
    d.ellipse([c3_x + card_w - 138, mb_y + 22, c3_x + card_w - 128, mb_y + 32], fill=CYAN)
    d.text((c3_x + card_w - 118, mb_y + 16), "VI · T", font=f("bold", 17), fill=WHITE)

    # Dropdown Menu expands at t > 3.2s
    if t_ch > 3.2:
        menu_y = mb_y + 60
        draw_rounded_card(img, [c3_x + card_w - 280, menu_y, c3_x + card_w - 35, menu_y + 270], (15, 23, 42, 250), (*CYAN, 180), radius=14, border_width=2)
        # Item 1: Telex
        draw_rounded_card(img, [c3_x + card_w - 270, menu_y + 12, c3_x + card_w - 45, menu_y + 52], (30, 60, 100, 240), radius=8)
        d.text((c3_x + card_w - 255, menu_y + 21), "✓  VI · T  (Telex)", font=f("bold", 16), fill=CYAN_BRIGHT)
        d.text((c3_x + card_w - 100, menu_y + 21), "⌥⌘T", font=f("mono", 15), fill=MUTED)
        # Item 2: VNI
        d.text((c3_x + card_w - 235, menu_y + 70), "VI · V  (VNI)", font=f("regular", 16), fill=WHITE)
        d.text((c3_x + card_w - 100, menu_y + 70), "⌥⌘V", font=f("mono", 15), fill=MUTED)
        # Item 3: English
        d.text((c3_x + card_w - 235, menu_y + 115), "EN     (English)", font=f("regular", 16), fill=WHITE)
        d.text((c3_x + card_w - 100, menu_y + 115), "⌥⌘E", font=f("mono", 15), fill=MUTED)

        d.line([c3_x + card_w - 265, menu_y + 155, c3_x + card_w - 50, menu_y + 155], fill=(255, 255, 255, 30), width=1)
        d.text((c3_x + card_w - 245, menu_y + 175), "⚙️ Cài đặt VFlow...", font=f("regular", 16), fill=WHITE)
        d.text((c3_x + card_w - 245, menu_y + 220), "🚪 Thoát VFlow", font=f("regular", 16), fill=MUTED)

    # Explanation
    d.text((c3_x + 45, card_y + 440), "• Bấm chuột để chuyển kiểu gõ", font=f("bold", 19), fill=WHITE)
    d.text((c3_x + 45, card_y + 485), "• Phím tắt nhanh: ⌥⌘T / ⌥⌘V / ⌥⌘E", font=f("mono", 17), fill=CYAN_BRIGHT)
    d.text((c3_x + 45, card_y + 530), "• Chạy nền êm ái, tốn < 0.1% CPU", font=f("regular", 18), fill=MUTED)

    draw_rounded_card(img, [c3_x + 35, card_y + card_h - 85, c3_x + card_w - 35, card_y + card_h - 30], (16, 50, 40, 220), (*EMERALD, 180), radius=14)
    d.text((c3_x + 110, card_y + card_h - 68), "✓ Hoạt động ngay tức thì!", font=f("bold", 18), fill=EMERALD)

    return img


def render_chapter_2(frame_idx):
    """Chapter 2 (00:05 - 00:12): Gõ Tiếng Anh & Code Không Nhảy Dấu"""
    img = Image.new("RGBA", (WIDTH, HEIGHT), BG_PRIMARY)
    t_ch = (frame_idx - 150) / FPS  # 0.0 to 7.0
    prog = min(1.0, max(0.0, t_ch / 7.0))

    draw_top_nav(img, 1, prog)
    draw_header_banner(img, "ĐỘT PHÁ #1: GÕ TIẾNG ANH & CODE KHÔNG NHẢY DẤU", "Thuật toán Smart Auto-Escape Engine — Giữ nguyên 100% cú pháp tiếng Anh và code", CYAN)

    d = ImageDraw.Draw(img)

    card_y = 210
    card_h = 720

    # --- LEFT CARD: BỘ GÕ CŨ THƯỜNG GẶP (❌) ---
    left_w = 860
    left_x = 70
    draw_window_chrome(img, left_x, card_y, left_w, card_h, "❌ Bộ gõ truyền thống (Lỗi nhảy dấu khó chịu)", RED)

    # Code background
    draw_rounded_card(img, [left_x + 30, card_y + 70, left_x + left_w - 30, card_y + 360], (15, 10, 15, 230), (255, 95, 86, 80), radius=14)
    d.text((left_x + 55, card_y + 95), "// Khi gõ code trong lúc bật tiếng Việt:", font=f("mono", 20), fill=DIM)

    # Distorted code line
    d.text((left_x + 55, card_y + 150), "const ", font=f("mono", 28), fill=(203, 213, 225, 255))
    d.text((left_x + 150, card_y + 150), "sảlảy", font=f("mono", 28), fill=RED)
    d.text((left_x + 245, card_y + 150), " = calculate", font=f("mono", 28), fill=(203, 213, 225, 255))
    d.text((left_x + 460, card_y + 150), "Arổw", font=f("mono", 28), fill=RED)
    d.text((left_x + 540, card_y + 150), "(", font=f("mono", 28), fill=(203, 213, 225, 255))

    d.text((left_x + 95, card_y + 205), "sẻvice", font=f("mono", 28), fill=RED)
    d.text((left_x + 215, card_y + 205), ", ", font=f("mono", 28), fill=(203, 213, 225, 255))
    d.text((left_x + 245, card_y + 205), "subclás", font=f("mono", 28), fill=RED)

    d.text((left_x + 55, card_y + 260), ");", font=f("mono", 28), fill=(203, 213, 225, 255))

    # Error breakdown badges
    err_y = card_y + 380
    d.text((left_x + 40, err_y), "⚠️ Các lỗi điển hình khiến lập trình viên ức chế:", font=f("bold", 22), fill=RED)

    errs = [
        ("salary", "➔ sảlảy", "Chữ 'r' bị nhận nhầm thành dấu hỏi trong Telex"),
        ("Arrow",  "➔ Arổw",  "Chữ 'w' bị nhận nhầm thành dấu móc/ô"),
        ("service","➔ sẻvice", "Chữ 'r' bị nuốt vào âm 'e' thành 'ẻ'"),
        ("subclass","➔ subclás","Chữ 's' bị nhận nhầm thành dấu sắc 'á'"),
    ]
    for i, (orig, broken, desc) in enumerate(errs):
        ey = err_y + 40 + i * 55
        draw_rounded_card(img, [left_x + 40, ey, left_x + left_w - 40, ey + 46], (25, 12, 18, 220), (255, 95, 86, 60), radius=10)
        d.text((left_x + 55, ey + 11), f"❌ {orig}", font=f("bold", 18), fill=WHITE)
        d.text((left_x + 180, ey + 11), broken, font=f("bold", 18), fill=RED)
        d.text((left_x + 290, ey + 12), f"• {desc}", font=f("regular", 16), fill=MUTED)

    draw_rounded_card(img, [left_x + 40, card_y + card_h - 75, left_x + left_w - 40, card_y + card_h - 25], (40, 15, 20, 240), (*RED, 140), radius=12)
    d.text((left_x + 75, card_y + card_h - 60), "➔ Hậu quả: Phải xóa gõ lại liên tục hoặc tắt gõ tiếng Việt thủ công!", font=f("bold", 17), fill=RED)

    # --- RIGHT CARD: VFLOW SMART AUTO-ESCAPE (✅) ---
    right_w = 900
    right_x = 950
    draw_window_chrome(img, right_x, card_y, right_w, card_h, "✅ VFlow Engine: Smart Auto-Escape (VI·T vẫn bật)", CYAN)

    # Code Editor Window
    draw_rounded_card(img, [right_x + 30, card_y + 70, right_x + right_w - 30, card_y + 360], (10, 18, 35, 230), (*CYAN, 120), radius=14)
    d.text((right_x + 55, card_y + 95), "// VFlow tự nhận diện từ khóa & cú pháp tiếng Anh:", font=f("mono", 20), fill=CYAN_BRIGHT)

    # Typing text animation
    full_code = "const salary = calculateArrow(service, subclass);"
    # Typing starts at t=1.2s, ends at t=5.8s
    chars_to_show = int(min(len(full_code), max(0, (t_ch - 1.2) / 4.0 * len(full_code))))
    typed_text = full_code[:chars_to_show]

    # Format typed code with highlighting
    d.text((right_x + 55, card_y + 160), typed_text, font=f("mono", 26), fill=WHITE)
    # Blinking cursor
    if (int(t_ch * 3) % 2 == 0) and chars_to_show < len(full_code):
        cw = f("mono", 26).getbbox(typed_text)[2]
        d.line([right_x + 55 + cw + 4, card_y + 155, right_x + 55 + cw + 4, card_y + 195], fill=CYAN, width=3)

    # Status Pill inside editor
    draw_rounded_card(img, [right_x + right_w - 180, card_y + 85, right_x + right_w - 45, card_y + 125], (15, 35, 65, 240), (*CYAN, 200), radius=16)
    d.ellipse([right_x + right_w - 168, card_y + 100, right_x + right_w - 158, card_y + 110], fill=CYAN)
    d.text((right_x + right_w - 148, card_y + 93), "VI · T BẬT", font=f("bold", 16), fill=WHITE)

    # Advantage callouts
    adv_y = card_y + 380
    d.text((right_x + 40, adv_y), "✨ Công nghệ độc quyền của VFlow:", font=f("bold", 22), fill=EMERALD)

    advs = [
        ("English Lexicon FSM", "Nhận diện từ vựng tiếng Anh theo thời gian thực"),
        ("CamelCase & snake_case", "Bảo vệ tên biến lập trình không bao giờ nhảy dấu"),
        ("Zero Backspace Delay", "Độ trễ xử lý < 2ms, mượt mà ở tốc độ gõ 120 WPM"),
        ("Per-App Mode Switch", "Tự động đổi cấu hình riêng cho Xcode, VS Code, Terminal"),
    ]
    for i, (title, desc) in enumerate(advs):
        ay = adv_y + 40 + i * 55
        draw_rounded_card(img, [right_x + 40, ay, right_x + right_w - 40, ay + 46], (15, 30, 48, 220), (*EMERALD, 80), radius=10)
        d.text((right_x + 55, ay + 11), f"⚡ {title}", font=f("bold", 18), fill=CYAN_BRIGHT)
        d.text((right_x + 320, ay + 12), f"• {desc}", font=f("regular", 16), fill=WHITE)

    # Bottom Tip Pill
    draw_rounded_card(img, [right_x + 40, card_y + card_h - 75, right_x + right_w - 40, card_y + card_h - 25], (25, 45, 80, 240), (*CYAN, 200), radius=12)
    d.text((right_x + 65, card_y + card_h - 60), "💡 Mẹo: Gõ đúp phím dấu (rr, ss, ff) để hoàn nguyên chữ tiếng Anh tức thì!", font=f("bold", 17), fill=CYAN_BRIGHT)

    return img


def render_chapter_3(frame_idx):
    """Chapter 3 (00:12 - 00:19): Nhấn Tab-Tab Sửa Ngữ Pháp Trọn Câu"""
    img = Image.new("RGBA", (WIDTH, HEIGHT), BG_PRIMARY)
    t_ch = (frame_idx - 360) / FPS  # 0.0 to 7.0
    prog = min(1.0, max(0.0, t_ch / 7.0))

    draw_top_nav(img, 2, prog)
    draw_header_banner(img, "ĐỘT PHÁ #2: NHẤN TAB-TAB SỬA NGỮ PHÁP TRỌN CÂU", "Caret Pill HUD 120fps hiển thị sát con trỏ — Nhấn ⇥⇥ để AI biên tập ngữ pháp tức thì", VIOLET)

    d = ImageDraw.Draw(img)

    card_y = 210
    card_h = 750
    card_w = 1780
    card_x = 70

    draw_window_chrome(img, card_x, card_y, card_w, card_h, "Soạn thảo văn bản & Email — Bất kỳ ứng dụng nào (AnywhereTextBridge)", VIOLET)

    # Typing phase: 0.0s to 3.0s -> raw text
    # Tab-Tab press: 3.8s and 4.1s
    # Shimmer sweep: 4.25s to 5.2s
    # Polished text after 4.8s
    raw_sentence = "to dang lam viec. she dont know how to fix this bug"
    polished_sentence = "Tôi đang làm việc. She doesn't know how to fix this bug."

    # Raw typing progression
    raw_chars = int(min(len(raw_sentence), max(0, t_ch / 2.8 * len(raw_sentence))))
    current_text = raw_sentence[:raw_chars]

    is_transformed = (t_ch >= 4.8)
    display_text = polished_sentence if is_transformed else current_text

    # Editor input box
    editor_box = [card_x + 50, card_y + 80, card_x + card_w - 50, card_y + 360]
    draw_rounded_card(img, editor_box, (10, 16, 32, 240), (255, 255, 255, 30), radius=16)

    # Subtext prompt
    d.text((card_x + 80, card_y + 110), "Gõ thử một câu chưa có dấu tiếng Việt và ngữ pháp tiếng Anh sai:", font=f("regular", 19), fill=DIM)

    # Main text line
    font_main = f("bold", 34)
    text_color = (*EMERALD, 255) if is_transformed else WHITE
    d.text((card_x + 80, card_y + 170), display_text, font=font_main, fill=text_color)

    # Caret position
    tb = font_main.getbbox(display_text)
    cur_x = card_x + 80 + (tb[2] - tb[0])
    cur_y = card_y + 165
    if not is_transformed and (int(t_ch * 3) % 2 == 0):
        d.line([cur_x + 5, cur_y, cur_x + 5, cur_y + 42], fill=CYAN, width=3)

    # Caret Pill HUD appears floating underneath caret (from t_ch >= 2.5)
    if t_ch >= 2.5:
        pill_x = min(card_x + card_w - 740, max(card_x + 80, cur_x - 120))
        pill_y = card_y + 245
        draw_caret_pill_hud(img, pill_x, pill_y, t_ch, selected_chip=1)

    # Shimmer sweep effect (t_ch between 4.25 and 5.3)
    if 4.25 <= t_ch <= 5.3:
        shimmer_prog = (t_ch - 4.25) / 1.05
        draw_shimmer_beam(img, card_x + 70, card_y + 140, card_x + card_w - 70, card_y + 230, shimmer_prog)

    # Bottom Area: Keyboard HUD & AI explanation
    bot_y = card_y + 390

    # Animated Keyboard Keycaps on Left
    draw_rounded_card(img, [card_x + 50, bot_y, card_x + 580, card_y + card_h - 40], (15, 23, 44, 230), (*CYAN, 100), radius=16)
    d.text((card_x + 80, bot_y + 30), "THAO TÁC PHÍM TẮT:", font=f("bold", 20), fill=CYAN_BRIGHT)

    tab1_pressed = (3.7 <= t_ch <= 4.0)
    tab2_pressed = (4.05 <= t_ch <= 4.4)
    draw_keycap(img, card_x + 80, bot_y + 80, 180, 90, "⇥ Tab", is_pressed=tab1_pressed)
    draw_keycap(img, card_x + 290, bot_y + 80, 180, 90, "⇥ Tab", is_pressed=tab2_pressed)

    d.text((card_x + 80, bot_y + 200), "Nhấn đúp Tab (⇥⇥):", font=f("bold", 22), fill=WHITE)
    d.text((card_x + 80, bot_y + 240), "• Tự động chọn gợi ý hoàn chỉnh nhất", font=f("regular", 18), fill=MUTED)
    d.text((card_x + 80, bot_y + 275), "• Quét Shimmer Sweep thay thế câu tức thì", font=f("regular", 18), fill=MUTED)

    # Right Explanation Card: What AI corrected
    draw_rounded_card(img, [card_x + 610, bot_y, card_x + card_w - 50, card_y + card_h - 40], (16, 28, 52, 230), (*VIOLET, 120), radius=16)
    d.text((card_x + 640, bot_y + 30), "AI GRAMMAR POLISHER ĐÃ SỬA NHỮNG GÌ?", font=f("bold", 20), fill=VIOLET_BRIGHT)

    corrections = [
        ("Bổ sung dấu Tiếng Việt", "'to dang lam viec' ➔ 'Tôi đang làm việc.' (thêm dấu & chấm câu)", EMERALD),
        ("Viết hoa đầu dòng tự động", "Tự nhận diện bắt đầu câu và ngắt đoạn chính xác", CYAN),
        ("Sửa ngữ pháp Tiếng Anh", "'she dont know' ➔ 'she doesn't know' (chia động từ ngôi thứ 3)", VIOLET_BRIGHT),
        ("Bảo mật 100% On-Device", "Mô hình ngôn ngữ chạy trực tiếp trên Apple Neural Engine (ANE)", WHITE),
    ]
    for idx, (title, desc, clr) in enumerate(corrections):
        cy = bot_y + 75 + idx * 56
        draw_rounded_card(img, [card_x + 640, cy, card_x + card_w - 80, cy + 48], (12, 20, 38, 220), (*clr[:3], 80), radius=10)
        d.text((card_x + 660, cy + 12), f"✨ {title}:", font=f("bold", 18), fill=clr)
        d.text((card_x + 940, cy + 13), desc, font=f("regular", 17), fill=WHITE)

    return img


def render_chapter_4(frame_idx):
    """Chapter 4 (00:19 - 00:26): Đọc Giọng Nói ⌥Space ➔ Văn Viết AI"""
    img = Image.new("RGBA", (WIDTH, HEIGHT), BG_PRIMARY)
    t_ch = (frame_idx - 570) / FPS  # 0.0 to 7.0
    prog = min(1.0, max(0.0, t_ch / 7.0))

    draw_top_nav(img, 3, prog)
    draw_header_banner(img, "ĐỘT PHÁ #3: GIỌNG NÓI ⌥SPACE ➔ VĂN VIẾT AI", "Push-to-Talk Offline Whisper CoreML — Tự nhận diện & biên tập thành văn viết chuyên nghiệp", VIOLET)

    d = ImageDraw.Draw(img)

    card_y = 210
    card_h = 750
    card_w = 1780
    card_x = 70

    draw_window_chrome(img, card_x, card_y, card_w, card_h, "Push-to-Talk Voice Dictation & Silence Watchdog (Whisper CoreML)", VIOLET)

    # Top shortcut banner
    draw_rounded_card(img, [card_x + 50, card_y + 70, card_x + card_w - 50, card_y + 135], (20, 35, 65, 230), (*VIOLET, 180), radius=14)
    d.text((card_x + 80, card_y + 92), "🎙️ PHÍM TẮT THU ÂM:", font=f("bold", 22), fill=VIOLET_BRIGHT)
    draw_keycap(img, card_x + 350, card_y + 80, 150, 46, "⌥ Option", is_pressed=True)
    d.text((card_x + 515, card_y + 92), "+", font=f("bold", 24), fill=WHITE)
    draw_keycap(img, card_x + 540, card_y + 80, 200, 46, "Space Bar", is_pressed=True)
    d.text((card_x + 770, card_y + 93), "(Giữ phím để nói, nhả phím để tự điền & biên tập văn viết)", font=f("regular", 19), fill=MUTED)

    # Center Orb & Waveform Stage
    center_y = card_y + 155
    orb_stage_w = 480
    draw_rounded_card(img, [card_x + 50, center_y, card_x + orb_stage_w, center_y + 360], (12, 18, 36, 230), (*CYAN, 100), radius=16)

    # 3D Glowing Voice Orb thumbnail
    if img_voice_orb:
        orb_thumb = img_voice_orb.resize((170, 170), Image.Resampling.LANCZOS)
        # Pulsing float
        pulse_y = int(math.sin(t_ch * 4.0) * 8.0)
        img.alpha_composite(orb_thumb, (card_x + 205, center_y + 35 + pulse_y))

    # Equalizer Spectrum (24 bars)
    eq_y = center_y + 245
    for bi in range(24):
        bx = card_x + 95 + bi * 16
        bar_h = int(15 + 35 * abs(math.sin(t_ch * 6.0 + bi * 0.45)))
        d.line([bx, eq_y + 40, bx, eq_y + 40 - bar_h], fill=CYAN if bi % 2 == 0 else VIOLET, width=8)

    d.text((card_x + 130, center_y + 315), "Offline Whisper CoreML", font=f("bold", 17), fill=CYAN_BRIGHT)

    # Right Content Stage (Transcript vs Polished)
    right_x = card_x + 550
    right_w = card_w - 600

    # Box 1: Raw Voice Transcript
    raw_speech = "Hình như là sau khi nhận diện cái phần giọng nói sang nhưng mà đúng ra cần có 1 thao tác AI"
    draw_rounded_card(img, [right_x, center_y, right_x + right_w, center_y + 160], (15, 20, 38, 230), (255, 255, 255, 40), radius=14)
    d.text((right_x + 30, center_y + 20), "1. VĂN NÓI THÔ (Whisper Transcript trực tiếp):", font=f("bold", 18), fill=MUTED)
    d.text((right_x + 30, center_y + 60), f'"{raw_speech}"', font=f("regular", 22), fill=(226, 232, 240, 255))
    d.text((right_x + 30, center_y + 115), "⚠️ Khẩu ngữ rườm rà, có từ đệm ('hình như là', 'cái phần', 'nhưng mà')", font=f("regular", 16), fill=RED)

    # Silence Watchdog Countdown Bar
    wd_y = center_y + 180
    draw_rounded_card(img, [right_x, wd_y, right_x + right_w, wd_y + 60], (10, 30, 50, 230), (*CYAN, 140), radius=12)
    # Countdown 2.2s -> 0.0s (between t=1.5 and 4.2)
    time_left = max(0.0, 2.2 - (t_ch - 1.2)) if t_ch >= 1.2 else 2.2
    prog_wd = min(1.0, max(0.0, (t_ch - 1.2) / 2.2))
    d.text((right_x + 25, wd_y + 18), f"⏱️ Silence Watchdog: {time_left:.1f}s", font=f("bold", 18), fill=CYAN_BRIGHT)
    # Progress bar
    pb_w = right_w - 380
    pb_x = right_x + 340
    draw_rounded_card(img, [pb_x, wd_y + 20, pb_x + pb_w, wd_y + 40], (20, 30, 50, 240), radius=10)
    fill_w = int(pb_w * (1.0 - prog_wd))
    if fill_w > 0:
        draw_rounded_card(img, [pb_x, wd_y + 20, pb_x + fill_w, wd_y + 40], (*EMERALD, 240), radius=10)

    # Box 2: Polished Written Result (Triggers at t >= 3.6s)
    is_polished = (t_ch >= 3.6)
    box2_border = (*EMERALD, 240) if is_polished else (255, 255, 255, 30)
    box2_bg = (12, 35, 30, 240) if is_polished else (12, 18, 30, 200)
    draw_rounded_card(img, [right_x, center_y + 260, right_x + right_w, center_y + 440], box2_bg, box2_border, radius=14, border_width=2)

    if is_polished:
        d.text((right_x + 30, center_y + 285), "2. VĂN VIẾT AI BIÊN TẬP (Tab-Tab Polish):", font=f("bold", 20), fill=EMERALD)
        polished_result = '"Sau khi nhận diện giọng nói sang văn bản, hệ thống cần một thao tác AI."'
        d.text((right_x + 30, center_y + 330), polished_result, font=f("bold", 24), fill=WHITE)
        d.text((right_x + 30, center_y + 390), "✨ Gãy gọn, văn phong trang trọng, chuẩn xác & sẵn sàng gửi email/báo cáo!", font=f("bold", 17), fill=EMERALD)
    else:
        d.text((right_x + 30, center_y + 285), "2. VĂN VIẾT AI BIÊN TẬP:", font=f("bold", 18), fill=DIM)
        d.text((right_x + 30, center_y + 340), "Đang chờ Silence Watchdog hoàn tất...", font=f("regular", 20), fill=MUTED)

    # Bottom summary chips
    bot_y = card_y + 630
    draw_rounded_card(img, [card_x + 50, bot_y, card_x + card_w - 50, card_y + card_h - 30], (16, 25, 45, 230), (*CYAN, 120), radius=14)
    d.text((card_x + 80, bot_y + 28), "🛡️ BẢO MẬT TUYỆT ĐỐI:", font=f("bold", 20), fill=CYAN_BRIGHT)
    d.text((card_x + 350, bot_y + 29), "Mô hình Whisper Tiny & Small chạy 100% trên chip M1/M2/M3/M4 • Không gửi dữ liệu âm thanh lên Cloud!", font=f("regular", 18), fill=WHITE)

    return img


def render_chapter_5(frame_idx):
    """Chapter 5 (00:26 - 00:31): Tự Ẩn Thông Minh & Tổng Kết"""
    img = Image.new("RGBA", (WIDTH, HEIGHT), BG_PRIMARY)
    t_ch = (frame_idx - 780) / FPS  # 0.0 to 5.0
    prog = min(1.0, max(0.0, t_ch / 5.0))

    draw_top_nav(img, 4, prog)

    d = ImageDraw.Draw(img)

    # Split into 2 parts:
    # 0.0s - 2.0s: Smart Auto-Hide (AXEditableAncestor)
    # 2.0s - 5.0s: Grand Finale Outro
    if t_ch < 2.2:
        draw_header_banner(img, "TỰ ẨN KHI LƯỚT WEB • BẢO MẬT 100% ON-DEVICE", "Thuật toán AXEditableAncestor bảo đảm Caret Pill chỉ hiện khi cần gõ", CYAN)

        card_y = 210
        card_h = 750
        card_w = 1780
        card_x = 70

        draw_window_chrome(img, card_x, card_y, card_w, card_h, "Safari / Chrome — Đọc báo & Lướt web (Non-editable content)", CYAN)

        # Mock browser content
        draw_rounded_card(img, [card_x + 50, card_y + 70, card_x + card_w - 50, card_y + 360], (15, 23, 42, 230), (255, 255, 255, 25), radius=16)
        d.text((card_x + 80, card_y + 100), "📰 VnExpress / Báo chí & Tài liệu công nghệ", font=f("bold", 24), fill=WHITE)
        d.text((card_x + 80, card_y + 150), "Apple ra mắt thế hệ chip M4 với Neural Engine vượt trội, hỗ trợ mô hình AI cục bộ...", font=f("regular", 20), fill=MUTED)
        d.text((card_x + 80, card_y + 190), "Người dùng cuộn trang đọc bài viết, con trỏ chuột di chuyển trên văn bản không chỉnh sửa.", font=f("regular", 20), fill=MUTED)

        # Notice badge: HUD hidden
        draw_rounded_card(img, [card_x + 80, card_y + 250, card_x + 700, card_y + 320], (20, 50, 35, 240), (*EMERALD, 200), radius=14, border_width=2)
        d.text((card_x + 110, card_y + 273), "✓ Caret Pill TỰ ĐỘNG ẨN 100% (Zero False Positives)", font=f("bold", 18), fill=EMERALD)

        # Explanatory lower cards
        bot_y = card_y + 390
        draw_rounded_card(img, [card_x + 50, bot_y, card_x + card_w - 50, card_y + card_h - 40], (12, 22, 42, 230), (*CYAN, 100), radius=16)
        d.text((card_x + 80, bot_y + 40), "CƠ CHẾ BẢO VỆ TRẢI NGHIỆM NGƯỜI DÙNG:", font=f("bold", 22), fill=CYAN_BRIGHT)

        pillars = [
            ("AXEditableAncestor Guard", "Truy vết ngược cây Accessibility DOM để xác nhận ô input thực thụ."),
            ("Không bao giờ che chữ", "Tự động lật mép trên/dưới màn hình khi con trỏ ở sát góc."),
            ("Non-Activating NSPanel", "Không bao giờ cướp focus hay làm gián đoạn cửa sổ đang làm việc."),
        ]
        for i, (p_title, p_desc) in enumerate(pillars):
            py = bot_y + 95 + i * 70
            draw_rounded_card(img, [card_x + 80, py, card_x + card_w - 80, py + 54], (16, 28, 52, 220), (255, 255, 255, 30), radius=12)
            d.text((card_x + 105, py + 15), f"🛡️ {p_title}:", font=f("bold", 19), fill=WHITE)
            d.text((card_x + 400, py + 16), p_desc, font=f("regular", 18), fill=MUTED)

    else:
        # GRAND FINALE OUTRO SCREEN
        draw_header_banner(img, "VFLOW — GÕ TIẾNG VIỆT & TRỢ LÝ AI BẤT KỲ ĐÂU", "Phiên bản v1.0.0 hoàn chỉnh dành cho macOS Apple Silicon", CYAN)

        center_y = 220
        # Glowing 3D App Icon
        if img_app_icon:
            icon_big = img_app_icon.resize((240, 240), Image.Resampling.LANCZOS)
            img.alpha_composite(icon_big, ((WIDTH - 240) // 2, center_y))

        # Brand Title
        font_b1 = f("bold", 44)
        t_brand = "VFlow v1.0.0"
        bb1 = font_b1.getbbox(t_brand)
        d.text(((WIDTH - (bb1[2] - bb1[0])) // 2, center_y + 260), t_brand, font=font_b1, fill=WHITE)

        font_b2 = f("regular", 24)
        t_sub = "Bộ Gõ Tiếng Việt • Caret Pill HUD 120fps • AI Grammar Polisher • Voice ⌥Space"
        bb2 = font_b2.getbbox(t_sub)
        d.text(((WIDTH - (bb2[2] - bb2[0])) // 2, center_y + 320), t_sub, font=font_b2, fill=CYAN_BRIGHT)

        # 3 Metrics Pills
        pill_y = center_y + 380
        metrics = [
            ("⚡", "< 2ms Latency", "Bộ gõ nhanh nhất macOS"),
            ("✨", "120fps Liquid HUD", "Mượt mà từng khung hình"),
            ("🛡️", "0 KB Cloud", "Bảo mật 100% On-Device"),
        ]
        mp_w = 420
        mp_gap = 40
        mp_start_x = (WIDTH - (3 * mp_w + 2 * mp_gap)) // 2

        for i, (icon, m_title, m_desc) in enumerate(metrics):
            mx = mp_start_x + i * (mp_w + mp_gap)
            draw_rounded_card(img, [mx, pill_y, mx + mp_w, pill_y + 110], (16, 28, 52, 230), (*CYAN, 140), radius=18, border_width=2)
            d.text((mx + 25, pill_y + 20), f"{icon} {m_title}", font=f("bold", 24), fill=WHITE)
            d.text((mx + 25, pill_y + 65), m_desc, font=f("regular", 18), fill=MUTED)

        # CTA Download Button & Link
        cta_y = center_y + 530
        cta_w = 640
        cta_x = (WIDTH - cta_w) // 2
        draw_rounded_card(img, [cta_x, cta_y, cta_x + cta_w, cta_y + 75], (14, 165, 233, 240), (*CYAN_BRIGHT, 255), radius=38, border_width=2)
        cta_txt = "🚀 TẢI VFLOW MIỄN PHÍ: tgalioautomation.github.io/VFlow"
        font_cta = f("bold", 20)
        cbb = font_cta.getbbox(cta_txt)
        d.text((cta_x + (cta_w - (cbb[2] - cbb[0])) // 2, cta_y + 25), cta_txt, font=font_cta, fill=(10, 15, 30, 255))

        d.text(((WIDTH - 500) // 2, cta_y + 100), "Dành riêng cho macOS Sonoma & Sequoia • Apple Silicon M1/M2/M3/M4", font=f("regular", 18), fill=DIM)

    return img


def get_frame(frame_idx):
    """Router for all 930 frames."""
    if frame_idx < 150:
        return render_chapter_1(frame_idx)
    elif frame_idx < 360:
        return render_chapter_2(frame_idx)
    elif frame_idx < 570:
        return render_chapter_3(frame_idx)
    elif frame_idx < 780:
        return render_chapter_4(frame_idx)
    else:
        return render_chapter_5(frame_idx)


# ==============================================================================
# MAIN PIPELINE
# ==============================================================================
def main():
    os.makedirs(ASSETS_DIR, exist_ok=True)
    video_out = os.path.join(ASSETS_DIR, "vflow-demo-guide.mp4")
    poster_out = os.path.join(ASSETS_DIR, "vflow-demo-poster.png")
    gif_out = os.path.join(ASSETS_DIR, "vflow-demo.gif")
    wav_path = "/tmp/vflow_audio.wav"

    # Step 1: Generate audio
    synthesize_audio(wav_path)

    # Step 2: Generate Poster Frame
    print(f"Generating poster frame at 1920x1080 -> {poster_out}...")
    # Frame 500 (Chapter 3 with Caret Pill HUD, Tab-Tab and polished sentence)
    poster_img = get_frame(500)
    poster_img.save(poster_out, "PNG")
    print(f"Poster frame saved: {poster_out} ({os.path.getsize(poster_out):,} bytes)")

    # Step 3: Stream frames into ffmpeg
    print(f"Rendering {TOTAL_FRAMES} frames (30fps, {DURATION_SEC}s) into {video_out}...")
    ffmpeg_cmd = [
        "/opt/homebrew/bin/ffmpeg",
        "-y",
        "-f", "rawvideo",
        "-vcodec", "rawvideo",
        "-s", f"{WIDTH}x{HEIGHT}",
        "-pix_fmt", "rgba",
        "-r", str(FPS),
        "-i", "-",  # Video input from stdin
        "-i", wav_path,  # Audio input
        "-c:v", "libx264",
        "-preset", "medium",
        "-crf", "20",
        "-pix_fmt", "yuv420p",
        "-movflags", "+faststart",
        "-c:a", "aac",
        "-b:a", "192k",
        "-shortest",
        video_out
    ]

    proc = subprocess.Popen(ffmpeg_cmd, stdin=subprocess.PIPE, stderr=subprocess.PIPE)

    try:
        for idx in range(TOTAL_FRAMES):
            frame = get_frame(idx)
            proc.stdin.write(frame.tobytes())
            if idx % 100 == 0 or idx == TOTAL_FRAMES - 1:
                pct = (idx + 1) / TOTAL_FRAMES * 100
                sys.stdout.write(f"\rProgress: {idx+1}/{TOTAL_FRAMES} frames ({pct:.1f}%)")
                sys.stdout.flush()
        print("\nAll frames streamed. Finalizing ffmpeg encoding...")
        stdout, stderr = proc.communicate()
    except Exception as e:
        proc.kill()
        raise e

    if proc.returncode != 0:
        print("FFmpeg error:", stderr.decode("utf-8", errors="replace"))
        sys.exit(1)

    print(f"Video created successfully: {video_out} ({os.path.getsize(video_out):,} bytes)")

    # Step 4: Generate optimized GIF (960x540)
    print(f"Generating optimized GIF (960x540) -> {gif_out}...")
    gif_cmd = [
        "/opt/homebrew/bin/ffmpeg",
        "-y",
        "-i", video_out,
        "-vf", "fps=12,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3",
        gif_out
    ]
    sub_res = subprocess.run(gif_cmd, capture_output=True, text=True)
    if sub_res.returncode != 0:
        print("GIF creation error:", sub_res.stderr)
    else:
        print(f"GIF created successfully: {gif_out} ({os.path.getsize(gif_out):,} bytes)")

    # Step 5: Clean up temporary audio
    if os.path.exists(wav_path):
        os.remove(wav_path)

    print("\n--- ALL DELIVERABLES GENERATED SUCCESSFULLY ---")

if __name__ == "__main__":
    main()
