-- tools/anim8tor/scene.lua
-- Anim8tor scene integrated into GP-RPG (LoveMotion viewport & playback + GP-RPG character/tile manifest saving).

local state    = require('tools.anim8tor.state')
local logic    = require('tools.anim8tor.logic')
local viewport = require('tools.anim8tor.viewport')
local ui_right = require('tools.anim8tor.ui_right')
local UI       = require('engine.ui.init')
local ui_left  = require('tools.anim8tor.ui_left')

local AnimatorScene = {}

function AnimatorScene:load()
    state.screenW, state.screenH = love.graphics.getDimensions()

    love.graphics.setBackgroundColor(0.05, 0.05, 0.05)
    love.graphics.setDefaultFilter("nearest", "nearest")

    local ok1, f1 = pcall(love.graphics.newFont, "fonts/PressStart2P.ttf", 11)
    local ok2, f2 = pcall(love.graphics.newFont, "fonts/PressStart2P.ttf", 9)
    state.font      = ok1 and f1 or love.graphics.getFont()
    state.fontSmall = ok2 and f2 or love.graphics.getFont()

    UI.Theme.font = state.font
    UI.Theme.fontSmall = state.fontSmall

    state.savedSlots = {}
    love.keyboard.setKeyRepeat(true)
end

function AnimatorScene:update(dt)
    if state.toastTimer and state.toastTimer > 0 then
        state.toastTimer = math.max(0, state.toastTimer - dt)
    end
    if state.animation and state.playing then
        state.animation:update(dt)
    end
    UI.update(dt)
    ui_right.update()
end

function AnimatorScene:draw()
    love.graphics.setColor(0.05, 0.05, 0.05)
    love.graphics.rectangle("fill", 0, 0, state.screenW, state.screenH)

    viewport.draw()
    ui_right.draw()

    if ui_left.draw() == "exit" then
        local ok, f = pcall(love.graphics.newFont, "fonts/PressStart2P.ttf", 12)
        if ok then love.graphics.setFont(f) end
        local Context   = require('engine.core.context')
        local SceneGame = require("scenes.game")
        Context.scene   = SceneGame
        _G.game         = SceneGame
        love.graphics.setBackgroundColor(0, 0, 0)
        love.keyboard.setKeyRepeat(false)
        return
    end

    if state.toastTimer and state.toastTimer > 0 and state.toastText ~= "" then
        local tw = (state.fontSmall and state.fontSmall:getWidth(state.toastText) or #state.toastText * 8) + 24
        local tx = (state.screenW - tw) / 2
        local ty = state.screenH - 44
        love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
        love.graphics.rectangle("fill", tx, ty, tw, 28, 4, 4)
        love.graphics.setColor(0.4, 0.9, 0.5, 1)
        love.graphics.rectangle("line", tx, ty, tw, 28, 4, 4)
        if state.fontSmall then love.graphics.setFont(state.fontSmall) end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(state.toastText, tx, ty + 8, tw, "center")
    end
end

function AnimatorScene:mousepressed(x, y, button, istouch, presses)
    if x > 320 and x < state.screenW - 320 then
        viewport.mousepressed(x, y, button)
    end
end

function AnimatorScene:mousereleased(x, y, button, istouch, presses)
    viewport.mousereleased(x, y, button)
end

function AnimatorScene:mousemoved(x, y, dx, dy, istouch)
    viewport.mousemoved(x, y, dx, dy)
end

function AnimatorScene:wheelmoved(x, y)
    local mx = love.mouse.getX()
    if mx > 320 and mx < state.screenW - 320 then
        viewport.wheelmoved(x, y)
    end
end

function AnimatorScene:textinput(t)
    UI.textinput(t)
end

function AnimatorScene:keypressed(key)
    UI.keypressed(key)
end

function AnimatorScene:filedropped(file)
    logic.handleFileDropped(file)
end

function AnimatorScene:resize(w, h)
    state.screenW = w
    state.screenH = h
end

return AnimatorScene
