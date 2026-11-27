-- content/plugins/directors_cut.lua
-- Director's Cut: In-game cutscene & cinematic camera sequencer plugin.
-- Run via console: `directors_cut` or `plugin.run directors_cut`

local StoryManager = require('engine.narrative.story_manager')

local state = {
    playing = false,
    steps = {},
    stepIdx = 1,
    waitTimer = 0,
    waitingDialogue = false,
    moveTask = nil,
    savedZoom = nil,
    barHeight = 0,
    targetBarHeight = 0,
    fadeAlpha = 0,
    fadeTween = nil,
}

local function resolveEntity(ctx, target)
    if target == nil or target == "player" then
        return ctx.game and ctx.game.playerId or nil
    end
    return target
end

local function stopCutscene(ctx)
    state.playing = false
    state.steps = {}
    state.stepIdx = 1
    state.waitTimer = 0
    state.waitingDialogue = false
    state.moveTask = nil
    state.targetBarHeight = 0
    state.fadeTween = nil
    state.fadeAlpha = 0

    if ctx and ctx.camera then
        ctx.camera.clearTarget()
        if state.savedZoom ~= nil then
            ctx.camera.setZoom(state.savedZoom)
            state.savedZoom = nil
        end
    end

    local PluginLoader = require('engine.core.plugin_loader')
    if PluginLoader.activeMode == "directors_cut" then
        PluginLoader.exit("directors_cut")
    end
end

local function advanceStep(ctx)
    while state.playing and state.stepIdx <= #state.steps do
        local step = state.steps[state.stepIdx]
        state.stepIdx = state.stepIdx + 1
        local cmd = step.cmd

        if cmd == "bars" then
            state.targetBarHeight = step.show and (step.height or 56) or 0

        elseif cmd == "fade" then
            local dur = step.duration or 0.5
            state.fadeTween = {
                from = state.fadeAlpha,
                to   = step.alpha or 1,
                dur  = math.max(0.01, dur),
                t    = 0,
            }
            if step.wait ~= false then
                state.waitTimer = (step.wait ~= nil) and step.wait or dur
                return
            end

        elseif cmd == "camera" then
            local ts = (ctx.world and ctx.world.tileSize) or 32
            local tx = step.x or ((step.gx or 0) * ts + ts / 2)
            local ty = step.y or ((step.gy or 0) * ts + ts / 2)
            if step.duration and step.duration > 0 and ctx.camera.tweenTo then
                local val = (step.scale ~= nil) and step.scale or step.zoom
                ctx.camera.tweenTo(tx, ty, val, step.duration, step.ease or "inOut", step.scale ~= nil)
                state.waitTimer = (step.wait ~= nil) and step.wait or step.duration
                return
            else
                ctx.camera.setTarget(tx, ty, step.snap == true)
                if step.zoom ~= nil then
                    ctx.camera.setZoom(step.zoom, step.snap == true)
                end
                if step.wait and step.wait > 0 then
                    state.waitTimer = step.wait
                    return
                end
            end

        elseif cmd == "wait" then
            state.waitTimer = step.time or 1.0
            return

        elseif cmd == "flag" then
            if step.name then
                ctx.flags.set(step.name, step.value)
            end

        elseif cmd == "move" then
            local eid = resolveEntity(ctx, step.target)
            local ts = (ctx.world and ctx.world.tileSize) or 32
            if eid then
                local t = ctx.registry.get(eid, "Transform")
                if t then
                    local tx = step.x or ((step.gx or 0) * ts)
                    local ty = step.y or ((step.gy or 0) * ts)
                    state.moveTask = {
                        id = eid,
                        tx = tx,
                        ty = ty,
                        speed = step.speed or 80,
                    }
                    if step.wait ~= false then
                        return
                    end
                end
            end

        elseif cmd == "dialogue" then
            state.waitingDialogue = true
            if step.story then
                StoryManager.startStory(step.story, step.knot)
            elseif step.text then
                StoryManager.startInteraction(step.text)
            end
            return

        elseif cmd == "release" then
            stopCutscene(ctx)
            return
        end
    end

    if state.stepIdx > #state.steps and not state.moveTask and state.waitTimer <= 0 then
        stopCutscene(ctx)
    end
end

local function startScript(ctx, script)
    state.steps = script or {}
    state.stepIdx = 1
    state.waitTimer = 0
    state.waitingDialogue = false
    state.moveTask = nil
    state.playing = true
    state.savedZoom = ctx.camera and ctx.camera.getZoom() or nil
    state.targetBarHeight = 56
    advanceStep(ctx)
end

local DEMO_SCRIPT = {
    { cmd = "bars", show = true, height = 56 },
    { cmd = "camera", gx = -3, gy = -1, scale = 3.5, duration = 1.4, ease = "inOut" },
    { cmd = "dialogue", text = "Director's Cut: Smooth eased pan left & zoom in." },
    { cmd = "camera", gx = 3, gy = -1, scale = 2.0, duration = 1.6, ease = "inOut" },
    { cmd = "camera", gx = 0, gy = 0, zoom = 1, duration = 1.0, ease = "out" },
    { cmd = "bars", show = false },
    { cmd = "release" },
}

