# Console & Shortcuts Reference

The Developer Console (`engine/core/console.lua`) is the master control panel for the GP-RPG engine. It runs pure Lua code in a sandboxed environment, allowing you to manipulate state in real-time.

## Opening the Console
Press **Tilde (`~` or `` ` ``)** or **F1** at any time during gameplay.

---

## 1. Map Management
The Map Registry manages all JSON and legacy LUA maps across the `maps/` and `content/maps/` directories.

- **`listmaps`**: Prints a list of all currently discovered playable maps.
- **`newmap.name`**: Creates a new map named `name.json` using the `template.json` blueprint.
- **`duplicatemap.src.dest`**: Duplicates map `src` into a new map `dest`.
- **`deletemap.name`**: Deletes the specified map from disk.
- **`save`**: Saves the map you are currently on.
- **`save.name`**: Saves the current map under a new filename (`name.json`).
- **`loadmap.name`**: Saves the current map and instantly loads `name`.
- **`resize.N`**: Dynamically scales the entire world grid and tiles to `N` pixels (e.g., `resize.64`).

---

## 2. Tools, Plugins & Display
- **`edit`**: Toggles the Map Editor slide-in panel.
- **`anim`**: Transitions from the game scene into the Anim8tor Sprite Tool.
- **`plugin.list`**: Lists all discovered plugins (`content/plugins/`) with enabled/disabled status and type (`scene` or `rule`).
- **`plugin.run <id>`** (or simply **`<id>`**, e.g. `tetris`): Enters or exits a runnable plugin mode.
- **`plugin.enable <id>` / `plugin.disable <id>`**: Enables or disables a plugin.
- **`plugin.reload`**: Reloads all plugins from `content/plugins/`.
- **`theme.name`**: Changes the visual UI and primitive colors. Available: `neon`, `dracula`, `dark`, `light`.
- **`zoom.set(N)`**: Sets the permanent gameplay zoom level (`0` to `6`, e.g. `zoom.set(3)`).
- **`zoom.temp(N)` / `zoom.temp clear`**: Sets or clears a temporary gameplay zoom override (`0` to `6`).
- **`clear`**: Wipes the console logs clean.
- **`history`**: Displays previously entered console commands.

---

## 3. Player Stats & Debugging
- **`charc`**: Prints the player's stat block as an ASCII table.
- **`hp.N`**: Sets current and maximum Health.
- **`spd.N`**: Sets the base movement speed.
- **`atk.N`, `def.N`, `endr.N`, `int.N`**: Sets the respective combat stats.

*(Because the console acts as a Lua REPL, you can also execute raw code like `player.x = 0` or `math.sqrt(100)`)*

---

## 4. Flag & Save State Management
The State Architecture manages global booleans/variables through `FlagManager` and full RPG save slots through `SaveManager`.

- **`flag.list()`**: Prints all active flags and their current values to the console.
- **`flag.get("name")`**: Returns the current value of the specified flag.
- **`flag.set("name", true/false)`**: Sets the specified flag to a boolean value.
- **`flag.toggle("name")`**: Inverts the specified boolean flag.
- **`savegame` / `savegame.slot`**: Saves current map, player position/HP, flags, and attributes to `saves/<slot>.json` (defaults to `slot1`).
- **`loadgame` / `loadgame.slot`**: Restores saved map, player position/HP, flags, and attributes from `saves/<slot>.json`.
- **`listsaves`**: Lists all saved game slots.

---

## 5. Keyboard Shortcuts

**Global Actions:**
- **`~`, `` ` ``, or `F1`**: Toggle Developer Console.
- **`E`**: Interact with nearby `is_interactable` entities (emitting `TriggerOnInteract`) or fall back to tile `interactMessage`.
- **`Shift + Z`**: Hold for temporary gameplay zoom override.
- **`Shift + F`**: Toggle Free-Cam mode on or off manually.
- **`F11`**: Toggle fullscreen.
- **`Esc`**: Quit game (saves current map).

**Editor specific (when `edit()` is active):**
- **Left-Click**: Paint selected tile.
- **Right-Click**: Erase tile (turns to void).
- **Mouse Wheel**: Scroll tile palette in the panel.
- **`W`, `A`, `S`, `D`**: Move the camera freely when detached from the player.
- **`Shift` + `F`**: Toggle Free-Cam mode on or off manually.
