-- engine/core/debug_overlay.lua
-- Visual debug mode (toggle with F3 or `debug` in console).

local Registry     = require('engine.ecs.registry')
local Camera       = require('engine.core.camera')
local PluginLoader = require('engine.core.plugin_loader')

local DebugOverlay = {
    enabled = false,
}

function DebugOverlay.toggle()
    DebugOverlay.enabled = not DebugOverlay.enabled
    return DebugOverlay.enabled
end

function DebugOverlay.drawWorld(world)
    if not DebugOverlay.enabled or not world then return end

    local ts = world.tileSize or 32
    -- Draw visible tile grid + portal/solid markers
    local sw, sh = love.graphics.getDimensions()
    local x0, y0 = Camera:screenToWorld(0, 0)
    local x1, y1 = Camera:screenToWorld(sw, sh)
    local minGx = math.floor(x0 / ts)
    local maxGx = math.floor(x1 / ts)
    local minGy = math.floor(y0 / ts)
    local maxGy = math.floor(y1 / ts)

    love.graphics.setLineWidth(1)
    for gy = minGy, maxGy do
        for gx = minGx, maxGx do
            local px, py = gx * ts, gy * ts
            local tdata = world:getTileData(gx, gy)
            if tdata and tdata.flags then
                if tdata.flags.isSceneTransition then
                    love.graphics.setColor(0.2, 0.8, 1.0, 0.35)
                    love.graphics.rectangle("fill", px, py, ts, ts)
                elseif tdata.flags.solid then
                    love.graphics.setColor(1.0, 0.25, 0.25, 0.20)
                    love.graphics.rectangle("fill", px, py, ts, ts)
                end
            end
            love.graphics.setColor(1, 1, 1, 0.08)
            love.graphics.rectangle("line", px, py, ts, ts)
        end
    end

    -- Draw entity Transform (blue) and Collider (green) boxes
    for id, comps in pairs(Registry.entities) do
        local t = comps.Transform
        if t then
            love.graphics.setColor(0.3, 0.6, 1.0, 0.6)
            love.graphics.rectangle("line", t.x, t.y, t.w, t.h)

            local c = comps.Collider
            if c then
                local cx = t.x + (c.ox or 0)
                local cy = t.y + (c.oy or 0)
                love.graphics.setColor(0.2, 1.0, 0.4, 0.9)
                love.graphics.rectangle("line", cx, cy, c.w, c.h)
                if c.r and c.r > 0 then
                    love.graphics.setColor(0.2, 0.85, 1.0, 0.85)
                    love.graphics.circle("line", t.x + (c.rox or t.w / 2), t.y + (c.roy or t.h / 2), c.r)
                end
            end
        end
    end
end

function DebugOverlay.drawHUD(game)
    if not DebugOverlay.enabled then return end

    local entCount = 0
    for _ in pairs(Registry.entities) do entCount = entCount + 1 end

    local px, py, pz, gx, gy = 0, 0, 0, 0, 0
    if game and game.playerId then
        local t = Registry.get(game.playerId, "Transform")
        local ts = (game.world and game.world.tileSize) or 32
        if t then
            px, py, pz = math.floor(t.x), math.floor(t.y), (t.z or 0)
            gx = math.floor((t.x + t.w / 2) / ts)
            gy = math.floor((t.y + t.h / 2) / ts)
        end
    end

    local lines = {
        string.format("FPS: %d  |  Entities: %d", love.timer.getFPS(), entCount),
        string.format("Map: %s%s  |  Zoom: %d (%.1fx)",
            tostring(game and game.currentMapName or "?"),
            (game and game.world and game.world._isIsolated) and " [ISO]" or "",
            Camera.getZoom(), Camera.scale or 1),
        string.format("Pos: (%d, %d, z=%g)  Grid: (%d, %d)", px, py, pz, gx, gy),
        string.format("Mode: %s  |  F3: Toggle Debug", tostring(PluginLoader.activeMode or "rpg")),
    }

    local font = love.graphics.getFont()
    local maxW = 0
    for _, line in ipairs(lines) do
        local w = font and font:getWidth(line) or (#line * 10)
        if w > maxW then maxW = w end
    end
    local boxW = maxW + 20
    local boxH = #lines * 16 + 14
    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", 10, 74, boxW, boxH, 4, 4)
    love.graphics.setColor(0.3, 1.0, 0.5, 0.8)
    love.graphics.rectangle("line", 10, 74, boxW, boxH, 4, 4)

    love.graphics.setColor(0.9, 1.0, 0.9, 1)
    for i, line in ipairs(lines) do
        love.graphics.print(line, 18, 80 + (i - 1) * 16)
    end
end

return DebugOverlay
