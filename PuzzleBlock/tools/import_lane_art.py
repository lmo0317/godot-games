"""Bring the Codex pixel art for the lane battle into the game (assets/art/lane/).

Raw files (prompts in docs/ART_GUIDE.md, "블록 기사단 픽셀 아트"):
  sheet.png  one row of 8 side-view characters: knight, archer, mage, spearman (face right),
             slime, goblin, skeleton, orc (face left) - drawn together so they share one style
  bases.png  ally castle (left) and enemy fortress (right)
  lane.png   wide side-view background
  foes.png   (optional) two more monsters drawn with sheet.png as the style reference:
             bat (flying), armored skeleton
  allies2.png (optional) 8 more soldiers, same reference: shield, crossbow, cleric, cavalry, ice mage,
             cannoneer, paladin, hero (the 4 middle ones joined on 2026-10-08)
  allies3.png (optional) rogue, berserker, bard, dragon rider, with allies2.png as the reference
  foes2.png  (optional) wolf, goblin archer, dark priest, golem, demon lord
  fx2.png    (optional) hit spark, slash, arrow, bolt, fireball, holy orb, heal plus, dust, (coin), ring
  summon.png (optional) gacha pieces, same reference: summoning altar, swirling portal, pillar of
             light, starburst, ray sunburst, sparkle (light pieces are pale so the game tints them)
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
# allies2.png: 8 figures, all used since the 16-soldier update. Its art-pixel size is 6 screen pixels
# (the measure finds 5, which would draw them 1.2x too big); allies3.png is 7 (measured 4)
ALLIES2 = ["shield", "crossbow", "cleric", "cavalry", "icemage", "cannoneer", "paladin", "hero"]
ALLIES3 = ["rogue", "berserker", "bard", "dragon"]
FOES2 = ["wolf", "gob_archer", "priest", "golem", "demon"]
FX2 = ["spark", "slash", "arrow", "bolt", "fireball", "holy", "heal", "dust", None, "ring"]
# summon.png pieces are full of loose light specks, so they are cut by empty columns instead
SUMMON = ["summon_altar", "summon_portal", "summon_pillar", "summon_burst", "summon_rays", "summon_sparkle"]


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


def to_grid(img, opaque=False, block=0):
    img = img.convert("RGBA")
    box = img.getchannel("A").point(lambda a: 255 if a > 10 else 0).getbbox() if not opaque else None
    b = block or block_size(img.crop(box) if box else img)
    small = img.resize((max(1, round(img.width / b)), max(1, round(img.height / b))), Image.Resampling.NEAREST)
    if opaque:
        return small.convert("RGB")
    small.putalpha(small.getchannel("A").point(lambda a: 255 if a >= 128 else 0))
    return small


def split(img):
    """Sprites as connected opaque areas (8-neighbour), left to right; specks join the nearest.
    Each crop keeps only its own pixels, so a neighbour reaching into the box is left out."""
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
            comps.append({"box": [x0, y0, x1 + 1, y1 + 1], "n": n, "ids": {cid}})
    big = [c for c in comps if c["n"] >= 40]
    for c in comps:
        if c["n"] < 40 and big:
            mid = (c["box"][0] + c["box"][2]) / 2
            t = min(big, key=lambda b: abs((b["box"][0] + b["box"][2]) / 2 - mid))
            t["box"] = [min(t["box"][0], c["box"][0]), min(t["box"][1], c["box"][1]), max(t["box"][2], c["box"][2]), max(t["box"][3], c["box"][3])]
            t["ids"] |= c["ids"]
    big.sort(key=lambda c: c["box"][0])
    out = []
    for c in big:
        x0, y0, x1, y1 = c["box"]
        crop = img.crop((x0, y0, x1, y1))
        px = crop.load()
        for yy in range(y1 - y0):
            for xx in range(x1 - x0):
                if label[y0 + yy][x0 + xx] not in c["ids"]:
                    px[xx, yy] = (0, 0, 0, 0)
        out.append(crop)
    return out


def split_columns(img):
    """Pieces separated by fully empty columns, left to right, each trimmed to its pixels."""
    a = img.getchannel("A")
    w, h = img.size
    used = [any(a.getpixel((x, y)) for y in range(h)) for x in range(w)]
    out, x = [], 0
    while x < w:
        if not used[x]:
            x += 1
            continue
        x0 = x
        while x < w and used[x]:
            x += 1
        piece = img.crop((x0, 0, x, h))
        out.append(piece.crop(piece.getchannel("A").getbbox()))
    return out


def whiten(img):
    """Light pieces turned into white light (brightness kept) so the game can tint them by tier."""
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a:
                v = int(110 + 145 * (0.3 * r + 0.59 * g + 0.11 * b) / 255)
                px[x, y] = (v, v, v, a)
    return out


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
    extra = [("allies2.png", ALLIES2, 6), ("allies3.png", ALLIES3, 7), ("foes2.png", FOES2, 0), ("fx2.png", FX2, 0)]
    for file, names, block in extra:
        path = os.path.join(src, file)
        if not os.path.exists(path):
            continue
        sprites = split(to_grid(Image.open(path), block=block))
        if len(sprites) != len(names):
            sys.exit(f"expected {len(names)} sprites in {file}, found {len(sprites)}")
        for name, sp in zip(names, sprites):
            if name:
                save(sp, name)
    summon_path = os.path.join(src, "summon.png")
    if os.path.exists(summon_path):
        pieces = split_columns(to_grid(Image.open(summon_path)))
        if len(pieces) != len(SUMMON):
            sys.exit(f"expected {len(SUMMON)} pieces in summon.png, found {len(pieces)}")
        for name, sp in zip(SUMMON, pieces):
            save(sp if name == "summon_altar" else whiten(sp), name)
    fx_path = os.path.join(src, "fx.png")
    if os.path.exists(fx_path):
        fx = split(to_grid(Image.open(fx_path)))
        if len(fx) != len(FX):
            sys.exit(f"expected {len(FX)} pieces in fx.png, found {len(fx)}")
        for name, sp in zip(FX, fx):
            save(sp, name)


if __name__ == "__main__":
    main()
