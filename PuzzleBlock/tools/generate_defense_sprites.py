"""Code-drawn retro pixel art for Block Defense (docs/ART_GUIDE.md, "블록 디펜스 도트").

Every sprite is built on its own small pixel grid from simple shapes, then gets a 1-pixel dark
outline and top-left lighting. The game draws all of them at the same x4 scale
(DefenseMode.PIXEL_SCALE), so every art pixel is the same size on screen.

  archer, mage      allies, BACK view (they face up the screen toward the monsters)
  slime, goblin     monsters, FRONT view
  boss              wizard boss, FRONT view
  wall              180 px wide castle wall with the gate (720 px on screen)
  field             180x297 top-down grass and road (720x1188 on screen)
  arrow, fireball   archer and mage shots; spark: hit star

Usage: python tools/generate_defense_sprites.py
"""
import math
import os
import random

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "art", "defense")

# One palette for the whole mode (hex in the guide)
P = {
    "ink": (43, 29, 46),          # outline
    "skin": (241, 195, 154), "skin_d": (201, 141, 107),
    "hair": (246, 211, 101), "hair_d": (201, 154, 58),
    "brown_hair": (140, 86, 52), "brown_hair_d": (98, 58, 36),
    "green_l": (140, 208, 106), "green": (92, 168, 74), "green_d": (52, 112, 52),
    "leather": (139, 90, 60), "leather_d": (91, 56, 38),
    "wood": (208, 138, 69), "wood_d": (154, 90, 42),
    "cream": (255, 244, 214), "string": (232, 224, 200),
    "pants": (91, 74, 110), "boot": (74, 52, 40),
    "blue_l": (127, 168, 240), "blue": (74, 123, 216), "blue_d": (52, 83, 158),
    "gold": (242, 178, 58), "gold_d": (190, 120, 40),
    "orange": (255, 138, 58), "yellow": (255, 226, 110),
    "slime_l": (190, 240, 150), "slime": (126, 217, 87), "slime_m": (79, 168, 61), "slime_d": (46, 110, 44),
    "gob_l": (164, 204, 92), "gob": (126, 170, 64), "gob_d": (86, 124, 46),
    "red": (224, 64, 64), "white": (250, 250, 245),
    "purple_l": (156, 108, 214), "purple": (122, 74, 184), "purple_d": (82, 48, 135),
    "beard": (232, 232, 240), "beard_d": (176, 176, 196),
    "stone_l": (196, 192, 186), "stone": (164, 160, 154), "stone_d": (124, 120, 116), "mortar": (86, 82, 80),
    "door": (178, 74, 52), "door_d": (124, 48, 36), "iron": (70, 66, 74),
    "banner": (74, 110, 200), "banner_d": (50, 76, 150),
    "grass_l": (126, 190, 92), "grass": (104, 172, 78), "grass_d": (86, 150, 66),
    "road_l": (226, 196, 140), "road": (210, 176, 118), "road_d": (176, 142, 92), "pebble": (150, 128, 96),
    "tree_l": (86, 156, 74), "tree": (58, 120, 60), "tree_d": (38, 86, 48), "trunk": (110, 74, 50),
    "flower_w": (250, 248, 236), "flower_y": (250, 214, 90), "flower_p": (230, 150, 190),
}


class Sprite:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[None] * w for _ in range(h)]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = P[c] if isinstance(c, str) else c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return None

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(self.h):
            for x in range(self.w):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.set(x, y, c)

    def rows(self, y0, spans, c):
        """spans: list of (x0, x1) per row starting at y0."""
        for i, (x0, x1) in enumerate(spans):
            for x in range(x0, x1 + 1):
                self.set(x, y0 + i, c)

    def shade_right(self, c_from, c_to, cols=1):
        """Darken the right-most pixels of every row that use c_from."""
        f = P[c_from]
        for y in range(self.h):
            xs = [x for x in range(self.w) if self.px[y][x] == f]
            for x in xs[-cols:]:
                self.px[y][x] = P[c_to]

    def light_left(self, c_from, c_to, cols=1):
        f = P[c_from]
        for y in range(self.h):
            xs = [x for x in range(self.w) if self.px[y][x] == f]
            for x in xs[:cols]:
                self.px[y][x] = P[c_to]

    def outline(self):
        ink = P["ink"]
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] is None:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        n = self.get(x + dx, y + dy)
                        if n is not None and n != ink:
                            add.append((x, y))
                            break
        for x, y in add:
            self.px[y][x] = ink

    def image(self):
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                c = self.px[y][x]
                if c is not None:
                    img.putpixel((x, y), c + (255,))
        return img


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    img.save(path)
    print(f"Generated: {path} {img.size}")


