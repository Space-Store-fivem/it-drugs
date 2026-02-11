print('^2[IT-DRUGS DEBUG]^7 cl_zones.lua iniciando...')
drugZones = drugZones or {}
drugTables = drugTables or {}
local zoneObjects = {}
tableObjects = tableObjects or {}
currentEditingZone = currentEditingZone or nil

-- Variáveis de debug
local debugMode = false
local debugWasEnabled = false -- Rastrear se debug estava ativo antes de ativar temporariamente

-- Função para log de debug (definida antes de ser usada)
local function DebugLog(message, level)
    if not debugMode or not Config.ZoneDebug.showLogs then
        return
    end
    
    level = level or "INFO"
    local prefix = "^3[IT-DRUGS DEBUG]^7"
    
    if level == "ERROR" then
        prefix = "^1[IT-DRUGS DEBUG ERROR]^7"
    elseif level == "WARN" then
        prefix = "^3[IT-DRUGS DEBUG WARN]^7"
    elseif level == "SUCCESS" then
        prefix = "^2[IT-DRUGS DEBUG SUCCESS]^7"
    end
    
    print(string.format("%s %s", prefix, message))
end

-- Função para desenhar texto 3D
local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local camCoords = GetGameplayCamCoord()
    local distance = #(camCoords - vector3(x, y, z))
    
    local scale = (1 / distance) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    scale = scale * fov
    
    if onScreen then
        SetTextScale(0.0 * scale, 0.55 * scale)
        SetTextFont(0)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- Helper Functions para RayCast (Portado de cl_processing.lua)
local RotationToDirection = function(rot)
    local rotZ = math.rad(rot.z)
    local rotX = math.rad(rot.x)
    local cosOfRotX = math.abs(math.cos(rotX))
    return vector3(-math.sin(rotZ) * cosOfRotX, math.cos(rotZ) * cosOfRotX, math.sin(rotX))
end

local RayCastCamera = function(dist)
    local camRot = GetGameplayCamRot()
    local camPos = GetGameplayCamCoord()
    local dir = RotationToDirection(camRot)
    local dest = camPos + (dir * dist)
    local ray = StartShapeTestRay(camPos, dest, 17, -1, 0)
    local _, hit, endPos, surfaceNormal, entityHit = GetShapeTestResult(ray)
    if hit == 0 then endPos = dest end
    return hit, endPos, entityHit, surfaceNormal
end

-- Função para desenhar linha 3D
local function DrawLine3D(x1, y1, z1, x2, y2, z2, r, g, b, a)
    DrawLine(x1, y1, z1, x2, y2, z2, r, g, b, a)
end

