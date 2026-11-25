# GP-RPG Performance Optimization Report

This report details the targeted optimization pass executed to eliminate frame-time spikes, garbage collection stutter, and perceived sluggishness before beginning the Animation and Attribute generations.

## Changes Applied

1. **Incremental Spatial Hash (Critical)**: Refactored `engine/ecs/systems.lua` to prevent destroying and rebuilding the `SpatialHash` every frame. Entities now mathematically update their cell registration only when crossing cell boundaries (via `SpatialCache`). This completely eliminated the massive per-frame table allocation GC spike.
2. **Dialogue UI Allocation Caching (Critical)**: Refactored `tools/LoveInk/dialogue_ui.lua`. The `TextBox:draw()` loop was previously allocating a new table of word-wrapped text via `font:getWrap()` 60 times a second. This string calculation is now explicitly cached and only re-evaluates when the text or window width physically changes.
3. **Animation Allocation Cleanup (High)**: Refactored `Systems.AnimationControllerSystem`. Removed the `resolveAnim` varargs `{...}` packing that silently allocated a new array per entity per frame. Additionally, implemented a static `AnimKeyCache` to prevent the `action .. "_" .. facing` string concatenation from generating garbage string allocations every frame.
4. **Rendering Allocation Cleanup (Medium)**: Added statically defined `DEFAULT_COLOR` and `DEFAULT_UNTEXTURED_COLOR` constants to `engine/ecs/systems.lua` and `engine/world/tilemap.lua`. This prevents the engine from generating temporary `{1, 1, 1}` fallback tables during the draw loop for entities missing color definitions.
5. **DeltaTime Clamping (Medium)**: Added `dt = math.min(dt, 0.033)` to `love.update()` in `main.lua`. This prevents the engine from overcompensating during lag spikes or OS background tasks, ensuring the player never visually "teleports", which previously contributed to perceived jank.

## Estimated Impact

* **High Impact**: Frame pacing should now be perfectly locked to the display refresh rate without micro-stutters, as the lua garbage collector is no longer fighting hundreds of per-frame nested table and string allocations.
* **High Impact**: Perceived input latency and camera trailing are significantly reduced. The game should feel native and tight.

## Remaining Bottlenecks

* **Spatial Hashing Nested Loops**: While the GC spike is eliminated, `checkEntityCollision` still performs nested loops over a grid. It is extremely fast right now, but if the map were to have thousands of active colliders clustering in identical cells, it could become CPU-bound. This is an eventual optimization, not an immediate one.

## Deferred

The following items were intentionally NOT addressed during this pass as they belong to future generations:

* Full Animation Architecture (Anim8 integration)
* Audio System
* Attribute Framework
* Input Architecture Rewrite