# ---------------------------------------------------------------- allies (back view)

def archer():
    s = Sprite(20, 24)
    # legs and boots
    s.rect(8, 19, 9, 21, "pants"); s.rect(11, 19, 12, 21, "pants")
    s.rect(8, 22, 9, 22, "boot"); s.rect(11, 22, 12, 22, "boot")
    # brown tunic under a dark green cloak hanging from the shoulders
    s.rows(10, [(6, 14), (5, 15), (5, 15), (5, 15), (6, 14), (6, 14), (6, 14), (6, 14), (7, 13)], "green_d")
    s.light_left("green_d", "green")
    s.rect(8, 17, 12, 18, "leather"); s.rect(12, 17, 12, 18, "leather_d")
    # quiver on the back, arrows sticking out over the right shoulder
    s.rect(12, 8, 13, 15, "leather"); s.rect(13, 9, 13, 15, "leather_d")
    s.set(13, 5, "cream"); s.set(14, 5, "cream"); s.set(13, 6, "wood"); s.set(14, 6, "cream"); s.set(13, 7, "wood"); s.set(15, 4, "cream")
    # hood: a round head shape with a point, lighter than the cloak
    s.ellipse(10.0, 6.0, 3.4, 3.2, "green")
    s.set(10, 2, "green"); s.set(11, 2, "green")
    s.light_left("green", "green_l")
    s.shade_right("green", "green_d")
    s.set(7, 8, "hair"); s.set(13, 8, "hair_d")
    # both arms up to the bow held high in front (seen from behind: above the head)
    s.rect(5, 9, 6, 10, "green_d"); s.rect(14, 9, 15, 10, "green_d")
    s.set(5, 8, "skin"); s.set(15, 8, "skin")
    # the bow: a wide arc above, string and an arrow pointing up
    for x, y in ((3, 4), (4, 3), (5, 2), (6, 2), (7, 1), (8, 1), (9, 1), (10, 1), (11, 1), (12, 1), (13, 2), (14, 2), (15, 3), (16, 4)):
        s.set(x, y, "wood")
    s.set(3, 5, "wood_d"); s.set(16, 5, "wood_d")
    for x in range(4, 16):
        if s.get(x, 5) is None:
            s.set(x, 5, "string")
    s.set(10, 0, "cream")
    s.outline()
    return s.image()


def mage():
    s = Sprite(20, 24)
    # robe
    s.rows(11, [(7, 13), (7, 13), (6, 14), (6, 14), (6, 14), (5, 15), (5, 15), (5, 15), (4, 16), (4, 16), (5, 15)], "blue")
    s.light_left("blue", "blue_l")
    s.shade_right("blue", "blue_d", 2)
    s.rect(6, 22, 8, 22, "boot"); s.rect(12, 22, 14, 22, "boot")
    # hair under the brim
    s.rect(8, 9, 12, 10, "brown_hair"); s.rect(12, 9, 12, 10, "brown_hair_d")
    # big pointy hat from behind, tip bending right
    s.ellipse(10.0, 8.5, 6.2, 1.7, "blue")
    s.rows(1, [(12, 13), (11, 13), (10, 12), (9, 12), (9, 12), (8, 12), (8, 12)], "blue")
    s.rect(8, 7, 12, 7, "gold")
    s.light_left("blue", "blue_l")
    s.shade_right("blue", "blue_d")
    # right arm raised with the star wand
    s.rect(15, 8, 16, 11, "blue_d")
    s.set(16, 7, "skin")
    for y in range(3, 7):
        s.set(17, y, "wood")
    s.set(17, 1, "yellow"); s.set(16, 2, "orange"); s.set(18, 2, "orange"); s.set(17, 2, "yellow"); s.set(17, 3, "orange")
    s.outline()
    return s.image()


