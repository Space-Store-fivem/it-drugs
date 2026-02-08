gangZones = {}

local function getPlayerGang(src)
    local Player = it.getPlayer(src)
    if not Player then return nil end
    
    if it.core == 'qb-core' then
        if Player.PlayerData.gang and Player.PlayerData.gang.name ~= 'none' then
            return {
                name = Player.PlayerData.gang.name,
                label = Player.PlayerData.gang.label or Player.PlayerData.gang.name,
                grade = Player.PlayerData.gang.grade and Player.PlayerData.gang.grade.level or 0,
                isBoss = Player.PlayerData.gang.isboss
            }
        end
    elseif it.core == 'esx' then
        -- Handle ESX Job as Gang if needed
        local job = Player.getJob()
        return {
            name = job.name,
            label = job.label,
            grade = job.grade,
            isBoss = (job.grade_name == 'boss')
        }
    end
    
    return nil
end

-- Load Gang Zones from DB
local function loadGangZones()
    local zones = MySQL.query.await('SELECT * FROM it_gang_zones')
    if zones then
        for _, zone in ipairs(zones) do
            if zone.polygon_points then
                local success, decoded = pcall(json.decode, zone.polygon_points)
                if success then
                    zone.polygon_points = decoded
                else
                    zone.polygon_points = nil
                end
            end
            
            if zone.color then
                local success, decoded = pcall(json.decode, zone.color)
                if success then
                    zone.color = decoded
                end
            end
            
            if zone.flag_point then
                local success, decoded = pcall(json.decode, zone.flag_point)
                if success then
                    zone.flag_point = decoded
                end
                if success then
                    zone.flag_point = decoded
                end
            end

            if zone.visual_zone then
                local success, decoded = pcall(json.decode, zone.visual_zone)
                if success then
                    zone.visual_zone = decoded
                end
            end
            
            if zone.upgrades then
                local success, decoded = pcall(json.decode, zone.upgrades)
                if success then
                    zone.upgrades = decoded
                else
                    zone.upgrades = {}
                end
            else
                zone.upgrades = {}
            end
            
            gangZones[zone.zone_id] = zone
        end
    end
    
    -- RESETAR DeathTime de todos os NPCs ao iniciar o servidor
    for _, zone in pairs(gangZones) do
        if zone.upgrades then
            for _, upgrade in ipairs(zone.upgrades) do
                if upgrade.type == 'npc' then
                    upgrade.deathTime = 0
                end
            end
        end
    end

    TriggerClientEvent('it-drugs:client:updateGangZones', -1, gangZones)
end

CreateThread(function()
    Wait(1000)
    loadGangZones()
end)

-- Callback to get zones
lib.callback.register('it-drugs:server:getGangZones', function(source)
    return gangZones
end)

