# GP-RPG Engine Architecture Master Guide

This document is the current architecture snapshot for the **GP-RPG (v6.5+ / `feat/plugins`)** engine. It is written to serve as the definitive guide for developers to understand the structure, subsystems, and flow of the codebase.

## 1. Core Philosophy

GP-RPG is built for rapid iteration, embedded tooling, and runtime experimentation. It relies on a custom Entity Component System (ECS) paired with a data-driven Tilemap to power the environment, avoiding the memory bloat of treating every static tile as an entity. Tiles, entities/composites, rule tokens, and drop-in plugins all follow plain Lua table contracts (see [GRAMMAR_SPEC.md](GRAMMAR_SPEC.md)).

## 2. Directory Structure

```text
GP-RPGV6.5/
├── engine/             # Core logic and systems
│   ├── core/           # Console, Camera, Factory, Event Bus, Assets, PluginLoader, PresetLoader, Validator, Transitions
│   ├── ecs/            # Components, Registry, and logic Systems
│   ├── narrative/      # LoveInk adapter, story manager, and narrative events
│   ├── state/          # FlagManager and AttributeManager
│   ├── ui/             # In-game UI framework and widgets
│   └── world/          # Tilemap (static + animated SpriteBatches) and Map Registry
├── content/            # Data-driven game assets
│   ├── characters/     # Spritesheets and animation manifests
│   ├── maps/           # Map files (.json and legacy .lua)
│   ├── plugins/        # Drop-in table-driven plugins (e.g., tetris.lua)
│   ├── presets/        # Rule/composite presets (e.g., CoreRPG_MVP)
│   ├── stories/        # LoveInk narrative scripts
│   └── tiles/          # Tile definitions, flagTable.lua defaults, and textures
├── tools/              # Embedded editors & narrative runtime
│   ├── anim8tor/       # Integrated animation & tile-animation editor
│   ├── editor/         # In-game map editor
│   └── LoveInk/        # Bundled LoveInk dialogue library
├── scenes/             # High-level game states
│   └── game.lua        # Primary gameplay loop
├── tests/              # Engine test runner & transition tests
└── docs/               # Technical documentation
```

## 3. Subsystems

### 3.1. ECS (Entity Component System)
Located in `engine/ecs/`. Handles dynamic interactive objects (Player, NPCs, triggers, plugin entities).
- **Registry (`registry.lua`)**: Manages integer IDs and component tables. Uses `queryCached` to optimize tight loops with automatic cache invalidation.
- **Components (`components.lua`)**: Pure data structures without logic (`Transform`, `Velocity`, `Health`, `Flags`, `Attributes`, `TokenQueue`, etc.).
- **Systems (`systems.lua`)**: Per-frame loops (`PlayerInputSystem`, `MovementSystem`, `TileEffectSystem`, `AnimationControllerSystem`, `AnimationSystem`, `HoverSystem`, `TokenSystem`).

### 3.2. Tilemap & World Data
Located in `engine/world/tilemap.lua`.
- Manages the grid array of static and animated tiles.
- Serializes to and from sparse RLE-compressed JSON via `Assets.getMapData`.
- Provides collision (`isSolidPixel`) and rendering via `SpriteBatch` (`tileBatches` for static tiles and `animBatches` updated via `Tilemap:update(dt)` for animated tiles).

### 3.3. Narrative & State
- **Narrative (`engine/narrative/`)**: `StoryManager` and `LoveInkAdapter` execute branching LoveInk stories and dialogue UI.
- **State (`engine/state/`)**: `FlagManager` (global boolean/variable flags) and `AttributeManager` (entity/rule attributes).

### 3.4. Presets, Plugins & Grammar
- **PresetLoader (`engine/core/preset_loader.lua`)** & **Validator (`engine/core/validator.lua`)**: Load and validate rule/token/composite presets such as `CoreRPG_MVP`.
- **PluginLoader (`engine/core/plugin_loader.lua`)**: Discovers drop-in `.lua` or folder (`init.lua`) plugins from `content/plugins/`, registers their tokens, composites, and console commands, and manages `onEnter`/`onExit`/`onUpdate`/`onKeypressed`/`onDraw` lifecycles with automatic camera/entity state save & restore.

### 3.5. Embedded Tooling
The engine ships with its tools embedded into the runtime:
- **Map Editor (`tools/editor/editor.lua`)**: Real-time tile placement, box-filling, and map-to-map link creation.
- **Anim8tor (`tools/anim8tor/scene.lua`)**: Visual editor for binding spritesheet frames to character animations and animated tile definitions (Tile Mode).
- **Developer Console (`engine/core/console.lua`)**: Quake-style drop-down providing a sandboxed Lua REPL for live commands, flags, maps, and plugins.

## 4. Data Flows & Pipelines

### 4.1. Map Lifecycle
- **Discovery**: `engine/world/map_registry.lua` scans `content/maps/` and `maps/` to dynamically build the list of playable maps, feeding the editor and console.
- **Creation**: Use `newmap.name` to spawn a new JSON map based on `content/maps/template.json`.
- **Serialization**: Maps are saved automatically on transitions or via `save` / quit, utilizing a sparse-array RLE JSON format.

### 4.2. Content Pipeline (Tiles & Entities)
- **Factory (`engine/core/factory.lua`)**: Scans `content/tiles/`, merges individual `.lua` tile scripts with `flagTable.lua` defaults, and builds character/composite entities (`createCharacterEntity`, `applyComposite`).
- **Plugins (`content/plugins/`)**: Loaded at boot by `PluginLoader.loadAll()` after `PresetLoader.load("CoreRPG_MVP")`.

## 5. Runtime Flow

1. `main.lua`: Initializes `Factory`, `PresetLoader` (`CoreRPG_MVP`), `PluginLoader`, and `AnimationManager.verifyAll(Factory)`, then boots `scenes/game.lua`.
2. `scenes/game.lua:load()`: Initializes `StoryManager`, loads `Tilemap` (`map1`), configures `Camera` zoom/bounds, spawns default entities (`playerId`, `npcId`), and sets up `Console` globals.
3. `scenes/game.lua:update(dt)`:
   - Updates `Console` and `Editor`; pauses gameplay if `Console.isOpen`.
   - Updates `StoryManager` (pausing movement/input during active dialogue while keeping `AnimationSystem` running).
   - Runs ECS `Systems` sequentially (`PlayerInputSystem` -> `MovementSystem` -> `TileEffectSystem` -> `AnimationControllerSystem` -> `AnimationSystem` -> `HoverSystem` -> `TokenSystem`).
   - Updates `Tilemap:update(dt)` (animated tiles) and `PluginLoader.update(dt)`.
   - Updates `Camera:update(dt, tx, ty, self.world)` unconditionally (even if the player entity is absent).
4. `scenes/game.lua:draw()`:
   - Attaches the camera transform, renders `Tilemap`, renders ECS entities via `RenderSystem`, and calls `PluginLoader.draw()`.
   - Detaches the camera and draws `StoryManager` dialogue UI, `Editor`, and `Console` in screen-space.
