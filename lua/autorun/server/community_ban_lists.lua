if game.SinglePlayer() or (game.MaxPlayers() < 2) then return end
include( 'community_bans/core.lua' )

community_bans.InstallLocal( 'community_bans/lists/' )

do

    local community_bans_CheckSteamID64 = community_bans.CheckSteamID64
    local community_bans_Log = community_bans.Log
    local util_SteamIDFrom64 = util.SteamIDFrom64
    local game_GetIPAddress = game.GetIPAddress
    local cvars_String = cvars.String
    local string_lower = string.lower
    local string_gsub = string.gsub
    local isstring = isstring

    hook.Add('CheckPassword', 'Community Ban Lists', function( steamID64, ip, _, __, nickname )
        local banned, reason, silent, listName = community_bans_CheckSteamID64( steamID64 )
        if (banned) then
            local info = {
                -- Player Info
                ['nickname'] = nickname,
                ['steamid64'] = steamID64,
                ['ip'] = ip,

                -- Server Info
                ['listname'] = listName,
                ['serverip'] = game_GetIPAddress(),
                ['servername'] = cvars_String( 'hostname', 'Garry\'s Mod' )
            }

            if not silent then
                community_bans_Log( 'Player \'' .. nickname .. '\' (' .. util_SteamIDFrom64( steamID64 ) .. ') blocked in \'' .. listName .. '\'.' )
            end

            return false, string_gsub( reason, '{(%w)}', function( str )
                local value = info[ string_lower( str ) ]
                if isstring( value ) then
                    return value
                end

                return '{' .. str .. '}'
            end)
        end
    end)

end