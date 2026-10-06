"""Generates the game's painted sprites (hand-painted cartoon base-builder look) with the Codex CLI
image tool, several objects per sheet so a set keeps one scale, palette and finish, then cuts the
sheets and shrinks every object to its game size (tools/sheet_cut.py).

  style reference          art/style_ref_painted.png (the accepted test sheet, attached every time)
  raw sheets (not in git)  art/raw/sheets/<sheet>.png
  game sprites             assets/sprites/px/<name>.png, at twice the map's resolution (the game
                           draws them at half size): buildings 104 px wide on a 128x64 tile, people
                           34 px tall, cars 46 px wide, icons 54 px wide

Usage:
  python tools/paint_art.py --gen s1 s2      # generate sheets (missing ones only unless --force)
  python tools/paint_art.py --gen all --jobs 4
  python tools/paint_art.py --fit all        # cut the sheets again and write the sprites
"""
import argparse
import concurrent.futures as cf
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))
from sheet_cut import cut, fit  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RAW = os.path.join(ROOT, "art", "raw", "sheets")
OUT = os.path.join(ROOT, "assets", "sprites", "px")
REF = os.path.join(ROOT, "art", "style_ref_painted.png")
CODEX = os.path.expanduser("~/.claude/skills/art-director/scripts/codex_image.sh")

STYLE = ("Style: hand-painted mobile strategy base-builder game art: chunky rounded sturdy shapes, bright "
         "saturated cheerful colors, painterly soft shading with warm light from the top-left and cool "
         "shadows, crisp clean edges with a subtle dark outline, toy-like and readable at small size. Match "
         "the attached reference image's style, outline, colors, view angle, scale and level of detail exactly.")
RULES = ("TRANSPARENT background (PNG with alpha). Wide empty transparent gaps between the objects. No ground "
         "tile, no grass around them, no shadow on the ground, no text, no letters, no numbers, no logos, no "
         "watermark. NOT pixel art.")
ROW = ("in ONE horizontal row, evenly spaced with wide clear gaps, all at the same scale as the reference, all "
       "bases on the same baseline")
ISO = ("each standing on its own square footprint seen from above at a 2:1 isometric angle (diamond base, both "
       "the left wall and the right wall visible)")

