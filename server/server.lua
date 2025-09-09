local RSGCore = exports['rsg-core']:GetCoreObject()


RegisterNetEvent('RSGCore:Server:OnPlayerLoaded', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player and Player.PlayerData and Player.PlayerData.money then
        Player(src).state:set('money', Player.PlayerData.money, true)
    end
end)


local function updateMoneyState(src, account, amount, isMinus)
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player and Player.PlayerData and Player.PlayerData.money then
        Player(src).state:set('money', Player.PlayerData.money, true)
        TriggerClientEvent('hud:client:OnMoneyChange', src, account, amount, isMinus)
    end
end


AddEventHandler('RSGCore:Server:AddMoney', function(src, account, amount)
    updateMoneyState(src, account, amount, false)
end)

AddEventHandler('RSGCore:Server:RemoveMoney', function(src, account, amount)
    updateMoneyState(src, account, amount, true)
end)

AddEventHandler('RSGCore:Server:SetMoney', function(src, account, amount)
    updateMoneyState(src, account, amount, false)
end)


RSGCore.Commands.Add('cash', 'Check Cash Balance', {}, false, function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if Player and Player.PlayerData.money and Player.PlayerData.money.cash ~= nil then
        TriggerClientEvent('hud:client:ShowAccounts', source, 'cash', Player.PlayerData.money.cash)
    end
end)

RSGCore.Commands.Add('bloodmoney', 'Check Bloodmoney Balance', {}, false, function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if Player and Player.PlayerData.money and Player.PlayerData.money.bloodmoney ~= nil then
        TriggerClientEvent('hud:client:ShowAccounts', source, 'bloodmoney', Player.PlayerData.money.bloodmoney)
    end
end)


RSGCore.Functions.CreateCallback('hud:server:getoutlawstatus', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb(nil) end
    MySQL.query('SELECT outlawstatus FROM players WHERE citizenid = ?', {Player.PlayerData.citizenid}, function(result)
        cb(result[1] or nil)
    end)
end)
