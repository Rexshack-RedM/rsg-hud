local RSGCore = exports['rsg-core']:GetCoreObject()

local function addBalanceCommand(account, help)
    RSGCore.Commands.Add(account, help, {}, false, function(source)
        local Player = RSGCore.Functions.GetPlayer(source)
        local amount = Player and Player.PlayerData.money[account]
        if amount then
            TriggerClientEvent('hud:client:ShowAccounts', source, account, amount)
        end
    end)
end

addBalanceCommand('cash', locale('cmd_cash_help'))
addBalanceCommand('bloodmoney', locale('cmd_bloodmoney_help'))

---------------------------------
-- bank balance (rsg-banking v3 total across branches)
---------------------------------
local function getBankBalance(Player)
    if GetResourceState('rsg-banking') == 'started' then
        local ok, total = pcall(function() return exports['rsg-banking']:GetTotalBalance(Player.PlayerData.citizenid) end)
        if ok and tonumber(total) then return tonumber(total) end
    end
    return Player.PlayerData.money.bank or 0
end

local bankCooldown = {}
RSGCore.Commands.Add(Config.BankCommand or 'bank', locale('cmd_bank_help'), {}, false, function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    local now = GetGameTimer()
    if bankCooldown[source] and now - bankCooldown[source] < 3000 then return end -- DB query, so rate limit
    bankCooldown[source] = now
    TriggerClientEvent('hud:client:ShowAccounts', source, 'bank', getBankBalance(Player))
end)

---------------------------------
-- get outlaw status
---------------------------------
-- cached per player so a spamming client can't hammer the database
local OUTLAW_CACHE_MS = 20000
local outlawCache = {}

RSGCore.Functions.CreateCallback('hud:server:getoutlawstatus', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb(0) end

    local now = GetGameTimer()
    local cached = outlawCache[source]
    if cached and now - cached.time < OUTLAW_CACHE_MS then return cb(cached.value) end

    local status = tonumber(MySQL.scalar.await('SELECT outlawstatus FROM players WHERE citizenid = ?', { Player.PlayerData.citizenid })) or 0
    outlawCache[source] = { time = now, value = status }
    cb(status)
end)

---------------------------------
-- server-owned needs (decay + anti-tamper)
---------------------------------
local SERVER_NEEDS = { hunger = true, thirst = true, stress = true }
local auth = {}   -- [src] = { hunger, thirst, stress } authoritative values
local gained = {} -- [src] = { t = window start, amount = hunger/thirst added this minute }

local function clampNeed(v) return math.floor(math.max(0, math.min(100, v)) * 100 + 0.5) / 100 end

local function setAuth(src, key, value)
    auth[src][key] = clampNeed(value)
    Player(src).state:set(key, auth[src][key], true)
end

local function initAuth(src)
    local st = Player(src).state
    auth[src] = { hunger = tonumber(st.hunger) or 100, thirst = tonumber(st.thirst) or 100, stress = tonumber(st.stress) or 0 }
    return auth[src]
end

if Config.ServerNeeds then
    for key in pairs(SERVER_NEEDS) do
        AddStateBagChangeHandler(key, nil, function(bagName, k, value)
            local src = GetPlayerFromStateBagName(bagName)
            if not src or src == 0 then return end
            local a = auth[src]
            if not a then return end -- not initialised yet, decay loop will pick it up
            value = tonumber(value)
            if value == a[k] then return end -- our own write

            if not value or value ~= value then
                return SetTimeout(0, function() setAuth(src, k, a[k]) end)
            end

            local delta = value - a[k]
            if k ~= 'stress' and delta > 0 then
                local now = os.time()
                local g = gained[src]
                if not g or now - g.t >= 60 then g = { t = now, amount = 0 }; gained[src] = g end
                if g.amount + delta > Config.MaxNeedGainPerMinute then
                    return SetTimeout(0, function() setAuth(src, k, a[k]) end) -- too much, revert
                end
                g.amount = g.amount + delta
            end
            a[k] = clampNeed(value)
            if a[k] ~= value then SetTimeout(0, function() setAuth(src, k, a[k]) end) end
        end)
    end

    CreateThread(function()
        while true do
            Wait(Config.StatusInterval)
            for _, src in ipairs(GetPlayers()) do
                src = tonumber(src)
                local P = RSGCore.Functions.GetPlayer(src)
                if P and not P.PlayerData.metadata.isdead then
                    local a = auth[src] or initAuth(src)
                    setAuth(src, 'hunger', a.hunger - Config.HungerRate)
                    setAuth(src, 'thirst', a.thirst - Config.ThirstRate)
                    if a.stress > 0 then setAuth(src, 'stress', a.stress - Config.StressDecayRate) end
                end
            end
        end
    end)

    AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
        auth[src], gained[src] = nil, nil
    end)
end

AddEventHandler('playerDropped', function()
    outlawCache[source] = nil
    bankCooldown[source] = nil
    auth[source], gained[source] = nil, nil
end)


---------------------------------
-- exports (server -> player's client)
---------------------------------
local NEEDS = { hunger = 'hud:client:UpdateHunger', thirst = 'hud:client:UpdateThirst', cleanliness = 'hud:client:UpdateCleanliness', stress = 'hud:client:UpdateStress' }

local function validTarget(src)
    return src and RSGCore.Functions.GetPlayer(src) ~= nil
end

exports('SetNeed', function(src, key, value)
    value = tonumber(value)
    if not NEEDS[key] or not value or not validTarget(src) then return false end
    if Config.ServerNeeds and SERVER_NEEDS[key] then
        if not auth[src] then initAuth(src) end
        setAuth(src, key, value) -- trusted server write, bypasses the gain limit
        return true
    end
    TriggerClientEvent(NEEDS[key], src, math.max(0, math.min(100, value)))
    return true
end)

exports('GetNeeds', function(src)
    local p = src and Player(src)
    if not p then return nil end
    local s = p.state
    return { hunger = s.hunger or 100, thirst = s.thirst or 100, cleanliness = s.cleanliness or 100, stress = s.stress or 0 }
end)

exports('GainStress', function(src, amount)
    if not validTarget(src) or not tonumber(amount) then return false end
    TriggerClientEvent('hud:client:GainStress', src, tonumber(amount))
    return true
end)

exports('RelieveStress', function(src, amount)
    if not validTarget(src) or not tonumber(amount) then return false end
    TriggerClientEvent('hud:client:RelieveStress', src, tonumber(amount))
    return true
end)

exports('ShowAccount', function(src, account)
    local P = src and RSGCore.Functions.GetPlayer(src)
    local amount = P and (account == 'bank' and getBankBalance(P) or P.PlayerData.money[account])
    if not amount then return false end
    TriggerClientEvent('hud:client:ShowAccounts', src, account, amount)
    return true
end)
