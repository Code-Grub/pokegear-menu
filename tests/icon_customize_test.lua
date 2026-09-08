-- Standalone: luajit mods/pokegear_menu/tests/icon_customize_test.lua
--
-- The regression this file exists for: PhoneScreen's A handling used to
-- fire the instant `input:wasPressed("a")` fires, with no notion of a hold.
-- Giving a foreign row's icon a customize gesture on the same button a
-- short tap already uses (PhoneScreen.lua's _updateA) is easy to get wrong
-- in either direction -- a hold that also selects the row underneath it,
-- or a short tap that stops selecting because it now waits to see if it
-- becomes a hold.  This drives real frame-by-frame input, not the
-- press-then-immediately-release helper the other PhoneScreen tests use,
-- because a hold is defined by dt accumulating across several frames
-- while A stays down.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local PhoneScreen = dofile("mods/pokegear_menu/PhoneScreen.lua")
local M = {
  Layout = dofile("mods/pokegear_menu/Layout.lua"),
  Apps   = dofile("mods/pokegear_menu/Apps.lua"),
  Items  = dofile("mods/pokegear_menu/Items.lua"),
}

local modStub = { log = { warn = function() end, error = function() end } }

local pushed, sounds
local function depsFor()
  pushed, sounds = {}, {}
  return {
    screens = { push = function(game, id, opts) pushed[#pushed + 1] = { id = id, opts = opts } end },
    sound   = { play = function(_, name) sounds[#sounds + 1] = name end },
    -- the injector fixture's own trick: insert one foreign row before SAVE
    runtime = { call = function(_, fallback, game, items)
      local out = fallback(game, items)
      out[#out + 1] = { label = "INJECTED",
                         onSelect = function() game._foreignSelected = true end }
      return out
    end },
    markTrueColor = function() end,
  }
end

-- a real edge/level input stub: wasPressed fires only the frame a button
-- transitions up->down, isDown reflects whatever is held right now -- a
-- press()/release() pulse that never advances dt, like every other
-- PhoneScreen test uses, cannot exercise a hold at all
local down, prevDown = {}, {}
local function input()
  return {
    wasPressed = function(_, n) return down[n] == true and prevDown[n] ~= true end,
    isDown     = function(_, n) return down[n] == true end,
  }
end
local function tick(screen, dt)
  screen.game.input = input()
  screen:update(dt)
  prevDown = {}
  for k, v in pairs(down) do prevDown[k] = v end
end

local function gameStub()
  return {
    save = { party = {}, flags = {}, inventory = {}, player = { name = "RED" } },
    stack = { push = function() end, pop = function() end },
  }
end

-- ---- a short tap on the foreign row still selects it, exactly as any
-- other row does; the hold gesture must not add latency to an ordinary tap
local deps = depsFor()
local screen = PhoneScreen.build(modStub, M, deps).new(gameStub())
local injectedAt
for i, item in ipairs(screen.items) do
  if item.label == "INJECTED" then injectedAt = i end
end
T.check(injectedAt, "the injected row is present")
T.check(screen.items[injectedAt].foreign, "the injected row is tagged foreign")

screen.index = injectedAt
down = { a = true };  tick(screen, 0.016)
down = {};             tick(screen, 0.016)
T.check(screen.game._foreignSelected, "a short A tap still selects a foreign row")
T.eq(#pushed, 0, "a short tap does not open the icon picker")

-- ---- holding A past the threshold opens the picker instead of selecting
deps = depsFor()
screen = PhoneScreen.build(modStub, M, deps).new(gameStub())
screen.index = injectedAt
down = { a = true }
for _ = 1, 60 do tick(screen, 0.016) end -- 960ms, past the 900ms threshold
T.check(not screen.game._foreignSelected, "a long hold does not run the row's onSelect")
T.eq(#pushed, 1, "a long hold pushes exactly one screen")
T.eq(pushed[1] and pushed[1].id, "PokegearIconPicker", "it pushes the icon picker")
T.eq(pushed[1] and pushed[1].opts and pushed[1].opts.label, "INJECTED",
  "and passes the row's own label, which is how the picker finds it again")
down = {}
tick(screen, 0.016)
T.eq(#pushed, 1, "releasing after the picker already opened does not push a second one")

-- ---- the pushed opts.onChosen patches this exact item's icon, so the row
-- redraws with the new one the instant the picker closes, rather than
-- waiting for the phone to next close and rebuild self.items from the save
-- data the picker also writes
T.eq(screen.items[injectedAt].icon, "generic", "before the picker replies, still generic")
pushed[1].opts.onChosen("bolt")
T.eq(screen.items[injectedAt].icon, "bolt",
  "onChosen updates the live row in place, not just the saved override")

local function pushedPicker()
  for _, p in ipairs(pushed) do
    if p.id == "PokegearIconPicker" then return true end
  end
  return false
end

-- ---- one of the phone's own apps never offers the picker, no matter how
-- long A is held -- only a foreign row is customizable.  BAG's own A press
-- pushes BagMenu, same as any tap on it always has; that push is expected
-- and is not what this case is checking.
deps = depsFor()
screen = PhoneScreen.build(modStub, M, deps).new(gameStub())
local bagAt
for i, item in ipairs(screen.items) do
  if item.icon == "bag" then bagAt = i end
end
screen.index = bagAt
down = { a = true }
tick(screen, 0.016)
T.check(not pushedPicker(), "tapping a built-in app does not open the icon picker")
for _ = 1, 60 do tick(screen, 0.016) end
T.check(not pushedPicker(), "holding A on a built-in app never opens the icon picker")
down = {}

-- ---- moving the cursor mid-hold must not let the hold carry over onto
-- whatever the cursor lands on next
deps = depsFor()
screen = PhoneScreen.build(modStub, M, deps).new(gameStub())
screen.index = injectedAt
down = { a = true }
for _ = 1, 10 do tick(screen, 0.016) end -- armed, short of the threshold
screen.index = bagAt
for _ = 1, 60 do tick(screen, 0.016) end
down = {}
T.eq(#pushed, 0, "a hold started on one row cannot fire against a different one")

T.finish("icon customize")
