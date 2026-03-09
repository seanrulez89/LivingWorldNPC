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
        TickFrames = 6,
    },

    Simulation = {
        MinuteTickEnabled = true,
        TenMinuteTickEnabled = true,
        MaxOffscreenUpdatesPerTick = 64,
    },

    Social = {
        CommandTrustFloor = -0.25,
        RecruitTrustFloor = 0.45,
        BetrayThreshold = 1.25,
        MemoryDecayPerDay = 0.02,
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
    },
}
