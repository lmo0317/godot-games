"""Bring Codex-generated battle art into the game.

The raw images are 1254px PNGs made with Codex's image tool (prompts in docs/ART_GUIDE.md).
Sprites get their empty margin trimmed and the longer side scaled down; the battlefield
backdrop is opaque and is saved as a JPG.

Usage: python tools/import_battle_art.py <folder with the raw PNGs>
"""
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
# name -> (folder under assets/art, longest side in px, format)
ART = {
    "knight": ("battle", 256, "png"),
    "wizard": ("battle", 256, "png"),
    "fx_slash": ("battle", 256, "png"),
    "fx_fireball": ("battle", 256, "png"),
    "soldier": ("defense", 256, "png"),
    "sniper": ("defense", 256, "png"),
    "slime": ("defense", 200, "png"),
    "goblin": ("defense", 256, "png"),
    "castle": ("defense", 320, "png"),
    "battlefield": ("defense", 1100, "jpg"),
}


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "."
    only = sys.argv[2:]  # optional names to import
    for name, (folder, size, fmt) in ART.items():
        if only and name not in only:
            continue
        raw = os.path.join(src, name + ".png")
        if not os.path.exists(raw):
            print(f"skip {name}: no {raw}")
            continue
        img = Image.open(raw)
        if fmt == "png":
            img = img.convert("RGBA")
            # Ignore faint alpha noise when finding the subject's edges
            box = img.getchannel("A").point(lambda a: 255 if a > 10 else 0).getbbox()
            if box:
                img = img.crop(box)
        else:
            img = img.convert("RGB")
        scale = size / max(img.size)
        img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.Resampling.LANCZOS)
        out_dir = os.path.join(ROOT, "assets", "art", folder)
        os.makedirs(out_dir, exist_ok=True)
        path = os.path.join(out_dir, f"{name}.{fmt}")
        if fmt == "png":
            img.save(path, optimize=True)
        else:
            img.save(path, quality=85, optimize=True)
        print(f"{path} {img.size} {os.path.getsize(path) // 1024}KB")


if __name__ == "__main__":
    main()
