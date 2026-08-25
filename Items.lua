-- Composing the final row list.
--
-- Claiming the StartMenu screen id means the builtin StartMenu.new never
-- runs, and with it the Runtime.call("ui.start_menu.items", ...) at
-- src/ui/StartMenu.lua:130.  Every row another mod injected would disappear
-- with no error.  So the phone re-runs that hook itself, over a list whose
-- labels are byte-identical to vanilla's.

local Items = {}

-- four glyphs at a 5px advance is 20px, the most a 21px cell holds
local MAX_CAPTION = 4

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
function Items.compose(game, apps, runtime)
  local hooked = apps
  local ok, result = pcall(runtime.call, "ui.start_menu.items",
                           passthrough, game, apps)
  if ok and type(result) == "table" then
    hooked = result
  end
  return Items.decorate(hooked)
end

return Items
