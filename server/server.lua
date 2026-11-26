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
local layoutCooldown = {} -- admin default layout pushes
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

local wellFed = {} -- [src] = bool, mirrors the 'rsghud_wellfed' state bag

local function setWellFed(src, value)
    if wellFed[src] == value then return end
    wellFed[src] = value
    Player(src).state:set('rsghud_wellfed', value, true)
end

-- hunger/thirst decay multipliers for this tick. The client only reports activity/weather (never below 1.0 here),
-- the well fed buff is worked out from the server's own values.
local function decayMultipliers(src, a)
    local dm = Config.DecayModifiers
    if not dm or not dm.enabled then
        setWellFed(src, false)
        return 1.0, 1.0
    end

    local st = Player(src).state
    local act, env = st.rsghud_act, st.rsghud_env
    local actMult = math.max(1.0, type(act) == 'string' and tonumber((dm.activity or {})[act]) or 1.0)
    local hunger, thirst = actMult, actMult

    local e = type(env) == 'string' and (dm.environment or {})[env]
    if e then
        hunger = hunger * math.max(1.0, tonumber(e.hunger) or 1.0)
        thirst = thirst * math.max(1.0, tonumber(e.thirst) or 1.0)
    end

    local cap = tonumber(dm.maxMultiplier) or 3.0
    hunger, thirst = math.min(hunger, cap), math.min(thirst, cap)

    local wf = dm.wellFed
    local fed = wf and wf.enabled and a.hunger >= (tonumber(wf.minimum) or 80) and a.thirst >= (tonumber(wf.minimum) or 80) or false
    setWellFed(src, fed)
    if fed then
        local m = math.max(0.1, math.min(1.0, tonumber(wf.decayMultiplier) or 0.5))
        hunger, thirst = hunger * m, thirst * m
    end
    return hunger, thirst
end

local function clampNeed(v) return math.floor(math.max(0, math.min(100, v)) * 100 + 0.5) / 100 end

local function setAuth(src, key, value)
    auth[src][key] = clampNeed(value)
    Player(src).state:set(key, auth[src][key], true)
end

-- on login we seed from the server's own metadata so a client can't pre-load the state bag before the first tick;
-- after a resource restart (fromMetadata = false) the live state bag is newer than metadata, so use that
local function initAuth(src, fromMetadata)
    local P = fromMetadata and RSGCore.Functions.GetPlayer(src)
    local md = P and P.PlayerData.metadata or {}
    local st = Player(src).state
    auth[src] = {
        hunger = clampNeed(tonumber(md.hunger) or tonumber(st.hunger) or 100),
        thirst = clampNeed(tonumber(md.thirst) or tonumber(st.thirst) or 100),
        stress = clampNeed(tonumber(md.stress) or tonumber(st.stress) or 0),
    }
    for k, v in pairs(auth[src]) do st:set(k, v, true) end
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

            -- hunger/thirst may only go up (eating/drinking) and stress only down (relief) within a per-minute budget
            local delta = value - a[k]
            local gain = (k == 'stress') and -delta or delta
            if gain > 0 then
                local limit = k == 'stress' and (Config.MaxStressReliefPerMinute or 50) or Config.MaxNeedGainPerMinute
                local now = os.time()
                local g = gained[src]
                if not g or now - g.t >= 60 then g = { t = now, need = 0, stress = 0 }; gained[src] = g end
                local bucket = k == 'stress' and 'stress' or 'need'
                if g[bucket] + gain > limit then
                    return SetTimeout(0, function() setAuth(src, k, a[k]) end) -- too much, revert
                end
                g[bucket] = g[bucket] + gain
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
                    local hungerMult, thirstMult = decayMultipliers(src, a)
                    -- only write when the value actually moves (state bag writes replicate to the client)
                    if a.hunger > 0 then setAuth(src, 'hunger', a.hunger - Config.HungerRate * hungerMult) end
                    if a.thirst > 0 then setAuth(src, 'thirst', a.thirst - Config.ThirstRate * thirstMult) end
                    if a.stress > 0 then setAuth(src, 'stress', a.stress - Config.StressDecayRate) end
                end
            end
        end
    end)

    AddEventHandler('RSGCore:Server:PlayerLoaded', function(P)
        local src = P and P.PlayerData and P.PlayerData.source
        if src then initAuth(src, true) end
    end)
