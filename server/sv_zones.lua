drugZones = {}
local drugTables = {}
local lastCreatedZoneId = nil

-- Função para verificar se o player é admin
-- Função para verificar se o player é admin
function it.isAdmin(src)
    local Player = it.getPlayer(src)
    if not Player then return false end
    
    -- Tentar verificar usando exports.qbx_core:HasPermission (qbx_core)
    local success1, result1 = pcall(function()
        if exports.qbx_core and exports.qbx_core.HasPermission then
            for _, adminGroup in ipairs(Config.AdminGroups) do
                if exports.qbx_core:HasPermission(src, adminGroup) then
                    return true
                end
            end
        end
        return false
    end)
    
    if success1 and result1 then
        return true
    end
    
    -- Fallback: verificar usando PlayerData (qb-core padrão)
    if it.core == 'qb-core' then
        if Player.PlayerData then
            local group = Player.PlayerData.group or (Player.PlayerData.metadata and Player.PlayerData.metadata.staff)
            if group then
                for _, adminGroup in ipairs(Config.AdminGroups) do
                    if group == adminGroup then
                        return true
                    end
                end
            end
        end
    elseif it.core == 'esx' then
        local group = Player.getGroup()
        if group then
            for _, adminGroup in ipairs(Config.AdminGroups) do
                if group == adminGroup then
                    return true
                end
            end
        end
    end
    
    return false
end

-- Função para obter o grupo/gang do player
local function getPlayerGang(src)
    local Player = it.getPlayer(src)
    if not Player then return nil end
    
    if it.core == 'qb-core' then
        if Player.PlayerData.gang and Player.PlayerData.gang.name then
            return Player.PlayerData.gang.name
        end
    elseif it.core == 'esx' then
        -- Para ESX, pode ser necessário adaptar conforme seu sistema de gangs
        -- Por enquanto, retornamos nil
    end
    
    return nil
end

-- Função para obter todas as gangs disponíveis (usando mesma abordagem do space_economy)
local function getAllGangs()
    local gangs = {}
    
    if it.core == 'qb-core' then
        -- Tentar buscar de QBCore.Shared.Gangs primeiro
        local success1, result1 = pcall(function()
            if QBCore and QBCore.Shared and QBCore.Shared.Gangs then
                return QBCore.Shared.Gangs
            end
            return nil
        end)
        
        if success1 and result1 and next(result1) ~= nil then
            for gangName, gangData in pairs(result1) do
                table.insert(gangs, {
                    name = gangName,
                    label = gangData.label or gangName
                })
            end
            return gangs
        end
        
        -- Tentar buscar de exports.qbx_core.Shared.Gangs
        local success2, result2 = pcall(function()
            local QBX = exports.qbx_core
            if QBX and QBX.Shared and QBX.Shared.Gangs then
                return QBX.Shared.Gangs
            end
            return nil
        end)
        
        if success2 and result2 and next(result2) ~= nil then
            for gangName, gangData in pairs(result2) do
                table.insert(gangs, {
                    name = gangName,
                    label = gangData.label or gangName
                })
            end
            return gangs
        end
        
        -- Tentar buscar de exports.qbx_core:GetGangs() se disponível
        local success3, result3 = pcall(function()
            if exports.qbx_core and exports.qbx_core.GetGangs then
                return exports.qbx_core:GetGangs()
            end
            return nil
        end)
        
        if success3 and result3 and next(result3) ~= nil then
            for gangName, gangData in pairs(result3) do
                table.insert(gangs, {
                    name = gangName,
                    label = gangData.label or gangName
                })
            end
            return gangs
        end
        
        -- Fallback: buscar de players online
        local players = it.getPlayers()
        local gangSet = {}
        
        for _, playerId in pairs(players) do
            local Player = it.getPlayer(playerId)
            if Player and Player.PlayerData and Player.PlayerData.gang and Player.PlayerData.gang.name then
                local gangName = Player.PlayerData.gang.name
                if not gangSet[gangName] then
                    gangSet[gangName] = true
                    table.insert(gangs, {
                        name = gangName,
                        label = Player.PlayerData.gang.label or gangName
                    })
                end
            end
        end
    elseif it.core == 'esx' then
        -- Para ESX, adaptar conforme necessário
    end
    
    return gangs
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

