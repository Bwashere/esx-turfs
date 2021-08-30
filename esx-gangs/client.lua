ESX              = nil
local PlayerData = {}
local curGang = nil
local curRank = nil
local menu_open = false 
local inside_menu = false
local vehicle_spawn_timer = 0
local IsDead = false
local lastvalid = nil
local zones = Config.Zones
local inside_zone = false
local last_zone = nil












-- Brackzz LOL
-- [/Turfs Command] 
RegisterCommand("turfs", function() -- kaBam
		-- Magic Below
    local turfString = ""
	  for i, v in pairs(zones) do
        if v.capturing == true then
             turfString = turfString .. v.Label .. " is being captured.\n"
        end
    end
-- Turf Strin
    if turfString == "" then
        turfString = "No Zones Are Being Captured."
    end

    TriggerEvent('chat:addMessage', {
      color = { 0, 0, 255 }, -- Change Color by rgb color codes not hard lol - brackzz
      multiline = true,
      args = {"[Esx-Turfs]", turfString}
    })
end)





--------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------


local mygang = {}
local invite = {}


function EnableSelector(enable)

  SendNUIMessage({
    type = "Selector",
    enable = enable,
  })
  SetNuiFocus(enable,enable)
end

function EnableMenu(enable,data)
   SendNUIMessage({
     type = "OpenBoss",
     enable = enable,
     gang = data
   })
   SetNuiFocus(enable,enable)
end

RegisterCommand("gm", function()
  ESX.TriggerServerCallback('esx_gangs:allowedToManage', function(result)
      if result then
          EnableSelector(true)
      else
        TriggerEvent('esx:showNotification', "You are not permitted to manage this gang.")
      end
    end)
end)

RegisterNUICallback('EnableManage', function(data,cb)
   TriggerEvent("Open:Manage")
   cb('ok')
end)


function EnableInvite(enable,data)
  SendNUIMessage({
    type = "OpenInvite",
    enable = enable,
    invites = data
  })
  SetNuiFocus(enable,enable)
end


RegisterNUICallback('EnableInvite', function(data,cb)
  TriggerEvent("Open:Invite")
  cb('ok')
end)

RegisterNUICallback('InvitePlayer', function(data,cb) 
  TriggerServerEvent("esx_gangs:InvitePlayer", data.idshit)
  cb('ok')
end)

RegisterNetEvent("Open:Invite")
AddEventHandler("Open:Invite", function()
    invite = nil
    invite = {}
   
    ESX.TriggerServerCallback('esx_gangs:getInvitablePlayers', function(result)
      local list = {}
      if result then
        for i=1, #result do
          table.insert(invite, {label = result[i].name .. " (id: ".. result[i].sid ..")", value = result[i].id})
        end
      end
    end,curGang)
    Wait(500)
    EnableInvite(true,invite)
end)


RegisterNetEvent("Open:Manage")
AddEventHandler("Open:Manage", function()

  mygang = nil
  mygang = {}
     TriggerServerEvent("Fetch:Gang:Shit")
    Wait(500)
    EnableMenu(true,mygang)

end)


RegisterNUICallback('closemenu', function(data,cb)
   SetNuiFocus(false,false)
   cb('ok')
end)



RegisterNetEvent('Cl:Fetch:Gang')
AddEventHandler('Cl:Fetch:Gang', function(data,data2,rankss)
  
  table.insert(mygang, {Name = data.name,Id = data.identifier,Rank = rankss, gang = data.gang,gangmoney = data2,namelol = data.firstname, namelol2 = data.lastname})
end)


RegisterNUICallback('PromotePlayer', function(data,cb)
  TriggerServerEvent("esx_gangs:PromotePlayer", data.ident)
  cb('ok')
end)

RegisterNUICallback('KickPlayer', function(data,cb)
  TriggerServerEvent("esx_gangs:FirePlayer", data.ident)
  cb('ok')
end)

RegisterNUICallback('DemotePlayer', function(data,cb)
  TriggerServerEvent("esx_gangs:DemotePlayer", data.ident)
  cb('ok')
end)















































































