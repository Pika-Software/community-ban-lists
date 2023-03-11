if game.SinglePlayer() or (game.MaxPlayers() < 2) then return end
include( 'community_bans/init.lua' )

local util_SteamIDFrom64 = util.SteamIDFrom64
local game_GetIPAddress = game.GetIPAddress
local community_bans = community_bans
local GetHostName = GetHostName
local string = string

do

    local folder = 'community_bans/lists/'
    for _, fileName in ipairs( file.Find( folder .. '*', 'LUA' ) ) do
        community_bans.InstallLocal( folder .. fileName )
    end

end

hook.Add( 'CheckPassword', 'Community Ban Lists', function( sid64, ip, _, __, nickname )
    local result = community_bans.GetResult( sid64 )
    if not result.Banned then return end

    local info = {
        -- Player Info
        ['steamid'] = util_SteamIDFrom64( sid64 ),
        ['steamid64'] = sid64,
        ['nickname'] = nickname,
        ['ip'] = ip,

        -- Server Info
        ['listname'] = result.ListName,
        ['serverip'] = game_GetIPAddress(),
        ['servername'] = GetHostName()
    }

    return false, string.gsub( result.Reason, '{(%w)}', function( str )
        local value = info[ string.lower( str ) ]
        if not value then return '{' .. str .. '}' end
        return value
    end)
end )