gangZones = {} -- GLOBAL (Internal to resource scope) for access in cl_war.lua
local zonePolys = {}

-- Load zones from server
RegisterNetEvent('it-drugs:client:updateGangZones', function(zones)
    gangZones = zones
    refreshGangZones()
    
    -- Update NUI Map if open
    SendNUIMessage({
        action = 'updateZones',
        zones = zones
    })
end)

function refreshGangZones()
    -- Clear existing polys
    for _, poly in pairs(zonePolys) do
        if poly.remove then poly:remove() end
    end
    zonePolys = {}

    -- Create new polys
    for zoneId, zone in pairs(gangZones) do
        if zone.polygon_points and #zone.polygon_points >= 3 then
            local points = {}
            for _, p in ipairs(zone.polygon_points) do
                table.insert(points, vector3(p.x, p.y, p.z))
            end

            local color = {r=255, g=0, b=0} -- Default Enemy
            local playerGang = it.getPlayerGang()
            if playerGang and playerGang.name == zone.owner_gang then
                color = {r=0, g=255, b=0} -- Friendly
            end

            zonePolys[zoneId] = lib.zones.poly({
                points = points,
                thickness = 50.0, -- Tall zones for territory
                debug = false, -- Enable for debug view
                onEnter = function()
                    -- Trigge zone logic (invasion check etc)
                    TriggerEvent('it-drugs:client:enterGangZone', zoneId)
                end,
                onExit = function()
                    TriggerEvent('it-drugs:client:exitGangZone', zoneId)
                end
            })

            -- Upgrades: Spawn físicos (Mesas e Guardas)
            if zone.upgrades then
                for _, upgrade in ipairs(zone.upgrades) do
                    if upgrade.placed and upgrade.coords then
                        if upgrade.type == 'table' then
                            -- Mesas já são gerenciadas pelo cl_zones.lua/cl_drug_table.lua
                            -- Mas se precisar de lógica extra, pode ser aqui
                        elseif upgrade.type == 'npc' then
                            -- Lógica para spawnar guarda
                            spawnZoneGuard(zoneId, upgrade)
                        end
                    end
                end
            end

            -- Ponto da Bandeira (Legacy/Alternative)
            --[[
            if zone.flag_point and type(zone.flag_point) == 'table' then
                local flagCoords = vector3(zone.flag_point.x, zone.flag_point.y, zone.flag_point.z)
                
                if playerGang and playerGang.name == zone.owner_gang then
                    if exports.ox_target then
                        exports.ox_target:addSphereZone({
                            coords = flagCoords,
                            radius = 1.0,
                            debug = false,
                            options = {
                                {
                                    name = 'it_drugs_flag_' .. zoneId,
                                    icon = 'fas fa-flag',
                                    label = 'Gerenciar Zona',
                                    onSelect = function()
                                        -- Agora gerenciado via Painel (NUI)
                                        -- openZoneShop(zoneId)
                                    end
                                }
                            }
                        })
                    end
                end
            end
            ]]
        end
    end
end

-- Variável para rastrear guardas spawnados
local spawnedGuards = {}

