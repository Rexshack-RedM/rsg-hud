local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local showUI = false
local removeFlies -- forward declaration (defined in flies section)
local editMode = false
local temperature = '0'
local temp = 0   -- display value (in Config.TempFormat units)
local tempC = 0  -- internal value in celsius (used for damage checks)
local outlawstatus = 0

local NATIVE_SET_HUD_ICON = 0xC116E6DF68DCE667
local NATIVE_GET_ATTRIBUTE_RANK = 0x147149F2E909323C

local function getDirt(ped)
    return Citizen.InvokeNative(NATIVE_GET_ATTRIBUTE_RANK, ped, 16, Citizen.ResultAsInteger())
end

local function isDead()
    local playerData = RSGCore.Functions.GetPlayerData()
    return playerData and playerData.metadata and playerData.metadata['isdead']
end

------------------------------------------------
-- send locales + icon colors to NUI
------------------------------------------------
local localeKeys = {
    'edit_mode_on_title', 'edit_mode_on_desc', 'edit_mode_off_desc', 'reset_hud_title', 'reset_hud_desc',
    'money_hud_label', 'voice_label', 'outlaw_label', 'temp_label', 'health_label', 'stamina_label', 'hunger_label', 'thirst_label',
    'clean_label', 'stress_label', 'mail_label', 'horse_health_label', 'horse_stamina_label', 'horse_clean_label'
}

local function sendConfigToNUI()
    local locales = {}
    for _, key in ipairs(localeKeys) do
        locales[key] = locale(key)
    end
    SendNUIMessage({ action = 'setLocales', locales = locales })
    SendNUIMessage({ action = 'setConfig', iconColors = Config.IconColors, voiceAlwaysVisible = Config.VoiceAlwaysVisible, showPercentages = Config.ShowPercentages })
end

-- NUI tells us when it has loaded (avoids the old fixed Wait(1000) race)
RegisterNUICallback('nuiReady', function(_, cb)
    sendConfigToNUI()
    cb('ok')
end)

------------------------------------------------
-- hide ui
------------------------------------------------
RegisterNetEvent('HideAllUI', function()
    showUI = not showUI
end)

------------------------------------------------
-- hide native hud cores
------------------------------------------------
local function applyNativeHides()
    local hides = {
        { Config.HidePlayerHealthNative,  4,  5 },  -- health / core
        { Config.HidePlayerStaminaNative, 0,  1 },  -- stamina / core
        { Config.HidePlayerDeadEyeNative, 2,  3 },  -- deadeye / core
        { Config.HideHorseHealthNative,   6,  7 },  -- horse health / core
        { Config.HideHorseStaminaNative,  8,  9 },  -- horse stamina / core
        { Config.HideHorseCourageNative,  10, 11 }, -- horse courage / core
    }
    for _, h in ipairs(hides) do
        if h[1] then
            Citizen.InvokeNative(NATIVE_SET_HUD_ICON, h[2], 2)
            Citizen.InvokeNative(NATIVE_SET_HUD_ICON, h[3], 2)
        end
    end
end

CreateThread(applyNativeHides)

------------------------------------------------
-- login / logout
------------------------------------------------
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    showUI = true
    applyNativeHides()
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    showUI = false
    removeFlies()
end)

-- resource restarted while already logged in
CreateThread(function()
    if LocalPlayer.state.isLoggedIn then
        showUI = true
    end
end)

------------------------------------------------
-- needs
------------------------------------------------
local function updateNeed(key, value, reduce)
    if reduce then
        value = (LocalPlayer.state[key] or 0) - value
    end

    value = lib.math.clamp(lib.math.round(value, 2), 0, 100)
    if LocalPlayer.state[key] ~= value then
        LocalPlayer.state:set(key, value, true)
    end
end

local function setNeed(key, value, offset)
    value = tonumber(value)
    if not value then return end
    updateNeed(key, value - (offset or 0))
end

RegisterNetEvent('hud:client:UpdateNeeds', function(newHunger, newThirst, newCleanliness)
    setNeed('hunger', newHunger)
    setNeed('thirst', newThirst)
    setNeed('cleanliness', newCleanliness, getDirt(cache.ped))
end)

RegisterNetEvent('hud:client:UpdateHunger', function(v) setNeed('hunger', v) end)
RegisterNetEvent('hud:client:UpdateThirst', function(v) setNeed('thirst', v) end)
RegisterNetEvent('hud:client:UpdateStress', function(v) setNeed('stress', v) end)
RegisterNetEvent('hud:client:UpdateCleanliness', function(v) setNeed('cleanliness', v, getDirt(cache.ped)) end)