-- Função para desenhar polígono de zona
local function DrawZonePolygon(zone, color, isCurrent)
    if not zone or not zone.polygon_points or #zone.polygon_points < 3 then
        return
    end
    
    local points = zone.polygon_points
    local thickness = zone.thickness or 10.0
    
    -- Desenhar linhas do polígono (parte inferior)
    for i = 1, #points do
        local p1 = points[i]
        local p2 = points[(i % #points) + 1]
        
        -- Linha inferior
        DrawLine3D(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, color.r, color.g, color.b, color.a)
        
        -- Linha vertical (conectando inferior e superior)
        DrawLine3D(p1.x, p1.y, p1.z, p1.x, p1.y, p1.z + thickness, color.r, color.g, color.b, color.a)
        
        -- Linha superior
        DrawLine3D(p1.x, p1.y, p1.z + thickness, p2.x, p2.y, p2.z + thickness, color.r, color.g, color.b, color.a)
    end
    
    -- Desenhar pontos dos vértices
    for i = 1, #points do
        local p = points[i]
        local pointSize = Config.ZoneDebug.pointSize or 0.3
        
        -- Ponto inferior
        DrawMarker(1, p.x, p.y, p.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, pointSize, pointSize, pointSize, color.r, color.g, color.b, color.a, false, true, 2, false, nil, nil, false)
        
        -- Ponto superior
        DrawMarker(1, p.x, p.y, p.z + thickness, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, pointSize, pointSize, pointSize, color.r, color.g, color.b, color.a, false, true, 2, false, nil, nil, false)
    end
    
    -- Desenhar centro da zona com informações
    local sumX, sumY, sumZ = 0, 0, 0
    for _, point in ipairs(points) do
        sumX = sumX + point.x
        sumY = sumY + point.y
        sumZ = sumZ + point.z
    end
    local centerX = sumX / #points
    local centerY = sumY / #points
    local centerZ = sumZ / #points
    
    -- Texto com informações da zona
    local zoneName = zone.name or "Sem Nome"
    local zoneGang = zone.gang_name or "Público"
    local tableCount = 0
    if drugTables[zone.zone_id] then
        tableCount = #drugTables[zone.zone_id]
    end
    
    local infoText = string.format("~b~Zona: ~w~%s\n~y~Gang: ~w~%s\n~g~Mesas: ~w~%d", zoneName, zoneGang, tableCount)
    DrawText3D(centerX, centerY, centerZ + (thickness / 2), infoText)
end

-- Função para desenhar mesas
local function DrawTableDebug(tableData, zoneId)
    if not tableData or not tableData.coords then
        return
    end
    
    local coords = tableData.coords
    local color = Config.ZoneDebug.zoneColors.table
    
    -- Desenhar marcador na mesa
    DrawMarker(1, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, color.r, color.g, color.b, color.a, false, true, 2, false, nil, nil, false)
    
    -- Texto com ID da mesa
    DrawText3D(coords.x, coords.y, coords.z + 1.0, string.format("~y~Mesa ID: ~w~%s", tableData.table_id or "N/A"))
end

-- Carregar zonas do servidor
local function loadZones()
    drugZones, drugTables = lib.callback.await('it-drugs:server:getZones', false)
    
    if debugMode then
        local zoneCount = 0
        local tableCount = 0
        for _ in pairs(drugZones) do zoneCount = zoneCount + 1 end
        for _, tables in pairs(drugTables) do
            tableCount = tableCount + #tables
        end
        DebugLog(string.format("Zonas carregadas: %d | Mesas carregadas: %d", zoneCount, tableCount), "SUCCESS")
    end
    
    -- Limpar zonas antigas
    for _, zoneObj in pairs(zoneObjects) do
        if zoneObj.remove then
            zoneObj:remove()
        end
    end
    zoneObjects = {}
    
    -- Limpar todas as mesas antigas antes de recriar
    for tableId, tableData in pairs(tableObjects) do
        if tableData.object and DoesEntityExist(tableData.object) then
            DeleteEntity(tableData.object)
        end
    end
    tableObjects = {}
    
    -- Criar zonas (apenas estrutura de dados, o loop principal gerencia a detecção)
    -- Isso substitui o uso do lib.zones.poly que estava falhando devido a erro no ox_lib
    zoneObjects = {}
    for zoneId, zone in pairs(drugZones) do
        zoneObjects[zoneId] = zone
    end
    
    -- Criar mesas de venda (Config)
    for zoneId, tables in pairs(drugTables) do
        for _, tableData in ipairs(tables) do
            if tableData.coords then
                local coords = vector4(tableData.coords.x, tableData.coords.y, tableData.coords.z, tableData.coords.heading or 0.0)
                spawnDrugTable(tableData.table_id, coords, tableData.model or 'bkr_prop_weed_table_01a', zoneId)
            end
        end
    end

    -- Criar mesas de gangue (Upgrades)
    if gangZones then
        for zoneId, zone in pairs(gangZones) do
            if zone.upgrades then
                for _, upgrade in ipairs(zone.upgrades) do
                    if upgrade.placed and upgrade.coords and upgrade.type == 'table' then
                        local coords = vector4(upgrade.coords.x, upgrade.coords.y, upgrade.coords.z, upgrade.coords.w or 0.0)
                        spawnDrugTable(upgrade.id, coords, upgrade.model, zoneId)
                    end
                end
            end
        end
    end
end

-- Spawnar mesa de drogas (tornar global)
-- Spawnar mesa de drogas (tornar global)
function spawnDrugTable(tableId, coords, model, zoneId)
    if Config.Debug then print(string.format('^3[IT-DRUGS DEBUG] Spawning Table: %s | Model: %s | Zone: %s^7', tostring(tableId), tostring(model), tostring(zoneId))) end

    -- Verificar se a mesa já existe e remover antes de criar nova
    if tableObjects[tableId] then
        if DoesEntityExist(tableObjects[tableId].object) then
            DeleteEntity(tableObjects[tableId].object)
        end
        tableObjects[tableId] = nil
    end
    
    local modelHash = GetHashKey(model)
    
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 100 do
        Wait(100)
        timeout = timeout + 1
    end

    if not HasModelLoaded(modelHash) then
        print('^1[IT-DRUGS DEBUG] Failed to load table model: ' .. tostring(model) .. '^7')
        return
    end
    
    local tableObj = CreateObject(modelHash, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(tableObj, coords.w)
    FreezeEntityPosition(tableObj, true)
    SetEntityAsMissionEntity(tableObj, true, true)
    
    tableObjects[tableId] = {
        object = tableObj,
        coords = coords,
        zoneId = zoneId
    }
    
    SetModelAsNoLongerNeeded(modelHash)
end

-- Remover mesa
local function removeDrugTable(tableId)
    if tableObjects[tableId] then
        if DoesEntityExist(tableObjects[tableId].object) then
            DeleteEntity(tableObjects[tableId].object)
        end
        tableObjects[tableId] = nil
    end
end

-- Evento para iniciar criação de zona
RegisterNetEvent('it-drugs:client:startZoneCreation', function(data)
    -- Buscar gangs disponíveis ANTES de mostrar o diálogo
    local gangs = lib.callback.await('it-drugs:server:getAllGangs', false)
    
    -- Debug: verificar se gangs foram carregadas
    if Config.Debug then
        print("^3[IT-DRUGS DEBUG]^7 Gangs carregadas: " .. tostring(#gangs or 0))
        if gangs then
            for i, gang in ipairs(gangs) do
                print("^3[IT-DRUGS DEBUG]^7 Gang " .. i .. ": " .. tostring(gang.name) .. " - " .. tostring(gang.label))
            end
        end
    end
    
    -- Preparar opções de seleção de gang (usar string vazia ao invés de nil)
    local gangOptions = {}
    table.insert(gangOptions, {value = '', label = 'Nenhum (Público)'})
    
    if gangs and #gangs > 0 then
        for _, gang in ipairs(gangs) do
            if gang and gang.name then
                table.insert(gangOptions, {
                    value = gang.name,
                    label = gang.label or gang.name
                })
            end
        end
    end
    
    -- Debug: verificar opções preparadas
    if Config.Debug then
        print("^3[IT-DRUGS DEBUG]^7 Opções de gang preparadas: " .. tostring(#gangOptions))
    end
    
    -- Se o player tem gang, adicionar como padrão
    -- Se for admin, pode escolher qualquer grupo (default será '' para permitir escolha livre)
    local playerGang = it.getPlayerGang()
    local defaultGang = ''
    if not data.canChooseAnyGang then
        -- Se não for admin, usar a gang do player como padrão
        if playerGang and playerGang.name then
            defaultGang = playerGang.name
        elseif data.gangName then
            defaultGang = data.gangName
        end
    end
    -- Se for admin (canChooseAnyGang = true), defaultGang fica '' para permitir escolha livre
    
    -- Verificar se há opções de gang antes de mostrar o diálogo
    if #gangOptions == 0 then
        lib.notify({ type = 'error', description = 'Erro: Nenhuma gang encontrada!' })
        return
    end
    
    -- Mostrar diálogo com seleção de grupo logo no início (ANTES de iniciar o criador)
    local input = lib.inputDialog('Criar Zona de Drogas', {
        {type = 'input', label = 'Nome da Zona', required = true, placeholder = 'Ex: Zona Ballas'},
        {type = 'select', label = 'Gang/Grupo', required = false, options = gangOptions, default = defaultGang or gangOptions[1].value},
        {type = 'number', label = 'Altura (Thickness)', required = true, default = 10.0, min = 1.0, max = 50.0}
    })
    
    if not input then 
        -- Se cancelou o diálogo, não fazer nada
        return 
    end
    
    -- Ativar debug temporariamente para criação/edição de zonas (após confirmar o diálogo)
    debugWasEnabled = debugMode
    if not debugMode then
        debugMode = true
        if Config.ZoneDebug.showLogs then
            DebugLog("Debug ativado automaticamente para criação/edição de zona", "INFO")
        end
    end
    
    local zoneName = input[1]
    local selectedGang = input[2] -- Pode ser '' (string vazia) para zona pública
    local thickness = input[3] or 10.0
    
    -- Converter string vazia para nil
    if selectedGang == '' then
        selectedGang = nil
    end
    
    -- Iniciar criador de zona
    ZoneCreator.startCreator({
        thickness = thickness,
        onCreated = function(zoneData)
            -- Salvar zona no servidor
            -- Gerar ID único usando GetGameTimer (disponível no cliente)
            local uniqueId = 'drug_zone_' .. GetGameTimer() .. '_' .. math.random(1000, 9999)
            if debugMode then
                DebugLog(string.format("Salvando nova zona: %s (ID: %s)", zoneName, uniqueId), "INFO")
            end
            TriggerServerEvent('it-drugs:server:saveZone', {
                zoneId = uniqueId,
                label = zoneName,
                gangName = selectedGang,
                points = zoneData.points,
                thickness = zoneData.thickness,
                drugs = nil -- Usar drogas padrão
            })
            
            -- Restaurar estado do debug se foi ativado temporariamente
            if not debugWasEnabled then
                debugMode = false
                if Config.ZoneDebug.showLogs then
                    DebugLog("Debug desativado após criação de zona", "INFO")
                end
            end
        end,
        onCanceled = function()
            -- Restaurar estado do debug se foi ativado temporariamente
            if not debugWasEnabled then
                debugMode = false
                if Config.ZoneDebug.showLogs then
                    DebugLog("Debug desativado após cancelar criação de zona", "INFO")
                end
            end
        end
    })
end)

-- Função para limpar props órfãos (mesas sem ID válido)
local function cleanupOrphanTables()
    local validTableIds = {}
    
    -- Coletar todos os IDs válidos de mesas
    if drugTables then
        for zoneId, tables in pairs(drugTables) do
            for _, tableData in ipairs(tables) do
                if tableData.table_id then
                    validTableIds[tableData.table_id] = true
                end
            end
        end
    end
    
    -- Deletar props que não têm ID válido
    for tableId, tableData in pairs(tableObjects) do
        if not validTableIds[tableId] then
            if tableData.object and DoesEntityExist(tableData.object) then
                DeleteEntity(tableData.object)
            end
            tableObjects[tableId] = nil
        end
    end
    
    -- Limpar objetos órfãos no mundo próximos às zonas (mesas que não estão na lista)
    -- Isso é mais seguro do que limpar todas as mesas do mundo
    if drugZones then
        for zoneId, zone in pairs(drugZones) do
            if zone.polygon_points and #zone.polygon_points >= 3 then
                -- Calcular centro da zona
                local centerX, centerY, centerZ = 0, 0, 0
                for _, point in ipairs(zone.polygon_points) do
                    centerX = centerX + point.x
                    centerY = centerY + point.y
                    centerZ = centerZ + point.z
                end
                centerX = centerX / #zone.polygon_points
                centerY = centerY / #zone.polygon_points
                centerZ = centerZ / #zone.polygon_points
                
                local modelHash = GetHashKey('bkr_prop_weed_table_01a')
                local objects = GetGamePool('CObject')
                
                for _, obj in ipairs(objects) do
                    if DoesEntityExist(obj) then
                        local objModel = GetEntityModel(obj)
                        if objModel == modelHash then
                            local objCoords = GetEntityCoords(obj)
                            local dist = #(vector3(centerX, centerY, centerZ) - objCoords)
                            
                            -- Se estiver dentro de 100m da zona e não estiver sendo gerenciado
                            if dist < 100.0 then
                                local isManaged = false
                                for _, tableData in pairs(tableObjects) do
                                    if tableData.object == obj then
                                        isManaged = true
                                        break
                                    end
                                end
                                if not isManaged then
                                    DeleteEntity(obj)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Evento para atualizar zonas (atualização ao vivo)
-- Evento para receber alerta de gang
RegisterNetEvent('it-drugs:client:gangAlert', function(alertData)
    if alertData and alertData.message then
        it.notify(alertData.message, 'error')
        
        -- Opcional: Criar waypoint no mapa
        if alertData.coords then
            SetNewWaypoint(alertData.coords.x, alertData.coords.y)
        end
    end
end)

-- Sincronizar mesas quando as zonas de gangue atualizarem
RegisterNetEvent('it-drugs:client:updateGangZones', function(zones)
    -- gangZones é global, mas garantimos a atualização aqui se necessário
    if zones then gangZones = zones end
    print('^2[IT-DRUGS DEBUG] Gang Zones updated. Refreshing tables...^7')
    loadZones()
end)

RegisterNetEvent('it-drugs:client:zonesUpdated', function(zones, tables)
    -- Atualizar dados imediatamente
    if zones then drugZones = zones end
    if tables then drugTables = tables end
    
    -- Salvar zona atual antes de recarregar
    local wasInZone = currentEditingZone
    
    -- Recarregar zonas (isso vai recriar as zonas e mesas)
    loadZones()
    
    -- Se estava em uma zona que foi deletada, remover o target de venda
    if wasInZone and not drugZones[wasInZone] then
        currentEditingZone = nil
        if Config.EnableSelling then
            RemoveSellTarget()
        end
    end
    
    -- Se ainda está em uma zona válida, garantir que o target está ativo
    if currentEditingZone and drugZones[currentEditingZone] then
        if Config.EnableSelling then
            CreateSellTarget()
        end
    end
    
    Wait(500) -- Aguardar um pouco
    cleanupOrphanTables() -- Limpar props órfãos após atualizar
end)

-- Variável para mesa sendo posicionada
local positioningTable = nil
local positioningTableObj = nil

-- Função para verificar se coordenadas estão dentro de uma zona
local function isPointInZone(point, zone)
    if not zone then return false, "invalid_zone_data" end
    
    -- Tentar usar o objeto de zona do ox_lib se disponível (Mais preciso e consistente)
    if zone.zone_id and zoneObjects[zone.zone_id] then
       -- keeping this commented out or minimal as per previous issues, or we can leave it commented if user preferred manual check. 
       -- Let's just remove the disabled block to clean up if we are sure manual is better.
       -- actually, let's just leave the manual part as primary since ox_lib failed.
    end

    if not zone.polygon_points or #zone.polygon_points < 3 then 
        if Config.Debug then print('^1[IT-DRUGS DEBUG] Invalid polygon points: ' .. tostring(#(zone.polygon_points or {})) .. '^7') end
        return false, "invalid_zone_points" 
    end
    
    local x, y, z = point.x, point.y, point.z
    local inside = false
    local j = #zone.polygon_points
    
    for i = 1, #zone.polygon_points do
        local pi = zone.polygon_points[i]
        local pj = zone.polygon_points[j]
        
        local intersect = ((pi.y > y) ~= (pj.y > y)) and (x < (pj.x - pi.x) * (y - pi.y) / (pj.y - pi.y) + pi.x)
        
        if intersect then
            inside = not inside
             -- print(string.format("  -> Intersected edge %d-%d. Inside flip to: %s", j, i, tostring(inside)))
        end
        j = i
    end
    
    if not inside then
        print("^1[ZONE CHECK FAIL XY]^7 Point outside polygon limits.")
        return false, "outside_xy"
    end
    
    -- Verificar altura (mais flexível para zonas em prédios)
    local thickness = zone.thickness or 10.0
    local minZ = math.huge
    local maxZ = -math.huge
    
    -- Encontrar min e max Z dos pontos do polígono
    for i = 1, #zone.polygon_points do
        local pz = zone.polygon_points[i].z
        if pz < minZ then minZ = pz end
        if pz > maxZ then maxZ = pz end
    end
    
    -- Aplicar thickness a partir do minZ e maxZ
    local zoneMinZ = minZ
    local zoneMaxZ = maxZ + thickness
    
    -- Verificar se o ponto está dentro da faixa de altura
    -- Aumentada margem de erro para 50.0 para evitar frustrações
    if z < (zoneMinZ - 50.0) or z > (zoneMaxZ + 50.0) then
        -- Debug para entender o porque falha
        print(string.format("^3[ZONE FAIL Z]^7 PointZ: %.2f | MinZ: %.2f | MaxZ: %.2f", z, zoneMinZ - 50.0, zoneMaxZ + 50.0))
        return false, "outside_z"
    end
    
    return true, "inside"
end

-- Comando removido - usar painel (/drugzone)

-- Função para posicionar mesa (usada pelo painel)
local function positionTable(zoneId, tableId, model, currentCoords)
    -- Ativar debug temporariamente para posicionamento de mesa
    debugWasEnabled = debugMode
    if not debugMode then
        debugMode = true
        if Config.ZoneDebug.showLogs then
            DebugLog("Debug ativado automaticamente para posicionamento de mesa", "INFO")
        end
    end
    
    local modelHash = GetHashKey(model or 'bkr_prop_weed_table_01a')
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(100)
    end
    
    local tempTable = CreateObject(modelHash, currentCoords.x, currentCoords.y, currentCoords.z, false, false, false)
    SetEntityHeading(tempTable, currentCoords.w or 0.0)
    SetEntityAlpha(tempTable, 200, false)
    SetEntityCollision(tempTable, false, false)
    FreezeEntityPosition(tempTable, false)
    
    positioningTable = {
        zoneId = zoneId,
        model = model or 'bkr_prop_weed_table_01a',
        tableId = tableId,
        coords = {x = currentCoords.x, y = currentCoords.y, z = currentCoords.z, heading = currentCoords.w or 0.0}
    }
    positioningTableObj = tempTable
    
    lib.notify({ 
        type = 'info', 
        description = 'Posicionando mesa! Use [WASD] para mover, [Q/E] para rotacionar, [Shift/Ctrl] para subir/descer, [Enter] para confirmar, [X] para cancelar' 
    })
    
    CreateThread(function()
        local moveSpeed = 0.1
        local rotSpeed = 2.0
        local editZoneId = zoneId
        
        while positioningTableObj and DoesEntityExist(positioningTableObj) do
            Wait(0)
            
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 32, true)
            DisableControlAction(0, 33, true)
            
            local currentCoords = GetEntityCoords(positioningTableObj)
            local currentHeading = GetEntityHeading(positioningTableObj)
            local newCoords = currentCoords
            local newHeading = currentHeading
            
            if IsControlPressed(0, 32) then
                newCoords = newCoords + vector3(0.0, moveSpeed, 0.0)
            elseif IsControlPressed(0, 33) then
                newCoords = newCoords + vector3(0.0, -moveSpeed, 0.0)
            end
            
            if IsControlPressed(0, 34) then
                newCoords = newCoords + vector3(-moveSpeed, 0.0, 0.0)
            elseif IsControlPressed(0, 35) then
                newCoords = newCoords + vector3(moveSpeed, 0.0, 0.0)
            end
            
            if IsControlPressed(0, 21) then
                newCoords = newCoords + vector3(0.0, 0.0, moveSpeed)
            elseif IsControlPressed(0, 36) then
                newCoords = newCoords + vector3(0.0, 0.0, -moveSpeed)
            end
            
            if IsControlPressed(0, 44) then
                newHeading = newHeading - rotSpeed
            elseif IsControlPressed(0, 38) then
                newHeading = newHeading + rotSpeed
            end
            
            local found, groundZ = GetGroundZFor_3dCoord(newCoords.x, newCoords.y, newCoords.z, false)
            if found then
                newCoords = vector3(newCoords.x, newCoords.y, groundZ)
            end
            
            SetEntityCoords(positioningTableObj, newCoords.x, newCoords.y, newCoords.z, false, false, false, true)
            SetEntityHeading(positioningTableObj, newHeading)
            
            local zone = drugZones[editZoneId]
            local inZone = false
            local reason = nil
            if zone then
                inZone, reason = isPointInZone(newCoords, zone)
                DrawZonePolygon(zone, {r=0, g=255, b=0, a=100}, true)
            end
            
            local onScreen, screenX, screenY = World3dToScreen2d(newCoords.x, newCoords.y, newCoords.z + 1.0)
            if onScreen then
                local statusText = "~g~Dentro da Zona"
                if not inZone then
                    if reason == "outside_z" then
                        statusText = "~r~Altura Incorreta (Fora Z)"
                    else
                        statusText = "~r~Fora da Zona"
                    end
                end
                
                DrawText3D(newCoords.x, newCoords.y, newCoords.z + 1.0, 
                    statusText .. "~w~\n[Enter] Confirmar | [X] Cancelar")
            end
            
            if IsControlJustPressed(0, 191) then
                if inZone then
                    positioningTable.coords = {
                        x = newCoords.x,
                        y = newCoords.y,
                        z = newCoords.z,
                        heading = newHeading
                    }
                    
                    -- Remover mesa antiga se estiver editando
                    if tableId and tableObjects[tableId] then
                        if DoesEntityExist(tableObjects[tableId].object) then
                            DeleteEntity(tableObjects[tableId].object)
                        end
                        tableObjects[tableId] = nil
                    end
                    
                    if tableId then
                        if debugMode then
                            DebugLog(string.format("Atualizando mesa ID: %s na zona: %s", tableId, zoneId), "INFO")
                        end
                        TriggerServerEvent('it-drugs:server:updateDrugTable', {
                            tableId = tableId,
                            coords = positioningTable.coords
                        })
                    else
                        if debugMode then
                            DebugLog(string.format("Salvando nova mesa na zona: %s", zoneId), "INFO")
                        end
                        TriggerServerEvent('it-drugs:server:saveDrugTable', {
                            zoneId = zoneId,
                            coords = positioningTable.coords,
                            model = positioningTable.model
                        })
                    end
                    
                    DeleteEntity(positioningTableObj)
                    positioningTable = nil
                    positioningTableObj = nil
                    lib.notify({ type = 'success', description = 'Mesa salva com sucesso!' })
                    
                    -- Restaurar estado do debug se foi ativado temporariamente
                    if not debugWasEnabled then
                        debugMode = false
                        if Config.ZoneDebug.showLogs then
                            DebugLog("Debug desativado após salvar mesa", "INFO")
                        end
                    end
                    break
                else
                    lib.notify({ type = 'error', description = 'A mesa precisa estar dentro da zona!' })
                end
            end
            
            if IsControlJustPressed(0, 73) then
                DeleteEntity(positioningTableObj)
                positioningTable = nil
                positioningTableObj = nil
                lib.notify({ type = 'info', description = 'Posicionamento cancelado.' })
                
                -- Restaurar estado do debug se foi ativado temporariamente
                if not debugWasEnabled then
                    debugMode = false
                    if Config.ZoneDebug.showLogs then
                        DebugLog("Debug desativado após cancelar posicionamento de mesa", "INFO")
                    end
                end
                
                if tableId then
                    loadZones()
                end
                break
            end
        end
        
        SetModelAsNoLongerNeeded(modelHash)
    end)
end

-- Evento genérico para posicionar upgrades (Mesas ou NPCs)
RegisterNetEvent('it-drugs:client:positionUpgrade', function(zoneId, upgradeUniqueId, model, type)
    print(string.format('^3[IT-DRUGS DEBUG] Client received positionUpgrade event. Zone: %s | ID: %s | Model: %s | Type: %s^7', tostring(zoneId), tostring(upgradeUniqueId), tostring(model), tostring(type)))
    
    -- Se o tipo não vier, tentar descobrir pelo modelo na config
    if not type then
        for k, v in pairs(Config.ZoneUpgrades) do
            if v.model == model then
                type = v.type
                print('^3[IT-DRUGS DEBUG] Resolved missing type from config: ' .. tostring(type) .. '^7')
                break
            end
        end
    end

    if type == 'table' then
        -- Alteração solicitada: Mesas viram itens no inventário em vez de serem posicionadas
        TriggerServerEvent('it-drugs:server:giveUpgradeItem', zoneId, upgradeUniqueId, type, model)
        lib.notify({type = 'success', description = 'A mesa foi adicionada ao seu inventário!'})
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    
    -- Iniciar posicionamento (Apenas para NPCs agora)
    positionUpgradeGeneric(zoneId, upgradeUniqueId, model, vector4(coords.x, coords.y, coords.z, heading), type)
end)

-- Função genérica de posicionamento (Adaptada de positionTable)
-- Função genérica de posicionamento (Adaptada para RayCast estilo Processing Table)
function positionUpgradeGeneric(zoneId, upgradeUniqueId, model, currentCoords, type)
    -- Configuração de distância do RayCast (padrão 10.0 se não existir na config)
    local rayCastDist = Config.rayCastingDistance or 10.0

    -- Carregar modelo
    local modelHash = GetHashKey(model)
    if not IsModelInCdimage(modelHash) then
        print('^1[IT-DRUGS DEBUG] Model not found in CD image: ' .. tostring(model) .. '^7')
    end

    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 100 do
        Wait(100)
        timeout = timeout + 1
    end
    
    if not HasModelLoaded(modelHash) then
        print('^1[IT-DRUGS DEBUG] Failed to load model: ' .. tostring(model) .. '^7')
        lib.notify({type = 'error', description = 'Erro ao carregar modelo: ' .. tostring(model)})
        return
    end
    
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local _, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, true)
    
    -- Se groundZ falhar (retornar 0 em interiores), usar z do player
    if groundZ == 0.0 then
        groundZ = coords.z - 1.0
    end

    -- Criar objeto temporário (fantasma)
    local tempObj
    if type == 'npc' then
        print('^3[IT-DRUGS DEBUG] Spawning NPC ghost: ' .. tostring(model) .. ' at ' .. tostring(coords) .. '^7')
        tempObj = CreatePed(4, modelHash, coords.x, coords.y, groundZ, 0.0, false, false)
        if not DoesEntityExist(tempObj) then
             print('^1[IT-DRUGS DEBUG] Failed to create NPC ghost entity!^7')
        end
        SetEntityAlpha(tempObj, 200, false)
        SetEntityCollision(tempObj, false, false)
        FreezeEntityPosition(tempObj, true)
    else
        tempObj = CreateObject(modelHash, coords.x, coords.y, groundZ, false, false, false)
        SetEntityCollision(tempObj, false, false)
        SetEntityAlpha(tempObj, 150, false)
        SetEntityHeading(tempObj, 0.0)
    end
    
    lib.showTextUI('Posicionando Upgrade\n[E] Confirmar\n[G] Cancelar\n[Setas] Rodar\nUse o mouse para mover', {
        position = "left-center",
        icon = "arrows-up-down-left-right",
    })
    
    local placed = false
    local rotation = 0.0
    
    CreateThread(function()
        while not placed and DoesEntityExist(tempObj) do
            Wait(0)
            
            -- RayCast da câmera
            local hit, dest, _, surfaceNormal = RayCastCamera(rayCastDist)
            
            if hit == 1 then
                SetEntityCoords(tempObj, dest.x, dest.y, dest.z)
                
                -- Controle de Rotação (Setas)
                if IsControlPressed(0, 174) then -- Seta Esquerda
                    rotation = rotation + 1.0
                    if rotation >= 360.0 then rotation = 0.0 end
                elseif IsControlPressed(0, 175) then -- Seta Direita
                    rotation = rotation - 1.0
                    if rotation <= 0.0 then rotation = 360.0 end
                end
                SetEntityHeading(tempObj, rotation)

                -- Visualização da Zona e Verificação
                local zone = drugZones[zoneId]
                if not zone and gangZones then
                    zone = gangZones[zoneId]
                end

                local isInside = false
                local reason = nil
                
                if zone then
                    -- Desenhar visual da zona
                    DrawZonePolygon(zone, {r=0, g=255, b=0, a=100}, true)
                    
                    -- Verificar se está dentro
                    isInside, reason = isPointInZone(dest, zone)
                    
                    if isInside then
                        if type ~= 'npc' then -- NPCs nao suportam outline
                             SetEntityDrawOutline(tempObj, true)
                             SetEntityDrawOutlineColor(0, 255, 0, 255) -- Verde se OK
                        end
                    else
                        if type ~= 'npc' then
                             SetEntityDrawOutline(tempObj, true)
                             SetEntityDrawOutlineColor(255, 0, 0, 255) -- Vermelho se Fora
                        end
                        
                        local failText = reason == "outside_z" and "~r~Altura Incorreta" or "~r~Fora da Zona"
                        DrawText3D(dest.x, dest.y, dest.z + 1.0, failText)
                    end
                end

                -- Confirmar (E)
                if IsControlJustPressed(0, 38) then
                    if isInside then
                        placed = true
                        TriggerServerEvent('it-drugs:server:placeUpgrade', zoneId, upgradeUniqueId, dest, rotation)
                        DeleteEntity(tempObj)
                        lib.hideTextUI()
                        lib.notify({ type = 'success', description = 'Upgrade posicionado com sucesso!' })
                        break
                    else
                        lib.notify({ type = 'error', description = reason == "outside_z" and 'Altura incorreta!' or 'Precisa ser dentro da zona!' })
                    end
                end

                -- Cancelar (G)
                if IsControlJustPressed(0, 47) then 
                    placed = true
                    DeleteEntity(tempObj)
                    lib.hideTextUI()
                    lib.notify({ type = 'error', description = 'Posicionamento cancelado.' })
                    break
                end
            else
                -- Se o RayCast não bater em nada, manter perto do jogador para não sumir
                local pCoords = GetEntityCoords(ped)
                SetEntityCoords(tempObj, pCoords.x, pCoords.y, pCoords.z - 5.0) -- Esconder embaixo da terra ou perto
            end
        end
    end)
end


-- Função para listar zonas
local function showZonesList()
    local options = {}
    
    for zoneId, zone in pairs(drugZones) do
        table.insert(options, {
            title = zone.label or 'Zona Sem Nome',
            description = string.format('ID: %s | Gang: %s | Altura: %.1fm', zoneId, zone.gang_name and zone.gang_name ~= '' and zone.gang_name or 'Público', zone.thickness or 10.0),
            icon = 'map',
            arrow = true,
            onSelect = function()
                lib.registerContext({
                    id = 'it-drugs-zone-actions',
                    title = zone.label or 'Zona',
                    menu = 'it-drugs-zones-list',
                    options = {
                        {
                            title = 'Editar Zona',
                            description = 'Modificar pontos e configurações',
                            icon = 'edit',
                            onSelect = function()
                                local input = lib.inputDialog('Editar Zona', {
                                    {type = 'input', label = 'Nome', required = true, default = zone.label or 'Zona de Drogas'},
                                    {type = 'number', label = 'Altura', required = true, default = zone.thickness or 10.0, min = 1.0, max = 50.0}
                                })
                                
                                if not input then return end
                                
                                -- Ativar debug temporariamente para edição de zona
                                debugWasEnabled = debugMode
                                if not debugMode then
                                    debugMode = true
                                    if Config.ZoneDebug.showLogs then
                                        DebugLog("Debug ativado automaticamente para edição de zona", "INFO")
                                    end
                                end
                                
                                ZoneCreator.startCreator({
                                    thickness = input[2] or 10.0,
                                    initialPoints = zone.polygon_points,
                                    onCreated = function(zoneData)
                                        TriggerServerEvent('it-drugs:server:updateZone', {
                                            zoneId = zoneId,
                                            label = input[1],
                                            points = zoneData.points,
                                            thickness = zoneData.thickness
                                        })
                                        
                                        -- Restaurar estado do debug se foi ativado temporariamente
                                        if not debugWasEnabled then
                                            debugMode = false
                                            if Config.ZoneDebug.showLogs then
                                                DebugLog("Debug desativado após editar zona", "INFO")
                                            end
                                        end
                                    end,
                                    onCanceled = function()
                                        -- Restaurar estado do debug se foi ativado temporariamente
                                        if not debugWasEnabled then
                                            debugMode = false
                                            if Config.ZoneDebug.showLogs then
                                                DebugLog("Debug desativado após cancelar edição de zona", "INFO")
                                            end
                                        end
                                    end
                                })
                            end
                        },
                        {
                            title = 'Deletar Zona',
                            description = 'Remover zona permanentemente',
                            icon = 'trash',
                            onSelect = function()
                                local alert = lib.alertDialog({
                                    header = 'Confirmar Exclusão',
                                    content = 'Tem certeza que deseja deletar esta zona? Todas as mesas serão removidas também.',
                                    centered = true,
                                    cancel = true,
                                    labels = {
                                        cancel = 'Cancelar',
                                        confirm = 'Deletar'
                                    }
                                })
                                
                                if alert == 'confirm' then
                                    if debugMode then
                                        DebugLog(string.format("Deletando zona: %s (ID: %s)", zone.label or "Sem Nome", zoneId), "WARN")
                                    end
                                    TriggerServerEvent('it-drugs:server:deleteZone', zoneId)
                                end
                            end
                        }
                    }
                })
                lib.showContext('it-drugs-zone-actions')
            end
        })
    end
    
    if #options == 0 then
        table.insert(options, {
            title = 'Nenhuma Zona Encontrada',
            description = 'Crie uma zona primeiro',
            icon = 'info'
        })
    end
    
    lib.registerContext({
        id = 'it-drugs-zones-list',
        title = 'Lista de Zonas',
        menu = 'it-drugs-zone-menu',
        options = options
    })
    
    lib.showContext('it-drugs-zones-list')
end

-- Função para mostrar menu de mesas
local function showTableMenu(zoneId)
    local zone = drugZones[zoneId]
    if not zone then return end
    
    local options = {}
    
    -- Adicionar nova mesa
    table.insert(options, {
        title = 'Adicionar Mesa',
        description = 'Adicionar uma nova mesa nesta zona',
        icon = 'plus',
        arrow = true,
        onSelect = function()
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            
            local input = lib.inputDialog('Criar Mesa de Drogas', {
                {type = 'input', label = 'Modelo da Mesa', required = false, placeholder = 'bkr_prop_weed_table_01a', default = 'bkr_prop_weed_table_01a'}
            })
            
            if not input then return end
            
            positionTable(zoneId, nil, input[1] or 'bkr_prop_weed_table_01a', vector4(coords.x, coords.y, coords.z, heading))
        end
    })
    
    -- Listar mesas existentes
    if drugTables[zoneId] and #drugTables[zoneId] > 0 then
        for _, tableData in ipairs(drugTables[zoneId]) do
            table.insert(options, {
                title = string.format('Mesa #%s', tableData.table_id),
                description = string.format('Modelo: %s | Editar ou Deletar', tableData.model or 'bkr_prop_weed_table_01a'),
                icon = 'table',
                arrow = true,
                onSelect = function()
                    lib.registerContext({
                        id = 'it-drugs-table-actions',
                        title = 'Ações da Mesa',
                        menu = 'it-drugs-table-menu',
                        options = {
                            {
                                title = 'Editar Posição',
                                description = 'Mover esta mesa para outra posição',
                                icon = 'edit',
                                onSelect = function()
                                    if tableData.coords then
                                        local coords = vector4(tableData.coords.x, tableData.coords.y, tableData.coords.z, tableData.coords.heading or 0.0)
                                        positionTable(zoneId, tableData.table_id, tableData.model, coords)
                                    end
                                end
                            },
                            {
                                title = 'Deletar Mesa',
                                description = 'Remover esta mesa permanentemente',
                                icon = 'trash',
                                onSelect = function()
                                    local alert = lib.alertDialog({
                                        header = 'Confirmar Exclusão',
                                        content = 'Tem certeza que deseja deletar esta mesa?',
                                        centered = true,
                                        cancel = true,
                                        labels = {
                                            cancel = 'Cancelar',
                                            confirm = 'Deletar'
                                        }
                                    })
                                    
                                    if alert == 'confirm' then
                                        if debugMode then
                                            DebugLog(string.format("Deletando mesa ID: %s", tableData.table_id), "WARN")
                                        end
                                        TriggerServerEvent('it-drugs:server:deleteDrugTable', tableData.table_id)
                                    end
                                end
                            }
                        }
                    })
                    lib.showContext('it-drugs-table-actions')
                end
            })
        end
    end
    
    lib.registerContext({
        id = 'it-drugs-table-menu',
        title = string.format('Mesas - %s', zone.label or 'Zona'),
        menu = 'it-drugs-zone-menu',
        options = options
    })
    
    lib.showContext('it-drugs-table-menu')
end

-- Função para mostrar menu principal de zonas
local function showZoneMenu()
    local options = {}
    
    -- Opção: Criar Nova Zona
    table.insert(options, {
        title = 'Criar Nova Zona',
        description = 'Criar uma nova zona de drogas',
        icon = 'plus',
        arrow = true,
        onSelect = function()
            TriggerServerEvent('it-drugs:server:requestZoneCreation')
        end
    })
    
    -- Opção: Editar Zona Atual (se estiver em uma zona)
    if currentEditingZone and drugZones[currentEditingZone] then
        local zone = drugZones[currentEditingZone]
        table.insert(options, {
            title = 'Editar Zona Atual',
            description = string.format('Editar zona: %s', zone.label or 'Sem nome'),
            icon = 'edit',
            arrow = true,
            onSelect = function()
                local input = lib.inputDialog('Editar Zona de Drogas', {
                    {type = 'input', label = 'Nome da Zona', required = true, default = zone.label or 'Zona de Drogas'},
                    {type = 'number', label = 'Altura (Thickness)', required = true, default = zone.thickness or 10.0, min = 1.0, max = 50.0}
                })
                
                if not input then return end
                
                -- Ativar debug temporariamente para edição de zona
                debugWasEnabled = debugMode
                if not debugMode then
                    debugMode = true
                    if Config.ZoneDebug.showLogs then
                        DebugLog("Debug ativado automaticamente para edição de zona", "INFO")
                    end
                end
                
                ZoneCreator.startCreator({
                    thickness = input[2] or 10.0,
                    initialPoints = zone.polygon_points,
                    onCreated = function(zoneData)
                        TriggerServerEvent('it-drugs:server:updateZone', {
                            zoneId = currentEditingZone,
                            label = input[1],
                            points = zoneData.points,
                            thickness = zoneData.thickness
                        })
                        
                        -- Restaurar estado do debug se foi ativado temporariamente
                        if not debugWasEnabled then
                            debugMode = false
                            if Config.ZoneDebug.showLogs then
                                DebugLog("Debug desativado após editar zona", "INFO")
                            end
                        end
                    end,
                    onCanceled = function()
                        -- Restaurar estado do debug se foi ativado temporariamente
                        if not debugWasEnabled then
                            debugMode = false
                            if Config.ZoneDebug.showLogs then
                                DebugLog("Debug desativado após cancelar edição de zona", "INFO")
                            end
                        end
                    end
                })
            end
        })
        
        -- Opção: Gerenciar Mesas da Zona
        table.insert(options, {
            title = 'Gerenciar Mesas',
            description = 'Adicionar, editar ou remover mesas desta zona',
            icon = 'table',
            arrow = true,
            onSelect = function()
                showTableMenu(currentEditingZone)
            end
        })
    end
    
    -- Opção: Listar Todas as Zonas
    table.insert(options, {
        title = 'Listar Zonas',
        description = 'Ver todas as zonas criadas',
        icon = 'list',
        arrow = true,
        onSelect = function()
            showZonesList()
        end
    })
    
    lib.registerContext({
        id = 'it-drugs-zone-menu',
        title = 'Gerenciar Zonas de Drogas',
        options = options
    })
    
    lib.showContext('it-drugs-zone-menu')
end


-- Evento duplicado removido - usando o evento principal na linha 138 que inclui seleção de gang

-- Comando para abrir painel de gerenciamento
RegisterNetEvent('it-drugs:client:openZoneMenu', function()
    print('^2[IT-DRUGS DEBUG]^7 Evento it-drugs:client:openZoneMenu recebido')
    showZoneMenu()
end)

-- Comandos removidos - usar painel (/drugzone)

-- Limpar props órfãos quando o script iniciar
AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        Wait(1000) -- Aguardar um pouco para garantir que tudo está carregado
        cleanupOrphanTables()
    end
end)

-- ============================================
-- SISTEMA DE DEBUG
-- ============================================



-- Thread principal de debug
CreateThread(function()
    while true do
        Wait(0)
        
        if debugMode and Config.ZoneDebug.showZones then
            -- Desenhar todas as zonas
            for zoneId, zone in pairs(drugZones) do
                if zone.polygon_points and #zone.polygon_points >= 3 then
                    local isCurrent = (currentEditingZone == zoneId)
                    local color = nil
                    
                    if isCurrent then
                        color = Config.ZoneDebug.zoneColors.current
                    elseif zone.color then
                        color = zone.color
                        if not color.a then color.a = 150 end
                    else
                        color = (zone.gang_name and Config.ZoneDebug.zoneColors.owned or Config.ZoneDebug.zoneColors.default)
                    end
                    
                    DrawZonePolygon(zone, color, isCurrent)
                end
            end
            
            -- Desenhar todas as mesas
            if Config.ZoneDebug.showInfo then
                for zoneId, tables in pairs(drugTables) do
                    for _, tableData in ipairs(tables) do
                        DrawTableDebug(tableData, zoneId)
                    end
                end
            end
        else
            Wait(500) -- Reduzir uso de CPU quando debug está desativado
        end
    end
end)

-- Thread para mostrar informações na tela
CreateThread(function()
    while true do
        Wait(1000)
        
        if debugMode and Config.ZoneDebug.showInfo then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            
            -- Encontrar zona atual
            local currentZoneInfo = nil
            for zoneId, zone in pairs(drugZones) do
                if zone.polygon_points and #zone.polygon_points >= 3 then
                    if isPointInZone(playerCoords, zone) then
                        currentZoneInfo = {
                            id = zoneId,
                            name = zone.name or "Sem Nome",
                            gang = zone.gang_name or "Público",
                            thickness = zone.thickness or 10.0,
                            points = #zone.polygon_points,
                            tables = drugTables[zoneId] and #drugTables[zoneId] or 0
                        }
                        break
                    end
                end
            end
            
            -- Mostrar informações no console
            if currentZoneInfo and Config.ZoneDebug.showLogs then
                print(string.format("^2[DEBUG ZONA]^7 Zona: %s | Gang: %s | Mesas: %d | Pontos: %d", 
                    currentZoneInfo.name, currentZoneInfo.gang, currentZoneInfo.tables, currentZoneInfo.points))
            end
        else
            Wait(5000) -- Reduzir uso quando debug está desativado
        end
    end
end)

-- Comando para ativar/desativar debug mode
RegisterCommand('drugzonedebug', function()
    debugMode = not debugMode
    
    if debugMode then
        lib.notify({
            type = 'success',
            description = 'Modo Debug de Zonas ATIVADO'
        })
        DebugLog("Modo Debug ATIVADO", "SUCCESS")
    else
        lib.notify({
            type = 'info',
            description = 'Modo Debug de Zonas DESATIVADO'
        })
        DebugLog("Modo Debug DESATIVADO", "INFO")
    end
end, false)

-- Exportar função de debug para outros scripts
exports('DebugLog', DebugLog)
exports('IsDebugMode', function() return debugMode end)

-- Helper Function: Check if point is inside polygon (Ray Casting Algorithm)
local function isPointInZone(coords, zone)
    if not zone or not zone.polygon_points then return false end
    
    local x, y, z = coords.x, coords.y, coords.z
    local points = zone.polygon_points
    local inside = false
    local j = #points
    
    -- Check XY polygon
    for i = 1, #points do
        local pi = points[i]
        local pj = points[j]
        
        if ((pi.y > y) ~= (pj.y > y)) and (x < (pj.x - pi.x) * (y - pi.y) / (pj.y - pi.y) + pi.x) then
            inside = not inside
        end
        j = i
    end
    
    -- Check Z height if inside polygon
    if inside then
        local minZ = points[1].z
        for i = 2, #points do
            if points[i].z < minZ then minZ = points[i].z end
        end
        
        local thickness = zone.thickness or 10.0
        local maxZ = minZ + thickness
        
        -- Optional: Expanded check for z-fighting or slight offset
        if z < (minZ - 2.0) or z > (maxZ + 2.0) then
            inside = false
        end
    end
    
    return inside
end

-- Inicializar ao carregar
CreateThread(function()
    Wait(2000) -- Aguardar o servidor estar pronto
    loadZones()
    Wait(1000) -- Aguardar zonas carregarem
    cleanupOrphanTables() -- Limpar props órfãos após carregar
    
    -- Debug para verificar carregamento
    local zoneCount = 0
    if drugZones then for _ in pairs(drugZones) do zoneCount = zoneCount + 1 end end
    print('^2[IT-DRUGS DETECTION]^7 Sistema iniciado. Zonas carregadas: ' .. zoneCount)
    
    -- Verificar se debug deve estar ativo por padrão
    if Config.ZoneDebug.enabled then
        debugMode = true
        DebugLog("Modo Debug ativado por padrão na config", "INFO")
    end

    -- Loop Manual de Detecção e Notificação NUI
    -- Este loop roda separado do polyzone para gerenciar a UI React
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        
        -- Otimização: Apenas verificar se houver zonas carregadas
        local foundZone = nil
        
        if drugZones then
            for zoneId, zone in pairs(drugZones) do
                -- Checagem básica de distância antes de polígono complexo (Raio de 150m do primeiro ponto)
                if zone.polygon_points and zone.polygon_points[1] then
                    local firstPoint = zone.polygon_points[1]
                    local dist = #(coords - vector3(firstPoint.x, firstPoint.y, firstPoint.z))
                    
                    if dist < 150.0 then
                        sleep = 200 -- Aumentar frequência quando perto de possível zona
                        
                        local inside = isPointInZone(coords, zone)
                        if inside then
                            if Config.Debug then print('^2[IT-DRUGS CHECK]^7 INSIDE ZONE: ' .. tostring(zoneId)) end
                            foundZone = zoneId
                            break -- Encontrou uma
                        else
                            if dist < 50.0 and Config.Debug then
                                print('^3[IT-DRUGS CHECK]^7 NEAR ZONE: ' .. tostring(zoneId) .. ' Dist: ' .. math.floor(dist) .. 'm')
                            end
                        end
                    end
                end
            end
        end
        
        -- Lógica de Entrada/Saída para UI
            -- Lógica de Entrada/Saída para UI
            if foundZone ~= currentEditingZone then
                -- SAÍDA da zona anterior
                if currentEditingZone then
                    if Config.Debug then print("Exited Drug Zone ["..tostring(currentEditingZone).."] (NUI Trigger)") end
                    
                    -- Enviar evento NUI para fechar notificação (DESATIVADO PARA DRUG ZONES)
                    -- SendNUIMessage({
                    --     action = 'zoneNotification',
                    --     show = false,
                    --     zoneName = '',
                    --     gangOwner = ''
                    -- })
                    
                    -- Trigger legacy events for selling/gangs
                    TriggerEvent('it-drugs:client:exitGangZone', currentEditingZone)
                    currentZone = nil -- For selling logic
                end
                
                -- ENTRADA na nova zona
                if foundZone then
                    if Config.Debug then print("Entered Drug Zone ["..tostring(foundZone).."] (NUI Trigger)") end
                    
                    local zone = drugZones[foundZone]
                    local gangOwner = zone.gang_name or "Ninguém"
                    local zoneLabel = zone.label or zone.name or "Zona Desconhecida"
                    
                    -- Enviar evento NUI para mostrar notificação (DESATIVADO PARA DRUG ZONES)
                    -- SendNUIMessage({
                    --     action = 'zoneNotification',
                    --     show = true,
                    --     zoneName = zoneLabel,
                    --     gangOwner = gangOwner
                    -- })
                    
                    -- Trigger legacy events for selling/gangs
                    TriggerEvent('it-drugs:client:enterGangZone', foundZone)
                    currentZone = foundZone -- For selling logic
                end
                
                currentEditingZone = foundZone
            end
        
        Wait(sleep)
    end
end)


-- Global Gang Colors Cache
GangColors = {}

RegisterNetEvent('it-drugs:client:syncGangColors', function(colors)
    GangColors = colors
    -- Trigger refresh if needed
    -- If zones are blips, update them.
end)

-- Request on load
CreateThread(function()
    TriggerServerEvent('it-drugs:server:requestGangColors')
end)

-- Export for external use
exports('getGangColor', function(gangName)
    if GangColors[gangName] then return GangColors[gangName] end
    return nil
end)
