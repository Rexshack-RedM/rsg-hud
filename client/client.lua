local RSGCore = exports['rsg-core']:GetCoreObject()
local speed = 0.0
local radarActive = false
local stress = 0
local hunger = 100
local thirst = 100
local cashAmount = 0
local bankAmount = 0
local isLoggedIn = false
local youhavemail = false
local incinematic = false
local inBathing = false
local showUI = true
local temperature = 0
local temp = 0
local tempadd = 0

RegisterNetEvent("HideAllUI")
AddEventHandler("HideAllUI", function()
    showUI = not showUI
end)

-- functions
local function GetShakeIntensity(stresslevel)
    local retval = 0.05
    for _, v in pairs(Config.Intensity['shake']) do
        if stresslevel >= v.min and stresslevel <= v.max then
            retval = v.intensity
            break
        end
    end
    return retval
end

local function GetEffectInterval(stresslevel)
    local retval = 60000
    for _, v in pairs(Config.EffectInterval) do
        if stresslevel >= v.min and stresslevel <= v.max then
            retval = v.timeout
            break
        end
    end
    return retval
end

-- Events

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    isLoggedIn = false
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    isLoggedIn = true
end)

RegisterNetEvent('hud:client:UpdateNeeds', function(newHunger, newThirst, newCleanliness)
    hunger = newHunger
    thirst = newThirst
    cleanliness = newCleanliness
end)

RegisterNetEvent('hud:client:UpdateThirst', function(newThirst)
    thirst = newThirst
end)

RegisterNetEvent('hud:client:UpdateStress', function(newStress)
    stress = newStress
end)

-- Player HUD
CreateThread(function()
    while true do
        Wait(500)
        if LocalPlayer.state['isLoggedIn'] and incinematic == false and inBathing == false and showUI then
            local show = true
            local player = PlayerPedId()
            local playerid = PlayerId()
            local coords = GetEntityCoords(player)
            local stamina = tonumber(string.format("%.2f", Citizen.InvokeNative(0x0FF421E467373FCF, PlayerId(), Citizen.ResultAsFloat())))
            local mounted = IsPedOnMount(PlayerPedId())
            if metric then
                temperature = math.floor(GetTemperatureAtCoords(coords)) .. "°C" --Uncomment for celcius
                --temperature = math.floor(GetTemperatureAtCoords(coords) * 9/5 + 32) .. "°F" --Comment out for celcius 
            end
            ---@type any
            local horsehealth = 0 
            
            ---@type any
            local horsestam = 0 

            if mounted then
                local horse = GetMount(PlayerPedId())
                local maxHealth = Citizen.InvokeNative(0x4700A416E8324EF3, horse, Citizen.ResultAsInteger())
                local maxStamina = Citizen.InvokeNative(0xCB42AFE2B613EE55, horse, Citizen.ResultAsFloat())
                horsehealth = tonumber(
                    string.format(
                        "%.2f", Citizen.InvokeNative(0x82368787EA73C0F7, horse) / maxHealth * 100 
                    )
                )
                horsestam = tonumber(
                    string.format(
                        "%.2f", Citizen.InvokeNative(0x775A1CA7893AA8B5, horse, Citizen.ResultAsFloat()) / maxStamina * 100
                    )
                )
            end
            if IsPauseMenuActive() then
                show = false
            end

            local voice = 0
            local talking = Citizen.InvokeNative(0x33EEF97F, playerid)
            if LocalPlayer.state['proximity'] then
                voice = LocalPlayer.state['proximity'].distance
            end

            SendNUIMessage({
                action = 'hudtick',
                show = show,
                health = GetEntityHealth(player) / 6, -- health in red dead max health is 600 so dividing by 6 makes it 100 here
                stamina = stamina,
                armor = Citizen.InvokeNative(0x2CE311A7, player),
                thirst = thirst,
                hunger = hunger,
                cleanliness = cleanliness,
                stress = stress,
                talking = talking,
                horsehealth = horsehealth,
                horsestamina = horsestam,
                onHorse = mounted,
                temp = temperature,
                voice = voice,
                youhavemail = youhavemail,
            })
        else
            SendNUIMessage({
                action = 'hudtick',
                show = false,
            })
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1000)

        local ped = PlayerPedId()
        local isMounted = IsPedOnMount(ped) or IsPedInAnyVehicle(ped)
        local IsBirdPostApproaching = exports['rsg-telegram']:IsBirdPostApproaching()

        if isMounted or IsBirdPostApproaching then
            if Config.MounttMinimap and showUI then
                if Config.MountCompass then
                    SetMinimapType(3)
                else
                    SetMinimapType(1)
                end
            else
                SetMinimapType(0)
            end
        else
            if Config.OnFootMinimap and showUI then
                SetMinimapType(1)
            else
                if Config.OnFootCompass and showUI then
                    SetMinimapType(3)
                else
                    SetMinimapType(0)
                end
            end
        end
    end
