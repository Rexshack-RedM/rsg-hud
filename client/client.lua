local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local speed = 0.0
local cashAmount = 0
local bloodmoneyAmount = 0
local bankAmount = 0
local showUI = true
local temperature = 0
local temp = 0
local tempadd = 0
-- local outlawstatus = 0

------------------------------------------------
-- send locales to NUI
------------------------------------------------
local function sendLocalesToNUI()
    local locales = {
        edit_mode_on_title = locale('edit_mode_on_title'),
        edit_mode_on_desc = locale('edit_mode_on_desc'),
        edit_mode_off_desc = locale('edit_mode_off_desc'),
        reset_hud_title = locale('reset_hud_title'),
        reset_hud_desc = locale('reset_hud_desc'),
        money_hud_label = locale('money_hud_label'),
        temp_label = locale('temp_label'),
        health_label = locale('health_label'),
        stamina_label = locale('stamina_label'),
        hunger_label = locale('hunger_label'),
        thirst_label = locale('thirst_label'),
        clean_label = locale('clean_label'),
        stress_label = locale('stress_label'),
        mail_label = locale('mail_label'),
        horse_health_label = locale('horse_health_label'),
        horse_stamina_label = locale('horse_stamina_label'),
        horse_clean_label = locale('horse_clean_label')
    }
    
    SendNUIMessage({
        action = 'setLocales',
        locales = locales
    })
end

-- Send locales when resource starts
CreateThread(function()
    Wait(1000)
    sendLocalesToNUI()
end)

------------------------------------------------
-- hide ui
------------------------------------------------
RegisterNetEvent("HideAllUI")
AddEventHandler("HideAllUI", function()
    showUI = not showUI
end)

------------------------------------------------
-- hud display settings
------------------------------------------------
Citizen.CreateThread(function()

    if Config.HidePlayerHealthNative then
        Citizen.InvokeNative(0xC116E6DF68DCE667, 4, 2) -- ICON_HEALTH / HIDE
        Citizen.InvokeNative(0xC116E6DF68DCE667, 5, 2) -- ICON_HEALTH_CORE / HIDE
    end

    if Config.HidePlayerStaminaNative then
        Citizen.InvokeNative(0xC116E6DF68DCE667, 0, 2) -- ICON_STAMINA / HIDE
        Citizen.InvokeNative(0xC116E6DF68DCE667, 1, 2) -- ICON_STAMINA_CORE / HIDE
    end

    if Config.HidePlayerDeadEyeNative then
        Citizen.InvokeNative(0xC116E6DF68DCE667, 2, 2) -- ICON_DEADEYE / HIDE
        Citizen.InvokeNative(0xC116E6DF68DCE667, 3, 2) -- ICON_DEADEYE_CORE / HIDE
    end

    if Config.HideHorseHealthNative then
        Citizen.InvokeNative(0xC116E6DF68DCE667, 6, 2) -- ICON_HORSE_HEALTH / HIDE
        Citizen.InvokeNative(0xC116E6DF68DCE667, 7, 2) -- ICON_HORSE_HEALTH_CORE / HIDE
    end

    if Config.HideHorseStaminaNative then
        Citizen.InvokeNative(0xC116E6DF68DCE667, 8, 2) -- ICON_HORSE_STAMINA / HIDE
        Citizen.InvokeNative(0xC116E6DF68DCE667, 9, 2) -- ICON_HORSE_STAMINA_CORE / HIDE
    end

    if Config.HideHorseCourageNative then
        Citizen.InvokeNative(0xC116E6DF68DCE667, 10, 2) -- ICON_HORSE_COURAGE / HIDE
        Citizen.InvokeNative(0xC116E6DF68DCE667, 11, 2) -- ICON_HORSE_COURAGE_CORE / HIDE
    end

end)

------------------------------------------------
-- functions
------------------------------------------------
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

