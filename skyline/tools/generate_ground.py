"""Draws the isometric ground tiles into assets/sprites/px/ in the painted base-builder look (soft
cartoon shading, smooth edges, bright colors): a lawn in a light/dark checker, stone-edged asphalt
roads, turquoise water with a sandy shore, wooden bridges and the three zoned plots.

Tiles are 128x64 diamonds: a 64x32 map tile at 2x detail (the game draws them at half size).
Every pixel is computed from its position on the tile in grid space (gx, gy in 0..1; gx grows toward
the lower right, gy toward the lower left), so roads, shores and fences line up from tile to tile.
Each tile is computed at 4x and shrunk, so edges are smooth. Neighbor masks: N (y-1) = 1, E (x+1) = 2,
S (y+1) = 4, W (x-1) = 8.

  grass0, grass1            lawn, light and dark squares of the checker (the map alternates them)
  water<m>_<f>              water with a sandy shore toward land on the mask sides, frames f = 0, 1
  road<m>, bridge<m>        road / wooden bridge pieces by neighbor mask
  lot_r, lot_c, lot_i       zoned plots (also the yard under buildings): lawn with a hedge, stone
                            paving, concrete yard with hazard stripes
Also: car_front0..3 / car_back0..3 color versions of the red car, and the app icon.

Usage: python tools/generate_ground.py
"""
import colorsys
import os

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PX = os.path.join(ROOT, "assets", "sprites", "px")
TW, TH = 128, 64
SS = 4                      # supersampling


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


GRASS = [hexc("#8fd14f"), hexc("#7fc243")]          # checker light / dark
GRASS_SPOT = hexc("#a4de62")
WATER_DEEP = hexc("#2f9fd8")
WATER_LIGHT = hexc("#5cc8ef")
FOAM = hexc("#e9f8ff")
SAND = hexc("#f1d79b")
SAND_D = hexc("#d9b673")
ASPHALT = hexc("#8a93a0")
ASPHALT_D = hexc("#707a87")
CURB = hexc("#e6dfcf")
CURB_D = hexc("#b9b09c")
WOOD = hexc("#c98f55")
WOOD_D = hexc("#9a6638")
HEDGE = hexc("#4f9a35")
HEDGE_L = hexc("#6dbb47")
PAVE = hexc("#e9dfc8")
PAVE_D = hexc("#d3c6a8")
CONC = hexc("#c4c2bb")
CONC_D = hexc("#aeaba3")
HAZ_Y = hexc("#f6c033")
HAZ_K = hexc("#3b3530")


def grid():
    ys, xs = np.mgrid[0:TH * SS, 0:TW * SS]
    u = (xs + 0.5 - TW * SS / 2) / (TW * SS / 2)
    v = (ys + 0.5 - TH * SS / 2) / (TH * SS / 2)
    gx = (u + v) / 2 + 0.5
    gy = (v - u) / 2 + 0.5
    e = 0.012                                       # tiny overlap so neighbors leave no seam
    inside = (gx >= -e) & (gx < 1 + e) & (gy >= -e) & (gy < 1 + e)
    return gx, gy, inside


GX, GY, INSIDE = grid()


def smooth(x, a, b):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def blobs(seed, count, size):
    """Soft periodic blotches (period 1 in gx and gy, so they match across tile edges)."""
    rng = np.random.default_rng(seed)
    f = np.zeros_like(GX)
    for _ in range(count):
        cx, cy = rng.random(2)
        dx = (GX - cx + 0.5) % 1 - 0.5
        dy = (GY - cy + 0.5) % 1 - 0.5
        f += np.exp(-(dx * dx + dy * dy) / (size * size))
    return np.clip(f, 0, 1)


def mix(a, b, t):
    return a + (b - a) * t[..., None]


def finish(rgb, alpha=None):
    """4x float image -> 128x64 RGBA with smooth edges."""
    a = INSIDE.astype(float) if alpha is None else alpha * INSIDE
    big = np.dstack([np.clip(rgb, 0, 255), a * 255]).astype(np.uint8)
    img = Image.fromarray(big)
    return img.resize((TW, TH), Image.LANCZOS)


