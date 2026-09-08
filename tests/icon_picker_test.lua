-- Standalone: luajit mods/pokegear_menu/tests/icon_picker_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Layout = dofile("mods/pokegear_menu/Layout.lua")
local Icons = dofile("mods/pokegear_menu/Icons.lua")
local IconPicker = dofile("mods/pokegear_menu/IconPicker.lua")

-- the real drawing instance, the way icons_test.lua builds one: labelWidth
-- and drawIcon must behave like the genuine article (a stub returning
-- nothing where the real one returns a number breaks the draw path below
-- in a way the real mod never would)
local fakeMod = {
  path = "mods/pokegear_menu",
  assets = { image = function(_, rel)
    return love.graphics.newImage("mods/pokegear_menu/" .. rel)
  end },
  log = { warn = function() end, error = function() end },
}
local iconsInstance = Icons.new(fakeMod)
local chromeStub = setmetatable({}, { __index = function() return function() end end })
local M = { Layout = Layout, Icons = Icons, icons = iconsInstance, chrome = chromeStub }

local sounds, popped
local deps = {
  sound = { play = function(_, name) sounds[#sounds + 1] = name end },
  markTrueColor = function() end,
}
local factory = IconPicker.build({}, M, deps)

local function newGame(overrides)
  popped, sounds = 0, {}
  return {
    save = { modIconOverrides = overrides },
    stack = { pop = function() popped = popped + 1 end },
    input = { wasPressed = function() return false end },
  }
end

-- ---- opens on generic with no saved override, and on the saved choice
-- when there is one
local screen = factory.new(newGame(nil), { label = "INJECTED" })
T.eq(Icons.CUSTOM_ORDER[screen.index], "generic",
  "opens on generic when nothing is saved for this row")

screen = factory.new(newGame({ INJECTED = "bolt" }), { label = "INJECTED" })
T.eq(Icons.CUSTOM_ORDER[screen.index], "bolt", "opens on the row's saved icon")

-- ---- left/right wrap at both ends of the option list
screen = factory.new(newGame({}), { label = "INJECTED" })
local n = #Icons.CUSTOM_ORDER
screen:_move(-1)
T.eq(screen.index, n, "left from the first option wraps to the last")
screen:_move(1)
T.eq(screen.index, 1, "right from the last wraps back to the first")

-- ---- down/up move by a whole row of the 3-wide grid the options are
-- drawn in (Layout.cell), the same as PhoneScreen's own up/down; a picker
-- that only wired left/right left the bottom row unreachable except by
-- wrapping all the way around
local downUpGame = newGame({})
screen = factory.new(downUpGame, { label = "INJECTED" })
screen.game.input = { wasPressed = function(_, key) return key == "down" end }
screen:update(0)
T.eq(screen.index, 4, "down moves from the first option to the one below it")
screen.game.input = { wasPressed = function(_, key) return key == "up" end }
screen:update(0)
T.eq(screen.index, 1, "up moves back to the row above")

-- ---- A saves the highlighted choice under the row's label, and closes
local game = newGame({})
local chosenViaCallback
screen = factory.new(game, { label = "INJECTED",
  onChosen = function(key) chosenViaCallback = key end })
screen:_move(1) -- star
screen.game.input = { wasPressed = function(_, key) return key == "a" end }
screen:update(0)
T.eq(game.save.modIconOverrides.INJECTED, "star", "A saves the highlighted icon")
T.eq(chosenViaCallback, "star",
  "A also calls onChosen, which is how PhoneScreen updates the live row")
T.eq(popped, 1, "A closes the picker")
T.same(sounds, { "Press_AB" }, "A plays Press_AB")

-- ---- choosing generic clears a previously saved override rather than
-- writing "generic" into the table, so an override table that only ever
-- grows is not still pointing at a mod years after it was uninstalled
game = newGame({ INJECTED = "heart" })
screen = factory.new(game, { label = "INJECTED" })
while Icons.CUSTOM_ORDER[screen.index] ~= "generic" do screen:_move(-1) end
screen.game.input = { wasPressed = function(_, key) return key == "a" end }
screen:update(0)
T.check(game.save.modIconOverrides.INJECTED == nil,
  "choosing generic clears the row's override instead of storing it")

-- ---- B cancels without saving anything
game = newGame({})
screen = factory.new(game, { label = "INJECTED" })
screen:_move(1) -- star, never confirmed
screen.game.input = { wasPressed = function(_, key) return key == "b" end }
screen:update(0)
T.eq(popped, 1, "B closes the picker")
T.check(next(game.save.modIconOverrides) == nil, "B saves nothing")

-- ---- drawing never raises, with or without a loaded icon sheet
local ok, err = pcall(function() screen:draw() end)
T.check(ok, "drawing the picker succeeds: " .. tostring(err))

T.finish("icon picker")
