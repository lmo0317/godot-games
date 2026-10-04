"""Generate the glossy clear-feedback text used by ComboPopup.

Block Blast style lettering: each glyph has a light-to-saturated vertical gradient,
a gloss band on its upper half, a white inner stroke, a thick dark outer stroke and
a soft drop shadow. Pieces are drawn at 2x and saved at 1x into assets/sprites/combo/:

  combo_word.png        "Combo" with a different colour per letter
  gold_0..9.png         gold digits for the combo number
  score_plus.png, score_0..9.png   white digits for the points
  praise_<tier>.png     Good! .. Unbelievable!
  rays.png              soft light rays shown behind the words
  big_0..9.png, big_comma.png      large white digits for the score at the top

Usage: python tools/generate_combo_text.py
"""
import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "sprites", "combo")
FONTS = os.path.join(os.environ.get("WINDIR", "C:/Windows"), "Fonts")
ROUNDED = os.path.join(FONTS, "ARLRDBD.TTF")  # Arial Rounded MT Bold
SS = 2

# (top, bottom) gradient colours
COMBO_LETTERS = [
    ((236, 255, 214), (64, 200, 72)),     # C green
    ((255, 236, 250), (255, 92, 178)),    # o pink
    ((255, 250, 236), (255, 168, 72)),    # m orange
    ((236, 248, 255), (72, 170, 255)),    # b blue
    ((250, 236, 255), (178, 104, 255)),   # o violet
]
COMBO_OUTLINE = (52, 22, 96)
GOLD = ((255, 252, 196), (255, 176, 20))
GOLD_OUTLINE = (120, 44, 8)
SCORE = ((255, 255, 255), (206, 228, 255))
SCORE_OUTLINE = (18, 40, 96)

# text, gradient, outline — matches PRAISE tiers in main.gd
PRAISE = [
    ("Good!", ((228, 252, 255), (60, 200, 255)), (8, 54, 120)),
    ("Great!", ((236, 255, 228), (72, 220, 110)), (10, 76, 40)),
    ("Excellent!", ((255, 252, 210), (255, 196, 40)), (110, 50, 0)),
    ("Amazing!", ((255, 240, 214), (255, 128, 40)), (120, 30, 10)),
    ("Unbelievable!", ((255, 232, 250), (255, 84, 200)), (84, 14, 110)),
]


def font(size):
    return ImageFont.truetype(ROUNDED, size * SS)


def gradient(w, h, top, bottom):
    g = Image.new("RGBA", (w, h))
    px = g.load()
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = c + (255,)
    return g


