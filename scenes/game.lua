-- scenes/game.lua
local Context      = require('engine.core.context')
local Tilemap      = require('engine.world.tilemap')
local Camera       = require('engine.core.camera')
local Console      = require('engine.core.console')
local Registry     = require('engine.ecs.registry')
local Factory      = require('engine.core.factory')
local Systems      = require('engine.ecs.systems')
local Theme        = require('engine.core.theme')
local Components   = require('engine.ecs.components')
local Editor       = require('tools.editor.editor')
local StoryManager = require('engine.narrative.story_manager')
local PluginLoader = require('engine.core.plugin_loader')
local LayerStack   = require('engine.core.layer_stack')
local DebugOverlay = require('engine.core.debug_overlay')

local Game = {}

function Game:spawnDefaultEntities()
    if self.playerId and Registry.entities[self.playerId] then return end

    self.playerId = Factory.createCharacterEntity(0, 0, "player")
    Registry.add(self.playerId, "PlayerInput", Components.PlayerInput())

    -- Fallback MVP NPC only if the loaded map has no declarative entities
    if not self.world.entities or #self.world.entities == 0 then
        self.npcId = Factory.createCharacterEntity(-64, -32, "player")
        Factory.applyComposite(self.npcId, "InteractiveNPC")
        local npcTrans = Registry.get(self.npcId, "Transform")
        if npcTrans then
            npcTrans.x = -64
            npcTrans.y = -32
        end
    end

    local pTrans = Registry.get(self.playerId, "Transform")
    if pTrans then
        Context.lastTeleportTile = {
            x = math.floor((pTrans.x + pTrans.w / 2) / self.world.tileSize),
            y = math.floor((pTrans.y + pTrans.h / 2) / self.world.tileSize)
        }
    end
end

function Game:clearDefaultEntities()
    if self.playerId then
        Registry.remove(self.playerId)
        self.playerId = nil
    end
    if self.npcId then
        Registry.remove(self.npcId)
        self.npcId = nil
    end
end

