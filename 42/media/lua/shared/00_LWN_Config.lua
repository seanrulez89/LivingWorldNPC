LWN = LWN or {}

LWN.Config = {
    Version = 1,
    ModDataTag = "LWN_SP",

    Population = {
        InitialMin = 24,
        InitialMax = 48,
        IntroLockHours = 4,
        IntroTravelThreshold = 180,
        MaxEmbodied = 4,
        EncounterCooldownHours = 2.0,
    },

    Embodiment = {
        RadiusTiles = 32,
        DespawnRadiusTiles = 44,
        CompanionDespawnRadiusTiles = 58,
        GraceHours = 0.05,
        DeathCleanupDelayHours = 0.0025,
        TickFrames = 6,
    },

    Simulation = {
        MinuteTickEnabled = true,
        TenMinuteTickEnabled = true,
        MaxOffscreenUpdatesPerTick = 64,
    },

    Logging = {
        Enabled = true,
        Debug = false,
        BufferEnabled = true,
        MaxBufferEntries = 500,
        DefaultRateMs = 1000,
    },

    Social = {
        CommandTrustFloor = -0.25,
        RecruitTrustFloor = 0.45,
        BetrayThreshold = 1.25,
        MemoryDecayPerDay = 0.02,
        ComfortableCompanionCount = 3,
        OversizeStressPerCompanion = 0.12,
        OversizeCohesionPenaltyPerCompanion = 0.08,
    },

    Legacy = {
        MinTrust = 0.55,
        RequireRecruitment = true,
    },

    UI = {
        QuickMenuInnerRadius = 28,
        QuickMenuOuterRadius = 90,
        CommandPanelX = 50,
        CommandPanelY = 100,
        CommandPanelW = 380,
        CommandPanelH = 280,
        DialogueWindowX = 460,
        DialogueWindowY = 100,
        DialogueWindowW = 420,
        DialogueWindowH = 260,
    },

    Debug = {
        Enabled = true,
        Verbose = false,
        DrawEncounterInfo = false,
        KeepDebugSpawnsEmbodied = true,
        DebugSpawnDespawnRadiusTiles = 96,
        DebugSterileRadiusTiles = 8,
        DebugTestForceFriendly = true,
        DebugTestHoldPosition = true,
        DebugTestIdentityLock = true,
        DebugTestQuarantine = false,
        DebugTestAllowForcedHostile = false,
        DebugActorLostRecoveryTicks = 120,
        DebugRecoveryAttackQuarantineHours = 0.08,
        DebugPurgeRogueShellOnActorLost = true,
        ShowLegacyCarrierMenu = false,
        ShowDangerousDebugMenu = true,
    },
}
