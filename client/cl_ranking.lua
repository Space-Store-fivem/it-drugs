RegisterNUICallback('requestRanking', function(_, cb)
    TriggerServerEvent('it-drugs:server:requestRanking')
    cb('ok')
end)

RegisterNetEvent('it-drugs:client:receiveRanking', function(ranking)
    SendNUIMessage({
        action = 'updateRanking',
        ranking = ranking
    })
end)
