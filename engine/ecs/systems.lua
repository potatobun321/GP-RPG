-- ecs/systems.lua
local Registry = require('engine.ecs.registry')
local Context  = require('engine.core.context')
local Input    = require('engine.core.input')
local Theme    = require('engine.core.theme')

local _Camera, _PluginLoader, _StoryManager, _Factory, _Console
local function getCamera()       if not _Camera       then _Camera       = require('engine.core.camera') end; return _Camera end
local function getPluginLoader() if not _PluginLoader then _PluginLoader = require('engine.core.plugin_loader') end; return _PluginLoader end
local function getStoryManager() if not _StoryManager then _StoryManager = require('engine.narrative.story_manager') end; return _StoryManager end
local function getFactory()      if not _Factory      then _Factory      = require('engine.core.factory') end; return _Factory end
local function getConsole()      if not _Console      then _Console      = require('engine.core.console') end; return _Console end

local SYS_QUERIES = {
    PlayerInput = { sig = "Velocity|PlayerInput", req = {"Velocity", "PlayerInput"} },
    Movement    = { sig = "Transform|Velocity", req = {"Transform", "Velocity"} },
    TileEffect  = { sig = "PlayerInput|Transform|Health", req = {"PlayerInput", "Transform", "Health"} },
    Animation   = { sig = "Animator", req = {"Animator"} },
    AnimControl = { sig = "Animator|Velocity", req = {"Animator", "Velocity"} },
    Render      = { sig = "Transform|Renderable", req = {"Transform", "Renderable"} },
    UI          = { sig = "Health|PlayerInput", req = {"Health", "PlayerInput"} }
}

local Systems = {}

function Systems.PlayerInputSystem(dt)
    local players = Registry.queryCached(SYS_QUERIES.PlayerInput.sig, SYS_QUERIES.PlayerInput.req)
    for _, id in ipairs(players) do
        local vel = Registry.get(id, "Velocity")
        vel.dx = Input.getAxis("a", "d")
        vel.dy = Input.getAxis("w", "s")
        if vel.dx ~= 0 and vel.dy ~= 0 then
            local l = math.sqrt(vel.dx^2 + vel.dy^2)
            vel.dx, vel.dy = vel.dx/l, vel.dy/l
        end
        -- Fix #8: use Input.isDown instead of direct love.keyboard.isDown
        if Input.isDown("s") then     vel.facing = "down"
        elseif Input.isDown("w") then vel.facing = "up"
        elseif Input.isDown("a") then vel.facing = "left"
        elseif Input.isDown("d") then vel.facing = "right"
        end
    end
end

local SpatialHash = {}
local SpatialCache = {}
local CELL_SIZE = 64

local function addToHash(id, minC, maxC, minR, maxR)
    for r = minR, maxR do
        local row = SpatialHash[r]
        if not row then row = {}; SpatialHash[r] = row end
        for c = minC, maxC do
            local cell = row[c]
            if not cell then cell = {}; row[c] = cell end
            cell[id] = true
        end
    end
end

local function removeFromHash(id, minC, maxC, minR, maxR)
    for r = minR, maxR do
        local row = SpatialHash[r]
        if row then
            for c = minC, maxC do
                local cell = row[c]
                if cell then cell[id] = nil end
            end
        end
    end
end

local function updateSpatialHash()
    local colliders = Registry.queryCached("Transform|Collider", {"Transform", "Collider"})
    local currentIds = {}
    
    for _, cid in ipairs(colliders) do
        currentIds[cid] = true
        local ct = Registry.get(cid, "Transform")
        local cc = Registry.get(cid, "Collider")
        local cx = ct.x + (cc.ox or 0)
        local cy = ct.y + (cc.oy or 0)
        
        local minCol = math.floor(cx / CELL_SIZE)
        local maxCol = math.floor((cx + cc.w) / CELL_SIZE)
        local minRow = math.floor(cy / CELL_SIZE)
        local maxRow = math.floor((cy + cc.h) / CELL_SIZE)
        
        local cache = SpatialCache[cid]
        if not cache then
            SpatialCache[cid] = {minCol, maxCol, minRow, maxRow}
            addToHash(cid, minCol, maxCol, minRow, maxRow)
        elseif cache[1] ~= minCol or cache[2] ~= maxCol or cache[3] ~= minRow or cache[4] ~= maxRow then
            removeFromHash(cid, cache[1], cache[2], cache[3], cache[4])
            cache[1], cache[2], cache[3], cache[4] = minCol, maxCol, minRow, maxRow
            addToHash(cid, minCol, maxCol, minRow, maxRow)
        end
    end
    
    for cid, cache in pairs(SpatialCache) do
        if not currentIds[cid] then
            removeFromHash(cid, cache[1], cache[2], cache[3], cache[4])
            SpatialCache[cid] = nil
        end
    end
