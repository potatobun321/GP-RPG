-- scenes/game.lua
local Context    = require('engine.core.context')
local Tilemap    = require('engine.world.tilemap')
local Camera     = require('engine.core.camera')
local Console    = require('engine.core.console')
local Registry   = require('engine.ecs.registry')
local Factory    = require('engine.core.factory')
local Systems    = require('engine.ecs.systems')
local Theme      = require('engine.core.theme')
local Components = require('engine.ecs.components')
local Editor     = require('tools.editor.editor')
local StoryManager = require('engine.narrative.story_manager')
local PluginLoader = require('engine.core.plugin_loader')

local Game = {}

function Game:load()
    Registry.clear()
    StoryManager.init()

    self.currentMapName = "map1"
    self.world = Tilemap.new(31, 31, 32)
    self.world:loadMap(self.currentMapName)
    if self.world.mapZoomLevel then
        Camera.profiles.gameplay.zoomLevel = self.world.mapZoomLevel
        Camera.profiles.gameplay.targetZoomLevel = self.world.mapZoomLevel
    end
    Camera.customBounds = self.world.customBounds

    -- Guard against duplicate event listener on re-load (#32)
    if not self._mapEventRegistered then
        self._mapEventRegistered = true
        Event.on("change_map", function(targetMap, targetX, targetY)
            self.world:saveMap(self.currentMapName)
            self.currentMapName = targetMap
            self.world:loadMap(self.currentMapName)
            
            if self.world.mapZoomLevel then
                Camera.profiles.gameplay.zoomLevel = self.world.mapZoomLevel
                Camera.profiles.gameplay.targetZoomLevel = self.world.mapZoomLevel
            end
            Camera.customBounds = self.world.customBounds

            if self.playerId then
                local trans = Registry.get(self.playerId, "Transform")
                if trans then
                    trans.x = (targetX or 0) * self.world.tileSize
                    trans.y = (targetY or 0) * self.world.tileSize
                end
            end
            Context.lastTeleportTile = {x = targetX or 0, y = targetY or 0}
            Context.transitioning    = false
        end)
    end

    self.playerId = Factory.createCharacterEntity(0, 0, "player")
    Registry.add(self.playerId, "PlayerInput", Components.PlayerInput())

    -- Add MVP NPC at -2, -1
    self.npcId = Factory.createCharacterEntity(-64, -32, "player")
    Factory.applyComposite(self.npcId, "InteractiveNPC")
    local npcTrans = Registry.get(self.npcId, "Transform")
    if npcTrans then
        npcTrans.x = -64
        npcTrans.y = -32
    end

    local pTrans = Registry.get(self.playerId, "Transform")
    if pTrans then
        Context.lastTeleportTile = {
            x = math.floor((pTrans.x + pTrans.w/2) / self.world.tileSize),
            y = math.floor((pTrans.y + pTrans.h/2) / self.world.tileSize)
        }
    end

    -- Setup console globals once here (#23)
    Console.setupGlobals(self)

    Console.log("Engine Loaded in Minimalist Object ECS Mode.")
    Console.log("Current Theme: " .. Theme.current)
end

function Game:update(dt)
    Console.update(dt)
    Editor.update(dt, self.world)
    if Console.isOpen then return end

    StoryManager.update(dt)
    if StoryManager.isActive() then
        Systems.AnimationSystem(dt)
        return
    end

    Systems.PlayerInputSystem(dt)
    Systems.MovementSystem(dt, self.world)
    Systems.TileEffectSystem(dt, self.world)
    Systems.AnimationControllerSystem()
    Systems.AnimationSystem(dt)
    Systems.HoverSystem(dt)
    Systems.TokenSystem(dt)
    PluginLoader.update(dt)

    local trans = Registry.get(self.playerId, "Transform")
    local tx = Camera.x
    local ty = Camera.y
    if trans then
        local shiftDown = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
        Camera.profiles.gameplay.tempZoomActive = (love.keyboard.isDown("z") and shiftDown)
        
        tx = trans.x + trans.w / 2
        ty = trans.y + trans.h / 2
    end
    Camera:update(dt, tx, ty, self.world)
end

function Game:textinput(t)
    if Console.isOpen then Console.textinput(t) end
end

function Game:wheelmoved(x, y)
    if Console.isOpen then Console.wheelmoved(x, y); return end
    if Editor.isActive then Editor.wheelmoved(x, y) end
end

function Game:keypressed(key)
    if key == "`" or key == "~" or key == "f1" then
        Console.toggle()
        return
    end

    if Console.isOpen then
        Console.keypressed(key, self)
        return
    end

    if StoryManager.isActive() then
        StoryManager.keypressed(key)
        return
    end

    if key == "f" and (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) then
        Camera.isFreeCam = not Camera.isFreeCam
        Console.log("Free Camera: " .. tostring(Camera.isFreeCam), {0.5, 1, 0.5})
    end

    PluginLoader.keypressed(key)

    if key == "e" then
        local trans = Registry.get(self.playerId, "Transform")
        if trans then
            local gx = math.floor((trans.x + trans.w/2) / self.world.tileSize)
            local gy = math.floor((trans.y + trans.h/2) / self.world.tileSize)
            
            local interactedWithEntity = false
            -- Gen 7 Interaction: Find entities in the same grid cell that are interactable
            for id, _ in pairs(Registry.entities) do
                if id ~= self.playerId then
                    local etrans = Registry.get(id, "Transform")
                    local eflags = Registry.get(id, "Flags")
                    if etrans and eflags and eflags.is_interactable then
                        local egx = math.floor((etrans.x + etrans.w/2) / self.world.tileSize)
                        local egy = math.floor((etrans.y + etrans.h/2) / self.world.tileSize)
                        
                        -- Check distance (simple adjacent/overlap check)
                        if math.abs(gx - egx) <= 1 and math.abs(gy - egy) <= 1 then
                            local q = Registry.get(id, "TokenQueue")
                            if q then
                                table.insert(q, "TriggerOnInteract")
                                Console.log("Emitted TriggerOnInteract to entity " .. id)
                                interactedWithEntity = true
                            end
                        end
                    end
                end
            end
            
            -- Legacy Tile Interaction (fallback)
            if not interactedWithEntity then
                local tdata = self.world:getTileData(gx, gy)
                if tdata and tdata.flags and tdata.flags.interactMessage then
                    StoryManager.startInteraction(tdata.flags.interactMessage)
                end
            end
        end
    end
end

function Game:draw()
    Camera:attach()
    self.world:draw()
    Systems.RenderSystem()
    Camera:detach()

    Systems.UISystem()
    PluginLoader.draw()
    StoryManager.draw()
    Editor.draw(self.world)
    Console.draw()
end

function Game:mousepressed(x, y, button, istouch, presses)
    if Console.isOpen then return end
    if StoryManager.isActive() then
        StoryManager.mousepressed(x, y, button)
        return
    end
    if Editor.mousepressed(x, y, button, istouch, presses, self.world) then
        return
    end
    
    if button == 1 then
        local wx, wy = Camera:screenToWorld(x, y)
        local entities = Registry.queryCached("Transform|Flags", {"Transform", "Flags"})
        for _, id in ipairs(entities) do
            local flags = Registry.get(id, "Flags")
            if flags.is_hoverable then
                local t = Registry.get(id, "Transform")
                if wx >= t.x and wx <= t.x + t.w and wy >= t.y and wy <= t.y + t.h then
                    local q = Registry.get(id, "TokenQueue")
                    if q then 
                        table.insert(q, "TriggerOnClick") 
                        Console.log("Emitted TriggerOnClick to entity " .. id)
                    end
                end
            end
        end
    end
end

function Game:mousereleased(x, y, button, istouch, presses)
    if Console.isOpen then return end
    if Editor.isActive then Editor.mousereleased(x, y, button, istouch, presses) end
end

function Game:mousemoved(x, y, dx, dy, istouch)
    if Console.isOpen then return end
    if Editor.isActive then Editor.mousemoved(x, y, dx, dy, istouch) end
end

return Game