-- Carregar zonas do banco de dados
local function loadZones()
    local zones = MySQL.query.await('SELECT * FROM it_drug_zones')
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
            
            if zone.drugs then
                local success, decoded = pcall(json.decode, zone.drugs)
                if success then
                    zone.drugs = decoded
                else
                    zone.drugs = {}
                end
            else
                zone.drugs = {}
            end

            if zone.color then
                local success, decoded = pcall(json.decode, zone.color)
                if success then
                    zone.color = decoded
                end
            end
            
            drugZones[zone.zone_id] = zone
        end
    end
    
    -- Carregar mesas (limpar primeiro para evitar duplicatas)
    drugTables = {}
    local tables = MySQL.query.await('SELECT * FROM it_drug_tables')
    if tables then
        for _, tableData in ipairs(tables) do
            if not drugTables[tableData.zone_id] then
                drugTables[tableData.zone_id] = {}
            end
            
            local success, coords = pcall(json.decode, tableData.coords)
            if success then
                tableData.coords = coords
            end
            
            table.insert(drugTables[tableData.zone_id], tableData)
        end
    end
    
    -- Notificar todos os clientes para atualizar as zonas
    TriggerClientEvent('it-drugs:client:zonesUpdated', -1, drugZones, drugTables)
end

-- Inicializar ao iniciar o script
CreateThread(function()
    Wait(1000) -- Aguardar o MySQL estar pronto
    
    -- Auto-Migration: Check for 'color' column in it_drug_zones
    MySQL.query('SHOW COLUMNS FROM it_drug_zones LIKE "color"', {}, function(result)
        if not result or #result == 0 then
            print('^3[IT-DRUGS DATABASE] Adding missing "color" column to it_drug_zones...^7')
            MySQL.query('ALTER TABLE it_drug_zones ADD COLUMN color VARCHAR(20) DEFAULT NULL COMMENT "Hex Color #RRGGBB"', {}, function(alterResult)
                print('^2[IT-DRUGS DATABASE] Column "color" added successfully to it_drug_zones!^7')
                checkGangZones()
            end)
        else
            checkGangZones()
        end
    end)
end)

function checkGangZones()
    MySQL.query('SHOW COLUMNS FROM it_gang_zones LIKE "color"', {}, function(result)
        if not result or #result == 0 then
            print('^3[IT-DRUGS DATABASE] Adding missing "color" column to it_gang_zones...^7')
            MySQL.query('ALTER TABLE it_gang_zones ADD COLUMN color VARCHAR(20) DEFAULT NULL COMMENT "Hex Color #RRGGBB"', {}, function(alterResult)
                print('^2[IT-DRUGS DATABASE] Column "color" added successfully to it_gang_zones!^7')
                loadZones()
            end)
        else
            loadZones()
        end
    end)
end

-- Comando /drugzone
RegisterCommand('drugzone', function(source, args, rawCommand)
    local src = source
    
    -- Verificar se é admin ou tem gang
    local playerGang = getPlayerGang(src)
    local playerIsAdmin = it.isAdmin(src)
    
    if not playerIsAdmin and not playerGang then
        ShowNotification(src, 'Você não tem permissão para usar este comando. Precisa ser admin ou ter um grupo/gang.', 'error')
        return
    end
    
    -- Abrir painel de gerenciamento
    TriggerClientEvent('it-drugs:client:openZoneMenu', src)
    exports['it-drugs']:syncWarRequests(src)
end, false)

-- Evento para solicitar criação de zona
RegisterNetEvent('it-drugs:server:requestZoneCreation', function()
    local src = source
    local playerIsAdmin = it.isAdmin(src)
    
    -- Apenas admins podem criar zonas
    if not playerIsAdmin then
        ShowNotification(src, 'Você não tem permissão para criar zonas. Apenas administradores podem criar.', 'error')
        return
    end
    
    -- Enviar evento para o cliente iniciar a criação da zona
    -- Admins podem escolher qualquer grupo
    TriggerClientEvent('it-drugs:client:startZoneCreation', src, {
        isAdmin = true,
        gangName = nil, -- Admins podem escolher qualquer gang
        canChooseAnyGang = true -- Admins podem escolher qualquer grupo
    })
end)

-- Callback para obter último zoneId criado
lib.callback.register('it-drugs:server:getLastCreatedZoneId', function(source)
    -- Retornar o último zoneId criado (será implementado com variável global)
    return lastCreatedZoneId
end)

