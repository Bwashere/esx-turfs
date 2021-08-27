resource_manifest_version "44febabe-d386-4d18-afbe-5e627f4af937"

fx_version 'adamant'
game 'gta5'

ui_page {
    'nui/index.html',
}

files {
    'nui/index.html',
    'nui/main.js',
    'nui/main.css',
    'nui/logo.png',
    'nui/gtafont.woff',
    'nui/gtafont.woff2',
}

shared_scripts {
    'config.lua'
} 

client_scripts {
    'client.lua'
} 

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server.lua' 
}
