-- Pure geometry for the phone, in the 160x144 UI canvas.  No love calls and
-- no engine requires, so it can be dofile'd straight into a test.
--
-- The numbers are read off the reference mockup at its native 1x scale: the
-- mockup is a 3x upscale of the Game Boy canvas, so its pixels transfer
-- directly rather than being rescaled by eye.

local Layout = {}

Layout.PHONE  = { x = 84, y = 1,   w = 74, h = 142 }
Layout.SCREEN = { x = 89, y = 13,  w = 64, h = 112 }
Layout.STATUS = { x = 89, y = 13,  w = 64, h = 11 }
Layout.FOOTER = { x = 89, y = 125, w = 64, h = 12 }

Layout.COLS = { 89, 110, 131 }
Layout.ROWS = { 28, 58, 88 }

Layout.CELL_W  = 21
Layout.ICON    = 16
Layout.LABEL_H = 6
-- 2px of air between an icon and its caption
Layout.LABEL_GAP = 2
Layout.PER_PAGE = 9
Layout.DOTS_Y   = 116

-- top-left of the icon for a 1-based slot, reading left to right, top to
-- bottom.  The icon centres horizontally in its 21px cell; vertically it
-- sits on the row line, with the caption hanging below it.
function Layout.cell(slot)
  local i = slot - 1
  local col = Layout.COLS[(i % 3) + 1]
  local row = Layout.ROWS[math.floor(i / 3) + 1]
  return col + math.floor((Layout.CELL_W - Layout.ICON) / 2), row
end

-- where a caption baseline starts for a slot
function Layout.labelPos(slot)
  local x, y = Layout.cell(slot)
  return x, y + Layout.ICON + Layout.LABEL_GAP
end

-- an empty list still occupies one page, so the grid never renders "page 0"
function Layout.pageCount(n)
  if n <= 0 then return 1 end
  return math.ceil(n / Layout.PER_PAGE)
end

-- 1-based item index to its page and its slot within that page
function Layout.locate(index)
  local i = index - 1
  return math.floor(i / Layout.PER_PAGE) + 1, (i % Layout.PER_PAGE) + 1
end

return Layout