-- Callback para obter todas as gangs disponíveis
lib.callback.register('it-drugs:server:getAllGangs', function(source)
    return getAllGangs()
end)

-- Evento para salvar zona criada
RegisterNetEvent('it-drugs:server:saveZone', function(zoneData)
    local src = source
    print('[DEBUG] saveZone received from '..src)
    
    local Player = it.getPlayer(src)
    if not Player then return end
    
    local playerIsAdmin = it.isAdmin(src)
    print('[DEBUG] isAdmin: '..tostring(playerIsAdmin))
    
    -- Apenas admins podem criar zonas
    if not playerIsAdmin then
        ShowNotification(src, 'Você não tem permissão para criar zonas. Apenas administradores podem criar.', 'error')
        return
    end
    
    -- Admins podem criar zonas para qualquer grupo (sem restrições)
    
    -- Converter string vazia para nil
    if zoneData.gangName == '' then
        zoneData.gangName = nil
    end
    
    local citizenId = it.getCitizenId(src)
    if not citizenId then
        ShowNotification(src, 'Erro ao obter CitizenID.', 'error')
        return
    end
    
    -- Gerar ID único para a zona
    local zoneId = zoneData.zoneId or ('drug_zone_' .. citizenId .. '_' .. os.time())
    lastCreatedZoneId = zoneId
    
    -- Preparar dados
    local polygonJson = nil
    if zoneData.points and #zoneData.points > 0 then
        polygonJson = json.encode(zoneData.points)
    end
    
    local drugsJson = nil
    if zoneData.drugs and #zoneData.drugs > 0 then
        drugsJson = json.encode(zoneData.drugs)
    else
        -- Usar drogas padrão se não especificadas
        local defaultDrugs = {
            { item = 'cocaine', price = math.random(100, 200)},
            { item = 'joint', price = math.random(50, 100)},
            { item = 'weed_lemonhaze', price = math.random(50, 100)}
        }
        drugsJson = json.encode(defaultDrugs)
    end
    
    -- Verificar se a zona já existe
    local exists = MySQL.scalar.await('SELECT COUNT(*) FROM it_drug_zones WHERE zone_id = ?', { zoneId })
    
    if exists > 0 then
        -- Atualizar zona existente
        MySQL.update.await('UPDATE it_drug_zones SET label = ?, gang_name = ?, color = ?, owner_cid = ?, polygon_points = ?, thickness = ?, drugs = ? WHERE zone_id = ?', {
            zoneData.label or 'Zona de Drogas',
            zoneData.gangName or nil,
            zoneData.color or nil, -- Saving color
            citizenId,
            polygonJson,
            zoneData.thickness or 10.0,
            drugsJson,
            zoneId
        })
    else
        -- Criar nova zona
        MySQL.insert.await('INSERT INTO it_drug_zones (zone_id, label, gang_name, color, owner_cid, polygon_points, thickness, drugs) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
            zoneId,
            zoneData.label or 'Zona de Drogas',
            zoneData.gangName or nil,
            zoneData.color or nil, -- Saving color
            citizenId,
            polygonJson,
            zoneData.thickness or 10.0,
            drugsJson
        })
    end
    
    -- Recarregar zonas no servidor
    loadZones()
    
    -- Notificar todos os clientes para recarregar IMEDIATAMENTE
    TriggerClientEvent('it-drugs:client:zonesUpdated', -1, drugZones, drugTables)
    
    ShowNotification(src, 'Zona de drogas salva com sucesso!', 'success')
end)

-- Evento para deletar zona
RegisterNetEvent('it-drugs:server:deleteZone', function(zoneId)
    local src = source
    
    local playerGang = getPlayerGang(src)
    local playerIsAdmin = it.isAdmin(src)
    
    if not playerIsAdmin and not playerGang then
        ShowNotification(src, 'Você não tem permissão para deletar zonas.', 'error')
        return
    end
    
    -- Verificar se a zona existe e se o player tem permissão
    local zone = drugZones[zoneId]
    if not zone then
        ShowNotification(src, 'Zona não encontrada.', 'error')
        return
    end
    
    -- Se não for admin, só pode deletar zonas do próprio grupo
    if not playerIsAdmin and zone.gang_name ~= playerGang then
        ShowNotification(src, 'Você só pode deletar zonas do seu próprio grupo.', 'error')
        return
    end
    
    -- Deletar zona (cascade vai deletar as mesas também)
    MySQL.update.await('DELETE FROM it_drug_zones WHERE zone_id = ?', { zoneId })
    
    -- Recarregar zonas no servidor
    loadZones()
    
    -- Notificar todos os clientes para recarregar IMEDIATAMENTE
    TriggerClientEvent('it-drugs:client:zonesUpdated', -1, drugZones, drugTables)
    
    ShowNotification(src, 'Zona deletada com sucesso!', 'success')
end)

