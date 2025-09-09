local RSGCore = exports['rsg-core']:GetCoreObject()


local showUI, temperature, temp = true, "0°C", 0
local outlawstatus, cashAmount, bloodmoneyAmount, bankAmount = 0, 0, 0, 0

local function clampRound(val, min, max)
    return lib.math.clamp(lib.math.round(val or 0, 2), min, max)
end

local function updateNeed(key, value, reduce)
    local cur = LocalPlayer.state[key] or 0
    if reduce then value = cur - (value or 0) end
    local newVal = clampRound(value, 0, 100)
    if LocalPlayer.state[key] ~= newVal then
        LocalPlayer.state:set(key, newVal, true)
    end
end

local function waitForLogin()
    while not LocalPlayer.state.isLoggedIn do Wait(100) end
end

local function waitForMoneyData()
    waitForLogin()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    while not (PlayerData and PlayerData.money and PlayerData.money.cash ~= nil) do
        Wait(100)
        PlayerData = RSGCore.Functions.GetPlayerData()
    end
    return PlayerData
end

local function updateMinimap()
    local isMounted = cache.mount and cache.mount ~= 0 and cache.mount ~= false
    local inVehicle = cache.vehicle and cache.vehicle ~= 0 and cache.vehicle ~= false
    local approachingBirdPost = LocalPlayer.state.telegramIsBirdPostApproaching or false

    if (isMounted or inVehicle or approachingBirdPost) then
        if Config.MountMinimap and showUI then
            SetMinimapType(Config.MountCompass and 3 or 1)
        else
            SetMinimapType(0)
        end
    else
        if Config.OnFootMinimap and showUI then
            SetMinimapType(1)
            if GetInteriorFromEntity(cache.ped) ~= 0 then
                SetRadarConfigType(0xDF5DB58C, 0)
            else
                SetRadarConfigType(0x25B517BF, 0)
            end
        else
            SetMinimapType((Config.OnFootCompass and showUI) and 3 or 0)
        end
    end
end

RegisterNetEvent("HideAllUI", function()
    showUI = not showUI
    updateMinimap()
end)

lib.onCache('mount', updateMinimap)
lib.onCache('vehicle', updateMinimap)

CreateThread(function()
    while true do
        Wait(30000)
        RSGCore.Functions.TriggerCallback('hud:server:getoutlawstatus', function(result)
            if result and result[1] and result[1].outlawstatus ~= nil then
                outlawstatus = result[1].outlawstatus
            end
        end)
    end
end)

RegisterNetEvent('hud:client:UpdateNeeds', function(h, t, c)
    local cleanStats = Citizen.InvokeNative(0x147149F2E909323C, cache.ped, 16, Citizen.ResultAsInteger())
    updateNeed('hunger', h)
    updateNeed('thirst', t)
    updateNeed('cleanliness', (c or 100) - cleanStats)
end)

RegisterNetEvent('hud:client:UpdateHunger',      function(v) updateNeed('hunger', v) end)
RegisterNetEvent('hud:client:UpdateThirst',      function(v) updateNeed('thirst', v) end)
RegisterNetEvent('hud:client:UpdateStress',      function(v) updateNeed('stress', v) end)
RegisterNetEvent('hud:client:UpdateCleanliness', function(v)
    local cleanStats = Citizen.InvokeNative(0x147149F2E909323C, cache.ped, 16, Citizen.ResultAsInteger())
    updateNeed('cleanliness', (v or 100) - cleanStats)
end)

local function updateStress(amount, isGain)
    RSGCore.Functions.GetPlayerData(function(PlayerData)
        if PlayerData and not PlayerData.metadata['isdead'] and (isGain or PlayerData.job.type ~= 'leo') then
            local current = LocalPlayer.state.stress or 0
            local nextVal = clampRound(current + (isGain and amount or -amount), 0, 100)
            LocalPlayer.state:set('stress', nextVal, true)
            lib.notify({ title = isGain and locale('sv_lang_1') or locale('sv_lang_3'), type = 'inform', duration = 5000 })
        end
    end)
end

RegisterNetEvent('hud:client:GainStress',    function(a) updateStress(a or 1,  true) end)
RegisterNetEvent('hud:client:RelieveStress', function(a) updateStress(a or 1, false) end)

CreateThread(function()
    while true do
        Wait(10000)
        if IsPedInAnyVehicle(cache.ped, false) then
            local speed = GetEntitySpeed(GetVehiclePedIsIn(cache.ped, false)) * 2.237
            if speed >= Config.MinimumSpeed then
                TriggerEvent('hud:client:GainStress', math.random(1, 3))
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(6)
        if IsPedShooting(cache.ped) and math.random() < Config.StressChance then
            TriggerEvent('hud:client:GainStress', math.random(1, 3))
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        local coords = GetEntityCoords(cache.ped)
        local clothingBonus = 0
        local clothingConfig = {
            { 0x9925C067, Config.WearingHat }, { 0x2026C46D, Config.WearingShirt },
            { 0x1D4C528A, Config.WearingPants }, { 0x777EC6EF, Config.WearingBoots },
            { 0xE06D30CE, Config.WearingCoat }, { 0x662AC34, Config.WearingOpenCoat },
            { 0xEABE0032, Config.WearingGloves }, { 0x485EE834, Config.WearingVest },
            { 0xAF14310B, Config.WearingPoncho }, { 0xA0E3AB7F, Config.WearingSkirt },
            { 0x3107499B, Config.WearingChaps },
        }
        for _, item in ipairs(clothingConfig) do
            if Citizen.InvokeNative(0xFB4891BD7578CDC1, cache.ped, item[1]) == 1 then
                clothingBonus += item[2]
            end
        end
        if Config.TempFormat == 'celsius' then
            temp = math.floor(GetTemperatureAtCoords(coords)) + clothingBonus
            temperature = ("%d°C"):format(temp)
        else
            temp = math.floor(GetTemperatureAtCoords(coords) * 9/5 + 32) + clothingBonus
            temperature = ("%d°F"):format(temp)
        end
    end
end)

