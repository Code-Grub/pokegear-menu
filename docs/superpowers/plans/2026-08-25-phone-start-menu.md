# Phone START Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Gen1Recomp START menu with a phone home screen: nine apps in a 3x3 grid drawn in true colour over the live overworld.

**Architecture:** The mod claims the `StartMenu` screen id through `mod.content.screens:register`, which `Screens.resolve` prefers over the builtin require. Because the builtin never runs, the mod rebuilds the vanilla item list itself and re-runs it through the `ui.start_menu.items` hook chain so other mods keep their injected rows. Drawing is split into pure-geometry (`Layout`), asset (`Icons`), chrome (`Chrome`) and orchestration (`PhoneScreen`) modules so each is testable alone.

**Tech Stack:** Lua 5.1 / LuaJIT, LOVE 11 graphics, Python 3 with Pillow for the asset generator, the repo's `tests/modkit` headless harness.

**Spec:** `docs/superpowers/specs/2026-08-25-phone-start-menu-design.md`

## Global Constraints

- Mod id is `phone_start_menu`; repo directory is `phone-start-menu`; junctioned to `game/mods/phone_start_menu`.
- Manifest: `api` 2, `profile` `content`, `category` `UI`, `priority` 100, `permissions` `["engine_internals"]`, `game_version` `">=0.0.0-0 <2.0.0"`.
- All engine paths in this plan are relative to the `game/` checkout. All mod paths are relative to `phone-start-menu/`.
- A mod cannot `require` its own files. Sibling modules load through `mod:read(name)` plus `load(source, "@" .. mod.path .. "/" .. name)`.
- No bare `error()` or `assert()` in mod callbacks. Every failure path uses `mod.log:warn` / `mod.log:error` and names a remediation.
- No ROM-derived bytes. Art ships as generator output only.
- No em-dashes and no AI attribution in any published file: README, CHANGELOG, mod.card, commit messages.
- Hook-visible labels are byte-identical to vanilla: `POKéDEX`, `POKéMON`, `ITEM`, the player's name, `SAVE`, `OPTION`, `LINK`, `MODS`. Grid captions live in a separate `display` field.
- Tests run from the `game/` directory: `luajit mods/phone_start_menu/tests/<name>.lua`.

---

### Task 1: Repo scaffold that loads clean

**Files:**
- Create: `manifest.json`, `main.lua`, `.modkitignore`, `LICENSE`
- Test: `tests/loads_test.lua`

**Interfaces:**
- Consumes: nothing.
- Produces: a loadable mod whose entry chunk is `return function(mod) ... end`. Later tasks add to this `main.lua`.

- [ ] **Step 1: Write the failing test**

Create `tests/loads_test.lua`:

```lua
-- Standalone: luajit mods/phone_start_menu/tests/loads_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Data = require("tests.modkit.fixtures").fresh()

local run = T.sdk.loadMod("mods/phone_start_menu", { data = Data })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")
run.release()

T.finish("phone_start_menu loads")
```

- [ ] **Step 2: Run test to verify it fails**

From the `game/` directory:

Run: `luajit mods/phone_start_menu/tests/loads_test.lua`
Expected: FAIL, the mod directory does not resolve so `loadMod` reports an error or `run.errors` is non-empty.

- [ ] **Step 3: Create the scaffold**

`manifest.json`:

```json
{
  "id": "phone_start_menu",
  "name": "Phone START Menu",
  "version": "0.1.0",
  "api": 2,
  "entry": "main.lua",
  "profile": "content",
  "category": "UI",
  "game_version": ">=0.0.0-0 <2.0.0",
  "priority": 100,
  "permissions": ["engine_internals"],
  "dependencies": [],
  "optional_dependencies": [],
  "conflicts": [],
  "description": "Replaces the START menu with a phone home screen: nine apps in a 3x3 grid over the overworld.",
  "github": "Code-Grub/phone-start-menu"
}
```

`main.lua`:

```lua
-- Replaces the START menu (src/ui/StartMenu.lua) with a phone home screen.
-- The screen id is claimed through the registry, so every push of
-- "StartMenu" resolves here instead of to the builtin.
--
-- A mod cannot require its own files, so sibling modules load through
-- mod:read + load, the same way example_jukebox loads its song.

return function(mod)
  local function sibling(name)
    local source = mod:read(name)
    if not source then
      mod.log:error("%s missing from %s -- reinstall the mod", name, mod.path)
      return nil
    end
    local chunk, compileErr = load(source, "@" .. mod.path .. "/" .. name)
    if not chunk then
      mod.log:error("%s did not compile: %s", name, tostring(compileErr))
      return nil
    end
    local ok, result = pcall(chunk)
    if not ok then
      mod.log:error("%s failed to load: %s", name, tostring(result))
      return nil
    end
    return result
  end

  -- siblings are wired in later tasks
  local _ = sibling
end
```

`.modkitignore`:

```
tests/
tools/
docs/
```

`LICENSE`: the MIT text, copyright holder `camwrightdc`, year 2026.

- [ ] **Step 4: Run test to verify it passes**

Run: `luajit mods/phone_start_menu/tests/loads_test.lua`
Expected: PASS, "loads clean".

- [ ] **Step 5: Create the junction so the running game sees the mod**

From `C:\Users\camwr\Desktop\Gen1Recomp`, in PowerShell:

```powershell
New-Item -ItemType Junction -Path game\mods\phone_start_menu -Target C:\Users\camwr\Desktop\Gen1Recomp\phone-start-menu
```

Verify: `Get-Item game\mods\phone_start_menu | Select-Object LinkType,Target` reports `Junction`.

- [ ] **Step 6: Commit**

```bash
git add manifest.json main.lua .modkitignore LICENSE tests/loads_test.lua
git commit -m "Scaffold the mod so it loads clean"
```

---

### Task 2: Layout geometry

**Files:**
- Create: `Layout.lua`
- Test: `tests/layout_test.lua`

**Interfaces:**
- Consumes: nothing. `Layout.lua` is pure arithmetic and must not call `love` or require any engine module, so it is testable with `dofile` alone.
- Produces:
  - `Layout.PHONE`, `Layout.SCREEN`, `Layout.STATUS`, `Layout.FOOTER`: tables `{ x, y, w, h }`.
  - `Layout.COLS = { 89, 110, 131 }`, `Layout.ROWS = { 28, 58, 88 }`.
  - `Layout.CELL_W = 21`, `Layout.ICON = 16`, `Layout.PER_PAGE = 9`, `Layout.DOTS_Y = 116`.
  - `Layout.cell(slot)` returns `x, y` for `slot` 1..9, the top-left of the icon.
  - `Layout.pageCount(n)` returns the number of pages for `n` items.
  - `Layout.locate(index)` returns `page, slot` for a 1-based item index.

- [ ] **Step 1: Write the failing test**

Create `tests/layout_test.lua`:

```lua
-- Standalone: luajit mods/phone_start_menu/tests/layout_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local L = dofile("mods/phone_start_menu/Layout.lua")

-- the phone sits on the right of the 160x144 canvas, clear of both edges
T.eq(L.PHONE.x, 84, "phone body starts at x 84")
T.eq(L.PHONE.x + L.PHONE.w, 158, "phone body ends 2px clear of the right edge")
T.check(L.PHONE.y + L.PHONE.h <= 144, "phone body fits the canvas height")

-- the bezel is symmetric: 5px of body either side of the inner screen
T.eq(L.SCREEN.x - L.PHONE.x, 5, "left bezel is 5px")
T.eq((L.PHONE.x + L.PHONE.w) - (L.SCREEN.x + L.SCREEN.w), 5, "right bezel is 5px")

-- three columns of 21px fill the 64px screen with 1px to spare
T.eq(#L.COLS, 3, "three columns")
T.eq(#L.ROWS, 3, "three rows")
T.eq(L.COLS[1], L.SCREEN.x, "first column is flush with the screen")
T.eq(L.COLS[3] + L.CELL_W, L.SCREEN.x + L.SCREEN.w - 1, "third column fits")

-- slot 1 is top-left, slot 9 bottom-right, and the icon centres in its cell
local x1, y1 = L.cell(1)
T.eq(x1, L.COLS[1] + math.floor((L.CELL_W - L.ICON) / 2), "slot 1 icon centres")
T.eq(y1, L.ROWS[1], "slot 1 sits on the first row")
local x9, y9 = L.cell(9)
T.eq(y9, L.ROWS[3], "slot 9 sits on the last row")
T.check(x9 > x1, "slot 9 is right of slot 1")

-- the last row's content clears the page dots
T.check(L.ROWS[3] + L.ICON + 2 + 6 <= L.DOTS_Y, "row 3 content clears the dots")
T.check(L.DOTS_Y < L.FOOTER.y, "the dots sit above the footer")

-- paging
T.eq(L.pageCount(0), 1, "an empty list still has one page")
T.eq(L.pageCount(9), 1, "nine apps are one page")
T.eq(L.pageCount(10), 2, "ten apps are two pages")
T.eq(L.pageCount(18), 2, "eighteen apps are two pages")
T.eq(L.pageCount(19), 3, "nineteen apps are three pages")

local page, slot = L.locate(1)
T.eq(page, 1, "item 1 is on page 1") T.eq(slot, 1, "item 1 is slot 1")
page, slot = L.locate(9)
T.eq(page, 1, "item 9 is on page 1") T.eq(slot, 9, "item 9 is slot 9")
page, slot = L.locate(10)
T.eq(page, 2, "item 10 is on page 2") T.eq(slot, 1, "item 10 is slot 1")

T.finish("layout")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `luajit mods/phone_start_menu/tests/layout_test.lua`
Expected: FAIL, `Layout.lua` does not exist so `dofile` raises.

- [ ] **Step 3: Write the implementation**

Create `Layout.lua`:

```lua
-- Pure geometry for the phone, in the 160x144 UI canvas.  No love calls and
-- no engine requires, so it can be dofile'd straight into a test.
--
-- The numbers are read off the reference mockup at its native 1x scale: the
-- mockup is a 3x upscale of the Game Boy canvas, so its pixels transfer
-- directly rather than being rescaled by eye.

local Layout = {}

Layout.PHONE  = { x = 84, y = 1,   w = 74, h = 142 }
Layout.SCREEN = { x = 89, y = 13,  w = 64, h = 112 }
Layout.STATUS = { x = 89, y = 13,  w = 64, h = 11 }
Layout.FOOTER = { x = 89, y = 125, w = 64, h = 12 }

Layout.COLS = { 89, 110, 131 }
Layout.ROWS = { 28, 58, 88 }

