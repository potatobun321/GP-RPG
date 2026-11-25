-- content/plugins/tetris.lua
-- Tetris plugin following GP-RPG's fixed Table Grammar (docs/GRAMMAR_SPEC.md).
-- Uses current Tilemap, ECS Registry entities, global Camera target & zoomLevel.
-- Open console (~) and type: tetris

local COLS = 10
local ROWS = 20
local ORIGIN_X = -5
local ORIGIN_Y = -10

local PIECES = {
    I = { tileId = "water", shapes = {
        { {0,0,0,0}, {1,1,1,1}, {0,0,0,0}, {0,0,0,0} },
        { {0,0,1,0}, {0,0,1,0}, {0,0,1,0}, {0,0,1,0} },
        { {0,0,0,0}, {0,0,0,0}, {1,1,1,1}, {0,0,0,0} },
        { {0,1,0,0}, {0,1,0,0}, {0,1,0,0}, {0,1,0,0} },
    }},
    O = { tileId = "sand", shapes = {
        { {1,1}, {1,1} }, { {1,1}, {1,1} }, { {1,1}, {1,1} }, { {1,1}, {1,1} },
    }},
    T = { tileId = "lava2", shapes = {
        { {0,1,0}, {1,1,1}, {0,0,0} },
        { {0,1,0}, {0,1,1}, {0,1,0} },
        { {0,0,0}, {1,1,1}, {0,1,0} },
        { {0,1,0}, {1,1,0}, {0,1,0} },
    }},
    S = { tileId = "grass", shapes = {
        { {0,1,1}, {1,1,0}, {0,0,0} },
        { {0,1,0}, {0,1,1}, {0,0,1} },
        { {0,0,0}, {0,1,1}, {1,1,0} },
        { {1,0,0}, {1,1,0}, {0,1,0} },
    }},
    Z = { tileId = "lava", shapes = {
        { {1,1,0}, {0,1,1}, {0,0,0} },
        { {0,0,1}, {0,1,1}, {0,1,0} },
        { {0,0,0}, {1,1,0}, {0,1,1} },
        { {0,1,0}, {1,1,0}, {1,0,0} },
    }},
    J = { tileId = "seawater", shapes = {
        { {1,0,0}, {1,1,1}, {0,0,0} },
        { {0,1,1}, {0,1,0}, {0,1,0} },
        { {0,0,0}, {1,1,1}, {0,0,1} },
        { {0,1,0}, {0,1,0}, {1,1,0} },
    }},
    L = { tileId = "wood", shapes = {
        { {0,0,1}, {1,1,1}, {0,0,0} },
        { {0,1,0}, {0,1,0}, {0,1,1} },
        { {0,0,0}, {1,1,1}, {1,0,0} },
        { {1,1,0}, {0,1,0}, {0,1,0} },
    }},
}

local PIECE_KEYS = { "I", "O", "T", "S", "Z", "J", "L" }

local state = {
    active = false,
    paused = false,
    gameOver = false,
    score = 0,
    lines = 0,
    level = 1,
    dropTimer = 0,
    bag = {},
    nextKind = nil,
    current = nil,
    pieceEntities = {},
}

local function clearPieceEntities(registry)
    for _, id in ipairs(state.pieceEntities) do
        registry.remove(id)
    end
    state.pieceEntities = {}
end

local function refillBag()
    local bag = {}
    for _, k in ipairs(PIECE_KEYS) do table.insert(bag, k) end
    for i = #bag, 2, -1 do
        local j = love.math.random(1, i)
        bag[i], bag[j] = bag[j], bag[i]
    end
    return bag
end

local function popBag()
    if #state.bag == 0 then state.bag = refillBag() end
    return table.remove(state.bag)
end

local function buildTilemapWell(world)
    for r = 0, ROWS + 1 do
        for c = 0, COLS + 1 do
            local gx = ORIGIN_X + c - 1
            local gy = ORIGIN_Y + r - 1
            if c == 0 or c == COLS + 1 or r == ROWS + 1 then
                world:setTile(gx, gy, "wall", { solid = true, tetris_wall = true })
            elseif r >= 1 then
                world:setTile(gx, gy, "void", { solid = false })
            end
        end
    end
end

local function collides(world, kind, rot, bx, by)
    local shape = PIECES[kind].shapes[rot]
    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] == 1 then
                local col = bx + c - 1
                local row = by + r - 1
                if col < 1 or col > COLS or row > ROWS then return true end
                if row >= 1 then
                    local tdata = world:getTileData(ORIGIN_X + col - 1, ORIGIN_Y + row - 1)
                    if tdata and tdata.flags and tdata.flags.solid then return true end
                end
            end
        end
    end
    return false
