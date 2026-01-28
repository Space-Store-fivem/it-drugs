-- \ Locals and tables
local SoldPeds = {}
local SellZone = {}
local currentZone = nil
local dynamicZones = {} -- Zonas dinâmicas do banco de dados

-- \ Create Zones for the drug sales (zonas estáticas do config)
for k, v in pairs(Config.SellZones) do
    local coords = {}
    for _, point in ipairs(v.points) do
        table.insert(coords, vector3(point.x, point.y, point.z))
    end

	lib.zones.poly({
        points = coords,
        thickness = v.thickness,
        debug = Config.DebugPoly,
		onEnter = function(self)
			CreateSellTarget()
			currentZone = k
			if Config.Debug then print("Entered Zone ["..k.."]") end
		end,
		onExit = function(self)
			currentZone = nil
			RemoveSellTarget()
			if Config.Debug then print("Exited Zone ["..k.."]") end
		end
    })
end

-- Função para atualizar zonas dinâmicas
local function updateDynamicZones()
    -- As zonas dinâmicas são criadas em cl_zones.lua
    -- Aqui apenas sincronizamos a referência
    if drugZones then
        for zoneId, zone in pairs(drugZones) do
            if not dynamicZones[zoneId] and zone.polygon_points then
                dynamicZones[zoneId] = zone
            end
        end
    end
end

-- Evento para atualizar quando as zonas mudarem
RegisterNetEvent('it-drugs:client:zonesUpdated', function()
    updateDynamicZones()
end)

-- \ Play five animation for both player and ped
local function PlayGiveAnim(tped)
	local pid = PlayerPedId()
	FreezeEntityPosition(pid, true)
	TaskPlayAnim(pid, "mp_common", "givetake2_a", 8.0, -8, 2000, 0, 1, 0,0,0)
	TaskPlayAnim(tped, "mp_common", "givetake2_a", 8.0, -8, 2000, 0, 1, 0,0,0)
	FreezeEntityPosition(pid, false)
end

-- \ Add Old Ped to table
local function AddSoldPed(entity)
    SoldPeds[entity] = true
end

--\ Check if ped is in table
local function HasSoldPed(entity)
    return SoldPeds[entity] ~= nil
end