Layout.CELL_W  = 21
Layout.ICON    = 16
Layout.LABEL_H = 6
-- 2px of air between an icon and its caption
Layout.LABEL_GAP = 2
Layout.PER_PAGE = 9
Layout.DOTS_Y   = 116

-- top-left of the icon for a 1-based slot, reading left to right, top to
-- bottom.  The icon centres horizontally in its 21px cell; vertically it
-- sits on the row line, with the caption hanging below it.
function Layout.cell(slot)
  local i = slot - 1
  local col = Layout.COLS[(i % 3) + 1]
  local row = Layout.ROWS[math.floor(i / 3) + 1]
  return col + math.floor((Layout.CELL_W - Layout.ICON) / 2), row
end

-- where a caption baseline starts for a slot
function Layout.labelPos(slot)
  local x, y = Layout.cell(slot)
  return x, y + Layout.ICON + Layout.LABEL_GAP
end

-- an empty list still occupies one page, so the grid never renders "page 0"
function Layout.pageCount(n)
  if n <= 0 then return 1 end
  return math.ceil(n / Layout.PER_PAGE)
end

-- 1-based item index to its page and its slot within that page
function Layout.locate(index)
  local i = index - 1
  return math.floor(i / Layout.PER_PAGE) + 1, (i % Layout.PER_PAGE) + 1
end

return Layout
```

- [ ] **Step 4: Run test to verify it passes**

Run: `luajit mods/phone_start_menu/tests/layout_test.lua`
Expected: PASS, every assertion green.

- [ ] **Step 5: Commit**

```bash
git add Layout.lua tests/layout_test.lua
git commit -m "Add phone geometry measured off the mockup"
```

---

### Task 3: Asset generator and its output

**Files:**
- Create: `tools/gen_assets.py`, `assets/icons.png`, `assets/label_font.png`, `.gitattributes`
- Test: `tests/assets_test.lua`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `assets/icons.png`: 160x16 RGBA, ten 16x16 icons in one row. Index order is `dex, pkmn, bag, id, optn, save, map, link, mods, generic`.
  - `assets/label_font.png`: 4px of WHITE ink plus a 1px gutter per glyph (a 5px advance), 6px tall, one row. Glyph order is the string `ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.- :` (40 glyphs, note the colon the clock needs), so the sheet is 200x6. White so callers can tint it.
  - `python tools/gen_assets.py` regenerates both, writing into `assets/`.

- [ ] **Step 1: Write the failing test**

Create `tests/assets_test.lua`:

```lua
-- Standalone: luajit mods/phone_start_menu/tests/assets_test.lua
-- The love stub reads real PNG headers, so these assertions check the
-- generator's actual output rather than a stub default.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")

local icons = love.graphics.newImage("mods/phone_start_menu/assets/icons.png")
T.eq(icons:getWidth(), 160, "icon sheet is ten 16px icons wide")
T.eq(icons:getHeight(), 16, "icon sheet is one 16px row tall")

local font = love.graphics.newImage("mods/phone_start_menu/assets/label_font.png")
T.eq(font:getWidth(), 200, "label font is 40 glyphs at a 5px advance")
T.eq(font:getHeight(), 6, "label font is 6px tall")

T.finish("assets")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `luajit mods/phone_start_menu/tests/assets_test.lua`
Expected: FAIL, the PNGs do not exist so the stub reports its 8x8 default.

- [ ] **Step 3: Write the generator**

Create `tools/gen_assets.py`. Every icon is drawn from an explicit pixel map so the art is original by construction and reviewable as text. `.` is transparent, digits index the palette.

```python
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
        "..115555555511..",
        ".11555555555511.",
        ".15555555555551.",
        "1555555555555551",
        "1111111111111111",
        "1116666611666111",
        "1666661116666661",
        ".16666111166661.",
        ".11666666666611.",
        "..116666666611..",
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
    "save": [
        "................",
        "..11111111111...",
        "..13333333331...",
        "..13111111131...",
        "..13122222131...",
        "..13122222131...",
        "..13122222131...",
        "..13111111131...",
        "..13333333331...",
        "..13333333331...",
        "..13113113131...",
        "..13113113131...",
        "..13113113131...",
        "..13333333331...",
        "..11111111111...",
        "................",
    ],
    # A map pin over a ground mark.
    "map": [
        "................",
        ".....111111.....",
        "...11333333 1...".replace(" ", "1"),
        "..1333333333 1..".replace(" ", "3"),
        "..1331111133 1..".replace(" ", "3"),
        "..1311111113 1..".replace(" ", "3"),
        "..1311166113 1..".replace(" ", "3"),
        "..1311166113 1..".replace(" ", "3"),
        "..1331111133 1..".replace(" ", "3"),
        "..13333333331...",
        "...133333331....",
        "....1333331.....",
        ".....13331......",
        "......131.......",
        ".......1........",
        "................",
    ],
    # A link cable: two plugs joined by a lead.
    "link": [
        "................",
        "..1111..........",
        ".133331.........",
        ".133331.........",
        ".1333311........",
        ".13333331.......",
        "..111133331.....",
        ".....1333331....",
        "....13333311....",
        "...1333331......",
        "...1333311111...",
        "...13333333331..",
        "...13333333331..",
        "....111111111...",
        "................",
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
GLYPH_ORDER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.- :"

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
    ":": ["....", ".1..", "....", ".1..", "....", "...."],
    "-": ["....", "....", "111.", "....", "....", "...."],
    " ": ["....", "....", "....", "....", "....", "...."],
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
```

Note on the `.replace(" ", "N")` calls: they exist only to keep the pixel maps visually aligned in the source. Verify after generating that every icon row is exactly 16 characters; the generator raises if not.

`.gitattributes`:

```
assets/*.png binary
```

- [ ] **Step 4: Generate and run the test**

```bash
python -m pip install --quiet Pillow
python tools/gen_assets.py
```
Expected output: `icons.png 160x16` and `label_font.png 200x6`.

Run: `luajit mods/phone_start_menu/tests/assets_test.lua`
Expected: PASS, both dimension assertions green.

- [ ] **Step 5: Commit**

```bash
git add tools/gen_assets.py assets/icons.png assets/label_font.png .gitattributes tests/assets_test.lua
git commit -m "Generate the app icons and the 4x6 caption face"
```

---

### Task 4: Icon and caption drawing

**Files:**
- Create: `Icons.lua`
- Modify: `main.lua`
- Test: `tests/icons_test.lua`

**Interfaces:**
- Consumes: `Layout.ICON` from Task 2, the sheets from Task 3.
- Produces a module built by `Icons.new(mod)` returning a table with:
  - `Icons.INDEX`: map of key to 1-based sheet column, `{ dex = 1, pkmn = 2, bag = 3, id = 4, optn = 5, save = 6, map = 7, link = 8, mods = 9, generic = 10 }`.
  - `icons:drawIcon(key, x, y, dim)`: draws one 16x16 icon; `dim` true draws it at 40 percent alpha.
  - `icons:drawLabel(text, x, y, dim, colour)`: draws `text` in the 4x6 face, uppercased, unknown characters falling back to space. `colour` defaults to the dark ink; the status bar passes a light one.
  - `icons:labelWidth(text)`: returns `#text * 5` (a 5px advance per glyph).

Images load lazily on first draw, never at registration, so a headless load with no graphics context still succeeds.

- [ ] **Step 1: Write the failing test**

Create `tests/icons_test.lua`:

```lua
-- Standalone: luajit mods/phone_start_menu/tests/icons_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Icons = dofile("mods/phone_start_menu/Icons.lua")

-- a stand-in for the mod handle: only assets:image and log are touched
local warned = {}
local fakeMod = {
  path = "mods/phone_start_menu",
  assets = { image = function(_, rel)
    return love.graphics.newImage("mods/phone_start_menu/" .. rel)
  end },
  log = { warn = function(_, fmt, ...) warned[#warned + 1] = fmt end,
          error = function(_, fmt, ...) warned[#warned + 1] = fmt end },
}

local icons = Icons.new(fakeMod)

T.eq(Icons.INDEX.dex, 1, "dex is the first icon")
T.eq(Icons.INDEX.generic, 10, "generic is the last icon")

T.eq(icons:labelWidth("DEX"), 15, "three glyphs advance 15px")
T.eq(icons:labelWidth(""), 0, "an empty caption is 0px")

-- nothing may raise, with or without a loaded sheet
local ok, err = pcall(function() icons:drawIcon("dex", 0, 0, false) end)
T.check(ok, "drawing an icon succeeds: " .. tostring(err))
ok, err = pcall(function() icons:drawIcon("pkmn", 0, 0, true) end)
T.check(ok, "drawing a dimmed icon succeeds: " .. tostring(err))

-- an unknown key must fall back rather than index nil
ok, err = pcall(function() icons:drawIcon("nosuchapp", 0, 0, false) end)
T.check(ok, "an unknown icon key falls back: " .. tostring(err))

ok, err = pcall(function() icons:drawLabel("OPTN", 0, 0, false) end)
T.check(ok, "drawing a caption succeeds: " .. tostring(err))

-- lowercase and unknown characters must not raise
ok, err = pcall(function() icons:drawLabel("optn!", 0, 0, false) end)
T.check(ok, "a caption with odd characters succeeds: " .. tostring(err))

T.finish("icons")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `luajit mods/phone_start_menu/tests/icons_test.lua`
Expected: FAIL, `Icons.lua` does not exist.

- [ ] **Step 3: Write the implementation**

Create `Icons.lua`:

```lua
-- The two generated sheets and the drawing that reads them.
--
-- Both images load on first draw rather than at registration: the loader's
-- assets:image asserts on a graphics context (src/mods/Loader.lua:733), and
-- a headless load has none.  Deferring keeps `modkit validate` green.

local Icons = {}
Icons.__index = Icons

local ICON = 16
-- 4px of ink plus a 1px gutter.  The gutter is why the advance is 5 and
-- not 4: at a 4px advance adjacent glyphs touch and a caption is a blob.
-- Four glyphs at 5px is 20px, which fits the 21px cell; that is the cap
-- Items.decorate clips foreign captions to.
local GLYPH_INK, GLYPH_ADV, GLYPH_H = 4, 5, 6
local GLYPH_ORDER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.- :"
-- the face is white on the sheet so it can be tinted; this is the
-- default ink for anything drawn on the phone's pale surfaces
local INK = { 0.14, 0.18, 0.18 }

Icons.INDEX = {
  dex = 1, pkmn = 2, bag = 3, id = 4, optn = 5,
  save = 6, map = 7, link = 8, mods = 9, generic = 10,
}

