# Generation 7 Language Evolution Log

This document serves as the historical record of how the gameplay language evolves.

---

### Discovery: PlayLoveInk
*   **Source:** Interactive NPC Prototype
*   **Problem Encountered:** The legacy `DialogueStart` token printed a raw string to the screen and failed to properly bridge into the LoveInk narrative state machine.
*   **Vocabulary Introduced:** `PlayLoveInk` (Token)
*   **Why It Was Needed:** Required a formal Token to map execution to `StoryManager.startStory` using a defined `story_id`.
*   **Validation Status:** Validated and Active.

### Discovery: Mouse Hover & Click Logic
*   **Source:** Usability Friction
*   **Problem Encountered:** The hardcoded `math.abs` distance check for the 'E' keypress felt clunky and conflicted with legacy Tilemap interactions.
*   **Vocabulary Introduced:** `TriggerOnHoverEnter`, `TriggerOnHoverExit`, `TriggerOnClick` (Tokens), `is_hoverable` (Flag).
*   **Why It Was Needed:** Replaced ambiguous keyboard distance logic with exact AABB screen-to-world intersections.
*   **Validation Status:** Validated and Active.

### Discovery: ReplaceComposite
*   **Source:** One-Time Interaction Requirement
*   **Problem Encountered:** Needed an NPC to only be interactable once, but didn't want to pollute core systems with boolean checks (e.g., `if not npc.spoken_to`).
*   **Vocabulary Introduced:** `ReplaceComposite` (Mutation Token)
*   **Why It Was Needed:** Proved that gameplay state can advance simply by overwriting an entity's vocabulary bundle, causing it to "forget" how to interact.
*   **Validation Status:** Validated and Active.