return {
    id          = "directors_cut",
    name        = "Director's Cut",
    version     = "1.0",
    description = "In-game cutscene & cinematic camera sequencer.",

    world = {
        isolated            = false,
        exclusiveInput      = true,
        hideDefaultEntities = false,
    },

    tokens = {
        PlayCutscene = {
            description = "Runs the Director's Cut cutscene script on the entity's Attributes.cutscene or demo.",
            consumes    = {},
            execute     = function(entityId, ctx)
                local attrs = entityId and ctx.registry.get(entityId, "Attributes")
                local script = attrs and attrs.cutscene or nil
                if type(script) == "string" then
                    local path = "content/cutscenes/" .. script .. ".lua"
                    if love.filesystem.getInfo(path) then
                        local ok, loaded = pcall(love.filesystem.load(path))
                        script = (ok and type(loaded) == "table") and loaded or nil
                    else
                        script = nil
                    end
                end
                ctx.call("directors_cut", "play", script)
            end
        }
    },

    composites = {
        CutsceneTrigger = {
            Flags      = { is_solid = false, is_interactable = true },
            Attributes = {},
            Reactions  = {
                TriggerOnInteract = { "PlayCutscene" }
            }
        }
    },

    commands = {
        play = function(script)
            local PluginLoader = require('engine.core.plugin_loader')
            PluginLoader.enter("directors_cut")
            if script then
                startScript(PluginLoader.buildContext(), script)
            end
        end,
        stop = function()
            local PluginLoader = require('engine.core.plugin_loader')
            stopCutscene(PluginLoader.buildContext())
        end
    },

    onEnter = function(ctx)
        startScript(ctx, DEMO_SCRIPT)
    end,

    onExit = function(ctx)
        state.playing = false
        state.targetBarHeight = 0
        state.moveTask = nil
        if ctx and ctx.camera then
            ctx.camera.clearTarget()
        end
    end,

    onUpdate = function(dt, ctx)
        -- Animate letterbox bars smoothly
        state.barHeight = state.barHeight + (state.targetBarHeight - state.barHeight) * math.min(1, 10 * dt)

        if state.fadeTween then
            local ft = state.fadeTween
            ft.t = math.min(ft.dur, ft.t + dt)
            state.fadeAlpha = ft.from + (ft.to - ft.from) * (ft.t / ft.dur)
            if ft.t >= ft.dur then state.fadeTween = nil end
        end

        if not state.playing then return end

        -- Resume after LoveInk dialogue closes
        if state.waitingDialogue then
            if not StoryManager.isActive() then
                state.waitingDialogue = false
                advanceStep(ctx)
            end
            return
        end

        -- Handle entity walk step
        if state.moveTask then
            local m = state.moveTask
            local t = ctx.registry.get(m.id, "Transform")
            local v = ctx.registry.get(m.id, "Velocity")
            if not t then
                state.moveTask = nil
                advanceStep(ctx)
                return
            end
            local dx = m.tx - t.x
            local dy = m.ty - t.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist <= 2 then
                t.x, t.y = m.tx, m.ty
                if v then v.dx, v.dy = 0, 0 end
                state.moveTask = nil
                advanceStep(ctx)
            else
                local nx, ny = dx / dist, dy / dist
                local stepDist = math.min(dist, m.speed * dt)
                t.x = t.x + nx * stepDist
                t.y = t.y + ny * stepDist
                if v then
                    v.dx, v.dy = nx, ny
                    if math.abs(dx) > math.abs(dy) then
                        v.facing = (dx > 0) and "right" or "left"
                    else
                        v.facing = (dy > 0) and "down" or "up"
                    end
                end
            end
            return
        end

        -- Handle wait timer
        if state.waitTimer > 0 then
            state.waitTimer = state.waitTimer - dt
            if state.waitTimer <= 0 then
                state.waitTimer = 0
                advanceStep(ctx)
            end
        end
    end,

    onKeypressed = function(key, ctx)
        if not state.playing then return end
        if key == "q" or key == "backspace" then
            stopCutscene(ctx)
        end
    end,

    onDraw = function(ctx)
        local sw, sh = love.graphics.getDimensions()
        if state.fadeAlpha > 0.01 then
            love.graphics.setColor(0, 0, 0, state.fadeAlpha)
            love.graphics.rectangle("fill", 0, 0, sw, sh)
        end
        if state.barHeight < 1 then return end
        local bh = math.floor(state.barHeight)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, sw, bh)
        love.graphics.rectangle("fill", 0, sh - bh, sw, bh)

        if state.playing then
            love.graphics.setColor(0.7, 0.7, 0.7, 0.7)
            love.graphics.print("DIRECTOR'S CUT  [Q = Skip]", 16, sh - bh + 18)
        end
    end,
}
