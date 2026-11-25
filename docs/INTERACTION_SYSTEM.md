# Interaction System

## Overview
The Interaction System governs what happens when a player presses `E` while facing a tile or entity.

## Legacy Compatibility Flow
Previously, interacting with a signpost simply printed a message to the developer console. To ensure legacy maps do not break, this flow has been bridged into the narrative system:

```text
E Key Pressed
↓
Detect Tile & Read `tdata.flags.interactMessage`
↓
StoryManager dynamically generates a single-node LoveInk story.
↓
LoveInk UI renders the dialogue box.
```

## Future Flow
The future of interactions involves explicitly defining story paths within the tile or NPC attributes, rather than hardcoding dialogue strings into maps:

```text
E Key Pressed
↓
Detect Entity `story_id = "npcs/blacksmith_intro"`
↓
StoryManager loads `content/stories/npcs/blacksmith_intro.lua`
↓
LoveInk parses the branching narrative.
```
