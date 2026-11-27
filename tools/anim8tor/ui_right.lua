-- tools/anim8tor/ui_right.lua
-- Right panel: animation preview + playback + hitbox/radius editor (top) + binding slots & export (bottom).

local state    = require('tools.anim8tor.state')
local viewport = require('tools.anim8tor.viewport')
local logic    = require('tools.anim8tor.logic')
local UI       = require('engine.ui.init')

local ui_right = {}

local PANEL_W = 320
local PAD     = 16
local ROW_H   = 18

local TEMPLATES = {
    "walk_down",  "walk_up",  "walk_left",  "walk_right",
    "idle_down",  "idle_up",  "idle_left",  "idle_right",
    "attack", "hurt", "default"
}

local hoverIdx     = nil
local mouseWasDown = false

local function panelX() return state.screenW - PANEL_W end

local function listStartY()
    return math.floor(state.screenH * 0.5) + PAD + 38
end

local function getPreviewRect()
    local px    = panelX()
    local divY  = math.floor(state.screenH * 0.5)
    local prevW = PANEL_W - PAD * 2
    local prevY = PAD + 26
    local ctrlH = 26
    local prevH = divY - prevY - ctrlH - PAD - 8

    local fw = tonumber(state.inputState.frameWidth.text)  or 32
    local fh = tonumber(state.inputState.frameHeight.text) or 32
    local sc = math.min((prevW - 8) / fw, (prevH - 8) / fh)
    if sc > 1 then sc = math.floor(sc) end
    local dw = fw * sc
    local dh = fh * sc
    local dx = px + PAD + (prevW / 2) - (dw / 2)
    local dy = prevY + (prevH / 2) - (dh / 2)
    return dx, dy, dw, dh, sc, fw, fh, prevY, prevH
end

local function screenToFramePixel(mx, my)
    local dx, dy, _, _, sc, fw, fh = getPreviewRect()
    local fx = math.max(0, math.min(fw, math.floor((mx - dx) / sc + 0.5)))
    local fy = math.max(0, math.min(fh, math.floor((my - dy) / sc + 0.5)))
    return fx, fy, fw, fh
end

function ui_right.mousepressed(x, y, button)
    if state.targetMode == "tile" or state.hitboxEditMode == "view" then return end
    if not state.image or not state.animation then return end

    local dx, dy, dw, dh = getPreviewRect()
    if x < dx or x > dx + dw or y < dy or y > dy + dh then return end

    local fx, fy, fw, fh = screenToFramePixel(x, y)
    if button == 1 then
        if state.hitboxEditMode == "box" then
            state.previewDrag = { kind = "box", sx = fx, sy = fy, fw = fw, fh = fh }
            state.collider = { ox = fx, oy = fy, w = 1, h = 1, baseW = fw, baseH = fh }
        elseif state.hitboxEditMode == "radius" then
            state.previewDrag = { kind = "radius", sx = fx, sy = fy, fw = fw, fh = fh }
            state.radius = { ox = fx, oy = fy, r = 1, baseW = fw, baseH = fh }
        end
    end
end

function ui_right.mousemoved(x, y, dx, dy)
    if not state.previewDrag then return end
    local fx, fy, fw, fh = screenToFramePixel(x, y)
    local d = state.previewDrag
    if d.kind == "box" then
        local ox = math.min(d.sx, fx)
        local oy = math.min(d.sy, fy)
        local w  = math.max(1, math.abs(fx - d.sx))
        local h  = math.max(1, math.abs(fy - d.sy))
        state.collider = { ox = ox, oy = oy, w = w, h = h, baseW = fw, baseH = fh }
    elseif d.kind == "radius" then
        local r = math.max(1, math.floor(math.sqrt((fx - d.sx)^2 + (fy - d.sy)^2) + 0.5))
        state.radius = { ox = d.sx, oy = d.sy, r = r, baseW = fw, baseH = fh }
    end
end

function ui_right.mousereleased(x, y, button)
    if button == 1 and state.previewDrag then
        state.previewDrag = nil
    end
end

function ui_right.update()
    local px  = panelX()
    local lsY = listStartY()
    local mx, my = love.mouse.getPosition()

    hoverIdx = nil
    if state.targetMode ~= "tile" then
        for i = 1, #TEMPLATES do
            local ry = lsY + (i - 1) * ROW_H
            if mx >= px + PAD and mx <= px + PANEL_W - PAD
            and my >= ry and my < ry + ROW_H then
                hoverIdx = i
                break
            end
        end
    end

    local down = love.mouse.isDown(1)
    if down and not mouseWasDown and hoverIdx then
        logic.selectBindingSlot(TEMPLATES[hoverIdx])
    end
    mouseWasDown = down
