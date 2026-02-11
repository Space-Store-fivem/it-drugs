local function GetRanking()
    local ranking = {}
    local gangs = {}

    -- Query directly from DB to avoid touching sv_gangs.lua
    -- Assuming structure from viewed files: zone_id, owner_gang
    local zones = MySQL.query.await('SELECT owner_gang FROM it_gang_zones WHERE owner_gang IS NOT NULL')

    if zones then
        for _, zone in ipairs(zones) do
            local gangName = zone.owner_gang
            if gangName and gangName ~= '' then
                if not gangs[gangName] then
                    gangs[gangName] = {
                        name = gangName,
                        label = gangName, -- We don't have easy access to label without config, using name
                        count = 0,
                        -- Logo would normally be in gangMetadata but that's in sv_gangs.lua. 
                        -- We might send without logo for now or try to fetch if stored in DB.
                        -- For now, simple ranking.
                    }
                end
                gangs[gangName].count = gangs[gangName].count + 1
            end
        end
    end

    -- Convert to array
    for _, v in pairs(gangs) do
        table.insert(ranking, v)
    end

    -- Sort descending
    table.sort(ranking, function(a, b)
        return a.count > b.count
    end)

    return ranking
end

RegisterNetEvent('it-drugs:server:requestRanking', function()
    local src = source
    local ranking = GetRanking()
    TriggerClientEvent('it-drugs:client:receiveRanking', src, ranking)
end)