Citizen.CreateThread(function()
	while ESX == nil do
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
    Citizen.Wait(0)
  end
  TriggerServerEvent("esx_gangs:InitializeClient")
  ESX.UI.Menu.CloseAll()
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
  PlayerData = xPlayer   
end)

RegisterNetEvent('esx_gangs:UpdateClient')
AddEventHandler('esx_gangs:UpdateClient', function(_gang, _rank)
  curGang = _gang.name
  curRank = _rank.ranking
  SendNUIMessage({
    type    = "update",
    data  = {gang = _gang, rank = _rank},
  })
end)

RegisterNetEvent('esx_gangs:UpdateZones')
AddEventHandler('esx_gangs:UpdateZones', function(_zones)
  zones = _zones
end)

local function playerDied()
  if (last_zone ~= nil and zones[last_zone].capturing) then
    TriggerServerEvent("esx_gangs:AddDeadPlayer", last_zone)
  end
end

AddEventHandler('baseevents:onPlayerDied', function(killerType, coords)
	playerDied()
end)

AddEventHandler('baseevents:onPlayerKilled', function(killerId, data)
	playerDied()
  TriggerServerEvent("Turf:Add:Kill:Add:Death",killerId)
end)

local function DrawZoneTimer(_zone)
	local x = 1.15
	local y = 0.505
	local width = 1.0
	local height = 1.0
	local scale = 0.37 --43
	local text = ""
	if (_zone ~= -1) then
		local zone = zones[_zone]
		if (zone.timer ~= nil) then
      text = "~p~".. zone.Label .." - ~g~Capture Timer~w~: " .. zone.timer .. " seconds~w~"
		end
	end
	if AOPLocation == 1 or AOPLocation == 4 then
		SetTextCentre(true)
	end
	SetTextFont(4)
	SetTextProportional(0)
	SetTextScale(scale, scale)
	SetTextColour(255, 0, 0, 255)
	SetTextDropShadow(0, 0, 0, 0,255)
	SetTextEdge(2, 0, 0, 0, 255)
	SetTextDropShadow()
	SetTextOutline()
	SetTextEntry("STRING")
	AddTextComponentString(text)
	DrawText(x - width/2, y - height/2 + 0.005)
end

local function DisplayHelpText(str)
  SetTextComponentFormat("STRING")
  AddTextComponentString(str)
  DisplayHelpTextFromStringLabel(0, 0, 1, -1)
end