local function updateNeed(key, value, reduce)
    if reduce then
        value = LocalPlayer.state[key] - value
    end

    value = lib.math.clamp(lib.math.round(value, 2), 0, 100)
    if LocalPlayer.state[key] ~= value then
        LocalPlayer.state:set(key, value, true)
    end
end

------------------------------------------------
-- flies when not clean (Config.MinCleanliness)
------------------------------------------------
local current_ptfx_handle_id = false
local is_particle_effect_active = false

local FliesSpawn = function (clean)
    local new_ptfx_dictionary = "scr_mg_cleaning_stalls"
    local new_ptfx_name = "scr_mg_stalls_manure_flies"
    local current_ptfx_dictionary = new_ptfx_dictionary
    local current_ptfx_name = new_ptfx_name
    local bone_index = IsPedMale() and 413 or 464   -- ["CP_Chest"]  = {bone_index = 464, bone_id = 53684},
    local ptfx_offcet_x = 0.2
    local ptfx_offcet_y = 0.0
    local ptfx_offcet_z = -0.4
    local ptfx_rot_x = 0.0
    local ptfx_rot_y = 0.0
    local ptfx_rot_z = 0.0
    local ptfx_scale = 1.0
    local ptfx_axis_x = 0
    local ptfx_axis_y = 0
    local ptfx_axis_z = 0
    local clean = clean

    if LocalPlayer.state.isBathingActive then
        if is_particle_effect_active then
            if Citizen.InvokeNative(0x9DD5AFF561E88F2A, current_ptfx_handle_id) then   -- DoesParticleFxLoopedExist
                Citizen.InvokeNative(0x459598F579C98929, current_ptfx_handle_id, false) 
            end

            current_ptfx_handle_id = false
            is_particle_effect_active = false
        end

        return
    end

    if not is_particle_effect_active and clean < Config.MinCleanliness then
        current_ptfx_dictionary = new_ptfx_dictionary
        current_ptfx_name = new_ptfx_name
        if not Citizen.InvokeNative(0x65BB72F29138F5D6, joaat(current_ptfx_dictionary)) then -- HasNamedPtfxAssetLoaded
            Citizen.InvokeNative(0xF2B2353BBC0D4E8F, joaat(current_ptfx_dictionary))  -- RequestNamedPtfxAsset
            local counter = 0
            while not Citizen.InvokeNative(0x65BB72F29138F5D6, joaat(current_ptfx_dictionary)) and counter <= 300 do  -- while not HasNamedPtfxAssetLoaded
                Citizen.Wait(0)
            end
        end
        if not filesspawned and Citizen.InvokeNative(0x65BB72F29138F5D6, joaat(current_ptfx_dictionary)) then  -- HasNamedPtfxAssetLoaded
            Citizen.InvokeNative(0xA10DB07FC234DD12, current_ptfx_dictionary) -- UseParticleFxAsset

            current_ptfx_handle_id = Citizen.InvokeNative(0x9C56621462FFE7A6,current_ptfx_name,PlayerPedId(),ptfx_offcet_x,ptfx_offcet_y,ptfx_offcet_z,ptfx_rot_x,ptfx_rot_y,ptfx_rot_z,bone_index,ptfx_scale,ptfx_axis_x,ptfx_axis_y,ptfx_axis_z) -- StartNetworkedParticleFxLoopedOnEntityBone
            is_particle_effect_active = true
        else
            print("cant load ptfx dictionary!")
        end
    elseif is_particle_effect_active and clean >= Config.MinCleanliness then
        if current_ptfx_handle_id then
            if Citizen.InvokeNative(0x9DD5AFF561E88F2A, current_ptfx_handle_id) then   -- DoesParticleFxLoopedExist
                Citizen.InvokeNative(0x459598F579C98929, current_ptfx_handle_id, false)   -- RemoveParticleFx
            end
        end
        current_ptfx_handle_id = false
        is_particle_effect_active = false
    elseif is_particle_effect_active then
        if current_ptfx_handle_id then
            if not Citizen.InvokeNative(0x9DD5AFF561E88F2A, current_ptfx_handle_id) then   -- DoesParticleFxLoopedExist
                current_ptfx_handle_id = false
                is_particle_effect_active = false
            end
        end
    end
