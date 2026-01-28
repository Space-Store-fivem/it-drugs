-- STANDALONE DEBUG SCRIPT (RETRY)
print("IT-DRUGS: DEBUG - cl_debug.lua LOADED SUCCESSFULLY")

RegisterCommand('itdrugsdebug', function()
  print("IT-DRUGS: DEBUG - Debug command executed")
  TriggerServerEvent('it-drugs:server:openGangPanel')
end)
