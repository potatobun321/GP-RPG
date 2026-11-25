return {
    InteractiveNPC = {
        Flags = { is_solid = true, is_interactable = true, is_hoverable = true },
        Attributes = { story_id = "intro" },
        Reactions = {
            TriggerOnClick = { "PlayLoveInk", "ReplaceComposite_SpentNPC" }
        }
    },
    SpentNPC = {
        Flags = { is_solid = true },
        Attributes = {},
        Reactions = {}
    }
}
