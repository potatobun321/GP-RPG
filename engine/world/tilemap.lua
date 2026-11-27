local Registry = require('engine.ecs.registry')
local Factory  = require('engine.core.factory')
local Context  = require('engine.core.context')

local _Theme, _Camera
local function getTheme()  if not _Theme  then _Theme  = require('engine.core.theme') end; return _Theme end
local function getCamera() if not _Camera then _Camera = require('engine.core.camera') end; return _Camera end

local CHUNK_SIZE = 16

local Tilemap = {}
Tilemap.__index = Tilemap

function Tilemap.new(w, h, size)
    local self = setmetatable({}, Tilemap)
    self.width    = w    or 31
    self.height   = h    or 31
    self.tileSize = size or 32
    self.grid     = {}
    self.entities = {}
    self.chunks   = {}
    self.dirtyChunks = {}
    self.animClocks  = {}
    self._needsFullRebuild = true
    return self
end

function Tilemap:clear()
    local toRemove = {}
    for id, comps in pairs(Registry.entities) do
        if not comps.Persistent then
            table.insert(toRemove, id)
        end
    end
    for _, id in ipairs(toRemove) do
        Registry.remove(id)
    end
    self.grid = {}
    self.entities = {}
    self.chunks = {}
    self.dirtyChunks = {}
    self.animClocks = {}
    self._needsFullRebuild = true
    Context.mapDirty = true
end

function Tilemap:saveMap(mapName)
    local mapData = {
        name = mapName,
        width = self.width,
        height = self.height,
        tileSize = self.tileSize,
        zoomLevel = require('engine.core.camera').profiles.gameplay.zoomLevel,
        customBounds = require('engine.core.camera').customBounds,
        tiles = {}
    }
    if self.entities and #self.entities > 0 then
        mapData.entities = self.entities
    end
    
    local function flagsMatch(f1, f2)
        if f1 == nil and f2 == nil then return true end
        if f1 == nil or f2 == nil then return false end
        for k, v in pairs(f1) do if f2[k] ~= v then return false end end
        for k, v in pairs(f2) do if f1[k] ~= v then return false end end
        return true
    end

    for y, row in pairs(self.grid) do
        local sortedRow = {}
        for x, tdata in pairs(row) do
            local tDef = Factory.getTile(tdata.typeId)
            local defaults = tDef.flags or {}
            local customFlags = nil
            if tdata.flags then
                for k, v in pairs(tdata.flags) do
                    if defaults[k] ~= v then
                        if not customFlags then customFlags = {} end
                        customFlags[k] = v
                    end
                end
            end
            table.insert(sortedRow, {x = x, id = tdata.typeId, flags = customFlags})
        end
        table.sort(sortedRow, function(a, b) return a.x < b.x end)
        
        local run = nil
        for _, t in ipairs(sortedRow) do
            if not run then
                run = {x = t.x, y = y, len = 1, id = t.id, flags = t.flags}
            elseif t.x == run.x + run.len and t.id == run.id and flagsMatch(t.flags, run.flags) then
                run.len = run.len + 1
            else
                table.insert(mapData.tiles, run)
                run = {x = t.x, y = y, len = 1, id = t.id, flags = t.flags}
            end
        end
        if run then table.insert(mapData.tiles, run) end
    end
    
    local json = require('lib.json')
    local str = json.encode(mapData)
    
    local devPath = love.filesystem.getSource() .. "/content/maps/" .. mapName .. ".json"
    local f, err = io.open(devPath, "w")
    if f then
        f:write(str)
        f:close()
        print("Saved map (dev mode): " .. devPath)
    else
        love.filesystem.createDirectory("maps")
        local success, msg = love.filesystem.write("maps/" .. mapName .. ".json", str)
        if success then
            print("Saved map (save dir): maps/" .. mapName .. ".json")
        else
            print("Failed to save map: " .. tostring(msg))
        end
    end
end

