-- Standalone: luajit mods/pokegear_menu/tests/degrade_test.lua
--
-- The START menu is the only route to SAVE.  Screens.push (src/ui/Screens.lua:
-- 45-55) pcalls a mod-owned factory and falls back to the builtin when it
-- throws.  This asserts that net actually catches a broken phone, because
-- the alternative is a player who cannot save.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Data = require("tests.modkit.fixtures").fresh()

local run = T.sdk.loadMod("mods/pokegear_menu", { data = Data })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")

local Screens = require("src.ui.Screens")
Screens.invalidate()

-- Menu.new measures every label through Font.split (src/ui/Menu.lua:24),
-- which needs a loaded font; load the real one before the builtin has to
-- construct itself, so the fallback path is what gets exercised below
-- rather than a Font-shaped crash inside it.
local Font = require("src.render.Font")
pcall(Font.load, Data)

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
  "the builtin menu took over, so it has rows at all")

-- having rows is not the same as SAVE being reachable: find the row the
-- builtin itself uses for SAVE (its label is whatever the active string
-- catalog resolves "SAVE" to, src/ui/StartMenu.lua:54) and confirm it is
-- actually selectable, not just present
local Strings = require("src.core.Strings")
local saveLabel = Strings("SAVE")
local saveRow
for _, item in ipairs(pushed[1].items) do
  if item.label == saveLabel then saveRow = item end
end
T.check(saveRow, "the fallback menu has a row labelled " .. tostring(saveLabel))
T.check(saveRow and type(saveRow.onSelect) == "function",
  "the builtin menu took over, so SAVE is still reachable")

run.release()
T.finish("degradation")
