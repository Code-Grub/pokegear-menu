-- The screen a long A-press over a mod's own row opens (PhoneScreen.lua's
-- _updateA).  Lets a player replace that row's fallback "?" with one of the
-- neutral icons in Icons.CUSTOM_ORDER, or put the "?" back.
--
-- The choice is saved by the row's label, not by anything that survives one
-- session on its own: Items.ownSet snapshots a fresh table every time the
-- phone opens, so table identity is gone by the time this screen could be
-- reopened, and label is the one thing Save.lua already trusts to find the
-- same row again across a rebuild.

local IconPicker = {}

function IconPicker.build(mod, M, deps)
  -- Icons is the MODULE, for its CUSTOM_ORDER list; icons is the drawing
  -- instance PhoneScreen also uses (M.icons, built once in main.lua).  The
  -- two are easy to conflate by name, so both are spelled out here rather
  -- than aliased to one local.
  local Layout, Icons, icons = M.Layout, M.Icons, M.icons

  local Screen = {}
  Screen.__index = Screen

  function Screen.new(game, opts)
    local self = setmetatable({}, Screen)
    self.game = game
    self.label = opts and opts.label
    self.onChosen = opts and opts.onChosen

    local overrides = (game.save and game.save.modIconOverrides) or {}
    local current = (self.label and overrides[self.label]) or "generic"
    self.index = 1
    for i, key in ipairs(Icons.CUSTOM_ORDER) do
      if key == current then self.index = i end
    end
    return self
  end

  function Screen:_move(delta)
    local n = #Icons.CUSTOM_ORDER
    self.index = ((self.index - 1 + delta) % n) + 1
  end

  function Screen:_confirm()
    local chosen = Icons.CUSTOM_ORDER[self.index]
    if self.label then
      local save = self.game.save
      save.modIconOverrides = save.modIconOverrides or {}
      -- "generic" is the way back to the fallback, not a stored choice: an
      -- override table that only ever grows would still be readable years
      -- after the mod it pointed at was uninstalled.
      if chosen == "generic" then
        save.modIconOverrides[self.label] = nil
      else
        save.modIconOverrides[self.label] = chosen
      end
    end
    -- This save write is what the choice survives on; onChosen (if the
    -- caller passed one) is only so the row updates before that -- the
    -- phone screen underneath was already built, and would otherwise keep
    -- drawing the old icon until it next closed and reopened.
    if self.onChosen then self.onChosen(chosen) end
    self.game.stack:pop()
  end

  function Screen:update(_)
    local input = self.game.input
    if input:wasPressed("right") then
      self:_move(1)
    elseif input:wasPressed("left") then
      self:_move(-1)
    elseif input:wasPressed("a") then
      deps.sound.play(self.game.data, "Press_AB")
      self:_confirm()
    elseif input:wasPressed("b") then
      deps.sound.play(self.game.data, "Press_AB")
      self.game.stack:pop()
    end
  end

  function Screen:draw()
    local L = Layout
    deps.markTrueColor(L.PHONE.x, L.PHONE.y, L.PHONE.w, L.PHONE.h)
    M.chrome:drawBody()
    M.chrome:drawStatus(self.game)

    for i, key in ipairs(Icons.CUSTOM_ORDER) do
      local x, y = L.cell(i)
      icons:drawIcon(key, x, y, false)
      if i == self.index then self:_drawCursor(x, y) end
    end

    local caption = tostring(self.label or "ICON"):sub(1, 8)
    local width = icons:labelWidth(caption)
    icons:drawLabel(caption,
      L.FOOTER.x + math.floor((L.FOOTER.w - width) / 2), L.FOOTER.y + 3, false)
    love.graphics.setColor(1, 1, 1, 1)
  end

  -- Identical to PhoneScreen's own cursor frame, duplicated rather than
  -- shared: it is six lines, and the two screens have no other reason to
  -- depend on each other.
  function Screen:_drawCursor(x, y)
    local pr, pg, pb, pa = love.graphics.getColor()
    local n = Layout.ICON + 2
    local cx, cy = x - 1, y - 1
    love.graphics.setColor(0.14, 0.18, 0.18, 1)
    love.graphics.rectangle("fill", cx + 1, cy, n - 2, 1)
    love.graphics.rectangle("fill", cx + 1, cy + n - 1, n - 2, 1)
    love.graphics.rectangle("fill", cx, cy + 1, 1, n - 2)
    love.graphics.rectangle("fill", cx + n - 1, cy + 1, 1, n - 2)
    love.graphics.setColor(pr, pg, pb, pa)
  end

  return { new = Screen.new }
end

return IconPicker
