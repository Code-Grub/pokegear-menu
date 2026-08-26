-- Standalone: luajit mods/phone_start_menu/tests/phone_screen_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Data = require("tests.modkit.fixtures").fresh()

-- Intercept the real src.core.Sound module (wired in main.lua) before the
-- mod loads, so "%s plays %s" claims are actually checked rather than
-- merely declared.
local sounds = {}
local function clearSounds()
  for i = #sounds, 1, -1 do sounds[i] = nil end
end
package.loaded["src.core.Sound"] = {
  play = function(_, name) sounds[#sounds + 1] = name end,
}

local run = T.sdk.loadMod("mods/phone_start_menu", { data = Data })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")

local Screens = require("src.ui.Screens")
Screens.invalidate()

-- a controllable input stand-in
local held = {}
local function press(name) held = { [name] = true } end
local function release() held = {} end

local popped
local function newGame(overrides)
  popped = 0
  clearSounds()
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

-- ---- a stale, out-of-range saved index clamps instead of indexing past
-- the list
game.save.startMenuIndex = 50
local reopenedOOB = factory.new(game)
T.eq(#reopenedOOB.items, 9, "still nine apps to clamp against")
T.eq(reopenedOOB.index, #reopenedOOB.items,
  "an oversized saved index clamps to the last app, not 50")

-- ---- B and START close; B beeps, START is silent
-- (src/ui/StartMenu.lua:136-138: only the A/B branch replays the beep)
game = newGame()
screen = factory.new(game)
press("b") screen:update(0) release()
T.eq(popped, 1, "B closes the phone")
T.same(sounds, { "Press_AB" }, "B plays Press_AB")

game = newGame()
screen = factory.new(game)
press("start") screen:update(0) release()
T.eq(popped, 1, "START closes the phone")
T.same(sounds, {}, "START closes silently and plays nothing")

-- ---- a dimmed app refuses, a live one opens; each plays its own sound
game = newGame()
screen = factory.new(game)
screen.index = 1  -- DEX, dimmed on a fresh save
press("a") screen:update(0) release()
T.eq(popped, 0, "selecting a dimmed app does not close the phone")
T.same(sounds, { "Tink" }, "a dimmed app plays Tink")

game = newGame()
screen = factory.new(game)
screen.index = 3  -- BAG, always live
press("a") screen:update(0) release()
T.eq(popped, 1, "selecting a live app closes the phone")
T.same(sounds, { "Press_AB" }, "A plays Press_AB")

-- ---- the stack pops before onSelect runs
--
-- Menu:update pops the stack BEFORE running the item's onSelect
-- (src/ui/Menu.lua:91-93), so a submenu's onCancel can push the phone back
-- on top of nothing. Two independent counters can't catch a reversal of
-- this order (both still end at 1 either way), so this records the actual
-- sequence of stack operations against the item's own onSelect marker.
game = newGame()
local events = {}
game.stack = {
  push = function() events[#events + 1] = "push" end,
  pop = function() events[#events + 1] = "pop" end,
}
screen = factory.new(game)
local bagIndex
for i, item in ipairs(screen.items) do
  if item.icon == "bag" then bagIndex = i end
end
T.check(bagIndex ~= nil, "BAG (icon 'bag') is present in the app list")
screen.items[bagIndex].onSelect = function() events[#events + 1] = "select" end
screen.index = bagIndex
press("a") screen:update(0) release()
T.eq(table.concat(events, ","), "pop,select",
  "the stack pops before onSelect runs")

run.release()
-- Rows whose screen ignores an onCancel option must NOT pop the phone, or
-- there is no way back to it: TownMap, ManagerState and LinkState carry no
-- reference to onCancel at all, and the save chain ends in plain text boxes.
-- Leaving the phone on the stack is what reveals it again when they close.
-- All three of those screens are isOpaque, so it is not drawn meanwhile.
local function selectByIcon(key)
  local g = newGame({ flags = { EVENT_GOT_POKEDEX = true },
                      party = { { species = "FIXMON_A" } },
                      inventory = { TOWN_MAP = 1 } })
  g.modStatus = { available = { "m" } }
  local scr = factory.new(g)
  for i, item in ipairs(scr.items) do
    if item.icon == key then scr.index = i end
  end
  press("a") scr:update(0) release()
  return popped
end

for _, key in ipairs({ "save", "map", "link", "mods" }) do
  T.eq(selectByIcon(key), 0,
    key .. " keeps the phone on the stack, so closing it comes back here")
end
for _, key in ipairs({ "dex", "pkmn", "bag", "id", "optn" }) do
  T.eq(selectByIcon(key), 1,
    key .. " pops the phone, because its screen reopens it on cancel")
end

T.finish("phone screen")