end

AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    auth[src], gained[src], outlawCache[src], wellFed[src] = nil, nil, nil, nil
end)

AddEventHandler('playerDropped', function()
    outlawCache[source] = nil
    bankCooldown[source] = nil
    auth[source], gained[source], wellFed[source] = nil, nil, nil
    layoutCooldown[source] = nil
end)


---------------------------------
-- admin default layout
---------------------------------
-- An admin's own layout (/pushhuddefault) becomes the default for players without a saved layout. Everything the
-- client sends is re-validated here: only known enum values, clamped numbers, booleans and hex colours are kept.
local LAYOUT_KEY = 'rsghud_default_layout'
local LAYOUT_ENUMS = {
    size = { small = true, medium = true, large = true },
    align = { ['bottom-left'] = true, ['bottom-center'] = true, ['bottom-right'] = true, ['top-left'] = true, ['top-center'] = true, ['top-right'] = true },
    orientation = { horizontal = true, vertical = true },
}
local LAYOUT_HIDEABLE = { health = true, stamina = true, deadeye = true, hunger = true, thirst = true, cleanliness = true, stress = true, temp = true, voice = true, mail = true, outlaw = true,
    horse = true, horsebond = true, horsehunger = true, horsethirst = true, clock = true, compass = true, ammo = true, weapon = true, wellfed = true, horseinjury = true }
local LAYOUT_FEATURES = { 'lowNeeds', 'stressWarn', 'tempWarn', 'wellFedNotice', 'warningSound', 'heartbeat', 'painSound', 'stressShake', 'flies', 'damageFx' }
local LAYOUT_PALETTES = { default = true, redgreen = true, blueyellow = true }
local LAYOUT_MAP = { off = true, map = true, compass = true }

local function num(v, lo, hi, def)
    v = tonumber(v)
    if not v or v ~= v then return def end
    return math.floor(math.max(lo, math.min(hi, v)) + 0.5)
end

local function sanitiseLayout(l)
    if type(l) ~= 'table' then return nil end
    local out = {}
    for key, valid in pairs(LAYOUT_ENUMS) do
        if not valid[l[key]] then return nil end
        out[key] = l[key]
    end
    out.offsetX, out.offsetY = num(l.offsetX, -2000, 2000, 0), num(l.offsetY, -2000, 2000, 0)

    out.hidden = {}
    if type(l.hidden) == 'table' then
        for k, v in pairs(l.hidden) do
            if LAYOUT_HIDEABLE[k] and v == true then out.hidden[k] = true end
        end
    end

    local d = type(l.display) == 'table' and l.display or {}
    local bad = num(d.ringBad, 5, 90, 30)
    local display = {
        showPct = d.showPct == true, alwaysShow = d.alwaysShow == true, voiceAlways = d.voiceAlways ~= false, money = d.money ~= false,
        opacity = num(d.opacity, 30, 100, 100), scale = num(d.scale, 70, 140, 100),
        ringBad = bad, ringWarn = num(d.ringWarn, bad + 5, 95, math.max(70, bad + 5)),
        palette = LAYOUT_PALETTES[d.palette] and d.palette or 'default',
        mapFoot = LAYOUT_MAP[d.mapFoot] and d.mapFoot or nil, mapMount = LAYOUT_MAP[d.mapMount] and d.mapMount or nil,
        colors = {},
        features = {},
    }
    for _, key in ipairs(LAYOUT_FEATURES) do
        display.features[key] = not (type(d.features) == 'table' and d.features[key] == false) -- only an explicit false turns one off
    end
    if type(d.colors) == 'table' then
        local n = 0
        for k, v in pairs(d.colors) do
            if type(k) == 'string' and type(v) == 'string' and #k <= 32 and k:match('^[%w_]+%.%a+$') and v:match('^#%x%x%x%x%x%x$') then
                display.colors[k] = v:lower()
                n = n + 1
                if n >= 64 then break end
            end
        end
    end
    out.display = display
    return out