# ---------------------------------------------------------------- monsters (front view)

def slime():
    s = Sprite(16, 13)
    s.rows(1, [(6, 9), (4, 11), (3, 12), (2, 13), (2, 13), (1, 14), (1, 14), (1, 14), (1, 14), (2, 13), (1, 14)], "slime")
    s.light_left("slime", "slime_l")
    s.shade_right("slime", "slime_m", 2)
    s.rect(2, 11, 13, 11, "slime_m"); s.set(1, 11, "slime_d"); s.set(14, 11, "slime_d")
    s.set(4, 3, "slime_l"); s.set(5, 2, "white"); s.set(4, 4, "white")
    # angry eyes, eyebrows and a fanged mouth
    s.rect(4, 6, 5, 7, "white"); s.rect(10, 6, 11, 7, "white")
    s.set(5, 7, "ink"); s.set(10, 7, "ink")
    s.set(3, 5, "slime_d"); s.set(4, 5, "slime_d"); s.set(11, 5, "slime_d"); s.set(12, 5, "slime_d")
    s.rect(6, 9, 9, 9, "slime_d"); s.set(6, 10, "white"); s.set(9, 10, "white")
    s.outline()
    return s.image()


def goblin():
    s = Sprite(20, 22)
    # legs
    s.rect(7, 17, 8, 19, "gob_d"); s.rect(11, 17, 12, 19, "gob_d")
    s.rect(6, 20, 8, 20, "boot"); s.rect(11, 20, 13, 20, "boot")
    # ragged tunic and belt
    s.rows(11, [(6, 13), (6, 13), (6, 13), (5, 14), (5, 14), (5, 14)], "leather")
    s.set(5, 16, "leather"); s.set(8, 16, "leather"); s.set(11, 16, "leather"); s.set(14, 16, "leather")
    s.shade_right("leather", "leather_d", 2)
    s.rect(6, 13, 13, 13, "leather_d"); s.set(9, 13, "gold")
    # arms: left down, right up holding a club
    s.rect(3, 11, 4, 14, "gob"); s.set(3, 15, "gob_d")
    s.rect(15, 8, 16, 11, "gob")
    s.rect(15, 1, 17, 6, "wood"); s.rect(16, 0, 17, 0, "wood"); s.rect(17, 1, 17, 6, "wood_d"); s.set(15, 7, "wood_d")
    # head with big ears
    s.ellipse(9.5, 6.5, 4.2, 3.8, "gob")
    s.rows(4, [(1, 4), (2, 5), (3, 5)], "gob"); s.rows(4, [(15, 18), (14, 17), (14, 16)], "gob")
    s.light_left("gob", "gob_l")
    s.shade_right("gob", "gob_d")
    # yellow eyes with red pupils, toothy grin
    s.rect(7, 5, 8, 6, "yellow"); s.rect(11, 5, 12, 6, "yellow")
    s.set(8, 6, "red"); s.set(11, 6, "red")
    s.rect(7, 8, 12, 8, "ink"); s.set(8, 9, "white"); s.set(11, 9, "white")
    s.outline()
    return s.image()


