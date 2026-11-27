-- engine/state/save_manager.lua
-- Persists and restores RPG state: current map, player position/HP, FlagManager, and AttributeManager.

local json             = require('lib.json')
local Registry         = require('engine.ecs.registry')
local FlagManager      = require('engine.state.flag_manager')
local AttributeManager = require('engine.state.attribute_manager')
local Camera           = require('engine.core.camera')
local Context          = require('engine.core.context')

local SaveManager = {}

local SAVE_DIR = "saves"

local function slotPath(slotName)
    local clean = (slotName and slotName ~= "") and slotName:gsub("[^%w_%-]", "_") or "slot1"
    return SAVE_DIR .. "/" .. clean .. ".json", clean
end

function SaveManager.save(slotName, game)
    if not game or not game.world then
        return false, "No active game world."
    end

    local playerData = nil
    if game.playerId and Registry.entities[game.playerId] then
        local t = Registry.get(game.playerId, "Transform")
        local h = Registry.get(game.playerId, "Health")
        playerData = {
            x     = t and t.x or 0,
            y     = t and t.y or 0,
            hp    = h and h.current or 100,
            maxHp = h and h.max or 100,
        }
    end

    local payload = {
        version    = 1,
        map        = game.currentMapName or "map1",
        player     = playerData,
        flags      = FlagManager.serialize(),
        attributes = AttributeManager.serialize(),
    }

    love.filesystem.createDirectory(SAVE_DIR)
    local path, clean = slotPath(slotName)
    local ok, err = love.filesystem.write(path, json.encode(payload))
    if not ok then
        return false, tostring(err)
    end
    return true, clean
end

function SaveManager.load(slotName, game)
    if not game or not game.world then
        return false, "No active game world."
    end

    local path, clean = slotPath(slotName)
    if not love.filesystem.getInfo(path) then
        return false, "Save slot '" .. clean .. "' not found."
    end

    local raw, readErr = love.filesystem.read(path)
    if not raw then
        return false, tostring(readErr)
    end

    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= "table" then
        return false, "Corrupted save file."
    end

    FlagManager.deserialize(data.flags)
    AttributeManager.deserialize(data.attributes)

    local targetMap = data.map or "map1"
    if targetMap ~= game.currentMapName then
        game.currentMapName = targetMap
        game.world:loadMap(targetMap)
        if game.world.mapZoomLevel then
            Camera.profiles.gameplay.zoomLevel = game.world.mapZoomLevel
            Camera.profiles.gameplay.targetZoomLevel = game.world.mapZoomLevel
        end
        Camera.customBounds = game.world.customBounds
    end

    if game.spawnDefaultEntities then
        game:spawnDefaultEntities()
    end

    if data.player and game.playerId then
        local t = Registry.get(game.playerId, "Transform")
        if t then
            t.x = data.player.x or 0
            t.y = data.player.y or 0
            Context.lastTeleportTile = {
                x = math.floor((t.x + t.w / 2) / game.world.tileSize),
                y = math.floor((t.y + t.h / 2) / game.world.tileSize),
            }
        end
        local h = Registry.get(game.playerId, "Health")
        if h then
            h.max     = data.player.maxHp or h.max
            h.current = data.player.hp or h.current
        end
    end

    return true, clean
end

function SaveManager.list()
    local info = love.filesystem.getInfo(SAVE_DIR)
    if not info or info.type ~= "directory" then return {} end
    local out = {}
    for _, file in ipairs(love.filesystem.getDirectoryItems(SAVE_DIR)) do
        if file:sub(-5) == ".json" then
            table.insert(out, file:sub(1, -6))
        end
    end
    table.sort(out)
    return out
end

function SaveManager.delete(slotName)
    local path = slotPath(slotName)
    if love.filesystem.getInfo(path) then
        return love.filesystem.remove(path)
    end
    return false
end

return SaveManager
