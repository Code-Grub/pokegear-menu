-- Standalone: luajit mods/phone_start_menu/tests/paging_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Data = require("tests.modkit.fixtures").fresh()

-- loading the injector alongside pushes the list to ten rows
local run = T.sdk.loadMods({ "mods/phone_start_menu",
                             "mods/phone_start_menu/tests/fixtures/injector_mod" },
                           { data = Data })
T.eq(#run.errors, 0, "both mods load clean (" .. tostring(run.errors[1]) .. ")")

local Screens = require("src.ui.Screens")
Screens.invalidate()

local held = {}
local game = {
  data = Data,
  save = { party = {}, flags = {}, inventory = {}, player = { name = "RED" } },
  stack = { push = function() end, pop = function() end },
  input = { wasPressed = function(_, n) return held[n] == true end,
            isDown = function() return false end },
}

local screen = Screens.get(game, "StartMenu").new(game)
T.eq(#screen.items, 10, "the injected row makes ten")
T.eq(screen:pageCount(), 2, "ten apps are two pages")
T.eq(screen.page, 1, "the phone opens on page one")

-- R flips to page two
held = { r = true } screen:update(0) held = {}
T.eq(screen.page, 2, "R flips to page two")
T.eq(screen.index, 10, "R lands on the tenth app")

-- and walking forward from the last app wraps to the first
held = { right = true } screen:update(0) held = {}
T.eq(screen.index, 1, "walking off the end wraps to the first app")
T.eq(screen.page, 1, "which is back on page one")

local ok, err = pcall(function() screen:draw() end)
T.check(ok, "drawing a two-page phone succeeds: " .. tostring(err))

run.release()
T.finish("paging")
