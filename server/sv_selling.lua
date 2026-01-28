local getCopsAmount = function()
	local copsAmount = 0
	local onlinePlayers = it.getPlayers()
	for i=1, #onlinePlayers do
		local player = it.getPlayer(onlinePlayers[i])
		if player then
			local job = it.getPlayerJob(player)
			for _, v in pairs(Config.PoliceJobs) do
				if job.name == v then
					if it.getCoreName() == "qb-core" and Config.OnlyCopsOnDuty and not job.onduty then return end
					copsAmount = copsAmount + 1
				end
			end
		end
	end
	return copsAmount
end

-- Função para obter o grupo/gang do player (importar de sv_zones ou definir aqui)
local function getPlayerGang(src)
    local Player = it.getPlayer(src)
    if not Player then return nil end
    
    if it.core == 'qb-core' then
        if Player.PlayerData.gang and Player.PlayerData.gang.name then
            return Player.PlayerData.gang.name
        end
    elseif it.core == 'esx' then
        -- Para ESX, adaptar conforme necessário
    end
    
    return nil
end

-- Função para obter todos os players de uma gang específica
local function getGangMembers(gangName)
    local members = {}
    
    if not gangName then return members end
    
    local players = it.getPlayers()
    for _, playerId in pairs(players) do
        local Player = it.getPlayer(playerId)
        if Player then
            local playerGang = getPlayerGang(playerId)
            if playerGang == gangName then
                table.insert(members, playerId)
            end
        end
    end
    
    return members
end

RegisterNetEvent('it-drugs:server:initiatedrug', function(cad)
	local src = source
	local Player = it.getPlayer(src)
	if Player then
		-- Verificar se o player está vendendo em uma zona de gang
		local playerGang = getPlayerGang(src)
		local zoneGang = cad.zoneGang -- Gang da zona onde está vendendo
		
		-- Se a zona tem uma gang e o player não é dessa gang, alertar os membros
		if zoneGang and zoneGang ~= '' and playerGang ~= zoneGang then
			local gangMembers = getGangMembers(zoneGang)
			local playerName = Player.PlayerData.charinfo and (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname) or 'Desconhecido'
			local coords = GetEntityCoords(GetPlayerPed(src))
			
			-- Notificar todos os membros da gang dona da zona
			for _, memberId in ipairs(gangMembers) do
				TriggerClientEvent('it-drugs:client:gangAlert', memberId, {
					message = string.format('Alguém está vendendo drogas na sua zona! (%s)', playerName),
					coords = coords,
					zoneName = cad.zoneName or 'Zona Desconhecida'
				})
			end
			
			-- Notificar o vendedor que o olheiro avisou os donos
			ShowNotification(src, '⚠️ O olheiro avisou os donos da boca! Eles foram alertados sobre sua presença.', 'error')
		end
		
		local price = cad.price * cad.amount
		if Config.SellSettings['giveBonusOnPolice'] then
			local copsamount = getCopsAmount()
			if copsamount > 0 and copsamount < 3 then
				price = price * 1.2
			elseif copsamount >= 3 and copsamount <= 6 then
				price = price * 1.5
			elseif copsamount >= 7 and copsamount <= 10 then
				price = price * 1.7
			elseif copsamount >= 10 then
				price = price * 2.0
			end
		end
		price = math.floor(price)
		if it.hasItem(src, cad.item, cad.amount) then
			if it.removeItem(src, tostring(cad.item), cad.amount) then
				math.randomseed(GetGameTimer())
				local stealChance = math.random(0, 100)
				if stealChance < Config.SellSettings['stealChance'] then
					ShowNotification(src, _U('NOTIFICATION__STOLEN__DRUG'), 'error')
				else
					it.addMoney(src, "cash", price, "Money from Drug Selling")
					ShowNotification(src, _U('NOTIFICATION__SOLD__DRUG'):format(price), 'success')
				end
				local coords = GetEntityCoords(GetPlayerPed(src))
				SendToWebhook(src, 'sell', nil, ({item = cad.item, amount = cad.amount, price = price, coords = coords}))
				if Config.Debug then print('You got ' .. cad.amount .. ' ' .. cad.item .. ' for $' .. price) end
			else
				ShowNotification(src, _U('NOTIFICATION__SELL__FAIL'):format(cad.item), 'error')
			end
		else
			ShowNotification(src, _U('NOTIFICATION__NO__ITEM__LEFT'):format(cad.item), 'error')
		end
	end
end)

lib.callback.register('it-drugs:server:getCopsAmount', function(source)
	local copsAmount = getCopsAmount()
	return copsAmount
end)