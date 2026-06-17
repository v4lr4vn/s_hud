fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 's_hud'
description 'Per-player HUD for the Saga framework — custom panels (hunger/thirst/stamina/armour/IDs) + replacement minimap (removes native health/armour). Drag anything where you want it via /hud. Minimap assets from ps-hud (GPL-3.0) — see NOTICE.md.'
author 'ValRavn'
version '0.3.0'

dependencies {
    's_lib',
}

ui_page 'web/editor.html'

shared_scripts {
    '@s_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
}

files {
    'web/editor.html',
    'web/editor.css',
    'web/editor.js',
    'web/playerhud.js',
}
