Config = {}

Config.Debug = false

Config.Minimap = {
    Enabled = true,
    Texture = { Dictionary = 'rectmap', Name = 'radarmasksm' },
    MoveUp = 0.036,
    Position = {
        Minimap = { alignX = 'L', alignY = 'B', x = -0.0045, y = 0.002, width = 0.150, height = 0.188888 },
        Mask = { alignX = 'L', alignY = 'B', x = 0.020, y = 0.030, width = 0.111, height = 0.159 },
        Blur = { alignX = 'L', alignY = 'B', x = -0.030, y = 0.022, width = 0.266, height = 0.237 }
    },
    Ultrawide = {
        Enabled = true,
        ReferenceAspectRatio = 1920 / 1080,
        OffsetDivisor = 3.6
    },
    SessionRefreshDelays = { 250, 1250, 3000 },
    WatchdogInterval = 5000,
    AllowExpandedRadar = false,
    HideVanillaHealthArmour = true,
    HideNorthBlip = true,
    TextureLoadTimeout = 5000,
    RestoreDefaultOnStop = true
}

Config.Status = {
    Enabled = true,
    PlayerUpdateInterval = 125,
    NeedsUpdateInterval = 500,
    VisibilityInterval = 250,
    LayoutCheckInterval = 1000,
    HideOnPause = true,
    HideWithRadar = false,
    DisableHealthRegen = true,
    GapY = 0.006,
    OffsetX = 0,
    OffsetY = 0,
    WidthAdjustment = 0,
    ESXStatusResource = 'esx_status',
    HungerStatusName = 'hunger',
    ThirstStatusName = 'thirst',
    FallbackValue = 100,
    BackgroundColor = 'rgba(4, 12, 9, 0.90)',
    HealthColor = '#35E878',
    HealthColorEnd = '#74F6A6',
    WaterColor = '#38BDF8',
    WaterColorEnd = '#78D8FF',
    FoodColor = '#FFB84D',
    FoodColorEnd = '#FFD17B',
    StaminaColor = '#F1D94C',
    StaminaColorEnd = '#FFF08A'
}


Config.Needs = {

    Enabled = true,


    UseExternalStatus = false,

    StartValue = 100.0,

    TickInterval = 1000,


    HungerMinutes = 40,
    ThirstMinutes = 20,

    SprintMultiplier = 2.0,
    SwimMultiplier   = 1.75,
    VehicleMultiplier = 0.5,


    DamageEnabled   = true,
    DamageThreshold = 0,
    DamageAmount    = 1,
    DamageInterval  = 5000,
    -- true: starvation reaches 0 displayed HP and kills the player.
    -- false: damage stops at DamageMinHealth (105 native health = 5% HUD health).
    DamageCanKill   = true,
    DamageMinHealth = 105,

    SaveEnabled  = true,
    SaveInterval = 30 * 1000,
    SyncInterval = 3000,


    Database     = 'valerian',
    SaveTable    = 'vn_hud_needs',


    SaveColumn   = 'status',
    AlsoWriteUsersStatus = false,


    FileBackup     = true,
    FileBackupPath = 'data/needs.json',


    FoodMultiplier  = 1.0,
    DrinkMultiplier = 1.0,


    TreatBothEmptyAsFirstJoin = true,

    Gradual = {
        Enabled = true,

        FillPerSecond = 20.0,
        StepInterval = 80,
        MaxQueued = 100.0
    },

    UsableItems = {
        Enabled = true,

        Food = {
            bread     = 40.0,
            sandwich  = 50.0,
            burger    = 70.0,
            pizza     = 65.0,
            taco      = 45.0,
            donut     = 30.0,
            chocolate = 22.0,
            apple     = 20.0,
            banana    = 20.0,
            cake      = 45.0,
            hotdog    = 45.0,
            kebab     = 75.0
        },

        Drink = {
            water     = 50.0,
            cola      = 40.0,
            coffee    = 30.0,
            tea       = 30.0,
            juice     = 50.0,
            milk      = 40.0,
            energy    = 55.0,
            beer      = 22.0,
            wine      = 18.0,
            icetea    = 45.0,
            sprunk    = 40.0
        }
    },

    Animation = {
        Enabled  = true,
        Duration = 3000
    },

    Sounds = {
        Enabled = true,
        Eat = {
            Name = 'Eating',
            Set = 'DLC_H4_Prep_FC_Sounds',
            Interval = 720,
            Speech = 'GENERIC_EAT'
        },
        Drink = {
            Name = 'DRINK',
            Set = 'SAFEHOUSE_FRANKLIN_DRINK_BEER',
            Bank = 'SAFEHOUSE_FRANKLIN_DRINK_BEER',
            Interval = 640,
            Speech = 'GENERIC_DRINK'
        }
    },

    Notify = {
        Enabled    = true,
        EatMessage   = 'Eating...',
        DrinkMessage = 'Drinking...'
    },


    ListenToESXEvents = true,

    AdminCommand = 'setneed',
    AdminGroups  = {
        helper = true,
        seniorhelper = true,
        headhelper = true,
        admin = true,
        senioradmin = true,
        headadmin = true,
        developer = true,
        management = true,
        gamemaster = true
    },

    Debug = false
}

