LWN = LWN or {}
LWN.BanditsIntegration = LWN.BanditsIntegration or {}

local Integration = LWN.BanditsIntegration

Integration.ProgramName = "LWNControlled"
Integration.ClanId = "ae5e5d56-d82f-43a3-b1bb-28614544b343"
Integration.ProfileId = "381888f8-af27-45b6-aa90-f56d22299753"

local function isControlledBrain(brain)
    if type(brain) ~= "table" then return false end
    local program = brain.program
    return brain.lwnNonCombat == true
        or (type(program) == "table" and program.name == Integration.ProgramName)
end

Integration.isControlledBrain = isControlledBrain

local function enforceSafety(bandit, brain)
    if not bandit or not brain then return end
    brain.program = brain.program or {}
    if brain.program.name ~= Integration.ProgramName then
        brain.program.name = Integration.ProgramName
        brain.program.stage = "Main"
    elseif brain.program.stage ~= "Prepare" and brain.program.stage ~= "Main" then
        brain.program.stage = "Main"
    end
    brain.programFallback = Integration.ProgramName
    brain.hostile = false
    brain.hostileP = false
    brain.loyal = false
    brain.demolish = false
    brain.eatBody = false
    brain.lwnNonCombat = true
    if bandit.setTarget then bandit:setTarget(nil) end
    if bandit.setEatBodyTarget then bandit:setEatBodyTarget(nil, false) end
    if bandit.setVariable then
        bandit:setVariable("NoLungeTarget", true)
        if brain.lwnMoveActive ~= true then
            bandit:setVariable("BanditWalkType", "Walk")
        end
    end
    if bandit.setNoTeeth then bandit:setNoTeeth(true) end
end

Integration.enforceSafety = enforceSafety

local function registerProgram()
    ZombiePrograms = ZombiePrograms or {}
    ZombiePrograms[Integration.ProgramName] = ZombiePrograms[Integration.ProgramName] or {}

    ZombiePrograms[Integration.ProgramName].Prepare = function(bandit)
        local brain = BanditBrain and BanditBrain.Get and BanditBrain.Get(bandit) or nil
        enforceSafety(bandit, brain)
        if Bandit and Bandit.ForceStationary then
            Bandit.ForceStationary(bandit, true)
        end
        return { status = true, next = "Main", tasks = {} }
    end

    ZombiePrograms[Integration.ProgramName].Main = function(bandit)
        local brain = BanditBrain and BanditBrain.Get and BanditBrain.Get(bandit) or nil
        enforceSafety(bandit, brain)
        if Bandit and Bandit.ForceStationary then
            Bandit.ForceStationary(bandit, not (brain and brain.lwnMoveActive == true))
        end
        return { status = true, next = "Main", tasks = {} }
    end
end

function Integration.install()
    registerProgram()
    if Integration._patchInstalled == true then return true end
    if not (BanditUtils and BanditBrain and Bandit) then return false end
    if type(BanditUtils.AreEnemies) ~= "function"
        or type(BanditBrain.IsBareHands) ~= "function"
        or type(BanditBrain.NeedResupplySlot) ~= "function"
        or type(Bandit.Say) ~= "function"
    then
        return false
    end

    Integration._originalAreEnemies = BanditUtils.AreEnemies
    Integration._originalIsBareHands = BanditBrain.IsBareHands
    Integration._originalNeedResupplySlot = BanditBrain.NeedResupplySlot
    Integration._originalSay = Bandit.Say
    Integration._originalSetHostile = Bandit.SetHostile
    Integration._originalSetHostileP = Bandit.SetHostileP
    Integration._originalSetProgram = Bandit.SetProgram

    BanditUtils.AreEnemies = function(brain1, brain2)
        if isControlledBrain(brain1) or isControlledBrain(brain2) then
            return false
        end
        return Integration._originalAreEnemies(brain1, brain2)
    end

    BanditBrain.IsBareHands = function(brain)
        if isControlledBrain(brain) then return false end
        return Integration._originalIsBareHands(brain)
    end

    BanditBrain.NeedResupplySlot = function(brain, slot)
        if isControlledBrain(brain) then return false end
        return Integration._originalNeedResupplySlot(brain, slot)
    end

    Bandit.Say = function(bandit, phrase, force)
        local brain = BanditBrain.Get(bandit)
        if isControlledBrain(brain) then return end
        return Integration._originalSay(bandit, phrase, force)
    end

    if type(Integration._originalSetHostile) == "function" then
        Bandit.SetHostile = function(bandit, hostile)
            local brain = BanditBrain.Get(bandit)
            if isControlledBrain(brain) then
                brain.hostile = false
                return
            end
            return Integration._originalSetHostile(bandit, hostile)
        end
    end

    if type(Integration._originalSetHostileP) == "function" then
        Bandit.SetHostileP = function(bandit, hostileP)
            local brain = BanditBrain.Get(bandit)
            if isControlledBrain(brain) then
                brain.hostileP = false
                return
            end
            return Integration._originalSetHostileP(bandit, hostileP)
        end
    end

    if type(Integration._originalSetProgram) == "function" then
        Bandit.SetProgram = function(bandit, program, programParams)
            local brain = BanditBrain.Get(bandit)
            if isControlledBrain(brain) and program ~= Integration.ProgramName then
                enforceSafety(bandit, brain)
                return
            end
            return Integration._originalSetProgram(bandit, program, programParams)
        end
    end

    Integration._patchInstalled = true
    print("[LWN][Bandits] controlled NPC compatibility patches installed")
    return true
end

Integration.install()
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(Integration.install)
end
