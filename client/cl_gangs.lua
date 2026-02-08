gangZones = {} -- GLOBAL (Internal to resource scope) for access in cl_war.lua
local zonePolys = {}
local spawnedGuards = {} -- Moved to top for scope visibility

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
    -- cleanupAllGuards() -- DESATIVADO: Evitar resetar todos os NPCs a cada update
    
    -- Track valid IDs to cleanup removed upgrades
    local validGuardIds = {}

    -- Clear existing polys (Visual Zones only)
    for _, poly in pairs(zonePolys) do
        if poly.remove then poly:remove() end
    end
    zonePolys = {}

    -- Create new polys & Process Upgrades
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
                    TriggerEvent('it-drugs:client:enterGangZone', zoneId)
                end,
                onExit = function()
                    TriggerEvent('it-drugs:client:exitGangZone', zoneId)
                end
            })

            -- Upgrades: Spawn físicos (Mesas e Guardas)
            -- Bloqueio: Se a zona for da Polícia, NÃO SPAWNA NADA DE UPGRADE (Limpeza Visual)
            if zone.upgrades and zone.owner_gang ~= 'police' then
                for _, upgrade in ipairs(zone.upgrades) do
                    if upgrade.placed and upgrade.coords then
                        if upgrade.type == 'table' then
                            -- Mesas já são gerenciadas pelo cl_zones.lua
                        elseif upgrade.type == 'npc' then
                            -- Lógica para spawnar guarda (Inteligente)
                            if upgrade.id then
                                validGuardIds[upgrade.id] = true
                                spawnZoneGuard(zoneId, upgrade)
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Limpeza de guardas removidos (que não estão mais na lista validGuardIds)
    for id, ped in pairs(spawnedGuards) do
        if not validGuardIds[id] then
            if DoesEntityExist(ped) then DeleteEntity(ped) end
            spawnedGuards[id] = nil
        end
    end
end

            -- Legacy Flag Point Logic Removed to clean up syntax


local function cleanupAllGuards()
    for id, ped in pairs(spawnedGuards) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    spawnedGuards = {}
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        cleanupAllGuards()
    end
end)

