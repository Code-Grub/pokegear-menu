-- The SAVE confirmation chain, reproduced from src/ui/StartMenu.lua:55-88.
--
-- The engine exposes no seam to invoke that flow, so claiming the screen id
-- means reproducing it.  This is recorded in mod.card's `known` ledger: if
-- the engine changes the flow, this file drifts until it is updated.
--
-- The delays are load-bearing and come from engine/menus/save.asm:164-181:
-- "Now saving..." is a bare PlaceString held by DelayFrames 120, and the
-- confirmation ends in `done` so it never waits on a button; it waits on
-- SFX_SAVE and then DelayFrames 30.  Neither page takes a press.

local SaveFlow = {}

function SaveFlow.build(deps)
  local TextBox, Badges = deps.textbox, deps.badges
  local Strings, Sound = deps.strings, deps.sound

  return function(game)
    local owned = 0
    for _ in pairs(game.save.pokedex and game.save.pokedex.owned or {}) do
      owned = owned + 1
    end
    local badges = 0
    local okBadges, count = pcall(Badges.count, game.data, game.save)
    if okBadges and type(count) == "number" then badges = count end

    local t = math.floor(game.save.playTime or 0)
    local panel = Strings("PLAYER %s\nBADGES    %d\nPOKéDEX %3d\nTIME %6d:%02d",
                          game.save.player.name or "RED", badges, owned,
                          math.floor(t / 3600), math.floor(t / 60) % 60)

    game.stack:push(TextBox.new(game,
      panel .. Strings("\fWould you like to\nSAVE the game?"), nil, {
      choice = function(yes)
        if not yes then return end
        game.stack:push(TextBox.new(game, Strings("Now saving..."), function()
          game:writeSave()
          game.stack:push(TextBox.new(game,
            Strings("%s saved\nthe game!", game.save.player.name or "RED"),
            nil, { auto = {
              sound = function() return Sound.play(game.data, "Save") end,
              delay = 30,
            } }))
        end, { auto = { delay = 120 } }))
      end,
    }))
  end
end

return SaveFlow
