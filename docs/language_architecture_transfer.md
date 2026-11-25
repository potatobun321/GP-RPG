# GP-RPG Language Architecture Transfer

## Generation 7 Core Architecture

### Token Contracts
Every Token is a contract. It declares what it means, what System consumes it, and what Attributes it requires (`consumes` list). 

### Preset Dictionaries
Vocabulary dictionaries live exclusively within Presets (`content/presets/PresetName/tokens.lua`). The core engine possesses no master list of tokens.

### Validation Philosophy
The `PresetLoader` passes all presets to the `Validator`. Validation guarantees that if an entity possesses a `Reaction` mapping to a Token, the entity *must* possess the `Attributes` the Token declared in its contract.

### Composite Mutation
The primary method of advancing gameplay state is through Composite Mutation (`ReplaceComposite`, `AddComposite`, `RemoveComposite`). We change what an entity *is*, rather than checking flags in the update loop.

### Grammar vs Gameplay Distinction
The Engine handles the Grammar (Validating contracts, pushing intent arrays). The Systems handle the Gameplay (Executing the intent). This enforces strict decoupling.
