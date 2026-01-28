local npcBuyers = {}
local activeTables = {}
local zoneWalkers = {} -- NPCs que passam pela zona (sem mesa)

-- Garantir que as variáveis globais existam
if not drugZones then drugZones = {} end
if not drugTables then drugTables = {} end
if not tableObjects then tableObjects = {} end
if not currentEditingZone then currentEditingZone = nil end

-- Função para verificar se um NPC é de mesa (exportada para outros scripts)
function IsNPCFromTable(npc)
    if not npc or not DoesEntityExist(npc) then
        return false
    end
    return npcBuyers[npc] ~= nil
end

-- Função para verificar se um ponto está dentro de uma zona poligonal
local function isPointInZone(point, polygonPoints, thickness)
    if not polygonPoints or #polygonPoints < 3 then
        return false
    end
    
    thickness = thickness or 10.0
    
    -- Verificar se o ponto está dentro do polígono (projeção 2D)
    local x, y, z = point.x, point.y, point.z
    local inside = false
    
    local j = #polygonPoints
    for i = 1, #polygonPoints do
        local pi = polygonPoints[i]
        local pj = polygonPoints[j]
        
        if ((pi.y > y) ~= (pj.y > y)) and (x < (pj.x - pi.x) * (y - pi.y) / (pj.y - pi.y) + pi.x) then
            inside = not inside
        end
        j = i
    end
    
    -- Verificar altura (mais flexível para zonas em prédios)
    if inside then
        local minZ = math.huge
        local maxZ = -math.huge
        
        -- Encontrar min e max Z dos pontos do polígono
        for i = 1, #polygonPoints do
            local pz = polygonPoints[i].z
            if pz < minZ then minZ = pz end
            if pz > maxZ then maxZ = pz end
        end
        
        -- Aplicar thickness a partir do minZ e maxZ
        local zoneMinZ = minZ
        local zoneMaxZ = maxZ + thickness
        
        -- Verificar se o ponto está dentro da faixa de altura
        -- Permitir uma margem de erro de 2m para cima e para baixo
        inside = z >= (zoneMinZ - 2.0) and z <= (zoneMaxZ + 2.0)
    end
    
    return inside
end

