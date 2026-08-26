-- Composing the final row list.
--
-- Claiming the StartMenu screen id means the builtin StartMenu.new never
-- runs, and with it the Runtime.call("ui.start_menu.items", ...) at
-- src/ui/StartMenu.lua:130.  Every row another mod injected would disappear
-- with no error.  So the phone re-runs that hook itself, over a list whose
-- labels are byte-identical to vanilla's.

local Items = {}

-- Three glyphs at a 5px advance is 15px in a 21px cell, a 6px gap to
-- the neighbouring caption.  Four filled the cell and adjacent
-- captions read as one word: OPTNSAVE, LINKMODS.
local MAX_CAPTION = 3

-- the vanilla identity link: with no wrapper installed, the list is returned
-- exactly as it was handed in
local function passthrough(_, items) return items end

-- A row that came from another mod carries only { label, onSelect }.  Give
-- it what the grid needs to draw: a caption clipped to the cell, the
-- fallback icon, and selectability.
function Items.decorate(items)
  for _, item in ipairs(items) do
    if item.display == nil then
      item.display = tostring(item.label or "?"):sub(1, MAX_CAPTION)
    end
    if item.icon == nil then item.icon = "generic" end
    if item.enabled == nil then item.enabled = true end
  end
  return items
end

-- runtime is injected so a test can pass a stand-in; in the mod it is
-- src.mods.Runtime, reached under the engine_internals permission.
--
-- Returns the composed list, plus a reason string when the hook failed to
-- produce a usable one.  The caller owns the logging: this module has no
-- mod.log, and the builtin reports the same condition
-- (src/ui/StartMenu.lua:131-135), so returning no signal at all would be a
-- diagnosability regression against vanilla rather than a style choice.
function Items.compose(game, apps, runtime)
  local ok, result = pcall(runtime.call, "ui.start_menu.items",
                           passthrough, game, apps)
  if not ok then
    return Items.decorate(apps),
      ("the ui.start_menu.items chain threw (%s)"):format(tostring(result))
  end
  if type(result) ~= "table" then
    return Items.decorate(apps),
      ("ui.start_menu.items returned %s, not a table"):format(type(result))
  end
  return Items.decorate(result)
end

return Items