end

local function checkEntityCollision(id, nx, ny, w, h, entityZ)
    local ez = entityZ or 0
    local minCol = math.floor(nx / CELL_SIZE)
    local maxCol = math.floor((nx + w) / CELL_SIZE)
    local minRow = math.floor(ny / CELL_SIZE)
    local maxRow = math.floor((ny + h) / CELL_SIZE)
    
    local checked = {}
    
    for r = minRow, maxRow do
        if SpatialHash[r] then
            for c = minCol, maxCol do
                local cell = SpatialHash[r][c]
                if cell then
                    for cid in pairs(cell) do
                        if cid ~= id and not checked[cid] then
                            checked[cid] = true
                            local ct = Registry.get(cid, "Transform")
                            local cc = Registry.get(cid, "Collider")
                            if (ct.z or 0) == ez then
                                local cx = ct.x + (cc.ox or 0)
                                local cy = ct.y + (cc.oy or 0)
                                if nx < cx + cc.w and nx + w > cx and
                                   ny < cy + cc.h and ny + h > cy then
                                    return true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

function Systems.MovementSystem(dt, world)
    updateSpatialHash()
    local entities = Registry.queryCached(SYS_QUERIES.Movement.sig, SYS_QUERIES.Movement.req)
    for _, id in ipairs(entities) do
        local trans = Registry.get(id, "Transform")
        local vel   = Registry.get(id, "Velocity")

        local cx = trans.x + trans.w/2
        local cy = trans.y + trans.h/2
        local gx = math.floor(cx / world.tileSize)
        local gy = math.floor(cy / world.tileSize)

        local tileData   = world:getTileData(gx, gy)
        local speedMod = 1.0
        if tileData and tileData.flags and tileData.flags.speedMod then
            speedMod = tileData.flags.speedMod
        end

        vel.currentSpeed = vel.baseSpeed * speedMod

        local targetX = trans.x + vel.dx * vel.currentSpeed * dt
        local targetY = trans.y + vel.dy * vel.currentSpeed * dt

        local collW, collH, collOx, collOy = trans.w, trans.h, 0, 0
        local coll = Registry.get(id, "Collider")
        if coll then
            collW, collH = coll.w, coll.h
            collOx, collOy = coll.ox or 0, coll.oy or 0
        end

        -- Sub-stepping to prevent tunneling
        local dist = math.sqrt((targetX - trans.x)^2 + (targetY - trans.y)^2)
        local maxStep = math.min(collW, collH) / 2
        local steps = math.ceil(dist / maxStep)
        if steps == 0 then steps = 1 end
        
        local stepX = (targetX - trans.x) / steps
        local stepY = (targetY - trans.y) / steps
        
        local ez = trans.z or 0
        for i = 1, steps do
            local nextX = trans.x + stepX
            local nextY = trans.y + stepY
            
            if not world:isSolidPixel(nextX + collOx, trans.y + collOy, collW, collH, ez)
               and not checkEntityCollision(id, nextX + collOx, trans.y + collOy, collW, collH, ez) then
                trans.x = nextX
            else
                stepX = 0
            end
            
            if not world:isSolidPixel(trans.x + collOx, nextY + collOy, collW, collH, ez)
               and not checkEntityCollision(id, trans.x + collOx, nextY + collOy, collW, collH, ez) then
                trans.y = nextY
            else
                stepY = 0
            end
            
            if stepX == 0 and stepY == 0 then break end
        end
    end
end

function Systems.TileEffectSystem(dt, world)
    local players = Registry.queryCached(SYS_QUERIES.TileEffect.sig, SYS_QUERIES.TileEffect.req)
    for _, id in ipairs(players) do
        local trans  = Registry.get(id, "Transform")
        local health = Registry.get(id, "Health")

        if health.immunityTimer > 0 then
            health.immunityTimer = health.immunityTimer - dt
        end

        local gx = math.floor((trans.x + trans.w/2) / world.tileSize)
        local gy = math.floor((trans.y + trans.h/2) / world.tileSize)

        if Context.lastTeleportTile and (Context.lastTeleportTile.x ~= gx or Context.lastTeleportTile.y ~= gy) then
            Context.lastTeleportTile = nil
        end

        local tileData = world:getTileData(gx, gy)
        if tileData and tileData.flags then
            if tileData.flags.healthAffect then
                health.current = health.current + (tileData.flags.healthAffect * dt)
                if health.current < 0   then health.current = 0          end
                if health.current > health.max then health.current = health.max end
            end
            if tileData.flags.healthAffectInstant and health.immunityTimer <= 0 then
                health.current = health.current + tileData.flags.healthAffectInstant
                health.immunityTimer = 1.0
                if health.current < 0   then health.current = 0          end
                if health.current > health.max then health.current = health.max end
            end
            if tileData.flags.isSceneTransition then
                if not Context.lastTeleportTile then
                    local Transition = require('engine.core.transition')
                    Context.lastTeleportTile = {x = gx, y = gy}
                    Transition.execute(tileData, gx, gy)  -- gx/gy needed for same-map link detection
                end
            end
        end
    end
