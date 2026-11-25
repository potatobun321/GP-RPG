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

-- Future expansion: serialize() and deserialize(data)
return AttributeManager