local function OpenMenu(menu, params)
  ESX.TriggerServerCallback('esx_gangs:allowedToManage', function(result)
    if (not result and menu ~= "vehicle" and menu ~= "vehicle_return") then
      TriggerEvent('esx:showNotification', "You are not permitted to manage this gang.")
    else
      menu_open = true
      local gang = curGang
      if (menu == "manage") and notAllowedToManage ~= 1 then
        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'gangs_manage_main',
        {
            title    = "Gang Management (".. gang ..")",
            align    = 'top-left',
            elements = {
              {label = "Invite Players", value = "invite"},
              {label = "Manage Members", value = "members"},
              {label = "Inventory", value = "inventory"},
            }
        }, function(data, menu)
            menu.close()
            local option = data.current.value
            OpenMenu(option)
        end, function(data, menu)
          menu.close()
        end)
      elseif (menu == "vehicle") then
        if (vehicle_spawn_timer == 0) then
          ESX.TriggerServerCallback('esx_gangs:getVehicles', function(result) 
            local list = {}
            if (result ~= nil) then
              for k,v in pairs(result) do 
                table.insert(list, {label = k .. " ($".. v .. ")", value = k})
              end
              ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'gangs_vehicle_select',
              {
                  title    = "Gang Vehicles",
                  align    = 'top-left',
                  elements = list
              }, function(data, menu)
                menu.close()
                ESX.TriggerServerCallback('esx_gangs:spawnVehicle', function(result) 
                  if (result) then 
                    local marker = Config.Gangs[gang].Markers.VehicleReturn
                    local location = Config.Gangs[gang].Markers.VehicleReturn.Location
                    local model = GetHashKey(data.current.value)
                    RequestModel(model)
                    while not HasModelLoaded(model) do
                      Citizen.Wait(0)
                    end
                    local vehicle = CreateVehicle(model, location.x, location.y, location.z, location.h, true, false)
                    SetVehicleOnGroundProperly(vehicle)
                    SetModelAsNoLongerNeeded(model)
                    TaskWarpPedIntoVehicle(GetPlayerPed(-1), vehicle, -1)
                    vehicle_spawn_timer = Config.VehicleSpawnTimer
                  end
                end, data.current.value)
              end, function(data, menu)
                menu.close()
              end)
            end
          end, gang)
        else
          TriggerEvent('esx:showNotification', "Wait ".. vehicle_spawn_timer .." second(s) to spawn a vehicle again.")
        end
      elseif (menu == "vehicle_return") then
        local vehicle = GetVehiclePedIsIn(GetPlayerPed(-1), false)
        if (vehicle ~= nil) then 
          local entity = vehicle
          NetworkRequestControlOfEntity(entity)
      
          local timeout = 2000
          while timeout > 0 and not NetworkHasControlOfEntity(entity) do
              Wait(100)
              timeout = timeout - 100
          end
      
          SetEntityAsMissionEntity(entity, true, true)
          
          local timeout = 2000
          while timeout > 0 and not IsEntityAMissionEntity(entity) do
              Wait(100)
              timeout = timeout - 100
          end

          Citizen.InvokeNative( 0xEA386986E786A54F, Citizen.PointerValueIntInitialized( entity ) )
          
          if (DoesEntityExist(entity)) then 
              DeleteEntity(entity)
          end 
        end
      elseif (menu == "inventory") then
        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'gangs_inventory_method',
        {
            title    = "Gang Inventory",
            align    = 'top-left',
            elements = {
              {label = "Deposit Money and/or Items", value = "add_items"},
              {label = "Withdraw Money and/or Items", value = "remove_items"},
            }
        }, function(data, menu)
          menu.close()
          OpenMenu(data.current.value)
        end, function(data, menu)
          menu.close()
          OpenMenu("manage")
        end)
      elseif (menu == "add_items") then
        ESX.TriggerServerCallback('esx_gangs:getPlayerInventory', function(result) 
          local list = {}
          if (result ~= nil) then
              local cash = result.cash
              local dcash = result.dcash
              table.insert(list, {label = "Cash: $"..result.cash, value = "cash"})
              table.insert(list, {label = "Dirty Money: $"..result.dcash, value = "dcash"})
              for k,v in pairs(result.inventory) do
                  local item = v
                  table.insert(list, {label = item.label .. "(x".. item.count ..")", value = item})
              end
              
              --------------------------------------------------------------------------------
              
              ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'gangs_inventory_add',
              {
                  title    = "Deposit Money and/or Items",
                  align    = 'top-left',
                  elements = list
              }, function(data, menu)
                  menu.close()
                  if (data.current.value ~= "cash" and data.current.value ~= "dcash") then 
                    local item = data.current.value
                    ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'gangs_inventory_item_deposit', {title = "Deposit " .. item.label .. " into inventory"}, 
                    function(data, menu)
                        menu.close()
                        local count = tonumber(data.value)
                        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'gangs_inventory_item_deposit_confirm',
                        {
                            title    = "Are you sure you want to deposit " .. item.label .."(x"..count..") into inventory?",
                            align    = 'top-left',
                            elements = {
                                {label = "Yes", value = "yes"},
                                {label = "No", value = "no"},
                            }
                        }, function(data, menu)
                            menu.close()
                            if (data.current.value == "yes") then 
                              TriggerServerEvent("esx_gangs:DepositItem", item.name, count)
                            end
                            OpenMenu("add_items")
                        end, function(data, menu)
                            menu.close()
                            OpenMenu("add_items")
                        end)
                    end, function(data, menu)
                        menu.close()
                        OpenMenu("add_items")
                    end)
                  else
                      local option = data.current.value
                      ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'gangs_inventory_cash_deposit', {title = "Deposit $" .. ( option == "cash" and "Cash" or "Dirty Money") .. " into inventory"}, 
                      function(data, menu)
                          menu.close()
                          local count = tonumber(data.value)
                          ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'gangs_inventory_cash_deposit_confirm',
                          {
                              title    = "Are you sure you want to deposit $" .. count .. " in ".. ( option == "cash" and "Cash" or "Dirty Money") .."?",
                              align    = 'top-left',
                              elements = {
                                  {label = "Yes", value = "yes"},
                                  {label = "No", value = "no"},
                              }
                          }, function(data, menu)
                              menu.close()
                              if (data.current.value == "yes") then 
                                TriggerServerEvent("esx_gangs:DepositItem", option, count)
                              end
                              OpenMenu("add_items")
                          end, function(data, menu)
                              menu.close()
                              OpenMenu("add_items")
                          end)
                      end, function(data, menu)
                          menu.close()
                          OpenMenu("add_items")
                      end)
                  end
              end, function(data, menu)
                  menu.close()
                  OpenMenu("inventory")
              end)
          end
        end, gang)
      elseif (menu == "remove_items") then
        ESX.TriggerServerCallback('esx_gangs:getInventory', function(result) 
          local list = {}
          if (result ~= nil) then
              local cash = result.cash
              local dcash = result.dcash
              table.insert(list, {label = "Cash: $"..result.cash, value = "cash"})
              table.insert(list, {label = "Dirty Money: $"..result.dcash, value = "dcash"})
              for k,v in pairs(result.items) do
                  local item = v
                  table.insert(list, {label = item.label .. "(x".. item.count ..")", value = item})
              end
              
              --------------------------------------------------------------------------------
              
              ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'gangs_inventory_remove',
              {
                  title    = "Withdraw Money and/or Items",
                  align    = 'top-left',
                  elements = list
              }, function(data, menu)
                  menu.close()
                  if (data.current.value ~= "cash" and data.current.value ~= "dcash") then 
                    local item = data.current.value
                    ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'gangs_inventory_item_remove', {title = "Withdraw " .. item.label .. " from inventory"}, 
                    function(data, menu)
                        menu.close()
                        local count = tonumber(data.value)
                        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'gangs_inventory_item_remove_confirm',
                        {
                            title    = "Are you sure you want to remove " .. item.label .."(x"..count..") from the inventory?",
                            align    = 'top-left',
                            elements = {
                                {label = "Yes", value = "yes"},
                                {label = "No", value = "no"},
                            }
                        }, function(data, menu)
                            menu.close()
                            if (data.current.value == "yes") then 
                              TriggerServerEvent("esx_gangs:RemoveItem", item.name, count)
                            end
                            OpenMenu("remove_items")
                        end, function(data, menu)
                            menu.close()
                            OpenMenu("remove_items")
                        end)
                    end, function(data, menu)
                        menu.close()
                        OpenMenu("remove_items")
                    end)
                  else
                      local option = data.current.value
                      ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'gangs_inventory_cash_remove', {title = "Withdraw $" .. ( option == "cash" and "Cash" or "Dirty Money") .. " into inventory"}, 
                      function(data, menu)
                          menu.close()
                          local count = tonumber(data.value)
                          ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'gangs_inventory_cash_remove_confirm',
                          {
                              title    = "Are you sure you want to remove $" .. count .. " in ".. ( option == "cash" and "Cash" or "Dirty Money") .."?",
                              align    = 'top-left',
                              elements = {
                                  {label = "Yes", value = "yes"},
                                  {label = "No", value = "no"},
                              }
                          }, function(data, menu)
                              menu.close()
                              if (data.current.value == "yes") then 
                                TriggerServerEvent("esx_gangs:RemoveItem", option, count)
                              end
                              OpenMenu("remove_items")
                          end, function(data, menu)
                              menu.close()
                              OpenMenu("remove_items")
                          end)
                      end, function(data, menu)
                          menu.close()
                          OpenMenu("remove_items")
                      end)
                  end
              end, function(data, menu)
                  menu.close()
                  OpenMenu("inventory")
              end)
          end
        end, gang)
      elseif (menu == "invite") then
        ESX.TriggerServerCallback('esx_gangs:getInvitablePlayers', function(result)
          local list = {}
          if (result ~= nil) then
            for i=1, #result do
              table.insert(list, {label = result[i].name .. " (id: ".. result[i].sid ..")", value = result[i].id})
            end
            ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'gangs_invite_players',
            {
                title    = "Members (".. gang ..")",
                align    = 'top-left',
                elements = list
            }, function(data, menu)
              menu.close()
              local i_id = data.current.value
              ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'gangs_invite_players_confirm',
              {
                  title    = "Are you sure you want to invite " .. data.current.label .. "?",
                  align    = 'top-left',
                  elements = {
                    {label = "Yes", value = "yes"},
                    {label = "No", value = "no"},
                  }
              }, function(data, menu)
                menu.close()
                if (data.current.value == "yes") then 
                  TriggerServerEvent("esx_gangs:InvitePlayer", i_id)
                  Citizen.Wait(200)
                  OpenMenu("invite")
                elseif (data.current.value == "no") then 
                  OpenMenu("invite")
                end
              end, function(data, menu)
                menu.close()
                OpenMenu("invite")
              end)
            end, function(data, menu)
              menu.close()
              OpenMenu("manage")
            end)
          end
        end, gang)
      elseif (menu == "members") then
        ESX.TriggerServerCallback('esx_gangs:getMembers', function(result)
          local list = {}
          if (result ~= nil) then
            for i=1, #result do
              table.insert(list, {label = result[i].name .. " (Rank: ".. result[i].rank.label ..")", value = result[i].id})
            end
            ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'gangs_manage_players',
            {
                title    = "Members (".. gang ..")",
                align    = 'top-left',
                elements = list
            }, function(data, menu)
              menu.close()
              OpenMenu("player_options", {id = data.current.value})
            end, function(data, menu)
              menu.close()
              OpenMenu("manage")
            end)
          end
        end, gang)
      elseif (menu == "player_options") then
        ESX.TriggerServerCallback('esx_gangs:getMember', function(result)
          if (result ~= nil) then
            ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'gangs_manage_player',
            {
                title    = "Manage Player: " .. result.name,
                align    = 'top-left',
                elements = {
                  {label = "Promote Player", value = "promote"},
                  {label = "Demote Player", value = "demote"},
                  {label = "Fire Player", value = "fire"},
                }
            }, function(data, menu)
              menu.close()
              OpenMenu(data.current.value, {data = result})
            end, function(data, menu)
              menu.close()
              OpenMenu("members")
            end)
          end
        end, gang, params.id)
      elseif (menu == "promote") then
        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'gangs_manage_players_promote',
        {
            title    = "Are you sure you want to promote " .. params.data.name .. "?",
            align    = 'top-left',
            elements = {
              {label = "Yes", value = "yes"},
              {label = "No", value = "no"},
            }
        }, function(data, menu)
          menu.close()
          if (data.current.value == "yes") then 
            TriggerServerEvent("esx_gangs:PromotePlayer", params.data.identifier)
            Citizen.Wait(200)
            OpenMenu("members")
          elseif (data.current.value == "no") then 
            OpenMenu("player_options", params.data.identifier)
          end
        end, function(data, menu)
          menu.close()
          OpenMenu("player_options", params.data.identifier)
        end)
      elseif (menu == "demote") then
        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'gangs_manage_players_demote',
        {
            title    = "Are you sure you want to demote " .. params.data.name .. "?",
            align    = 'top-left',
            elements = {
              {label = "Yes", value = "yes"},
              {label = "No", value = "no"},
            }
        }, function(data, menu)
          menu.close()
          if (data.current.value == "yes") then 
            TriggerServerEvent("esx_gangs:DemotePlayer", params.data.identifier)
            Citizen.Wait(200)
            OpenMenu("members")
          elseif (data.current.value == "no") then 
            OpenMenu("player_options")
          end
        end, function(data, menu)
          menu.close()
          OpenMenu("player_options")
        end)
      elseif (menu == "fire") then
        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'gangs_manage_players_fire',
        {
            title    = "Are you sure you want to fire " .. params.data.name .. "?",
            align    = 'top-left',
            elements = {
              {label = "Yes", value = "yes"},
              {label = "No", value = "no"},
            }
        }, function(data, menu)
          menu.close()
          if (data.current.value == "yes") then 
            TriggerServerEvent("esx_gangs:FirePlayer", params.data.identifier)
            Citizen.Wait(200)
            OpenMenu("members")
          elseif (data.current.value == "no") then 
            OpenMenu("player_options")
          end
        end, function(data, menu)
          menu.close()
          OpenMenu("player_options")
        end)
      end
    end
  end)
