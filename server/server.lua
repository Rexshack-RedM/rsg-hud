local RSGCore = exports['rsg-core']:GetCoreObject()
local ResetStress = false
lib.locale()

RSGCore.Commands.Add('cash', 'Check Cash Balance', {}, false, function(source, args)
    local Player = RSGCore.Functions.GetPlayer(source)
    local cashamount = Player.PlayerData.money.cash
    if cashamount ~= nil then
        TriggerClientEvent('hud:client:ShowAccounts', source, 'cash', cashamount)
    else
        return
    end
end)

RSGCore.Commands.Add('bloodmoney', 'Check Bloodmoney Balance', {}, false, function(source, args)
    local Player = RSGCore.Functions.GetPlayer(source)
    local bloodmoneyamount = Player.PlayerData.money.bloodmoney
    if bloodmoneyamount ~= nil then
        TriggerClientEvent('hud:client:ShowAccounts', source, 'bloodmoney', bloodmoneyamount)
    else
        return
    end
end)

---------------------------------
-- get outlaw status
---------------------------------
RSGCore.Functions.CreateCallback('hud:server:getoutlawstatus', function(source, cb)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player ~= nil then
        MySQL.query('SELECT outlawstatus FROM players WHERE citizenid = ?', {Player.PlayerData.citizenid}, function(result)
            if result[1] then
                cb(result)
            else
                cb(nil)
            end
        end)
    end
end)