function spawnZoneGuard(zoneId, upgrade)
    local uniqueId = upgrade.id
    
    -- 1. Verificar cooldown de morte (Prioridade Total)
    if upgrade.deathTime and upgrade.deathTime > 0 then
        local currentTime = GetCloudTimeAsInt()
        local respawnTime = (Config.ZoneUpgrades[upgrade.type_id].respawnTime or 10) * 60
        
        if (currentTime - upgrade.deathTime) < respawnTime then
            -- Está no cooldown: Se o boneco ainda existe (bug?), deleta
            if spawnedGuards[uniqueId] then
                if DoesEntityExist(spawnedGuards[uniqueId]) then
                    DeleteEntity(spawnedGuards[uniqueId])
                end
                spawnedGuards[uniqueId] = nil
            end
            return -- Não spawna
        end
    end

    -- 2. Se já existe, verificar estado
    if spawnedGuards[uniqueId] then
        local existingPed = spawnedGuards[uniqueId]
        if DoesEntityExist(existingPed) and not IsEntityDead(existingPed) then
            -- Está vivo e saudável -> Não faz nada (Mantém posição/ação atual)
            -- Apenas atualiza estado se necessário? Por enquanto, retorno simples evita o "reset"
            return 
        else
            -- Existe na lista mas tá morto/sumiu -> Limpar para respawnar
            if DoesEntityExist(existingPed) then DeleteEntity(existingPed) end
            spawnedGuards[uniqueId] = nil
        end
    end
    
    -- 3. Spawna novo (apenas se passou pelos checks acima)
    local model = upgrade.model
    if not model then return end
    
    local modelHash = GetHashKey(model)
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do Wait(10) end
    
    local coords = upgrade.coords
    -- AUMENTAR Z em +1.0 para evitar nascer no chão
    local npc = CreatePed(4, modelHash, coords.x, coords.y, coords.z + 1.0, coords.w, true, true)
    
    local timeout = 0
    while not DoesEntityExist(npc) and timeout < 50 do
        Wait(10)
        timeout = timeout + 1
    end

    if not DoesEntityExist(npc) then return end

    SetEntityAsMissionEntity(npc, true, true)
    SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(npc), true)
    
    -- Configurar Guarda (Patrulha + Combate)
    local playerGang = it.getPlayerGang()
    local zone = gangZones[zoneId]
    
    -- 1. Dar armas (sem sacar)
    local configGuard = Config.ZoneUpgrades[upgrade.type_id]
    if configGuard and configGuard.weapons then
        for _, weapon in ipairs(configGuard.weapons) do
            GiveWeaponToPed(npc, GetHashKey(weapon), 999, false, true)
        end
    end
    
    -- 2. Grupos e Relacionamentos
    local groupName = 'GANG_' .. string.upper(zone.owner_gang)
    local groupHash = GetHashKey(groupName)
    
    if not DoesRelationshipGroupExist(groupHash) then
        AddRelationshipGroup(groupName, groupHash)
    end
    
    SetPedRelationshipGroupHash(npc, groupHash)
    
    -- Padrão: Odeia Jogadores (Proteção da Zona)
    SetRelationshipBetweenGroups(5, groupHash, GetHashKey("PLAYER"))
    SetRelationshipBetweenGroups(5, GetHashKey("PLAYER"), groupHash)

    -- Exceção: Se o player for da mesma gangue, vira amigo
    if playerGang and playerGang.name == zone.owner_gang then
        local playerGroup = GetPedRelationshipGroupHash(PlayerPedId())
        SetRelationshipBetweenGroups(1, groupHash, playerGroup) -- 1 = Respect/Friend
        SetRelationshipBetweenGroups(1, playerGroup, groupHash)
    end
    
    -- 3. Configurações de combate
    SetPedCombatAttributes(npc, 46, true) -- FIGHT_TO_DEATH
    SetPedCombatAttributes(npc, 5, true) -- COMBAT_PRIVATE_PROPERTY
    SetPedCombatAttributes(npc, 0, false) -- CAN_USE_COVER
    SetPedCombatAttributes(npc, 20, true) -- CALL_FOR_HELP
    SetPedCombatMovement(npc, 2) -- DEFENSIVE (Procura cover e ataca)
    SetPedCombatRange(npc, 2) -- FAR
    
    -- Ignorar aliados (redundancia)
    SetCanAttackFriendly(npc, false, false)
    
    -- ConfigFlags
    SetPedConfigFlag(npc, 292, false)
    SetPedConfigFlag(npc, 140, false)
    SetPedCanRagdoll(npc, true)
    SetPedCanPlayAmbientAnims(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, false) 
    SetEntityCollision(npc, true, true)
    
    SetPedFleeAttributes(npc, 0, false)
    SetPedAccuracy(npc, 70)
    SetPedArmour(npc, 100)
    SetEntityInvincible(npc, false)
    
    -- Integar com Sistema de Guerra (cl_war.lua)
    Entity(npc).state:set('isWarNPC', true, true)
    Entity(npc).state:set('warZoneId', zoneId, true)
    Entity(npc).state:set('gangOwner', zone.owner_gang, true)
    
    -- Tarefa de Patrulha (Wander)
    FreezeEntityPosition(npc, false)
    ClearPedTasksImmediately(npc)
    
    spawnedGuards[uniqueId] = npc
    SetModelAsNoLongerNeeded(modelHash)
    
    -- Atraso para garantir inicialização antes da task
    CreateThread(function()
        Wait(1000)
        if DoesEntityExist(npc) then
            print('^2[IT-DRUGS DEBUG] NPC Spawned & RAGDOLL Wakeup ' .. uniqueId .. '^7')
            
            -- Pulo do Gato: Forçar Ragdoll para garantir física
            SetPedToRagdoll(npc, 2000, 2000, 0, 0, 0, 0)
            Wait(2500) -- Esperar levantar
            
            -- Agora mandar andar
            if DoesEntityExist(npc) then
                TaskWanderInArea(npc, coords.x, coords.y, coords.z, 5.0, 5.0, 5.0)
                SetPedKeepTask(npc, true)
            end
        end
    end)

    -- Monitorar morte
    CreateThread(function()
        while DoesEntityExist(npc) do
            if IsEntityDead(npc) then
                TriggerServerEvent('it-drugs:server:guardDied', zoneId, uniqueId)
                break
            end
            Wait(2000)
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
    
    local sentUpgrades = Config.ZoneUpgrades
    if data.gangName == 'police' then
        sentUpgrades = {} -- Hide upgrades from police
    end
    
    SendNUIMessage({
        action = 'open',
        gangName = data.gangName,
        zones = data.zones,
        isAdmin = data.isAdmin,
        availableGangs = data.availableGangs,
        gangGrade = data.gangGrade,
        isBoss = data.isBoss,
        upgradesConfig = sentUpgrades
    })
end)

-- DEBUG COMMAND (Diagnosticar NPCs travados)
-- DEBUG COMMAND (Diagnosticar NPCs travados)
RegisterCommand('checknpc', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local closestPed = 0
    local closestDist = 10.0
    
    local handle, ped = FindFirstPed()
    local success
    
    repeat
        if DoesEntityExist(ped) and ped ~= playerPed and not IsPedAPlayer(ped) then
            local dist = #(coords - GetEntityCoords(ped))
            if dist < closestDist then
                closestDist = dist
                closestPed = ped
            end
        end
        
        success, ped = FindNextPed(handle)
    until not success
    
    EndFindPed(handle)
    
    if closestPed ~= 0 then
        local frozen = IsEntityPositionFrozen(closestPed) and "^1YES^7" or "^2NO^7"
        local netId = NetworkGetNetworkIdFromEntity(closestPed)
        
        print(string.format('^3[NPC CHECK]^7 ID: %s | NetID: %s | Frozen: %s | Health: %s/%s', closestPed, netId, frozen, GetEntityHealth(closestPed), GetEntityMaxHealth(closestPed)))
        print(string.format('^3[NPC CHECK]^7 Coords: %s | Dist: %.2f | Group: %s', GetEntityCoords(closestPed), closestDist, GetPedRelationshipGroupHash(closestPed)))
        print(string.format('^3[NPC CHECK]^7 ScenarioActive: %s | Ragdoll: %s | Ducking: %s', IsPedActiveInScenario(closestPed), IsPedRagdoll(closestPed), IsPedDucking(closestPed)))
        lib.notify({ type = 'info', description = 'Check F8 for NPC info. Frozen: '..frozen })
    else
        lib.notify({ type = 'error', description = 'Nenhum NPC próximo encontrada.' })
    end
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
