Config = {}

----------------------------------
-- needs settings
----------------------------------
Config.StatusInterval = 5000 -- how often to update hunger/thirst status in milliseconds
Config.HungerRate = 0.01 -- Rate at which hunger goes down.
Config.ThirstRate = 0.01 -- Rate at which thirst goes down.

-- server-owned needs: the server decays hunger/thirst/stress and reverts client state bag tampering
Config.ServerNeeds = true
Config.MaxStressReliefPerMinute = 50 -- max stress a client may remove per minute (smoking, drinking, etc.); more is reverted
Config.MaxNeedGainPerMinute = 150 -- max hunger/thirst a client may add per minute (eating/drinking); more is reverted

----------------------------------
-- warnings
----------------------------------
Config.LowNeedWarning = 20       -- notify when hunger/thirst drops to this value (0 = off)
Config.LowHealthHeartbeat = 25   -- play a heartbeat below this health % (0 = off)
Config.HeartbeatSound = { name = 'Heartbeat', set = 'RDRO_Sniper_Tension_Sounds' } -- rdr3_discoveries audio/frontend_soundsets
Config.WarningSound = true       -- play rsg-core's warning notification sound with the low hunger / thirst and high stress warnings
Config.HighStressWarning = 80    -- notify when stress reaches this value (0 = off)

----------------------------------
-- decay modifiers (needs Config.ServerNeeds = true)
----------------------------------
-- The client only reports what it is doing (running, swimming, hot/cold weather). The server picks the multiplier from
-- this table and never lets a reported value go below 1.0, so a modified client can only make itself hungrier, not less hungry.
Config.DecayModifiers = {
    enabled = true,
    maxMultiplier = 3.0, -- hunger/thirst decay can never be multiplied by more than this
    activity = {         -- hunger and thirst decay multiplier while doing this
        run = 1.25,
        sprint = 2.0,
        swim = 1.5,
        gallop = 1.5,    -- riding fast
    },
    environment = {      -- uses Config.MinTemp / Config.MaxTemp (celsius), works even if Config.TempFeature is off
        hot  = { thirst = 1.75, hunger = 1.0 },
        cold = { thirst = 1.0,  hunger = 1.5 },
    },
    -- "well fed" buff: while hunger AND thirst are both at or above `minimum`, both fade slower (the server decides this)
    wellFed = { enabled = true, minimum = 80, decayMultiplier = 0.5 },
}

----------------------------------
-- stress settings
----------------------------------
Config.StressChance = 0.1 -- Default: 10% -- Percentage Stress Chance When Shooting (0-1)
Config.MinimumStress = 50 -- Minimum Stress Level For Screen Shaking
Config.MinimumSpeed = 100 -- Going Over This Speed Will Cause Stress
Config.StressDecayRate = 0.01 -- Rate at which stress goes down.

----------------------------------
-- hud player display settings
----------------------------------
Config.HidePlayerHealthNative  = true
Config.HidePlayerStaminaNative = true
Config.HidePlayerDeadEyeNative = true

----------------------------------
-- hud horse display settings
----------------------------------
Config.HideHorseHealthNative  = true
Config.HideHorseStaminaNative = true
Config.HideHorseCourageNative = true

----------------------------------
-- extra icons
----------------------------------
Config.ShowDeadEye = true      -- deadeye core circle
Config.ShowHorseBonding = true -- horse bonding level circle
Config.ShowHorseNeeds = true   -- horse hunger + thirst circles (needs rsg-stables, own active horse only)

