local UI = require('engine.ui.init')
local state = require('tools.anim8tor.state')
local logic = require('tools.anim8tor.logic')

local ui_left = {}

function ui_left.update()
    -- IMGUI handles everything during draw
end

function ui_left.draw()
    local px = 0
    local py = 0
    local pw = 320
    local pad = 16
    local fullW = pw - pad * 2

    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("fill", px, py, pw, state.screenH)

    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.line(pw, 0, pw, state.screenH)
    love.graphics.setLineWidth(1)

    if state.font then love.graphics.setFont(state.font) end
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.print("ANIM8TOR", pad, 14)

    -- Image dimensions & remainder indicator
    if state.image then
        local iw, ih = state.image:getDimensions()
        local fw = tonumber(state.inputState.frameWidth.text) or 32
        local fh = tonumber(state.inputState.frameHeight.text) or 32
        local l = tonumber(state.inputState.left.text) or 0
        local t = tonumber(state.inputState.top.text) or 0
        local b = tonumber(state.inputState.border.text) or 0
        local remX = (iw - l) % math.max(1, fw + b)
        local remY = (ih - t) % math.max(1, fh + b)
        if state.fontSmall then love.graphics.setFont(state.fontSmall) end
        love.graphics.setColor(0.65, 0.75, 0.85)
        love.graphics.print(string.format("%dx%dpx (rem %d,%d)", iw, ih, remX, remY), pad, 36)
    end

    -- Grid mode toggle + AUTO
    local hw = math.floor((fullW - 6) / 2)
    local gModeTxt = (state.gridMode == "count") and "BY COUNT" or "BY PIXELS"
    if UI.Button("btn_grid_mode", gModeTxt, pad, 56, hw, 24) then
        state.gridMode = (state.gridMode == "count") and "pixels" or "count"
        if state.gridMode == "count" then logic.applyCountGrid() end
    end
    if UI.Button("btn_auto", "AUTO", pad + hw + 6, 56, hw, 24) then
        logic.autoDetectGrid()
    end

    -- Quick size presets + FIT zoom
    local bw = math.floor((fullW - 12) / 4)
    for idx, sz in ipairs({16, 32, 64}) do
        if UI.Button("btn_p" .. sz, tostring(sz), pad + (idx - 1) * (bw + 4), 86, bw, 24) then
            state.gridMode = "pixels"
            state.inputState.frameWidth.text = tostring(sz)
            state.inputState.frameHeight.text = tostring(sz)
            logic.updateGrid()
        end
    end
    if UI.Button("btn_fit", "FIT", pad + 3 * (bw + 4), 86, bw, 24) then
        logic.fitViewport()
    end

    -- Stepper field helper
    local function stepperField(label, id, y, inputObj, onChange, minVal, step)
        step = step or 1
        if state.fontSmall then love.graphics.setFont(state.fontSmall) end
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print(label .. ":", pad, y + 7)
        local boxW = fullW - 152
        local newVal = UI.Input(id, inputObj.text, pad + 96, y, boxW, 24)
        if newVal then
            inputObj.text = newVal
            onChange()
        end
        if UI.Button("dec_" .. id, "-", pad + 100 + boxW, y, 24, 24) then
            local v = math.max(minVal or 0, (tonumber(inputObj.text) or 0) - step)
            inputObj.text = (step < 1) and string.format("%.2f", v) or tostring(v)
            onChange()
        end
        if UI.Button("inc_" .. id, "+", pad + 128 + boxW, y, 24, 24) then
            local v = (tonumber(inputObj.text) or 0) + step
            inputObj.text = (step < 1) and string.format("%.2f", v) or tostring(v)
            onChange()
        end
    end

    if state.gridMode == "count" then
        stepperField("Cols",     "cols", 118, state.inputState.cols,   logic.applyCountGrid, 1, 1)
        stepperField("Rows",     "rows", 148, state.inputState.rows,   logic.applyCountGrid, 1, 1)
        stepperField("Margin L", "ml",   178, state.inputState.left,   logic.applyCountGrid, 0, 1)
        stepperField("Margin T", "mt",   208, state.inputState.top,    logic.applyCountGrid, 0, 1)
        stepperField("Border",   "bd",   238, state.inputState.border, logic.applyCountGrid, 0, 1)
    else
        stepperField("Frame W",  "fw",   118, state.inputState.frameWidth,  logic.updateGrid, 1, 1)
        stepperField("Frame H",  "fh",   148, state.inputState.frameHeight, logic.updateGrid, 1, 1)
        stepperField("Margin L", "ml",   178, state.inputState.left,        logic.updateGrid, 0, 1)
        stepperField("Margin T", "mt",   208, state.inputState.top,         logic.updateGrid, 0, 1)
        stepperField("Border",   "bd",   238, state.inputState.border,      logic.updateGrid, 0, 1)
    end

    -- Animation timing + FPS readout
    if state.font then love.graphics.setFont(state.font) end
    love.graphics.setColor(0.95, 0.95, 0.95)
    local durNum = tonumber(state.inputState.duration.text) or 0.1
    local fps = math.floor((1 / math.max(0.01, durNum)) + 0.5)
    love.graphics.print("ANIMATION", pad, 274)
    if state.fontSmall then love.graphics.setFont(state.fontSmall) end
    love.graphics.setColor(0.65, 0.85, 0.65)
    love.graphics.print(string.format("%d FPS", fps), pad + 140, 276)

    stepperField("Duration", "dur", 298, state.inputState.duration, logic.createAnimation, 0.02, 0.02)

    local tw3 = math.floor((fullW - 12) / 3)
    if UI.Button("btn_refresh", "REFRESH", pad, 334, tw3, 30) then
        logic.updateGrid()
    end
    if UI.Button("btn_undo_f", "UNDO", pad + tw3 + 6, 334, tw3, 30) then
        logic.popFrame()
    end
    if UI.Button("btn_clear", "CLEAR", pad + (tw3 + 6) * 2, 334, tw3, 30) then
        state.selectedFrames = {}
        logic.createAnimation()
    end

    -- Export target
    if state.font then love.graphics.setFont(state.font) end
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.print("EXPORT", pad, 380)

    local modeLabel = (state.targetMode == "tile") and "MODE: TILE" or "MODE: CHARACTER"
    if UI.Button("btn_mode", modeLabel, pad, 404, fullW, 28) then
        if state.targetMode == "tile" then
            state.targetMode = "character"
            if state.inputState.entityType.text == "water" then
                state.inputState.entityType.text = "player"
            end
        else
            state.targetMode = "tile"
            if state.inputState.entityType.text == "player" then
                state.inputState.entityType.text = "water"
            end
        end
    end

    local targetLabel = (state.targetMode == "tile") and "Tile ID" or "Entity"
    if state.fontSmall then love.graphics.setFont(state.fontSmall) end
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print(targetLabel .. ":", pad, 446)
    local ent = UI.Input("entity", state.inputState.entityType.text, pad + 86, 440, fullW - 140, 26)
    if ent then state.inputState.entityType.text = ent end
    if UI.Button("btn_ent_prev", "<", pad + fullW - 50, 440, 24, 26) then
        logic.cycleAsset(-1)
    end
    if UI.Button("btn_ent_next", ">", pad + fullW - 24, 440, 24, 26) then
        logic.cycleAsset(1)
    end

    if state.targetMode == "tile" then
        local phaseTxt = "PHASE: " .. string.upper(state.tilePhase or "sync")
        if UI.Button("btn_tile_phase", phaseTxt, pad, 474, fullW, 26) then
            local order = { sync = "noise", noise = "random", random = "sync" }
            state.tilePhase = order[state.tilePhase or "sync"] or "sync"
        end
        local tModeTxt = "PLAY: " .. string.upper(state.tileMode or "loop")
        if UI.Button("btn_tile_mode", tModeTxt, pad, 506, fullW, 26) then
            state.tileMode = (state.tileMode == "pingpong") and "loop" or "pingpong"
        end
        if UI.Button("btn_load_asset", "LOAD TILE", pad, 538, fullW, 28) then
            logic.loadCurrentAsset()
        end
    else
        if UI.Button("btn_load_asset", "LOAD CHARACTER", pad, 474, fullW, 28) then
            logic.loadCurrentAsset()
        end
    end

    -- Draw EXIT button at the top bar area (centered horizontally)
    if UI.Button("btn_exit", "EXIT TO GAME", state.screenW / 2 - 100, 16, 200, 32) then
        return "exit"
    end
end

return ui_left
