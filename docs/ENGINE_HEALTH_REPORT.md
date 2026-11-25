# GP-RPG Engine Health Report & Readiness Assessment

## 1. Critical Issues
*Can cause crashes or corruption.*
* **SpriteBatch Hard Limit:** `engine/world/tilemap.lua` hardcodes spritebatches to 10,000 sprites (`love.graphics.newSpriteBatch(..., 10000)`). If a large map exceeds 10k of a single tile texture, LÖVE will crash with a `SpriteBatch is full` error.
* **Camera Death Freeze:** In `scenes/game.lua`, `Camera:update()` is ONLY called inside `if trans then` (meaning if the player `Transform` exists). If the player is destroyed, despawned, or loses their transform, the camera stops updating entirely—freezing Lerps and bounds calculations instantly.

## 2. High Priority Issues
*Will cause maintenance problems.*
* **Monolithic Input in `game.lua`:** Input handling for interactions (`E`), free-cam (`Shift+F`), and zoom (`Shift+Z`) is hardcoded directly into `Game:keypressed` and `Game:update`. This violates ECS principles and makes input remapping impossible without rewriting scene logic.
* **Duplicated Code:** `scenes/animator.lua` and `tools/anim8tor/scene.lua` are exact, 1:1 duplicates of each other (4505 bytes). Only one should be the source of truth.
* **Dead Code:** `Factory.createTileEntity` in `engine/core/factory.lua` creates ECS entities for tiles. Since the Map Rewrite migrated static tiles out of ECS and into a pure Grid/SpriteBatch architecture, this function is completely dead and misleading.

## 3. Medium Priority Issues
*Should be cleaned eventually.*
* **ECS Purity Violation:** `Systems.TileEffectSystem` manually manages `health.immunityTimer`. Immunity should be its own ECS Component or handled by a dedicated status effect system rather than polluting the tile collision loop.
* **Camera Profile Encapsulation:** `Camera.profiles.gameplay.tempZoomActive` is mutated directly from `game.lua`. This bypasses the Camera module's metatable abstractions.
* **Save/Load Transition Glitch:** `Context.lastTeleportTile` prevents infinite transition loops when walking on a link tile. However, if a player saves the game *on top* of a link tile, and then loads the game, `lastTeleportTile` will be `nil`, causing them to instantly teleport upon loading.

## 4. Low Priority Issues
*Cosmetic or organizational.*
* **Experimental Leftovers:** `tools/LoveInk/main.lua` and `tools/LoveInk/example_story.lua` are LoveInk standalone demos that were left behind during integration. They are harmless but clutter the repository.
* **Legacy Map Scale Fallbacks:** `tilemap.lua` contains legacy fallback code (`math.floor(mapData.baseScale - 1.0 + 0.5)`) to support pre-Zoom-Level maps. It works, but adds minor clutter.

## 5. Safe Cleanup Opportunities
*Code that can be simplified.*
* The `FlagManager` and `AttributeManager` have been seeded but lack `serialize()` and `deserialize()` hooks for the save system. Adding this now will future-proof the state architecture.
* Legacy `tdata.flags.interactMessage` checks can be formalized into a proper `tdata.flags.story_id` check in preparation for complex NPC interactions.

## 6. Future Refactor Opportunities
*Things worth revisiting before Animation/Attributes.*
* **InteractionSystem:** Move the `E` key logic out of `game.lua` and into a dedicated `Systems.InteractionSystem(dt, world)`. This allows Raycasting/Facing-direction checks instead of just checking the tile the player is currently standing on.

---

# Documentation Audit Findings

The following documents need to be refreshed to match recent architectural migrations:
1. `CAMERA_ARCHITECTURE.md`: Needs updating to reflect discrete Zoom Levels (0-6) instead of continuous floats.
2. `MAP_SYSTEM.md`: Needs updating to reflect the new `Assets.getMapData` centralized caching system.
3. `CONSOLE_REFERENCE.md`: Needs updating to include the new `flag.list`, `flag.get`, `flag.set`, `flag.toggle` commands.

*(Note: LOVEINK_INTEGRATION.md, FLAGS_SYSTEM.md, INTERACTION_SYSTEM.md, and NARRATIVE_ARCHITECTURE.md are fully up to date).*

---

# Readiness Assessment

**1. Is GP-RPG stable enough to begin the Attribute Framework?**
Yes. The ECS architecture and State Foundation (`flag_manager.lua`) are solid. The Attribute Framework can slot right in. However, the ECS purity violation in the TileEffectSystem should be resolved so Attributes don't inherit bad patterns.

**2. Is GP-RPG stable enough to begin the Animation Architecture overhaul?**
Mostly yes. But the duplicate `animator.lua` files must be consolidated first to avoid confusion during the overhaul.

**3. What are the biggest architectural risks remaining?**
The hardcoded 10,000 SpriteBatch limit in the Tilemap is a silent killer for any large open-world maps you build in the future. The Camera freezing when the player despawns will also break cutscenes where the player character might be temporarily hidden or removed.

**4. What systems currently have the highest technical debt?**
Input handling. `game.lua` has become a dumping ground for global inputs instead of routing through an Input System or Event Bus. 

**5. What should be cleaned before the next generation begins?**
Apply fixes for the Critical and High Priority issues (SpriteBatches, Camera death freeze, Duplicate animator files, Dead factory functions, and Monolithic input). We should also update the 3 outdated documentation files.