----------------------------------
-- extra badges (every player can still hide each one in /hudsettings > Icons)
----------------------------------
Config.ShowClock = true            -- in-game time badge (follows rsg-weather's synced clock)
Config.Clock24h = false            -- true = 24 hour clock, false = 12 hour with AM/PM
Config.ShowCompass = true          -- compass bearing badge, e.g. NE 045 (separate from the minimap compass mode)
Config.ShowAmmo = true             -- ammo in clip / reserve while holding a firearm or bow
Config.ShowWeaponCondition = true  -- condition % of the weapon in hand (0-100, from the game's weapon degradation)
Config.ShowHorseInjury = true      -- injured horse badge while mounted and the horse's health is low
Config.HorseInjuredBelow = 25      -- horse health % at or below which the injured badge shows

----------------------------------
-- bank balance command (uses rsg-banking v3 total balance when started)
----------------------------------
Config.BankCommand = 'bank'

----------------------------------
-- voice icon settings
----------------------------------
Config.ShowVoice = false          -- true = show the voice icon on the HUD, false = voice icon disabled
Config.VoiceAlwaysVisible = true  -- true = always visible, false = only when talking
Config.ShowPercentages = false    -- default for the % under circle icons (players change it in /hudsettings or /togglehudpct, saved per player)

----------------------------------
-- hud settings panel (players change with /hudsettings, saved per player in client KVP)
----------------------------------
Config.SettingsCommand = 'hudsettings' -- opens the HUD settings window
Config.PresetCommand = 'hudpreset'     -- old command name, opens the same window
Config.AllowPlayerMinimap = true       -- let players choose minimap / compass / off (on foot + mounted); false = server Config only
Config.AllowPlayerColors = true        -- let players recolour icons + rings with the colour picker; false = Config.IconColors only
Config.AllowPlayerFeatures = true      -- let players turn alerts, sounds and screen effects on/off (/hudsettings > Features) and hide the whole HUD (/togglehud); false = server Config only
Config.ToggleHudCommand = 'togglehud'  -- shows / hides the whole HUD for the player (saved per player)

-- keys (default keys only, players can rebind them in the game's key settings; '' = unbound until the player binds one)
Config.UseKeyMapping = true            -- true = rsg-core RegisterKey / RegisterKeyMapping, false = commands only
Config.SettingsKey = 'F9'              -- opens the HUD settings window (Esc closes it)
Config.ToggleHudKey = ''               -- shows / hides the whole HUD
-- default ring colour thresholds (players can change these in /hudsettings > Display)
Config.RingWarnAt = 70           -- ring turns orange at or below this %
Config.RingBadAt = 30            -- ring turns red at or below this %

Config.SettingsLimits = {
    minOpacity = 30, -- lowest HUD opacity a player may pick (%)
    minScale = 70,   -- smallest icon scale (%)
    maxScale = 140,  -- biggest icon scale (%)
}

-- While NUI is open, block game controls but allow push-to-talk.
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}
-- admin default layout: an admin sets their own layout with /pushhuddefault and it becomes the default for every player
-- who has not saved a layout of their own (/clearhuddefault removes it, /resethudlayout drops your own saved layout)
Config.AdminPermission = 'admin'
Config.PushDefaultCommand = 'pushhuddefault'
Config.ClearDefaultCommand = 'clearhuddefault'
Config.DefaultPreset = {
    size = 'medium',          -- 'small' | 'medium' | 'large'
    align = 'bottom-center',  -- 'bottom-left' | 'bottom-center' | 'bottom-right' | 'top-left' | 'top-center' | 'top-right'
    orientation = 'horizontal' -- 'horizontal' | 'vertical'
}

----------------------------------
-- minimap / compass settings (server defaults; players can override when Config.AllowPlayerMinimap = true)
----------------------------------
Config.OnFootMinimap = true -- set to true/false to disable/enable minimap when on foot
Config.OnFootCompass = false -- true = have the minimap set to a compass instead of off or normal minimap
Config.MountMinimap = true  -- set to false if you want to disable the minimap when on mount
Config.MountCompass  = false -- set to true if you want to have a compass instead of normal minimap while on a mount

----------------------------------
-- turn health damage on/off
----------------------------------
Config.DoHealthDamage = true

----------------------------------
-- turn screen effect on/off
----------------------------------
Config.DoHealthDamageFx = false

----------------------------------
-- turn health damage sound on/off
----------------------------------
Config.DoHealthPainSound = true

----------------------------------
-- temp settings (only one setting)
----------------------------------
Config.TempFormat = 'celsius'
--Config.TempFormat = 'fahrenheit'

----------------------------------
-- temp feature (does damage to player if too hot or cold)
----------------------------------
Config.TempFeature = false
Config.TempStaminaDrain = 10 -- cold/heatstroke drains this much stamina core per StatusInterval before health is hit

----------------------------------
-- warmth add while wearing, in °C (temp feature must be enabled)
----------------------------------
Config.WearingHat      = 0
Config.WearingShirt    = 0
Config.WearingPants    = 0
Config.WearingBoots    = 0
Config.WearingCoat     = 15
Config.WearingOpenCoat = 15
Config.WearingGloves   = 0
Config.WearingVest     = 0
Config.WearingPoncho   = 0
Config.WearingSkirt    = 0
Config.WearingChaps    = 0

----------------------------------
-- job type warmth exemptions (temp feature must be enabled)
----------------------------------
Config.EnableNoWarmthJobs = true  -- set to true/false to enable/disable the feature

Config.NoWarmthJobs = {
    'leo',      -- Law enforcement (sheriff, deputy, marshal, etc.)
    'medic',    -- Medical jobs (doctor, surgeon, etc.)
    -- add more job types here
}

----------------------------------
-- warmth limit before impacts health, always in °C regardless of TempFormat (temp feature must be enabled)
----------------------------------
Config.MinTemp = -5
Config.MaxTemp = 55

----------------------------------
-- cleanliness limit before impacts health
----------------------------------
Config.FlyEffect = true -- toggle flies on/off
Config.MinCleanliness = 30

----------------------------------
-- amount of health to remove if min/max temp reached
----------------------------------
Config.RemoveHealth = 1

----------------------------------
-- stress settings
----------------------------------
Config.Intensity = {
    ["shake"] = {
        [1] = {
            min = 50,
            max = 60,
            intensity = 0.12,
        },
        [2] = {
            min = 60,
            max = 70,
            intensity = 0.17,
        },
        [3] = {
            min = 70,
            max = 80,
            intensity = 0.22,
        },
        [4] = {
            min = 80,
            max = 90,
            intensity = 0.28,
        },
        [5] = {
            min = 90,
            max = 100,
            intensity = 0.32,
        },
    }
}

Config.EffectInterval = {
    [1] = {
        min = 50,
        max = 60,
        timeout = { 50000, 60000 } -- ms, random between min/max each cycle
    },
    [2] = {
        min = 60,
        max = 70,
        timeout = { 40000, 50000 } -- ms, random between min/max each cycle
    },
    [3] = {
        min = 70,
        max = 80,
        timeout = { 30000, 40000 } -- ms, random between min/max each cycle
    },
    [4] = {
        min = 80,
        max = 90,
        timeout = { 20000, 30000 } -- ms, random between min/max each cycle
    },
    [5] = {
        min = 90,
        max = 100,
        timeout = { 15000, 20000 } -- ms, random between min/max each cycle
    }
}

----------------------------------
-- HUD icon colors configuration
----------------------------------
Config.IconColors = {
    -- Player Status Icons (RDR2 leather & gold: monochrome + semantic states)
    ['voice'] = {
        normal = '#FFFFFF',      -- White when not talking
        active = '#e0554f'       -- Red when talking
    },
    ['health'] = {
        normal = '#FFFFFF',      -- White when healthy
        low = '#e0554f'          -- Red when low health (<=30%)
    },
    ['stamina'] = {
        normal = '#FFFFFF',      -- White when full
        low = '#e0554f'          -- Red when low stamina (<=30%)
    },
    ['hunger'] = {
        normal = '#FFFFFF',      -- White when full
        low = '#e0554f'          -- Red when low hunger (<=30%)
    },
    ['thirst'] = {
        normal = '#FFFFFF',      -- White when full
        low = '#e0554f'          -- Red when low thirst (<=30%)
    },
    ['cleanliness'] = {
        normal = '#FFFFFF',      -- White when clean
        low = '#e0554f'          -- Red when dirty (<=30%)
    },
    ['deadeye'] = {
        normal = '#FFFFFF',
        low = '#e0554f'
    },
    ['stress'] = {
        normal = '#FFFFFF',      -- White (stress icon color)
    },
    ['temp'] = {
        cold = '#d9a441',        -- Amber when cold
        normal = '#f2f2f2'       -- Soft white when normal
    },
    ['mail'] = {
        normal = '#FFFFFF',      -- White when no mail
        hasmail = '#ffffff'      -- White highlight when has mail
    },
    ['outlaw'] = {
        normal = '#6fbf73',      -- Green when not outlaw
        active = '#e0554f'       -- Red when outlaw
    },

    -- Horse Status Icons
    ['horse_health'] = {
        normal = '#f2f2f2',      -- Soft white for horse health
        low = '#e0554f'          -- Red when low
    },
    ['horse_stamina'] = {
        normal = '#f2f2f2',      -- Soft white for horse stamina
        low = '#e0554f'          -- Red when low
    },
    ['horse_bond'] = {
        normal = '#d9a441',      -- Gold for bonding
        low = '#f2f2f2'
    },
    ['horse_clean'] = {
        normal = '#f2f2f2',      -- Soft white for horse cleanliness
        low = '#e0554f'          -- Red when dirty
    },
    ['horse_hunger'] = {
        normal = '#f2f2f2',      -- Soft white for horse hunger
        low = '#e0554f'          -- Red when hungry
    },
    ['horse_thirst'] = {
        normal = '#f2f2f2',      -- Soft white for horse thirst
        low = '#e0554f'          -- Red when thirsty
    }
}
