LWN = LWN or {}
LWN.BanditsIntegration = LWN.BanditsIntegration or {}

local Integration = LWN.BanditsIntegration

Integration.ProgramName = "LWNControlled"
Integration.ClanId = "ae5e5d56-d82f-43a3-b1bb-28614544b343"
Integration.ProfileId = "381888f8-af27-45b6-aa90-f56d22299753"

local function isControlledBrain(brain)
    if type(brain) ~= "table" then return false end
    local program = brain.program
    return brain.lwnControlled == true
        or brain.lwnNonCombat == true
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
    brain.lwnControlled = true
    brain.lwnNonCombat = brain.lwnCombatEngaged ~= true
    if brain.lwnCombatEngaged ~= true and bandit.setTarget then bandit:setTarget(nil) end
    if bandit.setEatBodyTarget then bandit:setEatBodyTarget(nil, false) end
    if bandit.setVariable then
        bandit:setVariable("NoLungeTarget", true)
        if brain.lwnMoveActive ~= true then
            bandit:setVariable("BanditWalkType", "Walk")
        end
    end
    if bandit.setNoTeeth then bandit:setNoTeeth(true) end
    if brain.lwnFriendlyFireProtected ~= true then
        if bandit.setGodMod then bandit:setGodMod(false) end
        if bandit.setInvulnerable then bandit:setInvulnerable(false) end
        if bandit.setAvoidDamage then bandit:setAvoidDamage(false) end
    end
    if bandit.setShootable then bandit:setShootable(true) end
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
            Bandit.ForceStationary(
                bandit,
                not (brain and (brain.lwnMoveActive == true or brain.lwnCombatEngaged == true))
            )
        end
        return { status = true, next = "Main", tasks = {} }
    end
end

local function installFriendlyFirePatch()
    if Integration._friendlyFirePatchInstalled == true then return true end
    if not (BanditPlayer and type(BanditPlayer.CheckFriendlyFire) == "function") then return false end

    Integration._originalCheckFriendlyFire = BanditPlayer.CheckFriendlyFire
    BanditPlayer.CheckFriendlyFire = function(bandit, attacker)
        local brain = BanditBrain and BanditBrain.Get and BanditBrain.Get(bandit) or nil
        local playerAttack = attacker
            and instanceof
            and instanceof(attacker, "IsoPlayer")
            and (not attacker.isNPC or attacker:isNPC() ~= true)
        if isControlledBrain(brain) and playerAttack then
            brain.lwnFriendlyFireProtected = true
            brain.lwnProtectedHealth = bandit.getHealth and bandit:getHealth() or brain.health
            brain.lwnFriendlyFireProtectedAtMs = getTimestampMs and getTimestampMs() or 0
            if bandit.setGodMod then bandit:setGodMod(true) end
            if bandit.setInvulnerable then bandit:setInvulnerable(true) end
            if bandit.setAvoidDamage then bandit:setAvoidDamage(true) end
            enforceSafety(bandit, brain)
            return
        end
        return Integration._originalCheckFriendlyFire(bandit, attacker)
    end
    Integration._friendlyFirePatchInstalled = true
    print("[LWN][Bandits] controlled NPC friendly-fire patch installed")
    return true
end

local function installApplyVisualsPatch()
    if Integration._applyVisualsPatchInstalled == true then return true end
    if not (Bandit and type(Bandit.ApplyVisuals) == "function") then return false end

    Integration._originalApplyVisuals = Bandit.ApplyVisuals
    Bandit.ApplyVisuals = function(bandit, brain)
        local preserve = isControlledBrain(brain)
            and (brain.lwnControlled == true or brain.lwnNpcId ~= nil)
        local beforeHealth = preserve and bandit and bandit.getHealth and bandit:getHealth() or nil
        local protectedHealth = preserve and tonumber(brain.lwnProtectedHealth) or nil
        local results = { Integration._originalApplyVisuals(bandit, brain) }
        if preserve and bandit and bandit.setHealth then
            local restoreHealth = protectedHealth or tonumber(beforeHealth)
            if restoreHealth ~= nil then
                bandit:setHealth(restoreHealth)
                brain.health = restoreHealth
            end
        end
        return unpack(results)
    end
    Integration._applyVisualsPatchInstalled = true
    print("[LWN][Bandits] controlled NPC health-preserving visuals patch installed")
    return true
end

local function shouldBlockTaskForControlledBrain(brain, task)
    if not isControlledBrain(brain) or type(task) ~= "table" then return false end
    return task.action == "Bandage"
end

local function installTaskGatePatch()
    if Integration._taskGatePatchInstalled == true then return true end
    if not (Bandit and type(Bandit.AddTask) == "function" and type(Bandit.AddTaskFirst) == "function") then
        return false
    end

    Integration._originalAddTask = Bandit.AddTask
    Integration._originalAddTaskFirst = Bandit.AddTaskFirst

    Bandit.AddTask = function(bandit, task)
        local brain = BanditBrain and BanditBrain.Get and BanditBrain.Get(bandit) or nil
        if shouldBlockTaskForControlledBrain(brain, task) then
            if LWN and LWN.Log and LWN.Log.warn then
                LWN.Log.warn("Combat", "bandits_task_gate", {
                    npcId = brain and brain.lwnNpcId,
                    source = "bandits",
                    task = task and task.action,
                    reason = "auto_medical_disabled",
                    detail = "Bandit.AddTask",
                }, { rateKey = tostring(brain and brain.lwnNpcId or "unknown") .. ":Bandage", rateMs = 1500 })
            end
            return
        end
        return Integration._originalAddTask(bandit, task)
    end

    Bandit.AddTaskFirst = function(bandit, task)
        local brain = BanditBrain and BanditBrain.Get and BanditBrain.Get(bandit) or nil
        if shouldBlockTaskForControlledBrain(brain, task) then
            if LWN and LWN.Log and LWN.Log.warn then
                LWN.Log.warn("Combat", "bandits_task_gate", {
                    npcId = brain and brain.lwnNpcId,
                    source = "bandits",
                    task = task and task.action,
                    reason = "auto_medical_disabled",
                    detail = "Bandit.AddTaskFirst",
                }, { rateKey = tostring(brain and brain.lwnNpcId or "unknown") .. ":BandageFirst", rateMs = 1500 })
            end
            return
        end
        return Integration._originalAddTaskFirst(bandit, task)
    end

    Integration._taskGatePatchInstalled = true
    print("[LWN][Bandits] controlled NPC task gate patch installed")
    return true
end

function Integration.install()
    registerProgram()
    installFriendlyFirePatch()
    installApplyVisualsPatch()
    installTaskGatePatch()
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
        local controlled1 = isControlledBrain(brain1)
        local controlled2 = isControlledBrain(brain2)
        if controlled1 and controlled2 then
            return false
        end
        if controlled1 then
            if brain2 == nil then return brain1.lwnCombatEngaged == true end
            return false
        end
        if controlled2 then
            if brain1 == nil then return brain2.lwnCombatEngaged == true end
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
