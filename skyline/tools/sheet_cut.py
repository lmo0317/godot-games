"""Cuts a generated sprite sheet (objects side by side in one row on a transparent background) into
separate sprites, left to right, and shrinks each to the game size with smooth sampling.

Objects are split at the empty columns between them (every pixel in the column nearly transparent),
so a chimney or a puff of smoke stays with its building. Narrow specks are dropped.

  cut(sheet_path) -> [PIL images, left to right]
  fit(img, width=..., height=...) -> image at game size
"""
import numpy as np
from PIL import Image


def cut(path, min_width=20, clear=24):
    img = Image.open(path).convert("RGBA")
    a = np.array(img)
    used = a[..., 3].max(axis=0) > clear
    parts, start = [], None
    for x, on in enumerate(list(used) + [False]):
        if on and start is None:
            start = x
        elif not on and start is not None:
            if x - start >= min_width:
                piece = img.crop((start, 0, x, img.height))
                parts.append(piece.crop(piece.getchannel("A").point(lambda v: 255 if v > clear else 0).getbbox()))
            start = None
    return parts


def fit(img, width=0, height=0):
    w, h = img.size
    s = width / w if width else height / h
    out = img.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
    a = np.array(out)
    a[..., 3] = np.where(a[..., 3] < 10, 0, a[..., 3])     # drop the faint fringe left by the shrink
    return Image.fromarray(a)
