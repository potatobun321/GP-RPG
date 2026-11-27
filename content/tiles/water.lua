-- content/tiles/water.lua

return {
    id = "water",
    name = "Water",
    colorKey = "water",
    draw_style = "fill",
    texturePath = "content/tiles/water.png",
    animation = { frameW=32, frameH=32, left=0, top=0, border=0, frames="1,1, 1,1, 1,1, 1,1, 1,1, 1,1", duration=0.1, phase="noise", mode="pingpong" },
    flags = {
        speedMod = 0.6,
        interactable = true,
        interactMessage = "Clear, fresh water.",
    }
}