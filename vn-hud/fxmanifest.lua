fx_version 'cerulean'
game 'gta5'

name 'vn-hud'

shared_script 'config.lua'

client_scripts {
    'client/weapon_images.lua',
    'client/needs.lua',
    'client/main.lua',
    'client/voice.lua',
    'client/vehicle.lua',
    'client/radio.lua',
    'client/chat.lua'
}

server_scripts {
    'server/main.lua',
    'server/radio.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/m.mp3',
    'html/assets/weapons/*.png',
    'stream/rectmap.ytd'
}
