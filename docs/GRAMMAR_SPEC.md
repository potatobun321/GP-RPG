# GP-RPG Table Grammar Specification

GP-RPG is built around plain Lua tables. Every extendable piece of the engine—tiles, entities, rules (tokens), and plugins—follows a fixed table contract so new content can be dropped in without editing engine internals.

---

## 1. Tile Table (`content/tiles/*.lua`)

Missing keys in `flags` inherit defaults from `content/tiles/flagTable.lua`.

```lua
return {
    id          = "wall",
    name        = "Wall",
    colorKey    = "wall",
    draw_style  = "fill",
    texturePath = "content/tiles/wall.png",
    flags = {
        solid = true,
    }
}
```

---

## 2. Entity / Composite Table (`composites.lua` or plugins)

Every game object (NPC, item, trigger, falling block) is a table of `Flags`, `Attributes`, and `Reactions`:

```lua
InteractiveNPC = {
    Flags      = { is_solid = true, is_interactable = true, is_hoverable = true },
    Attributes = { story_id = "intro" },
    Reactions  = {
        TriggerOnClick = { "PlayLoveInk", "ReplaceComposite_SpentNPC" }
    }
}
```

---

## 3. Token (Rule) Table

Tokens live in a lookup table (`Tokens[name]`) so `TokenSystem` dispatches them by table key instead of `if/elseif` chains:

```lua
LaunchTetris = {
    description = "Starts in-world Tetris.",
    consumes    = {}, -- Required Attributes validated at boot
    execute     = function(entityId, ctx, args)
        -- Real Lua/Love2D logic using ctx
    end
}
```

---

## 4. Plugin Table (`content/plugins/*.lua`)

Plugins are single Lua tables discovered from `content/plugins/`. Missing fields use engine defaults.

```lua
return {
    id       = "my_plugin",
    name     = "My Plugin",
    version  = "1.0",
    requires = {},

    -- Declarative world/camera state while this plugin is active
    world = {
        isolated            = false, -- true = give plugin its own clean Tilemap (preserves RPG map)
        exclusiveInput      = false, -- true = suppress RPG player input/interaction while active
        hideDefaultEntities = false, -- true = despawn RPG player & template NPC
        cameraZoomLevel     = nil,   -- integer 0..6, or nil to keep map zoom
        cameraUnbounded     = false, -- true = disable map-bounds clamping for plugin camera
    },

    tiles      = {},
    tokens     = {},
    composites = {},
    commands   = {}, -- Exposed under ~ terminal (e.g. plugin.run my_plugin)

    onLoad          = function(ctx) end,
    onEnter         = function(ctx) end,
    onExit          = function(ctx) end,
    onUpdate        = function(dt, ctx) end,
    onKeypressed    = function(key, ctx) end,
    onMousepressed  = function(x, y, button, ctx) end,
    onMousereleased = function(x, y, button, ctx) end,
    onMousemoved    = function(x, y, dx, dy, ctx) end,
    onWheelmoved    = function(x, y, ctx) end,
    onDraw          = function(ctx) end,
}
```

---

## 5. Engine Context Table (`ctx`)

Every plugin hook and token `execute` receives one consistent `ctx` table:

* `ctx.world` — Current `Tilemap` (`setTile`, `getTileData`, `width`, `height`, `tileSize`)
* `ctx.registry` — ECS `Registry` (`create`, `add`, `remove`, `get`, `has`, `query`)
* `ctx.camera` — Global `Camera` (`setTarget(x, y)`, `clearTarget()`, `setZoom(lvl)`, `getZoom()`)
* `ctx.flags` — Global `FlagManager` (`get`, `set`, `toggle`, `list`)
* `ctx.events` — Global `Event` bus (`on`, `emit`)
* `ctx.console` — `Console` (`log`)
* `ctx.plugins` — Registered plugins table (`id -> plugin`)
* `ctx.call(id, cmd, ...)` — Safely invoke another plugin's `commands[cmd]`
* `ctx.game` — Active `scenes/game.lua` table (`spawnDefaultEntities`, `clearDefaultEntities`)