end

function ui_right.draw()
    local px   = panelX()
    local divY = math.floor(state.screenH * 0.5)
    local prevW = PANEL_W - PAD * 2

    -- Panel background
    love.graphics.setColor(0.1, 0.1, 0.1, 1)
    love.graphics.rectangle("fill", px, 0, PANEL_W, state.screenH)

    love.graphics.setColor(0.3, 0.3, 0.3, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(px, 0, px, state.screenH)
    love.graphics.setLineWidth(1)

    -- TOP HALF: PREVIEW + HITBOX/RADIUS CONTROLS
    if state.font then love.graphics.setFont(state.font) end
    love.graphics.setColor(0.75, 0.75, 0.85)
    love.graphics.print("PREVIEW", px + PAD, PAD)

    if state.targetMode ~= "tile" then
        local modeLabels = { view = "HB: VIEW", box = "HB: BOX", radius = "HB: RAD" }
        local nextMode   = { view = "box", box = "radius", radius = "view" }
        local hbTxt = modeLabels[state.hitboxEditMode or "view"] or "HB: VIEW"
        if UI.Button("btn_hb_mode", hbTxt, px + PANEL_W - PAD - 122, PAD - 3, 76, 22) then
            state.hitboxEditMode = nextMode[state.hitboxEditMode or "view"] or "view"
        end
        if UI.Button("btn_hb_clr", "CLR", px + PANEL_W - PAD - 42, PAD - 3, 42, 22) then
            if state.hitboxEditMode == "radius" then
                state.radius = nil
            elseif state.hitboxEditMode == "box" then
                state.collider = nil
            else
                state.collider = nil
                state.radius = nil
            end
        end
    end

    local dx, dy, dw, dh, sc, fw, fh, prevY, prevH = getPreviewRect()
    local bx, by, bw, bh = px + PAD, prevY, prevW, prevH

    love.graphics.setColor(0.15, 0.15, 0.15)
    love.graphics.rectangle("fill", bx, by, bw, bh)
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx, by, bw, bh)
    love.graphics.setLineWidth(1)

    if state.errorMessage ~= "" then
        love.graphics.setColor(1, 0.35, 0.35)
        if state.fontSmall then love.graphics.setFont(state.fontSmall) end
        love.graphics.printf("ERR: " .. state.errorMessage,
            px + PAD + 6, prevY + 6, prevW - 12, "left")

    elseif state.animation and state.image then
        viewport.drawCheckerboard(dx, dy, dw, dh, 16)
        love.graphics.setColor(1, 1, 1)
        local sx = state.flipH and -sc or sc
        local ox = state.flipH and fw or 0
        state.animation:draw(state.image, dx, dy, 0, sx, sc, ox, 0)

        -- Preview existing / edited Collider & Radius
        if state.targetMode ~= "tile" and state.showHitboxPreview then
            if state.collider then
                local c = state.collider
                local cox = state.flipH and (fw - c.ox - c.w) or c.ox
                love.graphics.setColor(0.2, 1.0, 0.4, 0.25)
                love.graphics.rectangle("fill", dx + cox * sc, dy + c.oy * sc, c.w * sc, c.h * sc)
                love.graphics.setColor(0.2, 1.0, 0.4, 0.95)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", dx + cox * sc, dy + c.oy * sc, c.w * sc, c.h * sc)
                love.graphics.setLineWidth(1)
            end
            if state.radius then
                local r = state.radius
                local rox = state.flipH and (fw - r.ox) or r.ox
                love.graphics.setColor(0.2, 0.85, 1.0, 0.15)
                love.graphics.circle("fill", dx + rox * sc, dy + r.oy * sc, r.r * sc)
                love.graphics.setColor(0.2, 0.85, 1.0, 0.95)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", dx + rox * sc, dy + r.oy * sc, r.r * sc)
                love.graphics.setLineWidth(1)
            end
        end
    else
        love.graphics.setColor(0.38, 0.38, 0.43)
        if state.fontSmall then love.graphics.setFont(state.fontSmall) end
        love.graphics.printf("Drop spritesheet\n& click frames",
            px + PAD, prevY + prevH * 0.35, prevW, "center")
    end

    -- Playback controls row below preview box
    local ctrlH = 26
    local ctrlY = divY - ctrlH - 8
    local cbw = math.floor((prevW - 12) / 4)
    if UI.Button("btn_prev_f", "<", px + PAD, ctrlY, cbw, ctrlH) then
        logic.stepFrame(-1)
    end
    local playLabel = state.playing and "PAUSE" or "PLAY"
    if UI.Button("btn_play", playLabel, px + PAD + cbw + 4, ctrlY, cbw, ctrlH) then
        state.playing = not state.playing
    end
    if UI.Button("btn_next_f", ">", px + PAD + (cbw + 4) * 2, ctrlY, cbw, ctrlH) then
        logic.stepFrame(1)
    end
    local flipLabel = state.flipH and "FLIP*" or "FLIP"
    if UI.Button("btn_flip", flipLabel, px + PAD + (cbw + 4) * 3, ctrlY, cbw, ctrlH) then
        state.flipH = not state.flipH
    end

    -- Center TRY SAMPLE button when no image is loaded
    if not state.image then
        local tryX = state.screenW / 2 - 75
        local tryY = state.screenH / 2 + 148
        if UI.Button("btn_sample", "TRY SAMPLE", tryX, tryY, 150, 30) then
            logic.loadSample()
        end
    end

    -- BOTTOM HALF: BINDING SLOTS / TILE INFO
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("fill", px, divY, PANEL_W, state.screenH - divY)

    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.setLineWidth(1)
    love.graphics.line(px + PAD, divY, px + PANEL_W - PAD, divY)

    if state.font then love.graphics.setFont(state.font) end
    love.graphics.setColor(0.95, 0.95, 0.95)
    if state.targetMode == "tile" then
        love.graphics.print("TILE ANIMATION", px + PAD, divY + PAD)
        if state.fontSmall then love.graphics.setFont(state.fontSmall) end
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.printf("Writes animation = {...} to:\ncontent/tiles/<Tile ID>.lua\nand spritesheet to <Tile ID>.png", px + PAD, divY + PAD + 32, prevW, "left")
    else
        love.graphics.print("BINDINGS", px + PAD, divY + PAD)
        if state.fontSmall then love.graphics.setFont(state.fontSmall) end
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.print("slot -> BIND & SAVE -> animations.lua", px + PAD, divY + PAD + 20)

        local lsY = listStartY()
        for i, tmpl in ipairs(TEMPLATES) do
            local ry      = lsY + (i - 1) * ROW_H
            local rx      = px + PAD - 4
            local rw      = PANEL_W - PAD * 2 + 8
            local saved   = state.savedSlots[tmpl]
            local hovered = (i == hoverIdx)

            if state.selectedTemplate == tmpl then
                love.graphics.setColor(0.9, 0.9, 0.9, 0.2)
                love.graphics.rectangle("fill", rx, ry, rw, ROW_H - 2)
                love.graphics.setColor(0.9, 0.9, 0.9, 0.8)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", rx, ry, rw, ROW_H - 2)
                love.graphics.setLineWidth(1)
            elseif hovered then
                love.graphics.setColor(0.25, 0.25, 0.25, 1)
                love.graphics.rectangle("fill", rx, ry, rw, ROW_H - 2)
            end

            love.graphics.setColor(saved and {0.4, 0.9, 0.5} or {0.3, 0.3, 0.3})
            love.graphics.print(saved and "*" or "o", px + PAD, ry + 3)

            local hasData = state.bindings and state.bindings[tmpl] ~= nil
            if state.selectedTemplate == tmpl then
                love.graphics.setColor(0.95, 0.95, 0.95)
            elseif hasData then
                love.graphics.setColor(0.7, 0.7, 0.7)
            else
                love.graphics.setColor(0.5, 0.5, 0.5)
            end
            love.graphics.print(tmpl, px + PAD + 16, ry + 3)
        end
    end

    -- Divider above buttons
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.line(px + PAD, state.screenH - 96, px + PANEL_W - PAD, state.screenH - 96)

    -- Bottom Action Buttons
    local btnY = state.screenH - 88
    if UI.Button("btn_bind", "BIND & SAVE", px + PAD, btnY, PANEL_W - PAD * 2, 36) then
        logic.bindAndSave()
    end

    if UI.Button("btn_export", "COPY SNIPPET", px + PAD, btnY + 42, PANEL_W - PAD * 2, 36) then
        logic.exportBindings()
    end
end

return ui_right
