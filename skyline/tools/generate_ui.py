"""Draws the UI frames in the painted base-builder look into assets/ui/ (used as nine-patch boxes by
scripts/ui_kit.gd): chunky buttons with a thick dark rim, a glossy top and a darker lip at the
bottom, see-through dark status bars, the popup window and the advisor's speech box.

Everything is drawn at 4x and shrunk, so curves are smooth. The corner size of every picture is
CORNER px (the nine-patch margin in ui_kit.gd).

  btn_<color>.png, btn_<color>_down.png   green, orange, blue, red, yellow, gray (pressed: lip pushed in)
  hud.png                                 status bar background
  window.png                              popup / shop window
  bubble.png                              advisor message box

Usage: python tools/generate_ui.py
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "ui")
SS = 4
SIZE = 96
OUT_SIZE = 72                # drawn at 96 (design), saved at 72: corners about 24 px
CORNER = 24
RIM = (27, 24, 38)

BUTTONS = {          # top, bottom, lip
    "green": ("#a6e650", "#6fbf26", "#3f7a12"),
    "orange": ("#ffc94d", "#f5951f", "#a5520c"),
    "blue": ("#6cc4ff", "#3189dd", "#1c4f8f"),
    "red": ("#ff7a66", "#e0412f", "#8f1f16"),
    "yellow": ("#fff07a", "#ffc928", "#b07a0a"),
    "gray": ("#b9bec6", "#8b919b", "#5a5f68"),
}


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


def rrect(w, h, x0, y0, x1, y1, r):
    """Smooth-edged rounded rectangle coverage (0..1) on a w x h grid (big pixels)."""
    ys, xs = np.mgrid[0:h, 0:w] + 0.5
    cx = np.clip(xs, x0 + r, x1 - r)
    cy = np.clip(ys, y0 + r, y1 - r)
    d = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2) - r
    return np.clip(0.5 - d, 0, 1)


def over(dst, color, cover, alpha=1.0):
    a = cover * alpha
    dst[..., :3] = dst[..., :3] * (1 - a[..., None]) + np.asarray(color, float) * a[..., None]
    dst[..., 3] = dst[..., 3] * (1 - a) + 255 * a


def shrink(big, name, size=OUT_SIZE):
    img = Image.fromarray(np.clip(big, 0, 255).astype(np.uint8))
    img.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))


def button(top, bottom, lip, down):
    n = SIZE * SS
    big = np.zeros((n, n, 4))
    r = 26 * SS
    sink = 4 * SS if down else 0
    lip_h = 9 * SS - sink
    rim = 4 * SS
    # dark rim around everything, then the lip, then the face
    over(big, RIM, rrect(n, n, 0, sink, n, n, r))
    over(big, hexc(lip), rrect(n, n, rim, sink + rim, n - rim, n - rim, r - rim))
    face = rrect(n, n, rim, sink + rim, n - rim, n - rim - lip_h, r - rim)
    ys = np.mgrid[0:n, 0:n][0]
    t = np.clip((ys - sink - rim) / (n - 2 * rim - lip_h - sink), 0, 1)
    grad = hexc(top) * (1 - t[..., None]) + hexc(bottom) * t[..., None]
    big[..., :3] = big[..., :3] * (1 - face[..., None]) + grad * face[..., None]
    # glossy band on the upper half
    gloss = rrect(n, n, rim + 8 * SS, sink + rim + 5 * SS, n - rim - 8 * SS, sink + rim + 30 * SS, 14 * SS)
    over(big, (255, 255, 255), gloss, 0.28)
    return big


def hud():
    n = SIZE * SS
    big = np.zeros((n, n, 4))
    over(big, (12, 14, 26), rrect(n, n, 0, 0, n, n, 26 * SS), 0.62)
    over(big, (255, 255, 255), rrect(n, n, 3 * SS, 3 * SS, n - 3 * SS, 7 * SS + 3 * SS, 4 * SS), 0.06)
    return big


def window():
    n = SIZE * SS
    big = np.zeros((n, n, 4))
    r = 28 * SS
    rim = 5 * SS
    over(big, RIM, rrect(n, n, 0, 0, n, n, r))
    over(big, hexc("#4d6f93"), rrect(n, n, rim, rim, n - rim, n - rim, r - rim))
    over(big, hexc("#34506f"), rrect(n, n, rim + 3 * SS, rim + 3 * SS, n - rim - 3 * SS, n - rim - 3 * SS, r - rim - 3 * SS))
    ys = np.mgrid[0:n, 0:n][0]
    over(big, (255, 255, 255), rrect(n, n, rim + 3 * SS, rim + 3 * SS, n - rim - 3 * SS, n - rim - 3 * SS, r - rim - 3 * SS)
         * np.clip(1 - ys / (n * 0.5), 0, 1), 0.08)
    return big


def bubble():
    n = SIZE * SS
    big = np.zeros((n, n, 4))
    r = 24 * SS
    rim = 4 * SS
    over(big, RIM, rrect(n, n, 0, 0, n, n, r))
    over(big, hexc("#fff8e6"), rrect(n, n, rim, rim, n - rim, n - rim, r - rim))
    over(big, hexc("#f0e2c0"), rrect(n, n, rim, n - rim - 8 * SS, n - rim, n - rim, r - rim) *
         (np.mgrid[0:n, 0:n][0] > n - rim - 8 * SS), 1.0)
    return big


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (top, bottom, lip) in BUTTONS.items():
        shrink(button(top, bottom, lip, False), "btn_" + name)
        shrink(button(top, bottom, lip, True), "btn_%s_down" % name)
    shrink(hud(), "hud")
    shrink(window(), "window")
    shrink(bubble(), "bubble")
    print("ui frames written to", OUT)


if __name__ == "__main__":
    main()