function Tilemap:loadMap(mapName)
    self:clear()
    
    local Assets = require('engine.core.assets')
    local mapData = Assets.getMapData(mapName)
    
    if not mapData then
        print("Error: Map '" .. mapName .. "' not found.")
        return false
    end
    self.width = mapData.width
    self.height = mapData.height
    self.tileSize = mapData.tileSize or 32
    
    self.mapZoomLevel = nil
    if mapData.zoomLevel then
        self.mapZoomLevel = mapData.zoomLevel
    elseif mapData.baseScale then
        -- Legacy support: convert baseScale float directly to discrete zoomLevel ladder
        self.mapZoomLevel = math.floor(mapData.baseScale - 1.0 + 0.5)
    end
    self.customBounds = mapData.customBounds or nil
    
    for k, v in pairs(mapData.tiles) do
        if type(k) == "string" then
            local x, y = k:match("([^,]+),([^,]+)")
            x, y = tonumber(x), tonumber(y)
            local typeId = type(v) == "string" and v or v.id
            local customFlags = type(v) == "table" and v.flags or nil
            self:setTile(x, y, typeId, customFlags)
        else
            local x, y = v.x, v.y
            local length = v.len or 1
            for i = 0, length - 1 do
                self:setTile(x + i, y, v.id, v.flags)
            end
        end
    end
    Context.mapDirty = true
    self._needsFullRebuild = true
    self.entities = mapData.entities or {}
    for _, entDef in ipairs(self.entities) do
        Factory.spawnMapEntity(entDef, self.tileSize)
    end
    print("Loaded map: " .. mapName)
end

function Tilemap:getTileData(gx, gy)
    if self.grid[gy] and self.grid[gy][gx] then
        return self.grid[gy][gx]
    end
    return nil
end

function Tilemap:setTile(gx, gy, typeId, customFlags)
    if not self.grid[gy] then self.grid[gy] = {} end
    
    local currentMinX = -math.floor(self.width / 2)
    local currentMaxX = math.ceil(self.width / 2) - 1
    local currentMinY = -math.floor(self.height / 2)
    local currentMaxY = math.ceil(self.height / 2) - 1

    if gx < currentMinX or gx > currentMaxX then
        local newMinX = math.min(currentMinX, gx)
        local newMaxX = math.max(currentMaxX, gx)
        self.width = math.max(math.abs(newMinX) * 2, (newMaxX + 1) * 2)
    end
    if gy < currentMinY or gy > currentMaxY then
        local newMinY = math.min(currentMinY, gy)
        local newMaxY = math.max(currentMaxY, gy)
        self.height = math.max(math.abs(newMinY) * 2, (newMaxY + 1) * 2)
    end

    local tpl = Factory.getTile(typeId)
    local finalFlags = {}
    for k, v in pairs(tpl.flags or {}) do finalFlags[k] = v end
    if customFlags then
        for k, v in pairs(customFlags) do finalFlags[k] = v end
    end
    
    self.grid[gy][gx] = { typeId = typeId, flags = finalFlags, gridX = gx, gridY = gy }
    local cx = math.floor(gx / CHUNK_SIZE)
    local cy = math.floor(gy / CHUNK_SIZE)
    self.dirtyChunks[cy] = self.dirtyChunks[cy] or {}
    self.dirtyChunks[cy][cx] = true
    Context.mapDirty = true
end

function Tilemap:isSolidPixel(px, py, w, h, entityZ)
    local ez = entityZ or 0
    local minX = math.floor(px / self.tileSize)
    local maxX = math.floor((px + w - 0.01) / self.tileSize)
    local minY = math.floor(py / self.tileSize)
    local maxY = math.floor((py + h - 0.01) / self.tileSize)
    
    for gy = minY, maxY do
        for gx = minX, maxX do
            local tdata = self:getTileData(gx, gy)
            if not tdata then return true end
            if tdata.flags then
                local tz = tdata.flags.z or 0
                if tdata.flags.solid then
                    if ez <= tz then return true end
                elseif tz > 0 and ez < tz then
                    return true
                end
            end
        end
    end
    return false
end

local DEFAULT_UNTEXTURED_COLOR = {1, 0, 1}

