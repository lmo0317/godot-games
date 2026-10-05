"""Bring Codex-generated art into the game.

The raw images are 1254px PNGs made with Codex's image tool (prompts in docs/ART_GUIDE.md).

- "png": sprites get their empty margin trimmed and the longer side scaled down.
- "pixel": pixel-art sprites are trimmed and brought back to the art's own pixel grid (the size of
  one art pixel is measured from runs of equal colour; each art pixel's middle is sampled), with
  hard alpha edges. The game scales them up with nearest filtering so pixels stay crisp.
- "grid": like "pixel" but for sprites drawn on a known n-cell grid (n = size); if the measured
  grid is far off, the sprite is fitted to n cells on its longer side.
- "pixel_bg": an opaque pixel-art backdrop cropped to the target aspect and sampled down to exactly
  that many pixels (size = (width, height)).

Usage: python tools/import_battle_art.py <folder with the raw PNGs> [names...]
"""
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
# name -> (folder under assets/art, size, mode). For "pixel" the size caps the longest side on the
# pixel grid (very fine art is put on a coarser grid); for "pixel_bg" it gives the aspect to crop to.
ART = {
    "knight": ("battle", 256, "png"),
    "wizard": ("battle", 256, "png"),
    "fx_slash": ("battle", 256, "png"),
    "fx_fireball": ("battle", 256, "png"),
    # Block Defense art is code-drawn now (tools/generate_defense_sprites.py)
}


def trim(img):
    box = img.getchannel("A").point(lambda a: 255 if a > 10 else 0).getbbox()
    return img.crop(box) if box else img


def block_size(img):
    """Size in px of one art pixel: the most common run of same-coloured pixels along rows
    (runs of two or three art pixels count toward their base size too)."""
    import collections
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


def pixelize(img, max_pixels=120):
    """Back to the art's own pixel grid: sample the middle of each art pixel."""
    img = trim(img.convert("RGBA"))
    b = block_size(img)
    # Very fine art (no clear grid) is put on a coarser grid so it reads as pixel art too
    b = max(b, max(img.size) / max_pixels)
    w, h = max(1, round(img.width / b)), max(1, round(img.height / b))
    small = img.resize((w, h), Image.Resampling.NEAREST)
    alpha = small.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    small.putalpha(alpha)
    return small


def grid(img, n):
    """A sprite drawn on an n-cell grid: back to that grid (the taller side becomes ~n cells)."""
    img = trim(img.convert("RGBA"))
    b = block_size(img)
    cells = max(img.size) / b
    if not (n * 0.7 <= cells <= n * 1.35):
        b = max(img.size) / n   # the art's own grid is off: fit it to n cells
    w, h = max(1, round(img.width / b)), max(1, round(img.height / b))
    small = img.resize((w, h), Image.Resampling.NEAREST)
    small.putalpha(small.getchannel("A").point(lambda a: 255 if a >= 128 else 0))
    return small


def pixel_bg(img, size):
    img = img.convert("RGB")
    tw, th = size
    # Crop to the target aspect from the middle, then scale down
    aspect = tw / th
    if img.width / img.height > aspect:
        cw = round(img.height * aspect)
        img = img.crop(((img.width - cw) // 2, 0, (img.width - cw) // 2 + cw, img.height))
    else:
        ch = round(img.width / aspect)
        img = img.crop((0, (img.height - ch) // 2, img.width, (img.height - ch) // 2 + ch))
    # Exactly the target size so it can be drawn at the same whole-number scale as the sprites
    return img.resize((tw, th), Image.Resampling.NEAREST)


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "."
    only = sys.argv[2:]
    for name, (folder, size, mode) in ART.items():
        if only and name not in only:
            continue
        raw = os.path.join(src, name + ".png")
        if not os.path.exists(raw):
            print(f"skip {name}: no {raw}")
            continue
        img = Image.open(raw)
        if mode == "pixel":
            img = pixelize(img, size)
        elif mode == "grid":
            img = grid(img, size)
        elif mode == "pixel_bg":
            img = pixel_bg(img, size)
        else:
            img = trim(img.convert("RGBA"))
            scale = size / max(img.size)
            img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.Resampling.LANCZOS)
        out_dir = os.path.join(ROOT, "assets", "art", folder)
        os.makedirs(out_dir, exist_ok=True)
        path = os.path.join(out_dir, name + ".png")
        img.save(path, optimize=True)
        print(f"{path} {img.size} {os.path.getsize(path) // 1024}KB")


if __name__ == "__main__":
    main()