------------------------------------------------
-- stress
------------------------------------------------
local STRESS_NOTIFY_COOLDOWN = 30000
local lastStressNotify = { gain = 0, relieve = 0 }

local function updateStress(amount, isGain)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return end

    local playerData = RSGCore.Functions.GetPlayerData()
    if not playerData or not playerData.metadata or playerData.metadata['isdead'] then return end
    if isGain and playerData.job and playerData.job.type == 'leo' then return end -- law doesn't gain stress

    local current = LocalPlayer.state.stress or 0
    local newStress = lib.math.round(lib.math.clamp(current + (isGain and amount or -amount), 0, 100), 2)
    if newStress == current then return end
    LocalPlayer.state:set('stress', newStress, true)

    -- throttle notifications so shooting/speeding doesn't spam the feed
    local key = isGain and 'gain' or 'relieve'
    local now = GetGameTimer()
    if now - lastStressNotify[key] >= STRESS_NOTIFY_COOLDOWN then
        lastStressNotify[key] = now
        lib.notify({ title = locale(isGain and 'stress_gain' or 'stress_relief'), type = 'inform', duration = 4000 })
    end
end

RegisterNetEvent('hud:client:GainStress', function(amount)
    updateStress(amount, true)
end)

RegisterNetEvent('hud:client:RelieveStress', function(amount)
    updateStress(amount, false)
end)

local function getRangeValue(list, level, key, default)
    for _, v in pairs(list) do
        if level >= v.min and level <= v.max then
            return v[key]
        end
    end
    return default
end

-- stress gained while speeding
CreateThread(function()
    while true do
        Wait(10000)
        if LocalPlayer.state.isLoggedIn and IsPedInAnyVehicle(cache.ped, false) then
            local speed = GetEntitySpeed(GetVehiclePedIsIn(cache.ped, false)) * 2.237 -- mph
            if speed >= Config.MinimumSpeed then
                updateStress(math.random(1, 3), true)
            end
        end
    end
end)

-- stress gained while shooting (single loop, only alive while armed)
local shootingLoopActive = false

local function startShootingLoop()
    if shootingLoopActive then return end
    shootingLoopActive = true
    CreateThread(function()
        while cache.weapon and cache.weapon ~= -1569615261 do -- -1569615261 = bare hands
            if IsPedShooting(cache.ped) and math.random() < Config.StressChance then
                updateStress(math.random(1, 3), true)
            end
            Wait(100)
        end
        shootingLoopActive = false
    end)
end

lib.onCache('weapon', function(weapon)
    if weapon and weapon ~= -1569615261 then
        startShootingLoop()
    end
end)