local function buildTileQuads(texture, animDef)
    if animDef._cachedQuads and animDef._cachedTex == texture then
        return animDef._cachedQuads
    end

    local fw = animDef.frameW or 32
    local fh = animDef.frameH or 32
    local l  = animDef.left or 0
    local t  = animDef.top or 0
    local b  = animDef.border or 0
    local iw, ih = texture:getDimensions()

    local coords = {}
    if type(animDef.frames) == "string" then
        local nums = {}
        for n in animDef.frames:gmatch("%d+") do
            table.insert(nums, tonumber(n))
        end
        for i = 1, #nums - 1, 2 do
            table.insert(coords, { nums[i], nums[i + 1] })
        end
    elseif type(animDef.frames) == "table" then
        for _, f in ipairs(animDef.frames) do
            if type(f) == "table" and f[1] and f[2] then
                table.insert(coords, { f[1], f[2] })
            end
        end
    end

    local quads = {}
    for _, c in ipairs(coords) do
        local col, row = c[1], c[2]
        local qx = l + (col - 1) * fw + col * b
        local qy = t + (row - 1) * fh + row * b
        table.insert(quads, love.graphics.newQuad(qx, qy, fw, fh, iw, ih))
    end

    if #quads == 0 then
        table.insert(quads, love.graphics.newQuad(0, 0, fw, fh, iw, ih))
    end

    animDef._cachedQuads = quads
    animDef._cachedTex = texture
    return quads
end

