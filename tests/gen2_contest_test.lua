-- Standalone: luajit mods/pokegear_menu/tests/gen2_contest_test.lua
--
-- The Bug Catching Contest.  src/ui/gen2/StartMenu.lua's visibleItems hides
-- the PACK and swaps SAVE for QUIT while one is running, and Gen2PackMenu
-- has no contest guard of its own, so the grid is the only thing standing
-- between a contestant and the bag the cart took away.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")

local deps = {
  screens = { push = function() end },
  sound = { play = function() end },
  startMenuItem = function(_, id) return id end,
  pokegear = function() end,
}

local function game(bugContest)
  return {
    save = {
      party = { {} },
      engineFlags = { [11] = true, [4] = true, [0] = true, [1] = true, [2] = true },
      inventory = {}, player = { name = "GOLD" },
      bugContest = bugContest,
    },
    data = {},
    stack = { push = function() end, pop = function() end },
    modStatus = { available = { "x" } },
  }
end

local function byIcon(list, icon)
  for _, item in ipairs(list) do
    if item.icon == icon then return item end
  end
end

-- Each dofile re-runs the chunk, so each one gets its own resolved-module
-- cache and can be handed a different BugContest (or none at all).
local function loadApps()
  return dofile("mods/pokegear_menu/Apps.lua")
end

-- ---- no BugContest module reachable at all
--
-- An engine with no src/core/gen2/ tree, which is every Gen 1 build and
-- every Gen 2 build older than the contest.  A gate that hard-required it
-- would take the whole grid down; "no contest" is the only safe answer.
package.loaded["src.core.gen2.BugContest"] = nil
local absent = loadApps()
local grid = absent.build(game(nil), deps, nil, absent.GEN2_DEFS)
T.eq(#grid, 9, "nine apps with no contest module on the engine")
T.check(byIcon(grid, "bag").enabled, "the PACK is live when nothing answers")
T.check(byIcon(grid, "save").enabled, "SAVE is live when nothing answers")

-- ---- the module is there and says no contest is running
--
-- The stand-in answers the way src/core/gen2/BugContest.lua does: off
-- save.bugContest.active, which the officer's script sets.
local asked = {}
package.loaded["src.core.gen2.BugContest"] = {
  isActive = function(save)
    asked[#asked + 1] = save
    return type(save) == "table" and (save.bugContest or {}).active == true
  end,
}

local Apps = loadApps()
grid = Apps.build(game({ active = false }), deps, nil, Apps.GEN2_DEFS)
T.eq(#grid, 9, "nine apps outside a contest")
T.check(byIcon(grid, "bag").enabled, "the PACK is live outside a contest")
T.check(byIcon(grid, "save").enabled, "SAVE is live outside a contest")
T.check(#asked > 0, "the gates actually asked BugContest")

-- ---- a contest is running
local running = Apps.build(game({ active = true }), deps, nil, Apps.GEN2_DEFS)
T.eq(#running, 9, "the grid is still nine apps during a contest")

local order = {}
for _, item in ipairs(running) do order[#order + 1] = item.icon end
T.eq(table.concat(order, ","),
  "dex,pkmn,bag,map,radio,phone,save,optn,mods",
  "the two gated apps dim in place rather than collapsing the grid")

T.check(not byIcon(running, "bag").enabled,
  "the PACK is dark during a contest, as the cart hides it")
T.check(not byIcon(running, "save").enabled,
  "SAVE is dark during a contest, where the cart offers QUIT instead")

-- and a dimmed row opens nothing, so the PACK is really unreachable
local opened = {}
local guarded = { screens = { push = function() end },
                  sound = { play = function() end },
                  startMenuItem = function(_, id) opened[#opened + 1] = id end,
                  pokegear = function() end }
local sealed = Apps.build(game({ active = true }), guarded, nil, Apps.GEN2_DEFS)
byIcon(sealed, "bag").onSelect()
byIcon(sealed, "save").onSelect()
T.eq(#opened, 0, "pressing A on either dimmed app opens nothing")

-- the other seven are untouched: a contest gates two rows, not the grid
for _, icon in ipairs({ "dex", "pkmn", "map", "radio", "phone", "optn", "mods" }) do
  T.check(byIcon(running, icon).enabled,
    icon .. " is unaffected by the contest")
end

-- ---- a BugContest that raises is still "no contest"
package.loaded["src.core.gen2.BugContest"] = {
  isActive = function() error("engine says no") end,
}
local broken = loadApps()
local survived = broken.build(game({ active = true }), deps, nil, broken.GEN2_DEFS)
T.check(byIcon(survived, "bag").enabled,
  "a BugContest that raises leaves the PACK live rather than crashing")
T.check(byIcon(survived, "save").enabled,
  "a BugContest that raises leaves SAVE live rather than crashing")

package.loaded["src.core.gen2.BugContest"] = nil

T.finish("gen2 contest")
