-- sv_colors.lua: Centralized Gang Color Management
local GangColors = {}

-- Load colors on startup
CreateThread(function()
    Wait(1000) -- Wait for DB
    local p = promise.new()
    
    local success, result = pcall(function()
        local rows = MySQL.Sync.fetchAll('SELECT * FROM it_gang_data')
        if rows then
            for _, row in ipairs(rows) do
                if row.color then
                    GangColors[row.gang_name] = json.decode(row.color)
                end
            end
        end
    end)
    
    if not success then
        print('^1[IT-DRUGS] Error loading gang colors table (it_gang_data). Did you run the SQL?^7')
    else
        print(string.format('^2[IT-DRUGS] Loaded colors for %d gangs.^7', table.count(GangColors)))
    end
end)

-- Helper to get cache
function it.getGangColorCached(gangName)
    if not gangName then return nil end
    return GangColors[gangName]
end

-- Command for Boss to set color
RegisterCommand('setgangcolor', function(source, args)
    local src = source
    local playerGang = it.getPlayerGang(src)
    
    -- Check permissions (Boss/Leader)
    -- Assuming getPlayerGang returns grade info. If not, we might need a stricter check.
    -- Depending on framework, `isboss` might be a boolean in the returned table (QB) or grade check (ESX).
    local isBoss = false
    if playerGang.isboss == true or playerGang.grade_name == 'boss' or (tonumber(playerGang.grade) and tonumber(playerGang.grade) >= 2) then -- Heuristic
        isBoss = true
    end
    
    if not isBoss then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Apenas o líder pode mudar a cor da gangue.' })
        return
    end
    
    if #args < 3 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'info', description = 'Uso: /setgangcolor R G B (Ex: 255 0 0)' })
        return
    end
    
    local r = tonumber(args[1]) or 0
    local g = tonumber(args[2]) or 0
    local b = tonumber(args[3]) or 0
    
    -- Clamping
    r = math.min(255, math.max(0, r))
    g = math.min(255, math.max(0, g))
    b = math.min(255, math.max(0, b))
    
    local colorArr = {r, g, b}
    local gangName = playerGang.name
    
    -- Update Cache
    GangColors[gangName] = colorArr
    
    -- Update DB (Upsert)
    MySQL.Async.execute('INSERT INTO it_gang_data (gang_name, color) VALUES (@name, @color) ON DUPLICATE KEY UPDATE color = @color', {
        ['@name'] = gangName,
        ['@color'] = json.encode(colorArr)
    })
    
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = string.format('Cor da gangue %s atualizada!', gangName) })
    
    -- Sync everyone
    TriggerClientEvent('it-drugs:client:syncGangColors', -1, GangColors)
    
    print(string.format('[IT-DRUGS] Gang %s updated color to [%d, %d, %d]', gangName, r, g, b))
end)

-- Sync Event Request (on join)
RegisterNetEvent('it-drugs:server:requestGangColors', function()
    local src = source
    TriggerClientEvent('it-drugs:client:syncGangColors', src, GangColors)
end)

-- Export for other scripts if needed
exports('getGangColor', function(gangName)
    return GangColors[gangName]
end)

-- Helper to Count Table
function table.count(t)
    local c = 0
    for _ in pairs(t) do c = c + 1 end
    return c
end

-- Net Event for NUI
RegisterNetEvent('it-drugs:server:setGangColorNUI', function(color)
    local src = source
    local playerGang = it.getPlayerGang(src)
    
    if not playerGang then return end

    -- Check permissions (Boss/Leader)
    local isBoss = false
    if playerGang.isboss == true or playerGang.grade_name == 'boss' or (tonumber(playerGang.grade) and tonumber(playerGang.grade) >= 2) then
        isBoss = true
    end
    
    if not isBoss then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Apenas o líder pode mudar a cor da gangue.' })
        return
    end
    
    local r = tonumber(color.r) or 0
    local g = tonumber(color.g) or 0
    local b = tonumber(color.b) or 0
    
    r = math.min(255, math.max(0, r))
    g = math.min(255, math.max(0, g))
    b = math.min(255, math.max(0, b))
    
    local colorArr = {r, g, b}
    local gangName = playerGang.name
    
    -- Update Cache
    GangColors[gangName] = colorArr
    
    -- Update DB
    MySQL.Async.execute('INSERT INTO it_gang_data (gang_name, color) VALUES (@name, @color) ON DUPLICATE KEY UPDATE color = @color', {
        ['@name'] = gangName,
        ['@color'] = json.encode(colorArr)
    })
    
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = string.format('Cor atualizada para RGB(%d, %d, %d)!', r, g, b) })
    
    -- Sync everyone
    TriggerClientEvent('it-drugs:client:syncGangColors', -1, GangColors)
    
    print(string.format('[IT-DRUGS] Gang %s updated color via NUI to [%d, %d, %d]', gangName, r, g, b))
end)
