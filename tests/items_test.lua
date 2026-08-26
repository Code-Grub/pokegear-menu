-- Standalone: luajit mods/phone_start_menu/tests/items_test.lua
--
-- The regression this file exists for: claiming the StartMenu id stops the
-- builtin from running, and with it the ui.start_menu.items call at
-- src/ui/StartMenu.lua:130.  If the phone does not re-run that hook itself,
-- every other mod's injected row vanishes silently.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Items = dofile("mods/phone_start_menu/Items.lua")
local Apps = dofile("mods/phone_start_menu/Apps.lua")

local deps = {
  screens = { push = function() end },
  sound = { play = function() end },
  save = function() end,
  link = function() end,
}

local function newGame()
  return { save = { party = {}, flags = {}, inventory = {},
                    player = { name = "RED" } },
           data = {}, stack = { push = function() end, pop = function() end } }
end

-- ---- with no other mod loaded, the list passes through unchanged
local Data = require("tests.modkit.fixtures").fresh()
local run = T.sdk.loadMod("mods/phone_start_menu", { data = Data })
T.eq(#run.errors, 0, "the phone loads clean (" .. tostring(run.errors[1]) .. ")")

local Runtime = require("src.mods.Runtime")
local game = newGame()
local composed = Items.compose(game, Apps.build(game, deps), Runtime)
T.eq(#composed, 9, "nine apps with no other mod loaded")
run.release()

-- ---- with an injector loaded, its row survives
Data = require("tests.modkit.fixtures").fresh()
run = T.sdk.loadMods({ "mods/phone_start_menu",
                       "mods/phone_start_menu/tests/fixtures/injector_mod" },
                     { data = Data })
T.eq(#run.errors, 0, "both mods load clean (" .. tostring(run.errors[1]) .. ")")

game = newGame()
local apps = Apps.build(game, deps)

-- the list handed to the hook must carry vanilla's labels, or the
-- injector's insertBefore("SAVE", ...) anchor will not resolve
local labels = {}
for _, item in ipairs(apps) do labels[item.label] = true end
T.check(labels["SAVE"], "the hook sees a row labelled exactly SAVE")
T.check(labels["OPTION"], "the hook sees a row labelled exactly OPTION")
T.check(labels["ITEM"], "the hook sees a row labelled exactly ITEM")

composed = Items.compose(game, apps, Runtime)
T.eq(#composed, 10, "the injected row survives")

local found, position
for i, item in ipairs(composed) do
  if item.label == "INJECTED" then found, position = item, i end
end
T.check(found, "the injected row is present by label")

-- and it landed where the injector asked: immediately before SAVE
local saveAt
for i, item in ipairs(composed) do
  if item.label == "SAVE" then saveAt = i end
end
-- The phone keeps its own nine on page one and pushes every foreign row
-- after them, deliberately overriding where the injector asked to sit: the
-- grid is a fixed home screen and a row landing at slot six would shift
-- SAVE, MAP, LINK and MODS for as long as that mod stayed installed.  The
-- row is never dropped, only moved.
T.eq(position, 10, "the injected row is pushed past the nine built-ins")
T.check(position > saveAt, "so it no longer displaces SAVE")
T.eq(saveAt, 6, "and SAVE keeps its own slot")
-- membership is by identity, not label: mod.ui's insert helpers mutate the
-- list in place and return the same table, so a set snapshotted after the
-- hook would count every injected row as one of ours
local ownOrder = {}
for i = 1, 9 do ownOrder[#ownOrder + 1] = composed[i].display end
T.eq(table.concat(ownOrder, ","), "DEX,PKM,BAG,ID,OPT,SAV,MAP,LNK,MOD",
  "page one is exactly the nine built-in apps, in their fixed order")

-- a foreign row must be renderable: it needs a caption and an icon.
-- Guarded: without the `if`, a regression that loses the row entirely
-- crashes here on a nil index, which aborts the suite before the fallback
-- cases below ever run and lets one regression hide another.
if found then
  T.check(found.icon == "generic", "a foreign row gets the generic icon")
  T.check(found.display and #found.display > 0, "a foreign row gets a caption")
  T.check(#found.display <= 3, "a foreign caption is truncated to the cell")
  T.check(found.enabled, "a foreign row is selectable")
end

run.release()

-- ---- a wrapper returning junk must not take the menu down, and must say so
local composedFromJunk, junkWhy = Items.compose(newGame(),
  Apps.build(newGame(), deps), { call = function() return "not a table" end })
T.eq(#composedFromJunk, 9, "a bad hook result falls back to the app list")
T.check(junkWhy and junkWhy:find("not a table"),
  "and reports why, so the screen can log it: " .. tostring(junkWhy))

-- ---- a chain that THROWS is the pcall's real justification.  Hooks.lua
-- already absorbs an ordinary throwing wrapper, so without this case the
-- pcall could be deleted and every other check would stay green.
local composedFromThrow, throwWhy = Items.compose(newGame(),
  Apps.build(newGame(), deps), { call = function() error("boom", 0) end })
T.eq(#composedFromThrow, 9, "a throwing hook chain falls back to the app list")
T.check(throwWhy and throwWhy:find("threw"),
  "and reports that it threw: " .. tostring(throwWhy))

-- ---- a phone-aware mod supplying its own `display` bypasses the fill-when-
-- nil path, and PhoneScreen's centring subtracts the caption width from the
-- cell with no lower bound: an over-long supplied caption drew outside the
-- phone body entirely, over the live overworld.  decorate must clip every
-- display, supplied or not, not just the ones it fills in itself.
local overLong = Items.decorate(
  { { label = "X", display = "WAYTOOLONGCAPTION" } })
T.eq(overLong[1].display, "WAY",
  "a supplied over-long display is clipped to MAX_CAPTION like a filled-in one")

T.finish("items")