function Game:buildLayers()
    self.layers = LayerStack.new()

    -- 1. Developer Console (top modal)
    self.layers:push({
        blocksUpdate = function() return Console.isOpen end,
        blocksInput  = function() return Console.isOpen end,
        update       = function(dt) Console.update(dt) end,
        draw         = function() Console.draw() end,
        textinput    = function(t) if Console.isOpen then Console.textinput(t); return true end end,
        wheelmoved   = function(x, y) if Console.isOpen then Console.wheelmoved(x, y); return true end end,
        keypressed   = function(key)
            if key == "f3" then
                DebugOverlay.toggle()
                return true
            end
            if key == "`" or key == "~" or key == "f1" then
                Console.toggle()
                return true
            end
            if Console.isOpen then
                Console.keypressed(key, self)
                return true
            end
        end,
    })

    -- 2. In-Game Map Editor
    self.layers:push({
        update        = function(dt) Editor.update(dt, self.world) end,
        draw          = function() Editor.draw(self.world) end,
        wheelmoved    = function(x, y) if Editor.isActive then Editor.wheelmoved(x, y); return true end end,
        mousepressed  = function(x, y, btn, istouch, presses)
            return Editor.mousepressed(x, y, btn, istouch, presses, self.world)
        end,
        mousereleased = function(x, y, btn, istouch, presses)
            if Editor.isActive then Editor.mousereleased(x, y, btn, istouch, presses) end
        end,
        mousemoved    = function(x, y, dx, dy, istouch)
            if Editor.isActive then Editor.mousemoved(x, y, dx, dy, istouch) end
        end,
    })

    -- 3. LoveInk Story / Dialogue
    self.layers:push({
        blocksUpdate = function() return StoryManager.isActive() end,
        blocksInput  = function() return StoryManager.isActive() end,
        update       = function(dt)
            StoryManager.update(dt)
            if StoryManager.isActive() then Systems.AnimationSystem(dt) end
        end,
        draw         = function() StoryManager.draw() end,
        keypressed   = function(key)
            if StoryManager.isActive() then StoryManager.keypressed(key); return true end
        end,
        mousepressed = function(x, y, btn)
            if StoryManager.isActive() then StoryManager.mousepressed(x, y, btn); return true end
        end,
    })

    -- 4. Active Plugins
    self.layers:push({
        blocksInput   = function() return PluginLoader.hasExclusiveInput() end,
        update        = function(dt) PluginLoader.update(dt) end,
        draw          = function() PluginLoader.draw() end,
        keypressed    = function(key) PluginLoader.keypressed(key) end,
        mousepressed  = function(x, y, btn, istouch, presses) return PluginLoader.mousepressed(x, y, btn, istouch, presses) end,
        mousereleased = function(x, y, btn, istouch, presses) return PluginLoader.mousereleased(x, y, btn, istouch, presses) end,
        mousemoved    = function(x, y, dx, dy, istouch) PluginLoader.mousemoved(x, y, dx, dy, istouch) end,
        wheelmoved    = function(x, y) return PluginLoader.wheelmoved(x, y) end,
    })

    -- 5. Core Gameplay & ECS (bottom layer)
    self.layers:push({
        update = function(dt)
            if not PluginLoader.hasExclusiveInput() then
                Systems.PlayerInputSystem(dt)
            end
            Systems.MovementSystem(dt, self.world)
            Systems.TileEffectSystem(dt, self.world)
            Systems.AnimationControllerSystem()
            Systems.AnimationSystem(dt)
            Systems.HoverSystem(dt)
            Systems.TokenSystem(dt)
            if self.world and self.world.update then self.world:update(dt) end

            local trans = self.playerId and Registry.get(self.playerId, "Transform") or nil
            local tx = Camera.x
            local ty = Camera.y
            if trans then
                local shiftDown = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
                Camera.profiles.gameplay.tempZoomActive = (love.keyboard.isDown("z") and shiftDown)
                tx = trans.x + trans.w / 2
                ty = trans.y + trans.h / 2
            end
            Camera:update(dt, tx, ty, self.world)
        end,
        draw = function()
            Systems.UISystem()
        end,
        keypressed = function(key)
            if key == "f" and (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) then
                Camera.isFreeCam = not Camera.isFreeCam
                Console.log("Free Camera: " .. tostring(Camera.isFreeCam), {0.5, 1, 0.5})
                return true
            end
            if key == "e" then
                Systems.InteractionSystem(self.playerId, self.world)
                return true
            end
        end,
        mousepressed = function(x, y, button)
            if button == 1 then
                local wx, wy = Camera:screenToWorld(x, y)
                Systems.ClickInteractionSystem(wx, wy)
                return true
            end
        end,
    })
end

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

    self:spawnDefaultEntities()
    self:buildLayers()
    Console.setupGlobals(self)

    Console.log("Engine Loaded in Minimalist Object ECS Mode.")
    Console.log("Current Theme: " .. Theme.current)
end

function Game:update(dt)
    self.layers:update(dt)
end

function Game:draw()
    Camera:attach()
    self.world:draw()
    Systems.RenderSystem()
    DebugOverlay.drawWorld(self.world)
    Camera:detach()

    self.layers:draw()
    DebugOverlay.drawHUD(self)
end

function Game:textinput(t)
    self.layers:dispatch("textinput", t)
end

function Game:wheelmoved(x, y)
    self.layers:dispatch("wheelmoved", x, y)
end

function Game:keypressed(key)
    self.layers:dispatch("keypressed", key)
end

function Game:mousepressed(x, y, button, istouch, presses)
    self.layers:dispatch("mousepressed", x, y, button, istouch, presses)
end

function Game:mousereleased(x, y, button, istouch, presses)
    self.layers:dispatch("mousereleased", x, y, button, istouch, presses)
end

function Game:mousemoved(x, y, dx, dy, istouch)
    self.layers:dispatch("mousemoved", x, y, dx, dy, istouch)
end

function Game:resize(w, h)
    StoryManager.resize(w, h)
end

return Game
