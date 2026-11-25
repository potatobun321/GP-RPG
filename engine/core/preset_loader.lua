local PresetLoader = {
    activePresetName = nil,
    activePreset = nil
}
PresetLoader.activeComposites = {}

function PresetLoader.load(presetName)
    local Console = require('engine.core.console')
    local Validator = require('engine.core.validator')
    
    local presetData = require("content.presets." .. presetName .. ".preset")
    
    if Validator.validate(presetName, presetData) then
        PresetLoader.activePresetName = presetName
        PresetLoader.activePreset = presetData
        
        if presetData.Composites then
            for name, comp in pairs(presetData.Composites) do
                PresetLoader.activeComposites[name] = comp
            end
        end
        
        Console.log("Loaded and Validated Preset: " .. presetName, {0.2, 0.8, 0.2})
    end
end

function PresetLoader.getComposite(name)
    return PresetLoader.activeComposites[name]
end

return PresetLoader
