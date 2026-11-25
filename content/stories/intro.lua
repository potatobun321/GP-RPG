local helpers = require('tools.LoveInk.story_helpers')

return {
    start = {
        helpers.text("Hello there! I am the MVP NPC!", {speaker="NPC"}),
        helpers.text("This is a test of the Generation 7 Vocabulary Mutation.", {speaker="NPC"}),
        { type = "end" }
    }
}
