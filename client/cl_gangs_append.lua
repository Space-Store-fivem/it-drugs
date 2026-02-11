
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
        
        -- Default thickness for gangs is usually higher, e.g., 50.0
        local thickness = zone.thickness or 50.0 
        local maxZ = minZ + thickness
        
        -- Optional: Expanded check
        if z < (minZ - 10.0) or z > (maxZ + 10.0) then
            inside = false
        end
    end
    
    return inside
end

-- Manual Detection Loop for Gang Zones
local currentGangZoneId = nil

CreateThread(function()
    Wait(2000) -- Wait for zones to load
    
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        local foundZone = nil
        
        if gangZones then
            for zoneId, zone in pairs(gangZones) do
                if zone.polygon_points and zone.polygon_points[1] then
                    local firstPoint = zone.polygon_points[1]
                    local dist = #(coords - vector3(firstPoint.x, firstPoint.y, firstPoint.z))
                    
                    -- Check if within 200m (larger radius for gang zones)
                    if dist < 200.0 then
                        sleep = 200 
                        
                        if isPointInZone(coords, zone) then
                            foundZone = zoneId
                            break 
                        end
                    end
                end
            end
        end
        
        -- Handle Enter/Exit
        if foundZone ~= currentGangZoneId then
            -- EXIT
            if currentGangZoneId then
                if Config.Debug then print("Exited Gang Zone ["..tostring(currentGangZoneId).."]") end
                
                TriggerEvent('it-drugs:client:exitGangZone', currentGangZoneId)
                
                SendNUIMessage({
                    action = 'zoneNotification',
                    show = false,
                    zoneName = '',
                    gangOwner = ''
                })
            end
            
            -- ENTER
            if foundZone then
                if Config.Debug then print("Entered Gang Zone ["..tostring(foundZone).."]") end
                
                TriggerEvent('it-drugs:client:enterGangZone', foundZone)
                
                local zone = gangZones[foundZone]
                local owner = zone.owner_gang or "Ninguém"
                local label = zone.label or "Território"
                
                -- Beautify owner name if possible (would need gang label map)
                -- For now sending raw name or label if available
                
                SendNUIMessage({
                    action = 'zoneNotification',
                    show = true,
                    zoneName = label,
                    gangOwner = owner
                })
            end
            
            currentGangZoneId = foundZone
        end
        
        Wait(sleep)
    end
end)
