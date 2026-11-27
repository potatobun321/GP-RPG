# GP-RPG Changelog

## [feat/plugins] - Plugins, Grammar Spec & Animated Tiles
- **Drop-in PluginLoader (`engine/core/plugin_loader.lua`)**: Discovers `.lua` and folder (`init.lua`) plugins from `content/plugins/`, registers custom tokens, composites, and console commands (`plugin.list`, `plugin.run`, `plugin.enable`, `plugin.disable`, `plugin.reload`), and manages plugin enter/exit state.
- **Tetris Plugin (`content/plugins/tetris.lua`)**: In-world Tetris built on GP-RPG's `Tilemap`, ECS entities, and `Camera` controls (`Camera.setTarget`, `Camera.setZoom`).
- **Table Grammar Spec (`docs/GRAMMAR_SPEC.md`)**: Formalized plain-Lua-table contracts for tiles, composites, tokens, plugins, and `ctx`.
- **Self-Executing Tokens**: `TokenSystem` now dispatches plugin-registered tokens with `execute(entityId, ctx)`.
- **Animated SpriteBatch Tiles & Anim8tor Tile Mode**: `Tilemap:update(dt)` animates `animBatches` per frame, and `tools/anim8tor` adds Tile Mode for authoring animated tile definitions.

## [v6.5.1] - Stabilization & Cleanup
- **Registry Cache Fix**: Fixed `Registry` cache invalidation and entity loop key handling.
- **Camera Death Freeze Fix**: `Camera:update()` in `scenes/game.lua` now runs unconditionally even if the player entity lacks a `Transform`.
- **Dead/Duplicate Code Removal**: Removed duplicate `scenes/animator.lua` (keeping `tools/anim8tor/scene.lua`) and dead `Factory.createTileEntity`.

## [v6.5] - Narrative, State & Gen-7 Foundation
- **LoveInk Narrative Integration**: Added `engine/narrative/` (`StoryManager`, `LoveInkAdapter`, `NarrativeEvents`) for branching dialogue connected to global flags.
- **Flag & Attribute State**: Added `engine/state/flag_manager.lua` and `attribute_manager.lua` plus `flag.*` console commands.
- **Gen-7 Preset & Contract Validation**: Added `PresetLoader` (`CoreRPG_MVP`) and `Validator`.

## [v6.4] - Camera Profiles Rework
- Reworked discrete gameplay zoom profiles and editor camera controls.

## [v6.2] - Camera System Overhaul & Map System Overhaul
- **Camera Profiles**: Gameplay and Editor cameras now use completely independent profiles to prevent state contamination.
- **Gameplay Zoom Ladder**: Standardized to discrete integer zoom levels (0 to 6) to eliminate sub-pixel shimmering and ensure pixel-perfect presentation.
- **Editor Continuous Zoom**: The editor now correctly uses Mouse Wheel scrolling for continuous arbitrary floating-point zoom.
- **Editor Fit-to-Screen**: Pressing `0` in Editor Mode instantly calculates and applies the exact scale required to frame the entire map on-screen.
- **Bounds Redesign**: Camera bounds now solely restrict camera position (center clamping) and will never violently overwrite user zoom to hide void space.
- **Editor Drag Navigation**: Implemented modern canvas panning. Hold the Middle Mouse Button (MMB) or Space+Left-Click to drag the map intuitively.
- **Removed Keyboard Panning**: Arrow keys no longer pan the editor camera. The workflow is completely mouse-driven.
- **Command Migration**: `zoom.set N` and `zoom.temp N` now strictly enforce integers `0-6`. `zoom.temp clear` instantly drops the active override.
- **Backward Compatibility**: `tilemap.lua` now natively saves `zoomLevel` but silently falls back and converts legacy `baseScale` floats into discrete integer indices to ensure older maps never break.