-- Evento para salvar mesa de drogas
RegisterNetEvent('it-drugs:server:saveDrugTable', function(tableData)
    local src = source
    
    local playerGang = getPlayerGang(src)
    local playerIsAdmin = it.isAdmin(src)
    
    if not playerIsAdmin and not playerGang then
        ShowNotification(src, 'Você não tem permissão para criar mesas.', 'error')
        return
    end
    
    -- Verificar se a zona existe
    local zone = drugZones[tableData.zoneId]
    if not zone then
        ShowNotification(src, 'Zona não encontrada.', 'error')
        return
    end
    
    -- Se não for admin, verificar se a zona pertence ao grupo do player
    if not playerIsAdmin and zone.gang_name ~= playerGang then
        ShowNotification(src, 'Você só pode criar mesas em zonas do seu próprio grupo.', 'error')
        return
    end
    
    local coordsJson = json.encode(tableData.coords)
    
    MySQL.insert.await('INSERT INTO it_drug_tables (zone_id, coords, model) VALUES (?, ?, ?)', {
        tableData.zoneId,
        coordsJson,
        tableData.model or 'bkr_prop_weed_table_01a'
    })
    
    -- Recarregar zonas no servidor
    loadZones()
    
    -- Notificar todos os clientes para recarregar
    TriggerClientEvent('it-drugs:client:zonesUpdated', -1, drugZones, drugTables)
    
    ShowNotification(src, 'Mesa de drogas criada com sucesso!', 'success')
end)

-- Evento para deletar mesa
RegisterNetEvent('it-drugs:server:deleteDrugTable', function(tableId)
    local src = source
    
    local playerGang = getPlayerGang(src)
    local playerIsAdmin = it.isAdmin(src)
    
    if not playerIsAdmin and not playerGang then
        ShowNotification(src, 'Você não tem permissão para deletar mesas.', 'error')
        return
    end
    
    -- Buscar a mesa
    local tableData = MySQL.query.await('SELECT * FROM it_drug_tables WHERE table_id = ?', { tableId })
    if not tableData or #tableData == 0 then
        ShowNotification(src, 'Mesa não encontrada.', 'error')
        return
    end
    
    local zone = drugZones[tableData[1].zone_id]
    if not zone then
        ShowNotification(src, 'Zona não encontrada.', 'error')
        return
    end
    
    -- Se não for admin, verificar se a zona pertence ao grupo do player
    if not playerIsAdmin and zone.gang_name ~= playerGang then
        ShowNotification(src, 'Você só pode deletar mesas de zonas do seu próprio grupo.', 'error')
        return
    end
    
    MySQL.update.await('DELETE FROM it_drug_tables WHERE table_id = ?', { tableId })
    
    -- Recarregar zonas no servidor
    loadZones()
    
    -- Notificar todos os clientes para recarregar
    TriggerClientEvent('it-drugs:client:zonesUpdated', -1, drugZones, drugTables)
    
    ShowNotification(src, 'Mesa deletada com sucesso!', 'success')
end)

-- Evento para atualizar mesa de drogas
RegisterNetEvent('it-drugs:server:updateDrugTable', function(tableData)
    local src = source
    
    local playerGang = getPlayerGang(src)
    local playerIsAdmin = it.isAdmin(src)
    
    if not playerIsAdmin and not playerGang then
        ShowNotification(src, 'Você não tem permissão para editar mesas.', 'error')
        return
    end
    
    -- Buscar a mesa
    local existingTable = MySQL.query.await('SELECT * FROM it_drug_tables WHERE table_id = ?', { tableData.tableId })
    if not existingTable or #existingTable == 0 then
        ShowNotification(src, 'Mesa não encontrada.', 'error')
        return
    end
    
    local zone = drugZones[existingTable[1].zone_id]
    if not zone then
        ShowNotification(src, 'Zona não encontrada.', 'error')
        return
    end
    
    -- Se não for admin, verificar se a zona pertence ao grupo do player
    if not playerIsAdmin and zone.gang_name ~= playerGang then
        ShowNotification(src, 'Você só pode editar mesas de zonas do seu próprio grupo.', 'error')
        return
    end
    
    local coordsJson = json.encode(tableData.coords)
    
    MySQL.update.await('UPDATE it_drug_tables SET coords = ? WHERE table_id = ?', {
        coordsJson,
        tableData.tableId
    })
    
    -- Recarregar zonas no servidor
    loadZones()
    
    -- Notificar todos os clientes para recarregar
    TriggerClientEvent('it-drugs:client:zonesUpdated', -1, drugZones, drugTables)
    
    ShowNotification(src, 'Mesa atualizada com sucesso!', 'success')
end)