# sheet: (subject, [(name, kind), ...] left to right)
SHEETS = {
    "s0_core": (None, [("house_a", "b"), ("bakery", "b"), ("factory", "b"), ("power", "b"),
                       ("water_tower", "b"), ("police", "b")]),
    "s1_homes": (f"A SPRITE SHEET of 6 small city-builder buildings {ROW}, {ISO}. Keep them LOW and compact, about "
                 "as tall as they are wide. From left to right: 1 a cozy family house with a blue roof, white walls "
                 "and a little porch; 2 a small cottage with a green roof, beige walls and a tiny garden fence; 3 a "
                 "two-story townhouse with an orange roof, pink walls and small balconies; 4 a two-story townhouse "
                 "with a navy blue roof, mint green walls and small balconies; 5 a small industrial workshop with gray "
                 "walls, a flat corrugated metal roof, a yellow roller door and wooden crates; 6 a modern high-tech lab "
                 "factory with blue glass panels, white walls and solar panels on the roof.",
                 [("house_b", "b"), ("house_c", "b"), ("rowhouse", "b"), ("rowhouse_b", "b"),
                  ("workshop", "b"), ("hightech", "b")]),
    "s2_tall": (f"A SPRITE SHEET of 6 TALL city-builder buildings {ROW}, {ISO}. These are taller than wide. From left "
                "to right: 1 a six-story modern apartment block, gray and white walls, many windows and balconies, a "
                "rooftop water tank; 2 a six-story apartment block with warm beige brick walls, windows with plants and "
                "a red roof edge; 3 a four-story department store with a red band on top and large glass windows; 4 a "
                "four-story shopping mall with a blue roof band and a glass front; 5 a tall brick clock tower landmark "
                "with a big white clock face and a pointed blue roof; 6 a colorful ferris wheel landmark with rainbow "
                "cabins on a white frame and a small ticket booth.",
                [("apartment", "b"), ("apartment_b", "b"), ("dept", "b"), ("dept_b", "b"), ("clock", "b"),
                 ("wheel", "b")]),
    "s3_shops": (f"A SPRITE SHEET of 5 small one-story shops {ROW}, {ISO}. Keep them LOW and compact. Signs show small "
                 "pictures, never words. From left to right: 1 a small cafe with a brown striped awning, big windows and "
                 "a tiny outdoor table; 2 a small family restaurant with a red awning and red paper lanterns; 3 a small "
                 "clothing boutique with a pink awning and mannequins in the window; 4 a small bookstore with a blue "
                 "awning and colorful books in the window; 5 a small flower shop with a green awning and many flower "
                 "pots in front.",
                 [("cafe", "b"), ("restaurant", "b"), ("clothes", "b"), ("books", "b"), ("flowers", "b")]),
    "s4_shops2": (f"A SPRITE SHEET of 6 two-story shops {ROW}, {ISO}. Signs show small pictures, never words. From left "
                  "to right: 1 a two-story bakery with an orange and white awning and a cake picture sign on the roof "
                  "edge; 2 a two-story cafe with a rooftop terrace with umbrellas and a coffee cup picture sign; 3 a "
                  "two-story restaurant with a red roof, lanterns and warm lit windows; 4 a two-story fashion store with a "
                  "pink and white front and big windows with mannequins; 5 a two-story bookstore with a blue and mint "
                  "front and a reading room upstairs; 6 a two-story flower shop with a glass greenhouse upper floor full "
                  "of plants.",
                  [("bakery_2", "b"), ("cafe_2", "b"), ("restaurant_2", "b"), ("clothes_2", "b"), ("books_2", "b"),
                   ("flowers_2", "b")]),
    "s5_public": (f"A SPRITE SHEET of 6 small public places {ROW}, {ISO}. Keep them LOW and compact. From left to right: "
                  "1 a small fire station of red brick with a flat roof, a hose tower and a garage with a red fire truck; "
                  "2 a small hospital, a white three-story building with a flat roof and a big red cross on the front; 3 "
                  "a small elementary school, a cream two-story building with a clock tower in the middle and a flag "
                  "pole; 4 a small plaza with a round stone fountain spraying water on paving stones; 5 a small square "
                  "park plot with a lawn, one round tree, flower beds, a bench and a tiny pond inside a low hedge; 6 a "
                  "small sports stadium landmark with red and blue stands, a green field and floodlight towers.",
                  [("fire", "b"), ("hospital", "b"), ("school", "b"), ("fountain", "b"), ("park", "b"),
                   ("stadium", "b")]),
    "s6_sites": (f"A SPRITE SHEET of 5 objects {ROW}, {ISO}. Keep them LOW. From left to right: 1 two round leafy green "
                 "trees on a small patch; 2 a dense cluster of four trees, dark green pines and round trees mixed; 3 a "
                 "house under construction: a wooden timber frame, roof rafters, stacked roof tiles and orange traffic "
                 "cones; 4 a shop under construction: a steel frame with a few glass panels, scaffolding and orange "
                 "traffic cones; 5 a factory under construction: gray steel beams, a small yellow crane and orange "
                 "traffic cones.",
                 [("tree", "b"), ("forest", "b"), ("scaffold_r", "b"), ("scaffold_c", "b"), ("scaffold_i", "b")]),
    "s7_people": ("A SPRITE SHEET of 6 tiny townspeople standing in ONE horizontal row, evenly spaced with wide clear "
                  "gaps, all the same height and on the same baseline, full body, seen from the front at the same high "
                  "3/4 angle as the reference, cute simple proportions about 3 heads tall (NOT big-eyed chibi). From "
                  "left to right: 1 a man in a red shirt with brown hair; 2 a man in a blue shirt with black hair; 3 a "
                  "woman in a yellow dress with blond hair; 4 a young person in a green hoodie with short black hair; 5 "
                  "an elderly woman in a purple cardigan with gray hair; 6 a child in a white t-shirt and an orange cap.",
                  [("cit0", "p"), ("cit1", "p"), ("cit2", "p"), ("cit3", "p"), ("cit4", "p"), ("cit5", "p")]),
    "s8_cars": ("A SPRITE SHEET of 6 game objects in ONE horizontal row, evenly spaced with wide clear gaps. From left to "
                "right: 1 a small cute red compact car at the same 2:1 isometric angle as the reference, driving toward "
                "the viewer and to the right (its front and right side visible); 2 the same red car driving away from "
                "the viewer and to the left (its back and left side visible); 3 a shiny gold coin icon; 4 a game alert "
                "marker: a round white speech bubble with a thick dark outline and a tail pointing down, inside it a "
                "gray road piece broken in the middle with a bold red X; 5 the same speech bubble with a bold yellow "
                "lightning bolt with a red slash; 6 the same speech bubble with a bold blue water drop with a red slash.",
                [("car_front", "c"), ("car_back", "c"), ("coin", "t"), ("warn_road", "m"), ("warn_power", "m"),
                 ("warn_water", "m")]),
    "s9_icons": ("A SPRITE SHEET of 6 chunky game button icons in ONE horizontal row, evenly spaced with wide clear gaps, "
                 "all the same size, each a single object in the same painted style and 3/4 angle as the reference. From "
                 "left to right: 1 a short piece of gray road with a white dashed line; 2 a cute small house with a green "
                 "roof; 3 a cute small shop with a blue striped awning; 4 a cute small yellow factory with a chimney; 5 a "
                 "cute small yellow bulldozer; 6 a wooden hammer crossed with a wrench (building tools).",
                 [("ui_road", "i"), ("ui_res", "i"), ("ui_com", "i"), ("ui_ind", "i"), ("ui_bulldoze", "i"),
                  ("ui_fac", "i")]),
    "s10_misc": ("A SPRITE SHEET of 4 game pictures in ONE horizontal row, evenly spaced with wide clear gaps, in the same "
                 "painted style as the reference. From left to right: 1 a chunky game icon of a small open notebook with a "
                 "pencil; 2 a chunky game icon of a round alarm clock; 3 a chunky game icon of a curved arrow turning back "
                 "to the left (undo); 4 a bust portrait of a cheerful young town secretary with brown hair and a green "
                 "ribbon, smiling, facing the viewer (head and shoulders only, cute simple proportions, NOT big-eyed chibi).",
                 [("ui_menu", "i"), ("ui_speed", "i"), ("ui_undo", "i"), ("advisor", "a")]),
}

