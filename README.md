# GP-RPG

A lightweight, table-driven 2D RPG engine and multi-genre framework built with **Lua** and **LÖVE (Love2D)**.

## Core Features

* **Chunked Tilemap & Animations:** `16×16` SpriteBatch-culled JSON maps with static & animated tiles (`sync`, `noise`, `random` phases; `loop`, `pingpong` playback).
* **ECS & Pseudo-Depth (`z`-Axis):** Minimalist entity-component system with foot-aligned collision, `z`-elevation passability, and `(z, y)` depth sorting.
* **Table-Grammar Plugins:** Drop-in plugins (`content/plugins/`) with isolated worlds, exclusive input routing, custom tiles, composites, tokens, and console commands (includes playable `tetris`).
* **Narrative & State:** Integrated **LoveInk** branching dialogue, `FlagManager`, `AttributeManager`, and `SaveManager` (`savegame` / `loadgame`).
* **Built-in Tools:**
  * **Map Editor (`edit`)** — Tile painting, area fill, map links, camera bounds (`CBOUNDS`), and `ENTITY` composite placement.
  * **Anim8tor (`anim`)** — Visual spritesheet slicer & tile animation editor (LoveMotion workflow).
  * **Developer Console (`~` / `F1`) & Debug Overlay (`F3`)** — Sandboxed Lua REPL, live flags/stats/teleports, and collider/grid HUD.

## Running

Requires **LÖVE 11.x+**:

```bash
love .
```

## Controls

* **WASD** — Move | **E** — Interact | **F3** — Debug Overlay | **F11** — Fullscreen
* **~ / ` / F1** — Developer Console (`help` for commands) | **Shift + F** — Free Camera | **Shift + Z** — Temp Zoom

## Built With

* **[LÖVE (Love2D)](https://love2d.org/)** — 2D game framework
* **[anim8](https://github.com/kikito/anim8)** by kikito — Sprite animation library
* **[json.lua](https://github.com/rxi/json.lua)** by rxi — JSON encoder/decoder
* **[LoveInk](tools/LoveInk/README.md)** — Lua branching dialogue system
* **[LoveMotion (Anim8tor)](tools/anim8tor/scene.lua)** — Visual spritesheet & tile animation tool
* **[PressStart2P](fonts/PressStart2P.ttf)** — Pixel bitmap font

## License

MIT — see [LICENSE](LICENSE).
