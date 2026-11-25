-- content/plugins/tetris.lua
-- Complete Tetris game implemented purely as a drop-in GP-RPG plugin.
-- Launch from the in-game console (~) with: plugin.run tetris   (or just: tetris)

local COLS = 10
local ROWS = 20
local CELL = 26

local PIECES = {
    I = {
        color = { 0.2, 0.85, 0.95 },
        shapes = {
            { {0,0,0,0}, {1,1,1,1}, {0,0,0,0}, {0,0,0,0} },
            { {0,0,1,0}, {0,0,1,0}, {0,0,1,0}, {0,0,1,0} },
            { {0,0,0,0}, {0,0,0,0}, {1,1,1,1}, {0,0,0,0} },
            { {0,1,0,0}, {0,1,0,0}, {0,1,0,0}, {0,1,0,0} },
        }
    },
    O = {
        color = { 0.95, 0.85, 0.2 },
        shapes = {
            { {1,1}, {1,1} },
            { {1,1}, {1,1} },
            { {1,1}, {1,1} },
            { {1,1}, {1,1} },
        }
    },
    T = {
        color = { 0.75, 0.3, 0.9 },
        shapes = {
            { {0,1,0}, {1,1,1}, {0,0,0} },
            { {0,1,0}, {0,1,1}, {0,1,0} },
            { {0,0,0}, {1,1,1}, {0,1,0} },
            { {0,1,0}, {1,1,0}, {0,1,0} },
        }
    },
    S = {
        color = { 0.25, 0.85, 0.4 },
        shapes = {
            { {0,1,1}, {1,1,0}, {0,0,0} },
            { {0,1,0}, {0,1,1}, {0,0,1} },
            { {0,0,0}, {0,1,1}, {1,1,0} },
            { {1,0,0}, {1,1,0}, {0,1,0} },
        }
    },
    Z = {
        color = { 0.95, 0.3, 0.3 },
        shapes = {
            { {1,1,0}, {0,1,1}, {0,0,0} },
            { {0,0,1}, {0,1,1}, {0,1,0} },
            { {0,0,0}, {1,1,0}, {0,1,1} },
            { {0,1,0}, {1,1,0}, {1,0,0} },
        }
    },
    J = {
        color = { 0.3, 0.45, 0.95 },
        shapes = {
            { {1,0,0}, {1,1,1}, {0,0,0} },
            { {0,1,1}, {0,1,0}, {0,1,0} },
            { {0,0,0}, {1,1,1}, {0,0,1} },
            { {0,1,0}, {0,1,0}, {1,1,0} },
        }
    },
    L = {
        color = { 0.95, 0.6, 0.2 },
        shapes = {
            { {0,0,1}, {1,1,1}, {0,0,0} },
            { {0,1,0}, {0,1,0}, {0,1,1} },
            { {0,0,0}, {1,1,1}, {1,0,0} },
            { {1,1,0}, {0,1,0}, {0,1,0} },
        }
    },
}

local PIECE_KEYS = { "I", "O", "T", "S", "Z", "J", "L" }

local game = {}

local function newBoard()
    local b = {}
    for r = 1, ROWS do
        b[r] = {}
        for c = 1, COLS do
            b[r][c] = nil
        end
    end
    return b
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
    if not game.bag or #game.bag == 0 then
        game.bag = refillBag()
    end
    return table.remove(game.bag)
end

local function collides(kind, rot, gx, gy)
    local shape = PIECES[kind].shapes[rot]
    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] == 1 then
                local bx = gx + c - 1
                local by = gy + r - 1
                if bx < 1 or bx > COLS or by > ROWS then
                    return true
                end
                if by >= 1 and game.board[by][bx] ~= nil then
                    return true
                end
            end
        end
    end
    return false
end

local function spawnPiece(kind)
    game.current = {
        kind = kind or popBag(),
        rot = 1,
        x = 4,
        y = 1
    }
    if kind == "O" then game.current.x = 5 end
    if collides(game.current.kind, game.current.rot, game.current.x, game.current.y) then
        game.gameOver = true
    end
end

local function resetGame()
    game.board = newBoard()
    game.bag = refillBag()
    game.nextKind = popBag()
    game.holdKind = nil
    game.canHold = true
    game.score = 0
    game.lines = 0
    game.level = 1
    game.dropTimer = 0
    game.paused = false
    game.gameOver = false
    spawnPiece(game.nextKind)
    game.nextKind = popBag()
