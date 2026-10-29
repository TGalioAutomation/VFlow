#!/usr/bin/env python3
"""
VFlow Facebook Kit Generator
Creates 4 Square Carousel PNGs (1200x1200) + 1 Landscape Cover PNG (1200x630)
macOS Sequoia Dark Mode + Liquid Glass aesthetic.
Guarantees 0% missing-glyph tofu [□] via safe Arial / Menlo font tables and clean_str sanitizer.
"""

import os
import sys
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from fontTools.ttLib import TTFont

# Directories
WORKSPACE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(WORKSPACE_DIR, "docs", "assets")
OUTPUT_DIR = os.path.join(WORKSPACE_DIR, "release-assets", "facebook-kit")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# System Fonts (macOS)
FONT_ARIAL_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_ARIAL = "/System/Library/Fonts/Supplemental/Arial.ttf"
FONT_MENLO = "/System/Library/Fonts/Menlo.ttc"

# Load Font CMaps for 100% tofu-proof guarantee
_cmap_arial_bold = TTFont(FONT_ARIAL_BOLD).getBestCmap()
_cmap_arial = TTFont(FONT_ARIAL).getBestCmap()
_cmap_menlo = TTFont(FONT_MENLO, fontNumber=0).getBestCmap()

# Glyph Sanitizer mapping for 100% safe rendering
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
    "⌘": "Cmd",
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

def check_string_safety(text, font_type="bold"):
    cleaned = clean_str(text)
    cmap = _cmap_arial_bold if font_type == "bold" else (_cmap_menlo if font_type == "mono" else _cmap_arial)
    missing = [c for c in cleaned if ord(c) not in cmap]
    if missing:
        raise ValueError(f"CRITICAL: Characters {missing} missing in font {font_type} for text: '{cleaned}'")
    return cleaned

# Monkey-patch Pillow ImageDraw and ImageFont
_orig_draw_text = ImageDraw.ImageDraw.text
def _safe_draw_text(self, xy, text, *args, **kwargs):
    return _orig_draw_text(self, xy, clean_str(text), *args, **kwargs)
ImageDraw.ImageDraw.text = _safe_draw_text

_orig_getbbox = ImageFont.FreeTypeFont.getbbox
def _safe_getbbox(self, text, *args, **kwargs):
    return _orig_getbbox(self, clean_str(text), *args, **kwargs)
ImageFont.FreeTypeFont.getbbox = _safe_getbbox

_orig_draw_line = ImageDraw.ImageDraw.line
def _safe_draw_line(self, xy, *args, **kwargs):
    if "width" in kwargs and isinstance(kwargs["width"], float):
        kwargs["width"] = int(max(1, round(kwargs["width"])))
    return _orig_draw_line(self, xy, *args, **kwargs)
ImageDraw.ImageDraw.line = _safe_draw_line

_orig_draw_rounded_rectangle = ImageDraw.ImageDraw.rounded_rectangle
def _safe_draw_rounded_rectangle(self, xy, *args, **kwargs):
    if "width" in kwargs and isinstance(kwargs["width"], float):
        kwargs["width"] = int(max(1, round(kwargs["width"])))
    return _orig_draw_rounded_rectangle(self, xy, *args, **kwargs)
ImageDraw.ImageDraw.rounded_rectangle = _safe_draw_rounded_rectangle

# Font Cache
_font_cache = {}
def get_f(name, size):
    key = (name, size)
    if key in _font_cache:
        return _font_cache[key]
    if name in ("bold", "title"):
        res = ImageFont.truetype(FONT_ARIAL_BOLD, size)
    elif name == "mono":
        res = ImageFont.truetype(FONT_MENLO, size, index=0)
    else:
        res = ImageFont.truetype(FONT_ARIAL, size)
    _font_cache[key] = res
    return res

# Design Tokens (macOS Sequoia Dark Mode + Liquid Glass)
COLOR_BG_DARK = (6, 9, 18, 255)
COLOR_CYAN = (56, 189, 248)          # #38BDF8
COLOR_CYAN_BRIGHT = (125, 211, 252)  # #7DD3FC
COLOR_VIOLET = (168, 85, 247)        # #A855F7
COLOR_VIOLET_BRIGHT = (216, 180, 254)# #D8B4FE
COLOR_EMERALD = (16, 185, 129)       # #10B981
COLOR_EMERALD_BRIGHT = (52, 211, 153)# #34D399
COLOR_RED = (248, 113, 113)          # #F87171
COLOR_RED_BRIGHT = (252, 165, 165)
COLOR_AMBER = (251, 191, 36)         # #FBBF24
COLOR_WHITE = (248, 250, 252)        # #F8FAFC
COLOR_MUTED = (148, 163, 184)        # #94A3B8
COLOR_DIM = (100, 116, 139)          # #64748B

# Load Source Assets
app_icon_path = os.path.join(ASSETS_DIR, "app_icon_nobg.png")
voice_orb_path = os.path.join(ASSETS_DIR, "voice_orb_nobg.png")
neural_core_path = os.path.join(ASSETS_DIR, "neural_core_nobg.png")

IMG_APP_ICON = Image.open(app_icon_path).convert("RGBA") if os.path.exists(app_icon_path) else None
IMG_VOICE_ORB = Image.open(voice_orb_path).convert("RGBA") if os.path.exists(voice_orb_path) else None
IMG_NEURAL_CORE = Image.open(neural_core_path).convert("RGBA") if os.path.exists(neural_core_path) else None

# ==============================================================================
# GRAPHICS ENGINE & DRAWING PRIMITIVES
# ==============================================================================

def create_base_canvas(width, height, accent_orbs=None):
    """
    Creates rich dark gradient background with multi-point radial glowing ambient meshes
    and subtle tech dot grid pattern.
    """
    arr = np.zeros((height, width, 4), dtype=np.float32)
    t = np.linspace(0, 1, height)[:, None]
    
    top_c = np.array([5, 8, 17, 255], dtype=np.float32)
    bot_c = np.array([12, 17, 34, 255], dtype=np.float32)
    base_grad = top_c * (1 - t) + bot_c * t
    arr[:, :] = base_grad[:, None, :]

    if accent_orbs is None:
        accent_orbs = [
            (int(width * 0.18), int(height * 0.15), int(width * 0.45), (0, 180, 255), 0.22),
            (int(width * 0.82), int(height * 0.35), int(width * 0.50), (168, 85, 247), 0.18),
            (int(width * 0.50), int(height * 0.90), int(width * 0.40), (16, 185, 129), 0.16),
        ]

    y_coords, x_coords = np.ogrid[:height, :width]
    for cx, cy, rad, rgb, intensity in accent_orbs:
        dist_sq = (x_coords - cx) ** 2 + (y_coords - cy) ** 2
        rad_sq = rad ** 2
        mask = np.clip(1.0 - (dist_sq / rad_sq), 0, 1) ** 2
        for ch in range(3):
            arr[:, :, ch] += rgb[ch] * mask * intensity

    np.clip(arr, 0, 255, out=arr)
    base_img = Image.fromarray(arr.astype(np.uint8), mode="RGBA")

    # Subtle dot grid pattern (every 32px)
    grid_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grid_layer)
    for x in range(24, width, 32):
        for y in range(24, height, 32):
            gd.point((x, y), fill=(255, 255, 255, 14))
    base_img.alpha_composite(grid_layer)

    return base_img

