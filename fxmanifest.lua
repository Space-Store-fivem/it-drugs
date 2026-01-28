fx_version 'cerulean'
game 'gta5'

author '@allroundjonu'
description 'Advanced Drug System for FiveM'
version 'v1.2.4'

-- UI Configuration (moved to top)
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/assets/**/*', -- React Build Assets

    -- Optimization: Only load Zoom 1-5 to prevent server timeout (20k+ files crash boot)
    -- If you need Zoom 6/7, consider hosting tiles externally.
    'tiles/satellite/1/*.png',
    'tiles/satellite/2/*.png',
    'tiles/satellite/3/*.png',
    'tiles/satellite/4/*.png',
    'tiles/satellite/5/*.png',
    -- 'tiles/satellite/6/*.png', -- Too heavy (4k files)
    -- 'tiles/satellite/7/*.png', -- Too heavy (16k files)
    'server/database/drug_plants.sql',
    'server/database/drug_processing.sql',
    'server/database/drug_zones.sql',
    'server/database/war_requests.sql',
}

shared_script 'bridge/init.lua'

shared_scripts {
    'shared/config.lua',
    'locales/en.lua',
    'locales/*.lua',
    '@ox_lib/init.lua',
    'bridge/**/shared.lua',
}

client_scripts {
    'client/cl_debug.lua', -- Run this first to verify client execution
    'bridge/**/client.lua',
    'client/cl_admin.lua',
    'client/cl_menus.lua',
    'client/cl_dealer.lua',
    'client/cl_planting.lua',
    'client/cl_processing.lua',
    'client/cl_selling.lua',
    'client/cl_target.lua',
    'client/cl_using.lua',
    'client/cl_blips.lua',
    'client/cl_zone_creator.lua',
    'client/cl_zones.lua', -- Uncommented for Phase 1 functionality
    'client/cl_nui.lua',   -- New NUI Handler
    'client/cl_drug_table.lua',
    'client/cl_gangs.lua',
    'client/cl_war.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/**/server.lua',
    'server/sv_admin.lua',
    'server/sv_dealer.lua',
    'server/sv_planting.lua',
    'server/sv_processing.lua',
    'server/sv_selling.lua',
    'server/sv_usableitems.lua',
    'server/sv_versioncheck.lua',
    'server/sv_webhooks.lua',
    'server/sv_zones.lua',
    'server/database/sv_setupdatabase.lua',
    'server/sv_gangs.lua',
    'server/sv_war.lua',
}

dependencies {
    'ox_lib',
    'oxmysql'
}

lua54 'yes'
usefxv2oal 'yes'