end)

-- work out temperature
CreateThread(function()
    while true do
        Wait(1000)

        local player = PlayerPedId()
        local coords = GetEntityCoords(player)

        -- wearing
        local hat      = Citizen.InvokeNative(0xFB4891BD7578CDC1, player, 0x9925C067) -- hat
        local shirt    = Citizen.InvokeNative(0xFB4891BD7578CDC1, player, 0x2026C46D) -- shirt
        local pants    = Citizen.InvokeNative(0xFB4891BD7578CDC1, player, 0x1D4C528A) -- pants
        local boots    = Citizen.InvokeNative(0xFB4891BD7578CDC1, player, 0x777EC6EF) -- boots
        local coat     = Citizen.InvokeNative(0xFB4891BD7578CDC1, player, 0xE06D30CE) -- coat
        local opencoat = Citizen.InvokeNative(0xFB4891BD7578CDC1, player, 0x662AC34) -- open-coat
        local gloves   = Citizen.InvokeNative(0xFB4891BD7578CDC1, player, 0xEABE0032) -- gloves
        local vest     = Citizen.InvokeNative(0xFB4891BD7578CDC1, player, 0x485EE834) -- vest
        local poncho   = Citizen.InvokeNative(0xFB4891BD7578CDC1, player, 0xAF14310B) -- poncho
        local skirts   = Citizen.InvokeNative(0xFB4891BD7578CDC1, player, 0xA0E3AB7F) -- skirts
        local chaps    = Citizen.InvokeNative(0xFB4891BD7578CDC1, player, 0x3107499B) -- chaps
        
        -- get temp add
        if hat      == 1 then what      = Config.WearingHat      else what      = 0 end
        if shirt    == 1 then wshirt    = Config.WearingShirt    else wshirt    = 0 end
        if pants    == 1 then wpants    = Config.WearingPants    else wpants    = 0 end
        if boots    == 1 then wboots    = Config.WearingBoots    else wboots    = 0 end
        if coat     == 1 then wcoat     = Config.WearingCoat     else wcoat     = 0 end
        if opencoat == 1 then wopencoat = Config.WearingOpenCoat else wopencoat = 0 end
        if gloves   == 1 then wgloves   = Config.WearingGloves   else wgloves   = 0 end
        if vest     == 1 then wvest     = Config.WearingVest     else wvest     = 0 end
        if poncho   == 1 then wponcho   = Config.WearingPoncho   else wponcho   = 0 end
        if skirts   == 1 then wskirts   = Config.WearingSkirt    else wskirts   = 0 end
        if chaps    == 1 then wchaps    = Config.WearingChaps    else wchaps    = 0 end
        
        local tempadd = (what + wshirt + wpants + wboots + wcoat + wopencoat + wgloves + wvest + wponcho + wskirts + wchaps)
        
        if Config.TempFormat == 'celsius' then
            temperature = math.floor(GetTemperatureAtCoords(coords)) + tempadd .. "°C" --Uncomment for celcius
            temp = math.floor(GetTemperatureAtCoords(coords)) + tempadd
        end
        if Config.TempFormat == 'fahrenheit' then
            temperature = math.floor(GetTemperatureAtCoords(coords) * 9/5 + 32) + tempadd .. "°F" --Comment out for celcius
            temp = math.floor(GetTemperatureAtCoords(coords) * 9/5 + 32) + tempadd
        end
   
    end
end)

-- health/cleanliness damage
Citizen.CreateThread(function()
    while true do
        Wait(5000)
        if isLoggedIn and Config.DoHealthDamage then
            player = PlayerPedId()
            health = GetEntityHealth(player)

            -- cold health damage
            if temp < Config.MinTemp then 
                PlayPain(player, 9, 1, true, true)
                SetEntityHealth(player, health - Config.RemoveHealth)
                if Config.DoHealthDamageFx then
                    Citizen.InvokeNative(0x4102732DF6B4005F, "MP_Downed", 0, true) -- AnimpostfxPlay
                end
            elseif Citizen.InvokeNative(0x4A123E85D7C4CA0B, "MP_Downed") and Config.DoHealthDamageFx then -- AnimpostfxIsRunning
                Citizen.InvokeNative(0xB4FD7446BAB2F394, "MP_Downed") -- AnimpostfxStop
            end
            
            -- hot health damage
            if temp > Config.MaxTemp then
                PlayPain(player, 9, 1, true, true)
                SetEntityHealth(player, health - Config.RemoveHealth)
                if Config.DoHealthDamageFx then
                    Citizen.InvokeNative(0x4102732DF6B4005F, "MP_Downed", 0, true) -- AnimpostfxPlay
                end
            elseif Citizen.InvokeNative(0x4A123E85D7C4CA0B, "MP_Downed") and Config.DoHealthDamageFx then -- AnimpostfxIsRunning
                Citizen.InvokeNative(0xB4FD7446BAB2F394, "MP_Downed") -- AnimpostfxStop
            end

            -- cleanliness health damage
            if cleanliness < Config.MinCleanliness then
                PlayPain(player, 9, 1, true, true)
                SetEntityHealth(player, health - Config.RemoveHealth)
                if Config.DoHealthDamageFx then
                    Citizen.InvokeNative(0x4102732DF6B4005F, "MP_Downed", 0, true) -- AnimpostfxPlay
                end
            elseif Citizen.InvokeNative(0x4A123E85D7C4CA0B, "MP_Downed") and Config.DoHealthDamageFx then -- AnimpostfxIsRunning
                Citizen.InvokeNative(0xB4FD7446BAB2F394, "MP_Downed") -- AnimpostfxStop
            end

        end
    end
end)