def flat(color):
    return np.ones(GX.shape + (3,)) * color


def lawn(k):
    rgb = flat(GRASS[k])
    rgb = mix(rgb, GRASS_SPOT, blobs(10 + k, 5, 0.12) * 0.35)
    rgb = mix(rgb, GRASS[1] * 0.92, blobs(20 + k, 4, 0.10) * 0.25)
    return rgb


def grass_tile(k):
    return finish(lawn(k))


def edge_dist(mask):
    """Distance (in tile units) to the nearest side where the mask says 'land' (for shores)."""
    d = np.full(GX.shape, 9.0)
    if mask & 1:
        d = np.minimum(d, GY)
    if mask & 2:
        d = np.minimum(d, 1 - GX)
    if mask & 4:
        d = np.minimum(d, 1 - GY)
    if mask & 8:
        d = np.minimum(d, GX)
    return d


def water_tile(mask, frame):
    depth = smooth(edge_dist(mask), 0.08, 0.6)
    rgb = mix(WATER_LIGHT, WATER_DEEP, depth)
    # soft light streaks that move between the two frames
    phase = frame * 0.5
    wave = np.sin((GX * 2 + GY * 1 + phase) * np.pi * 2) * np.sin((GY * 3 - GX + phase) * np.pi * 2)
    rgb = mix(rgb, FOAM, smooth(wave, 0.75, 0.95) * 0.45)
    d = edge_dist(mask)
    rgb = mix(rgb, FOAM, (1 - smooth(d, 0.10, 0.16)) * 0.8)       # foam line
    rgb = mix(rgb, SAND, 1 - smooth(d, 0.07, 0.10))               # beach
    rgb = mix(rgb, SAND_D, (1 - smooth(d, 0.0, 0.05)) * 0.5)
    return finish(rgb)


def road_dist(mask):
    """Distance from the road's center line (0 = middle, 0.5 = tile edge), following the arms."""
    cx = np.abs(GX - 0.5)
    cy = np.abs(GY - 0.5)
    d = np.maximum(cx, cy)                          # the middle square
    if mask & 1:
        d = np.where(GY < 0.5, np.minimum(d, cx), d)
    if mask & 4:
        d = np.where(GY >= 0.5, np.minimum(d, cx), d)
    if mask & 8:
        d = np.where(GX < 0.5, np.minimum(d, cy), d)
    if mask & 2:
        d = np.where(GX >= 0.5, np.minimum(d, cy), d)
    return d


def road_tile(mask):
    d = road_dist(mask)
    rgb = lawn(0)
    curb = 1 - smooth(d, 0.36, 0.38)
    rgb = mix(rgb, CURB_D, curb)
    rgb = mix(rgb, CURB, 1 - smooth(d, 0.33, 0.35))
    body = 1 - smooth(d, 0.29, 0.31)
    tar = mix(ASPHALT, ASPHALT_D, smooth(d, 0.0, 0.3) * 0.6)
    tar = mix(tar, ASPHALT * 1.08, blobs(60 + mask, 3, 0.08) * 0.25)
    rgb = mix(rgb, tar, body)
    return finish(rgb)


def bridge_tile(mask):
    d = road_dist(mask)
    along_x = (mask & 10) and not (mask & 5)
    planks = ((GX if along_x else GY) * 10) % 1
    wood = mix(WOOD, WOOD_D, smooth(planks, 0.80, 0.92) * 0.9)
    deck = 1 - smooth(d, 0.31, 0.33)
    rail = (1 - smooth(d, 0.36, 0.38)) * smooth(d, 0.31, 0.33)
    rgb = flat(WATER_DEEP)
    rgb = mix(rgb, WOOD_D * 0.85, rail)
    rgb = mix(rgb, wood, deck)
    alpha = np.clip(deck + rail, 0, 1)
    return finish(rgb, alpha)


