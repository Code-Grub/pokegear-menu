-- Standalone: luajit mods/phone_start_menu/tests/chrome_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Chrome = dofile("mods/phone_start_menu/Chrome.lua")
local Layout = dofile("mods/phone_start_menu/Layout.lua")
local Icons = dofile("mods/phone_start_menu/Icons.lua")

-- clock formatting is pure, so assert it directly
T.eq(Chrome.clockText({ hour = 0,  min = 0 }),  "12:00", "midnight reads 12:00")
T.eq(Chrome.clockText({ hour = 12, min = 0 }),  "12:00", "noon reads 12:00")
T.eq(Chrome.clockText({ hour = 13, min = 5 }),  "1:05",  "13:05 reads 1:05")
T.eq(Chrome.clockText({ hour = 9,  min = 47 }), "9:47",  "no leading zero on the hour")
T.eq(Chrome.clockText(nil), "12:00", "an unreadable clock falls back")

-- the link test mirrors src/core/Game.lua:232
T.check(not Chrome.linkLive({}), "no link session reads as offline")
T.check(Chrome.linkLive({ linkSession = {} }), "a link session reads as online")
T.check(Chrome.linkLive({ linkNet = { closed = false } }),
  "an open link socket reads as online")
T.check(not Chrome.linkLive({ linkNet = { closed = true } }),
  "a closed link socket reads as offline")

-- drawing must never raise, with or without art
local fakeMod = {
  path = "mods/phone_start_menu",
  assets = { image = function(_, rel)
    return love.graphics.newImage("mods/phone_start_menu/" .. rel)
  end },
  log = { warn = function() end, error = function() end },
}
local chrome = Chrome.new(Layout, Icons.new(fakeMod))

local ok, err = pcall(function() chrome:drawBody() end)
T.check(ok, "drawing the body succeeds: " .. tostring(err))

ok, err = pcall(function() chrome:drawStatus({}) end)
T.check(ok, "drawing the status bar succeeds: " .. tostring(err))

ok, err = pcall(function() chrome:drawStatus({ linkSession = {} }) end)
T.check(ok, "drawing an online status bar succeeds: " .. tostring(err))

ok, err = pcall(function() chrome:drawFooter() end)
T.check(ok, "drawing the footer succeeds: " .. tostring(err))

ok, err = pcall(function() chrome:drawDots(1, 1) end)
T.check(ok, "drawing one page of dots succeeds: " .. tostring(err))

ok, err = pcall(function() chrome:drawDots(2, 3) end)
T.check(ok, "drawing three pages of dots succeeds: " .. tostring(err))

T.finish("chrome")