-- Função para obter um ponto aleatório dentro de uma zona poligonal
local function getRandomPointInZone(zone)
    if not zone or not zone.polygon_points or #zone.polygon_points < 3 then
        return nil
    end
    
    local thickness = zone.thickness or 10.0
    
    -- Método 1: Usar pontos existentes da zona e interpolar (mais confiável para ambientes fechados)
    -- Escolher 3 pontos aleatórios do polígono e gerar um ponto dentro do triângulo
    local point1 = zone.polygon_points[math.random(1, #zone.polygon_points)]
    local point2 = zone.polygon_points[math.random(1, #zone.polygon_points)]
    local point3 = zone.polygon_points[math.random(1, #zone.polygon_points)]
    
    -- Gerar ponto dentro do triângulo usando coordenadas baricêntricas
    local r1 = math.random()
    local r2 = math.random()
    if r1 + r2 > 1.0 then
        r1 = 1.0 - r1
        r2 = 1.0 - r2
    end
    local r3 = 1.0 - r1 - r2
    
    local x = r1 * point1.x + r2 * point2.x + r3 * point3.x
    local y = r1 * point1.y + r2 * point2.y + r3 * point3.y
    local z = r1 * point1.z + r2 * point2.z + r3 * point3.z
    
    -- Verificar se o ponto está dentro do polígono
    local testPoint = vector3(x, y, z)
    if isPointInZone(testPoint, zone.polygon_points, thickness) then
        -- Para zonas em prédios, usar a altura do ponto gerado (não buscar chão)
        -- Isso permite spawnar em diferentes andares
        return testPoint
    end
    
    -- Método 2: Usar centroide da zona (centro de massa)
    local sumX, sumY, sumZ = 0, 0, 0
    for _, point in ipairs(zone.polygon_points) do
        sumX = sumX + point.x
        sumY = sumY + point.y
        sumZ = sumZ + point.z
    end
    local centerX = sumX / #zone.polygon_points
    local centerY = sumY / #zone.polygon_points
    local centerZ = sumZ / #zone.polygon_points
    
    -- Verificar se o centroide está dentro
    local centerPoint = vector3(centerX, centerY, centerZ)
    if isPointInZone(centerPoint, zone.polygon_points, thickness) then
        -- Para zonas em prédios, usar a altura do centroide (não buscar chão)
        return centerPoint
    end
    
    -- Método 3: Usar pontos médios dos segmentos do polígono
    for i = 1, #zone.polygon_points do
        local p1 = zone.polygon_points[i]
        local p2 = zone.polygon_points[(i % #zone.polygon_points) + 1]
        
        local midX = (p1.x + p2.x) / 2.0
        local midY = (p1.y + p2.y) / 2.0
        local midZ = (p1.z + p2.z) / 2.0
        
        local midPoint = vector3(midX, midY, midZ)
        if isPointInZone(midPoint, zone.polygon_points, thickness) then
            -- Para zonas em prédios, usar a altura do ponto médio (não buscar chão)
            return midPoint
        end
    end
    
    -- Método 4: Fallback - usar bounding box com mais tentativas
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local minZ, maxZ = math.huge, -math.huge
    
    for _, point in ipairs(zone.polygon_points) do
        if point.x < minX then minX = point.x end
        if point.x > maxX then maxX = point.x end
        if point.y < minY then minY = point.y end
        if point.y > maxY then maxY = point.y end
        if point.z < minZ then minZ = point.z end
        if point.z > maxZ then maxZ = point.z end
    end
    
    maxZ = minZ + thickness
    
    -- Tentar encontrar um ponto dentro do polígono (máximo 200 tentativas)
    for attempt = 1, 200 do
        local x = minX + math.random() * (maxX - minX)
        local y = minY + math.random() * (maxY - minY)
        local z = minZ + math.random() * (maxZ - minZ)
        
        local testPoint = vector3(x, y, z)
        
        if isPointInZone(testPoint, zone.polygon_points, thickness) then
            -- Para zonas em prédios, usar a altura do ponto gerado (não buscar chão)
            return testPoint
        end
    end
    
    -- Último fallback: usar o primeiro ponto da zona
    local firstPoint = zone.polygon_points[1]
    return vector3(firstPoint.x, firstPoint.y, firstPoint.z)
end

-- Função para spawnar NPC comprador na mesa
local function spawnBuyerNPC(tableData, zoneId)
    if not tableData or not tableData.coords then return end
    
    local zone = drugZones[zoneId]
    if not zone or not zone.drugs then return end
    
    -- Modelos de NPCs aleatórios
    local npcModels = {
        'a_m_m_beach_01',
        'a_m_m_beach_02',
        'a_m_y_beach_01',
        'a_m_y_beach_02',
        'a_f_y_beach_01',
        'a_f_y_beach_02',
        'a_m_m_skater_01',
        'a_m_y_skater_01',
        'a_f_y_skater_01'
    }
    
    local model = npcModels[math.random(1, #npcModels)]
    local modelHash = GetHashKey(model)
    
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(100)
    end
    
    -- Spawnar NPC dentro da zona (não mais usando distância da mesa)
    local spawnPoint = getRandomPointInZone(zone)
    if not spawnPoint then
        -- Fallback: spawnar próximo à mesa se não conseguir encontrar ponto na zona
        spawnPoint = vector3(tableData.coords.x, tableData.coords.y, tableData.coords.z)
    end
    
    -- Calcular direção para a mesa
    local directionToTable = vector3(
        tableData.coords.x - spawnPoint.x,
        tableData.coords.y - spawnPoint.y,
        0.0
    )
    local heading = math.deg(math.atan2(directionToTable.y, directionToTable.x))
    
    local spawnCoords = vector4(
        spawnPoint.x,
        spawnPoint.y,
        spawnPoint.z,
        heading
    )
    
    local npc = CreatePed(4, modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, false, true)
    
    SetEntityAsMissionEntity(npc, true, true)
    SetBlockingOfNonTemporaryEvents(npc, false) -- Permitir que o NPC se mova
    SetEntityInvincible(npc, false)
    SetPedCanRagdoll(npc, false)
    SetPedFleeAttributes(npc, 0, false)
    SetPedCombatAttributes(npc, 46, true)
    SetPedKeepTask(npc, true) -- Manter tarefa mesmo quando a câmera vira
    NetworkRegisterEntityAsNetworked(npc) -- Garantir que o NPC seja persistente na rede
    
    -- Fazer NPC caminhar até a mesa usando TaskGoToEntity (melhor para distâncias maiores)
    local tableObj = tableObjects[tableData.table_id]
    if tableObj and tableObj.object and DoesEntityExist(tableObj.object) then
        -- Usar TaskGoToEntity que funciona melhor para distâncias maiores
        TaskGoToEntity(npc, tableObj.object, -1, 2.0, 1.0, 1073741824, 0)
        
        -- Thread para verificar quando o NPC chega perto da mesa
        CreateThread(function()
            local maxWait = 30000 -- 30 segundos máximo
            local startTime = GetGameTimer()
            
            while DoesEntityExist(npc) and (GetGameTimer() - startTime) < maxWait do
                Wait(1000)
                
                local npcCoords = GetEntityCoords(npc)
                local tableCoords = vector3(tableData.coords.x, tableData.coords.y, tableData.coords.z)
                local dist = #(npcCoords - tableCoords)
                
                -- Se chegou perto da mesa (menos de 3 metros)
                if dist < 3.0 then
                    -- Parar e olhar para a mesa
                    TaskStandStill(npc, 10000)
                    if tableObj.object and DoesEntityExist(tableObj.object) then
                        TaskLookAtEntity(npc, tableObj.object, 5000, 2048, 2)
                    end
                    break
                end
                
                -- Se o NPC parou de se mover, tentar novamente
                if GetEntitySpeed(npc) < 0.1 and dist > 3.0 then
                    if tableObj.object and DoesEntityExist(tableObj.object) then
                        TaskGoToEntity(npc, tableObj.object, -1, 2.0, 1.0, 1073741824, 0)
                    end
                end
            end
        end)
    else
        -- Fallback: usar TaskGoStraightToCoord se não houver objeto
        TaskGoStraightToCoord(npc, tableData.coords.x, tableData.coords.y, tableData.coords.z, 1.0, 10000, 0.0, 0)
    end
    
    -- Adicionar target/interação
    if Config.Target == 'ox_target' and exports.ox_target then
        exports.ox_target:addLocalEntity(npc, {
            {
                label = 'Vender Drogas',
                name = 'it-drugs-sell-to-npc',
                icon = 'fas fa-pills',
                onSelect = function(data)
                    -- Verificar se está na zona correta
                    if currentEditingZone ~= zoneId then
                        lib.notify({ type = 'error', description = 'Você precisa estar na zona de drogas!' })
                        return
                    end
                    
                    -- Processar venda
                    TriggerEvent('it-drugs:client:checkSellOffer', npc)
                end,
                distance = 2.0
            }
        })
    elseif Config.Target == 'qb-target' and exports['qb-target'] then
        exports['qb-target']:AddTargetEntity(npc, {
            options = {
                {
                    icon = 'fas fa-pills',
                    label = 'Vender Drogas',
                    action = function(entity)
                        if currentEditingZone ~= zoneId then
                            lib.notify({ type = 'error', description = 'Você precisa estar na zona de drogas!' })
                            return
                        end
                        TriggerEvent('it-drugs:client:checkSellOffer', entity)
                    end
                }
            },
            distance = 2.0
        })
    end
    
    npcBuyers[npc] = {
        tableId = tableData.table_id,
        zoneId = zoneId,
        spawnTime = GetGameTimer()
    }
    
    SetModelAsNoLongerNeeded(modelHash)
    
    -- Remover NPC após um tempo
    CreateThread(function()
        Wait(60000) -- 60 segundos
        if DoesEntityExist(npc) then
            TaskWanderStandard(npc, 10.0, 10)
            Wait(5000)
            if DoesEntityExist(npc) then
                DeleteEntity(npc)
            end
        end
        npcBuyers[npc] = nil
    end)
end

-- Thread para spawnar NPCs nas mesas
CreateThread(function()
    local spawnInterval = Config.DrugTable.tableNPCSpawnInterval or 10000
    local maxNPCsPerTable = Config.DrugTable.maxNPCsPerTable or 3
    
    while true do
        Wait(spawnInterval)
        
        for zoneId, tables in pairs(drugTables) do
            if drugZones[zoneId] then
                for _, tableData in ipairs(tables) do
                    if tableData.table_id and tableObjects[tableData.table_id] then
                        -- Contar NPCs ativos para esta mesa
                        local npcCount = 0
                        for npc, data in pairs(npcBuyers) do
                            if data and data.tableId == tableData.table_id and DoesEntityExist(npc) then
                                npcCount = npcCount + 1
                            end
                        end
                        
                        -- Spawnar NPC se não houver muitos e se o player estiver na zona
                        if npcCount < maxNPCsPerTable then
                            local ped = PlayerPedId()
                            local pedCoords = GetEntityCoords(ped)
                            
                            -- Verificar se o player está dentro da zona
                            local playerInZone = false
                            if drugZones[zoneId] and drugZones[zoneId].polygon_points and #drugZones[zoneId].polygon_points >= 3 then
                                playerInZone = isPointInZone(pedCoords, drugZones[zoneId].polygon_points, drugZones[zoneId].thickness or 10.0)
                            end
                            
                            local spawnChance = Config.DrugTable.npcSpawnChance or 30
                            
                            -- Spawnar NPC se o player estiver dentro da zona
                            if playerInZone and math.random(1, 100) <= spawnChance then
                                spawnBuyerNPC(tableData, zoneId)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- Limpar NPCs quando a mesa for removida
RegisterNetEvent('it-drugs:client:zonesUpdated', function()
    -- Limpar NPCs de mesas que não existem mais
    for npc, data in pairs(npcBuyers) do
        local tableExists = false
        for _, tables in pairs(drugTables) do
            for _, tableData in ipairs(tables) do
                if tableData.table_id == data.tableId then
                    tableExists = true
                    break
                end
            end
            if tableExists then break end
        end
        
        if not tableExists and DoesEntityExist(npc) then
            DeleteEntity(npc)
            npcBuyers[npc] = nil
        end
    end
    
    -- Limpar NPCs walkers de zonas que não existem mais
    if zoneWalkers then
        for npc, data in pairs(zoneWalkers) do
            if data and (not drugZones or not drugZones[data.zoneId]) then
                if DoesEntityExist(npc) then
                    DeleteEntity(npc)
                end
                zoneWalkers[npc] = nil
            end
        end
    end
end)

-- Função para spawnar NPC que passa pela zona
local function spawnZoneWalker(zoneId)
    local zone = drugZones[zoneId]
    if not zone then
        return
    end
    if not zone.polygon_points or #zone.polygon_points < 3 then
        return
    end
    
    -- Modelos de NPCs aleatórios
    local npcModels = {
        'a_m_m_beach_01', 'a_m_m_beach_02', 'a_m_y_beach_01', 'a_m_y_beach_02',
        'a_f_y_beach_01', 'a_f_y_beach_02', 'a_m_m_skater_01', 'a_m_y_skater_01',
        'a_f_y_skater_01', 'a_m_y_hipster_01', 'a_f_y_hipster_01', 'a_m_y_hipster_02',
        'a_m_y_stbla_01', 'a_f_y_stbla_01', 'a_m_m_tramp_01', 'a_m_m_trampbeac_01'
    }
    
    local model = npcModels[math.random(1, #npcModels)]
    local modelHash = GetHashKey(model)
    
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(100)
    end
    
    -- Spawnar NPC dentro da zona (não mais fora)
    local spawnPoint = getRandomPointInZone(zone)
    if not spawnPoint then
        return
    end
    
    -- Calcular ponto de destino também dentro da zona
    local destPoint = getRandomPointInZone(zone)
    if not destPoint then
        destPoint = spawnPoint -- Se não conseguir, usar o mesmo ponto
    end
    
    -- Garantir que destino seja diferente do spawn
    local attempts = 0
    while destPoint and #(destPoint - spawnPoint) < 5.0 and attempts < 10 do
        destPoint = getRandomPointInZone(zone)
        attempts = attempts + 1
    end
    
    if not destPoint then
        destPoint = spawnPoint
    end
    
    -- Calcular direção para o destino
    local directionToDest = vector3(
        destPoint.x - spawnPoint.x,
        destPoint.y - spawnPoint.y,
        0.0
    )
    local heading = math.deg(math.atan2(directionToDest.y, directionToDest.x))
    
    local spawnCoords = vector4(
        spawnPoint.x,
        spawnPoint.y,
        spawnPoint.z,
        heading
    )
    
    local npc = CreatePed(4, modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, false, true)
    
    if not DoesEntityExist(npc) then
        return
    end
    
    SetEntityAsMissionEntity(npc, true, true)
    SetBlockingOfNonTemporaryEvents(npc, false)
    SetEntityInvincible(npc, false)
    SetPedCanRagdoll(npc, false)
    SetPedFleeAttributes(npc, 0, false)
    SetPedCombatAttributes(npc, 46, true)
    SetPedKeepTask(npc, true) -- Manter tarefa mesmo quando a câmera vira
    NetworkRegisterEntityAsNetworked(npc) -- Garantir que o NPC seja persistente na rede
    
    -- Destino também dentro da zona
    local destCoords = vector3(destPoint.x, destPoint.y, destPoint.z)
    
    -- Fazer NPC caminhar através da zona
    TaskGoStraightToCoord(npc, destCoords.x, destCoords.y, destCoords.z, 1.0, 30000, 0.0, 0)
    
    zoneWalkers[npc] = {
        zoneId = zoneId,
        spawnTime = GetGameTimer(),
        destination = destCoords
    }
    
    SetModelAsNoLongerNeeded(modelHash)
    
    -- Remover NPC após chegar no destino ou timeout
    CreateThread(function()
        local maxWait = Config.ZoneWalkers.lifetime or 180000 -- 3 minutos por padrão
        local patrolTime = Config.ZoneWalkers.patrolTime or 30000 -- 30 segundos patrulhando
        local startTime = GetGameTimer()
        local enteredZone = false
        local patrolStartTime = nil
        
        while DoesEntityExist(npc) and (GetGameTimer() - startTime) < maxWait do
            Wait(2000)
            
            -- Verificar periodicamente se o NPC ainda existe e está válido
            if not DoesEntityExist(npc) then
                zoneWalkers[npc] = nil
                break
            end
            
            local npcCoords = GetEntityCoords(npc)
            local dist = #(npcCoords - destCoords)
            
            -- Verificar se o NPC entrou na zona
            if not enteredZone and isPointInZone(npcCoords, zone.polygon_points, zone.thickness or 10.0) then
                enteredZone = true
                patrolStartTime = GetGameTimer()
                -- Fazer NPC patrulhar dentro da zona
                TaskWanderStandard(npc, 10.0, 10)
            end
            
            -- Se o NPC está dentro da zona e já patrulhou o suficiente, fazer ele sair
            if enteredZone and patrolStartTime and (GetGameTimer() - patrolStartTime) >= patrolTime then
                -- Fazer NPC sair da zona
                TaskGoStraightToCoord(npc, destCoords.x, destCoords.y, destCoords.z, 1.0, 30000, 0.0, 0)
                enteredZone = false
                patrolStartTime = nil
            end
            
            -- Se chegou perto do destino final (fora da zona)
            if dist < 5.0 and not isPointInZone(npcCoords, zone.polygon_points, zone.thickness or 10.0) then
                if DoesEntityExist(npc) then
                    -- Fazer NPC ficar um pouco mais antes de remover
                    TaskStandStill(npc, 5000)
                    Wait(5000)
                    if DoesEntityExist(npc) then
                        DeleteEntity(npc)
                    end
                end
                if zoneWalkers then
                    zoneWalkers[npc] = nil
                end
                break
            end
            
            -- Verificar se o NPC parou de se mover (pode ter sido deletado ou congelado)
            if GetEntitySpeed(npc) < 0.1 and dist > 5.0 and not enteredZone then
                -- Tentar continuar o movimento
                TaskGoStraightToCoord(npc, destCoords.x, destCoords.y, destCoords.z, 1.0, 30000, 0.0, 0)
            elseif GetEntitySpeed(npc) < 0.1 and enteredZone then
                -- Se está dentro da zona e parou, continuar patrulhando
                TaskWanderStandard(npc, 10.0, 10)
            end
        end
        
        -- Timeout - remover NPC
        if DoesEntityExist(npc) then
            DeleteEntity(npc)
        end
        if zoneWalkers then
            zoneWalkers[npc] = nil
        end
    end)
end

-- Thread para spawnar NPCs que passam pela zona
CreateThread(function()
    local spawnInterval = Config.ZoneWalkers.spawnInterval or 15000
    local maxWalkers = Config.ZoneWalkers.maxWalkers or 5
    local walkerDensity = Config.ZoneWalkers.density or 5
    local walkerSpawnChance = Config.ZoneWalkers.spawnChance or 40
    
    while true do
        Wait(spawnInterval)
        
        if currentEditingZone and drugZones and drugZones[currentEditingZone] then
            local zoneId = currentEditingZone
            local zone = drugZones[zoneId]
            
            if zone and zone.polygon_points and #zone.polygon_points >= 3 then
                -- Contar NPCs walkers ativos para esta zona
                local activeWalkers = 0
                if zoneWalkers then
                    for npc, data in pairs(zoneWalkers) do
                        if data and data.zoneId == zoneId and DoesEntityExist(npc) then
                            activeWalkers = activeWalkers + 1
                        end
                    end
                end
                
                -- Calcular quantos NPCs spawnar baseado na densidade
                -- Densidade 1-10: 1-5 NPCs simultâneos
                local targetWalkers = math.min(maxWalkers, math.floor(walkerDensity / 2))
                local npcsToSpawn = math.max(0, targetWalkers - activeWalkers)
                
                -- Spawnar NPCs baseado na densidade
                if npcsToSpawn > 0 then
                    local ped = PlayerPedId()
                    local pedCoords = GetEntityCoords(ped)
                    
                    -- Verificar se o player está dentro da zona
                    local playerInZone = isPointInZone(pedCoords, zone.polygon_points, zone.thickness or 10.0)
                    
                    -- Spawnar NPCs se o player estiver dentro da zona
                    if playerInZone then
                        for i = 1, npcsToSpawn do
                            local chance = math.random(1, 100)
                            if chance <= walkerSpawnChance then
                                spawnZoneWalker(zoneId)
                                Wait(500) -- Pequeno delay entre spawns
                            end
                        end
                    end
                end
            end
        end
    end
end)