def lot_tile(kind):
    edge = np.minimum(np.minimum(GX, 1 - GX), np.minimum(GY, 1 - GY))
    if kind == "r":     # lawn with a low rounded hedge around it
        rgb = mix(lawn(0), hexc("#a6df6a"), np.ones(GX.shape) * 0.4)
        hedge = 1 - smooth(edge, 0.05, 0.07)
        rgb = mix(rgb, mix(HEDGE, HEDGE_L, smooth(edge, 0.0, 0.05)), hedge)
    elif kind == "c":   # stone paving
        tiles = ((np.floor(GX * 5) + np.floor(GY * 5)) % 2)
        rgb = mix(flat(PAVE), PAVE_D, tiles * 0.5)
        grout = np.minimum((GX * 5) % 1, (GY * 5) % 1)
        rgb = mix(rgb, PAVE_D * 0.9, (1 - smooth(grout, 0.0, 0.06)) * 0.6)
        rgb = mix(rgb, CURB_D, 1 - smooth(edge, 0.03, 0.05))
    else:               # concrete yard with hazard stripes
        rgb = mix(flat(CONC), CONC_D, blobs(90, 4, 0.12) * 0.5)
        stripe = (((GX + GY) * 8) % 1) < 0.5
        band = 1 - smooth(edge, 0.05, 0.065)
        rgb = mix(rgb, np.where(stripe[..., None], HAZ_Y, HAZ_K), band)
    return finish(rgb)


def save(img, name):
    img.save(os.path.join(PX, name + ".png"))


def hue_shift(img, shift):
    a = np.array(img.convert("RGBA")).astype(float) / 255.0
    flat_px = a.reshape(-1, 4)
    for i in range(len(flat_px)):
        r, g, b, al = flat_px[i]
        if al == 0:
            continue
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        if s >= 0.35 and (h < 0.08 or h > 0.92):     # only the red paint
            flat_px[i, :3] = colorsys.hls_to_rgb((h + shift) % 1.0, l, s)
    return Image.fromarray((a * 255).astype(np.uint8))


def white_car(img):
    a = np.array(img.convert("RGBA")).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    red = (r > g * 1.4) & (r > b * 1.4) & (a[..., 3] > 0)
    light = np.clip(r * 0.35 + 165, 0, 245)
    for c in range(3):
        a[..., c] = np.where(red, light, a[..., c])
    return Image.fromarray(a.astype(np.uint8))


def app_icon():
    """256x256 icon: the red-roof house on a lawn plot under a blue sky."""
    scene = Image.new("RGBA", (128, 128), (126, 196, 244, 255))
    scene.alpha_composite(Image.open(os.path.join(PX, "lot_r.png")).convert("RGBA"), (0, 60))
    house = Image.open(os.path.join(PX, "house_a.png")).convert("RGBA")
    scene.alpha_composite(house, ((128 - house.width) // 2, max(0, 112 - house.height)))
    scene.resize((256, 256), Image.LANCZOS).save(os.path.join(ROOT, "assets", "sprites", "icon.png"))


def main():
    os.makedirs(PX, exist_ok=True)
    for k in range(2):
        save(grass_tile(k), "grass%d" % k)
    for m in range(16):
        save(road_tile(m), "road%d" % m)
        save(bridge_tile(m), "bridge%d" % m)
        for f in range(2):
            save(water_tile(m, f), "water%d_%d" % (m, f))
    for k in ("r", "c", "i"):
        save(lot_tile(k), "lot_" + k)
    for view in ("front", "back"):
        src = os.path.join(PX, "car_%s.png" % view)
        if os.path.exists(src):
            car = Image.open(src)
            car.save(os.path.join(PX, "car_%s0.png" % view))
            hue_shift(car, 0.62).save(os.path.join(PX, "car_%s1.png" % view))
            hue_shift(car, 0.14).save(os.path.join(PX, "car_%s2.png" % view))
            white_car(car).save(os.path.join(PX, "car_%s3.png" % view))
    if os.path.exists(os.path.join(PX, "house_a.png")):
        app_icon()
    print("ground tiles written to", PX)


if __name__ == "__main__":
    main()
