local state = {
    image = nil,
    fileData = nil,
    fileExt = ".png",
    grid = nil,
    animation = nil,

    font = nil,
    fontSmall = nil,

    screenW = 0,
    screenH = 0,

    viewZoom = 1,
    viewPanX = 0,
    viewPanY = 0,
    isPanning = false,

    playing = true,
    flipH = false,
    gridMode = "pixels", -- "pixels" or "count"

    toastText = "",
    toastTimer = 0,

    generatedCode = "",
    errorMessage = "",

    selectedFrames = {},

    selectedTemplate = "walk_down",
    targetMode = "character", -- "character" or "tile"
    tilePhase = "sync",       -- "sync", "noise", or "random"
    tileMode = "loop",        -- "loop" or "pingpong"
    savedSlots = {},
    bindings = {},

    hitboxEditMode = "view", -- "view", "box", or "radius"
    showHitboxPreview = true,
    collider = nil,          -- { ox, oy, w, h, baseW, baseH }
    radius = nil,            -- { ox, oy, r, baseW, baseH }
    previewDrag = nil,

    inputState = {
        frameWidth = {text = "64"},
        frameHeight = {text = "64"},
        cols = {text = "3"},
        rows = {text = "4"},
        left = {text = "0"},
        top = {text = "0"},
        border = {text = "0"},
        duration = {text = "0.1"},
        entityType = {text = "player"},
        exportName = {text = "walk_down"}
    }
}

return state
