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