Config.Identity = {
    Enabled = true,
    Table = 'users',
    IdentifierColumn = 'identifier',
    FirstNameColumn = 'firstname',
    LastNameColumn = 'lastname',
    AccountsColumn = 'accounts',
    GroupColumn = 'group',
    Cache = true,
    RetryInterval = 15000
}

Config.PlayerInfo = {
    Enabled = true,
    UpdateInterval = 150,
    ESXRefreshInterval = 2000,
    OffsetRight = 22,
    OffsetTop = 42,
    NameSource = 'database',
    ShowJobGrade = true,
    FallbackJob = 'Unemployed',
    ShowGangGrade = true,
    FallbackGang = 'No Gang',
    UnarmedLabel = 'Unarmed',
    UnknownWeaponLabel = 'Weapon',
    CurrencySymbol = '$',
    HideDefaultCashHud = true,
    AccentColor = '#35DFC4'
}

Config.Compass = {
    Enabled = true,
    UpdateInterval = 50,
    AttachToScreenTop = true,
    OffsetTop = 0,
    FieldOfView = 120,
    AccentColor = '#35DFC4'
}

Config.Voice = {
    Enabled = true,
    UpdateInterval = 60,
    IdleUpdateInterval = 150,
    PushToTalkControl = 249,
    UsePushToTalkFallback = true,
    OffsetRightVw = 1.35,
    OffsetBottomVh = 1.8,
    SizeVh = 7.8,
    AccentColor = '#35DFC4',
    RadioColor = '#38BDF8',
    ShowWhenIdle = true,
    HideOnPause = true,
    WhisperDistance = 3.0,
    NormalDistance = 8.0
}

Config.Vehicle = {
    Enabled = true,
    UpdateInterval = 50,
    IdleInterval = 350,
    LayoutCheckInterval = 1000,
    UseMph = false,
    SpeedUnit = 'KM/H',

    CenterBottomVh = 1.8,

    RailGapPx = 13,
    RailOffsetX = 0,
    RailOffsetY = 0,

    Controls = {
        Seatbelt = 'L',
        Engine = 'J',
        Headlights = 'H',
        LeftIndicator = 'LBRACKET',
        RightIndicator = 'RBRACKET',
        Hazard = 'BACKSLASH'
    },

    Seatbelt = {
        Enabled = true,
        EjectionEnabled = true,
        EjectionMinSpeedKmh = 55.0,
        EjectionSpeedDropRatio = 0.52,
        EjectionSideForce = 11.5,
        EjectionUpForce = 5.4,
        EjectionForwardScale = 0.34,
        EjectionRagdollMs = 5600,
        WarningChime = true,
        WarningFile = 'm.mp3',
        WarningInterval = 980,
        ReminderInterval = 5000,
        ReminderMessage = 'Fasten your seatbelt.',
        EngineOffMessage = 'Start the vehicle.',
        FastenMessage = 'You fastened your seatbelt.',
        UnfastenMessage = 'You unfastened your seatbelt.'
    },

    IndicatorAutoCancelMs = 15000,
    AccentColor = '#35DFC4',
    WarningColor = '#FFB84D',
    DangerColor = '#FF4F63',
    GearColor = '#FFFFFF'
}