end

function Systems.AnimationSystem(dt)
    local entities = Registry.queryCached(SYS_QUERIES.Animation.sig, SYS_QUERIES.Animation.req)
    for _, id in ipairs(entities) do
        local anim = Registry.get(id, "Animator")
        if anim.current and anim.animations[anim.current] then
            anim.animations[anim.current]:update(dt)
        end
    end
end

-- Resolve an animation key using the fallback chain.
local function resolveAnim(animations, a, b, c, d)
    if a and animations[a] then return a end
    if b and animations[b] then return b end
    if c and animations[c] then return c end
    if d and animations[d] then return d end
    return nil
end

local AnimKeyCache = {}
local function getAnimKey(action, facing)
    if not AnimKeyCache[action] then AnimKeyCache[action] = {} end
    if not AnimKeyCache[action][facing] then
        AnimKeyCache[action][facing] = action .. "_" .. facing
    end
    return AnimKeyCache[action][facing]
end

function Systems.AnimationControllerSystem()
    local entities = Registry.queryCached(SYS_QUERIES.AnimControl.sig, SYS_QUERIES.AnimControl.req)
    for _, id in ipairs(entities) do
        local anim   = Registry.get(id, "Animator")
        local vel    = Registry.get(id, "Velocity")
        local state  = Registry.get(id, "State")
        local action = state and state.current or "idle"
        local f      = vel.facing or "down"
        local moving = (vel.dx ~= 0 or vel.dy ~= 0)

        local target
        if action ~= "idle" then
            target = resolveAnim(anim.animations, getAnimKey(action, f), action, "default")
        elseif moving then
            target = resolveAnim(anim.animations, getAnimKey("walk", f), "walk", "default")
        else
            target = resolveAnim(anim.animations, getAnimKey("idle", f), "idle", getAnimKey("walk", f), "walk", "default")
        end

        if target and target ~= anim.current then
            anim.current = target
            anim.animations[target]:gotoFrame(1)
        end
    end
end

local tileBatches = {}
local DEFAULT_COLOR = {1, 1, 1}

local _renderOrder = {}
local function sortByDepth(a, b)
    local ta = Registry.get(a, "Transform")
    local tb = Registry.get(b, "Transform")
    local za = ta.z or 0
    local zb = tb.z or 0
    if za ~= zb then return za < zb end
    return (ta.y + ta.h) < (tb.y + tb.h)
end

function Systems.RenderSystem()
    local entities = Registry.queryCached(SYS_QUERIES.Render.sig, SYS_QUERIES.Render.req)
    local colors   = Theme.get()

    for i = 1, #entities do _renderOrder[i] = entities[i] end
    for i = #entities + 1, #_renderOrder do _renderOrder[i] = nil end
    table.sort(_renderOrder, sortByDepth)

    -- Draw characters sorted by (z, y + h)
    for _, id in ipairs(_renderOrder) do
        local r = Registry.get(id, "Renderable")
        if r.type == "character" then
            local t    = Registry.get(id, "Transform")
            local anim = Registry.get(id, "Animator")
            local c    = colors[r.colorKey] or DEFAULT_COLOR

            if anim and anim.current and anim.animations[anim.current] and r.texture then
                if not r.scaleX or not r.scaleY then
                    local w, h = anim.animations[anim.current]:getDimensions()
                    r.scaleX = t.w / w
                    r.scaleY = t.h / h
                end
                love.graphics.setColor(1, 1, 1, 1)
                anim.animations[anim.current]:draw(r.texture, t.x, t.y, 0, r.scaleX, r.scaleY)
            elseif r.texture then
                if not r.scaleX or not r.scaleY then
                    r.scaleX = t.w / r.texture:getWidth()
                    r.scaleY = t.h / r.texture:getHeight()
                end
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(r.texture, t.x, t.y, 0, r.scaleX, r.scaleY)
            else
                love.graphics.setColor(c)
                love.graphics.rectangle("fill", t.x, t.y, t.w, t.h)
            end
        end
    end
end