end

local function lockPiece()
    local cur = game.current
    local shape = PIECES[cur.kind].shapes[cur.rot]
    local color = PIECES[cur.kind].color

    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] == 1 then
                local bx = cur.x + c - 1
                local by = cur.y + r - 1
                if by >= 1 and by <= ROWS and bx >= 1 and bx <= COLS then
                    game.board[by][bx] = color
                end
            end
        end
    end

    -- Clear full lines
    local cleared = 0
    for r = ROWS, 1, -1 do
        local full = true
        for c = 1, COLS do
            if not game.board[r][c] then full = false; break end
        end
        if full then
            cleared = cleared + 1
            table.remove(game.board, r)
            local emptyRow = {}
            for c = 1, COLS do emptyRow[c] = nil end
            table.insert(game.board, 1, emptyRow)
        end
    end

    if cleared > 0 then
        local pts = { 100, 300, 500, 800 }
        game.score = game.score + (pts[cleared] or 800) * game.level
        game.lines = game.lines + cleared
        game.level = math.floor(game.lines / 10) + 1
    end

    game.canHold = true
    spawnPiece(game.nextKind)
    game.nextKind = popBag()
end

local function tryMove(dx, dy)
    local cur = game.current
    if not collides(cur.kind, cur.rot, cur.x + dx, cur.y + dy) then
        cur.x = cur.x + dx
        cur.y = cur.y + dy
        return true
    end
    return false
end

local function tryRotate(dir)
    local cur = game.current
    local newRot = ((cur.rot - 1 + dir) % 4) + 1
    local kicks = { 0, -1, 1, -2, 2 }
    for _, kx in ipairs(kicks) do
        if not collides(cur.kind, newRot, cur.x + kx, cur.y) then
            cur.rot = newRot
            cur.x = cur.x + kx
            return true
        end
    end
    return false
end

local function ghostY()
    local cur = game.current
    local gy = cur.y
    while not collides(cur.kind, cur.rot, cur.x, gy + 1) do
        gy = gy + 1
    end
    return gy
end

local function drawCell(x, y, color, alpha)
    love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
    love.graphics.rectangle("fill", x + 1, y + 1, CELL - 2, CELL - 2)
    love.graphics.setColor(1, 1, 1, (alpha or 1) * 0.25)
    love.graphics.rectangle("line", x + 1, y + 1, CELL - 2, CELL - 2)
end

local function drawMiniPiece(kind, px, py, size)
    if not kind then return end
    local shape = PIECES[kind].shapes[1]
    local color = PIECES[kind].color
    for r = 1, #shape do
        for c = 1, #shape[r] do
            if shape[r][c] == 1 then
                love.graphics.setColor(color[1], color[2], color[3], 1)
                love.graphics.rectangle("fill", px + (c - 1) * size, py + (r - 1) * size, size - 2, size - 2)
            end
        end
    end
end

local TetrisScene = {}

function TetrisScene:load(api)
    love.graphics.setBackgroundColor(0.06, 0.07, 0.1)
    love.keyboard.setKeyRepeat(true)
    resetGame()
end

function TetrisScene:update(dt, api)
    if game.paused or game.gameOver then return end
    local interval = math.max(0.08, 0.75 - (game.level - 1) * 0.06)
    game.dropTimer = game.dropTimer + dt
    if game.dropTimer >= interval then
        game.dropTimer = 0
        if not tryMove(0, 1) then
            lockPiece()
        end
    end
end

function TetrisScene:keypressed(key, api)
    if key == "q" or key == "escape" then
        love.keyboard.setKeyRepeat(false)
        api.exitToGame()
        return
    end
    if key == "r" then
        resetGame()
        return
    end
    if key == "p" and not game.gameOver then
        game.paused = not game.paused
        return
    end
    if game.paused or game.gameOver then return end

    if key == "left" or key == "a" then
        tryMove(-1, 0)
    elseif key == "right" or key == "d" then
        tryMove(1, 0)
    elseif key == "down" or key == "s" then
        if tryMove(0, 1) then
            game.score = game.score + 1
            game.dropTimer = 0
        end
    elseif key == "up" or key == "w" or key == "x" then
        tryRotate(1)
    elseif key == "z" then
        tryRotate(-1)
    elseif key == "space" then
        local gy = ghostY()
        game.score = game.score + (gy - game.current.y) * 2
        game.current.y = gy
        lockPiece()
    elseif key == "c" and game.canHold then
        local curKind = game.current.kind
        if game.holdKind then
            local swap = game.holdKind
            game.holdKind = curKind
            spawnPiece(swap)
        else
            game.holdKind = curKind
            spawnPiece(game.nextKind)
            game.nextKind = popBag()
        end
        game.canHold = false
    end