function spawnZoneGuard(zoneId, upgrade)
    local uniqueId = upgrade.id
    if spawnedGuards[uniqueId] and DoesEntityExist(spawnedGuards[uniqueId]) then return end

    -- Verificar cooldown de morte
    if upgrade.deathTime and upgrade.deathTime > 0 then
        -- Obter tempo do servidor (aproximado) ou verificar timestamp
        -- Como deathTime é timestamp, precisamos comparar com timestamp atual
        -- Usar GetCloudTimeAsInt() para UTC timestamp
        local currentTime = GetCloudTimeAsInt()
        local respawnTime = (Config.ZoneUpgrades[upgrade.type_id].respawnTime or 10) * 60
        
        if (currentTime - upgrade.deathTime) < respawnTime then
            -- Ainda em cooldown
            return
        end
    end
    
    local model = upgrade.model
    if not model then return end
    
    local modelHash = GetHashKey(model)
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do Wait(10) end
    
    local coords = upgrade.coords
    local npc = CreatePed(4, modelHash, coords.x, coords.y, coords.z, coords.w, false, true)
    
    SetEntityAsMissionEntity(npc, true, true)
    SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(npc), true)
    
    -- Configurar Guarda
    local playerGang = it.getPlayerGang()
    local zone = gangZones[zoneId]
    
    -- Dar armas
    local configGuard = Config.ZoneUpgrades[upgrade.type_id]
    if configGuard and configGuard.weapons then
        for _, weapon in ipairs(configGuard.weapons) do
            GiveWeaponToPed(npc, GetHashKey(weapon), 999, false, true)
        end
        SetCurrentPedWeapon(npc, GetHashKey(configGuard.weapons[1]), true)
    end
    
    -- Comportamento (atacar inimigos, proteger área)
    -- Definir grupo de relacionamento baseado na gangue dona
    local groupHash = GetHashKey('GANG_' .. string.upper(zone.owner_gang))
    SetPedRelationshipGroupHash(npc, groupHash)
    
    -- Configurações de combate
    SetPedCombatAttributes(npc, 46, true) -- FIGHT_TO_DEATH
    SetPedCombatAttributes(npc, 5, true) -- COMBAT_PRIVATE_PROPERTY (defender área)
    SetPedFleeAttributes(npc, 0, false)
    SetPedAccuracy(npc, 60)
    SetPedArmour(npc, 100)
    
    -- Tarefa de guarda
    TaskGuardCurrentPosition(npc, 15.0, 15.0, 1) 
    
    spawnedGuards[uniqueId] = npc
    SetModelAsNoLongerNeeded(modelHash)

    -- Monitorar morte (opcional, melhor feito via evento de dano ou loop leve)
    CreateThread(function()
        while DoesEntityExist(npc) do
            if IsEntityDead(npc) then
                TriggerServerEvent('it-drugs:server:guardDied', zoneId, uniqueId)
                spawnedGuards[uniqueId] = nil
                break
            end
            Wait(5000)
        end
    end)
end

function openZoneShop(zoneId)
    local options = {}
    local zone = gangZones[zoneId]
    
    for id, data in pairs(Config.ZoneUpgrades) do
        -- Calcular quantos upgrades desse tipo a zona já tem
        local count = 0
        if zone.upgrades then
            for _, u in ipairs(zone.upgrades) do
                if u.type_id == id then count = count + 1 end
            end
        end
        
        local disabled = count >= data.max
        
        table.insert(options, {
            title = data.label,
            description = string.format('Preço: $%d | Possuídos: %d/%d\n%s', data.price, count, data.max, data.description),
            icon = data.icon or 'box',
            disabled = disabled,
            onSelect = function()
                TriggerServerEvent('it-drugs:server:buyUpgrade', zoneId, id)
            end
        })
    end
    
    lib.registerContext({
        id = 'zone_upgrade_shop',
        title = 'Loja da Zona: ' .. (zone.label or zoneId),
        options = options
    })
    
    lib.showContext('zone_upgrade_shop')
end

-- Evento para iniciar posicionamento (chamado pelo server após compra)
RegisterNetEvent('it-drugs:client:startUpgradePlacement', function(zoneId, upgradeUniqueId, type, model)
    if type == 'table' then
        -- Usar o sistema existente de posicionamento de mesa, mas adaptado
        -- Precisamos chamar a função positionTable do cl_zones.lua
        -- Como é local, vamos precisar expor ou criar evento. Vou criar um evento no cl_zones.lua
        TriggerEvent('it-drugs:client:positionUpgrade', zoneId, upgradeUniqueId, model, type)
    elseif type == 'npc' then
         TriggerEvent('it-drugs:client:positionUpgrade', zoneId, upgradeUniqueId, model, type)
    end
end)

