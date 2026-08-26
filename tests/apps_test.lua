-- Standalone: luajit mods/phone_start_menu/tests/apps_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Apps = dofile("mods/phone_start_menu/Apps.lua")

local pushed = {}
local deps = {
  screens = { push = function(_, id) pushed[#pushed + 1] = id end },
  sound = { play = function() end },
  save = function() end,
  link = function() end,
}

local function gameWith(overrides)
  local g = {
    save = { party = {}, flags = {}, inventory = {},
             player = { name = "RED" } },
    data = {},
    stack = { push = function() end, pop = function() end },
    modStatus = nil,
  }
  for k, v in pairs(overrides or {}) do g.save[k] = v end
  return g
end

local function byKey(items, key)
  for _, item in ipairs(items) do
    if item.icon == key then return item end
  end
end

-- a brand new save: the always-on apps are live, the gated ones are not
local items = Apps.build(gameWith(), deps)
T.eq(#items, 9, "nine apps, always")

T.check(byKey(items, "bag").enabled, "ITEM is always available")
T.check(byKey(items, "id").enabled, "the trainer card is always available")
T.check(byKey(items, "optn").enabled, "OPTION is always available")
T.check(byKey(items, "save").enabled, "SAVE is always available")

T.check(not byKey(items, "dex").enabled, "the dex is dimmed before Oak's gift")
T.check(not byKey(items, "pkmn").enabled, "POKéMON is dimmed with no party")
T.check(not byKey(items, "map").enabled, "the map is dimmed without the item")
T.check(not byKey(items, "link").enabled, "LINK is dimmed with no party")
T.check(not byKey(items, "mods").enabled, "MODS is dimmed with no mods")

-- hook-visible labels are exactly vanilla's, so insertBefore anchors resolve
T.eq(byKey(items, "bag").label, "ITEM", "the bag row is labelled ITEM")
T.eq(byKey(items, "save").label, "SAVE", "the save row is labelled SAVE")
T.eq(byKey(items, "optn").label, "OPTION", "the options row is labelled OPTION")
T.eq(byKey(items, "id").label, "RED", "the id row carries the player's name")

-- captions are separate from hook labels and fit five glyphs
for _, item in ipairs(items) do
  T.check(#item.display <= 3,
    "caption '" .. item.display .. "' leaves a readable gap to its neighbour")
end

-- each gate flips independently
items = Apps.build(gameWith({ flags = { EVENT_GOT_POKEDEX = true } }), deps)
T.check(byKey(items, "dex").enabled, "the dex lights up after Oak's gift")

items = Apps.build(gameWith({ party = { { species = "FIXMON_A" } } }), deps)
T.check(byKey(items, "pkmn").enabled, "POKéMON lights up with a party")
T.check(byKey(items, "link").enabled, "LINK lights up with a party")

items = Apps.build(gameWith({ inventory = { TOWN_MAP = 1 } }), deps)
T.check(byKey(items, "map").enabled, "the map lights up holding the TOWN MAP")

local g = gameWith()
g.modStatus = { available = { "some_mod" } }
items = Apps.build(g, deps)
T.check(byKey(items, "mods").enabled, "MODS lights up with a mod discovered")

-- selecting a live app reaches its screen; a dimmed one must not
pushed = {}
items = Apps.build(gameWith({ flags = { EVENT_GOT_POKEDEX = true } }), deps)
byKey(items, "dex").onSelect()
T.eq(pushed[1], "PokedexMenu", "the dex app opens the dex")

pushed = {}
items = Apps.build(gameWith(), deps)
byKey(items, "dex").onSelect()
T.eq(#pushed, 0, "a dimmed app opens nothing")

T.finish("apps")
