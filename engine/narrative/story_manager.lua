-- engine/narrative/story_manager.lua
-- Responsibility: Master narrative execution layer. Manages LoveInk instance, UI, and event dispatch.

local Dialogue = require('tools.LoveInk.dialogue')
local DialogueUI = require('tools.LoveInk.dialogue_ui')
local LoveInkAdapter = require('engine.narrative.loveink_adapter')
local NarrativeEvents = require('engine.narrative.narrative_events')

local Theme = require('engine.core.theme')

local StoryManager = {
    activeDialogue = nil,
    ui = nil,
    currentContent = nil
}

function StoryManager.init()
    local colors = Theme.get()
    
    local ok1, f1 = pcall(love.graphics.newFont, "fonts/PressStart2P.ttf", 10)
    local ok2, f2 = pcall(love.graphics.newFont, "fonts/PressStart2P.ttf", 8)
    local textboxFont = ok1 and f1 or love.graphics.getFont()
    local choiceFont  = ok2 and f2 or love.graphics.getFont()

    StoryManager.ui = DialogueUI.new({
        textbox = {
            x = 20,
            y = love.graphics.getHeight() - 140,
            width = love.graphics.getWidth() - 40,
            height = 120,
            typewriter_speed = 30,
            font = textboxFont,
            colors = {
                background = {colors.console_bg[1], colors.console_bg[2], colors.console_bg[3], 0.9},
                border = colors.player,
                text = colors.text,
                speaker_bg = colors.wall,
                speaker_text = colors.player
            }
        },
        choicelist = {
            x = 50,
            y = love.graphics.getHeight() - 250,
            width = love.graphics.getWidth() - 100,
            button_height = 30,
            font = choiceFont,
            colors = {
                normal = {colors.console_bg[1], colors.console_bg[2], colors.console_bg[3], 0.9},
                hover = {colors.wall[1], colors.wall[2], colors.wall[3], 1.0},
                border = colors.player,
                text = colors.text,
                text_hover = colors.player
            }
        }
    })
    
    StoryManager.ui.on_choice_made = function(index)
        StoryManager.currentContent = StoryManager.activeDialogue:choose(index)
        StoryManager.processTags(StoryManager.currentContent)
        StoryManager.ui:showContent(StoryManager.currentContent)
    end
end

function StoryManager.resize(w, h)
    if not StoryManager.ui then return end
    w = w or love.graphics.getWidth()
    h = h or love.graphics.getHeight()
    local tb = StoryManager.ui.textbox
    if tb then
        tb.x = 20
        tb.y = h - 140
        tb.width = w - 40
    end
    local cl = StoryManager.ui.choicelist
    if cl then
        cl.x = 50
        cl.y = h - 250
        cl.width = w - 100
    end
end

function StoryManager.startStory(storyPathOrData, startKnot)
    local storyData
    if type(storyPathOrData) == "string" then
        -- Future implementation: Load from content/stories/
        local chunk = love.filesystem.load("content/stories/" .. storyPathOrData .. ".lua")
        if chunk then
            storyData = chunk()
        else
            error("Could not load story: " .. storyPathOrData)
        end
    else
        storyData = storyPathOrData
    end

    StoryManager.activeDialogue = Dialogue.new(storyData, startKnot or "start")
    
    -- Attach GP-RPG State
    LoveInkAdapter.attach(StoryManager.activeDialogue)
    
    StoryManager.resize(love.graphics.getDimensions())
    StoryManager.currentContent = StoryManager.activeDialogue:getNext()
    StoryManager.processTags(StoryManager.currentContent)
    StoryManager.ui:showContent(StoryManager.currentContent)
end

function StoryManager.startInteraction(textMessage)
    -- Legacy Compatibility: Converts a plain string into a LoveInk story node.
    local helpers = require('tools.LoveInk.story_helpers')
    local story = {
        start = {
            helpers.text(textMessage)
        }
    }
    StoryManager.startStory(story, "start")
end

function StoryManager.processTags(content)
    if not content or not content.tags then return end
    for _, tag in ipairs(content.tags) do
        NarrativeEvents.fire(tag)
    end
end

function StoryManager.update(dt)
    if not StoryManager.activeDialogue then return end
    StoryManager.ui:update(dt)
end

function StoryManager.draw()
    if not StoryManager.activeDialogue then return end
    love.graphics.push("all")
    StoryManager.ui:draw()
    love.graphics.pop()
end

function StoryManager.mousepressed(x, y, button)
    if not StoryManager.activeDialogue then return false end
    
    if button == 1 then
        if StoryManager.ui:mousepressed(x, y, button) then return true end
        
        if StoryManager.currentContent and StoryManager.currentContent.type == "text" then
            if StoryManager.ui:isTextComplete() then
                StoryManager.resize(love.graphics.getDimensions())
    StoryManager.currentContent = StoryManager.activeDialogue:getNext()
                if StoryManager.currentContent and StoryManager.currentContent.type == "end" then
                    StoryManager.activeDialogue = nil
                    StoryManager.currentContent = nil
                else
                    StoryManager.processTags(StoryManager.currentContent)
                    StoryManager.ui:showContent(StoryManager.currentContent)
                end
            else
                StoryManager.ui:skipTypewriter()
            end
        end
        return true
    end
    return false
end

function StoryManager.keypressed(key)
    if not StoryManager.activeDialogue then return false end

    if key == "e" or key == "space" or key == "return" then
        if StoryManager.currentContent and StoryManager.currentContent.type == "text" then
            if StoryManager.ui:isTextComplete() then
                StoryManager.resize(love.graphics.getDimensions())
    StoryManager.currentContent = StoryManager.activeDialogue:getNext()
                if StoryManager.currentContent and StoryManager.currentContent.type == "end" then
                    StoryManager.activeDialogue = nil
                    StoryManager.currentContent = nil
                else
                    StoryManager.processTags(StoryManager.currentContent)
                    StoryManager.ui:showContent(StoryManager.currentContent)
                end
            else
                StoryManager.ui:skipTypewriter()
            end
        end
        return true
    end
    return false
end

function StoryManager.isActive()
    return StoryManager.activeDialogue ~= nil
end

return StoryManager
