-- content/plugins/sidescroller.lua
-- Side-Scroller plugin: 1D gravity, jumping, and platforming on GP-RPG's Tilemap + ECS.
-- Run via console: `sidescroller` or `plugin.run sidescroller`

local GRAVITY    = 900
local JUMP_SPEED = -340
local MOVE_SPEED = 150
local MAX_FALL   = 520

local state = {
    active   = false,
    playerId = nil,
    vy       = 0,
    grounded = false,
    coyote   = 0,
    spawnX   = 0,
    spawnY   = -64,
}

local function buildLevel(world)
    -- Clear a 48x18 playfield
    for gy = -10, 6 do
        for gx = -8, 36 do
            if gy == 5 then
                -- Ground floor with a lava pit
                if gx >= 10 and gx <= 13 then
                    world:setTile(gx, gy, "lava", { solid = false, hazard = true })
                else
                    world:setTile(gx, gy, "grass", { solid = true })
                end
            elseif gy == 6 then
                world:setTile(gx, gy, "wall", { solid = true })
            elseif gx == -8 or gx == 36 then
                world:setTile(gx, gy, "wall", { solid = true })
            else
                world:setTile(gx, gy, "void", { solid = false })
            end
        end
    end

    -- Platforms
    for gx = 3, 6 do world:setTile(gx, 2, "wood", { solid = true }) end
    for gx = 9, 14 do world:setTile(gx, 0, "wood", { solid = true }) end
    for gx = 17, 21 do world:setTile(gx, 2, "wood", { solid = true }) end
    for gx = 24, 29 do world:setTile(gx, -1, "wood", { solid = true }) end
end

local function respawn(ctx)
    if not state.playerId then return end
    local t = ctx.registry.get(state.playerId, "Transform")
    if t then
        t.x = state.spawnX
        t.y = state.spawnY
    end
    state.vy = 0
    state.grounded = false
end

return {
    id          = "sidescroller",
    name        = "Side-Scroller",
    version     = "1.0",
    description = "1D gravity platformer mode using GP-RPG Tilemap & ECS.",

    world = {
        isolated            = true,
        exclusiveInput      = true,
        hideDefaultEntities = true,
        cameraZoomLevel     = 1,
        cameraUnbounded     = true,
    },

    tokens = {
        LaunchSideScroller = {
            description = "Enters Side-Scroller platformer mode.",
            consumes    = {},
            execute     = function(entityId, ctx)
                require('engine.core.plugin_loader').enter("sidescroller")
            end
        }
    },

    commands = {
        play = function()
            require('engine.core.plugin_loader').enter("sidescroller")
        end
    },

    onEnter = function(ctx)
        if not ctx.world then return end
        state.active = true
        state.vy = 0
        state.grounded = false
        state.coyote = 0

        buildLevel(ctx.world)

        local Factory = require('engine.core.factory')
        local ts = ctx.world.tileSize
        state.spawnX = 0
        state.spawnY = 2 * ts
        state.playerId = Factory.createCharacterEntity(state.spawnX, state.spawnY, "player")
        ctx.registry.removeComponent(state.playerId, "Persistent")

        local t = ctx.registry.get(state.playerId, "Transform")
        if t then
            ctx.camera.setTarget(t.x + t.w / 2, t.y + t.h / 2, true)
        end
    end,

    onExit = function(ctx)
        state.active = false
        if state.playerId and ctx and ctx.registry then
            ctx.registry.remove(state.playerId)
            state.playerId = nil
        end
    end,

    onUpdate = function(dt, ctx)
        if not state.active or not state.playerId or not ctx.world then return end

        local t = ctx.registry.get(state.playerId, "Transform")
        local c = ctx.registry.get(state.playerId, "Collider")
        local v = ctx.registry.get(state.playerId, "Velocity")
        if not t then return end

        local cw  = (c and c.w)  or t.w
        local ch  = (c and c.h)  or t.h
        local cox = (c and c.ox) or 0
        local coy = (c and c.oy) or 0

        -- Horizontal input
        local moveX = 0
        if love.keyboard.isDown("a", "left")  then moveX = moveX - 1 end
        if love.keyboard.isDown("d", "right") then moveX = moveX + 1 end

        if v then
            v.dx = moveX
            v.dy = 0
            if moveX < 0 then v.facing = "left"
            elseif moveX > 0 then v.facing = "right" end
        end

        local nextX = t.x + moveX * MOVE_SPEED * dt
        if not ctx.world:isSolidPixel(nextX + cox, t.y + coy, cw, ch, t.z or 0) then
            t.x = nextX
        end

        -- 1D Gravity
        state.vy = math.min(MAX_FALL, state.vy + GRAVITY * dt)
        local nextY = t.y + state.vy * dt

        if not ctx.world:isSolidPixel(t.x + cox, nextY + coy, cw, ch, t.z or 0) then
            t.y = nextY
            state.grounded = false
        else
            if state.vy > 0 then
                state.grounded = true
                state.coyote = 0.08
            end
            state.vy = 0
        end

        if not state.grounded and state.coyote > 0 then
            state.coyote = state.coyote - dt
        end

        -- Hazard check (lava)
        local gx = math.floor((t.x + t.w / 2) / ctx.world.tileSize)
        local gy = math.floor((t.y + t.h / 2) / ctx.world.tileSize)
        local tdata = ctx.world:getTileData(gx, gy)
        if tdata and tdata.flags and tdata.flags.hazard then
            respawn(ctx)
        end

        ctx.camera.setTarget(t.x + t.w / 2, t.y + t.h / 2)
    end,

    onKeypressed = function(key, ctx)
        if not state.active then return end
        if key == "q" then
            require('engine.core.plugin_loader').exit("sidescroller")
            return
        elseif key == "r" then
            respawn(ctx)
            return
        elseif (key == "space" or key == "w" or key == "up") and (state.grounded or state.coyote > 0) then
            state.vy = JUMP_SPEED
            state.grounded = false
            state.coyote = 0
        end
    end,

    onDraw = function(ctx)
        if not state.active then return end
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 16, 56, 330, 62, 4, 4)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("SIDE-SCROLLER MODE", 26, 64)
        love.graphics.setColor(0.75, 0.85, 0.95, 1)
        love.graphics.print("A/D: Move | Space/W: Jump | R: Reset | Q: Exit", 26, 86)
    end,
}
