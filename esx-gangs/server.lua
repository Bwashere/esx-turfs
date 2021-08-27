-- STRUCTURE --
-- gangs = gangs table (MySQL)
-- ranks = each gang -> gang.ranks[rank_name] = rank data

-- GETTING RANKS: gangs["gangname"].ranks

Config.Webhook = ""

local gangs = {}

local initialized = {}

local zones = Config.Zones

local zones_waiting = {} 

ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

local function chatMessage(target, author, msg)
    TriggerClientEvent('chat:addMessage', target, { --125, 11, 212
        template = '<div style="padding: 0.41vw; margin: 0.5vw; background-color: rgba(136, 37, 202, 0.6); border-radius: 3px;"><i class=""></i> '..author..' {1}<br></div>',
        args = { author, msg }
    })
end

local function isAdmin(source)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	local group = xPlayer.getGroup()
	for i=1, #Config.AdministrativeGroups do
		if (group == Config.AdministrativeGroups[i]) then
			return true
		end
	end
    return false
end

local function InitializeData()
    MySQL.ready(function ()
        local data_gangs = MySQL.Sync.fetchAll('SELECT * FROM gangs', {})
        local data_ranks = MySQL.Sync.fetchAll('SELECT * FROM gang_ranks', {})
        for i=1, #data_gangs do
            gangs[data_gangs[i].name] = data_gangs[i]
            gangs[data_gangs[i].name].inventory = data_gangs[i].inventory ~= nil and json.decode(data_gangs[i].inventory) or {cash = 0, dcash = 0, items = {}}
            gangs[data_gangs[i].name].vehicles = Config.Gangs[data_gangs[i].name] ~= nil and (Config.Gangs[data_gangs[i].name].Vehicles ~= nil and Config.Gangs[data_gangs[i].name].Vehicles or {}) or {}
        end
        for i=1, #data_ranks do
            if (gangs[data_ranks[i].gang_name] ~= nil) then
                if (gangs[data_ranks[i].gang_name].ranks == nil) then 
                    gangs[data_ranks[i].gang_name].ranks = {}
                end
                gangs[data_ranks[i].gang_name].ranks[data_ranks[i].name] = data_ranks[i]
            end
        end
    end) 
end   

local function getPlayerGang(id)
    for a,b in pairs(gangs) do
        if (b.members ~= nil) then
            for k,v in pairs(b.members) do
                if (k == id) then
                    return a
                end
            end
        end
    end
end

local function getRankData(gang, rank)
    local _gang = gang
    local rank_id = rank
    for k,v in pairs(gangs[_gang].ranks) do
        if (v.ranking == rank_id) then
            return v
        end
    end
end

local function getPlayerRank(id, gang) 
    local _id = id
    local _gang = gang
    if (gangs[_gang] ~= nil) then 
        local members = gangs[_gang].members
        return getRankData(_gang, members[_id])
    end
end

local function isGangLeader(id, gang)
    local player = id
    local _gang = gang
    local gang_data = gangs[_gang]
    local members = gang_data.members
    local min_rank = gang_data.leadership_rank
    if (members[id] ~= nil and members[id] >= min_rank) then
        return true
    end
end

local function UpdatePlayerClient(id, gang, rank)
    local _id = id
    local _gang = {}
    local _rank = {}
    if (gang ~= nil) then 
        _gang = gangs[gang]
        _rank = getRankData(gang, rank)
    end
    if (_gang == nil or _rank == nil) then
        _gang = {}
        _rank = {}
    end
    TriggerClientEvent('esx_gangs:UpdateClient', _id, _gang, _rank)
end

local function InitializePlayerData(id)
    local source = id
    local xPlayer = nil 
    while xPlayer == nil do 
        xPlayer = ESX.GetPlayerFromId(source)
        Citizen.Wait(50)
    end
    local identifier = xPlayer.getIdentifier()
    local gang_data = MySQL.Sync.fetchAll('SELECT `gang`, `gang_rank` FROM `users` WHERE identifier=@identifier', {['@identifier'] = identifier})
    local gang_name = gang_data[1].gang
    local gang_rank = gang_data[1].gang_rank
    if (gangs[gang_name] ~= nil) then
        if (gangs[gang_name].members == nil) then
            gangs[gang_name].members = {}  
        end
        gangs[gang_name].members[source] = gang_rank
        UpdatePlayerClient(source, gang_name, gang_rank)
    end
end

local function RemovePlayerData(id)
    local source = id
    for k,v in pairs(gangs) do
        if (v.members ~= nil) then
            for a,b in pairs(v.members) do
                if (a == source) then
                    v.members[a] = nil
                end
            end
        end
    end
    if (ESX.GetPlayerFromId(source) ~= nil) then
        UpdatePlayerClient(source, nil, nil)
    end
end

