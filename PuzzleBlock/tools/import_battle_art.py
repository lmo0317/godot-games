"""Bring Codex-generated battle art into the game.

The raw images (knight, wizard, fx_slash, fx_fireball) are 1254px PNGs with transparency made
with Codex's image tool (prompts in docs/ART_GUIDE.md). This trims the empty margin, scales the
longer side to 256px and writes them to assets/art/battle/.

Usage: python tools/import_battle_art.py <folder with the raw PNGs>
"""
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "art", "battle")
NAMES = ["knight", "wizard", "fx_slash", "fx_fireball"]
SIZE = 256


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(OUT, exist_ok=True)
    for name in NAMES:
        img = Image.open(os.path.join(src, name + ".png")).convert("RGBA")
        # Ignore faint alpha noise when finding the subject's edges
        box = img.getchannel("A").point(lambda a: 255 if a > 10 else 0).getbbox()
        if box:
            img = img.crop(box)
        scale = SIZE / max(img.size)
        img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.Resampling.LANCZOS)
        path = os.path.join(OUT, name + ".png")
        img.save(path, optimize=True)
        print(f"{path} {img.size} {os.path.getsize(path) // 1024}KB")


if __name__ == "__main__":
    main()
