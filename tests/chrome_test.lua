-- Standalone: luajit mods/pokegear_menu/tests/chrome_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local T = require("tests.modkit")
local Chrome = dofile("mods/pokegear_menu/Chrome.lua")
local Layout = dofile("mods/pokegear_menu/Layout.lua")
local Icons = dofile("mods/pokegear_menu/Icons.lua")

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
  path = "mods/pokegear_menu",
  assets = { image = function(_, rel)
    return love.graphics.newImage("mods/pokegear_menu/" .. rel)
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

-- Colour restoration is genuinely assertable: love_stub tracks real
-- setColor/getColor state even though its rectangle/draw are no-ops.
-- Without this, a leak is invisible to the suite.
local function leaks(fn)
  love.graphics.setColor(0.25, 0.5, 0.75, 1)
  fn()
  local r, g, b, a = love.graphics.getColor()
  return not (r == 0.25 and g == 0.5 and b == 0.75 and a == 1)
end

T.check(not leaks(function() chrome:drawBody() end),
  "drawBody restores the colour it found")
T.check(not leaks(function() chrome:drawStatus({}) end),
  "drawStatus restores the colour it found")
T.check(not leaks(function() chrome:drawFooter() end),
  "drawFooter restores the colour it found")
T.check(not leaks(function() chrome:drawDots(2, 3) end),
  "drawDots restores the colour it found")
T.check(not leaks(function() chrome:drawDots(1, 1) end),
  "drawDots restores the colour on its early return")

-- Corner rounding is per-row insets, and those numbers are the only
-- assertable part: love_stub's rectangle is a no-op, so a wrong curve
-- draws nothing a test can see.
T.eq(Chrome.cornerInset(2, 0, 20), 2, "radius 2 insets the top row by 2")
T.eq(Chrome.cornerInset(2, 1, 20), 1, "and the next row by 1")
T.eq(Chrome.cornerInset(2, 2, 20), 0, "rows below the curve are full width")
T.eq(Chrome.cornerInset(2, 19, 20), 2, "the bottom row mirrors the top")
T.eq(Chrome.cornerInset(2, 18, 20), 1, "and so does the row above it")
T.eq(Chrome.cornerInset(1, 0, 10), 1, "radius 1 insets exactly one row")
T.eq(Chrome.cornerInset(1, 1, 10), 0, "and nothing below it")
T.eq(Chrome.cornerInset(0, 0, 10), 0, "radius 0 leaves a square corner")
T.eq(Chrome.cornerInset(2, -1, 20), 0, "a row before the shape insets nothing")
T.eq(Chrome.cornerInset(2, 20, 20), 0, "nor does one past its end")

T.finish("chrome")
