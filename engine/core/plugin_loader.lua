-- engine/core/plugin_loader.lua
-- Drop-in table-driven plugin and rule loader (mirrors content/tiles/ discovery).

local Context = require('engine.core.context')

local PluginLoader = {
    plugins = {},       -- id -> plugin table
    order = {},         -- deterministic load order of ids
    enabled = {},       -- id -> boolean
    activeMode = nil,   -- currently entered plugin id (if any)
    savedState = {},    -- saved camera/entity state before entering a plugin
    tokens = {},        -- tokenName -> tokenDef (with optional execute fn)
    commands = {},      -- pluginId -> { cmdName -> fn }
}

local PLUGIN_DEFAULTS = {
    world = {
        hideDefaultEntities = false,
        cameraZoomLevel = nil,
    }
}

function PluginLoader.buildContext()
    local game = require('scenes.game')
    return {
        world    = game and game.world or nil,
        registry = require('engine.ecs.registry'),
        camera   = require('engine.core.camera'),
        flags    = require('engine.state.flag_manager'),
        events   = _G.Event,
        console  = require('engine.core.console'),
        game     = game,
        Context  = Context,
    }
end

local function applyDefaults(plugin)
    plugin.world = plugin.world or {}
    for k, v in pairs(PLUGIN_DEFAULTS.world) do
        if plugin.world[k] == nil then
            plugin.world[k] = v
        end
    end
end

local function registerPlugin(plugin)
    if type(plugin) ~= "table" or not plugin.id then
        return false, "Plugin must return a table with an 'id' field."
    end

    applyDefaults(plugin)

    local id = plugin.id
    PluginLoader.plugins[id] = plugin
    PluginLoader.enabled[id] = (plugin.enabledByDefault ~= false)

    local alreadyInOrder = false
    for _, existingId in ipairs(PluginLoader.order) do
        if existingId == id then
            alreadyInOrder = true
            break
        end
    end
    if not alreadyInOrder then
        table.insert(PluginLoader.order, id)
    end

    -- Register tokens into PluginLoader + active PresetLoader
    local PresetLoader = require('engine.core.preset_loader')
    if plugin.tokens then
        for tName, tDef in pairs(plugin.tokens) do
            PluginLoader.tokens[tName] = tDef
            if PresetLoader.activePreset and PresetLoader.activePreset.Tokens then
                PresetLoader.activePreset.Tokens[tName] = tDef
            end
        end
    end

    -- Register composites into active PresetLoader
    if plugin.composites then
        for cName, cDef in pairs(plugin.composites) do
            PresetLoader.activeComposites[cName] = cDef
        end
    end

    -- Register console commands
    if plugin.commands then
        PluginLoader.commands[id] = plugin.commands
    end

    return true
end

function PluginLoader.loadAll()
    PluginLoader.plugins = {}
    PluginLoader.order = {}
    PluginLoader.enabled = {}
    PluginLoader.tokens = {}
    PluginLoader.commands = {}

    local dir = "content/plugins"
    local info = love.filesystem.getInfo(dir)
    if not info or info.type ~= "directory" then
        return
    end

    local items = love.filesystem.getDirectoryItems(dir)
    table.sort(items)

    local discovered = {}
    for _, item in ipairs(items) do
        local fullPath = dir .. "/" .. item
        local itemInfo = love.filesystem.getInfo(fullPath)
        local chunk, err

        if itemInfo and itemInfo.type == "file" and item:sub(-4) == ".lua" then
            chunk, err = love.filesystem.load(fullPath)
        elseif itemInfo and itemInfo.type == "directory" then
            local initPath = fullPath .. "/init.lua"
            if love.filesystem.getInfo(initPath) then
                chunk, err = love.filesystem.load(initPath)
            end
        end

        if chunk then
            local ok, plugin = pcall(chunk)
            if ok and type(plugin) == "table" and plugin.id then
                discovered[plugin.id] = plugin
            else
                print("PluginLoader error in " .. fullPath .. ": " .. tostring(plugin))
            end
        elseif err then
            print("PluginLoader load error in " .. fullPath .. ": " .. tostring(err))
        end
    end

    local ids = {}
    for id in pairs(discovered) do table.insert(ids, id) end
    table.sort(ids)

    local ctx = PluginLoader.buildContext()
    for _, id in ipairs(ids) do
        local plugin = discovered[id]
        local depsOk = true
        if plugin.requires then
            for _, reqId in ipairs(plugin.requires) do
                if not discovered[reqId] then
                    local PresetLoader = require('engine.core.preset_loader')
                    if PresetLoader.activePresetName ~= reqId then
                        print("PluginLoader: skipping '" .. id .. "', missing dependency '" .. reqId .. "'")
                        depsOk = false
                        break
                    end
                end
            end
        end

        if depsOk then
            local ok, msg = registerPlugin(plugin)
            if ok and plugin.onLoad then
                plugin.onLoad(ctx)
            elseif not ok then
                print("PluginLoader: " .. tostring(msg))
            end
        end
    end