end

local function ZoneInteracted(_zone)
  if (not zones[_zone].capturing and curGang ~= nil) then
    TriggerServerEvent("esx_gangs:zoneInteracted", _zone)
  elseif (curGang == nil) then
    TriggerEvent('esx:showNotification', "You are not in a gang.")
  else
    TriggerEvent('esx:showNotification', "This zone is already in a Turf War. Capture it for your gang!")
  end
end

Citizen.CreateThread(function()
  local dontSkip = true
  while true do
    Citizen.Wait(0)
    local player = {}
    player.x, player.y, player.z = table.unpack(GetEntityCoords(GetPlayerPed(-1), true))
    if (curGang ~= nil and Config.Gangs[curGang] ~= nil) then 
      local gang_table = Config.Gangs[curGang].Markers
      local marker_list = {gang_table.Management, gang_table.VehicleSpawn, gang_table.VehicleReturn}
      local action_list = {"manage", "vehicle", "vehicle_return"}  
      local label_list = {"manage the gang.", "retrieve a gang vehicle.", "return a gang vehicle"}
      local set_zone = false
      for i=1, #marker_list do
        local marker = marker_list[i]
        if (Vdist(marker.Location.x, marker.Location.y, marker.Location.z, player.x, player.y, player.z) <= 10.0) then
          dontSkip = true
          DrawMarker(1, marker.Location.x, marker.Location.y, marker.Location.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 1.0, marker.Color.r, marker.Color.g, marker.Color.b, 255, false, false, false, false, false, false)
          if (Vdist(marker.Location.x, marker.Location.y, marker.Location.z, player.x, player.y, player.z) <= 1.75) then
            inside_menu = true
            set_zone = true
            if (not menu_open) then
              DisplayHelpText("Press ~INPUT_CONTEXT~ to ".. label_list[i])
              if (IsControlJustReleased(1,  51)) then
                  OpenMenu(action_list[i])
              end
            end
          elseif (not set_zone) then
            inside_menu = false
            if (menu_open) then
              ESX.UI.Menu.CloseAll()
              menu_open = false
            end
          end
        end
      end
    end
    if (not dontSkip) then 
      Citizen.Wait(300)
    end
    dontSkip = false
  end
end)

