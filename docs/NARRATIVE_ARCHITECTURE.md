# Narrative Architecture

## Overview
GP-RPG utilizes an adapter-based narrative architecture where gameplay systems retain full ownership over game state, while the narrative engine orchestrates story presentation and logic evaluation.

## The Stack
The architecture flows from the engine core through a protective adapter layer down into the narrative runtime:

```text
GP-RPG (Engine & State)
   ↓
StoryManager (Orchestrator)
   ↓
LoveInkAdapter (Variable Translation)
   ↓
LoveInk (Dialogue Runtime & State Machine)
   ↓
NarrativeEvents (Tag Dispatcher)
```

## Philosophy
1. **GP-RPG owns the state.** LoveInk must never own permanent world variables.
2. **LoveInk drives the narrative.** LoveInk evaluates GP-RPG's state to determine branching dialogue.
3. **StoryManager handles input.** During dialogue, `StoryManager` blocks normal player movement and assumes control of input and UI rendering.
4. **Tags are Events.** Narrative side-effects (camera shakes, sfx) are emitted as string tags and processed by the engine asynchronously.
