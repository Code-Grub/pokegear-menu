-- Standalone: luajit mods/pokegear_menu/tests/assets_test.lua
-- The love stub reads real PNG headers, so these assertions check the
-- generator's actual output rather than a stub default.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Icons = dofile("mods/pokegear_menu/Icons.lua")

-- Derived from Icons.INDEX rather than written out, because a hand-copied
-- count is exactly what went stale: the picker's eight extra options grew
-- the sheet from thirteen icons to twenty-one, and this assertion kept
-- asking for thirteen.  Every index has to be a real column, so the sheet
-- is as wide as the highest one.
local widest = 0
for _, col in pairs(Icons.INDEX) do
  if col > widest then widest = col end
end

local icons = love.graphics.newImage("mods/pokegear_menu/assets/icons.png")
T.eq(icons:getWidth(), widest * 16,
     "icon sheet has a column for every Icons.INDEX entry")
T.eq(icons:getHeight(), 16, "icon sheet is one 16px row tall")

local font = love.graphics.newImage("mods/pokegear_menu/assets/label_font.png")
T.eq(font:getWidth(), 205, "label font is 41 glyphs at a 5px advance")
T.eq(font:getHeight(), 6, "label font is 6px tall")

T.finish("assets")
