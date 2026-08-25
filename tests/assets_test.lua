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
T.eq(font:getWidth(), 195, "label font is 39 glyphs at a 5px advance")
T.eq(font:getHeight(), 6, "label font is 6px tall")

T.finish("assets")