local function InsertPlayer(ident, gang_name, ranking) 
    local tplayer = MySQL.Sync.fetchAll('SELECT `gang`, `firstname`, `lastname` FROM `users` WHERE identifier=@identifier', {['@identifier'] = ident})
    local player = tplayer[1]
    local gang_data = gangs[gang_name]
    local rank_data = getRankData(gang_name, ranking)
    local xPlayer = ESX.GetPlayerFromIdentifier(ident)
    if (xPlayer ~= nil) then
        if (xPlayer.source ~= nil) then
            MySQL.Sync.execute("UPDATE users SET gang=@gang, gang_rank=@gang_rank WHERE identifier=@identifier", {['@gang'] = gang_name, ['@gang_rank'] = ranking, ['@identifier'] = ident})
            TriggerClientEvent('mythic_notify:client:SendAlert', xPlayer.source, { type = 'inform', text = player.firstname .. " " .. player.lastname .. " was set as ".. gang_data.label .. ": ".. rank_data.label ..".", length = 5000 })
            RemovePlayerData(xPlayer.source)
            InitializePlayerData(xPlayer.source)
        end
    end
end

local function InvitePlayer(ident, gang_name)
    local tplayer = MySQL.Sync.fetchAll('SELECT `gang`, `firstname`, `lastname` FROM `users` WHERE identifier=@identifier', {['@identifier'] = ident})
    local player = tplayer[1]
    local gang_data = gangs[gang_name]
    local xPlayer = ESX.GetPlayerFromIdentifier(ident)
    if (xPlayer ~= nil) then
        if (xPlayer.source ~= nil) then
            MySQL.Sync.execute("UPDATE users SET gang=@gang, gang_rank=0 WHERE identifier=@identifier", {['@gang'] = gang_name, ['@identifier'] = ident})
            TriggerClientEvent('mythic_notify:client:SendAlert', xPlayer.source, { type = 'inform', text = player.firstname .. " " .. player.lastname .. " was accepted into ".. gang_data.label .. ".", length = 5000 })
            RemovePlayerData(xPlayer.source)
            InitializePlayerData(xPlayer.source)
        end
    end
end

local function FirePlayer(ident)
    local tplayer = MySQL.Sync.fetchAll('SELECT `gang`, `firstname`, `lastname` FROM `users` WHERE identifier=@identifier', {['@identifier'] = ident})
    local player = tplayer[1]
    local gang_data = gangs[player.gang]
    local xPlayer = ESX.GetPlayerFromIdentifier(ident)
    if (xPlayer ~= nil) then
        if (xPlayer.source ~= nil) then
            MySQL.Sync.execute("UPDATE users SET gang=NULL, gang_rank=NULL WHERE identifier=@identifier", {['@identifier'] = ident})
            TriggerClientEvent('mythic_notify:client:SendAlert', xPlayer.source, { type = 'inform', text = player.firstname .. " " .. player.lastname .. " was removed from ".. gang_data.label .. ".", length = 5000 })
            RemovePlayerData(xPlayer.source)
        end
    else
        TriggerClientEvent('mythic_notify:client:SendAlert', xPlayer.source, { type = 'error', text = "Player Not Online", length = 5000 })
    end
end

local function PromotePlayer(ident,src)
    print(ident)
    local tplayer = MySQL.Sync.fetchAll('SELECT `gang`, `gang_rank`, `firstname`, `lastname` FROM `users` WHERE identifier=@identifier', {['@identifier'] = ident})
    local player = tplayer[1]
    local gang_data = gangs[player.gang]
    local xPlayer = ESX.GetPlayerFromIdentifier(ident)
    print(xPlayer)
    if (getRankData(player.gang, player.gang_rank + 1) ~= nil) then
        if (xPlayer ~= nil) then
            print("-----")
            if (xPlayer.source ~= nil) then
                print("--Updated--")
                MySQL.Sync.execute("UPDATE users SET gang_rank=@gang_rank WHERE identifier=@identifier", {['@gang_rank'] = player.gang_rank + 1, ['@identifier'] = ident})
                TriggerClientEvent('mythic_notify:client:SendAlert', xPlayer.source, { type = 'inform', text = "Promoted " .. player.firstname .. " " .. player.lastname .. " to ".. getRankData(player.gang, player.gang_rank + 1).label .. ".", length = 5000 })
                UpdatePlayerClient(xPlayer.source, player.gang, player.gang_rank + 1)
            end
        else
            TriggerClientEvent('mythic_notify:client:SendAlert', src, { type = 'error', text = "Player Not Online", length = 5000 })
        end
    else
        TriggerClientEvent('mythic_notify:client:SendAlert', xPlayer.source, { type = 'error', text = "Couldn't promote " .. player.firstname .. " " .. player.lastname .. " any higher.", length = 5000 })
    end
end

