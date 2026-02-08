local activeWars = {}

-- Helper to get zone data from sv_gangs global
local function getZone(zoneId)
    if gangZones and gangZones[zoneId] then
        return gangZones[zoneId]
    end
    return nil
end

local function updateWarStatus(zoneId, status)
    if not gangZones[zoneId] then return end
    gangZones[zoneId].current_status = status
    TriggerClientEvent('it-drugs:client:updateGangZones', -1, gangZones)
end

-- Helper to get player gang
local function getPlayerGang(src)
    local Player = it.getPlayer(src)
    if not Player then return nil end
    
    if it.core == 'qb-core' then
        if Player.PlayerData.gang and Player.PlayerData.gang.name ~= 'none' then
            return {
                name = Player.PlayerData.gang.name,
                label = Player.PlayerData.gang.label or Player.PlayerData.gang.name,
                grade = Player.PlayerData.gang.grade and Player.PlayerData.gang.grade.level or 0
            }
        end
    elseif it.core == 'esx' then
        -- Handle ESX Job as Gang if needed
        local job = Player.getJob()
        return {
            name = job.name,
            label = job.label,
            grade = job.grade
        }
    end
    
    return nil
end

-- Helper to get gang members online
local function getGangMembers(gangName)
    local members = {}
    if not gangName then return members end
    local players = it.getPlayers()
    for _, playerId in ipairs(players) do
        local gangData = getPlayerGang(playerId)
        if gangData and gangData.name == gangName then
            table.insert(members, playerId)
        end
    end
    return members
end

local function syncWarRequests(src)
    local requests = MySQL.query.await('SELECT * FROM it_war_requests WHERE status IN ("requested", "approved")')
    TriggerClientEvent('it-drugs:client:updateWarRequests', src or -1, requests)
end
exports('syncWarRequests', syncWarRequests)

RegisterNetEvent('it-drugs:server:requestWar', function(data)
    local src = source
    local zoneId = data.zoneId
    local reason = data.reason
    local playerGang = getPlayerGang(src)
    
    if not playerGang or playerGang.name == 'none' then
        return it.notify(src, 'Erro', 'error', 'Você precisa estar em uma gangue!')
    end
    
    local zone = getZone(zoneId)
    if not zone then
        return it.notify(src, 'Erro', 'error', 'Zona inválida.')
    end
    
    if zone.owner_gang == playerGang.name then
        return it.notify(src, 'Erro', 'error', 'Você já domina esta zona.')
    end
    
    -- Check for pending requests
    local pending = MySQL.query.await('SELECT id FROM it_war_requests WHERE zone_id = ? AND status = "requested"', {zoneId})
    if pending and #pending > 0 then
        return it.notify(src, 'Erro', 'error', 'Já existe uma solicitação pendente para esta zona.')
    end

    if activeWars[zoneId] then
        return it.notify(src, 'Erro', 'error', 'Já existe uma guerra em andamento nesta zona.')
    end
    
    -- Save Request to DB
    MySQL.insert.await('INSERT INTO it_war_requests (zone_id, attacker_gang, defender_gang, requested_by, reason, status) VALUES (?, ?, ?, ?, ?, ?)', {
        zoneId,
        playerGang.name,
        zone.owner_gang or 'neutral',
        src, -- Note: ideally use char id, but src works for session
        reason,
        'requested'
    })

    it.notify(src, 'Solicitação Enviada', 'success', 'Sua solicitação de invasão foi enviada para a Alta Cúpula.')
    syncWarRequests() -- Update admins
end)

RegisterNetEvent('it-drugs:server:resolveWarRequest', function(data)
    local src = source
    if not it.isAdmin(src) then return end

    local requestId = data.id
    local action = data.action -- 'approve' or 'reject'
    
    print('[IT-DRUGS] Resolvendo solicitação:', requestId, 'Ação:', action)

    if action == 'approve' then
        local scheduledTime = data.time -- Receive from UI (YYYY-MM-DD HH:mm:ss format)
        print('[IT-DRUGS] Agendando para:', scheduledTime)
        local success = MySQL.update.await('UPDATE it_war_requests SET status = "approved", scheduled_time = ? WHERE id = ?', {
            scheduledTime,
            requestId
        })
        if success then
            it.notify(src, 'Sucesso', 'success', 'Guerra aprovada e agendada!')
        else
            it.notify(src, 'Erro', 'error', 'Falha ao salvar no banco de dados!')
        end
    else
        local reason = data.reason
        local success = MySQL.update.await('UPDATE it_war_requests SET status = "rejected", rejection_reason = ? WHERE id = ?', {
            reason,
            requestId
        })
        it.notify(src, 'Sucesso', 'error', 'Solicitação recusada.')
    end

    syncWarRequests() -- Update admins
end)

