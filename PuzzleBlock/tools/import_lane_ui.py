"""Bring the Codex pixel-art UI kit for 블록 기사단 into the game (assets/art/ui/).

Raw file (prompt in docs/ART_GUIDE.md, "블록 기사단 UI"): ui.png, one sheet with a wooden panel,
a parchment panel, green/blue/red/grey buttons, gem/coin/star/empty star/lock icons, a title ribbon,
a stage medallion, a boss medallion and a stone card frame.
frames.png (optional): six card frames in one row, one per star tier (iron, sapphire, amethyst,
topaz, ruby, diamond with wings), saved as frame_0 .. frame_5.

The sheet is brought back to its pixel grid with one art-pixel size (BLOCK), pieces are cut by their
connected opaque areas (each crop keeps only its own pixels) and named by where they sit on the
sheet. Every piece is saved at UI_SCALE (nearest), so the game can use the pixels as they are in
9-slice styleboxes (margins in LaneUI are in these saved pixels).

Usage: python tools/import_lane_ui.py <folder with ui.png>
"""
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "art", "ui")
BLOCK = 6
FRAME_BLOCK = 5    # frames.png was drawn with a smaller art pixel
UI_SCALE = 2
# Where each piece's centre sits on the sheet (fractions of the width and height)
PIECES = {
    "panel_wood": (0.19, 0.28), "panel_paper": (0.50, 0.28),
    "btn_green": (0.81, 0.14), "btn_blue": (0.81, 0.27), "btn_red": (0.81, 0.40), "btn_grey": (0.81, 0.52),
    "icon_gem": (0.10, 0.59), "icon_coin": (0.21, 0.59), "icon_star": (0.32, 0.59), "icon_star_empty": (0.43, 0.59),
    "icon_lock": (0.56, 0.59), "ribbon": (0.24, 0.80), "medal": (0.55, 0.80), "medal_boss": (0.71, 0.79),
    "card_frame": (0.89, 0.78),
}


def to_grid(img, block=BLOCK):
    img = img.convert("RGBA")
    small = img.resize((max(1, round(img.width / block)), max(1, round(img.height / block))), Image.Resampling.NEAREST)
    small.putalpha(small.getchannel("A").point(lambda a: 255 if a >= 128 else 0))
    return small


def components(img, min_px=20):
    a = img.getchannel("A")
    w, h = img.size
    label = [[-1] * w for _ in range(h)]
    comps = []
    for y in range(h):
        for x in range(w):
            if label[y][x] >= 0 or a.getpixel((x, y)) == 0:
                continue
            cid = len(comps)
            stack, n = [(x, y)], 0
            label[y][x] = cid
            x0, y0, x1, y1 = x, y, x, y
            while stack:
                cx, cy = stack.pop()
                n += 1
                x0, y0, x1, y1 = min(x0, cx), min(y0, cy), max(x1, cx), max(y1, cy)
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < w and 0 <= ny < h and label[ny][nx] < 0 and a.getpixel((nx, ny)) > 0:
                            label[ny][nx] = cid
                            stack.append((nx, ny))
            comps.append({"id": cid, "box": (x0, y0, x1 + 1, y1 + 1), "n": n})
    return label, [c for c in comps if c["n"] >= min_px]


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "."
    img = to_grid(Image.open(os.path.join(src, "ui.png")))
    label, comps = components(img)
    w, h = img.size
    os.makedirs(OUT, exist_ok=True)
    used = set()
    for name, (fx, fy) in PIECES.items():
        c = min((c for c in comps if c["id"] not in used),
                key=lambda c: ((c["box"][0] + c["box"][2]) / 2 / w - fx) ** 2 + ((c["box"][1] + c["box"][3]) / 2 / h - fy) ** 2)
        used.add(c["id"])
        x0, y0, x1, y1 = c["box"]
        crop = img.crop((x0, y0, x1, y1))
        px = crop.load()
        for yy in range(y1 - y0):
            for xx in range(x1 - x0):
                if label[y0 + yy][x0 + xx] != c["id"]:
                    px[xx, yy] = (0, 0, 0, 0)
        crop = crop.resize((crop.width * UI_SCALE, crop.height * UI_SCALE), Image.Resampling.NEAREST)
        path = os.path.join(OUT, name + ".png")
        crop.save(path, optimize=True)
        print(f"{name} {crop.size}")
    frames_path = os.path.join(src, "frames.png")
    if os.path.exists(frames_path):
        img = to_grid(Image.open(frames_path), FRAME_BLOCK)
        label, comps = components(img)
        comps = sorted([c for c in comps if c["n"] >= 60], key=lambda c: c["box"][0])
        if len(comps) != 6:
            sys.exit(f"expected 6 frames, found {len(comps)}")
        for i, c in enumerate(comps):
            x0, y0, x1, y1 = c["box"]
            crop = img.crop((x0, y0, x1, y1))
            px = crop.load()
            for yy in range(y1 - y0):
                for xx in range(x1 - x0):
                    if label[y0 + yy][x0 + xx] != c["id"]:
                        px[xx, yy] = (0, 0, 0, 0)
            crop = crop.resize((crop.width * UI_SCALE, crop.height * UI_SCALE), Image.Resampling.NEAREST)
            crop.save(os.path.join(OUT, f"frame_{i}.png"), optimize=True)
            print(f"frame_{i} {crop.size}")


if __name__ == "__main__":
    main()
