-- The two generated sheets and the drawing that reads them.
--
-- Both images load on first draw rather than at registration: the loader's
-- assets:image asserts on a graphics context (src/mods/Loader.lua:733), and
-- a headless load has none.  Deferring keeps `modkit validate` green.

local Icons = {}
Icons.__index = Icons

local ICON = 16
-- 4px of ink plus a 1px gutter.  The gutter is why the advance is 5 and
-- not 4: at a 4px advance adjacent glyphs touch and a caption is a blob.
-- Four glyphs at 5px is 20px, which fits the 21px cell -- that bounds how
-- much this font can draw legibly in one, not what Items.decorate actually
-- clips foreign captions to, which is that module's own constant.
local GLYPH_ADV, GLYPH_H = 5, 6
local GLYPH_ORDER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.- :"

-- the face is white on the sheet so it can be tinted; this is the
-- default ink for anything drawn on the phone's pale surfaces
local INK = { 0.14, 0.18, 0.18 }

Icons.INDEX = {
  dex = 1, pkmn = 2, bag = 3, id = 4, optn = 5,
  save = 6, map = 7, link = 8, mods = 9, generic = 10,
}

-- character to 0-based column in label_font.png
local GLYPH_AT = {}
for i = 1, #GLYPH_ORDER do
  GLYPH_AT[GLYPH_ORDER:sub(i, i)] = i - 1
end

function Icons.new(mod)
  return setmetatable({ mod = mod, failed = false }, Icons)
end

-- Load once, remember a failure so a missing sheet warns a single time
-- rather than once per frame.
function Icons:_sheets()
  if self.failed then return nil end
  if self.iconSheet and self.fontSheet then
    return self.iconSheet, self.fontSheet
  end
  local ok, iconSheet, fontSheet = pcall(function()
    return self.mod.assets:image("assets/icons.png"),
           self.mod.assets:image("assets/label_font.png")
  end)
  if not ok or not iconSheet or not fontSheet then
    self.failed = true
    self.mod.log:warn("could not load assets/icons.png or "
      .. "assets/label_font.png -- reinstall the mod; the phone draws "
      .. "without art this session")
    return nil
  end
  self.iconSheet, self.fontSheet = iconSheet, fontSheet
  self.iconQuads = {}
  for _, col in pairs(Icons.INDEX) do
    self.iconQuads[col] = love.graphics.newQuad(
      (col - 1) * ICON, 0, ICON, ICON,
      iconSheet:getWidth(), iconSheet:getHeight())
  end
  self.glyphQuads = {}
  for ch, col in pairs(GLYPH_AT) do
    self.glyphQuads[ch] = love.graphics.newQuad(
      col * GLYPH_ADV, 0, GLYPH_ADV, GLYPH_H,
      fontSheet:getWidth(), fontSheet:getHeight())
  end
  return self.iconSheet, self.fontSheet
end

function Icons:drawIcon(key, x, y, dim)
  local sheet = self:_sheets()
  if not sheet then return end
  local col = Icons.INDEX[key] or Icons.INDEX.generic
  local quad = self.iconQuads[col]
  if not quad then return end
  local r, g, b, a = love.graphics.getColor()
  love.graphics.setColor(1, 1, 1, dim and 0.4 or 1)
  love.graphics.draw(sheet, quad, x, y)
  love.graphics.setColor(r, g, b, a)
end

function Icons:labelWidth(text)
  return #tostring(text or "") * GLYPH_ADV
end

-- colour is optional and defaults to the dark ink.  The status bar
-- passes a light colour because it draws onto black; nothing else
-- needs to.
function Icons:drawLabel(text, x, y, dim, colour)
  local _, font = self:_sheets()
  if not font then return end
  local r, g, b, a = love.graphics.getColor()
  local c = colour or INK
  love.graphics.setColor(c[1], c[2], c[3], dim and 0.4 or 1)
  local upper = tostring(text or ""):upper()
  for i = 1, #upper do
    local quad = self.glyphQuads[upper:sub(i, i)] or self.glyphQuads[" "]
    if quad then
      love.graphics.draw(font, quad, x + (i - 1) * GLYPH_ADV, y)
    end
  end
  love.graphics.setColor(r, g, b, a)
end

return Icons
