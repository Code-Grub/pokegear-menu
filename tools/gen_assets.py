#!/usr/bin/env python3
"""Generate the phone mod's art.

Two sheets, both original: assets/icons.png (ten 16x16 app icons) and
assets/label_font.png (a 4x6 face for the app captions).

Every pixel is declared here as text, so the art carries its own proof of
provenance: nothing in the output originates in a ROM.

Run: python tools/gen_assets.py
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(HERE, "assets")

# The mockup's palette. 0 is transparent.
PALETTE = {
    ".": (0, 0, 0, 0),
    "1": (36, 46, 46, 255),      # outline, near-black teal
    "2": (104, 132, 124, 255),   # mid shadow
    "3": (196, 214, 202, 255),   # light fill
    "4": (240, 240, 224, 255),   # cream highlight
    "5": (176, 48, 48, 255),     # pokeball red
    "6": (232, 232, 232, 255),   # white
}

ICON_ORDER = ["dex", "pkmn", "bag", "id", "optn", "save", "map", "link",
              "mods", "generic"]

# 16 rows of 16 characters each, per icon.
ICONS = {
    # A handheld dex: rounded body, screen, a red lamp.
    "dex": [
        "................",
        "...1111111111...",
        "..13333333331...",
        "..13111111131...",
        "..13166666131...",
        "..13166666131...",
        "..13166666131...",
        "..13111111131...",
        "..13333333331...",
        "..13511133331...",
        "..13511133331...",
        "..13333333331...",
        "..13313131331...",
        "..13333333331...",
        "...1111111111...",
        "................",
    ],
    # A poke ball: red top, white bottom, banded middle.
    "pkmn": [
        "................",
        ".....111111.....",
        "...1155555511...",
        "..155555555551..",
        ".15555555555551.",
        ".15555555555551.",
        "1555551111555551",
        "1111111661111111",
        "1111111661111111",
        "1666661111666661",
        ".16666666666661.",
        ".16666666666661.",
        "..166666666661..",
        "...1166666611...",
        ".....111111.....",
        "................",
    ],
    # A satchel with a flap and a clasp.
    "bag": [
        "................",
        "................",
        "....11....11....",
        "...1331..1331...",
        "...1331111331...",
        "..1133333333311.",
        "..1333333333331.",
        "..1322222222331.",
        "..1322222222331.",
        "..1333333333331.",
        "..1333311133331.",
        "..1333111113331.",
        "..1333311133331.",
        "..1333333333331.",
        "...11111111111..",
        "................",
    ],
    # A trainer card: portrait block and text rules.
    "id": [
        "................",
        "..111111111111..",
        "..144444444441..",
        "..141111114441..",
        "..141333314441..",
        "..141333311111..",
        "..141333314441..",
        "..141111114441..",
        "..144444444441..",
        "..141111111141..",
        "..144444444441..",
        "..141111111141..",
        "..144444444441..",
        "..141111114441..",
        "..111111111111..",
        "................",
    ],
    # Two sliders: the options screen as a mixing desk.
    "optn": [
        "................",
        "................",
        "....11....11....",
        "....11....11....",
        "....11....11....",
        "..1111....11....",
        "..1111....11....",
        "..1111..1111....",
        "....11..1111....",
        "....11..1111....",
        "....11....11....",
        "....11....11....",
        "....11....11....",
        "................",
        "................",
        "................",
    ],
    # A memory card: notched corner, contact strip.
    # A microSD card: bevelled corner, contact stripes near the base.
    # The old one was a device with a screen and buttons, which read as a
    # sibling of the dex rather than as somewhere to save.
    "save": [
        "................",
        "......1111111...",
        ".....13333331...",
        "....133333331...",
        "...1333333331...",
        "...1333333331...",
        "...1333333331...",
        "...1333333331...",
        "...1333333331...",
        "...1333333331...",
        "...1313131331...",
        "...1313131331...",
        "...1313131331...",
        "...1333333331...",
        "...1111111111...",
        "................",
    ],
    # A map pin over a ground mark.
    # A location pin with a centred hole, tapering to a tip on the
    # midline.  The old one was lopsided: eleven of its sixteen rows
    # were not left-right symmetric, the hole sat a pixel left of
    # centre, and the tip landed off the axis of the head.
    "map": [
        "................",
        ".....111111.....",
        "...1133333311...",
        "..133333333331..",
        "..133333333331..",
        "..133311113331..",
        "..133116611331..",
        "..133116611331..",
        "..133311113331..",
        "..133333333331..",
        "...1333333331...",
        "....13333331....",
        ".....133331.....",
        "......1331......",
        ".......11.......",
        "................",
    ],
    # A link cable: two plugs joined by a lead.
    # Two opposed arrows: the exchange gesture.  The earlier cable drew
    # as an unreadable squiggle at 16px, and legibility at actual size
    # beats era-accuracy for a row the player picks by glance.
    "link": [
        "................",
        "...........1....",
        "...........11...",
        ".1111111111111..",
        ".1111111111111..",
        "...........11...",
        "...........1....",
        "................",
        "................",
        "....1...........",
        "...11...........",
        "..1111111111111.",
        "..1111111111111.",
        "...11...........",
        "....1...........",
        "................",
    ],
    # A puzzle piece: the mod manager.
    "mods": [
        "................",
        "...11111111.....",
        "...13333331.....",
        "...13333331.....",
        "...1333331111...",
        "...133333    1..".replace(" ", "3"),
        "...1333331111...",
        "...13333331.....",
        "...13333331.....",
        "..111111133 1...".replace(" ", "3"),
        "..1333333333 1..".replace(" ", "3"),
        "..1333333333 1..".replace(" ", "3"),
        "..111111133 1...".replace(" ", "3"),
        "...13333331.....",
        "...11111111.....",
        "................",
    ],
    # The fallback for a row injected by another mod: a blank app tile.
    "generic": [
        "................",
        "..111111111111..",
        "..133333333331..",
        "..133333333331..",
        "..133311133331..",
        "..133111113331..",
        "..133133313331..",
        "..133333313331..",
        "..133333133331..",
        "..133331333331..",
        "..133333333331..",
        "..133331333331..",
        "..133333333331..",
        "..133333333331..",
        "..111111111111..",
        "................",
    ],
}

# 4x6 face. Only the characters app captions and the footer need.
GLYPH_ORDER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.- :é"

GLYPHS = {
    "A": [".11.", "1..1", "1..1", "1111", "1..1", "...."],
    "B": ["111.", "1..1", "111.", "1..1", "111.", "...."],
    "C": [".111", "1...", "1...", "1...", ".111", "...."],
    "D": ["111.", "1..1", "1..1", "1..1", "111.", "...."],
    "E": ["1111", "1...", "111.", "1...", "1111", "...."],
    "F": ["1111", "1...", "111.", "1...", "1...", "...."],
    "G": [".111", "1...", "1.11", "1..1", ".111", "...."],
    "H": ["1..1", "1..1", "1111", "1..1", "1..1", "...."],
    "I": ["111.", ".1..", ".1..", ".1..", "111.", "...."],
    "J": ["..11", "...1", "...1", "1..1", ".11.", "...."],
    "K": ["1..1", "1.1.", "11..", "1.1.", "1..1", "...."],
    "L": ["1...", "1...", "1...", "1...", "1111", "...."],
    "M": ["1..1", "1111", "1111", "1..1", "1..1", "...."],
    "N": ["1..1", "11.1", "1111", "1.11", "1..1", "...."],
    "O": [".11.", "1..1", "1..1", "1..1", ".11.", "...."],
    "P": ["111.", "1..1", "111.", "1...", "1...", "...."],
    "Q": [".11.", "1..1", "1..1", "1.11", ".111", "...."],
    "R": ["111.", "1..1", "111.", "1.1.", "1..1", "...."],
    "S": [".111", "1...", ".11.", "...1", "111.", "...."],
    "T": ["111.", ".1..", ".1..", ".1..", ".1..", "...."],
    "U": ["1..1", "1..1", "1..1", "1..1", ".11.", "...."],
    "V": ["1..1", "1..1", "1..1", ".11.", ".11.", "...."],
    "W": ["1..1", "1..1", "1111", "1111", "1..1", "...."],
    "X": ["1..1", ".11.", ".11.", ".11.", "1..1", "...."],
    "Y": ["1..1", "1..1", ".11.", ".1..", ".1..", "...."],
    "Z": ["1111", "..1.", ".1..", "1...", "1111", "...."],
    "0": [".11.", "1..1", "1..1", "1..1", ".11.", "...."],
    "1": [".1..", "11..", ".1..", ".1..", "111.", "...."],
    "2": ["111.", "...1", ".11.", "1...", "1111", "...."],
    "3": ["111.", "...1", ".11.", "...1", "111.", "...."],
    "4": ["1..1", "1..1", "1111", "...1", "...1", "...."],
    "5": ["1111", "1...", "111.", "...1", "111.", "...."],
    "6": [".11.", "1...", "111.", "1..1", ".11.", "...."],
    "7": ["1111", "...1", "..1.", ".1..", ".1..", "...."],
    "8": [".11.", "1..1", ".11.", "1..1", ".11.", "...."],
    "9": [".11.", "1..1", ".111", "...1", ".11.", "...."],
    ".": ["....", "....", "....", "....", ".1..", "...."],
    "-": ["....", "....", "111.", "....", "....", "...."],
    " ": ["....", "....", "....", "....", "....", "...."],
    ":": ["....", ".1..", "....", ".1..", "....", "...."],
    # A real lowercase e with an acute accent, and a blank row between them
    # so the accent reads as an accent.  The earlier version stacked the
    # mark straight onto an E's top bar and the two merged into a blob.
    # Sitting shorter than the caps is correct: it is a lowercase letter,
    # and it shares their baseline on row 4.
    "é": ["...1", ".11.", "1111", "1...", ".111", "...."],
}


def blit(img, rows, ox, oy, palette):
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            colour = palette.get(ch)
            if colour and colour[3]:
                img.putpixel((ox + x, oy + y), colour)


def build_icons():
    sheet = Image.new("RGBA", (16 * len(ICON_ORDER), 16), (0, 0, 0, 0))
    for i, name in enumerate(ICON_ORDER):
        rows = ICONS[name]
        if len(rows) != 16 or any(len(r) != 16 for r in rows):
            raise SystemExit("icon %s is not 16x16" % name)
        blit(sheet, rows, i * 16, 0, PALETTE)
    sheet.save(os.path.join(OUT, "icons.png"))
    return sheet.size


def build_font():
    # White ink, not dark.  Drawing multiplies the sheet's RGB by the
    # colour the caller sets, so a dark sheet can only ever draw dark:
    # the clock was near black on a near black status bar.  White ink is
    # tintable to anything, which is the standard shape for a bitmap face.
    mono = {".": (0, 0, 0, 0), "1": (255, 255, 255, 255)}
    # 4px of ink plus a 1px gutter. At a 4px pitch every glyph touched its
    # neighbour and a caption read as one blob at native resolution.
    sheet = Image.new("RGBA", (5 * len(GLYPH_ORDER), 6), (0, 0, 0, 0))
    for i, ch in enumerate(GLYPH_ORDER):
        rows = GLYPHS[ch]
        if len(rows) != 6 or any(len(r) != 4 for r in rows):
            raise SystemExit("glyph %r is not 4x6" % ch)
        blit(sheet, rows, i * 5, 0, mono)
    sheet.save(os.path.join(OUT, "label_font.png"))
    return sheet.size


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    print("icons.png      %dx%d" % build_icons())
    print("label_font.png %dx%d" % build_font())