-- Evento para atualizar zona
RegisterNetEvent('it-drugs:server:updateZone', function(zoneData)
    local src = source
    
    local playerGang = getPlayerGang(src)
    local playerIsAdmin = it.isAdmin(src)
    
    if not playerIsAdmin and not playerGang then
        ShowNotification(src, 'Você não tem permissão para editar zonas.', 'error')
        return
    end
    
    -- Verificar se a zona existe
    local zone = drugZones[zoneData.zoneId]
    if not zone then
        ShowNotification(src, 'Zona não encontrada.', 'error')
        return
    end
    
    -- Se não for admin, verificar se a zona pertence ao grupo do player
    if not playerIsAdmin and zone.gang_name ~= playerGang then
        ShowNotification(src, 'Você só pode editar zonas do seu próprio grupo.', 'error')
        return
    end
    
    -- Preparar dados
    local polygonJson = nil
    if zoneData.points and #zoneData.points > 0 then
        polygonJson = json.encode(zoneData.points)
    end
    
    -- Atualizar zona
    MySQL.update.await('UPDATE it_drug_zones SET label = ?, polygon_points = ?, thickness = ?, color = ? WHERE zone_id = ?', {
        zoneData.label or zone.label,
        polygonJson or zone.polygon_points,
        zoneData.thickness or zone.thickness,
        zoneData.color or zone.color,
        zoneData.zoneId
    })
    
    -- Recarregar zonas
    loadZones()
    
    ShowNotification(src, 'Zona atualizada com sucesso!', 'success')
end)

-- Callback para obter zonas
lib.callback.register('it-drugs:server:getZones', function(source)
    return drugZones, drugTables
end)

-- Export para obter zona por coordenadas
exports('GetDrugZoneByCoords', function(coords)
    if not coords then return nil end
    
    for _, zone in pairs(drugZones) do
        if zone.polygon_points and #zone.polygon_points >= 3 then
            -- Verificar se está dentro do polígono
            local minZ, maxZ = math.huge, -math.huge
            for _, p in ipairs(zone.polygon_points) do
                if p.z < minZ then minZ = p.z end
                if p.z > maxZ then maxZ = p.z end
            end
            
            local thickness = zone.thickness or 10.0
            if coords.z >= minZ and coords.z <= (maxZ + thickness) then
                -- Verificar se está dentro do polígono (implementação simplificada)
                -- Você pode usar uma biblioteca de polígonos mais robusta se necessário
                local inside = false
                local j = #zone.polygon_points
                for i = 1, #zone.polygon_points do
                    local pi = zone.polygon_points[i]
                    local pj = zone.polygon_points[j]
                    if ((pi.y > coords.y) ~= (pj.y > coords.y)) and (coords.x < (pj.x - pi.x) * (coords.y - pi.y) / (pj.y - pi.y) + pi.x) then
                        inside = not inside
                    end
                    j = i
                end
                
                if inside then
                    return zone
                end
            end
        end
    end
    
    return nil
end)