def glyph_layers(text, size, colors, outline, inner=0.07, outer=0.16):
    """Render text (one gradient per character if colors is a list) with strokes."""
    f = font(size)
    s_in = max(2, int(size * SS * inner))
    s_out = s_in + max(3, int(size * SS * outer))
    pad = s_out + size * SS // 6
    asc, desc = f.getmetrics()
    advances = [f.getlength(ch) for ch in text]
    w = int(sum(advances)) + pad * 2
    h = asc + desc + pad * 2
    base_y = pad

    def mask(stroke):
        m = Image.new("L", (w, h), 0)
        d = ImageDraw.Draw(m)
        x = pad
        for ch, adv in zip(text, advances):
            d.text((x, base_y), ch, font=f, fill=255, stroke_width=stroke, stroke_fill=255)
            x += adv
        return m

    m_out, m_in, m_fill = mask(s_out), mask(s_in), mask(0)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    # Drop shadow
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    shadow.paste((10, 6, 30, 150), (0, 0), m_out)
    shadow = shadow.filter(ImageFilter.GaussianBlur(size * SS * 0.05))
    img.alpha_composite(shadow, (0, int(size * SS * 0.07)))
    # Outer and inner strokes
    img.paste(outline + (255,), (0, 0), m_out)
    white = Image.new("RGBA", (w, h), (255, 255, 255, 255))
    img.paste(white, (0, 0), m_in)

    # Fill: per-character gradient spanning the glyph height
    top_y = base_y + int(asc * 0.18)
    bot_y = base_y + asc
    fill = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x = pad
    if not isinstance(colors, list):
        colors = [colors]
    for i, (ch, adv) in enumerate(zip(text, advances)):
        top, bottom = colors[i % len(colors)]
        g = gradient(int(adv) + s_out * 2, bot_y - top_y, top, bottom)
        col = Image.new("RGBA", (w, h), bottom + (255,))
        col.paste(top + (255,), (0, 0, w, top_y))
        col.paste(g, (int(x) - s_out, top_y))
        cm = Image.new("L", (w, h), 0)
        ImageDraw.Draw(cm).rectangle([int(x) - 1, 0, int(x + adv) + 1, h], fill=255)
        fill.paste(col, (0, 0), ImageChops.multiply(cm, m_fill))
        x += adv
    img.alpha_composite(fill)

    # Gloss: a soft white band on the upper part of each glyph
    gloss = Image.new("L", (w, h), 0)
    gy0, gy1 = top_y - int(asc * 0.1), base_y + int(asc * 0.52)
    ImageDraw.Draw(gloss).rectangle([0, gy0, w, gy1], fill=120)
    gloss = gloss.filter(ImageFilter.GaussianBlur(size * SS * 0.04))
    gloss = ImageChops.multiply(gloss, m_fill.filter(ImageFilter.MinFilter(max(3, (size * SS // 18) | 1))))
    img.paste(white, (0, 0), gloss)
    return trim(img)


def trim(img):
    box = img.getbbox()
    return img.crop(box) if box else img


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    img.resize((max(1, img.width // SS), max(1, img.height // SS)), Image.Resampling.LANCZOS).save(path, "PNG")
    print(f"Generated: {path}")


def rays():
    # Soft white light rays fading out from the centre; tinted in the engine
    n = 512 * SS
    img = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(img)
    c = n / 2
    count = 14
    for i in range(count):
        a = i * 2 * math.pi / count
        half = math.pi / count * 0.42
        pts = [(c, c)]
        for t in (a - half, a + half):
            pts.append((c + math.cos(t) * n, c + math.sin(t) * n))
        d.polygon(pts, fill=255)
    img = img.filter(ImageFilter.GaussianBlur(n * 0.012))
    radial = Image.new("L", (n, n), 0)
    rp = radial.load()
    for y in range(n):
        for x in range(n):
            r = math.hypot(x - c, y - c) / c
            rp[x, y] = int(255 * max(0.0, 1.0 - r) ** 1.6)
    img = ImageChops.multiply(img, radial)
    core = Image.new("L", (n, n), 0)
    ImageDraw.Draw(core).ellipse([c - n * 0.16, c - n * 0.16, c + n * 0.16, c + n * 0.16], fill=170)
    core = core.filter(ImageFilter.GaussianBlur(n * 0.06))
    img = ImageChops.lighter(img, core)
    out = Image.new("RGBA", (n, n), (255, 255, 255, 0))
    out.putalpha(img)
    save(out, "rays.png")


def main():
    save(glyph_layers("Combo", 76, COMBO_LETTERS, COMBO_OUTLINE), "combo_word.png")
    for dgt in "0123456789":
        save(glyph_layers(dgt, 92, GOLD, GOLD_OUTLINE), f"gold_{dgt}.png")
        save(glyph_layers(dgt, 44, SCORE, SCORE_OUTLINE, 0.06, 0.13), f"score_{dgt}.png")
    save(glyph_layers("+", 44, SCORE, SCORE_OUTLINE, 0.06, 0.13), "score_plus.png")
    for dgt in "0123456789":
        save(glyph_layers(dgt, 70, SCORE, SCORE_OUTLINE, 0.05, 0.11), f"big_{dgt}.png")
    save(glyph_layers(",", 70, SCORE, SCORE_OUTLINE, 0.05, 0.11), "big_comma.png")
    for i, (text, grad, outline) in enumerate(PRAISE):
        save(glyph_layers(text, 58, grad, outline), f"praise_{i + 1}.png")
    rays()


if __name__ == "__main__":
    main()