CreateThread(function()
    waitForLogin()
    while true do
        Wait(Config.StatusInterval)
        local pd = RSGCore.Functions.GetPlayerData()
        if LocalPlayer.state.isLoggedIn and pd and not pd.metadata['isdead'] then
            local s, health = LocalPlayer.state, GetEntityHealth(cache.ped)
            if (s.hunger or 100) <= 0 or (s.thirst or 100) <= 0 or temp < Config.MinTemp or temp > Config.MaxTemp or (s.cleanliness or 100) <= 0 then
                if Config.DoHealthDamageFx then
                    Citizen.InvokeNative(0x4102732DF6B4005F, "MP_Downed", 0, true)
                end
                if Config.DoHealthPainSound then
                    PlayPain(cache.ped, 9, 1, true, true)
                end
                SetEntityHealth(cache.ped, math.max(0, health - Config.RemoveHealth))
            end
            updateNeed('hunger',      Config.HungerRate,      true)
            updateNeed('thirst',      Config.ThirstRate,      true)
            updateNeed('cleanliness', Config.CleanlinessRate, true)
            updateNeed('stress',      Config.StressDecayRate, true)
        end
    end
end)

local myBag = ('player:%s'):format(cache.serverId)
AddStateBagChangeHandler('money', myBag, function(_, _, value, _, replicated)
    if not replicated or not value then return end
    cashAmount, bloodmoneyAmount, bankAmount = value.cash or 0, value.bloodmoney or 0, value.bank or 0
    SendNUIMessage({
        action     = 'update',
        cash       = lib.math.round(cashAmount, 2),
        bloodmoney = lib.math.round(bloodmoneyAmount, 2),
            bank       = lib.math.round(bankAmount, 2),
    amount     = 0,
    minus      = false,
    type       = 'sync',
})
end)

RegisterNetEvent('hud:client:OnMoneyChange', function(type, amount, isMinus)
    local pd = waitForMoneyData()
    cashAmount       = pd.money.cash or 0
    bloodmoneyAmount = pd.money.bloodmoney or 0
    bankAmount       = pd.money.bank or 0
    SendNUIMessage({
        action     = 'update',
        cash       = lib.math.round(cashAmount, 2),
        bloodmoney = lib.math.round(bloodmoneyAmount, 2),
        bank       = lib.math.round(bankAmount, 2),
        amount     = lib.math.round(amount or 0, 2),
        minus      = isMinus or false,
        type       = type or "unknown",
    })
end)

RegisterNetEvent('hud:client:ShowAccounts', function(type, amount)
    SendNUIMessage({
        action = 'show',
        type   = type,
        [type] = string.format("%.2f", amount or 0)
    })
end)

CreateThread(function()
    while true do
        Wait(500)
        local canShow = LocalPlayer.state.isLoggedIn and showUI and not IsCinematicCamRendering()
            and not LocalPlayer.state.isBathingActive and not LocalPlayer.state.inClothingStore

        if canShow then
            local stamina = tonumber(string.format("%.2f", Citizen.InvokeNative(0x0FF421E467373FCF, cache.playerId, Citizen.ResultAsFloat())))
            local mounted = cache.mount and cache.mount ~= 0 and cache.mount ~= false
            local talking = Citizen.InvokeNative(0x33EEF97F, cache.playerId)
            local voice   = (LocalPlayer.state['proximity'] and LocalPlayer.state['proximity'].distance) or 0

            local horsehealth, horsestamina, horseclean = 0, 0, 0
            if mounted then
                local horse = cache.mount
                local maxHealth  = Citizen.InvokeNative(0x4700A416E8324EF3, horse, Citizen.ResultAsInteger())
                local maxStamina = Citizen.InvokeNative(0xCB42AFE2B613EE55, horse, Citizen.ResultAsFloat())
                local hClean     = Citizen.InvokeNative(0x147149F2E909323C, horse, 16, Citizen.ResultAsInteger())
                horseclean       = hClean == 0 and 100 or 100 - hClean
                horsehealth      = tonumber(string.format("%.2f", Citizen.InvokeNative(0x82368787EA73C0F7, horse) / math.max(1, maxHealth) * 100))
                horsestamina     = tonumber(string.format("%.2f", Citizen.InvokeNative(0x775A1CA7893AA8B5, horse, Citizen.ResultAsFloat()) / math.max(0.001, maxStamina) * 100))
            end

            SendNUIMessage({
                action       = 'hudtick',
                show         = true,
                health       = GetEntityHealth(cache.ped) / 6,
                stamina      = stamina,
                armor        = Citizen.InvokeNative(0x2CE311A7, cache.ped),
                thirst       = LocalPlayer.state.thirst or 100,
                hunger       = LocalPlayer.state.hunger or 100,
                cleanliness  = LocalPlayer.state.cleanliness or 100,
                stress       = LocalPlayer.state.stress or 0,
                talking      = talking,
                temp         = temperature,
                onHorse      = mounted,
                horsehealth  = horsehealth,
                horsestamina = horsestamina,
                horseclean   = horseclean,
                voice        = voice,
                youhavemail  = (LocalPlayer.state.telegramUnreadMessages or 0) > 0,
                outlawstatus = outlawstatus,
            })
        else
            SendNUIMessage({ action = 'hudtick', show = false })
        end
    end
end)