local function DemotePlayer(ident,src)
    local tplayer = MySQL.Sync.fetchAll('SELECT `gang`, `gang_rank`, `firstname`, `lastname` FROM `users` WHERE identifier=@identifier', {['@identifier'] = ident})
    local player = tplayer[1]
    local gang_data = gangs[player.gang]
    local xPlayer = ESX.GetPlayerFromIdentifier(ident)
    if (getRankData(player.gang, player.gang_rank - 1) ~= nil) then
        if (xPlayer ~= nil) then
            if (xPlayer.source ~= nil) then
                MySQL.Sync.execute("UPDATE users SET gang_rank=@gang_rank WHERE identifier=@identifier", {['@gang_rank'] = player.gang_rank - 1, ['@identifier'] = ident})
                TriggerClientEvent('mythic_notify:client:SendAlert', xPlayer.source, { type = 'inform', text = "Demoted " .. player.firstname .. " " .. player.lastname .. " to ".. getRankData(player.gang, player.gang_rank - 1).label .. ".", length = 5000 })
                UpdatePlayerClient(xPlayer.source, player.gang, player.gang_rank - 1)
            end
        else
            TriggerClientEvent('mythic_notify:client:SendAlert', src, { type = 'inform', text = "Player Not Online", length = 5000 })
        end
    else
        TriggerClientEvent('mythic_notify:client:SendAlert', xPlayer.source, { type = 'inform', text = "Couldn't demote " .. player.firstname .. " " .. player.lastname .. " any lower.", length = 5000 })
    end
end

local function UpdateItems(gang_name)
    local gang = gangs[gang_name]
    local pinventory = gang.inventory ~= nil and json.encode(gang.inventory) or nil
    MySQL.Sync.execute("UPDATE gangs SET inventory=@inventory WHERE name=@name", {['@name'] = gang_name, ['@inventory'] = pinventory})
end

local function DepositItem(_item, amount, id)
    local leader = id
    local xLeader = ESX.GetPlayerFromId(leader)
    local gang_name = getPlayerGang(id)
    local gang_data = gangs[gang_name]
    local steamid = ""
    for _, idents in pairs(GetPlayerIdentifiers(leader)) do
        if string.sub(idents, 1, string.len("steam:")) == "steam:" then
            steamid = idents
        end
    end
    if (gang_name ~= nil) then
        if (_item == "cash" or _item == "dcash") then 
            local count = _item == "cash" and xLeader.getMoney() or xLeader.getAccount('black_money').money
            if (count - amount >= 0) then
                if (_item == "cash") then 
                    xLeader.removeMoney(amount)
                    gangs[gang_name].inventory.cash = (gangs[gang_name].inventory.cash ~= nil and gangs[gang_name].inventory.cash + amount) or amount
                    TriggerEvent("tronix-log:server:CreateLog", "all", "Money Deposited", "black", "**Name: **"..GetPlayerName(xLeader.source).." (ID: "..tonumber(leader)..") ("..steamid..")\n**Item: **"..item.label.."\n**Amount: **x"..amount.."\n**Gang: **"..gang_data.label.."\n**Date & Time: **"..(os.date("%B %d, %Y at %I:%M %p")))
                    --TriggerEvent("esxrp:discordlog", "Money Deposited", "**Name: **"..GetPlayerName(xLeader.source).." (ID: "..tonumber(leader)..") ("..steamid..")\n**Amount: **$"..amount.."\n**Gang: **"..gang_data.label.."\n**Date & Time: **"..(os.date("%B %d, %Y at %I:%M %p")), "https://discord.com/api/webhooks/858412064308723752/2D3CIG_650v9LW2SlY5Pd5bMkaP2ebt5nvO7GGIouRVMtpP5PYeXXTApjf_awj9MES1R", 'Gang Storage')
                else
                    xLeader.removeAccountMoney('black_money', amount)
                    gangs[gang_name].inventory.dcash = (gangs[gang_name].inventory.dcash ~= nil and gangs[gang_name].inventory.dcash + amount) or amount
                    TriggerEvent("tronix-log:server:CreateLog", "all", "Dirty Money Deposited", "black", "**Name: **"..GetPlayerName(xLeader.source).." (ID: "..tonumber(leader)..") ("..steamid..")\n**Item: **"..item.label.."\n**Amount: **x"..amount.."\n**Gang: **"..gang_data.label.."\n**Date & Time: **"..(os.date("%B %d, %Y at %I:%M %p")))
                   -- TriggerEvent("esxrp:discordlog", "Dirty Money Deposited", "**Name: **"..GetPlayerName(xLeader.source).." (ID: "..tonumber(leader)..") ("..steamid..")\n**Amount: **$"..amount.."\n**Gang: **"..gang_data.label.."\n**Date & Time: **"..(os.date("%B %d, %Y at %I:%M %p")), "https://discord.com/api/webhooks/858412064308723752/2D3CIG_650v9LW2SlY5Pd5bMkaP2ebt5nvO7GGIouRVMtpP5PYeXXTApjf_awj9MES1R", 'Gang Storage')
                end
                UpdateItems(gang_name)
            else
                TriggerClientEvent('esx:showNotification', leader, "You dont have enough.")
            end
        else
            local item = xLeader.getInventoryItem(_item)
            if (item.count - amount >= 0) then
                xLeader.removeInventoryItem(item.name, amount)
                gangs[gang_name].inventory = gangs[gang_name].inventory == nil and {} or gangs[gang_name].inventory
                gangs[gang_name].inventory.items[item.name] = gangs[gang_name].inventory.items[item.name] ~= nil and (gangs[gang_name].inventory.items[item.name] + amount) or amount
                UpdateItems(gang_name)
                TriggerEvent("tronix-log:server:CreateLog", "all", "Item Deposited", "black", "**Name: **"..GetPlayerName(xLeader.source).." (ID: "..tonumber(leader)..") ("..steamid..")\n**Item: **"..item.label.."\n**Amount: **x"..amount.."\n**Gang: **"..gang_data.label.."\n**Date & Time: **"..(os.date("%B %d, %Y at %I:%M %p")))
                --TriggerEvent("esxrp:discordlog", "Item Deposited", "**Name: **"..GetPlayerName(xLeader.source).." (ID: "..tonumber(leader)..") ("..steamid..")\n**Item: **"..item.label.."\n**Amount: **x"..amount.."\n**Gang: **"..gang_data.label.."\n**Date & Time: **"..(os.date("%B %d, %Y at %I:%M %p")), "https://discord.com/api/webhooks/858412064308723752/2D3CIG_650v9LW2SlY5Pd5bMkaP2ebt5nvO7GGIouRVMtpP5PYeXXTApjf_awj9MES1R", 'Gang Storage')
            else
                TriggerClientEvent('esx:showNotification', leader, "You dont have enough.")
            end
        end
    end
