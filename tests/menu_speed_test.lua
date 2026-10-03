-- Standalone: luajit mods/pokegear_menu/tests/menu_speed_test.lua
--
-- Engine #2578 gives MENU SPEED to any screen marked isMenu, and Screens
-- stamps an instance whose factory carries the mark.  Vanilla Gen 1
-- StartMenu is marked, so the phone that replaces it has to be too, or it
-- keeps following OVERWORLD SPEED while every other menu follows MENU SPEED.
-- Gen 2's own menus are not marked, so the Gen 2 phone matches them.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Data = require("tests.modkit.fixtures").fresh()
local Gen = dofile("mods/pokegear_menu/Gen.lua")

local run = T.sdk.loadMod("mods/pokegear_menu", { data = Data })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")

local Screens = require("src.ui.Screens")
Screens.invalidate()

local game = { data = Data, save = { party = {}, flags = {}, inventory = {},
  money = 0, player = { name = "RED" } },
  stack = { push = function() end, pop = function() end },
  input = { wasPressed = function() return false end,
            isDown = function() return false end } }

T.eq(Screens.get(game, "StartMenu").isMenu, true,
  "the Gen 1 phone is a menu, like the StartMenu it replaces")
T.eq(Screens.get(game, Gen.GEN1.iconPickerId).isMenu, true,
  "and so is its icon picker")
T.check(not Screens.get(game, "Gen2StartMenu").isMenu,
  "the Gen 2 phone stays unmarked, matching Gen 2's own menus")

run.release()
Screens.invalidate()
T.finish("pokegear_menu menu_speed")
