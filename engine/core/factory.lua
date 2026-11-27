local Registry = require('engine.ecs.registry')
local Components = require('engine.ecs.components')

local Factory = {
    tiles = {},
    characters = {}
}

local Assets = require('engine.core.assets')

local function safeLoad(path)
    return Assets.getImage(path)
end

local _flagTableCache = nil

local function getFlagDefaults()
    if not _flagTableCache then
        _flagTableCache = love.filesystem.load("content/tiles/flagTable.lua")()
    end
    return _flagTableCache
end

function Factory.registerTile(tileDef)
    if type(tileDef) ~= "table" or not tileDef.id then return false end
    if tileDef.texturePath then
        tileDef.texture = safeLoad(tileDef.texturePath)
    end
    local flagTable = getFlagDefaults()
    tileDef.flags = tileDef.flags or {}
    for k, v in pairs(flagTable) do
        if tileDef.flags[k] == nil then
            tileDef.flags[k] = v
        end
    end
    Factory.tiles[tileDef.id] = tileDef
    return true
end

function Factory.load()
    _flagTableCache = love.filesystem.load("content/tiles/flagTable.lua")()

    -- Dynamically load all tiles from content/tiles
    local files = love.filesystem.getDirectoryItems("content/tiles")
    for _, file in ipairs(files) do
        if file:sub(-4) == ".lua" and file ~= "template.lua" and file ~= "flagTable.lua" then
            local chunk = love.filesystem.load("content/tiles/" .. file)
            if chunk then
                local tileDef = chunk()
                Factory.registerTile(tileDef)
            end
        end
    end
    
    -- Dynamically load all characters from content/characters
    local charDirs = love.filesystem.getDirectoryItems("content/characters")
    for _, dir in ipairs(charDirs) do
        local path = "content/characters/" .. dir
        local info = love.filesystem.getInfo(path)
        if info and info.type == "directory" then
            local charDef = nil
            local luaPath = path .. "/" .. dir .. ".lua"
            if love.filesystem.getInfo(luaPath) then
                local chunk = love.filesystem.load(luaPath)
                if chunk then charDef = chunk() end
            end
            
            if not charDef then
                -- Fallback defaults for character
                charDef = {
                    name = dir:gsub("^%l", string.upper), speed = 200,
                    colorKey = dir, draw_style = "fill",
                    animated = love.filesystem.getInfo(path .. "/animations.lua") ~= nil,
                    texture = safeLoad(path .. "/" .. dir .. ".png") or safeLoad(path .. "/spritesheet.png")
                }
            end
            
            Factory.characters[dir] = charDef
        end
    end
end

function Factory.getTile(id)
    return Factory.tiles[id] or Factory.tiles["void"]
end

function Factory.getCharacter(id)
    return Factory.characters[id]
end

function Factory.createCharacterEntity(px, py, typeId)
    local id = Registry.create()
    local tpl = Factory.getCharacter(typeId)
    
    Registry.add(id, "Transform", Components.Transform(px, py, 24, 24))
    Registry.add(id, "Velocity", Components.Velocity(0, 0, tpl.speed))
    
    local animData
    if tpl.animated then
        local AnimationManager = require('engine.core.animation')
        animData = AnimationManager.load(typeId)
        if animData and animData.anims then
            local clonedAnims = {}
            for k, v in pairs(animData.anims) do
                clonedAnims[k] = v:clone()
            end
            local startAnim = clonedAnims["idle"] and "idle" or next(clonedAnims)
            Registry.add(id, "Animator", Components.Animator(clonedAnims, startAnim))
        end
    end
    
    local tex = animData and animData.image or tpl.texture
    Registry.add(id, "Renderable", Components.Renderable("character", tpl.colorKey, tex, tpl.draw_style))
    
    Registry.add(id, "Health", Components.Health(100, 100))
    Registry.add(id, "CharacterStats", Components.CharacterStats({atk=10, def=10, endr=10, int=10}))
    Registry.add(id, "Persistent", Components.Persistent())
    Registry.add(id, "State", Components.State("idle"))
    Registry.add(id, "Collider", Components.Collider(16, 12, 4, 12))
    
    return id
end

function Factory.applyComposite(id, compositeName)
    local PresetLoader = require('engine.core.preset_loader')
    local comp = PresetLoader.getComposite(compositeName)
    if not comp then
        print("Error: Composite not found: " .. compositeName)
        return
    end
    
    local Components = require('engine.ecs.components')
    Registry.add(id, "ActiveComposite", Components.ActiveComposite(compositeName))
    
    if comp.Flags then
        local flags = {}
        for k, v in pairs(comp.Flags) do flags[k] = v end
        Registry.add(id, "Flags", Components.Flags(flags))
    else
        Registry.add(id, "Flags", Components.Flags({}))
    end
    
    if comp.Attributes then
        local attrs = {}
        for k, v in pairs(comp.Attributes) do attrs[k] = v end
        Registry.add(id, "Attributes", Components.Attributes(attrs))
    else
        Registry.add(id, "Attributes", Components.Attributes({}))
    end
    
    if comp.Reactions then
        local rx = {}
        for k, v in pairs(comp.Reactions) do rx[k] = v end
        Registry.add(id, "Reactions", Components.Reactions(rx))
    else
        Registry.add(id, "Reactions", Components.Reactions({}))
    end
    
    -- Clear TokenQueue on mutation
    Registry.add(id, "TokenQueue", Components.TokenQueue())
end

function Factory.spawnMapEntity(def, tileSize)
    if type(def) ~= "table" then return nil end
    tileSize = tileSize or 32
    local px = (def.x ~= nil) and def.x or ((def.gx or 0) * tileSize)
    local py = (def.y ~= nil) and def.y or ((def.gy or 0) * tileSize)

    local id
    if def.character == false then
        id = Registry.create()
        Registry.add(id, "Transform", Components.Transform(px, py, def.w or tileSize, def.h or tileSize))
    else
        id = Factory.createCharacterEntity(px, py, def.character or "player")
        -- Map-scoped entities should be cleared on Tilemap:clear()
        Registry.removeComponent(id, "Persistent")
    end

    if def.composite then
        Factory.applyComposite(id, def.composite)
    end

    if def.attributes then
        local attrs = Registry.get(id, "Attributes")
        if not attrs then
            attrs = Components.Attributes({})
            Registry.add(id, "Attributes", attrs)
        end
        for k, v in pairs(def.attributes) do attrs[k] = v end
    end

    if def.flags then
        local flags = Registry.get(id, "Flags")
        if not flags then
            flags = Components.Flags({})
            Registry.add(id, "Flags", flags)
        end
        for k, v in pairs(def.flags) do flags[k] = v end
    end

    return id
end

return Factory