end

------------------------------------------------
-- events
------------------------------------------------

RegisterNetEvent('hud:client:UpdateNeeds', function(newHunger, newThirst, newCleanliness)
    local cleanStats = Citizen.InvokeNative(0x147149F2E909323C, cache.ped, 16, Citizen.ResultAsInteger())
    updateNeed('hunger', newHunger)
    updateNeed('thirst', newThirst)
    updateNeed('cleanliness', newCleanliness - cleanStats)
end)

RegisterNetEvent('hud:client:UpdateHunger', function(newHunger)
    updateNeed('hunger', newHunger)
end)

RegisterNetEvent('hud:client:UpdateThirst', function(newThirst)
    updateNeed('thirst', newThirst)
end)

RegisterNetEvent('hud:client:UpdateStress', function(newStress)
    updateNeed('stress', newStress)
end)

RegisterNetEvent('hud:client:UpdateCleanliness', function(newCleanliness)
    local cleanStats = Citizen.InvokeNative(0x147149F2E909323C, cache.ped, 16, Citizen.ResultAsInteger())
    updateNeed('cleanliness', newCleanliness - cleanStats)
end)

------------------------------------------------
-- get outlawstatus
------------------------------------------------
CreateThread(function()
    while true do
        Wait(30000)
        RSGCore.Functions.TriggerCallback('hud:server:getoutlawstatus', function(result)
            outlawstatus = result[1].outlawstatus
        end)
    end
end)

------------------------------------------------
-- export : outlawstatus
------------------------------------------------
exports('GetOutlawStatus', function()
    return outlawstatus
end)

------------------------------------------------
-- player hud
------------------------------------------------
CreateThread(function()
    while true do
        Wait(500)
        if LocalPlayer.state.isLoggedIn and showUI and not IsCinematicCamRendering() and not LocalPlayer.state.isBathingActive and not LocalPlayer.state.inClothingStore then
            local show = true
            local stamina = tonumber(string.format("%.2f", Citizen.InvokeNative(0x0FF421E467373FCF, cache.playerId, Citizen.ResultAsFloat())))
            local mounted = IsPedOnMount(cache.ped)
            if IsPauseMenuActive() then
                show = false
            end

            local voice = 0
            local talking = Citizen.InvokeNative(0x33EEF97F, cache.playerId)
            if LocalPlayer.state['proximity'] then
                voice = LocalPlayer.state['proximity'].distance
            end

            -- horse health, stamina & cleanliness
            local horsehealth = 0
            local horsestamina = 0
            local horseclean = 0

            if mounted then
                local horse = GetMount(cache.ped)
                local maxHealth = Citizen.InvokeNative(0x4700A416E8324EF3, horse, Citizen.ResultAsInteger())
                local maxStamina = Citizen.InvokeNative(0xCB42AFE2B613EE55, horse, Citizen.ResultAsFloat())
                local horseCleanliness = Citizen.InvokeNative(0x147149F2E909323C, horse, 16, Citizen.ResultAsInteger())
                if horseCleanliness == 0 then
                    horseclean = 100
                else
                    horseclean = 100 - horseCleanliness
                end
                horsehealth = tonumber(string.format("%.2f", Citizen.InvokeNative(0x82368787EA73C0F7, horse) / maxHealth * 100))
                horsestamina = tonumber(string.format("%.2f", Citizen.InvokeNative(0x775A1CA7893AA8B5, horse, Citizen.ResultAsFloat()) / maxStamina * 100))
            end

            SendNUIMessage({
                action = 'hudtick',
                show = show,
                health = GetEntityHealth(cache.ped) / 6, -- health in red dead max health is 600 so dividing by 6 makes it 100 here
                stamina = stamina,
                armor = Citizen.InvokeNative(0x2CE311A7, cache.ped),
                thirst = LocalPlayer.state.thirst or 100,
                hunger = LocalPlayer.state.hunger or 100,
                cleanliness = LocalPlayer.state.cleanliness or 100,
                stress = LocalPlayer.state.stress or 0,
                talking = talking,
                temp = temperature,
                onHorse = mounted,
                horsehealth = horsehealth,
                horsestamina = horsestamina,
                horseclean = horseclean,
                voice = voice,
                youhavemail = LocalPlayer.state.telegramUnreadMessages or 0 > 0,
                outlawstatus = outlawstatus,
                iconColors = Config.IconColors, -- Send config colors
            })
        else
            SendNUIMessage({
                action = 'hudtick',
                show = false,
            })
        end
    end
end)