-- character to 0-based column in label_font.png
local GLYPH_AT = {}
for i = 1, #GLYPH_ORDER do
  GLYPH_AT[GLYPH_ORDER:sub(i, i)] = i - 1
end

function Icons.new(mod)
  return setmetatable({ mod = mod, failed = false }, Icons)
end

-- Load once, remember a failure so a missing sheet warns a single time
-- rather than once per frame.
function Icons:_sheets()
  if self.failed then return nil end
  if self.iconSheet and self.fontSheet then
    return self.iconSheet, self.fontSheet
  end
  local ok, iconSheet, fontSheet = pcall(function()
    return self.mod.assets:image("assets/icons.png"),
           self.mod.assets:image("assets/label_font.png")
  end)
  if not ok or not iconSheet or not fontSheet then
    self.failed = true
    self.mod.log:warn("could not load assets/icons.png or "
      .. "assets/label_font.png -- reinstall the mod; the phone draws "
      .. "without art this session")
    return nil
  end
  self.iconSheet, self.fontSheet = iconSheet, fontSheet
  self.iconQuads = {}
  for _, col in pairs(Icons.INDEX) do
    self.iconQuads[col] = love.graphics.newQuad(
      (col - 1) * ICON, 0, ICON, ICON,
      iconSheet:getWidth(), iconSheet:getHeight())
  end
  self.glyphQuads = {}
  for ch, col in pairs(GLYPH_AT) do
    self.glyphQuads[ch] = love.graphics.newQuad(
      col * GLYPH_ADV, 0, GLYPH_ADV, GLYPH_H,
      fontSheet:getWidth(), fontSheet:getHeight())
  end
  return self.iconSheet, self.fontSheet
end

function Icons:drawIcon(key, x, y, dim)
  local sheet = self:_sheets()
  if not sheet then return end
  local col = Icons.INDEX[key] or Icons.INDEX.generic
  local quad = self.iconQuads[col]
  if not quad then return end
  local r, g, b, a = love.graphics.getColor()
  love.graphics.setColor(1, 1, 1, dim and 0.4 or 1)
  love.graphics.draw(sheet, quad, x, y)
  love.graphics.setColor(r, g, b, a)
end

function Icons:labelWidth(text)
  return #tostring(text or "") * GLYPH_ADV
end

-- colour is optional and defaults to the dark ink.  The status bar passes
-- a light colour because it draws onto black; nothing else needs to.
function Icons:drawLabel(text, x, y, dim, colour)
  local _, font = self:_sheets()
  if not font then return end
  local r, g, b, a = love.graphics.getColor()
  local c = colour or INK
  love.graphics.setColor(c[1], c[2], c[3], dim and 0.4 or 1)
  local upper = tostring(text or ""):upper()
  for i = 1, #upper do
    local quad = self.glyphQuads[upper:sub(i, i)] or self.glyphQuads[" "]
    if quad then
      love.graphics.draw(font, quad, x + (i - 1) * GLYPH_ADV, y)
    end
  end
  love.graphics.setColor(r, g, b, a)
end

return Icons
```

- [ ] **Step 4: Wire it into main.lua**

In `main.lua`, replace `local _ = sibling` with:

```lua
  local Icons = sibling("Icons.lua")
  local Layout = sibling("Layout.lua")
  if not (Icons and Layout) then return end

  local icons = Icons.new(mod)
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `luajit mods/phone_start_menu/tests/icons_test.lua`
Expected: PASS.

Run: `luajit mods/phone_start_menu/tests/loads_test.lua`
Expected: PASS, still loading clean with the siblings wired.

- [ ] **Step 6: Commit**

```bash
git add Icons.lua main.lua tests/icons_test.lua
git commit -m "Draw app icons and captions from the generated sheets"
```

---

### Task 5: The nine app definitions

**Files:**
- Create: `Apps.lua`
- Test: `tests/apps_test.lua`

**Interfaces:**
- Consumes: nothing engine-side beyond `game.save`.
- Produces:
  - `Apps.DEFS`: an ordered array of nine tables, each `{ key, display, label(game), gate(game), open(game, reopen) }`. `label` returns the hook-visible vanilla label; `display` is the grid caption.
  - `Apps.build(game, deps)` returns an array of item tables
    `{ label = <vanilla label>, display = <caption>, icon = <key>, enabled = <boolean>, onSelect = <function> }`, one per definition, in `Apps.DEFS` order.
  - `deps` is `{ screens = <module>, sound = <module>, save = <function> }`; injected so the test can pass stand-ins instead of driving the real stack. `deps.save` is the SAVE flow from Task 9; until then pass a no-op.

- [ ] **Step 1: Write the failing test**

Create `tests/apps_test.lua`:

```lua
-- Standalone: luajit mods/phone_start_menu/tests/apps_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Apps = dofile("mods/phone_start_menu/Apps.lua")

local pushed = {}
local deps = {
  screens = { push = function(_, id) pushed[#pushed + 1] = id end },
  sound = { play = function() end },
  save = function() end,
}

local function gameWith(overrides)
  local g = {
    save = { party = {}, flags = {}, inventory = {},
             player = { name = "RED" } },
    data = {},
    stack = { push = function() end, pop = function() end },
    modStatus = nil,
  }
  for k, v in pairs(overrides or {}) do g.save[k] = v end
  return g
end

local function byKey(items, key)
  for _, item in ipairs(items) do
    if item.icon == key then return item end
  end
end

-- a brand new save: the always-on apps are live, the gated ones are not
local items = Apps.build(gameWith(), deps)
T.eq(#items, 9, "nine apps, always")

T.check(byKey(items, "bag").enabled, "ITEM is always available")
T.check(byKey(items, "id").enabled, "the trainer card is always available")
T.check(byKey(items, "optn").enabled, "OPTION is always available")
T.check(byKey(items, "save").enabled, "SAVE is always available")

T.check(not byKey(items, "dex").enabled, "the dex is dimmed before Oak's gift")
T.check(not byKey(items, "pkmn").enabled, "POKéMON is dimmed with no party")
T.check(not byKey(items, "map").enabled, "the map is dimmed without the item")
T.check(not byKey(items, "link").enabled, "LINK is dimmed with no party")
T.check(not byKey(items, "mods").enabled, "MODS is dimmed with no mods")

-- hook-visible labels are exactly vanilla's, so insertBefore anchors resolve
T.eq(byKey(items, "bag").label, "ITEM", "the bag row is labelled ITEM")
T.eq(byKey(items, "save").label, "SAVE", "the save row is labelled SAVE")
T.eq(byKey(items, "optn").label, "OPTION", "the options row is labelled OPTION")
T.eq(byKey(items, "id").label, "RED", "the id row carries the player's name")

-- captions are separate from hook labels and fit five glyphs
for _, item in ipairs(items) do
  T.check(#item.display <= 3,
    "caption '" .. item.display .. "' leaves a readable gap to its neighbour")
end

-- each gate flips independently
items = Apps.build(gameWith({ flags = { EVENT_GOT_POKEDEX = true } }), deps)
T.check(byKey(items, "dex").enabled, "the dex lights up after Oak's gift")

items = Apps.build(gameWith({ party = { { species = "FIXMON_A" } } }), deps)
T.check(byKey(items, "pkmn").enabled, "POKéMON lights up with a party")
T.check(byKey(items, "link").enabled, "LINK lights up with a party")

items = Apps.build(gameWith({ inventory = { TOWN_MAP = 1 } }), deps)
T.check(byKey(items, "map").enabled, "the map lights up holding the TOWN MAP")

local g = gameWith()
g.modStatus = { available = { "some_mod" } }
items = Apps.build(g, deps)
T.check(byKey(items, "mods").enabled, "MODS lights up with a mod discovered")

-- selecting a live app reaches its screen; a dimmed one must not
pushed = {}
items = Apps.build(gameWith({ flags = { EVENT_GOT_POKEDEX = true } }), deps)
byKey(items, "dex").onSelect()
T.eq(pushed[1], "PokedexMenu", "the dex app opens the dex")

pushed = {}
items = Apps.build(gameWith(), deps)
byKey(items, "dex").onSelect()
T.eq(#pushed, 0, "a dimmed app opens nothing")

T.finish("apps")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `luajit mods/phone_start_menu/tests/apps_test.lua`
Expected: FAIL, `Apps.lua` does not exist.

- [ ] **Step 3: Write the implementation**

Create `Apps.lua`:

```lua
-- The nine apps: what gates each one, and what it opens.
--
-- `label` is the hook-visible text and is byte-identical to vanilla
-- (src/ui/StartMenu.lua), because another mod may anchor an insertion to it
-- with mod.ui.insertBefore(out, "SAVE", ...).  `display` is the grid
-- caption, capped at five glyphs by the 21px cell.
--
-- Engine access arrives through `deps` rather than a require, so a test can
-- drive the gates without a real screen stack.

local Apps = {}

local function partySize(game)
  return #((game.save and game.save.party) or {})
end

