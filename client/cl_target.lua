if Config.Debug and Config.Target then lib.print.info('Setting up Target System') end

-- Garantir que as variáveis globais existam
if not drugZones then drugZones = {} end
if not currentEditingZone then currentEditingZone = nil end

-- ┌────────────────────────────────────────────────────────┐
-- │ ____  _             _     _____                    _   │
-- │|  _ \| | __ _ _ __ | |_  |_   _|_ _ _ __ __ _  ___| |_ │
-- │| |_) | |/ _` | '_ \| __|   | |/ _` | '__/ _` |/ _ \ __|│
-- │|  __/| | (_| | | | | |_    | | (_| | | | (_| |  __/ |_ │
-- │|_|   |_|\__,_|_| |_|\__|   |_|\__,_|_|  \__, |\___|\__|│
-- │                                         |___/          │
-- └────────────────────────────────────────────────────────┘
-- Plant Target
CreateThread(function()
    if Config.Target == 'qb-target' then
        if Config.Debug then lib.print.info(_U('DEBUG__DETECTED_TARGET_SYSTEM'):format('qb-target')) end -- DEBUG

        if not exports['qb-target'] then
            if Config.Debug then lib.print.info(_U('DEBUG__TARGET_SYSTEM_STATUS'):format('false')) end -- DEBUG
        else
            if Config.Debug then lib.print.info(_U('DEBUG__TARGET_SYSTEM_STATUS'):format('true')) end -- DEBUG
        end
        -- Check if qb-target is running
        if not exports['qb-target'] then return end
        for k, v in pairs(Config.PlantTypes) do
            for _, plant in pairs(v) do
                exports['qb-target']:AddTargetModel(plant[1], {
                    options = {
                        {
                            label = _U('TARGET__PLANT__LABEL'),
                            icon = 'fas fa-eye',
                            action = function (entity)
                                TriggerEvent('it-drugs:client:checkPlant', {entity = entity})
                            end
                        }
                    },
                    distance = 1.5,
                })
            end
        end
        if Config.Debug then lib.print.info(_U('DEBUG__REGISTERED_ALL_PLANTS')) end -- DEBUG
    elseif Config.Target == 'ox_target' then
        if Config.Debug then lib.print.info(_U('DEBUG__DETECTED_TARGET_SYSTEM'):format('ox_target')) end -- DEBUG

        if not exports.ox_target then
            if Config.Debug then lib.print.info(_U('DEBUG__TARGET_SYSTEM_STATUS'):format('false')) end -- DEBUG
        else
            if Config.Debug then lib.print.info(_U('DEBUG__TARGET_SYSTEM_STATUS'):format('true')) end -- DEBUG
        end
        -- Check if ox target is running
        if not exports.ox_target then return end
        for k, v in pairs(Config.PlantTypes) do
            for _, plant in pairs(v) do
                exports.ox_target:addModel(plant[1], {
                    {
                        label = _U('TARGET__PLANT__LABEL'),
                        name = 'it-drugs-check-plant',
                        icon = 'fas fa-eye',
                        onSelect = function(data)
                            TriggerEvent('it-drugs:client:checkPlant', {entity = data.entity})
                        end,
                        distance = 1.5
                    }
                })
            end
        end
    end
    if Config.Debug then lib.print.info(_U('DEBUG__REGISTERED_ALL_PLANTS')) end -- DEBUG
end)


if Config.EnableDealers then
    CreateThread(function()
        if Config.Target == 'qb-target' then
            for k, v in pairs(Config.DrugDealers) do
                if v.ped ~= nil then
                    exports['qb-target']:AddTargetModel(v.ped, {
                        options = {
                            {
                                icon = 'fas fa-eye',
                                label = _U('TARGET__DEALER__LABEL'),
                                action = function (entity)
                                    TriggerEvent('it-drugs:client:showDealerMenu', k)
                                end
                            }
                        },
                        distance = 1.5,
                    })
                end
            end
        elseif Config.Target == 'ox_target' then
            -- Check if ox target is running
            if not exports.ox_target then return end
            for k, v in pairs(Config.DrugDealers) do
                if v.ped ~= nil then
                    exports.ox_target:addModel(v.ped, {
                        {
                            label = _U('TARGET__DEALER__LABEL'),
                            name = 'it-drugs-talk-dealer',
                            icon = 'fas fa-eye',
                            onSelect = function(data)
                                TriggerEvent('it-drugs:client:showDealerMenu', k)
                            end,
                            distance = 1.5
                        }
                    })
                end
            end
        end
    end)
end

-- ┌────────────────────────────────────────────────────────────────────────────────────┐
-- │ ____                                  _               _____                    _   │
-- │|  _ \ _ __ ___   ___ ___ ___  ___ ___(_)_ __   __ _  |_   _|_ _ _ __ __ _  ___| |_ │
-- │| |_) | '__/ _ \ / __/ __/ _ \/ __/ __| | '_ \ / _` |   | |/ _` | '__/ _` |/ _ \ __|│
-- │|  __/| | | (_) | (_| (_|  __/\__ \__ \ | | | | (_| |   | | (_| | | | (_| |  __/ |_ │
-- │|_|   |_|  \___/ \___\___\___||___/___/_|_| |_|\__, |   |_|\__,_|_|  \__, |\___|\__|│
-- │                                               |___/                 |___/          │
-- └────────────────────────────────────────────────────────────────────────────────────┘
-- Proccesing Target
if Config.EnableProcessing then
    CreateThread(function()
        if Config.Target == 'qb-target' then
            for k, v in pairs(Config.ProcessingTables) do
                if v.model ~= nil then
                    exports['qb-target']:AddTargetModel(v.model, {
                        options = {
                            {
                                icon = 'fas fa-eye',
                                label = _U('TARGET__TABLE__LABEL'),
                                action = function (entity)
                                    TriggerEvent('it-drugs:client:useTable', {entity = entity, type = k})
                                end
                            }
                        },
                        distance = 1.5,
                    })
                end
            end
        elseif Config.Target == 'ox_target' then
            -- Check if ox target is running
            if not exports.ox_target then return end
            for k, v in pairs(Config.ProcessingTables) do
                if v.model ~= nil then
                    exports.ox_target:addModel(v.model, {
                        {
                            label = _U('TARGET__TABLE__LABEL'),
                            name = 'it-drugs-use-table',
                            icon = 'fas fa-eye',
                            onSelect = function(data)
                                TriggerEvent('it-drugs:client:useTable', {entity = data.entity})
                            end,
                            distance = 1.5
                        }
                    })
                end
            end
        end
    end)
end

-- ┌─────────────────────────────────────────────────────────────┐
-- │ ____       _ _ _               _____                    _   │
-- │/ ___|  ___| | (_)_ __   __ _  |_   _|_ _ _ __ __ _  ___| |_ │
-- │\___ \ / _ \ | | | '_ \ / _` |   | |/ _` | '__/ _` |/ _ \ __|│
-- │ ___) |  __/ | | | | | | (_| |   | | (_| | | | (_| |  __/ |_ │
-- │|____/ \___|_|_|_|_| |_|\__, |   |_|\__,_|_|  \__, |\___|\__|│
-- │                        |___/                 |___/          │
-- └─────────────────────────────────────────────────────────────┘

local function isPedBlacklisted(ped)
	local model = GetEntityModel(ped)
	for i = 1, #Config.BlacklistPeds do
		if model == GetHashKey(Config.BlacklistPeds[i]) then
			return true
		end
	end
	return false
end

-- Função para verificar se um ped está dentro de uma zona dinâmica
local function isPedInDynamicZone(ped)
    if not ped or not DoesEntityExist(ped) then return false end
    if not drugZones then return false end
    
    local pedCoords = GetEntityCoords(ped)
    
    for zoneId, zone in pairs(drugZones) do
        if zone.polygon_points and #zone.polygon_points >= 3 then
            local x, y, z = pedCoords.x, pedCoords.y, pedCoords.z
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
            
            -- Verificar altura
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
                return true
            end
        end
    end
    
    return false
end

-- Create the selling Targets
CreateSellTarget = function()
    if Config.Target == 'qb-target' then
        if not exports['qb-target'] then 
            return 
        end
        exports['qb-target']:AddGlobalPed({
            options = {
                {
                    label = _U('TARGET__SELL__LABEL'),
                    icon = 'fas fa-comment',
                    action = function(entity)
                        TriggerEvent('it-drugs:client:checkSellOffer', entity)
                    end,
                    canInteract = function(entity)
                        if not IsPedDeadOrDying(entity, false) and not IsPedInAnyVehicle(entity, false) and (GetPedType(entity)~=28) and (not IsPedAPlayer(entity)) and (not isPedBlacklisted(entity)) and not IsPedInAnyVehicle(PlayerPedId(), false) then
                            -- Verificar se está em zona estática ou dinâmica
                            local playerPed = PlayerPedId()
                            local playerCoords = GetEntityCoords(playerPed)
                            
                            -- Se o player está em uma zona dinâmica, permitir interação
                            if currentEditingZone and drugZones and drugZones[currentEditingZone] then
                                return true
                            end
                            
                            -- Verificar se está em zona estática
                            if currentZone then
                                return true
                            end
                            
                            -- Verificar se o NPC está em uma zona dinâmica
                            if isPedInDynamicZone and isPedInDynamicZone(entity) then
                                return true
                            end
                        end
                        return false
                    end,
                }
            },
            distance = 4,
        })

    elseif Config.Target == 'ox_target' then
        -- Check if ox target is running
        if not exports.ox_target then return end
        exports.ox_target:addGlobalPed({
            {
                label = _U('TARGET__SELL__LABEL'),
                name = 'it-drugs-sell',
                icon = 'fas fa-comment',
                onSelect = function(data)
                    TriggerEvent('it-drugs:client:checkSellOffer', data.entity)
                end,
                canInteract = function(entity, _, _, _, _)
                    if not IsPedDeadOrDying(entity, false) and not IsPedInAnyVehicle(entity, false) and (GetPedType(entity)~=28) and (not IsPedAPlayer(entity)) and (not isPedBlacklisted(entity)) and not IsPedInAnyVehicle(PlayerPedId(), false) then
                        -- Verificar se está em zona estática ou dinâmica
                        local playerPed = PlayerPedId()
                        local playerCoords = GetEntityCoords(playerPed)
                        
                        -- Se o player está em uma zona dinâmica, permitir interação com QUALQUER NPC
                        if currentEditingZone and drugZones and drugZones[currentEditingZone] then
                            return true
                        end
                        
                        -- Verificar se está em zona estática
                        if currentZone then
                            return true
                        end
                        
                        -- Verificar se o NPC está em uma zona dinâmica (fallback)
                        if isPedInDynamicZone and isPedInDynamicZone(entity) then
                            return true
                        end
                    end
                    return false
                end,
                distance = 4
            }
        })
    end
end

RemoveSellTarget = function()
    if Config.Target == 'qb-target' then
        if not exports['qb-target'] then return end
        exports['qb-target']:RemoveGlobalPed({_U('TARGET__SELL__LABEL')})
    elseif Config.Target == 'ox_target' then
        -- Check if ox target is running
        if not exports.ox_target then return end
        exports.ox_target:removeGlobalPed('it-drugs-sell')
    end
end

-- Remove all Targets
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if Config.Target == 'qb-target' then
        if not exports['qb-target'] then return end
        for k, v in pairs(Config.PlantTypes) do
            for _, plant in pairs(v) do
                exports['qb-target']:RemoveTargetModel(plant[1])
            end
        end
        for k, v in pairs(Config.ProcessingTables) do
            if v.model ~= nil then
                exports['qb-target']:RemoveTargetModel(v.model)
            end
        end
    elseif Config.Target == 'ox_target' then
        if not exports.ox_target then return end
        for k, v in pairs(Config.PlantTypes) do
            for _, plant in pairs(v) do
                exports.ox_target:removeModel(plant[1], 'it-drugs-check-plant')
            end
        end
        for k, v in pairs(Config.ProcessingTables) do
            if v.model ~= nil then
                exports.ox_target:removeModel(v.model, 'it-drugs-use-table')
            end
        end
    end
    if Config.EnableSelling then
        RemoveSellTarget()
    end
end)