end

function PluginLoader.enter(id)
    local plugin = PluginLoader.plugins[id]
    if not plugin then return false, "Unknown plugin: " .. tostring(id) end

    if PluginLoader.activeMode and PluginLoader.activeMode ~= id then
        PluginLoader.exit(PluginLoader.activeMode)
    end

    local ctx = PluginLoader.buildContext()
    PluginLoader.activeMode = id
    PluginLoader.savedState = {
        zoomLevel = ctx.camera.getZoom(),
        hidDefaults = false,
    }

    if plugin.world.hideDefaultEntities and ctx.game and ctx.game.clearDefaultEntities then
        ctx.game:clearDefaultEntities()
        PluginLoader.savedState.hidDefaults = true
    end

    if plugin.world.cameraZoomLevel ~= nil then
        ctx.camera.setZoom(plugin.world.cameraZoomLevel)
    end

    if plugin.onEnter then
        plugin.onEnter(ctx)
    end
    return true
end

function PluginLoader.exit(id)
    local targetId = id or PluginLoader.activeMode
    if not targetId then return end
    local plugin = PluginLoader.plugins[targetId]
    local ctx = PluginLoader.buildContext()

    if plugin and plugin.onExit then
        plugin.onExit(ctx)
    end

    ctx.camera.clearTarget()
    if PluginLoader.savedState.zoomLevel ~= nil then
        ctx.camera.setZoom(PluginLoader.savedState.zoomLevel)
    end
    if PluginLoader.savedState.hidDefaults and ctx.game and ctx.game.spawnDefaultEntities then
        ctx.game:spawnDefaultEntities()
    end

    PluginLoader.activeMode = nil
    PluginLoader.savedState = {}
end

function PluginLoader.enable(id)
    if not PluginLoader.plugins[id] then return false, "Unknown plugin: " .. tostring(id) end
    PluginLoader.enabled[id] = true
    return true
end

function PluginLoader.disable(id)
    if not PluginLoader.plugins[id] then return false, "Unknown plugin: " .. tostring(id) end
    PluginLoader.enabled[id] = false
    return true
end

function PluginLoader.update(dt)
    local ctx = PluginLoader.buildContext()
    for _, id in ipairs(PluginLoader.order) do
        local plugin = PluginLoader.plugins[id]
        if PluginLoader.enabled[id] and plugin and plugin.onUpdate then
            plugin.onUpdate(dt, ctx)
        end
    end
end

function PluginLoader.draw()
    local ctx = PluginLoader.buildContext()
    for _, id in ipairs(PluginLoader.order) do
        local plugin = PluginLoader.plugins[id]
        if PluginLoader.enabled[id] and plugin and plugin.onDraw then
            plugin.onDraw(ctx)
        end
    end
end

function PluginLoader.keypressed(key)
    local ctx = PluginLoader.buildContext()
    for _, id in ipairs(PluginLoader.order) do
        local plugin = PluginLoader.plugins[id]
        if PluginLoader.enabled[id] and plugin and plugin.onKeypressed then
            plugin.onKeypressed(key, ctx)
        end
    end
end

return PluginLoader
