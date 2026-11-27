-- engine/state/attribute_manager.lua
-- Responsibility: Manage scalar attributes (Health, Reputation, etc) attached to entities or the world.

local AttributeManager = {
    attributes = {}
}

function AttributeManager.set(entity, key, value)
    if not AttributeManager.attributes[entity] then
        AttributeManager.attributes[entity] = {}
    end
    AttributeManager.attributes[entity][key] = value
end

function AttributeManager.get(entity, key)
    if AttributeManager.attributes[entity] then
        return AttributeManager.attributes[entity][key]
    end
    return nil
end

function AttributeManager.clear()
    AttributeManager.attributes = {}
end

function AttributeManager.serialize()
    local copy = {}
    for entity, attrs in pairs(AttributeManager.attributes) do
        if type(attrs) == "table" then
            copy[entity] = {}
            for k, v in pairs(attrs) do
                local t = type(v)
                if t == "boolean" or t == "number" or t == "string" then
                    copy[entity][k] = v
                end
            end
        end
    end
    return copy
end

function AttributeManager.deserialize(data)
    AttributeManager.attributes = {}
    if type(data) ~= "table" then return end
    for entity, attrs in pairs(data) do
        if type(attrs) == "table" then
            AttributeManager.attributes[entity] = {}
            for k, v in pairs(attrs) do
                local t = type(v)
                if t == "boolean" or t == "number" or t == "string" then
                    AttributeManager.attributes[entity][k] = v
                end
            end
        end
    end
end

return AttributeManager