Apps.DEFS = {
  { key = "dex", display = "DEX",
    label = function() return "POKéDEX" end,
    gate = function(game)
      return ((game.save or {}).flags or {}).EVENT_GOT_POKEDEX and true or false
    end,
    open = function(game, reopen, deps)
      deps.screens.push(game, "PokedexMenu", { onCancel = reopen })
    end },

  { key = "pkmn", display = "PKM",
    label = function() return "POKéMON" end,
    gate = function(game) return partySize(game) > 0 end,
    open = function(game, reopen, deps)
      deps.screens.push(game, "PartyMenu", { onCancel = reopen })
    end },

  { key = "bag", display = "BAG",
    label = function() return "ITEM" end,
    gate = function() return true end,
    open = function(game, reopen, deps)
      deps.screens.push(game, "BagMenu", { onCancel = reopen })
    end },

  { key = "id", display = "ID",
    label = function(game)
      return ((game.save or {}).player or {}).name or "RED"
    end,
    gate = function() return true end,
    open = function(game, reopen, deps)
      deps.screens.push(game, "TrainerCard", { onCancel = reopen })
    end },

  { key = "optn", display = "OPT",
    label = function() return "OPTION" end,
    gate = function() return true end,
    open = function(game, reopen, deps)
      deps.screens.push(game, "OptionsMenu", { onCancel = reopen })
    end },

  { key = "save", display = "SAV",
    label = function() return "SAVE" end,
    gate = function() return true end,
    open = function(game, _, deps) deps.save(game) end },

  -- Vanilla reaches the TOWN MAP by using the item (src/ui/BagMenu.lua:196).
  -- The app is a second door behind the same rule, so nothing becomes
  -- reachable that was not reachable before.
  { key = "map", display = "MAP",
    label = function() return "TOWN MAP" end,
    gate = function(game)
      return ((game.save or {}).inventory or {}).TOWN_MAP ~= nil
    end,
    open = function(game, reopen, deps)
      deps.screens.push(game, "TownMap", { onCancel = reopen })
    end },

  { key = "link", display = "LNK",
    label = function() return "LINK" end,
    gate = function(game) return partySize(game) > 0 end,
    open = function(game, _, deps) deps.link(game) end },

  { key = "mods", display = "MOD",
    label = function() return "MODS" end,
    gate = function(game)
      local status = game.modStatus
      return (status and #(status.available or {}) > 0) or false
    end,
    open = function(game, reopen, deps)
      deps.screens.push(game, "ManagerState", { onCancel = reopen })
    end },
}

-- reopen: pushed back onto the stack when a submenu cancels, mirroring
-- vanilla's `reopen` at src/ui/StartMenu.lua:24
function Apps.build(game, deps, reopen)
  local items = {}
  for _, def in ipairs(Apps.DEFS) do
    local enabled = def.gate(game) and true or false
    items[#items + 1] = {
      label = def.label(game),
      display = def.display,
      icon = def.key,
      enabled = enabled,
      onSelect = function()
        if not enabled then return end
        def.open(game, reopen, deps)
      end,
    }
  end
  return items
end

return Apps
```

Add a `link` entry to the `deps` table in the test alongside `save`:

```lua
  link = function() end,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `luajit mods/phone_start_menu/tests/apps_test.lua`
Expected: PASS, every gate assertion green.

- [ ] **Step 5: Commit**

```bash
git add Apps.lua tests/apps_test.lua
git commit -m "Define the nine apps and their availability gates"
```

---

### Task 6: Re-run the items hook

This is the task that keeps every other UI mod working. Review it hardest.

**Files:**
- Create: `Items.lua`, `tests/fixtures/injector_mod/manifest.json`, `tests/fixtures/injector_mod/main.lua`
- Test: `tests/items_test.lua`

**Interfaces:**
- Consumes: `Apps.build` from Task 5.
- Produces:
  - `Items.compose(game, apps, runtime)` returns the final item array. It calls `runtime.call("ui.start_menu.items", passthrough, game, apps)` and validates the result, falling back to `apps` if a wrapper returns a non-table.
  - Items arriving from the hook that the mod did not create carry no `display` or `icon`; `Items.decorate(items)` fills `display` from the first five characters of `label` and `icon` with `"generic"`.

- [ ] **Step 1: Write the failing test**

Create the fixture mod first.

`tests/fixtures/injector_mod/manifest.json`:

```json
{
  "id": "phone_test_injector",
  "name": "Phone Test Injector",
  "version": "1.0.0",
  "api": 2,
  "entry": "main.lua",
  "profile": "content",
  "category": "TOOL",
  "game_version": ">=0.0.0-0 <2.0.0",
  "priority": 10,
  "dependencies": [],
  "description": "Test fixture: injects a START menu row the way a real mod would."
}
```

`tests/fixtures/injector_mod/main.lua`:

```lua
-- Test fixture only.  Injects a row exactly the way example_dexnav does
-- (mods/examples/example_dexnav/main.lua:88-95): call next() first, then
-- decorate the list it returns, anchoring on the vanilla SAVE label.
return function(mod)
  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    local out = next(game, items)
    if type(out) ~= "table" then return out end
    return mod.ui.insertBefore(out, "SAVE", {
      label = "INJECTED",
      onSelect = function() end,
    })
  end)
end
```

Create `tests/items_test.lua`:

```lua
-- Standalone: luajit mods/phone_start_menu/tests/items_test.lua
--
-- The regression this file exists for: claiming the StartMenu id stops the
-- builtin from running, and with it the ui.start_menu.items call at
-- src/ui/StartMenu.lua:130.  If the phone does not re-run that hook itself,
-- every other mod's injected row vanishes silently.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Items = dofile("mods/phone_start_menu/Items.lua")
local Apps = dofile("mods/phone_start_menu/Apps.lua")

local deps = {
  screens = { push = function() end },
  sound = { play = function() end },
  save = function() end,
  link = function() end,
}

local function newGame()
  return { save = { party = {}, flags = {}, inventory = {},
                    player = { name = "RED" } },
           data = {}, stack = { push = function() end, pop = function() end } }
end

-- ---- with no other mod loaded, the list passes through unchanged
local Data = require("tests.modkit.fixtures").fresh()
local run = T.sdk.loadMod("mods/phone_start_menu", { data = Data })
T.eq(#run.errors, 0, "the phone loads clean (" .. tostring(run.errors[1]) .. ")")

local Runtime = require("src.mods.Runtime")
local game = newGame()
local composed = Items.compose(game, Apps.build(game, deps), Runtime)
T.eq(#composed, 9, "nine apps with no other mod loaded")
run.release()

-- ---- with an injector loaded, its row survives
Data = require("tests.modkit.fixtures").fresh()
run = T.sdk.loadMods({ "mods/phone_start_menu",
                       "mods/phone_start_menu/tests/fixtures/injector_mod" },
                     { data = Data })
T.eq(#run.errors, 0, "both mods load clean (" .. tostring(run.errors[1]) .. ")")

game = newGame()
local apps = Apps.build(game, deps)

-- the list handed to the hook must carry vanilla's labels, or the
-- injector's insertBefore("SAVE", ...) anchor will not resolve
local labels = {}
for _, item in ipairs(apps) do labels[item.label] = true end
T.check(labels["SAVE"], "the hook sees a row labelled exactly SAVE")
T.check(labels["OPTION"], "the hook sees a row labelled exactly OPTION")
T.check(labels["ITEM"], "the hook sees a row labelled exactly ITEM")

composed = Items.compose(game, apps, Runtime)
T.eq(#composed, 10, "the injected row survives")

local found, position
for i, item in ipairs(composed) do
  if item.label == "INJECTED" then found, position = item, i end
end
T.check(found, "the injected row is present by label")

-- and it landed where the injector asked: immediately before SAVE
local saveAt
for i, item in ipairs(composed) do
  if item.label == "SAVE" then saveAt = i end
end
T.eq(position, saveAt - 1, "the injected row landed before SAVE")

-- a foreign row must be renderable: it needs a caption and an icon.
-- Guarded: without the `if`, a regression that loses the row entirely
-- crashes here on a nil index, which aborts the suite before the fallback
-- cases below ever run and lets one regression hide another.
if found then
  T.check(found.icon == "generic", "a foreign row gets the generic icon")
  T.check(found.display and #found.display > 0, "a foreign row gets a caption")
  T.check(#found.display <= 3, "a foreign caption is truncated to the cell")
  T.check(found.enabled, "a foreign row is selectable")
end

run.release()

-- ---- a wrapper returning junk must not take the menu down, and must say so
local composedFromJunk, junkWhy = Items.compose(newGame(),
  Apps.build(newGame(), deps), { call = function() return "not a table" end })
T.eq(#composedFromJunk, 9, "a bad hook result falls back to the app list")
T.check(junkWhy and junkWhy:find("not a table"),
  "and reports why, so the screen can log it: " .. tostring(junkWhy))

-- ---- a chain that THROWS is the pcall's real justification.  Hooks.lua
-- already absorbs an ordinary throwing wrapper, so without this case the
-- pcall could be deleted and every other check would stay green.
local composedFromThrow, throwWhy = Items.compose(newGame(),
  Apps.build(newGame(), deps), { call = function() error("boom", 0) end })
T.eq(#composedFromThrow, 9, "a throwing hook chain falls back to the app list")
T.check(throwWhy and throwWhy:find("threw"),
  "and reports that it threw: " .. tostring(throwWhy))

T.finish("items")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `luajit mods/phone_start_menu/tests/items_test.lua`
Expected: FAIL, `Items.lua` does not exist.

- [ ] **Step 3: Write the implementation**

Create `Items.lua`:

```lua
-- Composing the final row list.
--
-- Claiming the StartMenu screen id means the builtin StartMenu.new never
-- runs, and with it the Runtime.call("ui.start_menu.items", ...) at
-- src/ui/StartMenu.lua:130.  Every row another mod injected would disappear
-- with no error.  So the phone re-runs that hook itself, over a list whose
-- labels are byte-identical to vanilla's.

local Items = {}

-- Three glyphs at a 5px advance is 15px in a 21px cell, a 6px gap to the
-- neighbouring caption.  Four filled the cell and adjacent captions read
-- as one word: OPTNSAVE, LINKMODS.
local MAX_CAPTION = 3

-- the vanilla identity link: with no wrapper installed, the list is returned
-- exactly as it was handed in
local function passthrough(_, items) return items end

-- A row that came from another mod carries only { label, onSelect }.  Give
-- it what the grid needs to draw: a caption clipped to the cell, the
-- fallback icon, and selectability.
function Items.decorate(items)
  for _, item in ipairs(items) do
    if item.display == nil then
      item.display = tostring(item.label or "?"):sub(1, MAX_CAPTION)
    end
    if item.icon == nil then item.icon = "generic" end
    if item.enabled == nil then item.enabled = true end
  end
  return items
end

-- runtime is injected so a test can pass a stand-in; in the mod it is
-- src.mods.Runtime, reached under the engine_internals permission.
--
-- Returns the composed list, plus a reason string when the hook failed to
-- produce a usable one.  The caller owns the logging: this module has no
-- mod.log, and the builtin reports the same condition
-- (src/ui/StartMenu.lua:131-135), so returning no signal at all would be a
-- diagnosability regression against vanilla rather than a style choice.
function Items.compose(game, apps, runtime)
  local ok, result = pcall(runtime.call, "ui.start_menu.items",
                           passthrough, game, apps)
  if not ok then
    return Items.decorate(apps),
      ("the ui.start_menu.items chain threw (%s)"):format(tostring(result))
  end
  if type(result) ~= "table" then
    return Items.decorate(apps),
      ("ui.start_menu.items returned %s, not a table"):format(type(result))
  end
  return Items.decorate(result)
end

return Items
```

`src/ui/StartMenu.lua:131-135` logs when the hook returns a non-table. `Items` has no `mod.log`, so it does not log; it returns the reason as a second value instead, and Task 8 logs it from the screen, which does have one. Returning the list alone would leave Task 8 nothing to log on.

- [ ] **Step 4: Run test to verify it passes**

Run: `luajit mods/phone_start_menu/tests/items_test.lua`
Expected: PASS, including "the injected row survives" and "the injected row landed before SAVE".

- [ ] **Step 5: Commit**

```bash
git add Items.lua tests/items_test.lua tests/fixtures/injector_mod/
git commit -m "Re-run the start menu items hook so injected rows survive"
```

---

### Task 7: Phone chrome

**Files:**
- Create: `Chrome.lua`
- Test: `tests/chrome_test.lua`

**Interfaces:**
- Consumes: `Layout` from Task 2, `Icons` from Task 4.
- Produces `Chrome.new(layout, icons)` returning a table with:
  - `chrome:drawBody()`: the cream bezel with its darker outline.
  - `chrome:drawStatus(game)`: black bar with the clock, the wifi glyph and the battery.
  - `chrome:drawFooter()`: the "PHONE" plate.
  - `chrome:drawDots(page, pages)`: page dots, drawn only when `pages > 1`.
  - `Chrome.clockText(now)`: `now` is an `os.date("*t")`-shaped table; returns `H:MM` in 12-hour form with no leading zero. Pure, so it is tested directly.
  - `Chrome.linkLive(game)`: the wifi test, `game.linkSession or (game.linkNet and not game.linkNet.closed)`, coerced to a boolean.

- [ ] **Step 1: Write the failing test**

Create `tests/chrome_test.lua`:

```lua
-- Standalone: luajit mods/phone_start_menu/tests/chrome_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Chrome = dofile("mods/phone_start_menu/Chrome.lua")
local Layout = dofile("mods/phone_start_menu/Layout.lua")
local Icons = dofile("mods/phone_start_menu/Icons.lua")

-- clock formatting is pure, so assert it directly
T.eq(Chrome.clockText({ hour = 0,  min = 0 }),  "12:00", "midnight reads 12:00")
T.eq(Chrome.clockText({ hour = 12, min = 0 }),  "12:00", "noon reads 12:00")
T.eq(Chrome.clockText({ hour = 13, min = 5 }),  "1:05",  "13:05 reads 1:05")
T.eq(Chrome.clockText({ hour = 9,  min = 47 }), "9:47",  "no leading zero on the hour")
T.eq(Chrome.clockText(nil), "12:00", "an unreadable clock falls back")

-- the link test mirrors src/core/Game.lua:232
T.check(not Chrome.linkLive({}), "no link session reads as offline")
T.check(Chrome.linkLive({ linkSession = {} }), "a link session reads as online")
T.check(Chrome.linkLive({ linkNet = { closed = false } }),
  "an open link socket reads as online")
T.check(not Chrome.linkLive({ linkNet = { closed = true } }),
  "a closed link socket reads as offline")

-- drawing must never raise, with or without art
local fakeMod = {
  path = "mods/phone_start_menu",
  assets = { image = function(_, rel)
    return love.graphics.newImage("mods/phone_start_menu/" .. rel)
  end },
  log = { warn = function() end, error = function() end },
}
local chrome = Chrome.new(Layout, Icons.new(fakeMod))

local ok, err = pcall(function() chrome:drawBody() end)
T.check(ok, "drawing the body succeeds: " .. tostring(err))

ok, err = pcall(function() chrome:drawStatus({}) end)
T.check(ok, "drawing the status bar succeeds: " .. tostring(err))

ok, err = pcall(function() chrome:drawStatus({ linkSession = {} }) end)
T.check(ok, "drawing an online status bar succeeds: " .. tostring(err))

ok, err = pcall(function() chrome:drawFooter() end)
T.check(ok, "drawing the footer succeeds: " .. tostring(err))

ok, err = pcall(function() chrome:drawDots(1, 1) end)
T.check(ok, "drawing one page of dots succeeds: " .. tostring(err))

ok, err = pcall(function() chrome:drawDots(2, 3) end)
T.check(ok, "drawing three pages of dots succeeds: " .. tostring(err))

-- Colour restoration is genuinely assertable: love_stub tracks real
-- setColor/getColor state even though its rectangle/draw are no-ops.
-- Without this, a leak is invisible to the suite.
local function leaks(fn)
  love.graphics.setColor(0.25, 0.5, 0.75, 1)
  fn()
  local r, g, b, a = love.graphics.getColor()
  return not (r == 0.25 and g == 0.5 and b == 0.75 and a == 1)
end

T.check(not leaks(function() chrome:drawBody() end),
  "drawBody restores the colour it found")
T.check(not leaks(function() chrome:drawStatus({}) end),
  "drawStatus restores the colour it found")
T.check(not leaks(function() chrome:drawFooter() end),
  "drawFooter restores the colour it found")
T.check(not leaks(function() chrome:drawDots(2, 3) end),
  "drawDots restores the colour it found")
T.check(not leaks(function() chrome:drawDots(1, 1) end),
  "drawDots restores the colour on its early return")

T.finish("chrome")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `luajit mods/phone_start_menu/tests/chrome_test.lua`
Expected: FAIL, `Chrome.lua` does not exist.

- [ ] **Step 3: Write the implementation**

Create `Chrome.lua`:

```lua
-- The phone itself: bezel, status bar, footer plate, page dots.
--
-- Colours are the mockup's, written as literals rather than pulled from a
-- palette record, because the whole phone rect is re-blit unshaded through
-- PaletteFX.markTrueColor and so never passes through the shade remap.

local Chrome = {}
Chrome.__index = Chrome

local BODY    = { 0.83, 0.80, 0.68 }
local BODY_HI = { 0.93, 0.91, 0.82 }
local OUTLINE = { 0.14, 0.18, 0.18 }
local SCREEN  = { 0.94, 0.95, 0.90 }
local BAR     = { 0.11, 0.14, 0.14 }
local BAR_INK = { 0.90, 0.92, 0.88 }
local DOT_ON  = { 0.20, 0.26, 0.26 }
local DOT_OFF = { 0.62, 0.66, 0.60 }

local function rect(colour, x, y, w, h)
  love.graphics.setColor(colour[1], colour[2], colour[3], 1)
  love.graphics.rectangle("fill", x, y, w, h)
end

function Chrome.new(layout, icons)
  return setmetatable({ L = layout, icons = icons }, Chrome)
end

-- 12-hour clock, no leading zero, matching the mockup's "12:00".
-- A nil or malformed table falls back rather than raising: the START menu
-- is the only route to SAVE and must always open.
function Chrome.clockText(now)
  if type(now) ~= "table" or type(now.hour) ~= "number"
     or type(now.min) ~= "number" then
    return "12:00"
  end
  local hour = now.hour % 12
  if hour == 0 then hour = 12 end
  return ("%d:%02d"):format(hour, now.min % 60)
end

-- the same test the engine uses at src/core/Game.lua:232
function Chrome.linkLive(game)
  if type(game) ~= "table" then return false end
  if game.linkSession then return true end
  local net = game.linkNet
  return (net ~= nil and not net.closed) and true or false
end

-- Every public draw brackets itself with the colour it found, the way
-- Icons.lua does.  The engine fences a mod's whole render callback in
-- push("all")/pop(), so a leak here cannot reach the engine, but it can
-- reach whatever this mod draws next inside the same callback.
function Chrome:drawBody()
  local cr, cg, cb, ca = love.graphics.getColor()
  local P, S = self.L.PHONE, self.L.SCREEN
  rect(OUTLINE, P.x, P.y, P.w, P.h)
  rect(BODY, P.x + 1, P.y + 1, P.w - 2, P.h - 2)
  -- a one-pixel highlight down the left edge gives the body its moulding
  rect(BODY_HI, P.x + 1, P.y + 1, 1, P.h - 2)
  -- earpiece slot and lens, above the screen
  rect(OUTLINE, P.x + 24, P.y + 5, 18, 2)
  rect(OUTLINE, P.x + 62, P.y + 4, 4, 4)
  rect(OUTLINE, S.x - 1, S.y - 1, S.w + 2, S.h + 2)
  rect(SCREEN, S.x, S.y, S.w, S.h)
  love.graphics.setColor(cr, cg, cb, ca)
end

function Chrome:drawStatus(game)
  local cr, cg, cb, ca = love.graphics.getColor()
  local B = self.L.STATUS
  rect(BAR, B.x, B.y, B.w, B.h)
  local okTime, now = pcall(os.date, "*t")
  -- light ink: the bar is near black, and the face is white on the sheet
  -- so it tints to whatever is asked for
  self.icons:drawLabel(Chrome.clockText(okTime and now or nil),
                       B.x + 3, B.y + 3, false, BAR_INK)

  -- wifi: three rising bars, hollow when there is no link session
  local live = Chrome.linkLive(game)
  local wx = B.x + B.w - 22
  for i = 1, 3 do
    local h = i * 2
    local colour = live and BAR_INK or DOT_OFF
    rect(colour, wx + (i - 1) * 3, B.y + 8 - h, 2, h)
  end

  -- battery: always full, decorative
  -- a solid cell plus a terminal nub.  Always full, so there is no
  -- separate hollow and fill: painting one inside the other would draw
  -- ink over ink.
  local bx = B.x + B.w - 11
  rect(BAR_INK, bx, B.y + 3, 8, 5)
  rect(BAR_INK, bx + 8, B.y + 4, 1, 3)
  love.graphics.setColor(cr, cg, cb, ca)
end

function Chrome:drawFooter()
  local cr, cg, cb, ca = love.graphics.getColor()
  local F = self.L.FOOTER
  rect(OUTLINE, F.x, F.y, F.w, F.h)
  rect(BODY, F.x + 1, F.y + 1, F.w - 2, F.h - 2)
  local text = "PHONE"
  local x = F.x + math.floor((F.w - self.icons:labelWidth(text)) / 2)
  self.icons:drawLabel(text, x, F.y + 3, false)
  love.graphics.setColor(cr, cg, cb, ca)
end

-- Dots render only when there is more than one page, so an install with no
-- other UI mods matches the mockup exactly.
function Chrome:drawDots(page, pages)
  if (pages or 1) <= 1 then return end
  local cr, cg, cb, ca = love.graphics.getColor()
  local S = self.L.SCREEN
  local span = pages * 5 - 2
  local x = S.x + math.floor((S.w - span) / 2)
  for i = 1, pages do
    rect(i == page and DOT_ON or DOT_OFF, x + (i - 1) * 5, self.L.DOTS_Y, 3, 3)
  end
  love.graphics.setColor(cr, cg, cb, ca)
end

return Chrome
```

- [ ] **Step 4: Run test to verify it passes**

Run: `luajit mods/phone_start_menu/tests/chrome_test.lua`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Chrome.lua tests/chrome_test.lua
git commit -m "Draw the phone body, status bar, footer and page dots"
```

---

### Task 8: The screen

**Files:**
- Create: `PhoneScreen.lua`
- Modify: `main.lua`
- Test: `tests/phone_screen_test.lua`

**Interfaces:**
- Consumes: `Layout`, `Icons`, `Apps`, `Items`, `Chrome`.
- Produces `PhoneScreen.build(mod, modules, deps)` returning `{ new = function(game) ... end }`, the factory handed to `mod.content.screens:register("StartMenu", ...)`. Screen instances expose:
  - `screen.items`, `screen.index`, `screen.page`
  - `screen:update(dt)`, `screen:draw()`
  - `screen:pageCount()`

Input mirrors `src/ui/Menu.lua:79-105`: A plays `Press_AB`, pops the stack, then runs `onSelect`; B plays `Press_AB` and pops; START pops silently. A dimmed app plays `Tink` and does not pop.

- [ ] **Step 1: Write the failing test**

Create `tests/phone_screen_test.lua`:

```lua
-- Standalone: luajit mods/phone_start_menu/tests/phone_screen_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Data = require("tests.modkit.fixtures").fresh()

local run = T.sdk.loadMod("mods/phone_start_menu", { data = Data })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")

local Screens = require("src.ui.Screens")
Screens.invalidate()

-- a controllable input stand-in
local held = {}
local function press(name) held = { [name] = true } end
local function release() held = {} end

local popped, sounds
local function newGame(overrides)
  popped, sounds = 0, {}
  local g = {
    data = Data,
    save = { party = {}, flags = {}, inventory = {},
             player = { name = "RED" }, startMenuIndex = nil },
    stack = { push = function() end, pop = function() popped = popped + 1 end },
    input = { wasPressed = function(_, n) return held[n] == true end,
              isDown = function() return false end },
  }
  for k, v in pairs(overrides or {}) do g.save[k] = v end
  return g
end

local factory = Screens.get(newGame(), "StartMenu")
T.check(factory and factory.new, "StartMenu resolves through the registry")
T.check(factory ~= require("src.ui.StartMenu"),
  "the mod screen wins over the builtin StartMenu")

-- ---- structure
local game = newGame()
local screen = factory.new(game)
T.eq(#screen.items, 9, "nine apps on a fresh save")
T.eq(screen.index, 1, "the cursor starts on the first app")
T.eq(screen.page, 1, "the phone opens on page one")
T.eq(screen:pageCount(), 1, "nine apps are one page")

-- ---- drawing never raises, empty or populated
local ok, err = pcall(function() screen:draw() end)
T.check(ok, "drawing a fresh phone succeeds: " .. tostring(err))

game = newGame({ flags = { EVENT_GOT_POKEDEX = true },
                 party = { { species = "FIXMON_A" } },
                 inventory = { TOWN_MAP = 1 } })
screen = factory.new(game)
ok, err = pcall(function() screen:draw() end)
T.check(ok, "drawing a fully unlocked phone succeeds: " .. tostring(err))

-- ---- movement wraps within the grid
game = newGame()
screen = factory.new(game)
press("right") screen:update(0) release()
T.eq(screen.index, 2, "right moves one cell")
press("down") screen:update(0) release()
T.eq(screen.index, 5, "down moves a whole row")
press("left") screen:update(0) release()
T.eq(screen.index, 4, "left moves back one cell")
press("up") screen:update(0) release()
T.eq(screen.index, 1, "up moves back a row")
press("up") screen:update(0) release()
T.eq(screen.index, 7, "up from the top row wraps to the bottom")

-- ---- the cursor position survives closing
T.eq(game.save.startMenuIndex, screen.index, "the cursor index is remembered")
game.save.startMenuIndex = 3
local reopened = factory.new(game)
T.eq(reopened.index, 3, "reopening restores the cursor")

-- ---- B and START close
game = newGame()
screen = factory.new(game)
press("b") screen:update(0) release()
T.eq(popped, 1, "B closes the phone")

game = newGame()
screen = factory.new(game)
press("start") screen:update(0) release()
T.eq(popped, 1, "START closes the phone")

-- ---- a dimmed app refuses, a live one opens
game = newGame()
screen = factory.new(game)
screen.index = 1  -- DEX, dimmed on a fresh save
press("a") screen:update(0) release()
T.eq(popped, 0, "selecting a dimmed app does not close the phone")

game = newGame()
screen = factory.new(game)
screen.index = 3  -- BAG, always live
press("a") screen:update(0) release()
T.eq(popped, 1, "selecting a live app closes the phone")

run.release()
T.finish("phone screen")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `luajit mods/phone_start_menu/tests/phone_screen_test.lua`
Expected: FAIL, `StartMenu` still resolves to the builtin because nothing registers it.

- [ ] **Step 3: Write the implementation**

Create `PhoneScreen.lua`:

```lua
-- The screen the registry hands back for "StartMenu".
--
-- Not opaque: src/core/StateStack.lua picks its draw floor from that flag,
-- so leaving it unset keeps the overworld drawing underneath, which is both
-- vanilla Menu behaviour and what the mockup shows.

local PhoneScreen = {}

local function clamp(n, lo, hi)
  if n < lo then return lo end
  if n > hi then return hi end
  return n
end

function PhoneScreen.build(mod, M, deps)
  local Layout, Icons, Apps, Items, Chrome =
    M.Layout, M.Icons, M.Apps, M.Items, M.Chrome

  local Screen = {}
  Screen.__index = Screen

  function Screen.new(game)
    local self = setmetatable({}, Screen)
    self.game = game

    local function reopen() deps.screens.push(game, "StartMenu") end
    local apps = Apps.build(game, deps, reopen)
    local composed, hookProblem = Items.compose(game, apps, deps.runtime)
    -- vanilla logs the same condition at src/ui/StartMenu.lua:131-135; the
    -- screen is the layer that owns a mod.log, so it does the reporting
    if hookProblem then
      mod.log:warn("%s -- showing the built-in apps; a mod wrapping "
        .. "ui.start_menu.items is misbehaving and its rows are missing "
        .. "this session", hookProblem)
    end
    self.items = composed
    if #self.items == 0 then
      -- cannot happen with the nine built-ins, but a wrapper may have
      -- emptied the list; an empty phone would be a dead end
      mod.log:warn("the start menu item list came back empty -- a mod "
        .. "wrapping ui.start_menu.items removed every row; showing the "
        .. "built-in apps instead")
      self.items = Items.decorate(apps)
    end

    self.index = clamp(game.save.startMenuIndex or 1, 1, #self.items)
    self.page = (Layout.locate(self.index))
    return self
  end

  function Screen:pageCount()
    return Layout.pageCount(#self.items)
  end

  -- Move by a whole-grid delta, wrapping through the list.  Wrapping on the
  -- flat index rather than per-page means walking off the bottom of page one
  -- lands on page two, which is what a grid of apps should do.
  function Screen:_move(delta)
    local n = #self.items
    if n == 0 then return end
    self.index = ((self.index - 1 + delta) % n) + 1
    self.page = (Layout.locate(self.index))
  end

  function Screen:update(_)
    local input = self.game.input
    if input:wasPressed("right") then
      self:_move(1)
    elseif input:wasPressed("left") then
      self:_move(-1)
    elseif input:wasPressed("down") then
      self:_move(3)
    elseif input:wasPressed("up") then
      self:_move(-3)
    elseif input:wasPressed("r") then
      self:_move(Layout.PER_PAGE)
    elseif input:wasPressed("l") then
      self:_move(-Layout.PER_PAGE)
    elseif input:wasPressed("a") then
      local item = self.items[self.index]
      if item and item.enabled == false then
        deps.sound.play(self.game.data, "Tink")
      elseif item then
        deps.sound.play(self.game.data, "Press_AB")
        -- Menu pops before running onSelect (src/ui/Menu.lua:91-93), so a
        -- submenu's onCancel can push the phone back on top of nothing
        self.game.stack:pop()
        if item.onSelect then item.onSelect() end
      end
    elseif input:wasPressed("b") or input:wasPressed("start") then
      -- the start menu's mask watches START (draw_start_menu.asm), and only
      -- the A/B branch replays the beep, so START closes silently
      if input:wasPressed("b") then
        deps.sound.play(self.game.data, "Press_AB")
      end
      self.game.stack:pop()
    end
    self.game.save.startMenuIndex = self.index
  end

  function Screen:draw()
    local L = Layout
    -- the whole phone is re-blit unshaded, so it keeps the mockup's colours
    -- while the overworld behind it stays on its Game Boy palette
    deps.markTrueColor(L.PHONE.x, L.PHONE.y, L.PHONE.w, L.PHONE.h)

    M.chrome:drawBody()
    M.chrome:drawStatus(self.game)

    local pages = self:pageCount()
    local first = (self.page - 1) * L.PER_PAGE
    for slot = 1, L.PER_PAGE do
      local item = self.items[first + slot]
      if item then
        local x, y = L.cell(slot)
        local dim = item.enabled == false
        M.icons:drawIcon(item.icon, x, y, dim)
        local lx, ly = L.labelPos(slot)
        local caption = item.display or ""
        local width = M.icons:labelWidth(caption)
        M.icons:drawLabel(caption,
          L.COLS[((slot - 1) % 3) + 1]
            + math.floor((L.CELL_W - width) / 2), ly, dim)
        if first + slot == self.index then
          self:_drawCursor(x, y)
        end
      end
    end

    M.chrome:drawDots(self.page, pages)
    M.chrome:drawFooter()
    love.graphics.setColor(1, 1, 1, 1)
  end

  -- a one-pixel frame around the focused cell, in the outline colour
  function Screen:_drawCursor(x, y)
    love.graphics.setColor(0.14, 0.18, 0.18, 1)
    love.graphics.rectangle("line", x - 2 + 0.5, y - 2 + 0.5,
                            Layout.ICON + 3, Layout.ICON + 3)
    love.graphics.setColor(1, 1, 1, 1)
  end

  return { new = Screen.new }
end

return PhoneScreen
```

- [ ] **Step 4: Wire it up in main.lua**

Replace the sibling block in `main.lua` with the full wiring:

```lua
  local Layout      = sibling("Layout.lua")
  local Icons       = sibling("Icons.lua")
  local Apps        = sibling("Apps.lua")
  local Items       = sibling("Items.lua")
  local Chrome      = sibling("Chrome.lua")
  local PhoneScreen = sibling("PhoneScreen.lua")
  if not (Layout and Icons and Apps and Items and Chrome and PhoneScreen) then
    return
  end

  -- engine_internals: Runtime is how the items hook is re-run, PaletteFX is
  -- how the phone keeps its colours, and Screens/Sound are the ordinary
  -- push and beep the vanilla menu uses
  local Runtime   = require("src.mods.Runtime")
  local PaletteFX = require("src.render.PaletteFX")
  local Screens   = require("src.ui.Screens")
  local Sound     = require("src.core.Sound")

  local icons  = Icons.new(mod)
  local chrome = Chrome.new(Layout, icons)

  local deps = {
    screens = { push = function(game, id, opts)
      Screens.push(game, id, opts)
    end },
    sound   = { play = function(data, name)
      pcall(Sound.play, data, name)
    end },
    runtime = Runtime,
    markTrueColor = function(x, y, w, h)
      pcall(PaletteFX.markTrueColor, x, y, w, h)
    end,
    save = function(game) SaveFlow(game) end,   -- filled in by Task 9
    link = function(game)
      local LinkState = require("src.link.LinkState")
      game.stack:push(LinkState.new(game))
    end,
  }

  local modules = { Layout = Layout, Icons = Icons, Apps = Apps,
                    Items = Items, Chrome = Chrome,
                    icons = icons, chrome = chrome }

  mod.content.screens:register("StartMenu",
    PhoneScreen.build(mod, modules, deps))
```

Until Task 9 lands, define a placeholder above `deps` so the chunk compiles:

```lua
  local SaveFlow = function() end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `luajit mods/phone_start_menu/tests/phone_screen_test.lua`
Expected: PASS.

Run each earlier suite to confirm nothing regressed:
`luajit mods/phone_start_menu/tests/loads_test.lua`
`luajit mods/phone_start_menu/tests/items_test.lua`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add PhoneScreen.lua main.lua tests/phone_screen_test.lua
git commit -m "Register the phone as the START menu screen"
```

---

### Task 9: The SAVE flow

**Files:**
- Create: `SaveFlow.lua`
- Modify: `main.lua`
- Test: `tests/save_flow_test.lua`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces `SaveFlow.build(deps)` returning `function(game)`, which pushes the vanilla save confirmation chain. `deps` is `{ textbox = <module>, badges = <module>, sound = <module>, strings = <function>, log = <mod.log, optional> }`. `log` is optional so the module stays drivable from a test with no mod handle.

This reproduces `src/ui/StartMenu.lua:55-88` because the engine exposes no seam to call it. Keep the frame delays exactly: 120 then 30.

- [ ] **Step 1: Write the failing test**

Create `tests/save_flow_test.lua`:

```lua
-- Standalone: luajit mods/phone_start_menu/tests/save_flow_test.lua
--
-- This flow is a reproduction of src/ui/StartMenu.lua:55-88.  The delays are
-- asserted here because they are the part most likely to drift: 120 frames
-- holding "Now saving...", then 30 after the save jingle.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local SaveFlow = dofile("mods/phone_start_menu/SaveFlow.lua")

local boxes
local deps = {
  textbox = { new = function(_, text, onDone, opts)
    local box = { text = text, onDone = onDone, opts = opts or {} }
    boxes[#boxes + 1] = box
    return box
  end },
  badges  = { count = function() return 3 end },
  sound   = { play = function() return true end },
  strings = function(fmt, ...)
    if select("#", ...) == 0 then return fmt end
    return string.format(fmt, ...)
  end,
}

local function newGame()
  boxes = {}
  local wrote = { n = 0 }
  return {
    data = {},
    save = { player = { name = "RED" }, party = {}, playTime = 3725,
             pokedex = { owned = { FIXMON_A = true }, seen = {} } },
    stack = { push = function() end, pop = function() end },
    writeSave = function() wrote.n = wrote.n + 1 end,
    _wrote = wrote,
  }
end

local flow = SaveFlow.build(deps)

-- the panel comes first, and it asks
local game = newGame()
flow(game)
T.eq(#boxes, 1, "the flow opens with one box")
T.check(boxes[1].text:find("PLAYER"), "the panel names the player")
T.check(boxes[1].text:find("BADGES"), "the panel counts badges")
T.check(boxes[1].text:find("1:02"), "the panel prints play time as H:MM")
T.check(type(boxes[1].opts.choice) == "function", "the panel asks to confirm")

-- declining writes nothing
boxes[1].opts.choice(false)
T.eq(game._wrote.n, 0, "declining does not write the save")
T.eq(#boxes, 1, "declining opens no further box")

-- accepting holds "Now saving..." for 120 frames, then writes
game = newGame()
flow(game)
boxes[1].opts.choice(true)
T.eq(#boxes, 2, "accepting opens the saving box")
T.check(boxes[2].text:find("Now saving"), "the second box is the saving hold")
T.eq(boxes[2].opts.auto.delay, 120, "the saving hold is 120 frames")
T.eq(game._wrote.n, 0, "the write waits for the hold to finish")

-- the hold finishing writes and confirms
boxes[2].onDone()
T.eq(game._wrote.n, 1, "the save is written exactly once")
T.eq(#boxes, 3, "the confirmation box opens")
T.check(boxes[3].text:find("saved"), "the third box confirms the save")
T.eq(boxes[3].opts.auto.delay, 30, "the confirmation holds 30 frames")
T.check(type(boxes[3].opts.auto.sound) == "function",
  "the confirmation waits on the save jingle")

T.finish("save flow")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `luajit mods/phone_start_menu/tests/save_flow_test.lua`
Expected: FAIL, `SaveFlow.lua` does not exist.

- [ ] **Step 3: Write the implementation**

Create `SaveFlow.lua`:

```lua
-- The SAVE confirmation chain, reproduced from src/ui/StartMenu.lua:55-88.
--
-- The engine exposes no seam to invoke that flow, so claiming the screen id
-- means reproducing it.  This is recorded in mod.card's `known` ledger: if
-- the engine changes the flow, this file drifts until it is updated.
--
-- The delays are load-bearing and come from engine/menus/save.asm:164-181:
-- "Now saving..." is a bare PlaceString held by DelayFrames 120, and the
-- confirmation ends in `done` so it never waits on a button; it waits on
-- SFX_SAVE and then DelayFrames 30.  Neither page takes a press.

local SaveFlow = {}

function SaveFlow.build(deps)
  local TextBox, Badges = deps.textbox, deps.badges
  local Strings, Sound = deps.strings, deps.sound

  return function(game)
    local owned = 0
    for _ in pairs(game.save.pokedex and game.save.pokedex.owned or {}) do
      owned = owned + 1
    end
    -- A save missing badge data must never block saving, so the count is
    -- guarded.  But it is reported: Items.compose records the same rule for
    -- a module with no mod.log of its own, and swallowing this silently
    -- would show BADGES 0 with no explanation anywhere.
    local badges = 0
    local okBadges, count = pcall(Badges.count, game.data, game.save)
    if okBadges and type(count) == "number" then
      badges = count
    elseif deps.log then
      deps.log:warn("could not read the badge count (%s); the save panel "
        .. "shows 0 badges but the save itself is unaffected -- report this "
        .. "with your save file if the count stays wrong", tostring(count))
    end

    local t = math.floor(game.save.playTime or 0)
    local panel = Strings("PLAYER %s\nBADGES    %d\nPOKéDEX %3d\nTIME %6d:%02d",
                          game.save.player.name or "RED", badges, owned,
                          math.floor(t / 3600), math.floor(t / 60) % 60)

    game.stack:push(TextBox.new(game,
      panel .. Strings("\fWould you like to\nSAVE the game?"), nil, {
      choice = function(yes)
        if not yes then return end
        game.stack:push(TextBox.new(game, Strings("Now saving..."), function()
          game:writeSave()
          game.stack:push(TextBox.new(game,
            Strings("%s saved\nthe game!", game.save.player.name or "RED"),
            nil, { auto = {
              sound = function() return Sound.play(game.data, "Save") end,
              delay = 30,
            } }))
        end, { auto = { delay = 120 } }))
      end,
    }))
  end
end

return SaveFlow
```

- [ ] **Step 4: Wire it into main.lua**

Remove the `local SaveFlow = function() end` placeholder. Add `SaveFlow.lua` to the sibling list and build the real flow:

```lua
  local SaveFlow = sibling("SaveFlow.lua")
```

Add it to the `if not (...)` guard, then above `deps`:

```lua
  local saveFlow = SaveFlow.build({
    textbox = require("src.render.TextBox"),
    badges  = require("src.inventory.Badges"),
    sound   = require("src.core.Sound"),
    strings = require("src.core.Strings"),
    log     = mod.log,
  })
```

and set `save = saveFlow` in `deps`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `luajit mods/phone_start_menu/tests/save_flow_test.lua`
Expected: PASS, including both delay assertions.

Run: `luajit mods/phone_start_menu/tests/phone_screen_test.lua`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add SaveFlow.lua main.lua tests/save_flow_test.lua
git commit -m "Reproduce the SAVE confirmation flow"
```

---

### Task 10: Paging, degradation, and the shipping files

**Files:**
- Create: `README.md`, `CHANGELOG.md`, `mod.card`, `tests/paging_test.lua`, `tests/degrade_test.lua`
- Modify: none

**Interfaces:**
- Consumes: everything above.
- Produces: a packageable mod.

- [ ] **Step 1: Write the failing paging test**

Create `tests/paging_test.lua`:

```lua
-- Standalone: luajit mods/phone_start_menu/tests/paging_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Data = require("tests.modkit.fixtures").fresh()

-- loading the injector alongside pushes the list to ten rows
local run = T.sdk.loadMods({ "mods/phone_start_menu",
                             "mods/phone_start_menu/tests/fixtures/injector_mod" },
                           { data = Data })
T.eq(#run.errors, 0, "both mods load clean (" .. tostring(run.errors[1]) .. ")")

local Screens = require("src.ui.Screens")
Screens.invalidate()

local held = {}
local game = {
  data = Data,
  save = { party = {}, flags = {}, inventory = {}, player = { name = "RED" } },
  stack = { push = function() end, pop = function() end },
  input = { wasPressed = function(_, n) return held[n] == true end,
            isDown = function() return false end },
}

local screen = Screens.get(game, "StartMenu").new(game)
T.eq(#screen.items, 10, "the injected row makes ten")
T.eq(screen:pageCount(), 2, "ten apps are two pages")
T.eq(screen.page, 1, "the phone opens on page one")

-- R flips to page two
held = { r = true } screen:update(0) held = {}
T.eq(screen.page, 2, "R flips to page two")
T.eq(screen.index, 10, "R lands on the tenth app")

-- and walking forward from the last app wraps to the first
held = { right = true } screen:update(0) held = {}
T.eq(screen.index, 1, "walking off the end wraps to the first app")
T.eq(screen.page, 1, "which is back on page one")

local ok, err = pcall(function() screen:draw() end)
T.check(ok, "drawing a two-page phone succeeds: " .. tostring(err))

run.release()
T.finish("paging")
```

- [ ] **Step 2: Run it**

Run: `luajit mods/phone_start_menu/tests/paging_test.lua`
Expected: PASS if Tasks 6 and 8 are correct. If the page does not advance, `Screen:_move` is wrapping per-page instead of on the flat index.

- [ ] **Step 3: Write the degradation test**

Create `tests/degrade_test.lua`:

```lua
-- Standalone: luajit mods/phone_start_menu/tests/degrade_test.lua
--
-- The START menu is the only route to SAVE.  Screens.push (src/ui/Screens.lua:
-- 44-52) pcalls a mod-owned factory and falls back to the builtin when it
-- throws.  This asserts that net actually catches a broken phone, because
-- the alternative is a player who cannot save.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Data = require("tests.modkit.fixtures").fresh()

local run = T.sdk.loadMod("mods/phone_start_menu", { data = Data })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")

local Screens = require("src.ui.Screens")
Screens.invalidate()

-- replace the registered factory with one that throws, the way a defect
-- inside the phone would
Data.screens.StartMenu = { new = function() error("simulated defect", 0) end }
Screens.invalidate()

local pushed = {}
local game = {
  data = Data,
  save = { party = {}, flags = {}, inventory = {}, player = { name = "RED" },
           startMenuIndex = 1 },
  stack = { push = function(_, st) pushed[#pushed + 1] = st end,
            pop = function() end },
  input = { wasPressed = function() return false end,
            isDown = function() return false end },
}

local ok, err = pcall(function() Screens.push(game, "StartMenu") end)
T.check(ok, "pushing a broken phone does not raise: " .. tostring(err))
T.eq(#pushed, 1, "something was pushed")
T.check(pushed[1].items and #pushed[1].items > 0,
  "the builtin menu took over, so SAVE is still reachable")

run.release()
T.finish("degradation")
```

- [ ] **Step 4: Run it**

Run: `luajit mods/phone_start_menu/tests/degrade_test.lua`
Expected: PASS.

If it fails inside the builtin rather than in the fallback path, the cause is
almost certainly that `src/ui/StartMenu.lua` cannot construct against the
fixture dataset: `Menu.new` measures every label through `Font.split`
(`src/ui/Menu.lua:24`), which needs a loaded font. Fix it by loading the real
font before the push rather than by weakening the assertion:

```lua
local Font = require("src.render.Font")
pcall(Font.load, Data)
```

The assertion being made is that the fallback happens at all, so never
replace it with a check that merely nothing raised.

- [ ] **Step 5: Write the shipping files**

`mod.card`:

```lua
-- Sharing metadata; read by tooling and the manager detail pane.
return {
  summary = "The START menu as a phone home screen: nine apps in a 3x3 grid.",
  author = "camwrightdc",
  tags = { "ui", "cosmetic", "quality-of-life" },
  differences = {
    changed = {
      "the START menu is a phone home screen instead of a text list",
      "POKéMON dims with an empty party instead of listing and doing nothing",
      "QUIT is gone; A+B+SELECT+START returns to the title, as it always did",
    },
    added = {
      "a MAP app opening the TOWN MAP, gated on holding the item",
      "a status bar showing the real time and whether a link is live",
    },
    known = {
      "the SAVE flow is reproduced from the engine rather than called, "
        .. "because no seam exposes it: an engine change to that flow "
        .. "leaves this mod drifting until it is updated to match",
      "the status bar clock reads real-world time, which sits outside "
        .. "the fiction",
      "app captions use a 4x6 face rather than the game font, which does "
        .. "not fit a 21px cell",
    },
  },
  compat = { engine = ">=1.0.0 <2.0.0", modApi = 2 },
}
```

`CHANGELOG.md`:

```markdown
# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-08-25

### Added

- The START menu drawn as a phone home screen: nine apps in a 3x3 grid over
  the overworld, in true colour.
- A MAP app opening the TOWN MAP, gated on holding the item.
- A status bar showing the real time and whether a link session is live.
- Page two and page dots when another mod injects extra rows.

### Changed

- POKéMON dims with an empty party rather than listing and doing nothing.

### Removed

- QUIT. A+B+SELECT+START performs the same return to the title from any
  state, on every platform.
```

`README.md`: open with one sentence saying what the mod does, name the
author, and give the three commands to try it:

```markdown
# Phone START Menu

Replaces the START menu in the [Pokemon Gen 1 Recompilation Project](https://github.com/bryanthaboi/pokemon-gen1-recomp-project)
with a phone home screen: nine apps in a 3x3 grid, drawn in colour over the
overworld.

## Try it

```sh
python3 tools/modkit.py validate mods/phone_start_menu --base imported
python3 tools/modkit.py lint mods/phone_start_menu
luajit mods/phone_start_menu/tests/phone_screen_test.lua
```

## The apps

Dex, Pkmn, Bag, Id, Optn, Save, Map, Link, Mods. An app you have not
unlocked yet sits dimmed in its own place, so nothing ever moves under your
thumb.

Map opens the TOWN MAP, and needs you to be carrying it, exactly as using
the item from the bag does.

## Where did QUIT go?

Hold A, B, SELECT and START together. That is the Game Boy's own soft reset,
it returns you to the title from anywhere, and it is what QUIT called.

## Regenerating the art

```sh
python tools/gen_assets.py
```

Every pixel is declared as text in that script, so the art is original and
carries its own provenance.
```

- [ ] **Step 5b: Regenerate `.modkitignore` and guard it with a test**

`tools/modkit.py:161-182` matches ignore entries by exact string equality
against a file's full relative path (`if rel in ignored`). A directory entry
like `tests/` therefore matches nothing and is silently a no-op: `pack` will
bundle the whole test suite, this plan, and the design spec into the
archive, and `validate --strict` reports no warning. Dot-prefixed
directories are skipped by the walk, so `.superpowers/` is already safe.

Regenerate the file with exact paths:

```bash
cd C:/Users/camwr/Desktop/Gen1Recomp/phone-start-menu
{
  echo "# modkit matches these by exact relative path, not by prefix:"
  echo "# a bare directory name here would silently match nothing."
  find tests tools docs -type f | sed 's|\|/|g' | sort
} > .modkitignore
cat .modkitignore
```

Then add `tests/packaging_test.lua`, which fails if anything under those
three directories would ship:

```lua
-- Standalone: luajit mods/phone_start_menu/tests/packaging_test.lua
--
-- .modkitignore entries are matched by exact relative path
-- (tools/modkit.py:161-182), so a directory entry is silently a no-op and
-- the suite, the plan and the spec end up inside the archive with no
-- warning from validate --strict.  This asserts the packaged file list.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")

local root = "mods/phone_start_menu"
local ignored = {}
for line in io.lines(root .. "/.modkitignore") do
  line = line:gsub("^%s+", ""):gsub("%s+$", "")
  if line ~= "" and line:sub(1, 1) ~= "#" then ignored[line] = true end
end

-- every file under tests/, tools/ and docs/ must be listed by exact path
local leaked, counted = {}, 0
local pipe = io.popen('cd "' .. root .. '" && find tests tools docs -type f')
for path in pipe:lines() do
  path = path:gsub("\\", "/"):gsub("^%./", "")
  counted = counted + 1
  if not ignored[path] then leaked[#leaked + 1] = path end
end
pipe:close()

T.check(counted > 0, "found files under tests/, tools/ and docs/ to check")
T.eq(#leaked, 0, "nothing under tests/, tools/ or docs/ would be packaged"
  .. (leaked[1] and (" -- leaked: " .. table.concat(leaked, ", ")) or ""))

T.finish("packaging")
```

Run: `luajit mods/phone_start_menu/tests/packaging_test.lua`
Expected: PASS. Break it deliberately once, by deleting a line from
`.modkitignore`, and confirm it fails naming that file, before moving on.

- [ ] **Step 6: Run the full suite and the packaging gates**

From the `game/` directory:

```bash
for t in loads layout assets icons apps items chrome phone_screen save_flow paging degrade packaging; do
  luajit mods/phone_start_menu/tests/${t}_test.lua || echo "FAILED: $t"
done
python3 tools/modkit.py validate mods/phone_start_menu --base imported
python3 tools/modkit.py lint mods/phone_start_menu
```

Expected: every suite green, `validate` and `lint` both clean. `validate`
warns if `manifest.version` advanced without a `CHANGELOG.md` heading; the
0.1.0 heading above satisfies it.

- [ ] **Step 7: Commit**

```bash
git add README.md CHANGELOG.md mod.card .modkitignore tests/paging_test.lua tests/degrade_test.lua tests/packaging_test.lua
git commit -m "Add paging and degradation tests, and the shipping files"
```

---

## Self-review notes

Checked against the spec:

- Every spec section maps to a task: architecture to 1/6/8, layout to 2,
  colour to 8 (`markTrueColor` in `Screen:draw`), assets to 3/4, apps to 5,
  unavailable apps to 5/8, Map to 5, QUIT to 10 (README and card), status bar
  to 7, interaction to 8, paging to 10, testing to every task, known
  limitations to 10.
- The spec's seven-point test list maps as: 1 to Task 1, 2 to Task 8, 3 and 4
  to Task 6, 5 to Task 5, 6 to Task 10, 7 to Task 10.
- Names are consistent across tasks: `Layout.cell`, `Layout.locate`,
  `Layout.pageCount`, `Icons.INDEX`, `icons:drawIcon`, `icons:drawLabel`,
  `icons:labelWidth`, `Apps.DEFS`, `Apps.build`, `Items.compose`,
  `Items.decorate`, `Chrome.clockText`, `Chrome.linkLive`,
  `PhoneScreen.build`, `SaveFlow.build`.
- `deps` carries the same six keys everywhere it appears: `screens`,
  `sound`, `runtime`, `markTrueColor`, `save`, `link`. Task 5's test passes
  a subset because `Apps.build` touches only `screens`, `save` and `link`.

Two items to watch during execution:

- Task 3's icon pixel maps use `.replace(" ", "N")` to keep rows aligned in
  the source. The generator raises if any row is not 16 characters, so a
  miscount fails loudly rather than producing skewed art.
- Task 8's `Screen:_move` wraps on the flat index, not per page. Task 10's
  paging test is what catches a per-page implementation.