# kind -> (width, height) in stored pixels; 0 keeps the shape
SIZE = {"b": (104, 0), "p": (0, 34), "c": (46, 0), "t": (26, 0), "m": (34, 0), "i": (54, 0), "a": (0, 76)}


def prompt(sheet):
    subject = SHEETS[sheet][0]
    return f"{subject} {STYLE} {RULES}"


def generate(sheet):
    os.makedirs(RAW, exist_ok=True)
    res = subprocess.run(["bash", CODEX, RAW, sheet, prompt(sheet), REF], capture_output=True, text=True,
                         encoding="utf-8", errors="replace")
    return sheet, os.path.exists(os.path.join(RAW, sheet + ".png")), (res.stdout or "")[-200:]


def fit_sheet(sheet):
    src = os.path.join(RAW, sheet + ".png")
    if not os.path.exists(src):
        return f"no sheet {sheet}"
    names = SHEETS[sheet][1]
    parts = cut(src)
    if len(parts) != len(names):
        return f"{sheet}: found {len(parts)} objects, expected {len(names)} - check the sheet"
    for (name, kind), part in zip(names, parts):
        w, h = SIZE[kind]
        fit(part, width=w, height=h).save(os.path.join(OUT, name + ".png"))
    return f"{sheet}: " + " ".join(n for n, _ in names)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--gen", nargs="*", default=None)
    ap.add_argument("--fit", nargs="*", default=None)
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--jobs", type=int, default=4)
    a = ap.parse_args()
    if a.gen is not None:
        sheets = [s for s in SHEETS if SHEETS[s][0]] if a.gen in ([], ["all"]) else a.gen
        if not a.force:
            sheets = [s for s in sheets if not os.path.exists(os.path.join(RAW, s + ".png"))]
        print("generating", " ".join(sheets), flush=True)
        with cf.ThreadPoolExecutor(max_workers=a.jobs) as ex:
            for sheet, ok, tail in ex.map(generate, sheets):
                print(("ok   " if ok else "FAIL ") + sheet + ("" if ok else " " + tail), flush=True)
                if ok:
                    print(fit_sheet(sheet), flush=True)
    if a.fit is not None:
        for s in (list(SHEETS) if a.fit in ([], ["all"]) else a.fit):
            print(fit_sheet(s))


if __name__ == "__main__":
    sys.exit(main())