def boss():
    s = Sprite(32, 36)
    # robe with gold trim
    s.rows(16, [(11, 20), (10, 21), (9, 22), (9, 22), (8, 23), (8, 23), (7, 24), (7, 24), (7, 24), (6, 25),
                (6, 25), (6, 25), (5, 26), (5, 26), (5, 26), (4, 27), (4, 27), (5, 26)], "purple")
    s.light_left("purple", "purple_l", 2)
    s.shade_right("purple", "purple_d", 3)
    for y in range(22, 34):
        s.set(15, y, "gold"); s.set(16, y, "gold_d")
    # sleeves and hands
    s.rows(17, [(5, 8), (4, 8), (3, 7), (3, 6)], "purple_d"); s.set(3, 21, "skin"); s.set(4, 21, "skin")
    s.rows(17, [(23, 26), (23, 27), (24, 28)], "purple_d"); s.set(27, 20, "skin")
    # long white beard
    s.rows(14, [(12, 19), (12, 19), (12, 19), (13, 18), (13, 18), (14, 17), (14, 17), (15, 16)], "beard")
    s.shade_right("beard", "beard_d")
    # face in the hat's shadow with glowing eyes
    s.rect(12, 11, 19, 13, "skin_d")
    s.rect(13, 12, 14, 12, "yellow"); s.rect(17, 12, 18, 12, "yellow")
    # huge hat, brim and a cone curling left, gem on the band
    s.ellipse(15.5, 10.5, 12.0, 2.2, "purple")
    s.rows(0, [(6, 8), (6, 10), (8, 12), (10, 14), (11, 15), (11, 16), (11, 17), (10, 18), (10, 19), (10, 20)], "purple")
    s.rect(10, 9, 21, 9, "gold"); s.set(15, 9, "red"); s.set(16, 9, "red")
    s.light_left("purple", "purple_l")
    s.shade_right("purple", "purple_d", 2)
    # staff with a glowing crystal
    for y in range(8, 35):
        s.set(28, y, "wood")
        s.set(29, y, "wood_d")
    s.rows(2, [(28, 29), (27, 30), (27, 30), (27, 30), (28, 29)], "orange")
    s.set(28, 3, "yellow"); s.set(28, 4, "yellow")
    s.outline()
    return s.image()


# ---------------------------------------------------------------- wall and field

def wall():
    W, H = 180, 40
    s = Sprite(W, H)
    # stone body
    s.rect(0, 9, W - 1, H - 1, "stone")
    # bricks: rows of 4 px, offset every other row; soft joints, a few lighter or darker bricks
    rnd = random.Random(3)
    for row, y in enumerate(range(10, H, 4)):
        off = 0 if row % 2 == 0 else 5
        for x0 in range(off - 10, W, 10):
            tint = rnd.choice(["stone", "stone", "stone", "stone_l", "stone_d"])
            for yy in range(y + 1, min(y + 4, H)):
                for x in range(max(0, x0 + 1), min(W, x0 + 10)):
                    s.set(x, yy, tint)
            for x in range(max(0, x0 + 1), min(W, x0 + 10)):
                s.set(x, y, "stone_d")
            if 0 <= x0 < W:
                for yy in range(y, min(y + 4, H)):
                    s.set(x0, yy, "stone_d")
    # battlements along the top, a walkway line under them
    for x0 in range(0, W, 12):
        s.rect(x0 + 1, 2, x0 + 7, 8, "stone")
        s.rect(x0 + 1, 2, x0 + 7, 2, "stone_l")
        s.rect(x0 + 7, 3, x0 + 7, 8, "stone_d")
    s.rect(0, 9, W - 1, 9, "stone_l")
    # banners either side of the gate
    for bx in (42, 130):
        s.rect(bx, 13, bx + 7, 28, "banner")
        s.rect(bx + 6, 13, bx + 7, 28, "banner_d")
        s.rect(bx + 2, 18, bx + 5, 21, "gold")
        s.set(bx, 29, "banner"); s.set(bx + 7, 29, "banner_d"); s.set(bx + 1, 29, "banner")
        s.rect(bx - 1, 12, bx + 8, 12, "wood")
    # the gate: stone arch, red wooden door with iron bands and gold studs
    cx = 90
    for y in range(14, H):
        for x in range(cx - 18, cx + 18):
            dx = (x + 0.5 - cx) / 18.0
            top = 26 - math.sqrt(max(0.0, 1 - dx * dx)) * 12
            if y >= top:
                s.set(x, y, "mortar")
    for y in range(16, H):
        for x in range(cx - 14, cx + 14):
            dx = (x + 0.5 - cx) / 14.0
            top = 27 - math.sqrt(max(0.0, 1 - dx * dx)) * 10
            if y >= top:
                s.set(x, y, "door" if (x - cx + 14) % 7 else "door_d")
    s.rect(cx, 18, cx, H - 1, "door_d")
    for y in (25, 33):
        s.rect(cx - 13, y, cx + 13, y, "iron")
    for x, y in ((cx - 7, 21), (cx + 6, 21), (cx - 7, 29), (cx + 6, 29)):
        s.set(x, y, "gold")
    s.set(cx - 2, 29, "gold"); s.set(cx + 1, 29, "gold")
    return s.image()


