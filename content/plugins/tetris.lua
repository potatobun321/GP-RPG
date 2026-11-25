-- content/plugins/tetris.lua
-- Tetris built purely from GP-RPG engine elements:
--   * Board & locked blocks = GP-RPG Tilemap tiles (wall, void, lava, water, sand, grass, wood, ...)
--   * Active falling piece  = 4 GP-RPG ECS entities (Transform + Renderable + Flags)
--   * Collision             = Tilemap:getTileData() & tile solid flags
--   * Rendering & Camera    = GP-RPG Systems.RenderSystem() + Tilemap:draw() + Camera
--
-- Open console (~) and type: tetris

local COLS = 10
local ROWS = 20

-- Board origin in Tilemap grid coordinates (placed to the right of spawn so it's clearly visible)
local ORIGIN_X = -5
local ORIGIN_Y = -10

-- Each tetromino maps to an existing GP-RPG tile in content/tiles/
local PIECES = {
    I = {
        tileId = "water",
        shapes = {
            { {0,0,0,0}, {1,1,1,1}, {0,0,0,0}, {0,0,0,0} },
            { {0,0,1,0}, {0,0,1,0}, {0,0,1,0}, {0,0,1,0} },
            { {0,0,0,0}, {0,0,0,0}, {1,1,1,1}, {0,0,0,0} },
            { {0,1,0,0}, {0,1,0,0}, {0,1,0,0}, {0,1,0,0} },
        }
    },
    O = {
        tileId = "sand",
        shapes = {
            { {1,1}, {1,1} },
            { {1,1}, {1,1} },
            { {1,1}, {1,1} },
            { {1,1}, {1,1} },
        }
    },
    T = {
        tileId = "lava2",
        shapes = {
            { {0,1,0}, {1,1,1}, {0,0,0} },
            { {0,1,0}, {0,1,1}, {0,1,0} },
            { {0,0,0}, {1,1,1}, {0,1,0} },
            { {0,1,0}, {1,1,0}, {0,1,0} },
        }
    },
    S = {
        tileId = "grass",
        shapes = {
            { {0,1,1}, {1,1,0}, {0,0,0} },
            { {0,1,0}, {0,1,1}, {0,0,1} },
            { {0,0,0}, {0,1,1}, {1,1,0} },
            { {1,0,0}, {1,1,0}, {0,1,0} },
        }
    },
    Z = {
        tileId = "lava",
        shapes = {
            { {1,1,0}, {0,1,1}, {0,0,0} },
            { {0,0,1}, {0,1,1}, {0,1,0} },
            { {0,0,0}, {1,1,0}, {0,1,1} },
            { {0,1,0}, {1,1,0}, {1,0,0} },
        }
    },
    J = {
        tileId = "seawater",
        shapes = {
            { {1,0,0}, {1,1,1}, {0,0,0} },
            { {0,1,1}, {0,1,0}, {0,1,0} },
            { {0,0,0}, {1,1,1}, {0,0,1} },
            { {0,1,0}, {0,1,0}, {1,1,0} },
        }
    },
    L = {
        tileId = "wood",
        shapes = {
            { {0,0,1}, {1,1,1}, {0,0,0} },
            { {0,1,0}, {0,1,0}, {0,1,1} },
            { {0,0,0}, {1,1,1}, {1,0,0} },
            { {1,1,0}, {0,1,0}, {0,1,0} },
        }
    },
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
    savedPlayerInput = nil,
}

local function getGame()
    return require('scenes.game')
end

local function clearPieceEntities(Registry)
    for _, id in ipairs(state.pieceEntities) do
        Registry.remove(id)
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
    if #state.bag == 0 then
        state.bag = refillBag()
    end
    return table.remove(state.bag)
end

-- Build the Tetris well directly inside GP-RPG's Tilemap using wall & void tiles
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

-- Collision checks directly against GP-RPG's Tilemap!
local function collides(world, kind, rot, bx, by)
    local shape = PIECES[kind].shapes[rot]
    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] == 1 then
                local col = bx + c - 1
                local row = by + r - 1
                if col < 1 or col > COLS or row > ROWS then
                    return true
                end
                if row >= 1 then
                    local gx = ORIGIN_X + col - 1
                    local gy = ORIGIN_Y + row - 1
                    local tdata = world:getTileData(gx, gy)
                    if tdata and tdata.flags and tdata.flags.solid then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- Sync the 4 ECS entities' Transform components to the active piece's grid coordinates
local function syncPieceEntities(Registry, world)
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
                    local tr = Registry.get(id, "Transform")
                    local attrs = Registry.get(id, "Attributes")
                    if tr then
                        tr.x = gx * ts
                        tr.y = gy * ts
                        tr.w = ts
                        tr.h = ts
                    end
                    if attrs then
                        attrs.gx = gx
                        attrs.gy = gy
                    end
                end
                idx = idx + 1
            end
        end
    end
end

local function spawnPiece(Registry, world, kind)
    clearPieceEntities(Registry)

    local Components = require('engine.ecs.components')
    local Factory = require('engine.core.factory')

    local k = kind or popBag()
    local tileId = PIECES[k].tileId
    local tileDef = Factory.getTile(tileId)

    state.current = {
        kind = k,
        rot = 1,
        x = (k == "O") and 5 or 4,
        y = 1
    }

    if collides(world, k, 1, state.current.x, state.current.y) then
        state.gameOver = true
        return
    end

    -- Spawn 4 real GP-RPG ECS entities for the falling piece
    for _ = 1, 4 do
        local id = Registry.create()
        Registry.add(id, "Transform", Components.Transform(0, 0, world.tileSize, world.tileSize))
        Registry.add(id, "Renderable", Components.Renderable("character", tileDef.colorKey, tileDef.texture, "fill"))
        Registry.add(id, "Flags", Components.Flags({ is_tetris_piece = true }))
        Registry.add(id, "Attributes", Components.Attributes({ tileId = tileId }))
        table.insert(state.pieceEntities, id)
    end

    syncPieceEntities(Registry, world)
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