Config.Chat = {
    Enabled = true,
    OpenControl = 245,
    MaxMessageLength = 300,
    MaxMessages = 50,
    FadeAfter = 11000,
    TimeOffsetHours = -1,
    SpamCooldown = 900,

    AntiSpam = {
        WindowMs = 10000,
        MaxMessagesPerWindow = 6,
        DuplicateWindowMs = 15000,
        MaxRepeatedCharacters = 6
    },

    ProfanityFilter = {
        Enabled = true,
        Replacement = '***',
        Persian = {
            'کصکش', 'کسکش', 'کیری', 'کونی', 'بیناموسی',
            'مادر جنده', 'مادر خراب', 'کص ننه', 'زن کصه',
            'مادرتو گاییدم', 'مادرتو گایددم', 'کصخل', 'جنده',
            'حرومزاده', 'دیوث', 'لاشی', 'پفیوز'
        },
        English = {
            'fuck', 'fucker', 'fucking', 'motherfucker', 'shit',
            'bitch', 'bastard', 'asshole', 'dickhead', 'cunt',
            'whore', 'slut', 'retard'
        }
    },

    StopDefaultChatResource = true,
    ShowJoinLeave = false,

    ProximityDistance = 5.0,
    WhisperDistance = 2.0,
    ShoutDistance = 15.0,
    ThreeDDistance = 5.0,
    ThreeDDuration = 7000,

    Position = {
        TopVh = 2.2,
        LeftVw = 1.4,
        WidthVw = 26.0,
        HeightVh = 28.0
    },

    AccentColor = '#35DFC4',
    MessageColor = { 238, 255, 252 },
    SystemColor = { 53, 223, 196 },
    ModeColors = {
        ic = { 53, 223, 196 },
        ooc = { 120, 185, 255 },
        me = { 190, 120, 255 },
        ['do'] = { 255, 184, 77 },
        try = { 245, 215, 90 },
        whisper = { 180, 205, 210 },
        shout = { 255, 220, 120 },
        pm = { 255, 120, 205 },
        ann = { 255, 66, 82 },
        bot = { 53, 223, 196 },
        admin = { 255, 196, 72 },
        job = { 120, 210, 255 },
        dep = { 255, 140, 90 }
    },

    AnnouncementGroups = {
        developer = true,
        management = true,
        gamemaster = true,
        headadmin = true
    },

    StaffGroups = {
        helper = true,
        seniorhelper = true,
        headhelper = true,
        admin = true,
        senioradmin = true,
        headadmin = true,
        developer = true,
        management = true,
        gamemaster = true
    },

    StaffRankLabels = {
        helper = 'HELPER',
        seniorhelper = 'SENIORHELPER',
        headhelper = 'HEADHELPER',
        admin = 'ADMIN',
        senioradmin = 'SENIORADMIN',
        headadmin = 'HEADADMIN',
        developer = 'DEVELOPER',
        management = 'MANAGEMENT',
        gamemaster = 'GAMEMASTER'
    },


    DepartmentJobs = {},

    AutoBot = {
        Enabled = true,
        IntervalMinutes = 15,
        Tag = 'CITY BOT',
        DiscordInvite = 'discord.gg/yourserver',
        Messages = {
            'Read the server rules and respect staff.',
            'Need help? Open a Discord ticket or use /report.',
            'RDM and VDM are not allowed.',
            'Join Discord for updates and events.'
        }
    }
}

Config.Radio = {
    Enabled = true,
    OpenKey = 'Q',
    DefaultVolume = 0.55,
    PanelLift = 108,
    ControllerSeats = { -1, 0 },
    Exterior = {
        Enabled = true,
        MaxDistance = 12.0,
        VolumeScale = 0.04
    },

    Stations = {
        {
            id = 'shadow',
            label = 'SHADOW',
            tracks = { '', '', '', '', '' }
        },
        {
            id = 'station2',
            label = 'Radio 2',
            tracks = { '', '', '', '', '' }
        },
        {
            id = 'station3',
            label = 'Radio 3',
            tracks = { '', '', '', '', '' }
        },
        {
            id = 'station4',
            label = 'Radio 4',
            tracks = { '', '', '', '', '' }
        },
        {
            id = 'station5',
            label = 'Radio 5',
            tracks = { '', '', '', '', '' }
        },
        {
            id = 'station6',
            label = 'Radio 6',
            tracks = { '', '', '', '', '' }
        },
        {
            id = 'station7',
            label = 'Radio 7',
            tracks = { '', '', '', '', '' }
        }
    }
}