def field():
    W, H = 180, 297
    rnd = random.Random(7)
    s = Sprite(W, H)
    s.rect(0, 0, W - 1, H - 1, "grass")
    # grass texture: soft clumps of light and dark
    for _ in range(1400):
        x, y = rnd.randrange(W), rnd.randrange(H)
        c = rnd.choice(["grass_l", "grass_d", "grass_d"])
        s.set(x, y, c)
        if rnd.random() < 0.5:
            s.set(x + 1, y, c)
    # dirt road down the middle with wavy edges
    for y in range(H):
        wob = int(round(math.sin(y / 23.0) * 3 + math.sin(y / 7.0)))
        x0, x1 = 68 + wob, 112 + wob
        for x in range(x0, x1):
            s.set(x, y, "road")
        s.set(x0, y, "road_d"); s.set(x1 - 1, y, "road_d")
        if rnd.random() < 0.35:
            s.set(x0 + 1 + rnd.randrange(x1 - x0 - 2), y, "road_l")
    for _ in range(90):
        y = rnd.randrange(H)
        wob = int(round(math.sin(y / 23.0) * 3 + math.sin(y / 7.0)))
        x = rnd.randrange(70 + wob, 110 + wob)
        s.set(x, y, "pebble")
    # flowers on the grass
    for _ in range(140):
        x, y = rnd.randrange(W), rnd.randrange(H)
        if 64 <= x <= 116:
            continue
        petal = rnd.choice(["flower_w", "flower_y", "flower_p"])
        s.set(x - 1, y, petal); s.set(x + 1, y, petal); s.set(x, y - 1, petal); s.set(x, y + 1, petal)
        s.set(x, y, "flower_y" if petal != "flower_y" else "wood")
    # round trees along both edges
    for side in (0, 1):
        y = rnd.randrange(-6, 10)
        while y < H:
            r = rnd.randrange(8, 13)
            cx = (rnd.randrange(2, 16) if side == 0 else W - rnd.randrange(2, 16))
            s.rect(cx - 1, y + r - 2, cx + 1, y + r + 4, "trunk")
            s.ellipse(cx + 0.5, y + 0.5, r, r * 0.9, "tree")
            s.ellipse(cx - r * 0.25, y - r * 0.25, r * 0.6, r * 0.5, "tree_l")
            s.ellipse(cx + r * 0.35, y + r * 0.3, r * 0.55, r * 0.45, "tree_d")
            y += rnd.randrange(22, 40)
    img = s.image()
    return img


# ---------------------------------------------------------------- shots and hits

def arrow():
    """Points up; the game rotates it toward the target."""
    s = Sprite(3, 10)
    s.set(1, 0, "cream"); s.set(0, 1, "stone_l"); s.set(1, 1, "white"); s.set(2, 1, "stone_l")
    for y in range(2, 8):
        s.set(1, y, "wood")
    s.set(0, 8, "red"); s.set(2, 8, "red"); s.set(1, 8, "wood_d"); s.set(0, 9, "red"); s.set(2, 9, "red")
    return s.image()


def fireball():
    s = Sprite(9, 9)
    s.ellipse(4.5, 4.5, 4.2, 4.2, "orange")
    s.ellipse(4.0, 4.0, 2.6, 2.6, "yellow")
    s.set(3, 3, "white"); s.set(4, 3, "white")
    return s.image()


def spark():
    """A small four-pointed hit star."""
    s = Sprite(7, 7)
    for i in range(7):
        s.set(3, i, "yellow"); s.set(i, 3, "yellow")
    s.set(3, 3, "white"); s.set(2, 3, "white"); s.set(4, 3, "white"); s.set(3, 2, "white"); s.set(3, 4, "white")
    s.set(0, 3, "orange"); s.set(6, 3, "orange"); s.set(3, 0, "orange"); s.set(3, 6, "orange")
    return s.image()


def main():
    save(archer(), "archer")
    save(mage(), "mage")
    save(slime(), "slime")
    save(goblin(), "goblin")
    save(boss(), "boss")
    save(wall(), "wall")
    save(field(), "field")
    save(arrow(), "arrow")
    save(fireball(), "fireball")
    save(spark(), "spark")


if __name__ == "__main__":
    main()
