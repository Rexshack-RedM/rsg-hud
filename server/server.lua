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

addBalanceCommand('cash', 'Check Cash Balance')
addBalanceCommand('bloodmoney', 'Check Bloodmoney Balance')

---------------------------------
-- get outlaw status
---------------------------------
RSGCore.Functions.CreateCallback('hud:server:getoutlawstatus', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb(0) end

    local status = MySQL.scalar.await('SELECT outlawstatus FROM players WHERE citizenid = ?', { Player.PlayerData.citizenid })
    cb(tonumber(status) or 0)
end)
