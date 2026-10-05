import os
from PIL import Image, ImageDraw

ASSETS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets"))
SPRITES_DIR = os.path.join(ASSETS_DIR, "sprites")
os.makedirs(SPRITES_DIR, exist_ok=True)

def render_original_block(
    base_color,
    top_color,
    left_color,
    right_color,
    bottom_color,
    size=76,
    bevel_ratio=0.145, # ~11px bevel at 76px
    corner_radius=4.0,  # subtle rounded corners
    scale=4
):
    s = int(size * scale)
    b = int(s * bevel_ratio)
    r = int(corner_radius * scale)

    # Render on high-res canvas
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Bevel coordinates
    ol, ot = 0, 0
    or_, ob = s, s
    il, it = b, b
    ir, ib = s - b, s - b

    # Trapezoid polygons - pure 4-side bevel (NO black outline!)
    draw.polygon([(ol, ot), (or_, ot), (ir, it), (il, it)], fill=top_color)
    draw.polygon([(ol, ob), (or_, ob), (ir, ib), (il, ib)], fill=bottom_color)
    draw.polygon([(ol, ot), (il, it), (il, ib), (ol, ob)], fill=left_color)
    draw.polygon([(or_, ot), (ir, it), (ir, ib), (or_, ob)], fill=right_color)

    # 2. Center square
    draw.rectangle([il, it, ir, ib], fill=base_color)

    # 3. Mask for soft subtle rounded outer corners
    mask = Image.new("L", (s, s), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.rounded_rectangle([0, 0, s - 1, s - 1], radius=r, fill=255)

    img.putalpha(mask)

    # Downsample with high-quality Lanczos antialiasing
    return img.resize((size, size), Image.Resampling.LANCZOS)

# Exact colors matching original Block Blast app store captures:
PALETTE = {
    "yellow": {
        "base": (251, 206, 5),      # #FBCE05 Gold/Yellow
        "top": (255, 248, 140),     # #FFF88C
        "left": (249, 215, 45),     # #F9D72D
        "right": (232, 175, 0),     # #E8AF00
        "bottom": (198, 128, 0),    # #C68000
    },
    "blue": {
        "base": (54, 97, 237),      # #3661ED Royal Blue
        "top": (143, 188, 255),     # #8FBCFF
        "left": (65, 112, 255),     # #4170FF
        "right": (37, 79, 213),     # #254FD5
        "bottom": (34, 54, 152),    # #223698
    },
    "green": {
        "base": (33, 202, 45),      # #21CA2D Lime Green
        "top": (127, 244, 159),     # #7FF49F
        "left": (43, 216, 60),      # #2BD83C
        "right": (15, 157, 43),     # #0F9D2B
        "bottom": (0, 122, 45),     # #007A2D
    },
    "purple": {
        "base": (146, 84, 228),     # #9254E4 Vivid Purple
        "top": (225, 153, 246),     # #E199F6
        "left": (170, 98, 234),     # #AA62EA
        "right": (120, 55, 177),    # #7837B1
        "bottom": (93, 34, 143),    # #5D228F
    },
    "orange": {
        "base": (255, 107, 0),      # #FF6B00 Vivid Orange
        "top": (255, 168, 107),     # #FFA86B
        "left": (255, 141, 54),     # #FF8D36
        "right": (214, 85, 0),      # #D65500
        "bottom": (184, 62, 0),     # #B83E00
    },
    "cyan": {
        "base": (0, 186, 242),      # #00BAF2 Sky / Cyan
        "top": (125, 230, 255),     # #7DE6FF
        "left": (59, 209, 255),     # #3BD1FF
        "right": (0, 154, 200),     # #009AC8
        "bottom": (0, 122, 168),    # #007AA8
    },
    "red": {
        "base": (232, 35, 60),      # #E8233C Candy Red
        "top": (255, 112, 132),     # #FF7084
        "left": (245, 69, 91),      # #F5455B
        "right": (184, 20, 40),     # #B81428
        "bottom": (138, 10, 26),    # #8A0A1A
    },
    "pink": {
        "base": (245, 60, 150),     # #F53C96 Candy Pink
        "top": (255, 150, 200),     # #FF96C8
        "left": (250, 100, 175),    # #FA64AF
        "right": (200, 30, 110),    # #C81E6E
        "bottom": (150, 15, 80),    # #960F50
    }
}

for name, cols in PALETTE.items():
    img = render_original_block(
        base_color=cols["base"],
        top_color=cols["top"],
        left_color=cols["left"],
        right_color=cols["right"],
        bottom_color=cols["bottom"],
        size=76
    )
    dest_path = os.path.join(SPRITES_DIR, f"block_{name}.png")
    img.save(dest_path)
    print(f"Generated {dest_path}")

print("Original blocks generated successfully!")
