-- Standalone: luajit mods/pokegear_menu/tests/layout_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local L = dofile("mods/pokegear_menu/Layout.lua")

-- the phone sits on the right of the 160x144 canvas, clear of both edges
T.eq(L.PHONE.x, 84, "phone body starts at x 84")
T.eq(L.PHONE.x + L.PHONE.w, 158, "phone body ends 2px clear of the right edge")
T.check(L.PHONE.y + L.PHONE.h <= 144, "phone body fits the canvas height")

-- the bezel is symmetric: 5px of body either side of the inner screen
T.eq(L.SCREEN.x - L.PHONE.x, 5, "left bezel is 5px")
T.eq((L.PHONE.x + L.PHONE.w) - (L.SCREEN.x + L.SCREEN.w), 5, "right bezel is 5px")

-- three columns of 21px fill the 64px screen with 1px to spare
T.eq(#L.COLS, 3, "three columns")
T.eq(#L.ROWS, 3, "three rows")
T.eq(L.COLS[1], L.SCREEN.x, "first column is flush with the screen")
T.eq(L.COLS[3] + L.CELL_W, L.SCREEN.x + L.SCREEN.w - 1, "third column fits")

-- slot 1 is top-left, slot 9 bottom-right, and the icon centres in its cell
local x1, y1 = L.cell(1)
T.eq(x1, L.COLS[1] + math.floor((L.CELL_W - L.ICON) / 2), "slot 1 icon centres")
T.eq(y1, L.ROWS[1], "slot 1 sits on the first row")
local x9, y9 = L.cell(9)
T.eq(y9, L.ROWS[3], "slot 9 sits on the last row")
T.check(x9 > x1, "slot 9 is right of slot 1")

-- the last row's content clears the page dots
T.check(L.ROWS[3] + L.ICON + 2 + 6 <= L.DOTS_Y, "row 3 content clears the dots")
T.check(L.DOTS_Y < L.FOOTER.y, "the dots sit above the footer")

-- paging
T.eq(L.pageCount(0), 1, "an empty list still has one page")
T.eq(L.pageCount(9), 1, "nine apps are one page")
T.eq(L.pageCount(10), 2, "ten apps are two pages")
T.eq(L.pageCount(18), 2, "eighteen apps are two pages")
T.eq(L.pageCount(19), 3, "nineteen apps are three pages")

local page, slot = L.locate(1)
T.eq(page, 1, "item 1 is on page 1") T.eq(slot, 1, "item 1 is slot 1")
page, slot = L.locate(9)
T.eq(page, 1, "item 9 is on page 1") T.eq(slot, 9, "item 9 is slot 9")
page, slot = L.locate(10)
T.eq(page, 2, "item 10 is on page 2") T.eq(slot, 1, "item 10 is slot 1")

T.finish("layout")
