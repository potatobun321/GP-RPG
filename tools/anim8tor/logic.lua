local anim8 = require 'lib.anim8.anim8'
local state = require('tools.anim8tor.state')

local logic = {}

function logic.notify(msg)
    state.toastText = msg or ""
    state.toastTimer = 2.0
    local ok, Console = pcall(require, 'engine.core.console')
    if ok and Console and msg and msg ~= "" then
        Console.log("[Anim8tor] " .. msg, {0.4, 0.9, 0.5})
    end
end

function logic.loadSample()
    local ok, fdata = pcall(love.filesystem.newFileData, "content/characters/player/spritesheet.png")
    if not ok or not fdata then
        state.errorMessage = "Sample spritesheet not found."
        return
    end
    state.fileData = fdata
    state.fileExt = ".png"
    state.image = love.graphics.newImage(fdata)
    state.animation = nil
    state.generatedCode = ""
    state.generatedFrameData = nil
    state.errorMessage = ""
    state.selectedFrames = {}
    logic.fitViewport()
    logic.autoDetectGrid()
    logic.notify("Loaded player spritesheet")
end

function logic.stepFrame(dir)
    if not state.animation or not state.animation.frames or #state.animation.frames == 0 then return end
    state.playing = false
    local count = #state.animation.frames
    local cur = state.animation.position or 1
    local nxt = ((cur - 1 + dir) % count) + 1
    state.animation:gotoFrame(nxt)
end

function logic.popFrame()
    if #state.selectedFrames > 0 then
        table.remove(state.selectedFrames)
        logic.createAnimation()
    end
end

local function parseFramesString(framesStr)
    local out = {}
    if type(framesStr) == "string" then
        local nums = {}
        for n in framesStr:gmatch("%d+") do
            table.insert(nums, tonumber(n))
        end
        for i = 1, #nums - 1, 2 do
            table.insert(out, { x = nums[i], y = nums[i + 1] })
        end
    elseif type(framesStr) == "table" then
        for _, f in ipairs(framesStr) do
            if type(f) == "table" and f[1] and f[2] then
                table.insert(out, { x = f[1], y = f[2] })
            end
        end
    end
    return out
end

local function loadImageFromPath(path)
    if not path then return false end
    local ok, fdata = pcall(love.filesystem.newFileData, path)
    if not ok or not fdata then return false end
    state.fileData = fdata
    state.fileExt = path:match("^.+(%..+)$") or ".png"
    state.image = love.graphics.newImage(fdata)
    return true
end

function logic.selectBindingSlot(slotName)
    state.selectedTemplate = slotName
    state.inputState.exportName.text = slotName
    local slot = state.bindings and state.bindings[slotName]
    if slot then
        state.inputState.frameWidth.text  = tostring(slot.frameW or 32)
        state.inputState.frameHeight.text = tostring(slot.frameH or 32)
        state.inputState.left.text        = tostring(slot.left or 0)
        state.inputState.top.text         = tostring(slot.top or 0)
        state.inputState.border.text      = tostring(slot.border or 0)
        state.inputState.duration.text    = tostring(slot.duration or 0.1)
        state.selectedFrames = parseFramesString(slot.frames)
    else
        state.selectedFrames = {}
    end
    logic.updateGrid()
end

