if game.SinglePlayer() or (game.MaxPlayers() < 2) then return end
include( 'community_bans/core.lua' )

community_bans.InstallLocal( 'community_bans/lists/' )

hook.Add('CheckPassword', 'Community Ban Lists', function( steamID64, ip, _, __, nickname )
    local banned, reason, silent, listName = community_bans.CheckSteamID64( steamID64 )
    if (banned) then
        local info = {
            -- Player Info
            ['nickname'] = nickname,
            ['steamid64'] = steamID64,
            ['ip'] = ip,

            -- Server Info
            ['listname'] = listName,
            ['serverip'] = game.GetIPAddress(),
            ['servername'] = cvars.String( 'hostname', 'Garry\'s Mod' )
        }

        if not silent then
            community_bans.Log( 'Player \'' .. nickname .. '\' (' .. steamID64 .. ') blocked in \'' .. listName .. '\'.' )
        end

        return false, string.gsub( reason, '{(%w)}', function( str )
            local value = info[ string.lower( str ) ]
            if isstring( value ) then
                return value
            end

            return '{' .. str .. '}'
        end)
    end
end)