end

function TetrisScene:draw(api)
    local sw, sh = love.graphics.getDimensions()
    local boardW = COLS * CELL
    local boardH = ROWS * CELL
    local bx = math.floor((sw - boardW) / 2)
    local by = math.floor((sh - boardH) / 2)

    -- Board background & grid
    love.graphics.setColor(0.11, 0.12, 0.16)
    love.graphics.rectangle("fill", bx, by, boardW, boardH)
    love.graphics.setColor(0.2, 0.22, 0.28)
    for r = 0, ROWS do
        love.graphics.line(bx, by + r * CELL, bx + boardW, by + r * CELL)
    end
    for c = 0, COLS do
        love.graphics.line(bx + c * CELL, by, bx + c * CELL, by + boardH)
    end

    -- Placed blocks
    for r = 1, ROWS do
        for c = 1, COLS do
            local color = game.board[r][c]
            if color then
                drawCell(bx + (c - 1) * CELL, by + (r - 1) * CELL, color, 1)
            end
        end
    end

    -- Ghost & active piece
    if game.current and not game.gameOver then
        local cur = game.current
        local shape = PIECES[cur.kind].shapes[cur.rot]
        local color = PIECES[cur.kind].color
        local gy = ghostY()

        for r = 1, #shape do
            for c = 1, #shape[r] do
                if shape[r][c] == 1 then
                    local gx = bx + (cur.x + c - 2) * CELL
                    drawCell(gx, by + (gy + r - 2) * CELL, color, 0.22)
                    drawCell(gx, by + (cur.y + r - 2) * CELL, color, 1)
                end
            end
        end
    end

    -- Board border
    love.graphics.setColor(0.55, 0.6, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx, by, boardW, boardH)
    love.graphics.setLineWidth(1)

    -- Side HUD
    local rx = bx + boardW + 24
    love.graphics.setColor(0.9, 0.9, 0.95)
    love.graphics.print("TETRIS (PLUGIN)", rx, by)
    love.graphics.print("SCORE: " .. game.score, rx, by + 30)
    love.graphics.print("LINES: " .. game.lines, rx, by + 54)
    love.graphics.print("LEVEL: " .. game.level, rx, by + 78)

    love.graphics.print("NEXT:", rx, by + 120)
    drawMiniPiece(game.nextKind, rx, by + 144, 18)

    love.graphics.print("HOLD (C):", rx, by + 220)
    drawMiniPiece(game.holdKind, rx, by + 244, 18)

    love.graphics.setColor(0.65, 0.68, 0.75)
    love.graphics.print("ARROWS/WASD: Move", rx, by + 330)
    love.graphics.print("UP/Z/X: Rotate", rx, by + 350)
    love.graphics.print("SPACE: Drop", rx, by + 370)
    love.graphics.print("P: Pause  R: Reset", rx, by + 390)
    love.graphics.print("Q: Back to GP-RPG", rx, by + 410)

    if game.paused then
        love.graphics.setColor(0, 0, 0, 0.65)
        love.graphics.rectangle("fill", bx, by, boardW, boardH)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("PAUSED", bx, by + boardH / 2 - 10, boardW, "center")
    elseif game.gameOver then
        love.graphics.setColor(0, 0, 0, 0.75)
        love.graphics.rectangle("fill", bx, by, boardW, boardH)
        love.graphics.setColor(1, 0.35, 0.35)
        love.graphics.printf("GAME OVER\nPress R to Retry\nPress Q to Exit", bx, by + boardH / 2 - 30, boardW, "center")
    end
end

return {
    id = "tetris",
    name = "Tetris",
    version = "1.0",
    description = "Playable Tetris game loaded purely as a GP-RPG plugin.",
    scene = TetrisScene,
    tokens = {
        LaunchTetris = {
            description = "Switches to the Tetris plugin scene.",
            consumes = {},
            execute = function(entityId, api)
                require('engine.core.plugin_loader').launchScene("tetris")
            end
        }
    },
    commands = {
        play = function()
            require('engine.core.plugin_loader').launchScene("tetris")
        end
    }
}
