return {
    Transform = function(x, y, w, h, z) return {x=x, y=y, w=w, h=h, z=z or 0} end,
    Velocity = function(dx, dy, speed) return {dx=dx or 0, dy=dy or 0, baseSpeed=speed or 100, currentSpeed=speed or 100, facing="down"} end,
    Renderable = function(type, colorKey, texture, draw_style) return {type=type, colorKey=colorKey, texture=texture, draw_style=draw_style or "fill"} end,
    PlayerInput = function() return {} end,
    Health = function(hp, maxHp) return {current = hp or 100, max = maxHp or 100, immunityTimer = 0} end,
    CharacterStats = function(template) return {stats = template} end,
    TileData = function(data) return data end,
    Animator = function(animations, current) return {animations = animations or {}, current = current or "default"} end,
    Persistent = function() return {} end,
    State = function(initial) return {current = initial or "idle"} end,
    Collider = function(w, h, ox, oy) return {w=w, h=h, ox=ox or 0, oy=oy or 0} end,

    -- Gen 7 Vocabulary Components
    Flags = function(flagsTable) return flagsTable or {} end,
    Attributes = function(attrTable) return attrTable or {} end,
    TokenQueue = function() return {} end,
    ActiveComposite = function(compositeId) return {id = compositeId} end,
    Reactions = function(reactionsTable) return reactionsTable or {} end
}