Citizen.CreateThread(function()
    local dontSkip = true
    while true do 
      Citizen.Wait(0)
      if (curGang ~= nil) then
        local player = {}
        player.x, player.y, player.z = table.unpack(GetEntityCoords(GetPlayerPed(-1), true))
        for k,v in pairs(zones) do 
          local marker = v
          if (Vdist(marker.Location.x, marker.Location.y, marker.Location.z, player.x, player.y, player.z) <= 25.0) then
            dontSkip = true
            DrawMarker(42, marker.Location.x, marker.Location.y, marker.Location.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.0, 3.0, 1.5, marker.Color.r, marker.Color.g, marker.Color.b, 255, false, false, false, true, false, false)
            if (Vdist(marker.Location.x, marker.Location.y, marker.Location.z, player.x, player.y, player.z) <= 1.75) then
              DisplayHelpText("Press ~INPUT_CONTEXT~ to capture ".. marker.Label .. ".")
              if (IsControlJustReleased(1,  51)) then
                ZoneInteracted(k)
              end
            end
          end
        end
      end
      if (not dontSkip) then 
        Citizen.Wait(300)
      end
      dontSkip = false
    end
  end)

Citizen.CreateThread(function()
  local dontSkip = true
  while true do
    Citizen.Wait(0)
    local player = {}
    player.x, player.y, player.z = table.unpack(GetEntityCoords(GetPlayerPed(-1), true))
    for k,v in pairs(zones) do 
      local marker = v
      if (Vdist(marker.Location.x, marker.Location.y, marker.Location.z, player.x, player.y, player.z) <= 100.0) then
        dontSkip = true
        if (marker.capturing) then
          DrawMarker(1, marker.Location.x, marker.Location.y, marker.Location.z - 10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 80.0, 80.0, 100.0, 136, 37, 202, 160, false, false, false, false, false, false)
          if (Vdist(marker.Location.x, marker.Location.y, marker.Location.z, player.x, player.y, player.z) <= 39.4) then
            DrawZoneTimer(k)
            if (inside_zone == false) then 
              inside_zone = true
              last_zone = k
              TriggerServerEvent("esx_gangs:PlayerEnteredZone", k)
            end
          elseif (inside_zone == true and last_zone == k) then
            inside_zone = false
            DrawZoneTimer(-1)
            TriggerServerEvent("esx_gangs:PlayerExitedZone", last_zone)
          end
        elseif (last_zone == k) then
          inside_zone = false
          last_zone = nil
        end
      end
    end
    if (not dontSkip) then 
      Citizen.Wait(300)
    end
    dontSkip = false
  end
end)

