
-- ┌──────────────────────────────────────────────────────────┐
-- │   _   _ _   _ ___    ___ _   _ _____ _____ ____  ____    │
-- │  | \ | | | | |_ _|  |_ _| \ | |_   _| ____|  _ \|  _ \   │
-- │  |  \| | | | || |    | ||  \| | | | |  _| | |_) | |_) |  │
-- │  | |\  | |_| || |    | || |\  | | | | |___|  _ <|  _ <   │
-- │  |_| \_|\___/|___|  |___|_| \_| |_| |_____|_| \_\_| \_\  │
-- │                                                          │
-- └──────────────────────────────────────────────────────────┘

RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    if cb then cb('ok') end
end)

RegisterNUICallback('startCreator', function(data, cb)
    local gangId = data.gangId
    local label = data.label
    local color = data.color -- FASE 1: Recebe cor do React

    SetNuiFocus(false, false)

    -- Iniciar ZoneCreator com os dados recebidos
    if ZoneCreator and ZoneCreator.startCreator then
        ZoneCreator.startCreator({
            thickness = 10.0,
            onCreated = function(zoneData)
                -- Gerar ID único
                local uniqueId = 'drug_zone_' .. GetGameTimer() .. '_' .. math.random(1000, 9999)
                
                local points = {}
                for _, p in ipairs(zoneData.points) do
                    table.insert(points, {x=p.x, y=p.y, z=p.z})
                end
                
                TriggerServerEvent('it-drugs:server:createGangZone', gangId, label, points, color, zoneData.flag)
            end,
            onCanceled = function()
                it.notify("Criação cancelada.")
            end
        })
    else
        print('[IT-DRUGS ERROR] ZoneCreator module not found! Certifique-se de que cl_zone_creator.lua está carregado.')
        it.notify("Erro interno: ZoneCreator não encontrado.", "error")
    end

    if cb then cb('ok') end
end)

RegisterNUICallback('requestWar', function(data, cb)
    local zoneId = data.zoneId
    local reason = data.reason
    TriggerServerEvent('it-drugs:server:requestWar', { zoneId = zoneId, reason = reason })
    if cb then cb('ok') end
end)

RegisterNUICallback('resolveWarRequest', function(data, cb)
    TriggerServerEvent('it-drugs:server:resolveWarRequest', data)
    if cb then cb('ok') end
end)

RegisterNetEvent('it-drugs:client:updateWarRequests', function(requests)
    SendNUIMessage({
        action = 'warRequestsUpdate',
        requests = requests
    })
end)

RegisterNUICallback('editGangFlag', function(data, cb)
    local zoneId = data.zoneId
    SetNuiFocus(false, false)
    
    if ZoneCreator and ZoneCreator.selectPoint then
        ZoneCreator.selectPoint({
            helpText = "Posicione a nova bandeira da zona",
            onSelected = function(point)
                TriggerServerEvent('it-drugs:server:updateGangFlag', zoneId, point)
            end,
            onCanceled = function()
                it.notify("Edição cancelada.")
            end
        })
    else
        it.notify("Erro: ZoneCreator não encontrado.", "error")
    end
    
    if cb then cb('ok') end
end)

RegisterNUICallback('setGangColor', function(data, cb)
    -- data = { r: 255, g: 0, b: 0 }
    TriggerServerEvent('it-drugs:server:setGangColorNUI', data)
    if cb then cb('ok') end
end)

RegisterNUICallback('updateZoneColor', function(data, cb)
    -- data = { zoneId: string, color: {r: number, g: number, b: number} }
     TriggerServerEvent('it-drugs:server:updateZoneColor', data)
    if cb then cb('ok') end
end)