end

local function RemoveItem(_item, amount, id)
    local leader = id
    local xLeader = ESX.GetPlayerFromId(leader)
    local gang_name = getPlayerGang(id)
    local gang_data = gangs[gang_name]
    local gang_inventory = gangs[gang_name].inventory
    local steamid = ""
    for _, idents in pairs(GetPlayerIdentifiers(leader)) do
        if string.sub(idents, 1, string.len("steam:")) == "steam:" then
            steamid = idents
        end
    end
    if (gang_name ~= nil) then
        if (_item == "cash" or _item == "dcash") then 
            local count = _item == "cash" and gang_inventory.cash or gang_inventory.dcash
            if (count ~= nil and count - amount >= 0) then 
                if (_item == "cash") then 
                    xLeader.addMoney(amount)
                    gangs[gang_name].inventory.cash = gangs[gang_name].inventory.cash - amount
                    TriggerEvent("tronix-log:server:CreateLog", "all", "Money Withdrawn", "black", "**Name: **"..GetPlayerName(xLeader.source).." (ID: "..tonumber(leader)..") ("..steamid..")\n**Amount: **$"..amount.."\n**Gang: **"..gang_data.label.."\n**Date & Time: **"..(os.date("%B %d, %Y at %I:%M %p")))
                else 
                    xLeader.addAccountMoney('black_money', amount)
                    gangs[gang_name].inventory.dcash = gangs[gang_name].inventory.dcash - amount
                    TriggerEvent("tronix-log:server:CreateLog", "all", "Dirty Money Withdrawn", "black", "**Name: **"..GetPlayerName(xLeader.source).." (ID: "..tonumber(leader)..") ("..steamid..")\n**Amount: **$"..amount.."\n**Gang: **"..gang_data.label.."\n**Date & Time: **"..(os.date("%B %d, %Y at %I:%M %p")))
                end
                UpdateItems(gang_name)
            else
                TriggerClientEvent('esx:showNotification', leader, "You dont have enough.")
            end
        else
            local item = gangs[gang_name].inventory.items[_item]
            local thing = xLeader.getInventoryItem(_item)
            if (item ~= nil and item - amount >= 0) then
                xLeader.addInventoryItem(_item, amount)
                gangs[gang_name].inventory.items[_item] = gangs[gang_name].inventory.items[_item] - amount
                UpdateItems(gang_name)
                TriggerEvent("tronix-log:server:CreateLog", "all", "Item Withdrawn", "black", "**Name: **"..GetPlayerName(xLeader.source).." (ID: "..tonumber(leader)..") ("..steamid..")\n**Item: **"..thing.label.."\n**Amount: **x"..amount.."\n**Gang: **"..gang_data.label.."\n**Date & Time: **"..(os.date("%B %d, %Y at %I:%M %p")))
            else
                TriggerClientEvent('esx:showNotification', leader, "You dont have enough.")
            end
        end
    end
end

