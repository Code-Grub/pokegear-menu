-- Standalone: luajit mods/pokegear_menu/tests/reopen_id_test.lua
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

local pushed
-- Items.compose indexes runtime.call before pcall runs, so a stub is
-- required rather than optional; this one is the identity chain.
local function depsFor()
  pushed = {}
  return {
    screens = { push = function(_, id) pushed[#pushed + 1] = id end },
    sound   = { play = function() end },
    runtime = { call = function(_, fallback, game, items)
      return fallback(game, items)
    end },
    markTrueColor = function() end,
    save = function() end,
    link = function() end,
    startMenuItem = function() end,
    pokegear = function() end,
  }
end

local function gameStub()
  return {
    save = { party = {}, flags = {}, inventory = {},
             player = { name = "RED" }, startMenuIndex = nil },
    data = {},
    stack = { push = function() end, pop = function() end },
    modStatus = nil,
  }
end

-- no profile: the old three-argument behaviour, unchanged
local deps = depsFor()
local screen = PhoneScreen.build(modStub, M, deps).new(gameStub())
T.eq(#screen.items, 10, "no profile still builds the Gen 1 ten")

-- a profile with an empty def list builds an empty grid, which proves the
-- fourth argument reaches Apps.build at all
deps = depsFor()
local empty = PhoneScreen.build(modStub, M, deps,
  { name = "gen2", reopenId = "Gen2StartMenu", defs = {} }).new(gameStub())
T.eq(#empty.items, 0, "an empty profile builds an empty grid")

-- and that the reopen closure pushes the profile's id, not "StartMenu".
-- The Gen 1 SAVE app is keepOpen, so drive reopen through a def that is not.
deps = depsFor()
local probe = { {
  key = "probe", display = "PRB",
  label = function() return "PROBE" end,
  gate = function() return true end,
  open = function(_, reopen) reopen() end,
} }
local gen2 = PhoneScreen.build(modStub, M, deps,
  { name = "gen2", reopenId = "Gen2StartMenu", defs = probe }).new(gameStub())
gen2.items[1].onSelect()
T.eq(table.concat(pushed, ","), "Gen2StartMenu",
  "the reopen closure pushes the profile's id")

T.finish("reopen id")
