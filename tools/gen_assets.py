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
    "7": (72, 112, 176, 255),   # link blue
    "8": (144, 192, 224, 255),  # screen blue
    "c": (104, 160, 88, 255),   # cartridge label green
    "a": (168, 112, 56, 255),   # bag leather
    "b": (104, 70, 36, 255),    # bag strap, the leather in shadow
}

ICON_ORDER = ["dex", "pkmn", "bag", "id", "optn", "save", "map", "link",
              "mods", "radio", "phone", "generic"]

# 16 rows of 16 characters each, per icon.
ICONS = {
    # A handheld dex: rounded body, screen, a red lamp.
    "dex": [
        "................",
        "...1111111111...",
        "..13333333331...",
        "..13111111131...",
        "..13188888131...",
        "..13188888131...",
        "..13188888131...",
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
    # A satchel: the flap is the leather in shadow so it separates from
    # the body without a hard line through the middle, and the bottom
    # corners are clipped so it reads as a bag rather than a case.
    "bag": [
        "................",
        "......1111......",
        ".....11..11.....",
        ".11111111111111.",
        ".1bbbbbbbbbbbb1.",
        ".1bbbbbbbbbbbb1.",
        ".1bbbbbbbbbbbb1.",
        ".11111111111111.",
        ".1aaaaa11aaaaa1.",
        ".1aaaaa11aaaaa1.",
        ".1aaaaaaaaaaaa1.",
        ".1aaaaaaaaaaaa1.",
        "..1aaaaaaaaaa1..",
        "..11aaaaaaaa11..",
        "...1111111111...",
        "................",
    ],
    # A trainer card: portrait block and text rules.
    "id": [
        "................",
        "..111111111111..",
        "..144444444441..",
        "..141111114441..",
        "..141888814441..",
        "..141888811111..",
        "..141888814441..",
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
        "...13cccccc31...",
        "...13cccccc31...",
        "...13cccccc31...",
        "...13cccccc31...",
        "...13cccccc31...",
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
        "...........7....",
        "...........77...",
        ".7777777777777..",
        ".7777777777777..",
        "...........77...",
        "...........7....",
        "................",
        "................",
        "....7...........",
        "...77...........",
        "..7777777777777.",
        "..7777777777777.",
        "...77...........",
        "....7...........",
        "................",
    ],
    # A plug: the mod manager.  A puzzle piece is the usual symbol for this
    # and it was the first thing drawn here, but its tabs need a narrow neck
    # opening into a wider head to read as tabs at all, and there is no room
    # for that profile in 16px next to a 1px outline -- every attempt came
    # out a rectangle with bumps.  A plug survives the size: two prongs and
    # a tapered body, and "plug-in" is the same idea anyway.
    "mods": [
        "................",
        "....11....11....",
        "....11....11....",
        "....11....11....",
        "..111111111111..",
        "..133333333331..",
        "..133333333331..",
        "..133333333331..",
        "..133333333331..",
        "...1333333331...",
        "....11111111....",
        "......1111......",
        "......1331......",
        "......1331......",
        ".......11.......",
        "................",
    ],
    # A radio set: speaker grille on the left, tuning dial on the right,
    # a power lamp, and an aerial off the top right corner.
    "radio": [
        "................",
        "..............1.",
        ".............1..",
        "............1...",
        "..1111111111111.",
        "..1444444444441.",
        "..1222244444441.",
        "..1222244334441.",
        "..1222244334441.",
        "..1222244444441.",
        "..1444444444441.",
        "..1444455444441.",
        "..1444444444441.",
        "..1111111111111.",
        "................",
        "................",
    ],
    # The call glyph a phone puts on its dial button: the handset tipped on
    # the diagonal, earpiece up at the left, mouthpiece down at the right,
    # both ends flaring off a pinched shaft.  Drawn as a thick quarter arc
    # rather than by hand, which is what keeps the two ends the same weight
    # and the inner curve smooth at this size.  The concave edge carries the
    # mid shadow, so the shape reads as a rounded body rather than a flat
    # boomerang.
    "phone": [
        "................",
        ".11111111.......",
        ".14444221.......",
        ".14444221.......",
        ".11444421.......",
        "..1444421.......",
        "..11444211......",
        "...114442111111.",
        "....11444222221.",
        ".....1144444221.",
        "......114444441.",
        ".......11444441.",
        "........1144441.",
        ".........111441.",
        "...........1111.",
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