-- Command to open panel
RegisterCommand('gangpanel', function()
    TriggerServerEvent('it-drugs:server:openGangPanel')
end)

-- Command to create gang zone (Restored)
RegisterCommand('creategangzone', function(source, args)
    local gangName = args[1]
    local label = args[2]

    if not gangName or not label then
        lib.notify({ type = 'error', description = 'Uso: /creategangzone [NomeGangue] [NomeZona]' })
        return
    end

    if ZoneCreator and ZoneCreator.startCreator then
        ZoneCreator.startCreator({
            onCreated = function(data)
                local points = {}
                for _, p in ipairs(data.points) do
                    table.insert(points, {x = p.x, y = p.y, z = p.z})
                end
                
                TriggerServerEvent('it-drugs:server:createGangZone', gangName, label, points)
            end,
            onCanceled = function()
                lib.notify({ type = 'error', description = 'Criação cancelada.' })
            end
        })
    else
        print('Erro: ZoneCreator não encontrado.')
    end
end)

-- NUI Events
RegisterNetEvent('it-drugs:client:openGangUi', function(data)
    SetNuiFocus(true, true)
    
    SendNUIMessage({
        action = 'open',
        gangName = data.gangName,
        zones = data.zones,
        isAdmin = data.isAdmin,
        availableGangs = data.availableGangs,
        gangGrade = data.gangGrade,
        isBoss = data.isBoss,
        upgradesConfig = Config.ZoneUpgrades
    })
end)

-- NUI Callbacks are handled in cl_nui.lua
-- Removed duplicates to prevent conflict

-- Initial Load
CreateThread(function()
    Wait(2000) -- Wait for server to register callback and player to load
    local success, result = pcall(function()
        return lib.callback.await('it-drugs:server:getGangZones', false)
    end)
    
    if success and result then
        gangZones = result
        refreshGangZones()
    else
        print('[IT-DRUGS] Falha ao carregar zonas via callback. Tentando novamente em 5s...')
        Wait(5000)
        gangZones = lib.callback.await('it-drugs:server:getGangZones', false)
        refreshGangZones()
    end
end)

RegisterCommand('setgangflag', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    
    -- Verificar se player tem gangue
    local playerGang = it.getPlayerGang()
    if not playerGang or playerGang.name == 'none' then
        lib.notify({ type = 'error', description = 'Você não pertence a uma gangue.' })
        return
    end
    
    -- Encontrar zona atual
    local currentZoneId = nil
    for zoneId, zone in pairs(gangZones) do
        -- Verificar distância básica primeiro para otimização
        if zone.polygon_points and #zone.polygon_points > 0 then
            local center = zone.polygon_points[1] -- Aproximação
            if #(coords - vector3(center.x, center.y, center.z)) < 500.0 then
                -- TODO: Usar verificação poligonal precisa se necessário, mas por enquanto assumimos que o player sabe onde está
                -- Ou melhor, verificamos se ele é dono da zona mais próxima
                if zone.owner_gang == playerGang.name then
                    currentZoneId = zoneId
                    break
                end
            end
        end
    end
    
    if not currentZoneId then
        lib.notify({ type = 'error', description = 'Você não está próximo de nenhuma zona da sua gangue.' })
        return
    end
    
    -- Iniciar seleção de ponto
    if ZoneCreator and ZoneCreator.selectPoint then
        ZoneCreator.selectPoint({
            helpText = "Posicione a nova bandeira da zona",
            onSelected = function(point)
                TriggerServerEvent('it-drugs:server:updateGangFlag', currentZoneId, point)
            end,
            onCanceled = function()
                lib.notify({ type = 'info', description = 'Edição cancelada.' })
            end
        })
    else
        lib.notify({ type = 'error', description = 'Erro: Módulo ZoneCreator não disponível.' })
    end
end)
