local lastNuiState = nil
local lastNuiUpdate = 0
local activeWars = {}
local spawnedPeds = {} 
local ctfProps = {} -- Tracks spawned flag props { prop, currentModel }
local isInsideWar = false
local currentWarId = nil
local GangColors = {} -- Local cache for War script

-- Utility: Get gang color from config or default
local function getGangColor(gangName)
    if GangColors[gangName] then return GangColors[gangName] end
    
    -- Fallbacks
    if gangName == 'ballas' then return {138, 43, 226} end -- Purple
    if gangName == 'vagos' then return {255, 215, 0} end -- Gold
    if gangName == 'families' then return {0, 128, 0} end -- Green
    if gangName == 'marabunta' then return {0, 0, 255} end -- Blue
    return {128, 128, 128} -- Grey
end

RegisterNetEvent('it-drugs:client:syncGangColors', function(colors)
    GangColors = colors
end)
CreateThread(function() TriggerServerEvent('it-drugs:server:requestGangColors') end)

-- Interpolate Color
local function lerpColor(c1, c2, t)
    return {
        math.floor(c1[1] + (c2[1] - c1[1]) * t),
        math.floor(c1[2] + (c2[2] - c1[2]) * t),
        math.floor(c1[3] + (c2[3] - c1[3]) * t)
    }
end

