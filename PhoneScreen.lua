-- The screen the registry hands back for "StartMenu".
--
-- Not opaque: src/core/StateStack.lua picks its draw floor from that flag,
-- so leaving it unset keeps the overworld drawing underneath, which is both
-- vanilla Menu behaviour and what the mockup shows.

local PhoneScreen = {}

local function clamp(n, lo, hi)
  if n < lo then return lo end
  if n > hi then return hi end
  return n
end

function PhoneScreen.build(mod, M, deps, profile)
  local Layout, Apps, Items = M.Layout, M.Apps, M.Items
  -- Which id this factory was registered under.  A Gen 1 boot never resolves
  -- "Gen2StartMenu" and a Gen 2 boot never resolves "StartMenu", so the
  -- profile is settled at registration and never tested for at runtime.
  local reopenId = (profile and profile.reopenId) or "StartMenu"
  local defs = profile and profile.defs

  local Screen = {}
  Screen.__index = Screen

  function Screen.new(game)
    local self = setmetatable({}, Screen)
    self.game = game

    local function reopen() deps.screens.push(game, reopenId) end
    local apps = Apps.build(game, deps, reopen, defs)
    local composed, hookProblem = Items.compose(game, apps, deps.runtime)
    -- vanilla logs the same condition at src/ui/StartMenu.lua:128-131; the
    -- screen is the layer that owns a mod.log, so it does the reporting
    if hookProblem then
      mod.log:warn("%s -- showing the built-in apps; a mod wrapping "
        .. "ui.start_menu.items is misbehaving and its rows are missing "
        .. "this session; update or disable the other mod that wraps "
        .. "ui.start_menu.items", hookProblem)
    end
    self.items = composed
    if #self.items == 0 then
      -- cannot happen with the nine built-ins, but a wrapper may have
      -- emptied the list; an empty phone would be a dead end
      mod.log:warn("the start menu item list came back empty -- a mod "
        .. "wrapping ui.start_menu.items removed every row; showing the "
        .. "built-in apps instead; update or disable the other mod that "
        .. "wraps ui.start_menu.items")
      self.items = Items.decorate(apps)
    end

    self.index = clamp(game.save.startMenuIndex or 1, 1, #self.items)
    self.page = (Layout.locate(self.index))
    return self
  end

  function Screen:pageCount()
    return Layout.pageCount(#self.items)
  end

  -- Move by a whole-grid delta, wrapping through the list.  Wrapping on the
  -- flat index rather than per-page means walking off the bottom of page one
  -- lands on page two, which is what a grid of apps should do.
  function Screen:_move(delta)
    local n = #self.items
    if n == 0 then return end
    self.index = ((self.index - 1 + delta) % n) + 1
    self.page = (Layout.locate(self.index))
  end

  function Screen:update(_)
    local input = self.game.input
    if input:wasPressed("right") then
      self:_move(1)
    elseif input:wasPressed("left") then
      self:_move(-1)
    elseif input:wasPressed("down") then
      self:_move(3)
    elseif input:wasPressed("up") then
      self:_move(-3)
    elseif input:wasPressed("r") then
      self:_move(Layout.PER_PAGE)
    elseif input:wasPressed("l") then
      self:_move(-Layout.PER_PAGE)
    elseif input:wasPressed("a") then
      local item = self.items[self.index]
      if item and item.enabled == false then
        deps.sound.play(self.game.data, "Tink")
      elseif item then
        deps.sound.play(self.game.data, "Press_AB")
        -- Menu pops before running onSelect (src/ui/Menu.lua:93-94), so a
        -- submenu's onCancel can push the phone back on top of nothing.
        --
        -- keepOpen rows are the exception, exactly as in Menu (:91-92): the
        -- phone stays on the stack, and closing what the row opened reveals
        -- it again.  That is the only way back for a screen that ignores an
        -- onCancel option, which TownMap, ManagerState and LinkState all do.
        if not item.keepOpen then self.game.stack:pop() end
        if item.onSelect then item.onSelect() end
      end
    elseif input:wasPressed("b") or input:wasPressed("start") then
      -- the start menu's mask watches START (draw_start_menu.asm), and only
      -- the A/B branch replays the beep, so START closes silently
      if input:wasPressed("b") then
        deps.sound.play(self.game.data, "Press_AB")
      end
      self.game.stack:pop()
    end
    self.game.save.startMenuIndex = self.index
  end

  function Screen:draw()
    local L = Layout
    -- the whole phone is re-blit unshaded, so it keeps the mockup's colours
    -- while the overworld behind it stays on its Game Boy palette
    deps.markTrueColor(L.PHONE.x, L.PHONE.y, L.PHONE.w, L.PHONE.h)

    M.chrome:drawBody()
    M.chrome:drawStatus(self.game)

    local pages = self:pageCount()
    local first = (self.page - 1) * L.PER_PAGE
    for slot = 1, L.PER_PAGE do
      local item = self.items[first + slot]
      if item then
        local x, y = L.cell(slot)
        local dim = item.enabled == false
        M.icons:drawIcon(item.icon, x, y, dim)
        local _, ly = L.labelPos(slot)
        local caption = item.display or ""
        local width = M.icons:labelWidth(caption)
        M.icons:drawLabel(caption,
          L.COLS[((slot - 1) % 3) + 1]
            + math.floor((L.CELL_W - width) / 2), ly, dim)
        if first + slot == self.index then
          self:_drawCursor(x, y)
        end
      end
    end

    M.chrome:drawDots(self.page, pages)
    M.chrome:drawFooter()
    love.graphics.setColor(1, 1, 1, 1)
  end

  -- a one-pixel frame around the focused cell, in the outline colour
  -- A one pixel frame with its four corner pixels left off, which reads as a
  -- soft corner at this size and matches the radius the screen itself uses.
  --
  -- Four fills rather than rectangle("line"): a line rect needs half pixel
  -- offsets to land on whole pixels, and it always paints all four corners,
  -- so there is no way to omit them.  Each edge is shortened by one at both
  -- ends, which is what leaves the corners bare.
  function Screen:_drawCursor(x, y)
    -- One pixel of air around the icon, not two.  A wider frame starts at
    -- the cell's own left edge, and for the first column that is also the
    -- screen's interior edge, so the cursor sat flush against the border.
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

return PhoneScreen