local function FinishCapturing(_zone)
    local zone = zones[_zone]
    local members = zone.members
    local dead = zone.deadmembers
    local counts = {["police"] = 0}
    local highest = {name = "", count = 0}
    for k,v in pairs(members) do
        if (dead[k] == nil) then
            local g_name = getPlayerGang(k)
            if (g_name ~= nil) then
                counts[g_name] = counts[g_name] ~= nil and counts[g_name] + 1 or 1
            end
        else
            members[k] = nil
        end
    end
    for k,v in pairs(counts) do
        if (v == highest.count and highest.count > 0) then
            highest.name = ""
            highest.count = 0
            break 
        elseif (v > highest.count) then
            highest.name = k
            highest.count = v
        end
    end
    if (highest.name == "") then
        chatMessage(-1, "", '⚔️The turf⚔️ "^3'.. zone.Label ..'^0" has ended in a ^3tie^0! No winners this time...')
    else
        local winner_label = highest.name
        local rewarded_depts = {}

        if (winner_label == "police") then
            winner_label = "the police"
        else
            winner_label = gangs[winner_label].label
        end
        
        local rewards = zone.Rewards
        local items = rewards['items']
        
        if (highest.name ~= "police") then
            for k,v in pairs(items) do
                gangs[highest.name].inventory = gangs[highest.name].inventory == nil and {} or gangs[highest.name].inventory
                gangs[highest.name].inventory.items[k] = gangs[highest.name].inventory.items[k] ~= nil and (gangs[highest.name].inventory.items[k] + v) or v
                UpdateItems(highest.name)
            end
            gangs[highest.name].inventory.cash = (gangs[highest.name].inventory.cash ~= nil and gangs[highest.name].inventory.cash + rewards['cash']) or rewards['cash']
            gangs[highest.name].inventory.dcash = (gangs[highest.name].inventory.dcash ~= nil and gangs[highest.name].inventory.dcash + rewards['dcash']) or rewards['dcash']
        end
        zones_waiting[_zone] = Config.CaptureCooldown
        local amount = highest.name == 'police' and ("Cash: ^2$" .. ((rewards['cash'] + rewards['dcash']) * 2) .. "^0" ) or ("Cash: ^2$" .. rewards['cash'] .. "^0 Dirty Cash: ^2$" .. rewards['dcash'] .. "^0")
        chatMessage(-1, "", '⚔️The turf⚔️ "^3'.. zone.Label ..'^0" was captured by ^3'.. winner_label..'^0! (Rewards: '.. amount ..'.')
        TriggerEvent("tronix-log:server:CreateLog", "Turf", "Turf War Completed", "purple", "**Winner**: ".. winner_label .."\n**Location**: \"" .. zone.Label .. "\"\n**Money**: ".. amount .. "\n**Items**: "  .. json.encode(items) .. "")
    end
    zones[_zone].capturing = false
    zones[_zone].members = {}
    zones[_zone].deadmembers = {}
    TriggerClientEvent("esx_gangs:UpdateZones", -1, zones)
end

RegisterServerEvent("esx_gangs:InitializeClient")
AddEventHandler("esx_gangs:InitializeClient", function() 
    local _source = source
    initialized[_source] = true
    TriggerClientEvent("esx_gangs:UpdateZones", -1, zones)
    InitializePlayerData(_source)
end)

