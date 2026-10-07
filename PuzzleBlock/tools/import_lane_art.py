"""Bring the Codex pixel art for the lane battle into the game (assets/art/lane/).

Raw files (prompts in docs/ART_GUIDE.md, "블록 기사단 픽셀 아트"):
  sheet.png  one row of 8 side-view characters: knight, archer, mage, spearman (face right),
             slime, goblin, skeleton, orc (face left) - drawn together so they share one style
  bases.png  ally castle (left) and enemy fortress (right)
  lane.png   wide side-view background
  foes.png   (optional) two more monsters drawn with sheet.png as the style reference:
             bat (flying), armored skeleton
  fx.png     (optional) castle cannon pieces, same reference: cannon, cannonball, muzzle flash,
             small explosion, big explosion, smoke

Each image is brought back to its own pixel grid (the size of one art pixel is measured from runs
of equal colour) and the sprites are cut apart by their connected opaque areas. The game draws them
at whole-number scales with nearest filtering.

Usage: python tools/import_lane_art.py <folder with the raw PNGs>
"""
import collections
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "art", "lane")
UNITS = ["knight", "archer", "mage", "spearman", "slime", "goblin", "skeleton", "orc"]
BASES = ["castle", "fortress"]
FOES = ["bat", "armored"]
FX = ["cannon", "cannonball", "flash", "boom_s", "boom_l", "smoke"]


def block_size(img):
    im = img.convert("RGBA")
    w, h = im.size
    px = im.load()
    hist = collections.Counter()
    for y in range(0, h, 5):
        run, prev = 1, px[0, y]
        for x in range(1, w):
            c = px[x, y]
            if c[3] > 128 and prev[3] > 128 and sum(abs(c[i] - prev[i]) for i in range(3)) < 30:
                run += 1
            else:
                if 3 <= run <= 80:
                    hist[run] += 1
                run = 1
            prev = c
    best, best_score = 8, -1.0
    for b in range(4, 25):
        score = sum(hist[b + d] for d in (-1, 0, 1))
        score += 0.5 * sum(hist[2 * b + d] for d in (-1, 0, 1)) + 0.3 * sum(hist[3 * b + d] for d in (-2, 0, 2))
        if score > best_score:
            best, best_score = b, score
    return best


def to_grid(img, opaque=False):
    img = img.convert("RGBA")
    box = img.getchannel("A").point(lambda a: 255 if a > 10 else 0).getbbox() if not opaque else None
    b = block_size(img.crop(box) if box else img)
    small = img.resize((max(1, round(img.width / b)), max(1, round(img.height / b))), Image.Resampling.NEAREST)
    if opaque:
        return small.convert("RGB")
    small.putalpha(small.getchannel("A").point(lambda a: 255 if a >= 128 else 0))
    return small


def split(img):
    """Sprites as connected opaque areas (8-neighbour), left to right; specks join the nearest."""
    a = img.getchannel("A")
    w, h = img.size
    seen = [[False] * w for _ in range(h)]
    comps = []
    for y in range(h):
        for x in range(w):
            if seen[y][x] or a.getpixel((x, y)) == 0:
                continue
            stack, n = [(x, y)], 0
            seen[y][x] = True
            x0, y0, x1, y1 = x, y, x, y
            while stack:
                cx, cy = stack.pop()
                n += 1
                x0, y0, x1, y1 = min(x0, cx), min(y0, cy), max(x1, cx), max(y1, cy)
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and a.getpixel((nx, ny)) > 0:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
            comps.append([x0, y0, x1 + 1, y1 + 1, n])
    big = [c for c in comps if c[4] >= 40]
    for c in comps:
        if c[4] < 40 and big:
            mid = (c[0] + c[2]) / 2
            t = min(big, key=lambda b: abs((b[0] + b[2]) / 2 - mid))
            t[0], t[1], t[2], t[3] = min(t[0], c[0]), min(t[1], c[1]), max(t[2], c[2]), max(t[3], c[3])
    big.sort(key=lambda c: c[0])
    return [img.crop((c[0], c[1], c[2], c[3])) for c in big]


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    img.save(path, optimize=True)
    print(f"{path} {img.size}")


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "."
    sprites = split(to_grid(Image.open(os.path.join(src, "sheet.png"))))
    if len(sprites) != len(UNITS):
        sys.exit(f"expected {len(UNITS)} sprites in sheet.png, found {len(sprites)}")
    for name, sp in zip(UNITS, sprites):
        save(sp, name)
    bases = split(to_grid(Image.open(os.path.join(src, "bases.png"))))
    save(bases[0], BASES[0])
    save(bases[-1], BASES[1])
    save(to_grid(Image.open(os.path.join(src, "lane.png")), opaque=True), "lane")
    foes_path = os.path.join(src, "foes.png")
    if os.path.exists(foes_path):
        foes = split(to_grid(Image.open(foes_path)))
        if len(foes) != len(FOES):
            sys.exit(f"expected {len(FOES)} sprites in foes.png, found {len(foes)}")
        for name, sp in zip(FOES, foes):
            save(sp, name)
    fx_path = os.path.join(src, "fx.png")
    if os.path.exists(fx_path):
        fx = split(to_grid(Image.open(fx_path)))
        if len(fx) != len(FX):
            sys.exit(f"expected {len(FX)} pieces in fx.png, found {len(fx)}")
        for name, sp in zip(FX, fx):
            save(sp, name)


if __name__ == "__main__":
    main()