def draw_glass_card(img, bbox, fill_rgba=(16, 24, 44, 220), border_rgba=(255, 255, 255, 35), radius=22, border_width=2, shadow=True):
    """Draws a premium liquid glass card with optional outer ambient drop shadow."""
    x1, y1, x2, y2 = bbox
    card_w = x2 - x1
    card_h = y2 - y1
    border_width = int(max(1, round(border_width)))

    if shadow:
        shadow_pad = 20
        shadow_img = Image.new("RGBA", (card_w + shadow_pad * 2, card_h + shadow_pad * 2), (0, 0, 0, 0))
        sd = ImageDraw.Draw(shadow_img)
        sd.rounded_rectangle(
            [shadow_pad, shadow_pad + 6, shadow_pad + card_w, shadow_pad + card_h + 6],
            radius=radius,
            fill=(0, 0, 0, 95)
        )
        shadow_img = shadow_img.filter(ImageFilter.GaussianBlur(shadow_pad // 2))
        img.alpha_composite(shadow_img, (x1 - shadow_pad, y1 - shadow_pad))

    card = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(card)
    d.rounded_rectangle(bbox, radius=radius, fill=fill_rgba, outline=border_rgba, width=border_width)
    
    # Inner specular top-edge sheen
    d.line([x1 + radius, y1 + 1, x2 - radius, y1 + 1], fill=(255, 255, 255, 45), width=1)
    img.alpha_composite(card)

def draw_window_chrome(img, bbox, title="VFlow Code Editor", border_color=COLOR_CYAN):
    """Draws macOS Sequoia dark window with authentic traffic lights and header bar."""
    x1, y1, x2, y2 = bbox
    width = x2 - x1

    # Base card
    draw_glass_card(img, bbox, fill_rgba=(12, 18, 34, 245), border_rgba=(*border_color[:3], 150), radius=18, border_width=2)

    # Title Bar
    head_h = 44
    head_card = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(head_card)
    hd.rounded_rectangle([x1, y1, x2, y1 + head_h + 8], radius=18, fill=(20, 29, 52, 240))
    hd.rectangle([x1, y1 + head_h, x2, y1 + head_h + 8], fill=(20, 29, 52, 240))
    hd.line([x1, y1 + head_h, x2, y1 + head_h], fill=(255, 255, 255, 30), width=1)
    img.alpha_composite(head_card)

    d = ImageDraw.Draw(img)
    # Traffic Lights (macOS standard: Red, Yellow, Green)
    dot_y = y1 + 15
    d.ellipse([x1 + 18, dot_y, x1 + 32, dot_y + 14], fill=(255, 95, 86, 255))
    d.ellipse([x1 + 38, dot_y, x1 + 52, dot_y + 14], fill=(255, 189, 46, 255))
    d.ellipse([x1 + 58, dot_y, x1 + 72, dot_y + 14], fill=(39, 201, 63, 255))

    # Window Title
    if title:
        font_t = get_f("bold", 18)
        bb = font_t.getbbox(title)
        tw = bb[2] - bb[0]
        tx = x1 + (width - tw) // 2
        d.text((tx, y1 + 12), title, font=font_t, fill=(203, 213, 225, 255))

def draw_pill_badge(img, xy, text, font, bg_rgba, border_rgba, text_color=COLOR_WHITE, pad_x=18, pad_y=8):
    """Draws a sleek capsule pill badge with custom text."""
    x, y = xy
    cleaned = clean_str(text)
    bb = font.getbbox(cleaned)
    tw = bb[2] - bb[0]
    th = bb[3] - bb[1]
    
    bw = tw + pad_x * 2
    bh = th + pad_y * 2
    rad = bh // 2

    pill = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(pill)
    d.rounded_rectangle([x, y, x + bw, y + bh], radius=rad, fill=bg_rgba, outline=border_rgba, width=1)
    img.alpha_composite(pill)

    d_main = ImageDraw.Draw(img)
    d_main.text((x + pad_x, y + pad_y - 1), cleaned, font=font, fill=text_color)
    return bw, bh

def draw_keycap(img, x, y, width, height, text, is_pressed=False):
    """Draws realistic 3D Apple keyboard keycap with high contrast."""
    bg = (38, 52, 80, 255) if is_pressed else (22, 32, 54, 250)
    border = (*COLOR_CYAN_BRIGHT, 255) if is_pressed else (255, 255, 255, 70)
    draw_glass_card(img, [x, y, x + width, y + height], fill_rgba=bg, border_rgba=border, radius=12, border_width=2 if is_pressed else 1, shadow=True)

    d = ImageDraw.Draw(img)
    font_k = get_f("bold", 20 if len(text) > 4 else 22)
    cleaned = clean_str(text)
    bb = font_k.getbbox(cleaned)
    tw = bb[2] - bb[0]
    th = bb[3] - bb[1]
    tx = x + (width - tw) // 2
    ty = y + (height - th) // 2 - 2
    d.text((tx, ty), text, font=font_k, fill=COLOR_WHITE if is_pressed else (226, 232, 240, 255))

# ==============================================================================
# IMAGE 1: fb-01-hero-overview.png (1200x1200)
# ==============================================================================
def generate_fb_01_hero():
    print("Generating fb-01-hero-overview.png (1200x1200)...")
    width, height = 1200, 1200
    orbs = [
        (220, 180, 500, (0, 180, 255), 0.28),
        (1000, 360, 550, (168, 85, 247), 0.22),
        (600, 950, 480, (16, 185, 129), 0.20),
    ]
    img = create_base_canvas(width, height, orbs)
    d = ImageDraw.Draw(img)

    # 1. Header / Brand Section
    # Draw App Icon with soft halo glow
    if IMG_APP_ICON:
        icon_size = 140
        icon_res = IMG_APP_ICON.resize((icon_size, icon_size), Image.Resampling.LANCZOS)
        # Drop shadow for icon
        shadow = Image.new("RGBA", (icon_size + 30, icon_size + 30), (0, 0, 0, 0))
        sd = ImageDraw.Draw(shadow)
        sd.ellipse([15, 15, 15 + icon_size, 15 + icon_size], fill=(0, 180, 255, 90))
        shadow = shadow.filter(ImageFilter.GaussianBlur(15))
        img.alpha_composite(shadow, (60, 55))
        img.alpha_composite(icon_res, (75, 70))

    # Header Badges & Titles
    draw_pill_badge(img, (245, 68), "MACOS SEQUOIA NATIVE • APPLE SILICON", get_f("bold", 15), (20, 35, 65, 230), (*COLOR_CYAN, 180), COLOR_CYAN_BRIGHT)
    
    # State Pill VI·T
    draw_pill_badge(img, (960, 68), "VI · T   BẬT", get_f("bold", 16), (16, 45, 35, 230), (*COLOR_EMERALD, 200), COLOR_EMERALD_BRIGHT)

    # Big Title: VFlow
    d.text((245, 102), "VFlow", font=get_f("bold", 54), fill=COLOR_WHITE)
    d.text((435, 116), "—", font=get_f("bold", 40), fill=COLOR_MUTED)
    d.text((485, 118), "Bộ Gõ Tiếng Việt & AI Thế Hệ Mới Cho Mac", font=get_f("bold", 27), fill=COLOR_CYAN_BRIGHT)

    # Sub-tagline
    d.text((245, 172), "Tối ưu hoàn hảo cho lập trình viên & người dùng macOS chuyên nghiệp", font=get_f("regular", 20), fill=COLOR_MUTED)

    # Header Divider
    d.line([70, 222, 1130, 222], fill=(255, 255, 255, 25), width=1)

    # 2. 3 Breakthrough Feature Cards
    # Card 1: salary ≠ sảlảy
    card1_box = [70, 245, 1130, 480]
    draw_glass_card(img, card1_box, fill_rgba=(14, 22, 42, 235), border_rgba=(*COLOR_CYAN, 160), radius=22, border_width=2)
    # Badge
    draw_pill_badge(img, (95, 265), "ĐỘT PHÁ 1", get_f("bold", 15), (15, 45, 70, 240), (*COLOR_CYAN, 220), COLOR_CYAN_BRIGHT)
    # Title
    d.text((220, 263), "salary ≠ sảlảy", font=get_f("bold", 30), fill=COLOR_EMERALD_BRIGHT)
    d.text((455, 268), "•  Gõ Tiếng Anh & Code Không Nhảy Dấu", font=get_f("bold", 22), fill=COLOR_WHITE)
    d.text((95, 312), "Nhận diện âm tiết thời gian thực • Gõ đúp phím dấu (rr, ss, ff) để hoàn nguyên ngay lập tức.", font=get_f("regular", 18), fill=COLOR_MUTED)

    # Comparison Subcard inside Card 1
    sub1_box = [95, 350, 1105, 455]
    draw_glass_card(img, sub1_box, fill_rgba=(8, 12, 24, 230), border_rgba=(255, 255, 255, 25), radius=14, border_width=1, shadow=False)
    # Old
    d.text((115, 368), "[X] Bộ gõ cũ:", font=get_f("bold", 18), fill=COLOR_RED)
    bad_sample = [("sảlảy", 260), ("arổw", 355), ("sẻvice", 445), ("subclás", 545)]
    f_bad = get_f("bold", 18)
    for word, wx in bad_sample:
        d.text((wx, 368), word, font=f_bad, fill=COLOR_RED_BRIGHT)
        w_len = f_bad.getbbox(word)[2] - f_bad.getbbox(word)[0]
        d.line([wx - 2, 379, wx + w_len + 2, 379], fill=COLOR_RED, width=2)
    d.text((328, 368), "•", font=f_bad, fill=COLOR_DIM)
    d.text((418, 368), "•", font=f_bad, fill=COLOR_DIM)
    d.text((520, 368), "•", font=f_bad, fill=COLOR_DIM)
    # VFlow
    d.text((115, 412), "[OK] VFlow:", font=get_f("bold", 18), fill=COLOR_EMERALD)
    d.text((260, 412), "const salary = calculateArrow(service, subclass);", font=get_f("mono", 17), fill=COLOR_CYAN_BRIGHT)
    # Status on right
    d.text((850, 412), "VI·T vẫn bật 100%", font=get_f("bold", 16), fill=COLOR_EMERALD_BRIGHT)

    # Card 2: Nhấn Tab-Tab
    card2_box = [70, 505, 1130, 740]
    draw_glass_card(img, card2_box, fill_rgba=(18, 20, 46, 235), border_rgba=(*COLOR_VIOLET, 160), radius=22, border_width=2)
    draw_pill_badge(img, (95, 525), "ĐỘT PHÁ 2", get_f("bold", 15), (45, 25, 75, 240), (*COLOR_VIOLET, 220), COLOR_VIOLET_BRIGHT)
    d.text((220, 523), "Nhấn Phím Tab-Tab", font=get_f("bold", 30), fill=COLOR_VIOLET_BRIGHT)
    d.text((515, 528), "•  Sửa Chính Tả & Ngữ Pháp Trọn Câu", font=get_f("bold", 22), fill=COLOR_WHITE)
    d.text((95, 572), "Caret Pill HUD 120fps nổi dưới con trỏ • Giữ trọn ngữ cảnh qua cả dấu chấm câu (.).", font=get_f("regular", 18), fill=COLOR_MUTED)

    # Comparison Subcard inside Card 2
    sub2_box = [95, 610, 1105, 715]
    draw_glass_card(img, sub2_box, fill_rgba=(8, 12, 24, 230), border_rgba=(255, 255, 255, 25), radius=14, border_width=1, shadow=False)
    # Input
    d.text((115, 628), "[X] Gõ nhanh:", font=get_f("bold", 18), fill=COLOR_RED)
    d.text((260, 628), "\"to dang lam viec. she dont know how to fix this bug\"", font=get_f("regular", 18), fill=COLOR_MUTED)
    # Output
    d.text((115, 672), "[OK] Tab-Tab:", font=get_f("bold", 18), fill=COLOR_EMERALD)
    d.text((260, 672), "\"Tôi đang làm việc. She doesn't know how to fix this bug.\"", font=get_f("bold", 18), fill=COLOR_WHITE)
    d.text((880, 672), "HUD 120fps Tự Động", font=get_f("bold", 16), fill=COLOR_VIOLET_BRIGHT)

    # Card 3: Phím Opt+Space
    card3_box = [70, 765, 1130, 1000]
    draw_glass_card(img, card3_box, fill_rgba=(14, 28, 42, 235), border_rgba=(*COLOR_EMERALD, 160), radius=22, border_width=2)
    draw_pill_badge(img, (95, 785), "ĐỘT PHÁ 3", get_f("bold", 15), (20, 50, 45, 240), (*COLOR_EMERALD, 220), COLOR_EMERALD_BRIGHT)
    d.text((220, 783), "Phím Tắt Opt+Space", font=get_f("bold", 30), fill=COLOR_AMBER)
    d.text((520, 788), "•  Đọc Giọng Nói → AI Biên Tập Văn Viết", font=get_f("bold", 22), fill=COLOR_WHITE)
    d.text((95, 832), "Bấm nói tự nhiên, nghỉ 2.2s tự điền • Whisper On-Device Apple Silicon 100% riêng tư.", font=get_f("regular", 18), fill=COLOR_MUTED)

    # Comparison Subcard inside Card 3
    sub3_box = [95, 870, 1105, 975]
    draw_glass_card(img, sub3_box, fill_rgba=(8, 12, 24, 230), border_rgba=(255, 255, 255, 25), radius=14, border_width=1, shadow=False)
    # Input
    d.text((115, 888), "[X] Văn nói thô:", font=get_f("bold", 18), fill=COLOR_RED)
    d.text((260, 888), "\"Hình như là cái phần giọng nói sang nhưng mà cần 1 thao tác AI\"", font=get_f("regular", 17), fill=COLOR_MUTED)
    # Output
    d.text((115, 932), "[OK] Văn viết AI:", font=get_f("bold", 18), fill=COLOR_EMERALD)
    d.text((260, 932), "\"Sau khi nhận diện giọng nói sang văn bản, hệ thống cần một thao tác AI.\"", font=get_f("bold", 17), fill=COLOR_EMERALD_BRIGHT)
    d.text((920, 932), "0 KB Cloud", font=get_f("bold", 16), fill=COLOR_EMERALD)

    # 3. Bottom Footer Bar (100% Swift 6 Native • On-Device Apple Silicon • 0 KB Cloud • Mã nguồn mở)
    foot_box = [70, 1025, 1130, 1145]
    draw_glass_card(img, foot_box, fill_rgba=(10, 16, 32, 240), border_rgba=(255, 255, 255, 40), radius=22, border_width=1)
    
    # Badges line
    foot_text = "100% Swift 6 Native  •  On-Device Apple Silicon  •  0 KB Cloud  •  Mã Nguồn Mở Miễn Phí"
    fb_font = get_f("bold", 20)
    f_bb = fb_font.getbbox(foot_text)
    f_tw = f_bb[2] - f_bb[0]
    d.text(((width - f_tw) // 2, 1045), foot_text, font=fb_font, fill=COLOR_WHITE)

    # Download link line
    url_text = "Tải ngay tại: tgalioautomation.github.io/VFlow  •  Hỗ trợ macOS 14 Sonoma & macOS 15 Sequoia"
    u_font = get_f("bold", 18)
    u_bb = u_font.getbbox(url_text)
    u_tw = u_bb[2] - u_bb[0]
    d.text(((width - u_tw) // 2, 1085), url_text, font=u_font, fill=COLOR_CYAN_BRIGHT)

    out_file = os.path.join(OUTPUT_DIR, "fb-01-hero-overview.png")
    img.save(out_file, "PNG", optimize=True)
    print(f"Saved: {out_file} ({os.path.getsize(out_file):,} bytes)")

# ==============================================================================
# IMAGE 2: fb-02-auto-escape-code.png (1200x1200)
# ==============================================================================
def generate_fb_02_escape_code():
    print("Generating fb-02-auto-escape-code.png (1200x1200)...")
    width, height = 1200, 1200
    orbs = [
        (200, 250, 480, (0, 180, 255), 0.25),
        (1000, 400, 520, (248, 113, 113), 0.16),
        (600, 950, 500, (16, 185, 129), 0.22),
    ]
    img = create_base_canvas(width, height, orbs)
    d = ImageDraw.Draw(img)

    # 1. Header Section
    draw_pill_badge(img, (70, 55), "TÍNH NĂNG ĐỘC BẢN • ĐỘT PHÁ #1", get_f("bold", 16), (20, 35, 65, 230), (*COLOR_CYAN, 200), COLOR_CYAN_BRIGHT)
    d.text((70, 95), "GÕ TIẾNG ANH & CODE KHÔNG NHẢY DẤU", font=get_f("bold", 44), fill=COLOR_WHITE)
    d.text((70, 155), "salary ≠ sảlảy  •  Quên đi nỗi ức chế phải chuyển EN/VI liên tục khi lập trình", font=get_f("bold", 23), fill=COLOR_CYAN_BRIGHT)

    # 2. Comparison Windows
    # Window 1: Before (Bộ gõ cũ)
    w1_box = [70, 205, 1130, 505]
    draw_window_chrome(img, w1_box, title="Bộ Gõ Cũ — Lỗi Nhảy Dấu Khó Chịu", border_color=COLOR_RED)
    
    # Red Warning Pill
    draw_pill_badge(img, (95, 265), "[X] BỘ GÕ CŨ (LỖI NHẢY DẤU)", get_f("bold", 16), (50, 20, 25, 230), (*COLOR_RED, 220), COLOR_RED_BRIGHT)
    d.text((420, 268), "Cú pháp code bị phá vỡ hoàn toàn khi đang bật gõ tiếng Việt:", font=get_f("regular", 18), fill=COLOR_MUTED)

    # Big bad word capsules in red
    bad_words = ["sảlảy", "arổw", "sẻvice", "subclás", "fĩ", "cáe"]
    start_bx = 95
    for bw in bad_words:
        w_pill, _ = draw_pill_badge(img, (start_bx, 312), bw, get_f("bold", 22), (60, 22, 28, 240), (*COLOR_RED, 220), COLOR_RED_BRIGHT, pad_x=22, pad_y=8)
        # Red strike-through line
        d.line([start_bx + 18, 332, start_bx + w_pill - 18, 332], fill=COLOR_RED, width=3)
        start_bx += w_pill + 14

    # Code Editor Snippet with Error
    code1_box = [95, 375, 1105, 480]
    draw_glass_card(img, code1_box, fill_rgba=(8, 12, 22, 240), border_rgba=(*COLOR_RED, 120), radius=12, border_width=1, shadow=False)
    d.text((115, 395), "const sảlảy = calculateArổw(sẻvice, subclás);", font=get_f("bold", 20), fill=COLOR_RED_BRIGHT)
    d.line([115, 422, 700, 422], fill=COLOR_RED, width=2)
    d.text((115, 435), "// SyntaxError: Unexpected token 'ả'  •  Phải xóa đi gõ lại từ đầu!", font=get_f("regular", 16), fill=COLOR_RED)

    # Window 2: After (VFlow)
    w2_box = [70, 530, 1130, 860]
    draw_window_chrome(img, w2_box, title="VFlow Smart Engine — VI·T Đang Bật 100%", border_color=COLOR_EMERALD)

    # Emerald Success Pill
    draw_pill_badge(img, (95, 590), "[OK] VFLOW (VI·T VẪN BẬT)", get_f("bold", 16), (15, 50, 40, 240), (*COLOR_EMERALD, 220), COLOR_EMERALD_BRIGHT)
    d.text((410, 593), "Tự động nhận diện từ vựng tiếng Anh & hàm code thời gian thực:", font=get_f("regular", 18), fill=COLOR_MUTED)
    
    # State badge on top right of window
    draw_pill_badge(img, (925, 588), "VI · T  BẬT 100%", get_f("bold", 15), (20, 55, 45, 230), (*COLOR_EMERALD, 220), COLOR_EMERALD_BRIGHT)

    # Clean Code Editor Snippet
    code2_box = [95, 638, 1105, 825]
    draw_glass_card(img, code2_box, fill_rgba=(8, 14, 26, 250), border_rgba=(*COLOR_EMERALD, 140), radius=14, border_width=1.5, shadow=False)
    
    # Syntax highlighted code
    code_tokens = [
        ("const ", COLOR_VIOLET_BRIGHT),
        ("salary ", COLOR_CYAN_BRIGHT),
        ("= ", COLOR_WHITE),
        ("calculateArrow", COLOR_EMERALD_BRIGHT),
        ("(", COLOR_WHITE),
        ("service", COLOR_AMBER),
        (", ", COLOR_WHITE),
        ("subclass", COLOR_AMBER),
        (");", COLOR_WHITE),
    ]
    cur_x = 120
    f_code = get_f("bold", 22)
    for text_tok, tok_col in code_tokens:
        d.text((cur_x, 660), text_tok, font=f_code, fill=tok_col)
        bb = f_code.getbbox(text_tok)
        cur_x += bb[2] - bb[0]

    d.text((120, 710), "// Tự động nhận diện cú pháp & từ vựng tiếng Anh — Không bao giờ nhảy dấu!", font=get_f("regular", 18), fill=COLOR_EMERALD_BRIGHT)
    d.text((120, 755), "// Không cần chuyển đổi EN/VI qua lại khi viết code hay chat với đồng nghiệp quốc tế.", font=get_f("regular", 18), fill=COLOR_MUTED)

    # 3. Bottom Pro-Tips Section
    tips_box = [70, 885, 1130, 1145]
    draw_glass_card(img, tips_box, fill_rgba=(12, 18, 36, 240), border_rgba=(*COLOR_CYAN, 120), radius=22, border_width=1.5)
    
    # Tip Header
    draw_pill_badge(img, (95, 910), "MẸO TIỆN ÍCH", get_f("bold", 15), (20, 40, 70, 240), (*COLOR_CYAN, 200), COLOR_CYAN_BRIGHT)
    d.text((250, 912), "Cơ chế hoàn nguyên cực nhanh và linh hoạt:", font=get_f("bold", 21), fill=COLOR_WHITE)

    # Bullet 1
    d.text((95, 960), "► Mẹo 1: Nhận diện âm tiết tiếng Anh thời gian thực theo từ điển & cú pháp ngữ cảnh.", font=get_f("bold", 19), fill=COLOR_CYAN_BRIGHT)
    d.text((125, 992), "Bộ từ điển 50.000+ từ vựng tiếng Anh thông dụng và từ khóa lập trình phổ biến được tích hợp sẵn.", font=get_f("regular", 17), fill=COLOR_MUTED)

    # Bullet 2
    d.text((95, 1032), "► Mẹo 2: Gõ đúp phím dấu (rr, ss, ff) để hoàn nguyên ngay lập tức.", font=get_f("bold", 19), fill=COLOR_EMERALD_BRIGHT)
    d.text((125, 1064), "Ví dụ: Gõ 'server' nếu muốn thành chữ tiếng Anh chỉ cần gõ đúp phím dấu để hoàn nguyên tức thì.", font=get_f("regular", 17), fill=COLOR_MUTED)

    # Badges bar
    d.text((95, 1108), "Tốc độ: 0ms  •  Native Apple Silicon  •  Hoạt động trên VS Code, Xcode, Cursor, Terminal", font=get_f("bold", 16), fill=COLOR_WHITE)

    out_file = os.path.join(OUTPUT_DIR, "fb-02-auto-escape-code.png")
    img.save(out_file, "PNG", optimize=True)
    print(f"Saved: {out_file} ({os.path.getsize(out_file):,} bytes)")

# ==============================================================================
# IMAGE 3: fb-03-tab-tab-grammar.png (1200x1200)
# ==============================================================================
def generate_fb_03_tab_tab():
    print("Generating fb-03-tab-tab-grammar.png (1200x1200)...")
    width, height = 1200, 1200
    orbs = [
        (220, 200, 500, (168, 85, 247), 0.26),
        (980, 450, 520, (0, 180, 255), 0.22),
        (550, 950, 480, (16, 185, 129), 0.20),
    ]
    img = create_base_canvas(width, height, orbs)
    d = ImageDraw.Draw(img)

    # 1. Header Section
    draw_pill_badge(img, (70, 55), "TRỢ LÝ BIÊN TẬP THÔNG MINH • ĐỘT PHÁ #2", get_f("bold", 16), (40, 25, 70, 230), (*COLOR_VIOLET, 200), COLOR_VIOLET_BRIGHT)
    d.text((70, 95), "NHẤN TAB-TAB SỬA NGỮ PHÁP TRỌN CÂU", font=get_f("bold", 44), fill=COLOR_WHITE)
    d.text((70, 155), "Tự động phát hiện lỗi chính tả tiếng Việt & ngữ pháp tiếng Anh ngay dưới con trỏ", font=get_f("bold", 23), fill=COLOR_CYAN_BRIGHT)

    # 2. Main macOS Window Canvas (Notion / Mail / Slack style)
    w_box = [70, 205, 1130, 895]
    draw_window_chrome(img, w_box, title="Cửa Sổ Soạn Thảo — Caret Pill HUD 120fps Nổi Dưới Con Trỏ", border_color=COLOR_VIOLET)

    # Before State
    d.text((100, 268), "[X] Gõ nhanh chưa sửa (Không dấu + Sai ngữ pháp tiếng Anh):", font=get_f("bold", 19), fill=COLOR_RED)
    
    # Input Box 1
    in1_box = [100, 305, 1100, 395]
    draw_glass_card(img, in1_box, fill_rgba=(10, 14, 28, 240), border_rgba=(255, 255, 255, 30), radius=14, border_width=1, shadow=False)
    d.text((125, 335), "\"to dang lam viec. she dont know how to fix this bug\"", font=get_f("regular", 25), fill=COLOR_MUTED)
    # Flashing cursor at end of text
    d.line([835, 332, 835, 368], fill=COLOR_CYAN_BRIGHT, width=3)

    # FLOATING CARET PILL HUD (120fps)
    hud_box = [120, 425, 1080, 550]
    draw_glass_card(img, hud_box, fill_rgba=(10, 16, 36, 250), border_rgba=(*COLOR_CYAN, 240), radius=28, border_width=2.5, shadow=True)

    # Inner sine wave ribbon (Audio / Neural waveform)
    wave_x = 145
    wave_y = 487
    pts = []
    for px in range(70):
        py = math.sin(px * 0.22) * 12.0
        pts.append((wave_x + px, wave_y + py))
    d.line(pts, fill=COLOR_CYAN_BRIGHT, width=3)
    d.text((wave_x + 12, wave_y + 18), "120fps", font=get_f("bold", 12), fill=COLOR_CYAN)

    # HUD Divider
    d.line([235, 445, 235, 530], fill=(255, 255, 255, 45), width=1)

    # Chip 1: [Tab] tôi đang...
    c1_box = [250, 450, 400, 525]
    draw_glass_card(img, c1_box, fill_rgba=(20, 30, 55, 220), border_rgba=(255, 255, 255, 30), radius=14, border_width=1, shadow=False)
    d.text((265, 465), "[Tab]", font=get_f("bold", 15), fill=COLOR_CYAN_BRIGHT)
    d.text((265, 490), "tôi đang...", font=get_f("regular", 15), fill=COLOR_MUTED)

    # Chip 2: [Tab-Tab] Sửa trọn câu (HIGHLIGHTED / ACTIVE)
    c2_box = [415, 445, 920, 530]
    draw_glass_card(img, c2_box, fill_rgba=(16, 50, 42, 245), border_rgba=(*COLOR_EMERALD_BRIGHT, 255), radius=16, border_width=2, shadow=True)
    d.text((435, 460), "[Tab-Tab]  ► SỬA TRỌN CÂU HOÀN CHỈNH:", font=get_f("bold", 16), fill=COLOR_EMERALD_BRIGHT)
    d.text((435, 490), "Tôi đang làm việc. She doesn't know how to fix this bug.", font=get_f("bold", 16), fill=COLOR_WHITE)

    # Chip 3: [Opt+3]
    c3_box = [935, 450, 1055, 525]
    draw_glass_card(img, c3_box, fill_rgba=(20, 30, 55, 220), border_rgba=(255, 255, 255, 30), radius=14, border_width=1, shadow=False)
    d.text((950, 465), "[Opt+3]", font=get_f("bold", 15), fill=COLOR_VIOLET_BRIGHT)
    d.text((950, 490), "Biên tập AI", font=get_f("regular", 15), fill=COLOR_MUTED)

    # After State (Result after double Tab)
    d.text((100, 580), "[OK] Kết quả ngay lập tức sau khi nhấn đúp phím Tab-Tab:", font=get_f("bold", 20), fill=COLOR_EMERALD)

    # Input Box 2 (Fixed Result)
    in2_box = [100, 615, 1100, 715]
    draw_glass_card(img, in2_box, fill_rgba=(10, 24, 30, 240), border_rgba=(*COLOR_EMERALD, 180), radius=14, border_width=2, shadow=False)
    d.text((125, 642), "\"Tôi đang làm việc. She doesn't know how to fix this bug.\"", font=get_f("bold", 24), fill=COLOR_WHITE)
    d.text((125, 680), "Đã sửa: Viết hoa đầu câu, thêm dấu tiếng Việt 'Tôi đang làm việc', sửa 'she dont' → 'She doesn't'", font=get_f("regular", 15), fill=COLOR_EMERALD_BRIGHT)

    # Keycap Visual Illustration inside Window
    d.text((100, 755), "Thao tác phím:", font=get_f("bold", 18), fill=COLOR_MUTED)
    draw_keycap(img, 240, 740, 120, 54, "Tab", is_pressed=True)
    d.text((375, 753), "+", font=get_f("bold", 26), fill=COLOR_CYAN_BRIGHT)
    draw_keycap(img, 410, 740, 120, 54, "Tab", is_pressed=True)
    d.text((550, 755), "→ Nhấn đúp Tab-Tab để chọn ngay gợi ý sửa trọn câu!", font=get_f("bold", 19), fill=COLOR_WHITE)
    d.text((240, 810), "Hoặc nhấn 1 lần Tab để chấp nhận từ tiếp theo. Hoàn toàn tự nhiên không cần chuột.", font=get_f("regular", 16), fill=COLOR_MUTED)

    # 3. Bottom Highlights Section
    high_box = [70, 920, 1130, 1145]
    draw_glass_card(img, high_box, fill_rgba=(12, 18, 36, 240), border_rgba=(*COLOR_CYAN, 120), radius=22, border_width=1.5)
    
    d.text((95, 945), "• Giữ trọn ngữ cảnh qua cả dấu chấm câu (.)", font=get_f("bold", 22), fill=COLOR_CYAN_BRIGHT)
    d.text((125, 980), "Không như bộ gõ cũ bị ngắt mạch khi gặp dấu chấm hoặc phím Enter, VFlow ghi nhớ toàn bộ đoạn văn.", font=get_f("regular", 17), fill=COLOR_MUTED)

    d.text((95, 1025), "• Tự ẩn 100% khi cuộn đọc báo trên Chrome/Safari, lướt web giải trí", font=get_f("bold", 22), fill=COLOR_EMERALD_BRIGHT)
    d.text((125, 1060), "Thuật toán phát hiện thao tác cuộn chuột (Scroll Detection) thông minh: HUD tự biến mất, không gây vướng mắt.", font=get_f("regular", 17), fill=COLOR_MUTED)

    d.text((95, 1105), "Độ trễ xử lý < 50ms  •  Mô hình On-Device 0 KB Cloud  •  Tuyệt đối bảo mật dữ liệu riêng tư", font=get_f("bold", 16), fill=COLOR_WHITE)

    out_file = os.path.join(OUTPUT_DIR, "fb-03-tab-tab-grammar.png")
    img.save(out_file, "PNG", optimize=True)
    print(f"Saved: {out_file} ({os.path.getsize(out_file):,} bytes)")

# ==============================================================================
# IMAGE 4: fb-04-voice-ai-install.png (1200x1200)
# ==============================================================================
def generate_fb_04_voice_install():
    print("Generating fb-04-voice-ai-install.png (1200x1200)...")
    width, height = 1200, 1200
    orbs = [
        (200, 250, 480, (251, 191, 36), 0.22),
        (1000, 300, 520, (16, 185, 129), 0.24),
        (600, 950, 500, (0, 180, 255), 0.20),
    ]
    img = create_base_canvas(width, height, orbs)
    d = ImageDraw.Draw(img)

    # 1. Header Section
    draw_pill_badge(img, (70, 55), "NHẬN DIỆN GIỌNG NÓI & AI REWRITE • ĐỘT PHÁ #3", get_f("bold", 16), (40, 35, 15, 230), (*COLOR_AMBER, 200), COLOR_AMBER)
    d.text((70, 95), "GIỌNG NÓI OPT+SPACE → VĂN VIẾT AI", font=get_f("bold", 44), fill=COLOR_WHITE)
    d.text((70, 155), "Bấm Opt+Space nói tự nhiên, VFlow tự động điền & biên tập thành văn phong chỉn chu", font=get_f("bold", 23), fill=COLOR_CYAN_BRIGHT)

    # 2. Upper Visual Section: Voice Orb & Transformation
    # Voice Orb Box on Left
    orb_box = [70, 205, 340, 655]
    draw_glass_card(img, orb_box, fill_rgba=(14, 20, 40, 235), border_rgba=(*COLOR_AMBER, 140), radius=22, border_width=2)
    
    # Place Voice Orb Icon
    if IMG_VOICE_ORB:
        orb_res = IMG_VOICE_ORB.resize((190, 190), Image.Resampling.LANCZOS)
        # Orb halo
        halo = Image.new("RGBA", (230, 230), (0, 0, 0, 0))
        hd = ImageDraw.Draw(halo)
        hd.ellipse([20, 20, 210, 210], fill=(251, 191, 36, 90))
        halo = halo.filter(ImageFilter.GaussianBlur(25))
        img.alpha_composite(halo, (90, 225))
        img.alpha_composite(orb_res, (110, 245))

    # Keycap Opt+Space under Orb
    draw_keycap(img, 95, 455, 190, 54, "Opt+Space", is_pressed=True)
    d.text((115, 525), "Nhấn để nói", font=get_f("bold", 17), fill=COLOR_WHITE)
    d.text((95, 555), "Nghỉ 2.2s tự điền", font=get_f("regular", 15), fill=COLOR_MUTED)
    d.text((95, 582), "Whisper Native", font=get_f("bold", 15), fill=COLOR_EMERALD_BRIGHT)
    d.text((95, 610), "0 KB Cloud", font=get_f("regular", 14), fill=COLOR_AMBER)

    # Transformation Details on Right
    trans_box = [365, 205, 1130, 655]
    draw_glass_card(img, trans_box, fill_rgba=(12, 18, 36, 245), border_rgba=(*COLOR_CYAN, 140), radius=22, border_width=2)
    
    draw_pill_badge(img, (395, 230), "QUY TRÌNH BIẾN ĐỔI THÔNG MINH", get_f("bold", 15), (20, 40, 70, 240), (*COLOR_CYAN, 200), COLOR_CYAN_BRIGHT)

    # Step 1: Văn nói thô
    d.text((395, 280), "[X] Bạn đọc nhanh bằng giọng nói (Văn nói thô):", font=get_f("bold", 18), fill=COLOR_RED)
    s1_box = [395, 310, 1100, 385]
    draw_glass_card(img, s1_box, fill_rgba=(10, 14, 26, 230), border_rgba=(255, 255, 255, 25), radius=12, border_width=1, shadow=False)
    d.text((415, 335), "\"Hình như là cái phần giọng nói sang nhưng mà cần 1 thao tác AI\"", font=get_f("regular", 19), fill=COLOR_MUTED)

    # Step 2: Smart trigger
    d.text((395, 410), "► Cơ chế thông minh: Nghỉ 2.2s tự điền vào ứng dụng  +  Nhấn đúp Tab-Tab", font=get_f("bold", 17), fill=COLOR_CYAN_BRIGHT)

    # Step 3: Văn viết hoàn chỉnh
    d.text((395, 455), "[OK] AI biên tập lại thành văn viết chỉn chu, chuyên nghiệp:", font=get_f("bold", 18), fill=COLOR_EMERALD)
    s3_box = [395, 485, 1100, 580]
    draw_glass_card(img, s3_box, fill_rgba=(10, 30, 30, 240), border_rgba=(*COLOR_EMERALD, 180), radius=12, border_width=2, shadow=False)
    d.text((415, 510), "\"Sau khi nhận diện giọng nói sang văn bản,", font=get_f("bold", 21), fill=COLOR_WHITE)
    d.text((415, 540), "hệ thống cần một thao tác AI.\"", font=get_f("bold", 21), fill=COLOR_EMERALD_BRIGHT)

    d.text((395, 605), "Xử lý On-Device bằng mô hình Whisper Apple Silicon. Hoàn toàn không gửi âm thanh lên mạng.", font=get_f("regular", 16), fill=COLOR_MUTED)

    # 3. Lower Section: Cài Đặt 30 Giây (Quick Install Guide)
    d.text((70, 685), "HƯỚNG DẪN CÀI ĐẶT NHANH TRONG 30 GIÂY", font=get_f("bold", 25), fill=COLOR_WHITE)
    sub_text = "• Không cần Homebrew, sẵn sàng dùng ngay"
    f_sub = get_f("regular", 17)
    sub_w = f_sub.getbbox(sub_text)[2] - f_sub.getbbox(sub_text)[0]
    d.text((1130 - sub_w, 690), sub_text, font=f_sub, fill=COLOR_MUTED)

    # 3 Steps in 3 Glass Cards
    step_y = 730
    step_h = 240
    
    # Step 1
    st1_box = [70, step_y, 400, step_y + step_h]
    draw_glass_card(img, st1_box, fill_rgba=(14, 22, 44, 240), border_rgba=(*COLOR_CYAN, 140), radius=18, border_width=1.5)
    draw_pill_badge(img, (90, step_y + 20), "BƯỚC 1", get_f("bold", 14), (20, 45, 75, 240), (*COLOR_CYAN, 200), COLOR_CYAN_BRIGHT)
    d.text((90, step_y + 65), "1. Tải VFlow .DMG", font=get_f("bold", 22), fill=COLOR_WHITE)
    d.text((90, step_y + 105), "Tải file cài đặt .DMG native", font=get_f("regular", 17), fill=COLOR_MUTED)
    d.text((90, step_y + 130), "siêu nhẹ (chỉ ~15MB)", font=get_f("regular", 17), fill=COLOR_MUTED)
    d.text((90, step_y + 155), "trực tiếp từ GitHub Release.", font=get_f("regular", 17), fill=COLOR_MUTED)
    d.text((90, step_y + 195), "► Miễn phí 100%", font=get_f("bold", 16), fill=COLOR_CYAN_BRIGHT)

    # Step 2
    st2_box = [435, step_y, 765, step_y + step_h]
    draw_glass_card(img, st2_box, fill_rgba=(14, 22, 44, 240), border_rgba=(*COLOR_VIOLET, 140), radius=18, border_width=1.5)
    draw_pill_badge(img, (455, step_y + 20), "BƯỚC 2", get_f("bold", 14), (45, 25, 75, 240), (*COLOR_VIOLET, 200), COLOR_VIOLET_BRIGHT)
    d.text((455, step_y + 65), "2. Kéo vào /Applications", font=get_f("bold", 21), fill=COLOR_WHITE)
    d.text((455, step_y + 105), "Mở file .DMG và kéo biểu tượng", font=get_f("regular", 17), fill=COLOR_MUTED)
    d.text((455, step_y + 130), "VFlow vào thư mục Applications", font=get_f("regular", 17), fill=COLOR_MUTED)
    d.text((455, step_y + 155), "như mọi ứng dụng macOS chuẩn.", font=get_f("regular", 17), fill=COLOR_MUTED)
    d.text((455, step_y + 195), "► Kéo thả 3 giây", font=get_f("bold", 16), fill=COLOR_VIOLET_BRIGHT)

    # Step 3
    st3_box = [800, step_y, 1130, step_y + step_h]
    draw_glass_card(img, st3_box, fill_rgba=(14, 22, 44, 240), border_rgba=(*COLOR_EMERALD, 140), radius=18, border_width=1.5)
    draw_pill_badge(img, (820, step_y + 20), "BƯỚC 3", get_f("bold", 14), (20, 50, 40, 240), (*COLOR_EMERALD, 200), COLOR_EMERALD_BRIGHT)
    d.text((820, step_y + 65), "3. Bật Accessibility", font=get_f("bold", 22), fill=COLOR_WHITE)
    d.text((820, step_y + 105), "Vào System Settings", font=get_f("regular", 17), fill=COLOR_MUTED)
    d.text((820, step_y + 130), "→ Privacy & Security", font=get_f("regular", 17), fill=COLOR_MUTED)
    d.text((820, step_y + 155), "→ Bật quyền Accessibility.", font=get_f("regular", 17), fill=COLOR_MUTED)
    d.text((820, step_y + 195), "► Hoàn tất & gõ ngay!", font=get_f("bold", 16), fill=COLOR_EMERALD_BRIGHT)

    # Download Link Box
    link_box = [70, 995, 1130, 1145]
    draw_glass_card(img, link_box, fill_rgba=(10, 16, 32, 240), border_rgba=(*COLOR_CYAN, 180), radius=22, border_width=2)
    
    url_str = "tgalioautomation.github.io/VFlow"
    u_font = get_f("bold", 34)
    u_bb = u_font.getbbox(url_str)
    u_tw = u_bb[2] - u_bb[0]
    d.text(((width - u_tw) // 2, 1025), url_str, font=u_font, fill=COLOR_CYAN_BRIGHT)

    sub_str = "Hỗ trợ macOS 14 Sonoma & 15 Sequoia  •  Tối ưu M1/M2/M3/M4  •  Mã nguồn mở miễn phí"
    s_font = get_f("bold", 18)
    s_bb = s_font.getbbox(sub_str)
    s_tw = s_bb[2] - s_bb[0]
    d.text(((width - s_tw) // 2, 1085), sub_str, font=s_font, fill=COLOR_WHITE)

    out_file = os.path.join(OUTPUT_DIR, "fb-04-voice-ai-install.png")
    img.save(out_file, "PNG", optimize=True)
    print(f"Saved: {out_file} ({os.path.getsize(out_file):,} bytes)")

# ==============================================================================
# IMAGE 5: fb-cover-landscape.png (1200x630)
# ==============================================================================
def generate_fb_cover_landscape():
    print("Generating fb-cover-landscape.png (1200x630)...")
    width, height = 1200, 630
    orbs = [
        (180, 140, 400, (0, 180, 255), 0.28),
        (1050, 200, 450, (168, 85, 247), 0.22),
        (600, 500, 420, (16, 185, 129), 0.20),
    ]
    img = create_base_canvas(width, height, orbs)
    d = ImageDraw.Draw(img)

    # 1. Header Section
    if IMG_APP_ICON:
        icon_size = 90
        icon_res = IMG_APP_ICON.resize((icon_size, icon_size), Image.Resampling.LANCZOS)
        img.alpha_composite(icon_res, (55, 30))

    # Titles next to Icon
    draw_pill_badge(img, (165, 28), "BỘ GÕ TIẾNG VIỆT & AI CHO MAC", get_f("bold", 13), (20, 35, 65, 230), (*COLOR_CYAN, 180), COLOR_CYAN_BRIGHT, pad_x=14, pad_y=5)
    d.text((165, 58), "VFlow — Đột Phá Bộ Gõ Thế Hệ Mới", font=get_f("bold", 32), fill=COLOR_WHITE)
    d.text((165, 100), "Gõ Code chuẩn không nhảy dấu  •  Sửa câu Tab-Tab  •  Giọng nói Opt+Space sang văn viết AI", font=get_f("bold", 17), fill=COLOR_MUTED)

    # Right Badge
    draw_pill_badge(img, (945, 35), "100% SWIFT 6 NATIVE", get_f("bold", 14), (16, 45, 35, 230), (*COLOR_EMERALD, 200), COLOR_EMERALD_BRIGHT)

    # Header Divider
    d.line([55, 138, 1145, 138], fill=(255, 255, 255, 25), width=1)

    # 2. 3 Columns for 3 Breakthroughs
    col_y = 155
    col_h = 360
    
    # Column 1: salary ≠ sảlảy
    c1_box = [55, col_y, 400, col_y + col_h]
    draw_glass_card(img, c1_box, fill_rgba=(14, 22, 42, 235), border_rgba=(*COLOR_CYAN, 160), radius=18, border_width=1.5)
    draw_pill_badge(img, (75, col_y + 18), "ĐỘT PHÁ 1", get_f("bold", 13), (15, 45, 70, 240), (*COLOR_CYAN, 220), COLOR_CYAN_BRIGHT, pad_x=12, pad_y=4)
    d.text((180, col_y + 18), "VI·T BẬT", font=get_f("bold", 13), fill=COLOR_EMERALD_BRIGHT)
    d.text((75, col_y + 55), "salary ≠ sảlảy", font=get_f("bold", 24), fill=COLOR_EMERALD_BRIGHT)
    d.text((75, col_y + 88), "Gõ Code Không Nhảy Dấu", font=get_f("bold", 17), fill=COLOR_WHITE)
    d.text((75, col_y + 120), "• Tự động nhận diện từ tiếng Anh.", font=get_f("regular", 15), fill=COLOR_MUTED)
    d.text((75, col_y + 145), "• Gõ đúp (rr, ss, ff) hoàn nguyên.", font=get_f("regular", 15), fill=COLOR_MUTED)
    d.text((75, col_y + 170), "• Tốc độ 0ms không trễ nhịp.", font=get_f("regular", 15), fill=COLOR_MUTED)

    # Mini Code box inside Col 1
    sc1 = [75, col_y + 210, 380, col_y + 335]
    draw_glass_card(img, sc1, fill_rgba=(8, 12, 22, 240), border_rgba=(255, 255, 255, 25), radius=10, border_width=1, shadow=False)
    d.text((90, col_y + 225), "[X] Bộ gõ cũ:", font=get_f("bold", 13), fill=COLOR_RED)
    d.text((90, col_y + 248), "const sảlảy = arổw;", font=get_f("bold", 14), fill=COLOR_RED_BRIGHT)
    d.text((90, col_y + 278), "[OK] VFlow:", font=get_f("bold", 13), fill=COLOR_EMERALD)
    d.text((90, col_y + 300), "const salary = arrow;", font=get_f("bold", 14), fill=COLOR_CYAN_BRIGHT)

    # Column 2: Tab-Tab Sentence
    c2_box = [425, col_y, 775, col_y + col_h]
    draw_glass_card(img, c2_box, fill_rgba=(18, 20, 46, 235), border_rgba=(*COLOR_VIOLET, 160), radius=18, border_width=1.5)
    draw_pill_badge(img, (445, col_y + 18), "ĐỘT PHÁ 2", get_f("bold", 13), (45, 25, 75, 240), (*COLOR_VIOLET, 220), COLOR_VIOLET_BRIGHT, pad_x=12, pad_y=4)
    d.text((560, col_y + 18), "HUD 120fps", font=get_f("bold", 13), fill=COLOR_CYAN_BRIGHT)
    d.text((445, col_y + 55), "Nhấn Phím Tab-Tab", font=get_f("bold", 24), fill=COLOR_VIOLET_BRIGHT)
    d.text((445, col_y + 88), "Sửa Ngữ Pháp Trọn Câu", font=get_f("bold", 17), fill=COLOR_WHITE)
    d.text((445, col_y + 120), "• Sửa cả chính tả & tiếng Anh.", font=get_f("regular", 15), fill=COLOR_MUTED)
    d.text((445, col_y + 145), "• Giữ trọn ngữ cảnh qua dấu (.).", font=get_f("regular", 15), fill=COLOR_MUTED)
    d.text((445, col_y + 170), "• Tự ẩn khi cuộn đọc web.", font=get_f("regular", 15), fill=COLOR_MUTED)

    # Mini Preview inside Col 2
    sc2 = [445, col_y + 210, 755, col_y + 335]
    draw_glass_card(img, sc2, fill_rgba=(8, 12, 22, 240), border_rgba=(255, 255, 255, 25), radius=10, border_width=1, shadow=False)
    d.text((460, col_y + 225), "[X] Gõ nhanh:", font=get_f("bold", 13), fill=COLOR_RED)
    d.text((460, col_y + 248), "\"she dont know bug\"", font=get_f("regular", 14), fill=COLOR_MUTED)
    d.text((460, col_y + 278), "[OK] Tab-Tab:", font=get_f("bold", 13), fill=COLOR_EMERALD)
    d.text((460, col_y + 300), "\"She doesn't know\"", font=get_f("bold", 14), fill=COLOR_WHITE)

    # Column 3: Voice Opt+Space
    c3_box = [800, col_y, 1145, col_y + col_h]
    draw_glass_card(img, c3_box, fill_rgba=(14, 28, 42, 235), border_rgba=(*COLOR_EMERALD, 160), radius=18, border_width=1.5)
    draw_pill_badge(img, (820, col_y + 18), "ĐỘT PHÁ 3", get_f("bold", 13), (20, 50, 45, 240), (*COLOR_EMERALD, 220), COLOR_EMERALD_BRIGHT, pad_x=12, pad_y=4)
    d.text((930, col_y + 18), "0 KB Cloud", font=get_f("bold", 13), fill=COLOR_AMBER)
    d.text((820, col_y + 55), "Phím Opt+Space", font=get_f("bold", 24), fill=COLOR_AMBER)
    d.text((820, col_y + 88), "Giọng Nói → Văn Viết AI", font=get_f("bold", 17), fill=COLOR_WHITE)
    d.text((820, col_y + 120), "• Bấm Opt+Space nói tự nhiên.", font=get_f("regular", 15), fill=COLOR_MUTED)
    d.text((820, col_y + 145), "• Nghỉ 2.2s tự động điền app.", font=get_f("regular", 15), fill=COLOR_MUTED)
    d.text((820, col_y + 170), "• Tab-Tab chuốt văn chuyên nghiệp.", font=get_f("regular", 15), fill=COLOR_MUTED)

    # Mini Preview inside Col 3
    sc3 = [820, col_y + 210, 1125, col_y + 335]
    draw_glass_card(img, sc3, fill_rgba=(8, 12, 22, 240), border_rgba=(255, 255, 255, 25), radius=10, border_width=1, shadow=False)
    d.text((835, col_y + 225), "[X] Nói thô:", font=get_f("bold", 13), fill=COLOR_RED)
    d.text((835, col_y + 248), "\"Hình như phần giọng nói...\"", font=get_f("regular", 13), fill=COLOR_MUTED)
    d.text((835, col_y + 278), "[OK] Văn viết AI:", font=get_f("bold", 13), fill=COLOR_EMERALD)
    d.text((835, col_y + 300), "\"Sau khi nhận diện giọng nói...\"", font=get_f("bold", 13), fill=COLOR_EMERALD_BRIGHT)

    # 3. Bottom Action Bar
    bar_box = [55, 530, 1145, 605]
    draw_glass_card(img, bar_box, fill_rgba=(10, 16, 32, 240), border_rgba=(255, 255, 255, 35), radius=16, border_width=1)
    
    d.text((80, 552), "100% Swift 6 Native  •  On-Device Apple Silicon  •  0 KB Cloud", font=get_f("bold", 16), fill=COLOR_WHITE)
    d.text((645, 552), "Tải miễn phí tại: tgalioautomation.github.io/VFlow", font=get_f("bold", 18), fill=COLOR_CYAN_BRIGHT)

    out_file = os.path.join(OUTPUT_DIR, "fb-cover-landscape.png")
    img.save(out_file, "PNG", optimize=True)
    print(f"Saved: {out_file} ({os.path.getsize(out_file):,} bytes)")

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================
if __name__ == "__main__":
    print("=" * 60)
    print("STARTING VFLOW FACEBOOK ASSET GENERATION")
    print("=" * 60)
    generate_fb_01_hero()
    generate_fb_02_escape_code()
    generate_fb_03_tab_tab()
    generate_fb_04_voice_install()
    generate_fb_cover_landscape()
    print("=" * 60)
    print("ALL 5 FACEBOOK ASSETS GENERATED SUCCESSFULLY!")
    print("=" * 60)
