LWN = LWN or {}

function LWN.init()
    if LWN._bootstrapped then return end
    LWN._bootstrapped = true

    LWN.PopulationStore.root()
    LWN.EventAdapter.bind()
end

LWN.init()