end

local function syncPieceEntities(registry, world)
    local cur = state.current
    if not cur then return end
    local shape = PIECES[cur.kind].shapes[cur.rot]
    local ts = world.tileSize
    local idx = 1

    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] == 1 then
                local id = state.pieceEntities[idx]
                local gx = ORIGIN_X + (cur.x + c - 1) - 1
                local gy = ORIGIN_Y + (cur.y + r - 1) - 1
                if id then
                    local tr = registry.get(id, "Transform")
                    if tr then
                        tr.x, tr.y, tr.w, tr.h = gx * ts, gy * ts, ts, ts
                    end
                end
                idx = idx + 1
            end
        end
    end
end

local function spawnPiece(ctx, kind)
    clearPieceEntities(ctx.registry)

    local Components = require('engine.ecs.components')
    local Factory = require('engine.core.factory')

    local k = kind or popBag()
    local tileId = PIECES[k].tileId
    local tileDef = Factory.getTile(tileId)

    state.current = { kind = k, rot = 1, x = (k == "O") and 5 or 4, y = 1 }

    if collides(ctx.world, k, 1, state.current.x, state.current.y) then
        state.gameOver = true
        return
    end

    for _ = 1, 4 do
        local id = ctx.registry.create()
        ctx.registry.add(id, "Transform", Components.Transform(0, 0, ctx.world.tileSize, ctx.world.tileSize))
        ctx.registry.add(id, "Renderable", Components.Renderable("character", tileDef.colorKey, tileDef.texture, "fill"))
        ctx.registry.add(id, "Flags", Components.Flags({ is_tetris_piece = true }))
        ctx.registry.add(id, "Attributes", Components.Attributes({ tileId = tileId }))
        table.insert(state.pieceEntities, id)
    end

    syncPieceEntities(ctx.registry, ctx.world)
end

local function clearFullRows(world)
    local cleared = 0
    local r = ROWS
    while r >= 1 do
        local full = true
        for c = 1, COLS do
            local tdata = world:getTileData(ORIGIN_X + c - 1, ORIGIN_Y + r - 1)
            if not tdata or not (tdata.flags and tdata.flags.solid) then
                full = false
                break
            end
        end

        if full then
            cleared = cleared + 1
            for shiftR = r, 2, -1 do
                for c = 1, COLS do
                    local above = world:getTileData(ORIGIN_X + c - 1, ORIGIN_Y + (shiftR - 1) - 1)
                    if above and above.flags and above.flags.solid then
                        world:setTile(ORIGIN_X + c - 1, ORIGIN_Y + shiftR - 1, above.typeId, { solid = true, tetris_locked = true })
                    else
                        world:setTile(ORIGIN_X + c - 1, ORIGIN_Y + shiftR - 1, "void", { solid = false })
                    end
                end
            end
            for c = 1, COLS do
                world:setTile(ORIGIN_X + c - 1, ORIGIN_Y, "void", { solid = false })
            end
        else
            r = r - 1
        end
    end

    if cleared > 0 then
        local pts = { 100, 300, 500, 800 }
        state.score = state.score + (pts[cleared] or 800) * state.level
        state.lines = state.lines + cleared
        state.level = math.floor(state.lines / 10) + 1
    end
end

local function lockPiece(ctx)
    local cur = state.current
    if not cur then return end
    local tileId = PIECES[cur.kind].tileId
    local shape = PIECES[cur.kind].shapes[cur.rot]

    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] == 1 then
                local gx = ORIGIN_X + (cur.x + c - 1) - 1
                local gy = ORIGIN_Y + (cur.y + r - 1) - 1
                ctx.world:setTile(gx, gy, tileId, { solid = true, tetris_locked = true })
            end
        end
    end

    clearPieceEntities(ctx.registry)
    clearFullRows(ctx.world)

    local nxt = state.nextKind
    state.nextKind = popBag()
    spawnPiece(ctx, nxt)
end

local function tryMove(ctx, dx, dy)
    local cur = state.current
    if not cur then return false end
    if not collides(ctx.world, cur.kind, cur.rot, cur.x + dx, cur.y + dy) then
        cur.x = cur.x + dx
        cur.y = cur.y + dy
        syncPieceEntities(ctx.registry, ctx.world)
        return true
    end
    return false
end

