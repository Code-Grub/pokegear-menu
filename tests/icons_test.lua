-- Standalone: luajit mods/pokegear_menu/tests/icons_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Icons = dofile("mods/pokegear_menu/Icons.lua")

-- a stand-in for the mod handle: only assets:image and log are touched
local warned = {}
local fakeMod = {
  path = "mods/pokegear_menu",
  assets = { image = function(_, rel)
    return love.graphics.newImage("mods/pokegear_menu/" .. rel)
  end },
  log = { warn = function(_, fmt, ...) warned[#warned + 1] = fmt end,
          error = function(_, fmt, ...) warned[#warned + 1] = fmt end },
}

local icons = Icons.new(fakeMod)

T.eq(Icons.INDEX.dex, 1, "dex is the first icon")
T.eq(Icons.INDEX.generic, 13, "generic is the last icon")

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

-- The quads themselves.  love_stub's draw is a no-op and its newQuad
-- discards the sheet dimensions, so nothing downstream ever reads these
-- numbers: without asserting them, an off-by-one in the column maths
-- passes every check above while the phone draws neighbouring art.
-- One draw call is enough to force the lazy load that builds both tables.
icons:drawIcon("dex", 0, 0, false)

local q = icons.iconQuads[Icons.INDEX.dex]
T.eq(q.x, 0, "the dex icon starts at column 0")
T.eq(q.w, 16, "an icon quad is 16px wide")
T.eq(q.h, 16, "an icon quad is 16px tall")

q = icons.iconQuads[Icons.INDEX.generic]
T.eq(q.x, 192, "the generic icon is the thirteenth 16px column")
T.eq(q.x + q.w, 208, "the last icon quad ends exactly at the sheet edge")

q = icons.glyphQuads["A"]
T.eq(q.x, 0, "A is the first glyph")
T.eq(q.w, 5, "a glyph quad spans 4px of ink plus its 1px gutter")
T.eq(q.h, 6, "a glyph quad is 6px tall")

q = icons.glyphQuads["D"]
T.eq(q.x, 15, "D is the fourth glyph, at a 5px advance")

q = icons.glyphQuads[" "]
T.eq(q.x, 190, "the trailing space is the 39th glyph")

q = icons.glyphQuads[":"]
T.check(q, "the colon the clock needs has a quad")
T.eq(q.x, 195, "the colon is the fortieth glyph")
T.eq(q.x + q.w, 200, "the colon quad ends where e-acute begins")

-- e-acute is the last glyph and the one the nameplate needs.  It is also
-- the only multibyte key in the sheet, so it proves the glyph map is built
-- by UTF-8 sequence and not by byte: a byte-wise build registers two bogus
-- one-byte keys and no e-acute at all.  Written as explicit bytes because
-- LuaJIT has no \u escape.
local EACUTE = "\195\169"
q = icons.glyphQuads[EACUTE]
T.check(q, "e-acute has a quad, so the map walked UTF-8 rather than bytes")
T.eq(q.x, 200, "e-acute is the forty first glyph")
T.eq(q.x + q.w, 205, "the last glyph quad ends exactly at the sheet edge")
T.eq(icons:labelWidth("POK" .. EACUTE .. "GEAR"), 40,
  "an accented caption measures 8 glyphs, not 9 bytes")

T.finish("icons")
