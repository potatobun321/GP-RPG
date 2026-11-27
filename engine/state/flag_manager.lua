-- engine/state/flag_manager.lua
-- Responsibility: Manage global boolean, string, and number state flags.

local FlagManager = {
    flags = {}
}

function FlagManager.set(name, value)
    FlagManager.flags[name] = value
end

function FlagManager.get(name)
    return FlagManager.flags[name]
end

function FlagManager.toggle(name)
    if type(FlagManager.flags[name]) == "boolean" then
        FlagManager.flags[name] = not FlagManager.flags[name]
    elseif FlagManager.flags[name] == nil then
        FlagManager.flags[name] = true
    end
    return FlagManager.flags[name]
end

function FlagManager.exists(name)
    return FlagManager.flags[name] ~= nil
end

function FlagManager.list()
    return FlagManager.flags
end

function FlagManager.clear()
    FlagManager.flags = {}
end

function FlagManager.serialize()
    local copy = {}
    for k, v in pairs(FlagManager.flags) do
        local t = type(v)
        if t == "boolean" or t == "number" or t == "string" then
            copy[k] = v
        end
    end
    return copy
end

function FlagManager.deserialize(data)
    FlagManager.flags = {}
    if type(data) ~= "table" then return end
    for k, v in pairs(data) do
        local t = type(v)
        if t == "boolean" or t == "number" or t == "string" then
            FlagManager.flags[k] = v
        end
    end
end

return FlagManager