-- stress screen effects
CreateThread(function()
    while true do
        local stress = LocalPlayer.state.stress or 0
        local range = getRangeValue(Config.EffectInterval, stress, 'timeout')
        local sleep = range and math.random(range[1], range[2]) or 10000

        if stress >= Config.MinimumStress and not isDead() then
            local intensity = getRangeValue(Config.Intensity['shake'], stress, 'intensity', 0.05)
            ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', intensity)

            if stress >= 100 then
                local fallRepeat = math.random(2, 4)
                local ragdollTimeout = fallRepeat * 1750

                if not IsPedRagdoll(cache.ped) and IsPedOnFoot(cache.ped) and not IsPedSwimming(cache.ped) then
                    SetPedToRagdollWithFall(cache.ped, ragdollTimeout, ragdollTimeout, 1, GetEntityForwardVector(cache.ped), 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
                end

                Wait(500)
                for _ = 1, fallRepeat do
                    Wait(750)
                    DoScreenFadeOut(200)
                    Wait(1000)
                    DoScreenFadeIn(200)
                    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', intensity)
                end
            end
        end
        Wait(sleep)
    end
end)

------------------------------------------------
-- flies when not clean (Config.MinCleanliness)
------------------------------------------------
local FLIES_DICT = 'scr_mg_cleaning_stalls'
local FLIES_NAME = 'scr_mg_stalls_manure_flies'
local fliesHandle = false

removeFlies = function()
    if fliesHandle then
        if Citizen.InvokeNative(0x9DD5AFF561E88F2A, fliesHandle) then -- DoesParticleFxLoopedExist
            Citizen.InvokeNative(0x459598F579C98929, fliesHandle, false) -- RemoveParticleFx
        end
        fliesHandle = false
    end
end

local function updateFlies(clean)
    if LocalPlayer.state.isBathingActive then
        removeFlies()
        return
    end

    -- drop a stale handle if the effect died on its own
    if fliesHandle and not Citizen.InvokeNative(0x9DD5AFF561E88F2A, fliesHandle) then
        fliesHandle = false
    end

    if clean >= Config.MinCleanliness then
        removeFlies()
        return
    end

    if fliesHandle then return end

    local dict = joaat(FLIES_DICT)
    if not Citizen.InvokeNative(0x65BB72F29138F5D6, dict) then -- HasNamedPtfxAssetLoaded
        Citizen.InvokeNative(0xF2B2353BBC0D4E8F, dict)         -- RequestNamedPtfxAsset
        local timeout = GetGameTimer() + 3000
        while not Citizen.InvokeNative(0x65BB72F29138F5D6, dict) and GetGameTimer() < timeout do
            Wait(0)
        end
    end

    if not Citizen.InvokeNative(0x65BB72F29138F5D6, dict) then
        lib.print.warn('cant load ptfx dictionary: ' .. FLIES_DICT)
        return
    end

    local bone = IsPedMale(cache.ped) and 413 or 464
    Citizen.InvokeNative(0xA10DB07FC234DD12, FLIES_DICT) -- UseParticleFxAsset
    fliesHandle = Citizen.InvokeNative(0x9C56621462FFE7A6, FLIES_NAME, cache.ped, 0.2, 0.0, -0.4, 0.0, 0.0, 0.0, bone, 1.0, 0, 0, 0) -- StartNetworkedParticleFxLoopedOnEntityBone
end

------------------------------------------------
-- temperature
------------------------------------------------
local clothingWarmth = {
    { 0x9925C067, 'WearingHat' },
    { 0x2026C46D, 'WearingShirt' },
    { 0x1D4C528A, 'WearingPants' },
    { 0x777EC6EF, 'WearingBoots' },
    { 0xE06D30CE, 'WearingCoat' },
    { 0x662AC34,  'WearingOpenCoat' },
    { 0xEABE0032, 'WearingGloves' },
    { 0x485EE834, 'WearingVest' },
    { 0xAF14310B, 'WearingPoncho' },
    { 0xA0E3AB7F, 'WearingSkirt' },
    { 0x3107499B, 'WearingChaps' },
}

local function getWarmth(ped)
    if Config.EnableNoWarmthJobs and Config.NoWarmthJobs then
        local playerData = RSGCore.Functions.GetPlayerData()
        local jobType = playerData and playerData.job and playerData.job.type
        if jobType then
            for _, exempt in pairs(Config.NoWarmthJobs) do
                if jobType == exempt then return 0 end
            end
        end
    end

    local total = 0
    for _, item in ipairs(clothingWarmth) do
        if Citizen.InvokeNative(0xFB4891BD7578CDC1, ped, item[1]) == 1 then
            total = total + (Config[item[2]] or 0)
        end
    end
    return total
end

CreateThread(function()
    while true do
        Wait(1000)
        if LocalPlayer.state.isLoggedIn then
            -- everything is calculated in celsius; fahrenheit is display only
            tempC = GetTemperatureAtCoords(GetEntityCoords(cache.ped)) + (Config.TempFeature and getWarmth(cache.ped) or 0)

            if Config.TempFormat == 'fahrenheit' then
                temp = math.floor(tempC * 9 / 5 + 32)
                temperature = temp .. '°F'
            else
                temp = math.floor(tempC)
                temperature = temp .. '°C'
            end
        end
    end
end)

exports('GetCurrentTemperature', function()
    return temp
end)

------------------------------------------------
-- outlaw status
------------------------------------------------
CreateThread(function()
    while true do
        if LocalPlayer.state.isLoggedIn then
            RSGCore.Functions.TriggerCallback('hud:server:getoutlawstatus', function(result)
                outlawstatus = tonumber(result) or 0
            end)
        end
        Wait(30000)
    end
end)

exports('GetOutlawStatus', function()
    return outlawstatus or 0
end)

------------------------------------------------
-- health / needs decay loop
------------------------------------------------
local DOWNED_FX = 'MP_Downed'

local function setDamageFx(active)
    local running = Citizen.InvokeNative(0x4A123E85D7C4CA0B, DOWNED_FX) -- AnimpostfxIsRunning
    if active and Config.DoHealthDamageFx and not running then
        Citizen.InvokeNative(0x4102732DF6B4005F, DOWNED_FX, 0, true) -- AnimpostfxPlay
    elseif not active and running then
        Citizen.InvokeNative(0xB4FD7446BAB2F394, DOWNED_FX) -- AnimpostfxStop
    end
end

CreateThread(function()
    repeat Wait(100) until LocalPlayer.state.isLoggedIn

    while true do
        Wait(Config.StatusInterval)

        if LocalPlayer.state.isLoggedIn and not isDead() then
            local state = LocalPlayer.state
            local ped = cache.ped

            -- cleanliness follows the ped's dirt level
            updateNeed('cleanliness', 100 - getDirt(ped))

            if Config.FlyEffect then
                updateFlies(state.cleanliness or 100)
            end

            if Config.DoHealthDamage then
                local hurt, painType = false, 9

                if (state.hunger or 100) <= 0 or (state.thirst or 100) <= 0 then
                    hurt = true
                    -- hunger/thirst damage is random
                    SetEntityHealth(ped, math.max(0, GetEntityHealth(ped) - math.random(5, 10)))
                    if Config.DoHealthPainSound then PlayPain(ped, 9, 1, true, true) end
                end

                local extreme = Config.TempFeature and (tempC < Config.MinTemp or tempC > Config.MaxTemp)
                local dirty = (state.cleanliness or 100) <= 0

                if extreme or dirty then
                    hurt = true
                    if dirty and not extreme then painType = 12 end
                    if Config.DoHealthPainSound then
                        PlayPain(ped, painType, 1, true, true)
                    end
                    SetEntityHealth(ped, math.max(0, GetEntityHealth(ped) - Config.RemoveHealth))
                end

                setDamageFx(hurt)
            end

            updateNeed('hunger', Config.HungerRate, true)
            updateNeed('thirst', Config.ThirstRate, true)
            updateNeed('stress', Config.StressDecayRate, true)
        end
    end
end)

------------------------------------------------
-- player hud (only sends to NUI when something changed)
------------------------------------------------
local lastPayload = nil

local function samePayload(a, b)
    if not a then return false end
    for k, v in pairs(b) do
        if a[k] ~= v then return false end
    end
    for k in pairs(a) do
        if b[k] == nil then return false end
    end
    return true
end

local function round(v)
    return math.floor(v + 0.5)
end

CreateThread(function()
    while true do
        Wait(500)
        local payload

        if LocalPlayer.state.isLoggedIn and showUI and not IsCinematicCamRendering()
            and not LocalPlayer.state.isBathingActive and not LocalPlayer.state.inClothingStore
            and not IsPauseMenuActive() then

            local ped = cache.ped
            local mounted = IsPedOnMount(ped)
            local horsehealth, horsestamina, horseclean = 0, 0, 0

            if mounted then
                local horse = GetMount(ped)
                local maxHealth = Citizen.InvokeNative(0x4700A416E8324EF3, horse, Citizen.ResultAsInteger())
                local maxStamina = Citizen.InvokeNative(0xCB42AFE2B613EE55, horse, Citizen.ResultAsFloat())
                horseclean = 100 - getDirt(horse)
                if maxHealth and maxHealth > 0 then
                    horsehealth = round(Citizen.InvokeNative(0x82368787EA73C0F7, horse) / maxHealth * 100)
                end
                if maxStamina and maxStamina > 0 then
                    horsestamina = round(Citizen.InvokeNative(0x775A1CA7893AA8B5, horse, Citizen.ResultAsFloat()) / maxStamina * 100)
                end
            end

            local maxHealth = GetEntityMaxHealth(ped)

            payload = {
                action = 'hudtick',
                show = true,
                health = maxHealth > 0 and round(GetEntityHealth(ped) / maxHealth * 100) or 0,
                stamina = round(Citizen.InvokeNative(0x0FF421E467373FCF, cache.playerId, Citizen.ResultAsFloat())),
                thirst = LocalPlayer.state.thirst or 100,
                hunger = LocalPlayer.state.hunger or 100,
                cleanliness = LocalPlayer.state.cleanliness or 100,
                stress = LocalPlayer.state.stress or 0,
                talking = Citizen.InvokeNative(0x33EEF97F, cache.playerId) and true or false,
                temp = temperature,
                onHorse = mounted,
                horsehealth = horsehealth,
                horsestamina = horsestamina,
                horseclean = horseclean,
                youhavemail = (LocalPlayer.state.telegramUnreadMessages or 0) > 0,
                outlawstatus = outlawstatus,
            }
        else
            payload = { action = 'hudtick', show = false }
        end

        if not samePayload(lastPayload, payload) then
            lastPayload = payload
            SendNUIMessage(payload)
        end
    end
end)

------------------------------------------------
-- minimap
------------------------------------------------
local lastInterior = nil

CreateThread(function()
    while true do
        Wait(500)
        local mapType = 0

        if IsPedOnMount(cache.ped) or IsPedInAnyVehicle(cache.ped, false) or LocalPlayer.state.telegramIsBirdPostApproaching then
            if Config.MountMinimap and showUI then
                mapType = Config.MountCompass and 3 or 1
            end
        elseif showUI then
            if Config.OnFootMinimap then
                mapType = 1
                local inside = GetInteriorFromEntity(cache.ped) ~= 0
                if inside ~= lastInterior then
                    lastInterior = inside
                    SetRadarConfigType(inside and 0xDF5DB58C or 0x25B517BF, 0) -- zoom in inside interiors
                end
            elseif Config.OnFootCompass then
                mapType = 3
            end
        end

        SetMinimapType(mapType)
    end
end)

------------------------------------------------
-- money hud
------------------------------------------------
local accountTypes = { cash = true, bloodmoney = true, bank = true }

RegisterNetEvent('hud:client:ShowAccounts', function(type, amount)
    if not accountTypes[type] or not amount then return end
    SendNUIMessage({ action = 'show', type = type, [type] = lib.math.round(tonumber(amount) or 0, 2) })
end)

RegisterNetEvent('hud:client:OnMoneyChange', function(type, amount, isMinus)
    local playerData = RSGCore.Functions.GetPlayerData()
    if not playerData or not playerData.money then return end

    SendNUIMessage({
        action = 'update',
        cash = lib.math.round(playerData.money.cash or 0, 2),
        bloodmoney = lib.math.round(playerData.money.bloodmoney or 0, 2),
        bank = lib.math.round(playerData.money.bank or 0, 2),
        amount = lib.math.round(amount or 0, 2),
        minus = isMinus,
        type = type,
    })
end)

------------------------------------------------
-- hud edit mode
------------------------------------------------
local function setEditMode(enabled)
    editMode = enabled
    SendNUIMessage({ action = 'toggleEditMode', enabled = enabled })
    SetNuiFocus(enabled, enabled)
    if enabled then SetNuiFocusKeepInput(false) end

    lib.notify({
        title = locale('edit_mode_on_title'),
        description = locale(enabled and 'edit_mode_on_desc' or 'edit_mode_off_desc'),
        type = enabled and 'success' or 'inform',
        duration = enabled and 5000 or 3000
    })
end

RegisterNetEvent('hud:client:ToggleEditMode', function()
    setEditMode(not editMode)
end)

RegisterCommand('edithud', function()
    setEditMode(not editMode)
end, false)

RegisterCommand('togglehudpct', function()
    SendNUIMessage({ action = 'togglePercentages' })
end, false)

RegisterCommand('resethud', function()
    SendNUIMessage({ action = 'resetPositions' })
    lib.notify({
        title = locale('reset_hud_title'),
        description = locale('reset_hud_desc'),
        type = 'success',
        duration = 3000
    })
end, false)

-- ESC pressed in NUI
RegisterNUICallback('disableEditMode', function(_, cb)
    if editMode then setEditMode(false) end
    cb('ok')
end)

------------------------------------------------
-- exports (for external scripts)
------------------------------------------------
local NEEDS = { hunger = true, thirst = true, cleanliness = true, stress = true }

exports('GetNeeds', function()
    local s = LocalPlayer.state
    return { hunger = s.hunger or 100, thirst = s.thirst or 100, cleanliness = s.cleanliness or 100, stress = s.stress or 0 }
end)

exports('GetNeed', function(key)
    if not NEEDS[key] then return nil end
    return LocalPlayer.state[key] or (key == 'stress' and 0 or 100)
end)

-- set a need to an absolute value (0-100)
exports('SetNeed', function(key, value)
    value = tonumber(value)
    if not NEEDS[key] or not value then return false end
    updateNeed(key, value)
    return true
end)

-- add (positive) or remove (negative) from a need
exports('AddNeed', function(key, amount)
    amount = tonumber(amount)
    if not NEEDS[key] or not amount then return false end
    updateNeed(key, (LocalPlayer.state[key] or 0) + amount)
    return true
end)

exports('GainStress', function(amount) updateStress(amount, true) end)
exports('RelieveStress', function(amount) updateStress(amount, false) end)

exports('SetHudVisible', function(visible) showUI = visible and true or false end)
exports('IsHudVisible', function() return showUI end)
exports('ToggleEditMode', function(enabled)
    if enabled == nil then enabled = not editMode end
    setEditMode(enabled and true or false)
end)
exports('IsEditMode', function() return editMode end)

------------------------------------------------
-- cleanup
------------------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    removeFlies()
    setDamageFx(false)
    StopGameplayCamShaking(true)
    if editMode then SetNuiFocus(false, false) end
end)