-- Lock piece by writing its 4 cells into GP-RPG's Tilemap as solid tiles
local function lockPiece(Registry, world)
    local cur = state.current
    if not cur then return end
    local tileId = PIECES[cur.kind].tileId
    local shape = PIECES[cur.kind].shapes[cur.rot]

    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] == 1 then
                local gx = ORIGIN_X + (cur.x + c - 1) - 1
                local gy = ORIGIN_Y + (cur.y + r - 1) - 1
                world:setTile(gx, gy, tileId, { solid = true, tetris_locked = true })
            end
        end
    end

    clearPieceEntities(Registry)
    clearFullRows(world)

    local nxt = state.nextKind
    state.nextKind = popBag()
    spawnPiece(Registry, world, nxt)
end

local function startTetris()
    local g = getGame()
    if not g or not g.world then return end
    local Registry = require('engine.ecs.registry')
    local Camera = require('engine.core.camera')

    state.active = true
    state.paused = false
    state.gameOver = false
    state.score = 0
    state.lines = 0
    state.level = 1
    state.dropTimer = 0
    state.bag = refillBag()
    state.nextKind = popBag()

    -- Temporarily pause player WASD movement while playing Tetris
    if g.playerId and Registry.has(g.playerId, "PlayerInput") then
        state.savedPlayerInput = Registry.get(g.playerId, "PlayerInput")
        Registry.entities[g.playerId]["PlayerInput"] = nil
        local vel = Registry.get(g.playerId, "Velocity")
        if vel then vel.dx, vel.dy = 0, 0 end
    end

    -- Frame the Tilemap well with GP-RPG's Camera
    local ts = g.world.tileSize
    Camera.isFreeCam = true
    Camera.x = (ORIGIN_X + COLS / 2 - 0.5) * ts
    Camera.y = (ORIGIN_Y + ROWS / 2 - 0.5) * ts

    buildTilemapWell(g.world)
    spawnPiece(Registry, g.world, popBag())
    love.keyboard.setKeyRepeat(true)
end

local function stopTetris()
    local g = getGame()
    local Registry = require('engine.ecs.registry')
    local Camera = require('engine.core.camera')
    local Components = require('engine.ecs.components')

    clearPieceEntities(Registry)
    state.active = false
    state.current = nil
    love.keyboard.setKeyRepeat(false)
    Camera.isFreeCam = false

    if g and g.playerId then
        Registry.add(g.playerId, "PlayerInput", state.savedPlayerInput or Components.PlayerInput())
        state.savedPlayerInput = nil
    end
end

local function tryMove(Registry, world, dx, dy)
    local cur = state.current
    if not cur then return false end
    if not collides(world, cur.kind, cur.rot, cur.x + dx, cur.y + dy) then
        cur.x = cur.x + dx
        cur.y = cur.y + dy
        syncPieceEntities(Registry, world)
        return true
    end
    return false
end

local function tryRotate(Registry, world, dir)
    local cur = state.current
    if not cur then return false end
    local newRot = ((cur.rot - 1 + dir) % 4) + 1
    for _, kx in ipairs({ 0, -1, 1, -2, 2 }) do
        if not collides(world, cur.kind, newRot, cur.x + kx, cur.y) then
            cur.rot = newRot
            cur.x = cur.x + kx
            syncPieceEntities(Registry, world)
            return true
        end
    end
    return false
end

return {
    id = "tetris",
    name = "Tetris (Engine-Native)",
    version = "2.0",
    description = "Tetris built from GP-RPG Tilemap tiles and ECS entities.",

    tokens = {
        LaunchTetris = {
            description = "Starts in-world Tetris using GP-RPG Tilemap and ECS entities.",
            consumes = {},
            execute = function(entityId, api)
                startTetris()
            end
        }
    },

    commands = {
        play = function()
            if state.active then stopTetris() else startTetris() end
        end
    },

    onUpdate = function(dt, api)
        if not state.active or state.paused or state.gameOver then return end
        local g = getGame()
        if not g or not g.world then return end

        local interval = math.max(0.08, 0.75 - (state.level - 1) * 0.06)
        state.dropTimer = state.dropTimer + dt
        if state.dropTimer >= interval then
            state.dropTimer = 0
            if not tryMove(api.Registry, g.world, 0, 1) then
                lockPiece(api.Registry, g.world)
            end
        end
    end,

    onKeypressed = function(key, api)
        if not state.active then return end
        local g = getGame()
        if not g or not g.world then return end

        if key == "q" then
            stopTetris()
            return
        elseif key == "r" then
            startTetris()
            return
        elseif key == "p" and not state.gameOver then
            state.paused = not state.paused
            return
        end

        if state.paused or state.gameOver then return end

        if key == "left" or key == "a" then
            tryMove(api.Registry, g.world, -1, 0)
        elseif key == "right" or key == "d" then
            tryMove(api.Registry, g.world, 1, 0)
        elseif key == "down" or key == "s" then
            if tryMove(api.Registry, g.world, 0, 1) then
                state.score = state.score + 1
                state.dropTimer = 0
            end
        elseif key == "up" or key == "w" or key == "x" then
            tryRotate(api.Registry, g.world, 1)
        elseif key == "z" then
            tryRotate(api.Registry, g.world, -1)
        elseif key == "space" then
            while tryMove(api.Registry, g.world, 0, 1) do
                state.score = state.score + 2
            end
            lockPiece(api.Registry, g.world)
        end
    end,

    onDraw = function(api)
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
