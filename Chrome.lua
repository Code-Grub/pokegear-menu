-- The phone itself: bezel, status bar, footer plate, page dots.
--
-- Colours are the mockup's, written as literals rather than pulled from a
-- palette record, because the whole phone rect is re-blit unshaded through
-- PaletteFX.markTrueColor and so never passes through the shade remap.

local Chrome = {}
Chrome.__index = Chrome

local BODY    = { 0.83, 0.80, 0.68 }
local BODY_HI = { 0.93, 0.91, 0.82 }
local OUTLINE = { 0.14, 0.18, 0.18 }
local SCREEN  = { 0.94, 0.95, 0.90 }
local BAR     = { 0.11, 0.14, 0.14 }
local BAR_INK = { 0.90, 0.92, 0.88 }
local DOT_ON  = { 0.20, 0.26, 0.26 }
local DOT_OFF = { 0.62, 0.66, 0.60 }

local function rect(colour, x, y, w, h)
  love.graphics.setColor(colour[1], colour[2], colour[3], 1)
  love.graphics.rectangle("fill", x, y, w, h)
end

-- Corner rounding, pixel-art style: per-row insets, not a real arc.  What
-- sits behind the phone is the live overworld rather than a fill, so a
-- corner has to be NOT DRAWN; it cannot be painted over afterwards.
-- CORNER[r] lists the inset for each of the top r rows, mirrored at the
-- bottom.  Radius 2 gives the 2/1 step that reads as a soft corner at this
-- scale without looking chamfered.
local CORNER = { [1] = { 1 }, [2] = { 2, 1 }, [3] = { 3, 2, 1 } }
local BODY_R, SCREEN_R = 2, 1

-- Inset for row i (0-based) of a shape h tall at radius r.  Exposed for
-- testing: the drawing itself is unassertable through the love stub.
function Chrome.cornerInset(r, i, h)
  local steps = CORNER[r]
  if not steps or i < 0 or i >= h then return 0 end
  if i < #steps then return steps[i + 1] end
  local fromBottom = h - 1 - i
  if fromBottom < #steps then return steps[fromBottom + 1] end
  return 0
end

-- Drawn as the two curved caps plus one full-width middle, so a 142px tall
-- body costs five rectangles rather than 142.
local function roundRect(colour, x, y, w, h, r)
  local steps = CORNER[r]
  if not steps or h < r * 2 then return rect(colour, x, y, w, h) end
  for i = 0, r - 1 do
    local inset = steps[i + 1]
    rect(colour, x + inset, y + i, w - inset * 2, 1)
    rect(colour, x + inset, y + h - 1 - i, w - inset * 2, 1)
  end
  rect(colour, x, y + r, w, h - r * 2)
end

function Chrome.new(layout, icons)
  return setmetatable({ L = layout, icons = icons }, Chrome)
end

-- 12-hour clock, no leading zero, matching the mockup's "12:00".
-- A nil or malformed table falls back rather than raising: the START menu
-- is the only route to SAVE and must always open.
function Chrome.clockText(now)
  if type(now) ~= "table" or type(now.hour) ~= "number"
     or type(now.min) ~= "number" then
    return "12:00"
  end
  local hour = now.hour % 12
  if hour == 0 then hour = 12 end
  return ("%d:%02d"):format(hour, now.min % 60)
end

-- the same test the engine uses at src/core/Game.lua:232
function Chrome.linkLive(game)
  if type(game) ~= "table" then return false end
  if game.linkSession then return true end
  local net = game.linkNet
  return (net ~= nil and not net.closed) and true or false
end

-- Every public draw brackets itself with the colour it found, the way
-- Icons.lua does.  The engine fences a mod's whole render callback in
-- push("all")/pop(), so a leak here cannot reach the engine, but it can
-- reach whatever this mod draws next inside the same callback.
function Chrome:drawBody()
  local cr, cg, cb, ca = love.graphics.getColor()
  local P, S = self.L.PHONE, self.L.SCREEN
  roundRect(OUTLINE, P.x, P.y, P.w, P.h, BODY_R)
  roundRect(BODY, P.x + 1, P.y + 1, P.w - 2, P.h - 2, BODY_R)
  -- a one-pixel highlight down the left edge gives the body its moulding.
  -- It starts below the corner curve and ends above it, or it would poke
  -- out past the rounded edge.
  rect(BODY_HI, P.x + 1, P.y + 1 + BODY_R, 1, P.h - 2 - BODY_R * 2)
  -- earpiece slot and lens, above the screen
  rect(OUTLINE, P.x + 24, P.y + 5, 18, 2)
  rect(OUTLINE, P.x + 62, P.y + 4, 4, 4)
  roundRect(OUTLINE, S.x - 1, S.y - 1, S.w + 2, S.h + 2, SCREEN_R)
  roundRect(SCREEN, S.x, S.y, S.w, S.h, SCREEN_R)
  love.graphics.setColor(cr, cg, cb, ca)
end

function Chrome:drawStatus(game)
  local cr, cg, cb, ca = love.graphics.getColor()
  local B = self.L.STATUS
  rect(BAR, B.x, B.y, B.w, B.h)
  local okTime, now = pcall(os.date, "*t")
  -- light ink: the bar is near black, and the face is white on the
  -- sheet so it tints to whatever is asked for
  self.icons:drawLabel(Chrome.clockText(okTime and now or nil),
                       B.x + 3, B.y + 3, false, BAR_INK)

  -- wifi: three rising bars, hollow when there is no link session
  local live = Chrome.linkLive(game)
  local wx = B.x + B.w - 22
  for i = 1, 3 do
    local h = i * 2
    local colour = live and BAR_INK or DOT_OFF
    rect(colour, wx + (i - 1) * 3, B.y + 8 - h, 2, h)
  end

  -- a solid cell plus a terminal nub.  Always full, so there is no
  -- separate hollow and fill: painting one inside the other would draw
  -- ink over ink.
  local bx = B.x + B.w - 11
  rect(BAR_INK, bx, B.y + 3, 8, 5)
  rect(BAR_INK, bx + 8, B.y + 4, 1, 3)
  love.graphics.setColor(cr, cg, cb, ca)
end

function Chrome:drawFooter()
  local cr, cg, cb, ca = love.graphics.getColor()
  -- No plate behind the word: drawBody already fills this band with the
  -- body colour, so the name sits straight on the phone's face.
  local F = self.L.FOOTER
  local text = "PHONE"
  local x = F.x + math.floor((F.w - self.icons:labelWidth(text)) / 2)
  self.icons:drawLabel(text, x, F.y + 3, false)
  love.graphics.setColor(cr, cg, cb, ca)
end

-- Dots render only when there is more than one page, so an install with no
-- other UI mods matches the mockup exactly.
function Chrome:drawDots(page, pages)
  if (pages or 1) <= 1 then return end
  local cr, cg, cb, ca = love.graphics.getColor()
  local S = self.L.SCREEN
  local span = pages * 5 - 2
  local x = S.x + math.floor((S.w - span) / 2)
  for i = 1, pages do
    rect(i == page and DOT_ON or DOT_OFF, x + (i - 1) * 5, self.L.DOTS_Y, 3, 3)
  end
  love.graphics.setColor(cr, cg, cb, ca)
end

return Chrome