local function tryRotate(ctx, dir)
    local cur = state.current
    if not cur then return false end
    local newRot = ((cur.rot - 1 + dir) % 4) + 1
    for _, kx in ipairs({ 0, -1, 1, -2, 2 }) do
        if not collides(ctx.world, cur.kind, newRot, cur.x + kx, cur.y) then
            cur.rot = newRot
            cur.x = cur.x + kx
            syncPieceEntities(ctx.registry, ctx.world)
            return true
        end
    end
    return false
end

return {
    id          = "tetris",
    name        = "Tetris",
    version     = "2.1",
    description = "Drives the current Tilemap & ECS entities using GP-RPG's table grammar.",

    world = {
        hideDefaultEntities = true,
        cameraZoomLevel     = 0,
    },

    tokens = {
        LaunchTetris = {
            description = "Enters Tetris mode on the current map.",
            consumes    = {},
            execute     = function(entityId, ctx)
                require('engine.core.plugin_loader').enter("tetris")
            end
        }
    },

    commands = {
        play = function()
            require('engine.core.plugin_loader').enter("tetris")
        end
    },

    onEnter = function(ctx)
        if not ctx.world then return end
        state.active = true
        state.paused = false
        state.gameOver = false
        state.score = 0
        state.lines = 0
        state.level = 1
        state.dropTimer = 0
        state.bag = refillBag()
        state.nextKind = popBag()

        local ts = ctx.world.tileSize
        ctx.camera.setTarget(
            (ORIGIN_X + COLS / 2 - 0.5) * ts,
            (ORIGIN_Y + ROWS / 2 - 0.5) * ts
        )

        buildTilemapWell(ctx.world)
        spawnPiece(ctx, popBag())
        love.keyboard.setKeyRepeat(true)
    end,

    onExit = function(ctx)
        clearPieceEntities(ctx.registry)
        state.active = false
        state.current = nil
        love.keyboard.setKeyRepeat(false)
    end,

    onUpdate = function(dt, ctx)
        if not state.active or state.paused or state.gameOver or not ctx.world then return end
        local interval = math.max(0.08, 0.75 - (state.level - 1) * 0.06)
        state.dropTimer = state.dropTimer + dt
        if state.dropTimer >= interval then
            state.dropTimer = 0
            if not tryMove(ctx, 0, 1) then
                lockPiece(ctx)
            end
        end
    end,

    onKeypressed = function(key, ctx)
        if not state.active or not ctx.world then return end

        if key == "q" then
            require('engine.core.plugin_loader').exit("tetris")
            return
        elseif key == "r" then
            require('engine.core.plugin_loader').enter("tetris")
            return
        elseif key == "p" and not state.gameOver then
            state.paused = not state.paused
            return
        end

        if state.paused or state.gameOver then return end

        if key == "left" or key == "a" then
            tryMove(ctx, -1, 0)
        elseif key == "right" or key == "d" then
            tryMove(ctx, 1, 0)
        elseif key == "down" or key == "s" then
            if tryMove(ctx, 0, 1) then
                state.score = state.score + 1
                state.dropTimer = 0
            end
        elseif key == "up" or key == "w" or key == "x" then
            tryRotate(ctx, 1)
        elseif key == "z" then
            tryRotate(ctx, -1)
        elseif key == "space" then
            while tryMove(ctx, 0, 1) do
                state.score = state.score + 2
            end
            lockPiece(ctx)
        end
    end,

    onDraw = function(ctx)
        if not state.active then return end
        love.graphics.setColor(0, 0, 0, 0.75)
        love.graphics.rectangle("fill", 16, 56, 230, 175)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("TETRIS (TILEMAP + ECS)", 26, 66)
        love.graphics.print("SCORE: " .. state.score, 26, 90)
        love.graphics.print("LINES: " .. state.lines, 26, 110)
        love.graphics.print("LEVEL: " .. state.level, 26, 130)
        love.graphics.print("NEXT: " .. tostring(state.nextKind), 26, 150)
        love.graphics.setColor(0.75, 0.85, 0.95, 1)
        love.graphics.print("ARROWS/WASD | SPACE | P/R | Q", 26, 180)
        if state.paused then
            love.graphics.setColor(1, 0.9, 0.2, 1)
            love.graphics.print("PAUSED", 26, 204)
        elseif state.gameOver then
            love.graphics.setColor(1, 0.3, 0.3, 1)
            love.graphics.print("GAME OVER (R=Retry Q=Exit)", 26, 204)
        end
    end
}