-- Scheduler Loop: Check for scheduled wars
CreateThread(function()
    while true do
        Wait(60000) -- Check em cada minuto
        
        local currentTime = os.date('%Y-%m-%d %H:%M:%S')
        
        local scheduled = MySQL.query.await('SELECT * FROM it_war_requests WHERE status = "approved" AND scheduled_time <= ?', {currentTime})
        
        if scheduled and #scheduled > 0 then
            print('[IT-DRUGS] Encontrados ' .. #scheduled .. ' agendamentos prontos para iniciar.')
            for _, req in ipairs(scheduled) do
                -- Check if zone is already in war
                if not activeWars[req.zone_id] then
                    -- Início direto (Removida restrição de membros online para teste/npcs)
                    activeWars[req.zone_id] = {
                        startTime = os.time(),
                        endTime = os.time() + (10 * 60), -- 10 Minutes duration
                        attacker = req.attacker_gang,
                        defender = req.defender_gang,
                        score = {
                            attacker = 0,
                            defender = 0
                        }
                    }
                    
                    updateWarStatus(req.zone_id, 'war')
                    
                    -- Update DB Status
                    MySQL.update.await('UPDATE it_war_requests SET status = "completed" WHERE id = ?', {req.id})
                    
                    TriggerClientEvent('it-drugs:client:warStarted', -1, {
                        zoneId = req.zone_id,
                        attacker = req.attacker_gang,
                        defender = req.defender_gang,
                        startTime = activeWars[req.zone_id].startTime,
                        endTime = activeWars[req.zone_id].endTime
                    })
                    
                    print('[IT-DRUGS] Guerra iniciada via agendamento: ' .. req.zone_id)
                else
                    print('[IT-DRUGS] Guerra para ' .. req.zone_id .. ' IGNORADA: Já existe um conflito ativo.')
                end
            end
        end
    end
end)

-- CTF Logic & Timer Check
CreateThread(function()
    while true do
        Wait(1000) -- Check every 1 second
        local currentTime = os.time()
        
        for zoneId, war in pairs(activeWars) do
            -- Initialize progress if missing
            if not war.captureProgress then war.captureProgress = -100 end
            if not war.captureStatus then war.captureStatus = 'DEFENDING' end

            -- Get Flag Position
            local zone = getZone(zoneId)
            local flagPoint = zone and zone.flag_point
            
            if flagPoint then
                local flagVec = vector3(flagPoint.x, flagPoint.y, flagPoint.z)
                local radius = 3.5 -- User requested 3.5m radius
                
                -- Count players in radius (for Capture) and in zone (for Alive Display)
                local nAttackersCap = 0
                local nDefendersCap = 0
                local nAttackersAlive = 0
                local nDefendersAlive = 0
                
                -- Debug Logic (Every 5 seconds)
                local doDebug = (currentTime % 5 == 0)

                -- 1. Count Real Players
                local players = GetPlayers() 
                if doDebug and #players > 0 then print(string.format("[WAR-DEBUG] Zone %s: Checking %d players...", zoneId, #players)) end
                
                -- Helper: Point in Polygon
                local function isPointInPolygon(point, polygon)
                    local x, y = point.x, point.y
                    local inside = false
                    local j = #polygon
                    for i = 1, #polygon do
                        local xi, yi = polygon[i].x, polygon[i].y
                        local xj, yj = polygon[j].x, polygon[j].y
                        local intersect = ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
                        if intersect then inside = not inside end
                        j = i
                    end
                    return inside
                end

                for _, srcStr in ipairs(players) do
                    local src = tonumber(srcStr)
                    local ped = GetPlayerPed(src)
                    
                    local isAlive = false
                    local health = 0
                    
                    if DoesEntityExist(ped) then
                        health = GetEntityHealth(ped)
                        if health > 0 then
                            isAlive = true
                            
                            -- Framework specific death check (QB-Core)
                            local Player = it.getPlayer(src)
                            if Player and it.core == 'qb-core' then
                                local metadata = Player.PlayerData.metadata
                                if metadata['isdead'] or metadata['inlaststand'] then
                                    isAlive = false
                                    if doDebug then print(string.format("[WAR-DEBUG] Player %d ignored (Metadata Dead/LastStand). Health: %d", src, health)) end
                                end
                            end
                        else
                             if doDebug then print(string.format("[WAR-DEBUG] Player %d ignored (Health <= 0). Health: %d", src, health)) end
                        end
                    end
                    
                    if isAlive then
                        local coords = GetEntityCoords(ped)
                        local dist2d = #(vector3(coords.x, coords.y, 0) - vector3(flagVec.x, flagVec.y, 0))
                        
                        local isPlayerInZone = false
                        local elapsed = currentTime - (war.startTime or 0)
                        
                        -- Initial Grace Period (20s): Map-Wide (50km)
                        if elapsed <= 20 then
                            if dist2d <= 50000.0 then isPlayerInZone = true end
                        else
                            -- Strict Mode: Must be in Polygon (Physical)
                            if zone.polygon_points and #zone.polygon_points >= 3 then
                                if isPointInPolygon({x=coords.x, y=coords.y}, zone.polygon_points) then
                                    isPlayerInZone = true
                                else
                                    if doDebug then
                                        print(string.format("[WAR-DEBUG] Point Check Fail: Player(%.2f, %.2f). Poly[1](%.2f, %.2f)", coords.x, coords.y, zone.polygon_points[1].x, zone.polygon_points[1].y))
                                    end
                                end
                            else
                                -- Fallback for point-only zones
                                if dist2d <= 150.0 then isPlayerInZone = true end
                            end
                        end
                        
                        -- Alive Check (Based on Logic)
                        -- Tolerance System for "Bounce Back" glitches (5 seconds grace)
                        war.playerStates = war.playerStates or {}
                        local isGracePeriod = false
                        
                        if isPlayerInZone then
                            war.playerStates[src] = nil
                        else
                            -- If zone lock active (elapsed > 20) and out of zone
                            if elapsed > 20 then
                                if not war.playerStates[src] then
                                    war.playerStates[src] = currentTime
                                end
                                
                                if (currentTime - war.playerStates[src]) <= 5 then
                                    isGracePeriod = true
                                    if doDebug then print(string.format("[WAR-DEBUG] Player %d OUT OF ZONE but in GRACE PERIOD (%ds)", src, (currentTime - war.playerStates[src]))) end
                                else
                                    if doDebug then print(string.format("[WAR-DEBUG] Player %d EXCLUDED (Out > 5s)", src)) end
                                end
                            else
                                -- Before 20s, everyone is "In Zone" effectively if in 50km, but logic above handles isPlayerInZone=true for 50km
                                -- So if isPlayerInZone is false here, they are > 50km away. No grace needed?
                                -- Actually, map wide check sets isPlayerInZone=true.
                            end
                        end

                        if isPlayerInZone or isGracePeriod then
                            local playerGang = getPlayerGang(src)
                            if playerGang then
                                local pGang = string.lower(playerGang.name)
                                local wAttacker = string.lower(war.attacker)
                                local wDefender = string.lower(war.defender)
                                
                                if pGang == wAttacker then
                                    nAttackersAlive = nAttackersAlive + 1
                                    if dist2d <= radius then nAttackersCap = nAttackersCap + 1 end
                                elseif pGang == wDefender then
                                    nDefendersAlive = nDefendersAlive + 1
                                    if dist2d <= radius then nDefendersCap = nDefendersCap + 1 end
                                end

                                if doDebug and dist2d <= radius then
                                     print(string.format("[WAR-DEBUG] Player %d CAPTURING. Gang: %s. A: %s D: %s", src, pGang, wAttacker, wDefender))
                                end
                            end
                        end
                    end
                end

                -- 2. Count NPCs (Defenders)
                local allPeds = GetAllPeds()
                for _, ped in ipairs(allPeds) do
                    if DoesEntityExist(ped) and GetEntityHealth(ped) > 0 and not IsPedAPlayer(ped) then
                        local state = Entity(ped).state
                        if state.isWarNPC and state.warZoneId == zoneId then
                            -- Valid War NPC = Alive Defender
                            nDefendersAlive = nDefendersAlive + 1

                            local coords = GetEntityCoords(ped)
                            local dist2d = #(vector3(coords.x, coords.y, 0) - vector3(flagVec.x, flagVec.y, 0))
                            
                            if dist2d <= radius then
                                nDefendersCap = nDefendersCap + 1
                                if doDebug then print("[WAR-DEBUG] NPC Defender CAPTURING.") end
                            end
                        end
                    end
                end
                
                if doDebug then 
                    print(string.format("[WAR-DEBUG] Zone %s: Cap[A=%d, D=%d] | Alive[A=%d, D=%d]", zoneId, nAttackersCap, nDefendersCap, nAttackersAlive, nDefendersAlive)) 
                end
                
                -- CTF Logic (Uses Cap Counts)
                local previousStatus = war.captureStatus
                local previousProgress = war.captureProgress

                if nDefendersCap > 0 then
                    -- CONTESTED / PAUSED
                    war.captureStatus = 'CONTESTED'
                elseif nAttackersCap > 0 then
                    -- ATTACKING
                    war.captureStatus = 'CAPTURING'
                    -- Rate: 200 points (from -100 to 100) in 120 seconds -> 1.666 per sec
                    war.captureProgress = math.min(100, war.captureProgress + 1.666)
                else
                    -- DECAYING
                    war.captureStatus = 'DECAYING'
                    -- Decay back to -100
                    war.captureProgress = math.max(-100, war.captureProgress - 1.666)
                end
                
                -- Check Win Condition (Full Capture)
                if war.captureProgress >= 100 then
                    -- INSTANT WIN
                    local winner = war.attacker
                    TriggerEvent('it-drugs:server:updateGangZoneOwner', zoneId, winner)
                    updateWarStatus(zoneId, 'peace')
                    
                    TriggerClientEvent('it-drugs:client:warEnded', -1, {
                        zoneId = zoneId,
                        winner = winner,
                        reason = 'capture'
                    })
                    
                    activeWars[zoneId] = nil
                    goto continue
                end
                
                -- Sync if changed significantly (optimize network)
                -- Always sync every second if active/capturing to update UI smoothly
                if previousStatus ~= war.captureStatus or math.abs(previousProgress - war.captureProgress) > 0.5 or (currentTime % 2 == 0) then
                     TriggerClientEvent('it-drugs:client:updateWarStatus', -1, {
                         zoneId = zoneId,
                         progress = war.captureProgress,
                         status = war.captureStatus,
                         attackerCount = nAttackersAlive, -- UI shows Alive Count
                         defenderCount = nDefendersAlive  -- UI shows Alive Count
                     })
                end

                -- Attacker Elimination Check (Auto-End if no attackers left alive/in zone)
                -- Grace period removed as requested (Ends immediately if 0 attackers)
                -- if (currentTime - war.startTime) > 60 then
                    -- Safety check if nAttackersAlive is nil somehow, though it is init to 0 in this block
                    if nAttackersAlive and nAttackersAlive == 0 then
                        local winner = war.defender
                        TriggerEvent('it-drugs:server:updateGangZoneOwner', zoneId, winner)
                        updateWarStatus(zoneId, 'peace')
                        
                        TriggerClientEvent('it-drugs:client:warEnded', -1, {
                            zoneId = zoneId,
                            winner = winner,
                            reason = 'elimination'
                        })
                        
                        if doDebug then print('[WAR-DEBUG] War '..zoneId..' ended due to ZERO attackers left.') end
                        activeWars[zoneId] = nil
                        goto continue
                    end
                -- end
            end
            
            -- Time Limit Check (keeps existing logic as fallback)
            if currentTime >= war.endTime then
                 -- End War logic
                 local winner = war.defender -- Default defender wins time limit unless score overrides
                 if war.captureProgress > 0 then -- If attackers have > 50% dominance (0 is neutral), maybe they win? User didn't specify, sticking to defender holds
                    -- Keeping defender win default
                 end
                 
                 TriggerEvent('it-drugs:server:updateGangZoneOwner', zoneId, winner)
                 updateWarStatus(zoneId, 'peace')
                 
                 TriggerClientEvent('it-drugs:client:warEnded', -1, {
                     zoneId = zoneId,
                     winner = winner,
                     reason = 'time'
                 })
                 
                 activeWars[zoneId] = nil
            end
            
            ::continue::
        end
    end
end)

-- Exports or Events to register kills (Placeholder)
RegisterNetEvent('it-drugs:server:registerWarKill', function(zoneId, killerGang)
    if activeWars[zoneId] then
        if killerGang == activeWars[zoneId].attacker then
            activeWars[zoneId].score.attacker = activeWars[zoneId].score.attacker + 1
        elseif killerGang == activeWars[zoneId].defender then
            activeWars[zoneId].score.defender = activeWars[zoneId].score.defender + 1
        end
        
        -- Sync Score
        TriggerClientEvent('it-drugs:client:updateWarScore', -1, {
            zoneId = zoneId,
            score = activeWars[zoneId].score
        })
    end
end)

-- Force end war (used when NPCs are defeated)
RegisterNetEvent('it-drugs:server:forceEndWar', function(zoneId, winner)
    if activeWars[zoneId] then
        print('[IT-DRUGS] Guerra finalizada forçadamente por eliminação de defensores na zona: ' .. zoneId)
        
        -- Update Owner
        TriggerEvent('it-drugs:server:updateGangZoneOwner', zoneId, winner)
        updateWarStatus(zoneId, 'peace')
        
        TriggerClientEvent('it-drugs:client:warEnded', -1, {
            zoneId = zoneId,
            winner = winner
        })
        
        activeWars[zoneId] = nil
    end
end)

-- Diagnostic Event (Triggered by Client /debugctf)
RegisterNetEvent('it-drugs:server:diagWar', function(zoneId, clientCoords)
    local src = source
    local war = activeWars[zoneId]
    
    if not war then 
        TriggerClientEvent('it-drugs:client:diagResult', src, "War " .. tostring(zoneId) .. " not found on server.")
        return 
    end
    
    local ped = GetPlayerPed(src)
    local serverCoords = GetEntityCoords(ped)
    local distSync = #(clientCoords - serverCoords)
    
    TriggerClientEvent('it-drugs:client:diagResult', src, string.format("Sync Check: Client=%.1f, Server=%.1f. Diff=%.2f", clientCoords.x, serverCoords.x, distSync))
    
    local zone = getZone(zoneId)
    if zone and zone.flag_point then
        local flagVec = vector3(zone.flag_point.x, zone.flag_point.y, zone.flag_point.z)
        local dist2d = #(vector3(serverCoords.x, serverCoords.y, 0) - vector3(flagVec.x, flagVec.y, 0))
        
        local playerGang = getPlayerGang(src)
        local gangName = playerGang and playerGang.name or "NIL"
        
        local logicCheck = (dist2d <= 3.5)
        local gangCheck = (string.lower(gangName) == string.lower(war.attacker) or string.lower(gangName) == string.lower(war.defender))
        
        TriggerClientEvent('it-drugs:client:diagResult', src, string.format("Logic: Dist2D=%.2f (Max 3.5). Inside? %s", dist2d, logicCheck and "YES" or "NO"))
        TriggerClientEvent('it-drugs:client:diagResult', src, string.format("Gang: '%s' (Attacker: '%s', Defender: '%s'). Match? %s", gangName, war.attacker, war.defender, gangCheck and "YES" or "NO"))
        
        if logicCheck and gangCheck then
             TriggerClientEvent('it-drugs:client:diagResult', src, "VERDICT: YOU SHOULD BE CAPTURING.")
        else
             TriggerClientEvent('it-drugs:client:diagResult', src, "VERDICT: NOT CAPTURING (Check distance or gang).")
        end
    end
end)
