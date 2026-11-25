return {
    PlayLoveInk = {
        description = "Starts a LoveInk story narrative.",
        consumes = {"story_id"},
        system = "StorySystem"
    },
    ReplaceComposite = {
        description = "Mutates an entity into a new vocabulary bundle.",
        consumes = {},
        system = "TokenSystem"
    },
    TriggerOnInteract = {
        description = "Fired when the player presses the interact key near the entity.",
        consumes = {},
        system = "InteractionSystem"
    },
    TriggerOnHoverEnter = {
        description = "Fired exactly once when the mouse enters the entity bounds.",
        consumes = {},
        system = "HoverSystem"
    },
    TriggerOnHoverExit = {
        description = "Fired exactly once when the mouse leaves the entity bounds.",
        consumes = {},
        system = "HoverSystem"
    },
    TriggerOnClick = {
        description = "Fired when the entity is left-clicked while hovered.",
        consumes = {},
        system = "InputSystem"
    }
}