RegisterNetEvent('it-drugs:server:updateZoneColor', function(data)
    local src = source
    local zoneId = data.zoneId
    local color = data.color
    local colorJson = json.encode(color)
    
    local playerGang = getPlayerGang(src)
    local playerIsAdmin = it.isAdmin(src)
    
    if not playerIsAdmin then
        ShowNotification(src, 'Você não tem permissão para editar cores de zonas.', 'error')
        return
    end
    
    -- Check if it's a DRUG ZONE
    local drugZone = drugZones[zoneId]
    if drugZone then
        if drugZone.gang_name and drugZone.gang_name ~= '' then
            -- Update ALL drug zones belonging to this gang
            MySQL.update.await('UPDATE it_drug_zones SET color = ? WHERE gang_name = ?', {
                colorJson,
                drugZone.gang_name
            })
            
            -- Update cache for all matching zones
            for id, z in pairs(drugZones) do
                if z.gang_name == drugZone.gang_name then
                    z.color = color -- Store as object
                end
            end
            ShowNotification(src, 'Cor da gangue ' .. drugZone.gang_name .. ' (Drogas) atualizada!', 'success')
        else
            -- Update only this zone (Public or no-gang zone)
            MySQL.update.await('UPDATE it_drug_zones SET color = ? WHERE zone_id = ?', {
                colorJson,
                zoneId
            })
            
            drugZones[zoneId].color = color
            ShowNotification(src, 'Cor da zona de drogas atualizada!', 'success')
        end
        
        loadZones() -- Sync Drug Zones
        return
    end

    -- Check if it's a GANG ZONE (Territory)
    -- gangZones is expected to be global from sv_gangs.lua
    if gangZones and gangZones[zoneId] then
        local gangZone = gangZones[zoneId]
        
        if gangZone.owner_gang and gangZone.owner_gang ~= 'none' then
            -- Update ALL gang zones belonging to this gang in DB
            MySQL.update.await('UPDATE it_gang_zones SET color = ? WHERE owner_gang = ?', {
                colorJson,
                gangZone.owner_gang
            })
            
            -- Update global cache
            for id, z in pairs(gangZones) do
                if z.owner_gang == gangZone.owner_gang then
                    z.color = color -- Store as object/struct
                end
            end
            
            -- Sync existing clients
            TriggerClientEvent('it-drugs:client:updateGangZones', -1, gangZones)
            ShowNotification(src, 'Cor da gangue ' .. gangZone.owner_gang .. ' (Território) atualizada!', 'success')
        else
           -- If for some reason it has no owner or is 'none'
            MySQL.update.await('UPDATE it_gang_zones SET color = ? WHERE zone_id = ?', {
               colorJson,
               zoneId
            })
            gangZones[zoneId].color = color
            TriggerClientEvent('it-drugs:client:updateGangZones', -1, gangZones)
            ShowNotification(src, 'Cor do território atualizada!', 'success')
        end
        return
    end

    ShowNotification(src, 'Zona não encontrada (nem Droga nem Território).', 'error')
end)

RegisterNetEvent('it-drugs:server:giveUpgradeItem', function(zoneId, upgradeUniqueId, type, model)
    local src = source
    print(string.format('^3[IT-DRUGS DEBUG] Server giveUpgradeItem. Source: %s | Model: %s^7', src, tostring(model)))
    
    local Player = it.getPlayer(src)
    if not Player then return end
    
    -- Mapeamento de modelo para item (Hardcoded ou busca na Config)
    local item = nil
    
    -- Tentar encontrar pelo modelo na config
    for k, v in pairs(Config.ZoneUpgrades) do
        if v.model == model then
            item = v.item or k -- Use 'item' field OR the key config name
            print('^3[IT-DRUGS DEBUG] Found mapped item: ' .. tostring(item) .. '^7')
            break
        end
    end
    
    if not item then
        -- Fallback manual (Corrigido para usar os nomes de itens válidos do Config.ProcessingTables)
        if model == 'bkr_prop_weed_table_01a' then item = 'weed_processing_table'
        elseif model == 'bkr_prop_coke_table01a' then item = 'cocaine_processing_table'
        end
        print('^3[IT-DRUGS DEBUG] Used fallback item: ' .. tostring(item) .. '^7')
    end

    if not item then
        ShowNotification(src, 'Erro: Item não configurado para este modelo ('..tostring(model)..').', 'error')
        print('^1[IT-DRUGS DEBUG] ERROR: No item found for model ' .. tostring(model) .. '^7')
        return
    end
    
    -- Dar item ao jogador
    local success = it.giveItem(src, item, 1)
    print(string.format('^3[IT-DRUGS DEBUG] Give Item Result: %s^7', tostring(success)))
    
    if success then
        ShowNotification(src, 'Você recebeu '..item..' no inventário.', 'success')
    else
        ShowNotification(src, 'Erro ao adicionar item ao inventário (Cheio ou Inválido?).', 'error')
    end
end)