function Systems.UISystem()
    local players = Registry.queryCached(SYS_QUERIES.UI.sig, SYS_QUERIES.UI.req)
    for _, id in ipairs(players) do
        local health = Registry.get(id, "Health")

        -- Background
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 18, 18, 204, 24)

        -- Fill (colour-coded by HP%)
        local hpPercent = health.current / health.max
        if     hpPercent > 0.5  then love.graphics.setColor(0.2, 0.8, 0.2, 1)
        elseif hpPercent > 0.25 then love.graphics.setColor(0.8, 0.8, 0.2, 1)
        else                         love.graphics.setColor(0.8, 0.2, 0.2, 1)
        end
        love.graphics.rectangle("fill", 20, 20, 200 * hpPercent, 20)

        -- Border
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", 20, 20, 200, 20)

        love.graphics.print("HP: " .. math.ceil(health.current) .. "/" .. health.max, 25, 46)
    end
end

function Systems.HoverSystem(dt)
    local mx, my = love.mouse.getPosition()
    local wx, wy = getCamera():screenToWorld(mx, my)

    local entities = Registry.queryCached("Transform|Flags", {"Transform", "Flags"})
    for _, id in ipairs(entities) do
        local flags = Registry.get(id, "Flags")
        if flags.is_hoverable then
            local t = Registry.get(id, "Transform")
            local isHovered = wx >= t.x and wx <= t.x + t.w and wy >= t.y and wy <= t.y + t.h
            
            if isHovered then
                if not flags.is_hovered then
                    flags.is_hovered = true
                    local q = Registry.get(id, "TokenQueue")
                    if q then table.insert(q, "TriggerOnHoverEnter") end
                end
            else
                if flags.is_hovered then
                    flags.is_hovered = false
                    local q = Registry.get(id, "TokenQueue")
                    if q then table.insert(q, "TriggerOnHoverExit") end
                end
            end
        end
    end
end

function Systems.TokenSystem(dt)
    local qEntities = Registry.queryCached("TokenQueue", {"TokenQueue"})
    for _, id in ipairs(qEntities) do
        local q = Registry.get(id, "TokenQueue")
        local rx = Registry.get(id, "Reactions")
        local i = 1
        while i <= #q do
            local token = q[i]
            
            if rx and rx[token] then
                -- Push reactions to the end of the queue
                for _, reaction in ipairs(rx[token]) do
                    table.insert(q, reaction)
                end
                table.remove(q, i)
            elseif token == "PlayLoveInk" then
                local attrs = Registry.get(id, "Attributes")
                if attrs and attrs.story_id then
                    getStoryManager().startStory(attrs.story_id)
                end
                table.remove(q, i)
            elseif string.sub(token, 1, 17) == "ReplaceComposite_" then
                local newComp = string.sub(token, 18)
                getConsole().log("Mutating entity " .. id .. " -> " .. newComp, {0.8, 0.2, 0.8})
                getFactory().applyComposite(id, newComp)
                break -- break loop because queue is wiped
            else
                local PluginLoader = getPluginLoader()
                local pToken = PluginLoader.tokens[token]
                if pToken and pToken.execute then
                    pToken.execute(id, PluginLoader.buildContext())
                end
                table.remove(q, i)
            end
        end
    end
end

function Systems.InteractionSystem(playerId, world)
    if not playerId or not world then return false end
    local trans = Registry.get(playerId, "Transform")
    if not trans then return false end

    local gx = math.floor((trans.x + trans.w / 2) / world.tileSize)
    local gy = math.floor((trans.y + trans.h / 2) / world.tileSize)
    local Console = require('engine.core.console')

    for id, _ in pairs(Registry.entities) do
        if id ~= playerId then
            local etrans = Registry.get(id, "Transform")
            local eflags = Registry.get(id, "Flags")
            if etrans and eflags and eflags.is_interactable then
                local egx = math.floor((etrans.x + etrans.w / 2) / world.tileSize)
                local egy = math.floor((etrans.y + etrans.h / 2) / world.tileSize)
                if math.abs(gx - egx) <= 1 and math.abs(gy - egy) <= 1 then
                    local q = Registry.get(id, "TokenQueue")
                    if q then
                        table.insert(q, "TriggerOnInteract")
                        Console.log("Emitted TriggerOnInteract to entity " .. id)
                        return true
                    end
                end
            end
        end
    end

    local tdata = world:getTileData(gx, gy)
    if tdata and tdata.flags and tdata.flags.interactMessage then
        local StoryManager = require('engine.narrative.story_manager')
        StoryManager.startInteraction(tdata.flags.interactMessage)
        return true
    end
    return false
end

function Systems.ClickInteractionSystem(wx, wy)
    local Console = require('engine.core.console')
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

return Systems
