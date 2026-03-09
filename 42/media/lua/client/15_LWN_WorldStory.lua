LWN = LWN or {}
LWN.WorldStory = LWN.WorldStory or {}

local Story = LWN.WorldStory
local Store = LWN.PopulationStore

function Story.seed()
    local root = Store.root()
    if root.worldStory.seeded then return end

    root.worldStory.seeded = true
    root.worldStory.pendingEvents = root.worldStory.pendingEvents or {}
    table.insert(root.worldStory.pendingEvents, {
        kind = "world_seeded",
        day = getGameTime() and getGameTime():getWorldAgeHours() / 24 or 0,
    })
end

function Story.tickNPC(record)
    if record.storyArc.type == "vice_decline" and record.vice.drinker then
        record.stats.stress = math.min(1.0, record.stats.stress + 0.01)
    elseif record.storyArc.type == "find_relative" then
        record.storyArc.phase = math.min(3, record.storyArc.phase + 0.01)
    end
end

function Story.maybeCreateClue(record)
    if record.storyArc.type == "find_relative" and record.storyArc.clueCount < 1 then
        record.storyArc.clueCount = 1
        return {
            kind = "clue",
            npcId = record.id,
            text = string.format("%s is looking for family.", record.identity.firstName),
            x = record.anchor.x,
            y = record.anchor.y,
            z = record.anchor.z,
        }
    end
    return nil
end
