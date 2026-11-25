# Global Flag System

## Overview
The Flag System (`engine/state/flag_manager.lua`) is the absolute source of truth for boolean, string, and numeric game state in GP-RPG.

## API
```lua
local Flags = require('engine.state.flag_manager')

Flags.set("has_sword", true)
Flags.get("has_sword")           -- Returns true
Flags.toggle("door_open")        -- Flips true/false
Flags.exists("met_blacksmith")   -- Returns boolean
Flags.list()                     -- Returns table of all flags
```

## Console Commands
Flags can be inspected and manipulated live during gameplay via the developer console (~) using the `flag.` namespace:

* `flag.list` - Prints all active flags to the console.
* `flag.get <name>` - Prints the current value of the flag.
* `flag.set <name> <value>` - Mutates the flag. (e.g. `flag.set has_sword true`)
* `flag.toggle <name>` - Toggles a boolean flag.

## Future Expansions
The Flag system is designed to eventually support full JSON serialization via `Flags.serialize()` and `Flags.deserialize()`, feeding directly into the future Save System.
