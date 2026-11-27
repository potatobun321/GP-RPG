-- engine/core/layer_stack.lua
-- Ordered modal/input layer router for scenes.
-- Layers are registered from highest priority (top) to lowest (bottom).

local LayerStack = {}
LayerStack.__index = LayerStack

function LayerStack.new()
    return setmetatable({ layers = {} }, LayerStack)
end

function LayerStack:push(layer)
    table.insert(self.layers, layer)
end

function LayerStack:clear()
    self.layers = {}
end

function LayerStack:dispatch(method, ...)
    for _, layer in ipairs(self.layers) do
        local active = (not layer.isActive) or layer.isActive()
        if active then
            local fn = layer[method]
            if fn then
                local consumed = fn(...)
                if consumed then return true end
            end
            if layer.blocksInput and layer.blocksInput() then
                return true
            end
        end
    end
    return false
end

function LayerStack:update(dt)
    for _, layer in ipairs(self.layers) do
        local active = (not layer.isActive) or layer.isActive()
        if active then
            if layer.update then
                layer.update(dt)
            end
            if layer.blocksUpdate and layer.blocksUpdate() then
                return
            end
        end
    end
end

function LayerStack:draw()
    -- Draw bottom-to-top so top modals render last
    for i = #self.layers, 1, -1 do
        local layer = self.layers[i]
        local active = (not layer.isActive) or layer.isActive()
        if active and layer.draw then
            layer.draw()
        end
    end
end

return LayerStack
