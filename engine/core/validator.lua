local Validator = {}

function Validator.validate(presetName, preset)
    if not preset.Tokens then
        error("Validation Error: Preset '" .. presetName .. "' must define a 'Tokens' dictionary.")
    end
    
    if not preset.Composites then return true end
    
    for compName, compData in pairs(preset.Composites) do
        if compData.Reactions then
            for triggerToken, reactions in pairs(compData.Reactions) do
                for _, reactionToken in ipairs(reactions) do
                    local tName = reactionToken
                    -- Special case for parameter-based mutation tokens
                    if string.sub(reactionToken, 1, 17) == "ReplaceComposite_" then
                        tName = "ReplaceComposite"
                    end
                    
                    local tokenDef = preset.Tokens[tName]
                    if not tokenDef then
                        error("Validation Error: Composite '" .. compName .. "' references undefined token '" .. tName .. "'.")
                    end
                    
                    if tokenDef.consumes then
                        for _, reqAttr in ipairs(tokenDef.consumes) do
                            if not compData.Attributes or compData.Attributes[reqAttr] == nil then
                                error("Validation Error: Composite '" .. compName .. "' uses token '" .. tName .. "' but is missing required attribute '" .. reqAttr .. "'.")
                            end
                        end
                    end
                end
            end
        end
    end
    
    return true
end

return Validator
