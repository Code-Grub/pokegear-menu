# PokéGear Menu

Restyles the START menu in the [Pokemon Gen 1 Recompilation Project](https://github.com/bryanthaboi/pokemon-gen1-recomp-project)
as a handheld device: nine apps in a 3x3 grid, drawn in colour over the
overworld.

**It is a reskin of the menu, not the Gen 2 PokéGear.** The real PokéGear had a
clock, a map, a radio and a phone. This has the clock and the map. There is no
radio and there are no calls, and every app it shows is somewhere the START
menu already went.

## Try it

```sh
python3 tools/modkit.py validate mods/phone_start_menu --base imported
python3 tools/modkit.py lint mods/phone_start_menu
luajit mods/phone_start_menu/tests/phone_screen_test.lua
```

## The apps

Dex, Pkmn, Bag, Id, Optn, Save, Map, Link, Mods. An app you have not
unlocked yet sits dimmed in its own place, so nothing ever moves under your
thumb.

Map opens the TOWN MAP, and needs you to be carrying it, exactly as using
the item from the bag does.

## Permissions

`engine_internals` is for re-running the START menu's own `ui.start_menu.items`
hook and reaching its built-in SAVE flow. `network` is for the Link app: it
opens the engine's own `src.link.LinkState`, the vanilla peer-to-peer link
play screen, unmodified.

## Where did QUIT go?

Hold A, B, SELECT and START together. That is the Game Boy's own soft reset,
it returns you to the title from anywhere, and it is what QUIT called.

## Regenerating the art

```sh
python tools/gen_assets.py
```

Every pixel is declared as text in that script, so the art is original and
carries its own provenance.
