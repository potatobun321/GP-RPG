# GP-RPG Deep Context Transfer

## The Philosophy
GP-RPG is an engine where games are built primarily out of data and vocabulary, rather than rigid system code.

## Generation 7 Shifts

*   **Preset-Owned Vocabulary:** The core engine does not dictate what a game is. Vocabulary definitions (Tokens, Composites, Flags) are owned entirely by the `Presets` (e.g., `CoreRPG_MVP`).
*   **Generic Validation:** The engine acts as a Grammar Checker via the `Validator`, enforcing that Presets define required attributes for their Tokens, without the engine needing to know what the Tokens actually mean.
*   **Vocabulary Mutation:** Gameplay state changes (like an NPC being spoken to) are executed by literally swapping an entity's vocabulary (`ReplaceComposite`) rather than writing hardcoded boolean checks.
*   **Console Reflection:** The Console is not just a debugger; it is a Language Explorer (`token.inspect`, `composite.inspect`) that dynamically reads vocabulary from the active Preset.
*   **Language Discovery Through Friction:** New vocabulary isn't designed in theory—it is discovered when implementations face friction (e.g., `TriggerOnHoverEnter` was born from the friction of keyboard-only interaction).
