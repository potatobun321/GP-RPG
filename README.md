# GP-RPG

GP-RPG is a 2D role-playing game (RPG) engine built with Lua and LÖVE (Love2D). It combines a playable game runtime with built-in editing tools so you can build maps, configure character animations, and test branching dialogue in one place.

---

## How It Is Organized

Think of the project as four main parts:

* **`engine/`** — The core program that runs the game: movement, camera, tile maps, dialogue playback, and game state (flags and attributes).
* **`content/`** — Your game data: JSON maps, tile definitions, character spritesheets, animation manifests, dialogue stories, and rule presets.
* **`tools/`** — Built-in creation tools:
  * **Map Editor (`tools/editor/`)** — Paint and erase tiles directly inside the running app.
  * **Anim8tor (`tools/anim8tor/`)** — An integrated animation editor for slicing spritesheets and binding them to character slots (such as `walk_down` or `idle_up`).
  * **LoveInk (`tools/LoveInk/`)** — A Lua dialogue system integrated into the engine for branching conversations and story events.
* **`docs/`** — Reference guides for the camera, console commands, map system, ECS architecture, and known engine issues.

---

## Requirements & Running

1. Install **LÖVE 11.x** or newer from [love2d.org](https://love2d.org/).
2. Open a terminal in the `GP-RPG` folder and run:

```bash
love .
```

Alternatively, drag the `GP-RPG` folder onto the LÖVE executable.

---

## Basic Controls

### Playing
* **WASD** — Move the character.
* **E** — Interact with nearby tiles (such as reading signs or triggering dialogue).
* **Shift + F** — Toggle Free Camera mode.
* **Shift + Z** — Toggle temporary zoom override.
* **F11** — Toggle fullscreen.
* **Esc** — Quit (automatically saves the current map).

### Developer Console
* **~**, **`**, or **F1** — Open or close the in-game console.
* Use **Up / Down** for command history, **Tab** to autocomplete, and **Enter** to run.
* Type `help()` to see available commands (including `edit()`, map save/load, camera zoom, and `flag.*` commands).

### Map Editor
* **Left-Click** — Place the selected tile.
* **Right-Click** — Erase a tile.
* **Mouse Wheel** — Zoom in and out.
* **Middle-Click Drag** or **Space + Left-Click Drag** — Pan around the map.
* **0** — Fit the entire map on screen.

---

## Current State (Honest Status)

GP-RPG is under active personal development. It is not a finished, plug-and-play RPG maker yet.

**What works today:**
* Tile-based 2D maps stored as JSON, rendered with SpriteBatching.
* An in-game map editor with map-to-map transitions and link IDs.
* Separate camera profiles for gameplay (integer zoom steps) and editing (smooth zoom and pan).
* Integrated Anim8tor scene for binding spritesheet frames to `content/characters/<entity>/animations.lua`.
* Integrated LoveInk dialogue execution connected to global flags (`flag_manager.lua`).
* Initial preset loading and validation foundation (`CoreRPG_MVP`).

**What is still in progress or has known limitations:**
* Combat, inventory, and save/load serialization for flags and attributes are not finished yet.
* Several architectural cleanups are still pending (documented in `docs/ENGINE_HEALTH_REPORT.md`), such as a 10,000-sprite batch cap per tile texture and moving hardcoded input out of `scenes/game.lua`.
* `tools/anim8tor/` is the engine-integrated version of Anim8tor; the standalone SUIT-based version is maintained separately.

---

## Versioning

Milestones are tracked with Git tags (`v6.0`, `v6.2`, `v6.4`, `v6.5`) on `main`.

---

## License

Distributed for educational and personal development use.
