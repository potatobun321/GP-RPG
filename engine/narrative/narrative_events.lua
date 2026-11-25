-- engine/narrative/narrative_events.lua
-- Responsibility: Intercept LoveInk tags and dispatch them to the global event bus or log them.

local Console = require('engine.core.console')

local NarrativeEvents = {}

function NarrativeEvents.fire(tag)
    -- In the future, this will hook into Event.fire(tag) for camera, audio, etc.
    -- For now, we simply log to the console to verify the pipeline.
    Console.log("Narrative Event Fired: " .. tostring(tag), {0, 1, 1})
end

return NarrativeEvents
