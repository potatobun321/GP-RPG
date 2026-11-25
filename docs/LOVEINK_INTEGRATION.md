# LoveInk Integration

## Introduction
LoveInk has been integrated as the **Narrative Execution Layer**. It provides a pure Lua state machine for branching dialogue without the overhead of JSON parsing.

## The StoryManager
`engine/narrative/story_manager.lua` is the definitive entry point for invoking narrative.

```lua
local StoryManager = require('engine.narrative.story_manager')

-- Launch a story from an asset
StoryManager.startStory("signs/warning_sign")

-- Launch a dynamic single-line story (Legacy fallback)
StoryManager.startInteraction("Beware the forest.")
```

## The Adapter Layer
To ensure LoveInk variables mutate global game state, `engine/narrative/loveink_adapter.lua` intercepts LoveInk's variable sandbox.
```lua
dialogue.getVariable = function(self, name) return Flags.get(name) end
dialogue.setVariable = function(self, name, val) Flags.set(name, val) end
```

## Event Flow
When LoveInk encounters a `text()` node with attached `tags`, the `StoryManager` delegates those tags to `engine/narrative/narrative_events.lua`.

Example Authoring:
```lua
text("The earth splits!", "Narrator", {"camera_shake"})
```
The GP-RPG engine will intercept `"camera_shake"` and dispatch the appropriate visual effect.