RegisterNetEvent('it-drugs:client:checkSellOffer', function(entity)
	local copsAmount = lib.callback.await('it-drugs:server:getCopsAmount', false)

	if copsAmount < Config.MinimumCops then
		ShowNotification(nil, _U('NOTIFICATION__NOT__INTERESTED'), 'error')
		if Config.Debug then lib.print.info(_U('INFO__NO_COPS')) end
		return
	end

	local isSoldtoPed = HasSoldPed(entity)
	if isSoldtoPed then
		ShowNotification(nil, _U('NOTIFICATION__ALLREADY__SPOKE'), 'error')
		return
	end

	SetEntityAsMissionEntity(entity, true, true)
	TaskTurnPedToFaceEntity(entity, PlayerPedId(), -1)
	Wait(500)

	-- seed math random
	math.randomseed(GetGameTimer())
	local sellChance = math.random(0, 100)

	-- Verificar se o NPC é de mesa
	local isTableNPC = IsNPCFromTable and IsNPCFromTable(entity) or false

	if sellChance > Config.SellSettings['sellChance'] then
		-- NPCs de mesa também podem ser informantes da polícia
		if isTableNPC then
			-- O comprador era um informante da polícia
			ShowNotification(nil, '⚠️ O comprador era um informante da polícia e os avisou!', 'error')
			TaskUseMobilePhoneTimed(entity, 8000)
			SetPedAsNoLongerNeeded(entity)
			ClearPedTasks(PlayerPedId())
			AddSoldPed(entity)
			
			-- Chamar a polícia
			SendPoliceAlert()
			return
		end
		
		-- NPCs normais (não de mesa) também chamam a polícia
		ShowNotification(nil, _U('NOTIFICATION__CALLING__COPS'), 'error')
		TaskUseMobilePhoneTimed(entity, 8000)
		SetPedAsNoLongerNeeded(entity)
		ClearPedTasks(PlayerPedId())
		AddSoldPed(entity)

		--local coords = GetEntityCoords(entity)
		SendPoliceAlert()
		return
	end

	-- Verificar se está em uma zona estática ou dinâmica
	local zoneConfig = nil
	local currentZoneGang = nil
	local currentZoneName = nil
	local entityCoords = GetEntityCoords(entity)
	
	if currentZone and Config.SellZones[currentZone] then
		zoneConfig = Config.SellZones[currentZone]
		currentZoneName = currentZone
		-- Zonas estáticas não têm gang por padrão
	elseif currentEditingZone and drugZones[currentEditingZone] then
		-- Usar zona dinâmica atual
		local dynamicZone = drugZones[currentEditingZone]
		zoneConfig = {
			drugs = dynamicZone.drugs or {}
		}
		currentZoneGang = dynamicZone.gang_name
		currentZoneName = dynamicZone.label or currentEditingZone
	else
		-- Verificar se o NPC está em alguma zona dinâmica
		for zoneId, zone in pairs(drugZones) do
			if zone.polygon_points and #zone.polygon_points >= 3 then
				local x, y, z = entityCoords.x, entityCoords.y, entityCoords.z
				local inside = false
				local j = #zone.polygon_points
				
				for i = 1, #zone.polygon_points do
					local pi = zone.polygon_points[i]
					local pj = zone.polygon_points[j]
					
					if ((pi.y > y) ~= (pj.y > y)) and (x < (pj.x - pi.x) * (y - pi.y) / (pj.y - pi.y) + pi.x) then
						inside = not inside
					end
					j = i
				end
				
				if inside then
					local minZ = zone.polygon_points[1].z
					for i = 2, #zone.polygon_points do
						if zone.polygon_points[i].z < minZ then
							minZ = zone.polygon_points[i].z
						end
					end
					local maxZ = minZ + (zone.thickness or 10.0)
					inside = z >= minZ and z <= maxZ
				end
				
				if inside then
					zoneConfig = {
						drugs = zone.drugs or {}
					}
					currentZoneGang = zone.gang_name
					currentZoneName = zone.label or zoneId
					break
				end
			end
		end
	end
	
	if not zoneConfig then return end

	local sellAmount = math.random(Config.SellSettings['sellAmount'].min, Config.SellSettings['sellAmount'].max)
	local sellItemData = nil
	local playerItems = 0

	if Config.SellSettings['onlyAvailableItems'] then
		local availabeItems = {}
		for _, itemData in pairs(zoneConfig.drugs) do
			if it.hasItem(itemData.item)then
				table.insert(availabeItems, itemData)
			end
		end

		if #availabeItems == 0 then
			ShowNotification(nil, _U('NOTIFICATION__NO__DRUGS'), 'error')
			SetPedAsNoLongerNeeded(entity)
			return
		end

		-- seed math random
		math.randomseed(GetGameTimer())
		sellItemData = availabeItems[math.random(1, #availabeItems)]
		playerItems = it.getItemCount(sellItemData.item)
	else
		sellItemData = zoneConfig.drugs[math.random(1, #zoneConfig.drugs)]
		playerItems = it.getItemCount(sellItemData.item)
		if playerItems == 0 then
			ShowNotification(nil, _U('NOTIFICATION__NO__DRUGS'), 'error')
			SetPedAsNoLongerNeeded(entity)
			return
		end
	end

	if playerItems < sellAmount then
		sellAmount = playerItems
	end

	TriggerEvent('it-drugs:client:showSellMenu', {
		item = sellItemData.item, 
		price = sellItemData.price, 
		amount = sellAmount, 
		entity = entity,
		zoneGang = currentZoneGang,
		zoneName = currentZoneName
	})
	SetTimeout(Config.SellSettings['sellTimeout']*1000, function()
		if Config.Debug then lib.print.info(_U('INFO__SELL_MENU_TIMEOUT'), lib.getOpenContextMenu()) end
		if lib.getOpenContextMenu() ~= nil then
			local currentMenu = lib.getOpenContextMenu()
			if currentMenu == 'it-drugs-sell-menu' then
				ShowNotification(nil, _U('NOTIFICATION__TO__LONG'), 'error')
				lib.hideContext(false)
				SetPedAsNoLongerNeeded(entity)
			end
		end
	end)
end)

-- \ event handler to server (execute server side)
RegisterNetEvent('it-drugs:client:salesInitiate', function(cad)
	AddSoldPed(cad.tped)
	if cad.type == 'close' then
		ShowNotification(nil, _U('NOTIFICATION__OFFER__REJECTED'), 'error')
		SetPedAsNoLongerNeeded(cad.tped)
	else
		PlayGiveAnim(cad.tped)
		TriggerServerEvent('it-drugs:server:initiatedrug', cad)
		SetPedAsNoLongerNeeded(cad.tped)
	end
end)