-- Helper: Ray Casting Algorithm for Point in Polygon
local function isPointInPolygon(point, polygon)
    local x, y = point.x, point.y
    local inside = false
    local j = #polygon
    for i = 1, #polygon do
        local xi, yi = polygon[i].x, polygon[i].y
        local xj, yj = polygon[j].x, polygon[j].y
        
        local intersect = ((yi > y) ~= (yj > y)) and 
            (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
        if intersect then inside = not inside end
        j = i
    end
    return inside
end

-- Debug Command (Client-Side Report + Server Request)
RegisterCommand('debugctf', function()
    local gang = it.getPlayerGang()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    
    print('^2[DEBUG-CLIENT] --- CTF DIAGNOSTIC ---^7')
    print('^2[DEBUG-CLIENT] Player:^7', GetPlayerName(PlayerId()), 'ID:', GetPlayerServerId(PlayerId()))
    print('^2[DEBUG-CLIENT] Gang Data:^7', json.encode(gang))
    print('^2[DEBUG-CLIENT] Coords:^7', coords)
    
    local foundZone = false
    for zoneId, war in pairs(activeWars) do
        foundZone = true
        local zone = gangZones[zoneId]
        if zone and zone.flag_point then
            local flagPos = vector3(zone.flag_point.x, zone.flag_point.y, zone.flag_point.z)
            local dist = #(coords - flagPos)
            local dist2d = #(vector3(coords.x, coords.y, 0) - vector3(flagPos.x, flagPos.y, 0))
            
            print(string.format('^3[DEBUG-CLIENT] War %s | Flag Dist: %.2fm (3D) | %.2fm (2D)^7', zoneId, dist, dist2d))
            print(string.format('^3[DEBUG-CLIENT] In Poly? %s | Fallback Dist < 50m? %s^7', 
                zone.polygon_points and tostring(isPointInPolygon(coords, zone.polygon_points)) or "NoPoly",
                tostring(dist < 50.0)
            ))
            
            -- Request Server Perspective
            TriggerServerEvent('it-drugs:server:diagWar', zoneId, coords)
        end
    end
    
    if not foundZone then
        print('^1[DEBUG-CLIENT] No Active Wars found on Client.^7')
    end
end)

RegisterNetEvent('it-drugs:client:diagResult', function(msg)
    print('^5[DEBUG-SERVER-RESPONSE]^7 ' .. msg)
end)

RegisterNetEvent('it-drugs:client:warStarted', function(data)
    activeWars[data.zoneId] = data
    data.captureProgress = -100 -- Init
    
    lib.notify({
        title = 'GUERRA INICIADA',
        description = string.format('Disputa entre %s e %s!', data.attacker, data.defender),
        type = 'info',
        duration = 10000
    })
    
    SendNUIMessage({ action = 'warUpdate', wars = activeWars })
end)

RegisterNetEvent('it-drugs:client:updateWarStatus', function(data)
    if activeWars[data.zoneId] then
        activeWars[data.zoneId].captureProgress = data.progress
        activeWars[data.zoneId].captureStatus = data.status
        activeWars[data.zoneId].attackerCount = data.attackerCount
        activeWars[data.zoneId].defenderCount = data.defenderCount
        
        SendNUIMessage({ action = 'warUpdate', wars = activeWars })
    end
end)

RegisterNetEvent('it-drugs:client:warEnded', function(data)
    activeWars[data.zoneId] = nil
    
    -- Cleanup Prop
    if ctfProps[data.zoneId] then
        if DoesEntityExist(ctfProps[data.zoneId].prop) then
            DeleteEntity(ctfProps[data.zoneId].prop)
        end
        ctfProps[data.zoneId] = nil
    end

    lib.notify({
        title = 'GUERRA FINALIZADA',
        description = string.format('Vencedor: %s', data.winner),
        type = 'success'
    })
    
    SendNUIMessage({ action = 'warUpdate', wars = activeWars })
    SendNUIMessage({ action = 'captureUpdate', state = { active = false } })
end)

local function spawnWarNPCs(zoneId)
    -- Lógica alterada: Em vez de spawnar, recrutamos os guardas existentes (cl_gangs.lua)
    -- Usando FindFirstPed para evitar crash com wrappers bugados de GetGamePool
    
    local handle, ped = FindFirstPed()
    local success
    local count = 0
    
    repeat
        if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
            -- Verificar se é um guarda desta zona (State Bags)
            if Entity(ped).state.warZoneId == zoneId then
                -- Evitar duplicados na lista
                local alreadyTracked = false
                for _, t in ipairs(spawnedPeds) do 
                    if t.ped == ped then 
                        alreadyTracked = true 
                        break 
                    end 
                end
                
                if not alreadyTracked then
                    table.insert(spawnedPeds, { ped = ped, zoneId = zoneId })
                    count = count + 1
                    
                    -- Reforçar agressividade na guerra
                    SetPedCombatAttributes(ped, 46, true) -- FIGHT_TO_DEATH
                    SetPedCombatRange(ped, 2) -- FAR
                end
            end
        end
        
        success, ped = FindNextPed(handle)
    until not success
    
    EndFindPed(handle)
    
    print('^2[IT-DRUGS WAR] Recrutados '..count..' guardas para a guerra na zona '..zoneId..'^7')
end

-- Thread to monitor NPC deaths and check for clearance
CreateThread(function()
    while true do
        Wait(1000)
        local hasWars = false
        for _,_ in pairs(activeWars) do hasWars = true break end

        if hasWars and #spawnedPeds > 0 then
            for i = #spawnedPeds, 1, -1 do
                local data = spawnedPeds[i]
                local ped = data.ped
                local zoneId = data.zoneId
                
                local isDead = false
                local exists = DoesEntityExist(ped)
                
                if not exists then 
                    isDead = true 
                elseif IsEntityDead(ped) then 
                    isDead = true 
                end
                
                if isDead then
                    if exists then SetEntityAsNoLongerNeeded(ped) end
                    table.remove(spawnedPeds, i)
                    
                    -- Victory Condition: Check if ANY defenders for this zone remain
                    local defendersLeft = 0
                    for _, remaining in ipairs(spawnedPeds) do
                        if remaining.zoneId == zoneId then
                            defendersLeft = defendersLeft + 1
                        end
                    end
                    
                    if defendersLeft == 0 then
                        if activeWars[zoneId] then
                             print('[IT-DRUGS] Todos os defensores da zona '..zoneId..' eliminados! Enviando vitória...')
                             local winner = activeWars[zoneId].attacker 
                             TriggerServerEvent('it-drugs:server:forceEndWar', zoneId, winner)
                        end
                    end
                elseif exists then -- NPC Alive Check logic for position
                     -- State Bags might be lost if we rely purely on entity, but we have zoneId in 'data'
                    local zone = gangZones[zoneId]
                    
                    if zone and zone.polygon_points then
                        local pedCoords = GetEntityCoords(ped)
                        local isInside = isPointInPolygon(pedCoords, zone.polygon_points)
                        local isReturning = Entity(ped).state.isReturning
                        
                        if not isInside and not isReturning then
                             -- Outside: Force Run to Flag
                             local flag = zone.flag_point or zone.polygon_points[1] -- Fallback
                             if flag then
                                 ClearPedTasks(ped)
                                 TaskGoToCoordAnyMeans(ped, flag.x, flag.y, flag.z, 2.0, 0, 0, 786603, 0)
                                 Entity(ped).state:set('isReturning', true, true)
                             end
                        elseif isInside and isReturning then
                             -- Back Inside: Resume Wander
                             local flag = zone.flag_point or zone.polygon_points[1]
                             if flag then
                                 ClearPedTasks(ped)
                                 TaskWanderInArea(ped, flag.x, flag.y, flag.z, 10.0, 10.0, 10.0) 
                                 Entity(ped).state:set('isReturning', false, true)
                             end
                        end
                    end
                end
            end
        end
    end
end)

-- Thread to clean up TextUI and props on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        SendNUIMessage({ action = 'captureUpdate', state = { active = false } })
        for _, data in pairs(ctfProps) do
            if DoesEntityExist(data.prop) then DeleteEntity(data.prop) end
        end
        for _, ped in ipairs(spawnedPeds) do
            if DoesEntityExist(ped) then DeleteEntity(ped) end
        end
    end
end)