-- NUI Callback: Open Panel
local function getAllGangs()
    local gangs = {}
    -- print("IT-DRUGS: DEBUG - Fetching Gangs List...")
    
    -- Try QBCore
    if GetResourceState('qb-core') == 'started' then
        local success, result = pcall(function()
            local QBCore = exports['qb-core']:GetCoreObject()
            if QBCore and QBCore.Shared and QBCore.Shared.Gangs then
                return QBCore.Shared.Gangs
            end
            return nil
        end)

        if success and result then
            for name, data in pairs(result) do
                table.insert(gangs, {id = name, label = data.label})
            end
            -- print("IT-DRUGS: DEBUG - Fetched " .. #gangs .. " gangs from QBCore.")
            return gangs
        else
            print("IT-DRUGS: DEBUG - Failed to fetch QBCore gangs or table empty.")
        end
    end
    
    -- Try ESX (Jobs or explicit gangs)
    if GetResourceState('es_extended') == 'started' then
        -- print("IT-DRUGS: DEBUG - Using ESX fallback gang list.")
        table.insert(gangs, {id = 'ballas', label = 'Ballas'})
        table.insert(gangs, {id = 'famillies', label = 'Families'})
        table.insert(gangs, {id = 'vagos', label = 'Vagos'})
        table.insert(gangs, {id = 'marabunta', label = 'Marabunta'})
    end

    if #gangs == 0 then
        print("IT-DRUGS: DEBUG - No gangs found. Using default list.")
        table.insert(gangs, {id = 'none', label = 'Nenhuma Gangue Detectada'})
    end

    return gangs
end

-- Helper to get gang's existing color
local function getGangColor(gangName)
    if not gangName or gangName == 'none' then return nil end
    for _, zone in pairs(gangZones) do
        if zone.owner_gang == gangName and zone.color then
            return zone.color
        end
    end
    return nil
end

RegisterNetEvent('it-drugs:server:openGangPanel', function()
    local src = source
    local playerGang = getPlayerGang(src)
    
    if playerGang then
        local gangName = playerGang.name
        
        -- Check if player is admin
        local isPlayerAdmin = false
        if it.isPlayerAdmin and it.isPlayerAdmin(src) then 
            isPlayerAdmin = true
        elseif IsPlayerAceAllowed(src, 'command') then 
            isPlayerAdmin = true 
        end

        local availableGangs = getAllGangs()

        TriggerClientEvent('it-drugs:client:openGangUi', src, {
            gangName = gangName,
            zones = gangZones,
            isAdmin = true, -- FORCE TRUE for debug
            availableGangs = availableGangs,
            gangGrade = playerGang.grade,
            isBoss = playerGang.isBoss
        })
        
        -- Sincronizar solicitações de guerra para o jogador que abriu (Chamada Direta)
        if syncWarRequests then
            syncWarRequests(src)
        end
    else
        it.notify(src, 'Erro', 'error', 'Você não pertence a uma gangue.')
    end
end)

-- Declare War (Placeholder for now)
RegisterNetEvent('it-drugs:server:declareWar', function(data)
    local src = source
    local targetZone = data.zoneId
    print('War declared on zone: ' .. tostring(targetZone))
end)

-- Create New Gang Zone
RegisterNetEvent('it-drugs:server:createGangZone', function(gangName, label, points, color, flagPoint, visualZone)
    local src = source
    if not gangName or not label or not points then return end
    
    -- Se a gangue já tem uma cor, usa ela. Senão, usa a nova.
    local finalColor = getGangColor(gangName) or color
    local zoneId = 'zone_' .. math.random(1000, 9999)
    local encodedPoints = json.encode(points)
    local encodedColor = json.encode(finalColor)
    local encodedFlag = flagPoint and json.encode(flagPoint) or nil
    local encodedVisual = visualZone and json.encode(visualZone) or nil
    
    -- Add to database
    MySQL.insert.await('INSERT INTO it_gang_zones (zone_id, label, owner_gang, polygon_points, color, flag_point, visual_zone) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        zoneId, label, gangName, encodedPoints, encodedColor, encodedFlag, encodedVisual
    })
    
    -- Add to runtime table
    gangZones[zoneId] = {
        zone_id = zoneId,
        label = label,
        owner_gang = gangName,

        polygon_points = points,
        color = finalColor,
        flag_point = flagPoint,
        visual_zone = visualZone,
        current_status = 'peace'
    }
    
    -- Sync with everyone
    TriggerClientEvent('it-drugs:client:updateGangZones', -1, gangZones)
    it.notify(src, 'Sucesso', 'success', 'Zona ' .. label .. ' criada com sucesso!')
end)

-- Exports/Events for updates (Conquest)
RegisterNetEvent('it-drugs:server:updateGangZoneOwner', function(zoneId, newOwner)
    if not gangZones[zoneId] then return end
    
    -- Busca a cor oficial da gangue vencedora
    local winningColor = getGangColor(newOwner) or gangZones[zoneId].color
    
    -- Update specific fields
    gangZones[zoneId].owner_gang = newOwner
    gangZones[zoneId].color = winningColor
    gangZones[zoneId].current_status = 'peace'
    
    MySQL.update('UPDATE it_gang_zones SET owner_gang = ?, color = ?, current_status = ? WHERE zone_id = ?', {
        newOwner, json.encode(winningColor), 'peace', zoneId
    })
    
    TriggerClientEvent('it-drugs:client:updateGangZones', -1, gangZones)
end)

RegisterNetEvent('it-drugs:server:updateGangFlag', function(zoneId, flagPoint)
    local src = source
    if not gangZones[zoneId] then return end

    MySQL.update('UPDATE it_gang_zones SET flag_point = ? WHERE zone_id = ?', {
        json.encode(flagPoint), zoneId
    })

    
    TriggerClientEvent('it-drugs:client:updateGangZones', -1, gangZones)
    it.notify(src, 'Sucesso', 'success', 'Bandeira da zona atualizada!')
end)

RegisterNetEvent('it-drugs:server:updateGangVisual', function(zoneId, visualZone)
    local src = source
    
    -- Admin Check
    local isPlayerAdmin = false
    if it.isPlayerAdmin and it.isPlayerAdmin(src) then 
        isPlayerAdmin = true
    elseif IsPlayerAceAllowed(src, 'command') then 
        isPlayerAdmin = true 
    end
    
    if not isPlayerAdmin then
        it.notify(src, 'Erro', 'error', 'Apenas administradores podem editar o visual da zona.')
        return
    end

    if not gangZones[zoneId] then return end

    MySQL.update('UPDATE it_gang_zones SET visual_zone = ? WHERE zone_id = ?', {
        json.encode(visualZone), zoneId
    })

    gangZones[zoneId].visual_zone = visualZone
    
    TriggerClientEvent('it-drugs:client:updateGangZones', -1, gangZones)
    it.notify(src, 'Sucesso', 'success', 'Visual da zona atualizado!')
end)

-- Sistema de Upgrades