AddEventHandler('esx:onPlayerDeath', function(data)
  IsDead = true
end)

AddEventHandler('playerSpawned', function()
	IsDead = false
end)

local blips = { 
  {title="Turf War (Coke Farm)", colour=1, id=625, x = 1001.77, y = -438.7, z = 64.2}, --Coke Turf
  {title="Turf War (Legion Square)", colour=1, id=625, x = 196.97, y = -935.22, z = 30.69}, --Leagion Squeare Turf
  {title="Turf War (Weed Farm)", colour=1, id=625, x = -265.88, y = -1571.26, z = 32.07}, --Weed Turf
  {title="Turf War (Money Wash)", colour=1, id=625, x = 901.02, y = -182.7, z = 73.9}, --Money Wash Turf
  {title="Turf War (Meth Farm)", colour=1, id=625, x = -1316.07, y = -711.91, z = 46.16}, --Meth Turf
  {title="Turf War (AirPort)", colour=1, id=625, x = -784.97, y = -2402.08, z = 14.57}, --AirPort
  {title="Turf War (Proosperity ST)", colour=1, id=625, x = -1522.56, y = -430.35, z = 35.44}, --Proosperity St
  {title="Turf War (Construction)", colour=1, id=625, x = 110.23, y = -397.14, z = 41.27}, --Construction    
  {title="Turf War (Casino)", colour=1, id=625, x = 892.82, y = 16.9, z = 78.76}, --Casino
  {title="Turf War (Beach)", colour=1, id=625, x = -1645.14, y = -893.02, z = 8.82}, --Beach parking lot
  {title="Turf War (Business)", colour=1, id=625, x = -338.86, y = -938.08, z = 31.08}, --Business lot
  {title="Turf War (JunkYard)", colour=1, id=625, x = -448.66, y = -1703.73, z = 18.89}, --Junk yard
}

      
Citizen.CreateThread(function()
    for _, info in pairs(blips) do
      info.blip = AddBlipForCoord(info.x, info.y, info.z)
      SetBlipSprite(info.blip, info.id)
      SetBlipDisplay(info.blip, 4)
      SetBlipScale(info.blip, 0.70)
      SetBlipColour(info.blip, info.colour)
      SetBlipAsShortRange(info.blip, true)
      BeginTextCommandSetBlipName("STRING")
      AddTextComponentString(info.title)
      EndTextCommandSetBlipName(info.blip)
    end
end)

Citizen.CreateThread(function()
  while true do 
      Citizen.Wait(1000)
      for k,v in pairs(zones) do
          if (v.timer ~= nil and v.timer > 0) then
            zones[k].timer = zones[k].timer - 1
              if (zones[k].timer <= 0) then
                zones[k].timer = nil
              end
          end
      end
  end
end)