function logic.loadCurrentAsset()
    local Factory = require('engine.core.factory')
    local id = state.inputState.entityType.text
    if id == "" then
        id = (state.targetMode == "tile") and "water" or "player"
        state.inputState.entityType.text = id
    end

    if state.targetMode == "tile" then
        local tDef = Factory.tiles[id]
        local imgPath = (tDef and tDef.texturePath) or ("content/tiles/" .. id .. ".png")
        if not loadImageFromPath(imgPath) then
            state.errorMessage = "Tile texture not found: " .. id
            return
        end
        state.bindings = {}
        state.savedSlots = {}
        if tDef and tDef.animation then
            local a = tDef.animation
            state.inputState.frameWidth.text  = tostring(a.frameW or 32)
            state.inputState.frameHeight.text = tostring(a.frameH or 32)
            state.inputState.left.text        = tostring(a.left or 0)
            state.inputState.top.text         = tostring(a.top or 0)
            state.inputState.border.text      = tostring(a.border or 0)
            state.inputState.duration.text    = tostring(a.duration or 0.2)
            state.tilePhase = a.phase or "sync"
            state.tileMode  = a.mode or "loop"
            state.selectedFrames = parseFramesString(a.frames)
        else
            state.selectedFrames = {}
        end
        logic.fitViewport()
        logic.updateGrid()
        logic.notify("Loaded tile: " .. id)
    else
        local basePath = "content/characters/" .. id
        local loaded = loadImageFromPath(basePath .. "/spritesheet.png")
            or loadImageFromPath(basePath .. "/" .. id .. ".png")
        if not loaded then
            state.errorMessage = "Character sheet not found: " .. id
            return
        end
        state.bindings = {}
        state.savedSlots = {}
        local animPath = basePath .. "/animations.lua"
        if love.filesystem.getInfo(animPath) then
            local ok, data = pcall(love.filesystem.load(animPath))
            if ok and type(data) == "table" and data.animations then
                state.bindings = data.animations
                for k in pairs(data.animations) do
                    state.savedSlots[k] = true
                end
            end
        end
        logic.fitViewport()
        logic.selectBindingSlot(state.selectedTemplate or "walk_down")
        logic.notify("Loaded character: " .. id)
    end
end

