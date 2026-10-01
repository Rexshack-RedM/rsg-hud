local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

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
-- get outlaw status
---------------------------------
RSGCore.Functions.CreateCallback('hud:server:getoutlawstatus', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb(0) end

    local status = MySQL.scalar.await('SELECT outlawstatus FROM players WHERE citizenid = ?', { Player.PlayerData.citizenid })
    cb(tonumber(status) or 0)
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
    local amount = P and P.PlayerData.money[account]
    if not amount then return false end
    TriggerClientEvent('hud:client:ShowAccounts', src, account, amount)
    return true
end)