end

local defaultLayout
local layoutLoaded = false

-- stored in MySQL instead of resource KVP, so no server "db" folder is created
MySQL.ready(function()
    if Config.AutoDatabase then
        MySQL.query.await([[
CREATE TABLE IF NOT EXISTS `rsg_hud_state` (
  `key` VARCHAR(50) NOT NULL,
  `value` LONGTEXT NOT NULL,
  PRIMARY KEY (`key`)
)]])
    end
    local raw = MySQL.scalar.await('SELECT `value` FROM rsg_hud_state WHERE `key` = ?', { LAYOUT_KEY })
    local ok, decoded = pcall(function() return raw and json.decode(raw) end)
    defaultLayout = ok and sanitiseLayout(decoded) or nil
    layoutLoaded = true
    if defaultLayout then TriggerClientEvent('hud:client:DefaultLayoutChanged', -1) end
end)

local function notifyAdmin(src, key, nType)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('settings_title'), description = locale(key), type = nType or 'success', duration = 5000 })
end

RSGCore.Functions.CreateCallback('hud:server:getDefaultLayout', function(_, cb)
    cb(defaultLayout or false)
end)

RSGCore.Commands.Add(Config.PushDefaultCommand or 'pushhuddefault', locale('cmd_pushdefault_help'), {}, false, function(source)
    TriggerClientEvent('hud:client:SendDefaultLayout', source) -- the client answers with hud:server:setDefaultLayout
end, Config.AdminPermission or 'admin')

RSGCore.Commands.Add(Config.ClearDefaultCommand or 'clearhuddefault', locale('cmd_cleardefault_help'), {}, false, function(source)
    if not layoutLoaded then return end
    defaultLayout = nil
    MySQL.prepare('DELETE FROM rsg_hud_state WHERE `key` = ?', { LAYOUT_KEY })
    TriggerClientEvent('hud:client:DefaultLayoutChanged', -1)
    notifyAdmin(source, 'default_cleared')
end, Config.AdminPermission or 'admin')

RegisterNetEvent('hud:server:setDefaultLayout', function(layout)
    local src = source
    if not RSGCore.Functions.GetPlayer(src) then return end
    local now = GetGameTimer()
    if layoutCooldown[src] and now - layoutCooldown[src] < 5000 then return end -- also stops non-admins spamming the denied notice
    layoutCooldown[src] = now
    if not RSGCore.Functions.HasPermission(src, Config.AdminPermission or 'admin') then
        return notifyAdmin(src, 'default_denied', 'error')
    end

    local clean = sanitiseLayout(layout)
    if not clean or not layoutLoaded then return end
    defaultLayout = clean
    MySQL.prepare('INSERT INTO rsg_hud_state (`key`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)', { LAYOUT_KEY, json.encode(clean) })
    TriggerClientEvent('hud:client:DefaultLayoutChanged', -1)
    notifyAdmin(src, 'default_pushed')
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

local function changeStress(src, amount, isGain)
    amount = tonumber(amount)
    if not amount or amount <= 0 or not validTarget(src) then return false end
    if Config.ServerNeeds then
        local a = auth[src] or initAuth(src)
        setAuth(src, 'stress', a.stress + (isGain and amount or -amount)) -- trusted, not subject to the client relief limit
    end
    TriggerClientEvent(isGain and 'hud:client:GainStress' or 'hud:client:RelieveStress', src, amount, Config.ServerNeeds == true)
    return true
end

exports('GainStress', function(src, amount) return changeStress(src, amount, true) end)
exports('RelieveStress', function(src, amount) return changeStress(src, amount, false) end)

exports('ShowAccount', function(src, account)
    local P = src and RSGCore.Functions.GetPlayer(src)
    local amount = P and (account == 'bank' and getBankBalance(P) or P.PlayerData.money[account])
    if not amount then return false end
    TriggerClientEvent('hud:client:ShowAccounts', src, account, amount)
    return true
end)
