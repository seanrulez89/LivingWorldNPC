LWN = LWN or {}
LWN.Legacy = LWN.Legacy or {}

local Legacy = LWN.Legacy

function Legacy.collectCandidates()
    local out = {}
    LWN.PopulationStore.eachNPC(function(record)
        if LWN.PopulationStore.isAlive(record)
            and record.companion.recruited
            and record.relationshipToPlayer.trust >= LWN.Config.Legacy.MinTrust
        then
            table.insert(out, LWN.Schema.newLegacySnapshot(record))
        end
    end)
    return out
end

function Legacy.showDeathModal(player)
    local candidates = Legacy.collectCandidates()

    local modal = ModalDialog.new(
        LWN.Loc.text("LWN_Legacy_Title"),
        LWN.Loc.text("LWN_Legacy_Text"),
        true
    )
    UIManager.AddUI(modal)

    -- A full picker window is left as TODO. For the skeleton, auto-pick the first candidate if the player accepts.
    modal.Clicked = function(self, buttonName)
        if buttonName == "Yes" and candidates[1] then
            LWN.PopulationStore.setPendingLegacy(candidates[1])
        end
    end
end
