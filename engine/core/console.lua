local utf8    = require("utf8")
local Theme   = require('engine.core.theme')
local Context = require('engine.core.context')

local Console = {
    isOpen = false,
    input = "",
    history = {},
    historyIndex = 0,
    logs = {},
    maxLogs = 100,
    scrollOffset = 0,
    animY = -1000,
    env = setmetatable({
        print = print, math = math, string = string, table = table,
        tostring = tostring, tonumber = tonumber, pairs = pairs,
        ipairs = ipairs, type = type
    }, {__index = _G})
}

function Console.log(text, color)
    local c = color or {1, 1, 1}
    table.insert(Console.logs, {text = tostring(text), color = c})
    if #Console.logs > Console.maxLogs then table.remove(Console.logs, 1) end
    print("[CONSOLE] " .. tostring(text))
end

function Console.clear()
    Console.logs = {}
    Console.scrollOffset = 0
end

function Console.setupGlobals(game)
    local Registry = require('engine.ecs.registry')
    Console.env.game = game
    Console.env.world = game.world
    
    if game.playerId then
        Console.env.player = Registry.get(game.playerId, "Transform")
        Console.env.vel = Registry.get(game.playerId, "Velocity")
        Console.env.char = Registry.get(game.playerId, "CharacterStats")
    end
    
    Console.env.save = function(name) game.world:saveMap(name or game.currentMapName); Console.log("Saved map", {0, 1, 0}) end
    
    Console.env.listmaps = function()
        local MapRegistry = require('engine.world.map_registry')
        local maps = MapRegistry.getPlayableMaps()
        Console.log("--- PLAYABLE MAPS ---", {0, 1, 1})
        for _, m in ipairs(maps) do
            Console.log(m, {0.8, 0.8, 0.8})
        end
    end

    Console.env.newmap = function(name)
        if not name then return Console.log("Need a map name!", {1,0,0}) end
        if love.filesystem.getInfo("maps/" .. name .. ".json") or love.filesystem.getInfo("content/maps/" .. name .. ".json") then
            return Console.log("Map already exists!", {1,0,0})
        end
        game.world:saveMap(game.currentMapName)
        game.currentMapName = name
        game.world:loadMap("template")
        game.world:saveMap(name)
        Console.log("Created new map: " .. name, {0, 1, 0})
    end

    Console.env.duplicatemap = function(src, dest)
        if not src or not dest then return Console.log("Need src and dest names!", {1,0,0}) end
        game.world:saveMap(game.currentMapName)
        game.world:loadMap(src)
        game.currentMapName = dest
        game.world:saveMap(dest)
        Console.log("Duplicated " .. src .. " to " .. dest, {0, 1, 0})
    end

    Console.env.deletemap = function(name)
        if not name then return Console.log("Need a map name!", {1,0,0}) end
        if name == "template" then return Console.log("Cannot delete template", {1,0,0}) end
        
        local deleted = false
        if love.filesystem.getInfo("maps/" .. name .. ".json") then
            love.filesystem.remove("maps/" .. name .. ".json")
            deleted = true
        end
        
        local devPath = love.filesystem.getSource() .. "/content/maps/" .. name .. ".json"
        local f = io.open(devPath, "r")
        if f then
            f:close()
            os.remove(devPath)
            deleted = true
        end
        
        if deleted then
            Console.log("Deleted map: " .. name, {0, 1, 0})
            if game.currentMapName == name then
                game.currentMapName = "map1"
                game.world:loadMap("map1")
            end
        else
            Console.log("Map not found to delete: " .. name, {1,0,0})
        end
    end

    -- Fix #24: renamed from Console.env.load to Console.env.loadmap to avoid shadowing Lua's built-in load()
    Console.env.loadmap = function(name)
        if not name then return Console.log("Need a map name!", {1,0,0}) end
        if not love.filesystem.getInfo("maps/" .. name .. ".json") and not love.filesystem.getInfo("content/maps/" .. name .. ".json") and not love.filesystem.getInfo("content/maps/" .. name .. ".lua") then
             return Console.log("Map not found: " .. name, {1,0,0})
        end
        game.world:saveMap(game.currentMapName)
        game.currentMapName = name
        game.world:loadMap(name)
        Console.log("Loaded map: "..name, {0, 1, 0})
    end
    Console.env.edit = function()
        if Context.editor then
            Context.editor.toggle()
            Console.log("Toggled Editor Mode", {0.5, 1, 0.5})
            if Console.isOpen then Console.toggle() end
        else
            Console.log("Editor module not found", {1, 0, 0})
        end
    end
    Console.env.speed = function(s) 
        if Console.env.vel then 
            Console.env.vel.baseSpeed = s 
            Console.log("Base speed set to: "..s, {0, 1, 0}) 
        end 
    end
    
    Console.env.theme = function(t)
        if Theme.set(t) then
            Console.log("Theme set to "..t, {0, 1, 0})
        else
            Console.log("Unknown theme. Try: neon, dracula, dark, light", {1, 0.2, 0.2})
        end
    end
    
    Console.env.resize = function(size)
        size = tonumber(size)
        if not size or size < 8 or size > 256 then
            return Console.log("Invalid size. Use 8 to 256.", {1,0,0})
        end
        local oldSize = game.world.tileSize
        if oldSize == size then return end
        local ratio = size / oldSize
        game.world.tileSize = size

        for _, comps in pairs(Registry.entities) do
            local t = comps.Transform
            if t then
                t.x = t.x * ratio
                t.y = t.y * ratio
                t.w = t.w * ratio
                t.h = t.h * ratio
            end
            local c = comps.Collider
            if c then
                c.w  = c.w * ratio
                c.h  = c.h * ratio
                c.ox = (c.ox or 0) * ratio
                c.oy = (c.oy or 0) * ratio
            end
            local r = comps.Renderable
            if r then
                r.scaleX = nil
                r.scaleY = nil
            end
        end

        local Camera = require('engine.core.camera')
        if Camera.customBounds then
            for i = 1, 4 do
                Camera.customBounds[i] = Camera.customBounds[i] * ratio
            end
            game.world.customBounds = Camera.customBounds
        end

        game.world._needsFullRebuild = true
        Context.mapDirty = true
        Console.log("Resized tiles to " .. size .. "px", {0, 1, 0})
    end
    Console.env.flag = {
        list = function()
            local FlagManager = require('engine.state.flag_manager')
            Console.log("--- FLAGS ---", {0, 1, 1})
            for k, v in pairs(FlagManager.list()) do
                Console.log(k .. " = " .. tostring(v), {0.8, 0.8, 0.8})
            end
        end,
        get = function(name)
            if not name or name == "" then return Console.log("Usage: flag.get name", {1,0,0}) end
            local FlagManager = require('engine.state.flag_manager')
            Console.log(name .. " = " .. tostring(FlagManager.get(name)), {0.8, 0.8, 0.8})
        end,
        set = function(name, valStr)
            if not name or name == "" or not valStr or valStr == "" then return Console.log("Usage: flag.set name value", {1,0,0}) end
            local val = valStr
            if valStr == "true" then val = true
            elseif valStr == "false" then val = false
            elseif tonumber(valStr) then val = tonumber(valStr) end
            local FlagManager = require('engine.state.flag_manager')
            FlagManager.set(name, val)
            Console.log("Set " .. name .. " = " .. tostring(val), {0, 1, 0})
        end,
        toggle = function(name)
            if not name or name == "" then return Console.log("Usage: flag.toggle name", {1,0,0}) end
            local FlagManager = require('engine.state.flag_manager')
            local newVal = FlagManager.toggle(name)
            Console.log("Toggled " .. name .. " = " .. tostring(newVal), {0, 1, 0})
        end
    }

    Console.env.token = {
        inspect = function(name)
            local PresetLoader = require('engine.core.preset_loader')
            local p = PresetLoader.activePreset
            if not p or not p.Tokens or not p.Tokens[name] then
                return Console.log("Token not found: " .. tostring(name), {1,0,0})
            end
            local t = p.Tokens[name]
            Console.log("--- TOKEN: " .. name .. " ---", {0, 1, 1})
            Console.log("Description: " .. (t.description or "None"), {0.8, 0.8, 0.8})
            Console.log("System: " .. (t.system or "Unknown"), {0.8, 0.8, 0.8})
            if t.consumes and #t.consumes > 0 then
                Console.log("Consumes:", {0.8, 0.8, 0.8})
                for _, attr in ipairs(t.consumes) do
                    Console.log("  - " .. attr, {0.8, 0.8, 0.8})
                end
            else
                Console.log("Consumes: Nothing", {0.8, 0.8, 0.8})
            end
        end
    }

    Console.env.composite = {
        inspect = function(name)
            local PresetLoader = require('engine.core.preset_loader')
            local c = PresetLoader.getComposite(name)
            if not c then
                return Console.log("Composite not found: " .. tostring(name), {1,0,0})
            end
            Console.log("--- COMPOSITE: " .. name .. " ---", {0, 1, 1})
            if c.Flags then
                Console.log("Flags:", {0.8, 0.8, 0.8})
                for k, v in pairs(c.Flags) do
                    Console.log("  " .. k .. " = " .. tostring(v), {0.8, 0.8, 0.8})
                end
            end
            if c.Attributes then
                Console.log("Attributes:", {0.8, 0.8, 0.8})
                for k, v in pairs(c.Attributes) do
                    Console.log("  " .. k .. " = " .. tostring(v), {0.8, 0.8, 0.8})
                end
            end
            if c.Reactions then
                Console.log("Reactions:", {0.8, 0.8, 0.8})
                for trig, rx in pairs(c.Reactions) do
                    Console.log("  " .. trig .. " -> " .. table.concat(rx, ", "), {0.8, 0.8, 0.8})
                end
            end
        end
    }

    Console.env.charc = function()
        if not game.playerId then return Console.log("No player", {1,0,0}) end
        local Registry = require('engine.ecs.registry')
        local health = Registry.get(game.playerId, "Health")
        local vel = Registry.get(game.playerId, "Velocity")
        local cstats = Registry.get(game.playerId, "CharacterStats")
        local stats = cstats and cstats.stats or {atk=0, def=0, endr=0, int=0}
        
        Console.log("+-------------------+", {0, 1, 1})
        Console.log("| STAT  | VALUE     |", {0, 1, 1})
        Console.log("+-------------------+", {0, 1, 1})
        Console.log(string.format("| %-5s | %-9s |", "HP", math.ceil(health.current) .. "/" .. health.max), {0.2, 1, 0.2})
        Console.log(string.format("| %-5s | %-9d |", "SPD", vel.baseSpeed), {1, 1, 0})
        Console.log(string.format("| %-5s | %-9d |", "ATK", stats.atk), {1, 0.2, 0.2})
        Console.log(string.format("| %-5s | %-9d |", "DEF", stats.def), {0.2, 0.5, 1})
        Console.log(string.format("| %-5s | %-9d |", "ENDR", stats.endr), {0.8, 0.5, 0.2})
        Console.log(string.format("| %-5s | %-9d |", "INT", stats.int), {0.8, 0.2, 1})
        Console.log("+-------------------+", {0, 1, 1})
    end
    
    local function numarg(val, name)
        local n = tonumber(val)
        if not n then
            Console.log("ERR: " .. (name or "arg") .. " must be a number (got: " .. tostring(val) .. ")", {1, 0.3, 0.3})
        end
        return n
    end

    local function setStat(statName, val)
        local n = numarg(val, statName)
        if not n or not game.playerId then return end
        local Registry = require('engine.ecs.registry')
        if statName == "hp" then
            local h = Registry.get(game.playerId, "Health")
            h.current = n; h.max = n
        elseif statName == "spd" then
            local v = Registry.get(game.playerId, "Velocity")
            v.baseSpeed = n
        else
            local c = Registry.get(game.playerId, "CharacterStats")
            if c and c.stats then c.stats[statName] = n end
        end
        Console.log(string.upper(statName) .. " set to " .. n, {0, 1, 0})
    end
    
    Console.env.atk = function(v) setStat("atk", v) end
    Console.env.def = function(v) setStat("def", v) end
    Console.env.endr = function(v) setStat("endr", v) end
    Console.env.int = function(v) setStat("int", v) end
    Console.env.hp = function(v) setStat("hp", v) end
    Console.env.spd = function(v) setStat("spd", v) end
    Console.env.z = function(v)
        local n = numarg(v, "z")
        if not n or not game.playerId then return end
        local t = Registry.get(game.playerId, "Transform")
        if t then t.z = n end
        Console.log("Player Z set to " .. n, {0, 1, 0})
    end
    
    local Camera = require('engine.core.camera')
    
    Console.env.zoom = {
        set = function(s)
            local n = tonumber(s)
            if not n or n < 0 or n > 6 or n ~= math.floor(n) then
                return Console.log("ERR: zoom.set requires integer 0-6", {1, 0.2, 0.2})
            end
            Camera.profiles.gameplay.zoomLevel = n
            Camera.profiles.gameplay.targetZoomLevel = n
            Console.log("Gameplay zoom set to Level " .. n, {0, 1, 0})
        end,
        temp = function(s)
            if s == "clear" then
                Camera.profiles.gameplay.activeZoomLevel = nil
                Console.log("Temp zoom cleared.", {0, 1, 0})
                return
            end
            local n = tonumber(s)
            if not n or n < 0 or n > 6 or n ~= math.floor(n) then
                return Console.log("ERR: zoom.temp requires integer 0-6 or 'clear'", {1, 0.2, 0.2})
            end
            Camera.profiles.gameplay.activeZoomLevel = n
            Console.log("Temp zoom active: Level " .. n, {0, 1, 0})
        end
    }
    
    Console.env.anim = function()
        Console.log("Switching to Animator Tool...", {1, 0.5, 0})
        Console.isOpen = false
        local AnimatorScene = require('tools.anim8tor.scene')
        Context.scene = AnimatorScene
        Context.scene:load()
    end

    Console.env.plugin = {
        list = function()
            local PluginLoader = require('engine.core.plugin_loader')
            Console.log("--- PLUGINS ---", {0, 1, 1})
            if #PluginLoader.order == 0 then
                Console.log("  (no plugins loaded)", {0.7, 0.7, 0.7})
                return
            end
            for _, id in ipairs(PluginLoader.order) do
                local p = PluginLoader.plugins[id]
                local status = PluginLoader.enabled[id] and "enabled" or "disabled"
                local kind = p.scene and "scene" or "rule"
                Console.log(string.format("  %-14s [%s | %s] %s", id, status, kind, p.description or ""), {0.9, 0.9, 0.9})
            end
        end,
        run = function(id)
            local PluginLoader = require('engine.core.plugin_loader')
            local p = PluginLoader.plugins[id]
            Console.isOpen = false
            if not p then
                Console.isOpen = true
                Console.log("ERR: Unknown plugin '" .. tostring(id) .. "'.", {1, 0.2, 0.2})
                return
            end
            if PluginLoader.activeMode == id then
                PluginLoader.exit(id)
            elseif p.onEnter or (p.world and p.world.hideDefaultEntities) then
                local ok, err = PluginLoader.enter(id)
                if not ok then
                    Console.isOpen = true
                    Console.log("ERR: " .. tostring(err), {1, 0.2, 0.2})
                end
            elseif p.commands and p.commands.play then
                p.commands.play()
            else
                Console.isOpen = true
                Console.log("ERR: Plugin '" .. tostring(id) .. "' has no runnable mode.", {1, 0.2, 0.2})
            end
        end,
        enable = function(id)
            local PluginLoader = require('engine.core.plugin_loader')
            local ok, err = PluginLoader.enable(id)
            if ok then Console.log("Plugin enabled: " .. id, {0, 1, 0})
            else Console.log("ERR: " .. tostring(err), {1, 0.2, 0.2}) end
        end,
        disable = function(id)
            local PluginLoader = require('engine.core.plugin_loader')
            local ok, err = PluginLoader.disable(id)
            if ok then Console.log("Plugin disabled: " .. id, {1, 0.8, 0.2})
            else Console.log("ERR: " .. tostring(err), {1, 0.2, 0.2}) end
        end,
        reload = function()
            local PluginLoader = require('engine.core.plugin_loader')
            PluginLoader.loadAll()
            Console.log("Reloaded " .. #PluginLoader.order .. " plugin(s).", {0, 1, 0})
        end
    }
    
    Console.env.history = function()
        Console.log("--- COMMAND HISTORY ---", {0, 1, 1})
        for i, h in ipairs(Console.history) do
            Console.log(i .. ": " .. h, {0.8, 0.8, 0.8})
        end
    end

    Console.env.commands = function()
        Console.env.help()
    end
    
    Console.env.savegame = function(slot)
        local SaveManager = require('engine.state.save_manager')
        local ok, res = SaveManager.save(slot or "slot1", game)
        if ok then Console.log("Saved game state -> " .. res, {0, 1, 0})
        else Console.log("ERR: " .. tostring(res), {1, 0.2, 0.2}) end
    end
    Console.env.loadgame = function(slot)
        local SaveManager = require('engine.state.save_manager')
        local ok, res = SaveManager.load(slot or "slot1", game)
        if ok then Console.log("Loaded game state <- " .. res, {0, 1, 0})
        else Console.log("ERR: " .. tostring(res), {1, 0.2, 0.2}) end
    end
    Console.env.listsaves = function()
        local SaveManager = require('engine.state.save_manager')
        local slots = SaveManager.list()
        Console.log("--- SAVED SLOTS ---", {0, 1, 1})
        if #slots == 0 then
            Console.log("  (no save slots)", {0.7, 0.7, 0.7})
            return
        end
        for _, s in ipairs(slots) do Console.log("  " .. s, {0.9, 0.9, 0.9}) end
    end

    Console.env.debug = function()
        local DebugOverlay = require('engine.core.debug_overlay')
        local on = DebugOverlay.toggle()
        Console.log("Debug Overlay: " .. (on and "ON" or "OFF"), on and {0.3, 1, 0.5} or {1, 0.7, 0.3})
    end

    Console.env.tp = function(gx, gy)
        gx, gy = tonumber(gx), tonumber(gy)
        if not gx or not gy or not game.playerId or not game.world then
            return Console.log("Usage: tp.gx.gy (e.g. tp.0.0)", {1, 0.2, 0.2})
        end
        local t = Registry.get(game.playerId, "Transform")
        if t then
            t.x = gx * game.world.tileSize
            t.y = gy * game.world.tileSize
            Context.lastTeleportTile = { x = gx, y = gy }
            Console.log(string.format("Teleported to (%d, %d)", gx, gy), {0, 1, 0})
        end
    end

    Console.env.entity = {
        list = function()
            Console.log("--- ENTITIES ---", {0, 1, 1})
            for id, comps in pairs(Registry.entities) do
                local compName = comps.ActiveComposite and comps.ActiveComposite.id or (comps.PlayerInput and "Player" or "Entity")
                local t = comps.Transform
                local pos = t and string.format("(%d,%d)", math.floor(t.x), math.floor(t.y)) or "(no transform)"
                Console.log(string.format("  #%d %-16s %s", id, compName, pos), {0.9, 0.9, 0.9})
            end
        end
    }

    Console.env.clear = Console.clear
    Console.env.help = function(topic)
        local C = {0, 1, 1}
        local W = {0.9, 0.9, 0.9}
        local M = {0.65, 0.75, 0.85}

        if topic == "maps" then
            Console.log("--- MAPS ---", C)
            Console.log("listmaps | newmap.X | loadmap.X | save / save.X", W)
            Console.log("duplicatemap.A.B | deletemap.X | resize.N", W)
            return
        elseif topic == "state" then
            Console.log("--- STATE & SAVES ---", C)
            Console.log("flag.list | flag.get X | flag.set X val | flag.toggle X", W)
            Console.log("savegame / savegame.slot | loadgame / loadgame.slot | listsaves", W)
            return
        elseif topic == "stats" then
            Console.log("--- PLAYER & DEBUG ---", C)
            Console.log("charc | hp.N | spd.N | atk.N | def.N | endr.N | int.N", W)
            Console.log("tp.gx.gy | entity.list | debug (F3)", W)
            return
        elseif topic == "tools" then
            Console.log("--- TOOLS & PLUGINS ---", C)
            Console.log("edit | anim | plugin.list | plugin.run X | plugin.reload", W)
            Console.log("zoom.set N | zoom.temp N | zoom.temp clear | theme.X", W)
            return
        end

        Console.log("--- CONSOLE COMMANDS (help.maps | help.state | help.stats | help.tools) ---", C)
        Console.log("Tools:   edit | anim | debug (F3) | theme.<name> | clear", W)
        Console.log("Plugins: plugin.list | plugin.run <id> | plugin.reload | <id>", W)
        Console.log("Maps:    listmaps | newmap.X | loadmap.X | save | save.X | resize.N", W)
        Console.log("State:   flag.list | flag.set X val | savegame [slot] | loadgame [slot]", W)
        Console.log("Player:  charc | hp.N | spd.N | tp.gx.gy | entity.list", W)
        Console.log("Camera:  zoom.set 0..6 | zoom.temp 0..6 | zoom.temp clear", W)
        Console.log("Inspect: token.inspect X | composite.inspect X | history", M)
    end
end

function Console.execute(line, game)
    if line == "" then return end
    if game then
        Console.env.world = game.world
        if game.playerId then
            local Registry = require('engine.ecs.registry')
            Console.env.player = Registry.get(game.playerId, "Transform")
            Console.env.vel    = Registry.get(game.playerId, "Velocity")
            Console.env.char   = Registry.get(game.playerId, "CharacterStats")
        end
    end
    Console.log("> " .. line, {0.6, 0.6, 0.6})
    table.insert(Console.history, line)
    Console.historyIndex = 0
    
    local rewritten = line
    if line == "edit" then rewritten = "edit()"
    elseif line == "save" then rewritten = "save()"
    elseif line == "clear" then rewritten = "clear()"
    elseif line == "help" then rewritten = "help()"
    elseif line == "debug" then rewritten = "debug()"
    elseif line == "charc" then rewritten = "charc()"
    elseif line == "anim" then rewritten = "anim()"
    elseif line == "listmaps" then rewritten = "listmaps()"
    elseif line == "savegame" then rewritten = "savegame()"
    elseif line == "loadgame" then rewritten = "loadgame()"
    elseif line == "listsaves" then rewritten = "listsaves()"
    elseif line == "entity.list" then rewritten = "entity.list()"
    elseif line == "flag.list" then rewritten = "flag.list()"
    elseif line == "plugin.list" then rewritten = "plugin.list()"
    elseif line == "plugin.reload" then rewritten = "plugin.reload()"
    elseif require('engine.core.plugin_loader').plugins[line] then
        rewritten = "plugin.run('" .. line .. "')"
    else
        local htopic = line:match("^help%.([a-z]+)$")
        if htopic then
            rewritten = "help('" .. htopic .. "')"
        end
        local zcmd, zarg = line:match("^zoom%.([a-z]+) ([^ ]+)$")
        if zcmd == "set" then
            rewritten = "zoom.set(" .. zarg .. ")"
        elseif zcmd == "temp" then
            rewritten = (zarg == "clear") and "zoom.temp('clear')" or ("zoom.temp(" .. zarg .. ")")
        end
        local tgx, tgy = line:match("^tp%.([%-]?%d+)%.([%-]?%d+)$")
        if tgx and tgy then
            rewritten = "tp(" .. tgx .. ", " .. tgy .. ")"
        end
        local pcmd, parg1 = line:match("^plugin%.([a-z]+) ([^ ]+)$")
        if pcmd == "run" or pcmd == "enable" or pcmd == "disable" then
            rewritten = "plugin." .. pcmd .. "('" .. parg1 .. "')"
        end
        local fcmd, farg1, farg2 = line:match("^flag%.([a-z]+) ([^ ]+) *(.*)$")
        if fcmd == "get" then rewritten = "flag.get('" .. farg1 .. "')"
        elseif fcmd == "toggle" then rewritten = "flag.toggle('" .. farg1 .. "')"
        elseif fcmd == "set" then rewritten = "flag.set('" .. farg1 .. "', '" .. farg2 .. "')"
        end
        
        local tcmd, targ1 = line:match("^token%.([a-z]+) ([^ ]+) *(.*)$")
        if tcmd == "inspect" then rewritten = "token.inspect('" .. targ1 .. "')" end
        
        local ccmd, carg1 = line:match("^composite%.([a-z]+) ([^ ]+) *(.*)$")
        if ccmd == "inspect" then rewritten = "composite.inspect('" .. carg1 .. "')" end
        
        if rewritten == line then
            local cmd, arg = line:match("^([%a_]+)%.([%w_]+)$")
        if cmd and arg then
            -- Fix #24: accept both 'load' and 'loadmap' from the user
            if cmd == "load" or cmd == "loadmap" or cmd == "theme" or cmd == "save" or cmd == "newmap" or cmd == "deletemap" or cmd == "savegame" or cmd == "loadgame" then
                rewritten = (cmd == "load" and "loadmap" or cmd) .. "('" .. arg .. "')"
            elseif tonumber(arg) then
                rewritten = cmd .. "(" .. arg .. ")"
            else
                local c, a1, a2 = line:match("^([%a_]+)%.([%w_]+)%.([%w_]+)$")
                if c == "duplicatemap" then
                    rewritten = "duplicatemap('" .. a1 .. "', '" .. a2 .. "')"
                end
            end
        end
        end
    end
    
    -- Fix #23: setupGlobals is called once in Game:load(). No need to call it here.
    
    local func, err = loadstring(rewritten)
    if not func then
        local funcExpr, _ = loadstring("return " .. line)
        if funcExpr then
            func = funcExpr
        else
            Console.log("Syntax Error: " .. tostring(err), {1, 0.2, 0.2})
            return
        end
    end
    
    setfenv(func, Console.env)
    
    local success, result = pcall(func)
    if success then
        if result ~= nil then
            Console.log("= " .. tostring(result), {0.5, 1, 0.5})
        end
    else
        Console.log("Runtime Error: " .. tostring(result), {1, 0.2, 0.2})
    end
end

function Console.toggle()
    Console.isOpen = not Console.isOpen
    if Console.isOpen then
        love.keyboard.setKeyRepeat(true)
        Console.input = ""
    else
        love.keyboard.setKeyRepeat(false)
    end
end

function Console.update(dt)
    local targetY = Console.isOpen and 0 or -love.graphics.getHeight()
    Console.animY = Console.animY + (targetY - Console.animY) * 15 * dt
end

function Console.textinput(t)
    if t ~= "`" and t ~= "~" then Console.input = Console.input .. t end
end

local function autocomplete()
    local envKeys = {
        "anim", "charc", "clear", "composite.inspect ", "debug", "deletemap.", "duplicatemap.",
        "edit", "entity.list", "flag.get ", "flag.list", "flag.set ", "flag.toggle ",
        "help", "history", "hp.", "spd.", "atk.", "def.", "endr.", "int.",
        "listmaps", "listsaves", "loadgame", "loadmap.", "newmap.",
        "plugin.disable ", "plugin.enable ", "plugin.list", "plugin.reload", "plugin.run ",
        "resize.", "save", "savegame", "theme.", "token.inspect ", "tp.",
        "zoom.set ", "zoom.temp "
    }
    local PluginLoader = require('engine.core.plugin_loader')
    for _, id in ipairs(PluginLoader.order or {}) do
        table.insert(envKeys, id)
    end
    for _, key in ipairs(envKeys) do
        if key:sub(1, #Console.input) == Console.input then
            Console.input = key
            return
        end
    end
end

function Console.keypressed(key, game)
    if key == "return" or key == "kpenter" then
        Console.execute(Console.input, game)
        Console.input = ""
    elseif key == "tab" then
        autocomplete()
    elseif key == "backspace" then
        local byteoffset = utf8.offset(Console.input, -1)
        if byteoffset then Console.input = string.sub(Console.input, 1, byteoffset - 1) end
    elseif key == "up" then
        if #Console.history > 0 and Console.historyIndex < #Console.history then
            Console.historyIndex = Console.historyIndex + 1
            Console.input = Console.history[#Console.history - Console.historyIndex + 1] or ""
        end
    elseif key == "down" then
        if Console.historyIndex > 1 then
            Console.historyIndex = Console.historyIndex - 1
            Console.input = Console.history[#Console.history - Console.historyIndex + 1] or ""
        else
            Console.historyIndex = 0
            Console.input = ""
        end
    end
end

function Console.wheelmoved(x, y)
    if not Console.isOpen then return end
    -- Fix #25: clamp scroll so it can never go negative or past the log end
    if y > 0 then
        Console.scrollOffset = math.min(#Console.logs - 1, Console.scrollOffset + 1)
    elseif y < 0 then
        Console.scrollOffset = math.max(0, Console.scrollOffset - 1)
    end
end

function Console.draw()
    if Console.animY <= -love.graphics.getHeight()/2 + 10 then return end
    
    local colors = Theme.get()
    local w, h = love.graphics.getDimensions()
    local ch = h / 2
    local yOff = Console.animY
    
    love.graphics.setColor(colors.console_bg)
    love.graphics.rectangle("fill", 0, yOff, w, ch)
    
    local pulse = math.sin(love.timer.getTime() * 4) * 0.3 + 0.7
    love.graphics.setColor(colors.player[1], colors.player[2], colors.player[3], pulse)
    love.graphics.setLineWidth(3)
    love.graphics.line(0, ch + yOff, w, ch + yOff)
    love.graphics.setLineWidth(1)
    
    love.graphics.setScissor(0, math.max(0, yOff), w, ch)
    
    love.graphics.setColor(colors.text)
    love.graphics.print("> " .. Console.input .. (math.floor(love.timer.getTime() * 2) % 2 == 0 and "_" or ""), 10, ch - 20 + yOff)
    
    local logY = ch - 40 + yOff
    local startIndex = #Console.logs - Console.scrollOffset
    for i = startIndex, 1, -1 do
        if logY < yOff + 10 then break end
        if Console.logs[i] then
            local c = Console.logs[i].color
            love.graphics.setColor(c[1], c[2], c[3], 1)
            love.graphics.print(Console.logs[i].text, 10, logY)
            logY = logY - 20
        end
    end
    
    love.graphics.setScissor()
end

return Console