-- Main Render Loop for CTF Visuals & Logic
-- Main Render Loop for CTF Visuals & Logic
CreateThread(function()
    while true do
        local sleep = 1000
        
        -- Optimization: Only run if there are active wars
        local hasWars = false
        for _, _ in pairs(activeWars) do hasWars = true break end

        if hasWars then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            
            local closestWar = nil
            local closestDist = 99999.0
            local closestZoneId = nil
            local nearAnyWar = false
            
            -- Pass 1: Visuals & Calc Closest
            for zoneId, war in pairs(activeWars) do
                local zone = gangZones[zoneId]
                if zone and zone.flag_point then
                    local flagPos = vector3(zone.flag_point.x, zone.flag_point.y, zone.flag_point.z)
                    local dist = #(coords - flagPos)
                    
                    if dist < 100.0 then
                        sleep = 0
                        nearAnyWar = true
                        
                        -- Tracking Closest for NUI
                        if dist < closestDist then
                            closestDist = dist
                            closestWar = war
                            closestZoneId = zoneId
                        end
                        
                        -- Spawn NPCs if not spawned
                        spawnWarNPCs(zoneId)
                        
                        -- CTF Visuals
                        -- 1. Manage Flag Prop
                        local desiredModel = `ctfblueflag`
                        if war.captureProgress > 0 then desiredModel = `ctfredflag` end
                        
                        if not ctfProps[zoneId] or not DoesEntityExist(ctfProps[zoneId].prop) then
                            RequestModel(`ctfblueflag`)
                            RequestModel(`ctfredflag`)
                            if HasModelLoaded(desiredModel) then
                                local zFloor = GetGroundZFor_3dCoord(flagPos.x, flagPos.y, flagPos.z, 0)
                                local prop = CreateObject(desiredModel, flagPos.x, flagPos.y, flagPos.z, false, false, false)
                                FreezeEntityPosition(prop, true)
                                SetEntityHeading(prop, 0.0)
                                ctfProps[zoneId] = { prop = prop, model = desiredModel }
                            end
                        elseif ctfProps[zoneId].model ~= desiredModel then
                            DeleteEntity(ctfProps[zoneId].prop)
                            ctfProps[zoneId] = nil 
                        end
                        
                        -- 2. Calculate Color
                        local color = {128, 128, 128} 
                        local defenderColor = getGangColor(war.defender)
                        local attackerColor = getGangColor(war.attacker)
                        
                        if war.captureProgress < 0 then
                            local t = (war.captureProgress + 100) / 100
                            color = lerpColor(defenderColor, {128, 128, 128}, t)
                        else
                            local t = war.captureProgress / 100
                            color = lerpColor({128, 128, 128}, attackerColor, t)
                        end
                        
                        -- 3. Draw Radius Marker & Wall (Polygon Based)
                        local serverTime = GetCloudTimeAsInt()
                        local startTime = war.startTime or (serverTime - 999) 
                        local elapsed = serverTime - startTime
                        
                        -- Ground Marker (Flat) at Flag
                        DrawMarker(27, flagPos.x, flagPos.y, flagPos.z + 0.03, 
                            0.0, 0.0, 0.0, 
                            0.0, 0.0, 0.0, 
                            7.0, 7.0, 1.0, 
                            color[1], color[2], color[3], 200, 
                            false, false, 2, false, nil, nil, false
                        )

                        -- Polygon Wall Logic
                        if zone.polygon_points then
                             local wallHeight = 30.0
                             local baseZ = flagPos.z - 10.0
                             local topZ = baseZ + wallHeight
                             
                             -- Draw Wall Visuals
                             if elapsed > 0 then
                                for i = 1, #zone.polygon_points do
                                    local p1 = zone.polygon_points[i]
                                    local p2 = zone.polygon_points[(i % #zone.polygon_points) + 1] -- Wrap
                                    
                                    local v1 = vector3(p1.x, p1.y, baseZ)
                                    local v2 = vector3(p1.x, p1.y, topZ)
                                    local v3 = vector3(p2.x, p2.y, baseZ)
                                    local v4 = vector3(p2.x, p2.y, topZ)
                                    
                                    -- Draw both sides for visibility
                                    DrawPoly(v1.x, v1.y, v1.z, v2.x, v2.y, v2.z, v3.x, v3.y, v3.z, color[1], color[2], color[3], 30)
                                    DrawPoly(v3.x, v3.y, v3.z, v2.x, v2.y, v2.z, v4.x, v4.y, v4.z, color[1], color[2], color[3], 30)
                                    DrawPoly(v3.x, v3.y, v3.z, v2.x, v2.y, v2.z, v1.x, v1.y, v1.z, color[1], color[2], color[3], 30)
                                    DrawPoly(v4.x, v4.y, v4.z, v2.x, v2.y, v2.z, v3.x, v3.y, v3.z, color[1], color[2], color[3], 30)
                                    
                                    -- Add bright lines at bottom/top for definition
                                    DrawLine(p1.x, p1.y, baseZ, p2.x, p2.y, baseZ, color[1], color[2], color[3], 200)
                                    DrawLine(p1.x, p1.y, topZ, p2.x, p2.y, topZ, color[1], color[2], color[3], 200)
                                    DrawLine(p1.x, p1.y, baseZ, p1.x, p1.y, topZ, color[1], color[2], color[3], 200)
                                end
                             end
                             
                             -- Lock & Feedback Logic
                             local isInside = isPointInPolygon(coords, zone.polygon_points)
                             
                             if elapsed < 20 then
                                -- Phase 1: Preparation Warning
                                if not isInside then
                                    local timeLeft = math.ceil(20 - elapsed)
                                    SendNUIMessage({
                                        action = "warAlert",
                                        alert = {
                                            type = "warning",
                                            message = "SAINDO DA ZONA DE CONFLITO",
                                            subMessage = "Retorne em " .. timeLeft .. "s"
                                        }
                                    })
                                else
                                    SendNUIMessage({ action = "warAlert", alert = nil })
                                end
                             else
                                -- Phase 2: Active War (Lock & Exclusion)
                                if not isInside then
                                    -- 1. Push Back Logic
                                    -- Check if player is trying to leave (Distance > Radius)
                                    -- Using polygon center approx or flag pos for push direction
                                    local dir = flagPos - coords
                                    local len = #(dir)
                                    local vec = (dir / len) * 3.0 
                                    ApplyForceToEntity(ped, 1, vec.x, vec.y, vec.z, 0.0, 0.0, 0.0, 0, false, false, true, false, true)
                                    
                                    -- 2. Exclusion Warning (Simulated 5s)
                                    if not zone.outStart then zone.outStart = GetGameTimer() end
                                    local outTime = (GetGameTimer() - zone.outStart) / 1000
                                    local remain = math.max(0, math.ceil(5 - outTime))
                                    
                                    SendNUIMessage({
                                        action = "warAlert",
                                        alert = {
                                            type = "error",
                                            message = "DESERÇÃO EMINENTE",
                                            subMessage = "Exclusão em " .. remain .. "s"
                                        }
                                    })
                                else
                                    zone.outStart = nil
                                    SendNUIMessage({ action = "warAlert", alert = nil })
                                end
                             end
                        end
                        
                        -- 4. Draw Status Text 3D
                        local statusText = "NEUTRO"
                        if war.captureStatus == 'CONTESTED' then statusText = "~r~PAUSADO (CONTESTADO)"
                        elseif war.captureStatus == 'CAPTURING' then statusText = "~g~CAPTURANDO >>>"
                        elseif war.captureStatus == 'DECAYING' then statusText = "~y~REVERTENDO <<<"
                        end
                        
                        local percent = math.abs(war.captureProgress) 
                        if percent > 100 then percent = 100 end
                        local ownerLabel = (war.captureProgress < 0) and war.defender or war.attacker
                        
                        DrawText3D(flagPos.x, flagPos.y, flagPos.z + 2.5, string.format("%s\n~w~Dominância: %.0f%%\n%s", statusText, percent, ownerLabel))
                        
                    else
                         -- Despawn if far
                         if ctfProps[zoneId] then
                            if DoesEntityExist(ctfProps[zoneId].prop) then DeleteEntity(ctfProps[zoneId].prop) end
                            ctfProps[zoneId] = nil
                         end
                    end
                end
            end
            
            -- 5. NUI Progress Logic (Global for Participants, Local for Observers)
            local shouldShowNui = false
            
            -- Check if player is part of the war
            local playerGang = it.getPlayerGang()
            local participatingWar = nil
            
            if playerGang and playerGang.name ~= 'none' then
                local pName = string.lower(playerGang.name)
                for zoneId, war in pairs(activeWars) do
                    local att = string.lower(war.attacker or "")
                    local def = string.lower(war.defender or "")
                    
                    if att == pName or def == pName then
                        participatingWar = war
                        closestZoneId = zoneId
                        break
                    end
                end
            end
            
            if participatingWar then
                -- Player IS involved -> Global Visibility
                closestWar = participatingWar
                shouldShowNui = true
            else
                -- Player NOT involved -> Local Visibility (Inside Zone)
                if not closestWar then
                    for zoneId, war in pairs(activeWars) do
                        local zone = gangZones[zoneId]
                        if zone and zone.polygon_points then
                            if isPointInPolygon(coords, zone.polygon_points) then
                                closestWar = war
                                closestZoneId = zoneId
                                shouldShowNui = true
                                break
                            end
                        end
                    end
                else
                     -- already found close war via distance check earlier, verify poly
                     local zone = gangZones[closestZoneId]
                     if zone and zone.polygon_points and isPointInPolygon(coords, zone.polygon_points) then
                        shouldShowNui = true
                     end
                     if closestDist < 50.0 then shouldShowNui = true end -- Safety fallback
                end
            end

            if shouldShowNui and closestWar then
                    -- Time-based throttling (200ms) to prevent flickering
                    if GetGameTimer() - lastNuiUpdate > 200 then
                        SendNUIMessage({
                            action = 'captureUpdate',
                            state = {
                                active = true,
                                zoneId = closestZoneId,
                                progress = closestWar.captureProgress or 0,
                                status = closestWar.captureStatus or 'NEUTRAL',
                                attacker = closestWar.attacker,
                                defender = closestWar.defender,
                                attackerCount = closestWar.attackerCount or 0,
                                defenderCount = closestWar.defenderCount or 0
                            }
                        })
                        lastNuiUpdate = GetGameTimer()
                    end
                    isInsideWar = true
                end

            
            -- Explicit Hide if not valid
            if not shouldShowNui and isInsideWar then
                SendNUIMessage({ action = 'captureUpdate', state = { active = false } })
                isInsideWar = false
                lib.hideTextUI()
            end
            
        else
            -- No active wars at all
            if isInsideWar then
                SendNUIMessage({ action = 'captureUpdate', state = { active = false } })
                isInsideWar = false
                SendNUIMessage({ action = "warAlert", alert = nil })
            end
        end
        
        Wait(sleep)
    end
end)

-- Helper for 3D Text
function DrawText3D(x, y, z, text)
	SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x,y,z, 0)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end