-- Evento para comprar upgrade
RegisterNetEvent('it-drugs:server:buyUpgrade', function(zoneId, upgradeId)
    local src = source
    local playerGang = getPlayerGang(src)
    
    if not gangZones[zoneId] then return end
    local zone = gangZones[zoneId]
    
    -- Validar se jogador é líder da gangue dona da zona
    if not playerGang or playerGang.name ~= zone.owner_gang or not playerGang.isBoss then
        it.notify(src, 'Erro', 'error', 'Apenas o líder da gangue pode comprar upgrades!')
        return
    end
    
    local upgradeConfig = Config.ZoneUpgrades[upgradeId]
    if not upgradeConfig then
        it.notify(src, 'Erro', 'error', 'Upgrade não encontrado.')
        return
    end
    
    -- Verificar limite de upgrades
    local currentCount = 0
    if zone.upgrades then
        for _, upgrade in ipairs(zone.upgrades) do
            if upgrade.type_id == upgradeId then
                currentCount = currentCount + 1
            end
        end
    end
    
    if currentCount >= upgradeConfig.max then
        it.notify(src, 'Erro', 'error', 'Limite máximo deste upgrade atingido!')
        return
    end
    
    -- Verificar dinheiro (usar bridge)
    local price = upgradeConfig.price
    local playerMoney = it.getMoney(src, 'bank')
    if playerMoney < price then
        playerMoney = it.getMoney(src, 'money')
        if playerMoney < price then
            it.notify(src, 'Erro', 'error', 'Dinheiro insuficiente!')
            return
        end
        it.removeMoney(src, 'money', price)
    else
        it.removeMoney(src, 'bank', price)
    end
    
    -- Adicionar upgrade à lista (pendente de posicionamento)
    if not zone.upgrades then zone.upgrades = {} end
    
    local newUpgrade = {
        id = 'upg_' .. math.random(100000, 999999),
        type_id = upgradeId,
        type = upgradeConfig.type,
        model = upgradeConfig.model,
        coords = nil, -- Será definido no posicionamento
        placed = false,
        deathTime = 0 -- Para guardas
    }
    
    table.insert(zone.upgrades, newUpgrade)
    
    -- Salvar no banco
    MySQL.update('UPDATE it_gang_zones SET upgrades = ? WHERE zone_id = ?', {
        json.encode(zone.upgrades), zoneId
    })
    
    -- Atualizar clientes
    TriggerClientEvent('it-drugs:client:updateGangZones', -1, gangZones)
    
    it.notify(src, 'Sucesso', 'success', 'Upgrade comprado! Agora posicione-o na zona.')
    
    -- Iniciar posicionamento automaticamente para quem comprou
    print('^3[IT-DRUGS DEBUG] Triggering client event: it-drugs:client:positionUpgrade for source: ' .. src .. '^7')
    TriggerClientEvent('it-drugs:client:positionUpgrade', src, zoneId, newUpgrade.id, upgradeConfig.model, upgradeConfig.type)
end)

-- Evento para salvar posicionamento do upgrade
RegisterNetEvent('it-drugs:server:placeUpgrade', function(zoneId, upgradeUniqueId, coords, heading)
    local src = source
    local playerGang = getPlayerGang(src)
    
    if not gangZones[zoneId] then return end
    local zone = gangZones[zoneId]
    
    -- Validar permissão
    if not playerGang or playerGang.name ~= zone.owner_gang or not playerGang.isBoss then
        return
    end
    
    -- Encontrar o upgrade na lista
    local found = false
    if zone.upgrades then
        for i, upgrade in ipairs(zone.upgrades) do
            if upgrade.id == upgradeUniqueId then
                upgrade.coords = {x = coords.x, y = coords.y, z = coords.z, w = heading}
                upgrade.placed = true
                found = true
                break
            end
        end
    end
    
    if found then
        MySQL.update('UPDATE it_gang_zones SET upgrades = ? WHERE zone_id = ?', {
            json.encode(zone.upgrades), zoneId
        })
        
        TriggerClientEvent('it-drugs:client:updateGangZones', -1, gangZones)
        it.notify(src, 'Sucesso', 'success', 'Upgrade posicionado com sucesso!')
    else
        it.notify(src, 'Erro', 'error', 'Upgrade não encontrado para posicionamento.')
    end
end)

-- Evento para registrar morte de guarda (chamado pelo client quando NPC morre)
RegisterNetEvent('it-drugs:server:guardDied', function(zoneId, upgradeUniqueId)
    if not gangZones[zoneId] then return end
    local zone = gangZones[zoneId]
    
    local found = false
    if zone.upgrades then
        for i, upgrade in ipairs(zone.upgrades) do
            if upgrade.id == upgradeUniqueId then
                upgrade.deathTime = os.time()
                found = true
                break
            end
        end
    end
    
    if found then
        MySQL.update('UPDATE it_gang_zones SET upgrades = ? WHERE zone_id = ?', {
            json.encode(zone.upgrades), zoneId
        })
        -- Sincronizar apenas o tempo de morte
        TriggerClientEvent('it-drugs:client:updateGangZones', -1, gangZones)
    end
end)