RegisterServerEvent("esx_gangs:FirePlayer")
AddEventHandler("esx_gangs:FirePlayer", function(ident) 
    local leader = source
    local identifier = ident
    local l_gang = getPlayerGang(leader)
    local l_rank = getPlayerRank(leader, l_gang)
    if (isGangLeader(leader, l_gang)) then
        local t_player = MySQL.Sync.fetchAll('SELECT `name`, `identifier`, `gang_rank` FROM `users` WHERE gang=@gang AND identifier=@identifier', {['@gang'] = l_gang, ['@identifier'] = identifier})
        if (#t_player == 1) then
            local player = t_player[1]
            if (l_rank.ranking > player.gang_rank) then
                FirePlayer(player.identifier)
            end
        end
    end
end)

RegisterServerEvent("esx_gangs:PromotePlayer")
AddEventHandler("esx_gangs:PromotePlayer", function(ident) 
    print("--Promoted--")
    print(ident)
    local leader = source
    local identifier = ident
    local l_gang = getPlayerGang(leader)
    local l_rank = getPlayerRank(leader, l_gang)
    if (isGangLeader(leader, l_gang)) then
        local t_player = MySQL.Sync.fetchAll('SELECT `firstname`, `lastname`, `name`, `identifier`, `gang_rank` FROM `users` WHERE gang=@gang AND identifier=@identifier', {['@gang'] = l_gang, ['@identifier'] = identifier})
        if (#t_player == 1) then
            local player = t_player[1]
            if (l_rank.ranking > player.gang_rank + 1) then
                PromotePlayer(player.identifier,leader) 
                print("Promoted Promoted")
            else
                TriggerClientEvent('mythic_notify:client:SendAlert', leader, { type = 'error', text = "Couldn't promote " .. player.firstname .. " " .. player.lastname .. " any higher.", length = 5000 })
            end
        end
    end
end)

RegisterServerEvent("esx_gangs:InvitePlayer")
AddEventHandler("esx_gangs:InvitePlayer", function(ident) 
    local leader = source
    local identifier = ident
    local xInvite = ESX.GetPlayerFromIdentifier(ident)
    local i_gang = getPlayerGang(xInvite.source)
    if (i_gang == nil) then
        local l_gang = getPlayerGang(leader)
        local l_rank = getPlayerRank(leader, l_gang)
        if (isGangLeader(leader, l_gang)) then
            InvitePlayer(ident, l_gang) 
        end
    else 
        TriggerClientEvent('mythic_notify:client:SendAlert', leader, { type = 'error', text = "That person is already in another gang.", length = 5000 })
    end
end)

RegisterServerEvent("esx_gangs:DemotePlayer")
AddEventHandler("esx_gangs:DemotePlayer", function(ident) 
    print("Triggered Demote" ..ident)
    local leader = source
    local identifier = ident
    local l_gang = getPlayerGang(leader)
    local l_rank = getPlayerRank(leader, l_gang)
    if (isGangLeader(leader, l_gang)) then
        local t_player = MySQL.Sync.fetchAll('SELECT `firstname`, `lastname`, `name`, `identifier`, `gang_rank` FROM `users` WHERE gang=@gang AND identifier=@identifier', {['@gang'] = l_gang, ['@identifier'] = identifier})
        if (#t_player == 1) then
            local player = t_player[1]
            if (l_rank.ranking > player.gang_rank and 0 <= player.gang_rank - 1) then
                DemotePlayer(player.identifier,leader) 
            else
                TriggerClientEvent('mythic_notify:client:SendAlert', leader, { type = 'error', text = "Couldn't demote " .. player.firstname .. " " .. player.lastname .. " any lower.", length = 5000 })
            end
        end
    end
end)

RegisterServerEvent("esx_gangs:zoneInteracted")
AddEventHandler("esx_gangs:zoneInteracted", function(_zone)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    local zone = zones[_zone]
    local gang = getPlayerGang(_source)
    if (zones_waiting[_zone] == nil or zones_waiting[_zone] <= 0) then
        if (zone ~= nil and (gang ~= nil)) then
            if (not zone.capturing) then 
                zone.capturing = true
                zone.members = {}
                zone.deadmembers = {}
                zone.timer = Config.CaptureTimer
                chatMessage(-1, "", '⚔️The Turf⚔️ "^3'.. zone.Label ..'^0" IS NOW UNDER ^2ATTACK^0 by ^3"'.. gangs[gang].label ..'^3"^7!')
                TriggerEvent("tronix-log:server:CreateLog", "Turf", "Turf War is Now Under Attack", "purple", "**Initiating Gang**: ".. gangs[gang].label .."\n**Location**: \"" .. zone.Label .. "\"\n**Date & Time: **"..(os.date("%B %d, %Y at %I:%M %p")))
                zones[_zone] = zone
                TriggerClientEvent("esx_gangs:UpdateZones", -1, zones)
            end
        else
            TriggerClientEvent('esx:showNotification', _source, "You are not in a gang.")
        end
    else
        TriggerClientEvent('esx:showNotification', _source, "This zone is on a cooldown for ".. zones_waiting[_zone] .." more seconds.")
    end
end)

RegisterServerEvent("esx_gangs:PlayerEnteredZone")
AddEventHandler("esx_gangs:PlayerEnteredZone", function(_zone)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    local zone = zones[_zone]
    local gang = getPlayerGang(_source)
    if (zone ~= nil and (gang ~= nil)) then
        if (zone.members ~= nil) then 
            zone.members[_source] = "gang"
        end
        zones[_zone] = zone
        TriggerClientEvent("esx_gangs:UpdateZones", -1, zones)
    else
        TriggerClientEvent('esx:showNotification', _source, "~r~You are not in a gang.~w~")
    end
end)

RegisterServerEvent("esx_gangs:PlayerExitedZone")
AddEventHandler("esx_gangs:PlayerExitedZone", function(_zone)
    local _source = source
    local zone = zones[_zone]
    zone.members[_source] = nil
end)

RegisterServerEvent("esx_gangs:AddDeadPlayer")
AddEventHandler("esx_gangs:AddDeadPlayer", function(last_zone)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    local zone = zones[_zone]
    local gang = getPlayerGang(_source)
    if (zones_waiting[_zone] == nil or zones_waiting[_zone] <= 0) then
        if (zone ~= nil and (gang ~= nil)) then
            if (zone.capturing) then 
                zones[_zone].deadmembers[_source] = true
            end
        end
    end

end)

ESX.RegisterServerCallback('esx_gangs:getMembers', function(source, cb, gang_name)
	local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if (isGangLeader(_source, gang_name)) then
        local gang = gangs[gang_name]
        local gang_rank = getPlayerRank(_source, gang_name).ranking
        if (gang ~= nil) then 
            local players = {}
            local members = MySQL.Sync.fetchAll('SELECT `name`, `identifier`, `gang_rank` FROM `users` WHERE gang=@gang AND gang_rank<@gang_rank', {['@gang'] = gang_name, ['@gang_rank'] = gang_rank})
            for i=1, #members do
                local member = members[i]
                local trank = getRankData(gang_name, member.gang_rank)
                if (trank ~= nil) then  
                    table.insert(players, {id = member.identifier, name = member.name, rank = trank})
                end
            end
            cb(players)
        else
            cb(nil)
        end
    end
end)

ESX.RegisterServerCallback('esx_gangs:getInvitablePlayers', function(source, cb, gang_name)
	local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if (isGangLeader(_source, gang_name)) then
        local gang = gangs[gang_name]
        if (gang ~= nil) then 
            local players = {}
            local members = gang.members
            local xPlayers = ESX.GetPlayers()
            for i=1, #xPlayers, 1 do
                if (members[xPlayers[i]] == nil) then
                    local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
                    table.insert(players, {id = xPlayer.identifier, sid = xPlayers[i], name = xPlayer.getName()})
                end
            end
            cb(players)
        else
            cb(nil)
        end
    end
end)

ESX.RegisterServerCallback('esx_gangs:getMember', function(source, cb, gang_name, ident)
    local _source = source
    local identifier = ident
    local xPlayer = ESX.GetPlayerFromId(_source)
    if (isGangLeader(_source, gang_name)) then
        local gang = gangs[gang_name]
        if (gang ~= nil) then 
            local player = nil
            local members = gang.members
            local members = MySQL.Sync.fetchAll('SELECT `name`, `gang`, `gang_rank` FROM `users` WHERE identifier=@identifier', {['@identifier'] = identifier})
            if (#members == 1) then 
                player = members[1]
                player.rank = player.gang_rank
                player.identifier = identifier
                player.gang_rank = nil
            end
            cb(player)
        else
            cb(nil)
        end
    end
end)

ESX.RegisterServerCallback('esx_gangs:getPlayerInventory', function(source, cb, gang_name)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if (isGangLeader(_source, gang_name)) then
        local gang = gangs[gang_name]
        local data = {}
        data.inventory = {}
        local inventory = xPlayer.getInventory()
        for i=1, #inventory do 
            local item = inventory[i]
            if (item.count > 0) then
                table.insert(data.inventory, item)
            end
        end
        data.cash = xPlayer.getMoney()
        data.dcash = xPlayer.getAccount('black_money').money
        cb(data)
    end
end)

ESX.RegisterServerCallback('esx_gangs:getInventory', function(source, cb, gang_name)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    if (isGangLeader(_source, gang_name)) then
        local gang = gangs[gang_name]
        local inventory = {}
        local tinventory = gang.inventory
        if (tinventory == nil) then
            inventory.cash = 0
            inventory.dcash = 0
            inventory.items = {}
            -- {cash = $cash, dcash = $dcash, items = {$item1=$quantity1, $item2=$quantity2, $item3=$quantity3} }
        else
            inventory.cash = gang.inventory.cash ~= nil and gang.inventory.cash or 0
            inventory.dcash = gang.inventory.dcash ~= nil and gang.inventory.dcash or 0
            inventory.items = {}
            for k,v in pairs(tinventory.items) do 
                local item = xPlayer.getInventoryItem(k)
                inventory.items[k] = item
                if (inventory.items[k] ~= nil) then
                    inventory.items[k].count = v
                end
            end
        end
        cb(inventory)
    end
end)

ESX.RegisterServerCallback('esx_gangs:getVehicles', function(source, cb, gang_name) 
    local leader = source
    local l_gang = getPlayerGang(leader)
    local l_rank = getPlayerRank(leader, l_gang)
    local vehicles = Config.Gangs[l_gang].Vehicles
    cb(vehicles)
end)

ESX.RegisterServerCallback('esx_gangs:spawnVehicle', function(source, cb, vehicle_name) 
    local leader = source
    local l_gang = getPlayerGang(leader)
    local l_rank = getPlayerRank(leader, l_gang)
    local vehicles = Config.Gangs[l_gang].Vehicles
    if (vehicles[vehicle_name] ~= nil) then 
        local xLeader = ESX.GetPlayerFromId(leader)
        cash = xLeader.getMoney()
        if (cash - vehicles[vehicle_name] >= 0) then
            xLeader.removeMoney(vehicles[vehicle_name])
            cb(true)
        else
            TriggerClientEvent('esx:showNotification', leader, "~r~You dont have enough.~w~")
            cb(false)
        end
    else 
        cb(false)
    end
end)



ESX.RegisterServerCallback('esx_gangs:allowedToManage', function(source, cb)
    local leader = source
    local l_gang = getPlayerGang(leader)
    if (isGangLeader(leader, l_gang)) then
        cb(true)
    else
        cb(false)
    end
end)

RegisterServerEvent("esx_gangs:DepositItem")
AddEventHandler("esx_gangs:DepositItem", function(item, amount) 
    local leader = source
    local l_gang = getPlayerGang(leader)
    if (isGangLeader(leader, l_gang)) then
        DepositItem(item, amount, leader)
    end
end)

RegisterServerEvent("esx_gangs:RemoveItem")
AddEventHandler("esx_gangs:RemoveItem", function(item, amount) 
    local leader = source
    local l_gang = getPlayerGang(leader)
    if (isGangLeader(leader, l_gang)) then
        RemoveItem(item, amount, leader)
    end
end)

AddEventHandler('playerDropped', function()
    local _source = source
    RemovePlayerData(_source)
end)

RegisterCommand("setgang", function(src, args, raw)
    local source = src
    if (isAdmin(source)) then 
        local target = args[1]
        local gang = args[2]
        local rank = args[3]
        if (target ~= nil) then
            target = tonumber(target) ~= nil and tonumber(target) or nil
        end
        if (gang ~= nil) then 
            gang = gangs[gang] ~= nil and gangs[gang] or nil
            if (gang ~= nil and rank ~= nil) then 
                rank = tonumber(rank) ~= nil and tonumber(rank) or nil
                if (rank ~= nil) then
                    rank = rank == -1 and rank or getRankData(gang.name, rank)
                end
            end
        end
        if (target ~= nil and gang ~= nil and rank ~= nil) then 
            local xTarget = ESX.GetPlayerFromId(target)
            if (rank == -1) then
                FirePlayer(xTarget.identifier)
            else
                InsertPlayer(xTarget.identifier, gang.name, rank.ranking)
            end
        else
            TriggerClientEvent('mythic_notify:client:SendAlert', source, { type = 'error', text = "Usage: /setgang [player_id] [gang_name] [#rank]", length = 5000 })
        end
    else
        TriggerClientEvent('mythic_notify:client:SendAlert', source, { type = 'error', text = "You don't have permission to use this command.", length = 5000 })
    end
end, false)

Citizen.CreateThread(function()
    InitializeData()
    while true do 
        Citizen.Wait(1000)
        for k,v in pairs(zones) do 
            zones[k].capturing = zones[k].capturing ~= nil and zones[k].capturing or false
            if (zones[k].timer ~= nil and zones[k].timer > 0) then 
                zones[k].timer = zones[k].timer - 1
                if (zones[k].timer <= 0) then
                    zones[k].timer = nil
                    FinishCapturing(k)
                end
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do 
        Citizen.Wait(1000)
        for k,v in pairs(zones_waiting) do
            if (zones_waiting[k] > 0) then
                zones_waiting[k] = zones_waiting[k] - 1
            end
        end
    end
end)

RegisterCommand("leavegang", function(src, args, raw)
    local source = src
    local l_gang = getPlayerGang(source)
    local l_rank = l_gang ~= nil and getPlayerRank(source, l_gang) or nil
    if (l_gang ~= nil and l_rank ~= nil) then 
        local xTarget = ESX.GetPlayerFromId(source)
        FirePlayer(xTarget.identifier)
    end
end, false)




RegisterServerEvent("Fetch:Gang:Shit")
AddEventHandler("Fetch:Gang:Shit", function()
    local src = source

    local steamid = ""
       for _, idents in pairs(GetPlayerIdentifiers(src)) do
        if string.sub(idents, 1, string.len("steam:")) == "steam:" then
            steamid = idents
        end
	   end

    exports.ghmattimysql:execute("select * FROM users WHERE identifier = @idshit ORDER BY gang_rank Desc;", {['idshit'] = steamid}, function(data222)
        if data222[1] ~= nil then

            exports.ghmattimysql:execute("SELECT * FROM users WHERE gang = @ganglol ", {['ganglol'] = data222[1].gang}, function(data)
                if data[1] ~= nil then

                    exports.ghmattimysql:execute("SELECT inventory FROM gangs WHERE name = @gangname", {['gangname'] = data222[1].gang}, function(gangshit)
                        if gangshit[1] ~= nil then
                            local result = gangs[data222[1].gang].inventory.dcash

                            for i =1, #data do
                            local rank_data = getRankData(data222[1].gang, data[i].gang_rank)
                            TriggerClientEvent('Cl:Fetch:Gang', src, data[i], result,rank_data.label)
                        end
                        end
                    end)
                end
            end)
        end

    end)

end)