function logic.cycleAsset(dir)
    local Factory = require('engine.core.factory')
    local src = (state.targetMode == "tile") and Factory.tiles or Factory.characters
    local keys = {}
    for k in pairs(src or {}) do table.insert(keys, k) end
    if #keys == 0 then return end
    table.sort(keys)

    local cur = state.inputState.entityType.text
    local idx = 1
    for i, k in ipairs(keys) do
        if k == cur then idx = i; break end
    end
    local nxt = ((idx - 1 + dir) % #keys) + 1
    state.inputState.entityType.text = keys[nxt]
    logic.loadCurrentAsset()
end

function logic.applyCountGrid()
    if not state.image then return end
    local cols = math.max(1, math.floor(tonumber(state.inputState.cols.text) or 1))
    local rows = math.max(1, math.floor(tonumber(state.inputState.rows.text) or 1))
    local l = tonumber(state.inputState.left.text) or 0
    local t = tonumber(state.inputState.top.text) or 0
    local b = tonumber(state.inputState.border.text) or 0
    local imgW, imgH = state.image:getDimensions()

    local fw = math.max(1, math.floor((imgW - l) / cols) - b)
    local fh = math.max(1, math.floor((imgH - t) / rows) - b)
    state.inputState.frameWidth.text = tostring(fw)
    state.inputState.frameHeight.text = tostring(fh)
    logic.updateGrid()
end

function logic.autoDetectGrid()
    if not state.fileData or not state.image then return end
    local ok, imgData = pcall(love.image.newImageData, state.fileData)
    if not ok or not imgData then
        state.errorMessage = "Auto-detect failed."
        return
    end

    local w, h = imgData:getDimensions()
    local bgR, bgG, bgB, bgA = imgData:getPixel(0, 0)

    local function isEmpty(x, y)
        local r, g, b, a = imgData:getPixel(x, y)
        if a < 0.05 then return true end
        return math.abs(r - bgR) < 0.04 and math.abs(g - bgG) < 0.04 and math.abs(b - bgB) < 0.04 and math.abs(a - bgA) < 0.04
    end

    local function findSegments(len, checkLineEmpty)
        local segs = {}
        local inSeg = false
        local segStart = 0
        for i = 0, len - 1 do
            local empty = checkLineEmpty(i)
            if not empty and not inSeg then
                inSeg = true
                segStart = i
            elseif empty and inSeg then
                inSeg = false
                table.insert(segs, { start = segStart, stop = i - 1 })
            end
        end
        if inSeg then
            table.insert(segs, { start = segStart, stop = len - 1 })
        end
        return segs
    end

    local colSegs = findSegments(w, function(x)
        for y = 0, h - 1 do
            if not isEmpty(x, y) then return false end
        end
        return true
    end)

    local rowSegs = findSegments(h, function(y)
        for x = 0, w - 1 do
            if not isEmpty(x, y) then return false end
        end
        return true
    end)

    if #colSegs == 0 or #rowSegs == 0 then
        state.errorMessage = "No sprites detected."
        return
    end

    local cols = #colSegs
    local rows = #rowSegs
    state.inputState.cols.text = tostring(cols)
    state.inputState.rows.text = tostring(rows)
    state.inputState.left.text = "0"
    state.inputState.top.text = "0"
    state.inputState.border.text = "0"

    local fw = math.max(1, math.floor(w / cols))
    local fh = math.max(1, math.floor(h / rows))
    state.inputState.frameWidth.text = tostring(fw)
    state.inputState.frameHeight.text = tostring(fh)
    state.gridMode = "count"
    logic.updateGrid()
    logic.notify(string.format("Auto-detected %dx%d grid (%dx%dpx)", cols, rows, fw, fh))
end

function logic.fitViewport()
    if not state.image then return end
    local panelW = state.screenW - 640
    local iw, ih = state.image:getDimensions()
    local sc = math.min((panelW - 40) / iw, (state.screenH - 100) / ih)
    sc = math.max(0.25, math.min(16, sc))
    state.viewZoom = sc
    local centerX = 320 + panelW / 2
    local centerY = state.screenH / 2
    local baseX = centerX - 128
    local baseY = centerY - 128
    state.viewPanX = (centerX - (iw * sc) / 2) - baseX
    state.viewPanY = (centerY - (ih * sc) / 2) - baseY
end

function logic.updateGrid()
    if not state.image then return end
    local fw = tonumber(state.inputState.frameWidth.text) or 32
    local fh = tonumber(state.inputState.frameHeight.text) or 32
    local l = tonumber(state.inputState.left.text) or 0
    local t = tonumber(state.inputState.top.text) or 0
    local b = tonumber(state.inputState.border.text) or 0

    local imgW, imgH = state.image:getDimensions()
    state.grid = anim8.newGrid(fw, fh, imgW, imgH, l, t, b)

    logic.createAnimation()
end

function logic.createAnimation()
    if not state.image or not state.grid then return end
    state.errorMessage = ""

    if #state.selectedFrames == 0 then
        state.animation = nil
        state.generatedCode = ""
        state.generatedFrameData = nil
        return
    end

    local dur = tonumber(state.inputState.duration.text)
    if not dur or dur <= 0 then
        state.errorMessage = "Invalid duration."
        state.animation = nil
        return
    end

    local framesArr = {}
    local framesStrArgs = {}
    for _, f in ipairs(state.selectedFrames) do
        table.insert(framesArr, f.x)
        table.insert(framesArr, f.y)
        table.insert(framesStrArgs, string.format("%d,%d", f.x, f.y))
    end

    local framesSuccess, frames = pcall(function() return state.grid(unpack(framesArr)) end)
    if not framesSuccess then
        state.errorMessage = "Frames out of bounds."
        state.animation = nil
        return
    end

    local animSuccess, anim = pcall(function() return anim8.newAnimation(frames, dur) end)
    if not animSuccess then
        state.errorMessage = "Failed to create animation."
        state.animation = nil
        return
    end

    state.animation = anim

    -- Store frame data compactly for writing to unified manifest
    state.generatedFrameData = {
        frameW   = tonumber(state.inputState.frameWidth.text)  or 32,
        frameH   = tonumber(state.inputState.frameHeight.text) or 32,
        left     = tonumber(state.inputState.left.text)   or 0,
        top      = tonumber(state.inputState.top.text)    or 0,
        border   = tonumber(state.inputState.border.text) or 0,
        frames   = table.concat(framesStrArgs, ", "),
        duration = dur,
    }

    local imgName = "spritesheet" .. (state.fileExt or ".png")
    state.generatedCode = string.format([[
local anim8 = require 'lib.anim8.anim8'
local image = love.graphics.newImage('%s')

local g = anim8.newGrid(%d, %d, image:getWidth(), image:getHeight(), %d, %d, %d)

local anim = anim8.newAnimation(g(%s), %s)
]],
        imgName,
        state.generatedFrameData.frameW,
        state.generatedFrameData.frameH,
        state.generatedFrameData.left,
        state.generatedFrameData.top,
        state.generatedFrameData.border,
        table.concat(framesStrArgs, ", "),
        state.inputState.duration.text
    )
end

function logic.handleFileDropped(file)
    local ext = file:getFilename():match("^.+(%..+)$")
    if ext then ext = ext:lower() end
    if ext == ".png" or ext == ".jpg" or ext == ".jpeg" then
        file:open("r")
        state.fileData = file:read("data")
        state.fileExt = ext
        state.image = love.graphics.newImage(state.fileData)

        state.animation = nil
        state.generatedCode = ""
        state.generatedFrameData = nil
        state.errorMessage = ""
        state.selectedFrames = {}
        logic.fitViewport()
        logic.updateGrid()
        logic.notify("Loaded " .. file:getFilename())
    end
end

-- ── Shared: write the unified animations.lua manifest to disk ────────────
local function writeManifest(exportDir, entity, allSlots)
    local lines = {
        "-- content/characters/" .. entity .. "/animations.lua",
        "-- Auto-generated by Anim8tor. Do not hand-edit individual anim files.",
        "",
        "return {",
        "    spritesheet = \"content/characters/" .. entity .. "/spritesheet.png\",",
        "",
        "    animations = {",
    }
    for name, def in pairs(allSlots) do
        table.insert(lines, string.format(
            "        %-12s= { frameW=%d, frameH=%d, left=%d, top=%d, border=%d, frames=\"%s\", duration=%s },",
            name .. " ",
            def.frameW, def.frameH, def.left, def.top, def.border,
            def.frames, tostring(def.duration)
        ))
    end
    table.insert(lines, "    },")
    table.insert(lines, "}")
    local content = table.concat(lines, "\n")

    local path = exportDir .. "/animations.lua"
    local f, err = io.open(path, "w")
    if not f then return false, err end
    f:write(content)
    f:close()
    return true
end

-- ── Load the current manifest from disk (or return empty table) ───────────
local function readManifestSlots(exportDir)
    local path = exportDir .. "/animations.lua"
    local chunk, _ = loadfile(path)
    if not chunk then return {} end
    local ok, data = pcall(chunk)
    if not ok or type(data) ~= "table" then return {} end
    return data.animations or {}
end

function logic.saveToDisk()
    logic.bindAndSave()
end

local function bindTileAndSave()
    local tileId = state.inputState.entityType.text
    if tileId == "" then tileId = "water" end

    local baseDir = love.filesystem.getSource()
    local tilesDir = baseDir .. "/content/tiles"
    local texRel = "content/tiles/" .. tileId .. ".png"

    if state.fileData then
        local fImg = io.open(tilesDir .. "/" .. tileId .. ".png", "wb")
        if fImg then
            fImg:write(state.fileData:getString())
            fImg:close()
        end
    end

    local tilePath = tilesDir .. "/" .. tileId .. ".lua"
    local tileDef = nil
    local chunk = loadfile(tilePath)
    if chunk then
        local ok, data = pcall(chunk)
        if ok and type(data) == "table" then tileDef = data end
    end
    tileDef = tileDef or {
        id = tileId,
        name = tileId:gsub("^%l", string.upper),
        colorKey = tileId,
        draw_style = "fill",
        flags = {}
    }
    tileDef.id = tileId
    tileDef.texturePath = texRel

    local anim = state.generatedFrameData
    local lines = {
        "-- content/tiles/" .. tileId .. ".lua",
        "",
        "return {",
        string.format("    id = %q,", tileDef.id),
        string.format("    name = %q,", tileDef.name or tileId),
        string.format("    colorKey = %q,", tileDef.colorKey or tileId),
        string.format("    draw_style = %q,", tileDef.draw_style or "fill"),
        string.format("    texturePath = %q,", tileDef.texturePath),
        string.format(
            "    animation = { frameW=%d, frameH=%d, left=%d, top=%d, border=%d, frames=%q, duration=%s, phase=%q, mode=%q },",
            anim.frameW, anim.frameH, anim.left, anim.top, anim.border, anim.frames, tostring(anim.duration),
            state.tilePhase or "sync", state.tileMode or "loop"
        ),
        "    flags = {"
    }
    if tileDef.flags then
        for k, v in pairs(tileDef.flags) do
            if type(v) == "string" then
                table.insert(lines, string.format("        %s = %q,", k, v))
            elseif type(v) == "boolean" or type(v) == "number" then
                table.insert(lines, string.format("        %s = %s,", k, tostring(v)))
            end
        end
    end
    table.insert(lines, "    }")
    table.insert(lines, "}")

    local f, err = io.open(tilePath, "w")
    if not f then
        state.errorMessage = "Failed to write tile: " .. tostring(err)
        return
    end
    f:write(table.concat(lines, "\n"))
    f:close()

    state.errorMessage = ""
    local Factory = require('engine.core.factory')
    local Context = require('engine.core.context')
    Factory.load()
    Context.mapDirty = true

    logic.notify("Saved tile -> content/tiles/" .. tileId .. ".lua")
end

function logic.bindAndSave()
    if not state.generatedFrameData or not state.image then
        state.errorMessage = "Select frames first!"
        return
    end

    if state.targetMode == "tile" then
        bindTileAndSave()
        return
    end

    local entity   = state.inputState.entityType.text
    local template = state.selectedTemplate
    if entity == "" then entity = "player" end
    if template == "" then template = "walk_down" end

    state.inputState.exportName.text = template

    local baseDir   = love.filesystem.getSource()
    local exportDir = baseDir .. "/content/characters/" .. entity
    os.execute('mkdir "' .. exportDir:gsub("/", "\\") .. '" 2>nul')
    os.execute('mkdir -p "' .. exportDir .. '" 2>/dev/null')

    if state.fileData then
        local f2 = io.open(exportDir .. "/spritesheet.png", "wb")
        if f2 then
            f2:write(state.fileData:getString())
            f2:close()
        end
    end

    local slots = readManifestSlots(exportDir)
    slots[template] = state.generatedFrameData

    local ok, err = writeManifest(exportDir, entity, slots)
    if not ok then
        state.errorMessage = "Failed to write manifest: " .. tostring(err)
        return
    end

    state.savedSlots[template] = true
    state.errorMessage = ""

    local AnimationManager = require('engine.core.animation')
    AnimationManager.invalidate(entity)

    logic.notify("Bound [" .. template .. "] -> " .. entity .. "/animations.lua")
end

function logic.exportBindings()
    if state.generatedCode ~= "" and state.errorMessage == "" then
        love.system.setClipboardText(state.generatedCode)
        logic.notify("Copied anim8 snippet to clipboard!")
        return
    end

    local entity = state.inputState.entityType.text
    if entity == "" then entity = "player" end

    if not next(state.savedSlots) then
        state.errorMessage = "Nothing bound yet! Select frames first."
        return
    end

    logic.notify("Slots saved in animations.lua for: " .. entity)
    state.errorMessage = ""
end

return logic
