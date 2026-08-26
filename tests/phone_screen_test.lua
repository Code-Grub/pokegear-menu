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
    save = { party = {}, flags = {}, inventory = {}, money = 0,
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