-- Money HUD
RegisterNetEvent('hud:client:ShowAccounts', function(type, amount)
    if type == 'cash' then
        SendNUIMessage({
            action = 'show',
            type = 'cash',
            cash = string.format("%.2f", amount)
        })
    elseif type == 'bloodmoney' then
        SendNUIMessage({
            action = 'show',
            type = 'bloodmoney',
            bloodmoney = string.format("%.2f", amount)
        })
    elseif type == 'bank' then
        SendNUIMessage({
            action = 'show',
            type = 'bank',
            bank = string.format("%.2f", amount)
        })
    end
end)

RegisterNetEvent('hud:client:OnMoneyChange', function(type, amount, isMinus)
    RSGCore.Functions.GetPlayerData(function(PlayerData)
        cashAmount = PlayerData.money['cash']
        bloodmoneyAmount = PlayerData.money['bloodmoney']
        bankAmount = PlayerData.money['bank']
    end)
    SendNUIMessage({
        action = 'update',
        cash = RSGCore.Shared.Round(cashAmount, 2),
        bloodmoney = RSGCore.Shared.Round(bloodmoneyAmount, 2),
        bank = RSGCore.Shared.Round(bankAmount, 2),
        amount = RSGCore.Shared.Round(amount, 2),
        minus = isMinus,
        type = type,
    })
end)

-- Stress Gain

CreateThread(function() -- Speeding
    while true do
        if RSGCore ~= nil --[[ and isLoggedIn ]] then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                speed = GetEntitySpeed(GetVehiclePedIsIn(ped, false)) * 2.237 --mph
                if speed >= Config.MinimumSpeed then
                    TriggerServerEvent('hud:server:GainStress', math.random(1, 3))
                end
            end
        end
        Wait(20000)
    end
end)

CreateThread(function() -- Shooting
    while true do
        if RSGCore ~= nil --[[ and isLoggedIn ]] then
            if IsPedShooting(PlayerPedId()) then
                if math.random() < Config.StressChance then
                    TriggerServerEvent('hud:server:GainStress', math.random(1, 3))
                end
            end
        end
        Wait(6)
    end
end)

-- Stress Screen Effects
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local sleep = GetEffectInterval(stress)

        if stress >= 100 then
            local ShakeIntensity = GetShakeIntensity(stress)
            local FallRepeat = math.random(2, 4)
            local RagdollTimeout = (FallRepeat * 1750)
            ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', ShakeIntensity)

            if not IsPedRagdoll(ped) and IsPedOnFoot(ped) and not IsPedSwimming(ped) then
                local player = PlayerPedId()
                SetPedToRagdollWithFall(player, RagdollTimeout, RagdollTimeout, 1, GetEntityForwardVector(player), 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
            end

            Wait(500)
            for i = 1, FallRepeat, 1 do
                Wait(750)
                DoScreenFadeOut(200)
                Wait(1000)
                DoScreenFadeIn(200)
                ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', ShakeIntensity)
            end
        elseif stress >= Config.MinimumStress then
            local ShakeIntensity = GetShakeIntensity(stress)
            ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', ShakeIntensity)
        end
        Wait(sleep)
    end
end)

-- check telegrams
CreateThread(function()
    while true do
        if isLoggedIn == true then
            RSGCore.Functions.TriggerCallback('hud:server:getTelegramsAmount', function(amount)
                if amount > 0 then
                    youhavemail = true
                else
                    youhavemail = false
                end
            end)
        end
        Wait(Config.TelegramCheck)
    end
end)

-- check cinematic and hide hud
CreateThread(function()
    while true do
        if LocalPlayer.state['isLoggedIn'] then
            local cinematic = Citizen.InvokeNative(0xBF7C780731AADBF8, Citizen.ResultAsInteger())
            local isBathingActive = exports['rsg-bathing']:IsBathingActive()

            if cinematic == 1 then
                incinematic = true
            else
                incinematic = false
            end

            if isBathingActive then
                inBathing = true
            else
                inBathing = false
            end
        end

        Wait(500)
    end
end)
