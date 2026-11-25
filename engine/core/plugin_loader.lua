-- engine/core/plugin_loader.lua
-- Drop-in plugin and rule loader (mirrors content/tiles/ discovery).

local Context = require('engine.core.context')

local PluginLoader = {
    plugins = {},       -- id -> plugin table
    order = {},         -- deterministic load order of ids
    enabled = {},       -- id -> boolean
    tokens = {},        -- tokenName -> tokenDef (with optional execute fn)
    commands = {},      -- pluginId -> { cmdName -> fn }
}

local function buildAPI()
    return {
        Context = Context,
        Registry = require('engine.ecs.registry'),
        Event = _G.Event,
        Flags = require('engine.state.flag_manager'),
        exitToGame = function()
            local SceneGame = require('scenes.game')
            Context.scene = SceneGame
            _G.game = SceneGame
            love.graphics.setBackgroundColor(0, 0, 0)
            local ok, f = pcall(love.graphics.newFont, "fonts/PressStart2P.ttf", 12)
            if ok then love.graphics.setFont(f) end
        end
    }
end

local function registerPlugin(plugin)
    if type(plugin) ~= "table" or not plugin.id then
        return false, "Plugin must return a table with an 'id' field."
    end

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

    -- Validate dependencies and register in sorted order
    local ids = {}
    for id in pairs(discovered) do table.insert(ids, id) end
    table.sort(ids)

    local api = buildAPI()
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
                plugin.onLoad(api)
            elseif not ok then
                print("PluginLoader: " .. tostring(msg))
            end
        end
    end
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

function PluginLoader.launchScene(id)
    local plugin = PluginLoader.plugins[id]
    if not plugin then return false, "Unknown plugin: " .. tostring(id) end
    if not plugin.scene then return false, "Plugin '" .. id .. "' does not define a scene." end

    local api = buildAPI()
    local sceneWrapper = {}
    for k, v in pairs(plugin.scene) do
        sceneWrapper[k] = v
    end
    sceneWrapper._api = api

    -- Wrap lifecycle methods so plugin scenes receive `api` cleanly if they accept it
    if plugin.scene.load then
        function sceneWrapper:load() return plugin.scene.load(self, api) end
    end
    if plugin.scene.update then
        function sceneWrapper:update(dt) return plugin.scene.update(self, dt, api) end
    end
    if plugin.scene.draw then
        function sceneWrapper:draw() return plugin.scene.draw(self, api) end
    end
    if plugin.scene.keypressed then
        function sceneWrapper:keypressed(key) return plugin.scene.keypressed(self, key, api) end
    end

    Context.scene = sceneWrapper
    if sceneWrapper.load then sceneWrapper:load() end
    return true
end

function PluginLoader.update(dt)
    local api = buildAPI()
    for _, id in ipairs(PluginLoader.order) do
        local plugin = PluginLoader.plugins[id]
        if PluginLoader.enabled[id] and plugin and plugin.onUpdate then
            plugin.onUpdate(dt, api)
        end
    end
end

function PluginLoader.draw()
    local api = buildAPI()
    for _, id in ipairs(PluginLoader.order) do
        local plugin = PluginLoader.plugins[id]
        if PluginLoader.enabled[id] and plugin and plugin.onDraw then
            plugin.onDraw(api)
        end
    end
end

function PluginLoader.keypressed(key)
    local api = buildAPI()
    for _, id in ipairs(PluginLoader.order) do
        local plugin = PluginLoader.plugins[id]
        if PluginLoader.enabled[id] and plugin and plugin.onKeypressed then
            plugin.onKeypressed(key, api)
        end
    end
end

return PluginLoader
