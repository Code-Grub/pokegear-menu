-- Standalone: luajit mods/pokegear_menu/tests/gen2_apps_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Apps = dofile("mods/pokegear_menu/Apps.lua")

local items, cards
local deps = {
  screens = { push = function() end },
  sound = { play = function() end },
  startMenuItem = function(_, id) items[#items + 1] = id end,
  pokegear = function(_, card) cards[#cards + 1] = card end,
}

-- everything unlocked: the dex, the gear and all three cards
local function fullGame()
  return {
    save = {
      party = { {} },
      engineFlags = { [11] = true, [4] = true,
                      [0] = true, [1] = true, [2] = true },
      inventory = {}, player = { name = "GOLD" },
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

local grid = Apps.build(fullGame(), deps, nil, Apps.GEN2_DEFS)
T.eq(#grid, 9, "nine apps on Gen 2 too")

-- grid order, reading left to right, top to bottom
local order = {}
for _, item in ipairs(grid) do order[#order + 1] = item.icon end
T.eq(table.concat(order, ","),
  "dex,pkmn,bag,map,radio,phone,save,optn,mods",
  "DEX PKM PAK / MAP RAD PHN / SAV OPT MOD")

-- the six ordinary apps delegate to Gen 2's own dispatch
for _, pair in ipairs({
  { "dex", "pokedex" }, { "pkmn", "pokemon" }, { "bag", "pack" },
  { "save", "save" }, { "optn", "option" }, { "mods", "mods" },
}) do
  items = {}
  byIcon(grid, pair[1]).onSelect()
  T.eq(table.concat(items, ","), pair[2],
    pair[1] .. " delegates to openStartMenuItem(" .. pair[2] .. ")")
end

-- the three card apps open the real gear, pinned
for _, pair in ipairs({
  { "map", "map" }, { "radio", "radio" }, { "phone", "phone" },
}) do
  cards = {}
  byIcon(grid, pair[1]).onSelect()
  T.eq(table.concat(cards, ","), pair[2],
    pair[1] .. " opens the " .. pair[2] .. " card")
end

-- every Gen 2 app keeps the phone on the stack: closeStartMenuItem pops the
-- pushed screen and reveals it, so nothing re-pushes
for _, item in ipairs(grid) do
  T.check(item.keepOpen, item.icon .. " leaves the phone on the stack")
end

-- PAK draws the bag icon under its own key
T.eq(byIcon(grid, "bag").display, "PAK", "the PACK is captioned PAK")

-- the three card apps carry the cart's own card labels, not Gen 1's item name
T.eq(byIcon(grid, "map").label, "MAP", "the map app uses the cart's MAP")
T.eq(byIcon(grid, "radio").label, "RADIO", "the radio app uses the cart's RADIO")
T.eq(byIcon(grid, "phone").label, "PHONE", "the phone app uses the cart's PHONE")

-- a fresh save dims what has not been earned
local fresh = { save = { party = {}, engineFlags = {}, inventory = {},
                         player = { name = "GOLD" } },
                data = {}, stack = {}, modStatus = nil }
local new = Apps.build(fresh, deps, nil, Apps.GEN2_DEFS)
T.eq(#new, 9, "a fresh save still shows nine apps")
T.check(byIcon(new, "bag").enabled, "the PACK is there from the start")
T.check(not byIcon(new, "dex").enabled, "the dex is dark before Oak")
T.check(not byIcon(new, "map").enabled, "MAP is dark before the Guide Gent")
T.check(not byIcon(new, "radio").enabled, "RADIO is dark before the quiz")
T.check(not byIcon(new, "phone").enabled, "PHONE is dark before Mom")
T.check(byIcon(new, "save").enabled, "SAVE always works")

T.finish("gen2 apps")
