-- engine/narrative/loveink_adapter.lua
-- Responsibility: Safely override LoveInk's internal variable sandbox to map directly to GP-RPG's state managers.

local FlagManager = require('engine.state.flag_manager')
-- local AttributeManager = require('engine.state.attribute_manager')

local LoveInkAdapter = {}

function LoveInkAdapter.attach(dialogueInstance)
    if not dialogueInstance then return end

    -- Override the getter
    dialogueInstance.getVariable = function(self, name)
        return FlagManager.get(name)
    end

    -- Override the setter
    dialogueInstance.setVariable = function(self, name, value)
        FlagManager.set(name, value)
    end
end

return LoveInkAdapter
