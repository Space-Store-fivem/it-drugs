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
        end
    end
end

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
        isBoss = data.isBoss
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