local function rebuildChunk(self, cx, cy)
    self.chunks[cy] = self.chunks[cy] or {}
    local chunk = {
        tileBatches = {},
        animGroups  = {},
        untextured  = {},
    }
    self.chunks[cy][cx] = chunk

    local startX = cx * CHUNK_SIZE
    local startY = cy * CHUNK_SIZE
    local endX   = startX + CHUNK_SIZE - 1
    local endY   = startY + CHUNK_SIZE - 1
    local maxSprites = CHUNK_SIZE * CHUNK_SIZE

    for gy = startY, endY do
        local row = self.grid[gy]
        if row then
            for gx = startX, endX do
                local tdata = row[gx]
                if tdata then
                    local tpl = Factory.getTile(tdata.typeId)
                    local px = gx * self.tileSize
                    local py = gy * self.tileSize

                    if tpl.texture and tpl.animation then
                        local quads = buildTileQuads(tpl.texture, tpl.animation)
                        local clock = self.animClocks[tdata.typeId]
                        if not clock then
                            clock = {
                                quads    = quads,
                                duration = tpl.animation.duration or 0.2,
                                mode     = tpl.animation.mode or "loop",
                                dir      = 1,
                                timer    = 0,
                                frame    = 1,
                            }
                            self.animClocks[tdata.typeId] = clock
                        end

                        local group = chunk.animGroups[tdata.typeId]
                        if not group then
                            group = {
                                batch   = love.graphics.newSpriteBatch(tpl.texture, maxSprites, "dynamic"),
                                clock   = clock,
                                entries = {},
                            }
                            chunk.animGroups[tdata.typeId] = group
                        end
                        local offset = 0
                        local phase = tpl.animation.phase
                        if #quads > 1 then
                            if phase == "noise" then
                                offset = math.floor(love.math.noise(gx * 0.25, gy * 0.25) * #quads)
                            elseif phase == "random" then
                                offset = love.math.random(0, #quads - 1)
                            end
                        end
                        local fw = tpl.animation.frameW or tpl.texture:getWidth()
                        local fh = tpl.animation.frameH or tpl.texture:getHeight()
                        local sx = self.tileSize / fw
                        local sy = self.tileSize / fh
                        local initIdx = ((clock.frame - 1 + offset) % #quads) + 1
                        local spriteId = group.batch:add(quads[initIdx], px, py, 0, sx, sy)
                        table.insert(group.entries, { id = spriteId, px = px, py = py, sx = sx, sy = sy, offset = offset })
                    elseif tpl.texture then
                        local batch = chunk.tileBatches[tpl.texture]
                        if not batch then
                            batch = love.graphics.newSpriteBatch(tpl.texture, maxSprites, "static")
                            chunk.tileBatches[tpl.texture] = batch
                        end
                        local scaleX = self.tileSize / tpl.texture:getWidth()
                        local scaleY = self.tileSize / tpl.texture:getHeight()
                        batch:add(px, py, 0, scaleX, scaleY)
                    else
                        table.insert(chunk.untextured, { px = px, py = py, tpl = tpl })
                    end
                end
            end
        end
    end
end

function Tilemap:update(dt)
    if not self.animClocks then return end
    local advanced = nil
    for typeId, clock in pairs(self.animClocks) do
        local n = #clock.quads
        if n > 1 and clock.duration > 0 then
            clock.timer = clock.timer + dt
            if clock.timer >= clock.duration then
                clock.timer = clock.timer - clock.duration
                if clock.mode == "pingpong" then
                    local nxt = clock.frame + clock.dir
                    if nxt > n then
                        clock.dir = -1
                        nxt = math.max(1, n - 1)
                    elseif nxt < 1 then
                        clock.dir = 1
                        nxt = math.min(n, 2)
                    end
                    clock.frame = nxt
                else
                    clock.frame = (clock.frame % n) + 1
                end
                advanced = advanced or {}
                advanced[typeId] = clock
            end
        end
    end
    if not advanced then return end

    for _, row in pairs(self.chunks) do
        for _, chunk in pairs(row) do
            for typeId, clock in pairs(advanced) do
                local group = chunk.animGroups[typeId]
                if group then
                    local n = #clock.quads
                    for _, entry in ipairs(group.entries) do
                        local idx = ((clock.frame - 1 + (entry.offset or 0)) % n) + 1
                        group.batch:set(entry.id, clock.quads[idx], entry.px, entry.py, 0, entry.sx, entry.sy)
                    end
                end
            end
        end
    end
end

function Tilemap:draw()
    if Context.mapDirty then
        if self._needsFullRebuild then
            self.chunks = {}
            self.dirtyChunks = {}
            self.animClocks = {}
            for gy, row in pairs(self.grid) do
                local cy = math.floor(gy / CHUNK_SIZE)
                for gx in pairs(row) do
                    local cx = math.floor(gx / CHUNK_SIZE)
                    self.dirtyChunks[cy] = self.dirtyChunks[cy] or {}
                    self.dirtyChunks[cy][cx] = true
                end
            end
            self._needsFullRebuild = false
        end
        for cy, cols in pairs(self.dirtyChunks) do
            for cx in pairs(cols) do
                rebuildChunk(self, cx, cy)
            end
        end
        self.dirtyChunks = {}
        Context.mapDirty = false
    end

    local colors = getTheme().get()
    local Camera = getCamera()
    local sw, sh = love.graphics.getDimensions()
    local x0, y0 = Camera:screenToWorld(0, 0)
    local x1, y1 = Camera:screenToWorld(sw, sh)
    local chunkPx = CHUNK_SIZE * self.tileSize
    local minCx = math.floor(x0 / chunkPx)
    local maxCx = math.floor(x1 / chunkPx)
    local minCy = math.floor(y0 / chunkPx)
    local maxCy = math.floor(y1 / chunkPx)

    love.graphics.setColor(1, 1, 1, 1)
    for cy = minCy, maxCy do
        local row = self.chunks[cy]
        if row then
            for cx = minCx, maxCx do
                local chunk = row[cx]
                if chunk then
                    for _, batch in pairs(chunk.tileBatches) do
                        love.graphics.draw(batch, 0, 0)
                    end
                    for _, group in pairs(chunk.animGroups) do
                        love.graphics.draw(group.batch, 0, 0)
                    end
                    for _, t in ipairs(chunk.untextured) do
                        local c = colors[t.tpl.colorKey] or DEFAULT_UNTEXTURED_COLOR
                        if t.tpl.draw_style == "line" then
                            love.graphics.setColor(c[1], c[2], c[3], 0.2)
                            love.graphics.rectangle("line", t.px, t.py, self.tileSize, self.tileSize)
                        else
                            love.graphics.setColor(c)
                            love.graphics.rectangle("fill", t.px, t.py, self.tileSize, self.tileSize)
                        end
                    end
                    love.graphics.setColor(1, 1, 1, 1)
                end
            end
        end
    end
end

return Tilemap