------------------------------------------------
-- show minimap setup
------------------------------------------------

CreateThread(function()
    while true do
        Wait(500)
        local isMounted = IsPedOnMount(cache.ped) or IsPedInAnyVehicle(cache.ped)

        if isMounted or LocalPlayer.state.telegramIsBirdPostApproaching then
            if Config.MountMinimap and showUI then
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
                -- interior zoom
                if GetInteriorFromEntity(cache.ped) ~= 0 then
                    -- ped entered an interior
                    SetRadarConfigType(0xDF5DB58C, 0) -- zoom in the map by 10x
                else
                    -- ped left an interior
                    SetRadarConfigType(0x25B517BF, 0) -- zoom in the map by 0x (return the minimap back to normal)
                end
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

------------------------------------------------
-- work out temperature
------------------------------------------------
CreateThread(function()
    while true do
        Wait(1000)

        local coords = GetEntityCoords(cache.ped)

        -- wearing
        local hat      = Citizen.InvokeNative(0xFB4891BD7578CDC1, cache.ped, 0x9925C067) -- hat
        local shirt    = Citizen.InvokeNative(0xFB4891BD7578CDC1, cache.ped, 0x2026C46D) -- shirt
        local pants    = Citizen.InvokeNative(0xFB4891BD7578CDC1, cache.ped, 0x1D4C528A) -- pants
        local boots    = Citizen.InvokeNative(0xFB4891BD7578CDC1, cache.ped, 0x777EC6EF) -- boots
        local coat     = Citizen.InvokeNative(0xFB4891BD7578CDC1, cache.ped, 0xE06D30CE) -- coat
        local opencoat = Citizen.InvokeNative(0xFB4891BD7578CDC1, cache.ped, 0x662AC34) -- open-coat
        local gloves   = Citizen.InvokeNative(0xFB4891BD7578CDC1, cache.ped, 0xEABE0032) -- gloves
        local vest     = Citizen.InvokeNative(0xFB4891BD7578CDC1, cache.ped, 0x485EE834) -- vest
        local poncho   = Citizen.InvokeNative(0xFB4891BD7578CDC1, cache.ped, 0xAF14310B) -- poncho
        local skirts   = Citizen.InvokeNative(0xFB4891BD7578CDC1, cache.ped, 0xA0E3AB7F) -- skirts
        local chaps    = Citizen.InvokeNative(0xFB4891BD7578CDC1, cache.ped, 0x3107499B) -- chaps

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

------------------------------------------------
-- health/cleanliness damage
------------------------------------------------
CreateThread(function()
    repeat Wait(100) until LocalPlayer.state.isLoggedIn

    while true do
        Wait(Config.StatusInterval)
        local playerData = RSGCore.Functions.GetPlayerData()

        if LocalPlayer.state.isLoggedIn and not playerData.metadata['isdead'] then
            local state = LocalPlayer.state

            if Config.FlyEffect then
                FliesSpawn(state.cleanliness)
            end

            if Config.DoHealthDamage then
                local health = GetEntityHealth(cache.ped)

                -- hunger/thirst damage
                if (state.hunger <= 0 or state.thirst <= 0) then
                    local decreaseThreshold = math.random(5, 10)
                    PlayPain(cache.ped, 9, 1, true, true)
                    SetEntityHealth(cache.ped, math.max(0, health - decreaseThreshold))
                end

                -- cold health damage
                if temp < Config.MinTemp then 
                    if Config.DoHealthDamageFx then
                        Citizen.InvokeNative(0x4102732DF6B4005F, "MP_Downed", 0, true)
                    end
                    if Config.DoHealthPainSound then
                        PlayPain(cache.ped, 9, 1, true, true)
                    end
                    SetEntityHealth(cache.ped, math.max(0, health -  Config.RemoveHealth))
                elseif Citizen.InvokeNative(0x4A123E85D7C4CA0B, "MP_Downed") and Config.DoHealthDamageFx then
                    Citizen.InvokeNative(0xB4FD7446BAB2F394, "MP_Downed")
                end

                -- hot health damage
                if temp > Config.MaxTemp then
                    if Config.DoHealthDamageFx then
                        Citizen.InvokeNative(0x4102732DF6B4005F, "MP_Downed", 0, true)
                    end
                    if Config.DoHealthPainSound then
                        PlayPain(cache.ped, 9, 1, true, true)
                    end
                    SetEntityHealth(cache.ped, math.max(0, health -  Config.RemoveHealth))
                elseif Citizen.InvokeNative(0x4A123E85D7C4CA0B, "MP_Downed") and Config.DoHealthDamageFx then
                    Citizen.InvokeNative(0xB4FD7446BAB2F394, "MP_Downed")
                end

                -- cleanliness health damage
                if state.cleanliness <= 0 then
                    if Config.DoHealthDamageFx then
                        Citizen.InvokeNative(0x4102732DF6B4005F, "MP_Downed", 0, true)
                    end
                    if Config.DoHealthPainSound then
                        PlayPain(cache.ped, 12, 1, true, true)
                    end
                    SetEntityHealth(cache.ped, math.max(0, health -  Config.RemoveHealth))
                elseif Citizen.InvokeNative(0x4A123E85D7C4CA0B, "MP_Downed") and Config.DoHealthDamageFx then
                    Citizen.InvokeNative(0xB4FD7446BAB2F394, "MP_Downed")
                end
            end

            updateNeed('hunger', Config.HungerRate, true)
            updateNeed('thirst', Config.ThirstRate, true)
            updateNeed('cleanliness', Config.CleanlinessRate, true)
            updateNeed('stress', Config.StressDecayRate, true)
        end
    end
end)

------------------------------------------------
-- player dirt status update loop
------------------------------------------------
CreateThread(function()
    repeat Wait(100) until LocalPlayer.state.isLoggedIn
    while true do
        Wait(Config.StatusInterval)
        local playerData = RSGCore.Functions.GetPlayerData()
        if LocalPlayer.state.isLoggedIn and not playerData.metadata['isdead'] then
            local cleanStats = Citizen.InvokeNative(0x147149F2E909323C, cache.ped, 16, Citizen.ResultAsInteger())
            local newDirtStatus = 100 - cleanStats
            updateNeed('cleanliness', newDirtStatus)
        end
    end
end)

------------------------------------------------
-- money hud
------------------------------------------------
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

------------------------------------------------
-- on money change
------------------------------------------------
RegisterNetEvent('hud:client:OnMoneyChange', function(type, amount, isMinus)
    RSGCore.Functions.GetPlayerData(function(PlayerData)
        cashAmount = PlayerData.money.cash
        bloodmoneyAmount = PlayerData.money.bloodmoney
        bankAmount = PlayerData.money.bank
    end)
    SendNUIMessage({
        action = 'update',
        cash = lib.math.round(cashAmount, 2),
        bloodmoney = lib.math.round(bloodmoneyAmount, 2),
        bank = lib.math.round(bankAmount, 2),
        amount = lib.math.round(amount, 2),
        minus = isMinus,
        type = type,
    })
end)

------------------------------------------------
-- stress gain when speeding
------------------------------------------------
CreateThread(function() -- Speeding
    while true do
        if RSGCore ~= nil then
            if IsPedInAnyVehicle(cache.ped, false) then
                speed = GetEntitySpeed(GetVehiclePedIsIn(cache.ped, false)) * 2.237 --mph
                if speed >= Config.MinimumSpeed then
                    TriggerEvent('hud:client:GainStress', math.random(1, 3))
                end
            end
        end
        Wait(10000)
    end
end)

------------------------------------------------
-- stress gained while shooting
------------------------------------------------
CreateThread(function()
    while true do
        if RSGCore ~= nil  then
            if IsPedShooting(cache.ped) then
                if math.random() < Config.StressChance then
                    TriggerEvent('hud:client:GainStress', math.random(1, 3))
                end
            end
        end
        Wait(6)
    end
end)

------------------------------------------------
-- stress screen effects
------------------------------------------------
CreateThread(function()
    while true do
        local stress = LocalPlayer.state.stress or 0
        local sleep = GetEffectInterval(stress)

        if stress >= 100 then
            local ShakeIntensity = GetShakeIntensity(stress)
            local FallRepeat = math.random(2, 4)
            local RagdollTimeout = (FallRepeat * 1750)
            ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', ShakeIntensity)

            if not IsPedRagdoll(cache.ped) and IsPedOnFoot(cache.ped) and not IsPedSwimming(cache.ped) then

                SetPedToRagdollWithFall(cache.ped, RagdollTimeout, RagdollTimeout, 1, GetEntityForwardVector(cache.ped), 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
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

local function updateStress(amount, isGain)
    RSGCore.Functions.GetPlayerData(function(PlayerData)
        if not PlayerData.metadata['isdead'] and  (isGain or PlayerData.job.type ~= 'leo') then
            local currentStress = LocalPlayer.state.stress or 0
            local newStress = currentStress + (isGain and amount or -amount)

            newStress = lib.math.clamp(newStress, 0, 100)
            LocalPlayer.state:set('stress', lib.math.round(newStress, 2), true)

            local title = isGain and locale('sv_lang_1') or locale('sv_lang_3')
            lib.notify({ title = title, type = 'inform', duration = 5000 })
        end
    end)
end

RegisterNetEvent('hud:client:GainStress', function(amount)
    updateStress(amount, true)
end)

RegisterNetEvent('hud:client:RelieveStress', function(amount)
    updateStress(amount, false)
end)

------------------------------------------------
-- hud edit mode toggle
------------------------------------------------
local editMode = false

RegisterNetEvent('hud:client:ToggleEditMode', function()
    editMode = not editMode
    SendNUIMessage({
        action = 'toggleEditMode',
        enabled = editMode
    })
    if editMode then
        -- Enable mouse cursor for dragging
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
        lib.notify({
            title = locale('edit_mode_on_title'),
            description = locale('edit_mode_on_desc'),
            type = 'success',
            duration = 5000
        })
    else
        -- Disable mouse cursor
        SetNuiFocus(false, false)
        lib.notify({
            title = locale('edit_mode_on_title'),
            description = locale('edit_mode_off_desc'),
            type = 'inform',
            duration = 3000
        })
    end
end)

-- Command to toggle HUD edit mode
RegisterCommand('edithud', function()
    TriggerEvent('hud:client:ToggleEditMode')
end, false)

-- Command to reset HUD positions
RegisterCommand('resethud', function()
    SendNUIMessage({
        action = 'resetPositions'
    })
    lib.notify({
        title = locale('reset_hud_title'),
        description = locale('reset_hud_desc'),
        type = 'success',
        duration = 3000
    })
end, false)

-- NUI Callback to disable edit mode (when ESC is pressed or NUI loses focus)
RegisterNUICallback('disableEditMode', function(data, cb)
    if editMode then
        editMode = false
        SetNuiFocus(false, false)
        SendNUIMessage({
            action = 'toggleEditMode',
            enabled = false
        })
        lib.notify({
            title = locale('edit_mode_on_title'),
            description = locale('edit_mode_off_desc'),
            type = 'inform',
            duration = 3000
        })
    end
    cb('ok')
end)

