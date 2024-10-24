local _G = _G

local game, print = _G.game, _G.print
if game.SinglePlayer() or ( game.MaxPlayers() < 2 ) then
    print( "[CBL] Not running in singleplayer or maxplayers < 2" )
    return nil
end

local lower, gsub, format, find, sub, len, match, Trim, gmatch
do
    local _obj_0 = _G.string
    lower, gsub, format, find, sub, len, match, Trim, gmatch = _obj_0.lower, _obj_0.gsub, _obj_0.format, _obj_0.find, _obj_0.sub, _obj_0.len, _obj_0.match, _obj_0.Trim, _obj_0.gmatch
end

local hook, file, util, isstring, setmetatable, SysTime, GetHostName = _G.hook, _G.file, _G.util, _G.isstring, _G.setmetatable, _G.SysTime, _G.GetHostName
local SteamIDFrom64, SteamIDTo64 = util.SteamIDFrom64, util.SteamIDTo64
local AsyncRead, Exists = file.AsyncRead, file.Exists
local Iterator = _G.player.Iterator
local Fetch = _G.http.Fetch

local bans, urls = {}, {}

local loadConfig = function()
    if Exists( "community_ban_lists.json", "DATA" ) then
        local json = file.Read( "community_ban_lists.json", "DATA" )
        if isstring( json ) then
            local data = util.JSONToTable( json )
            if _G.istable( data ) then
                table.Merge( urls, data )
            end
        end
    else
        file.Write("community_ban_lists.json", "[]")
    end

    return nil
end

local server_address = game.GetIPAddress()
local server_map = game.GetMap()

local reasonFormatter = function( tbl )
    return function( str )
        return tbl[ lower( str ) ] or ( "{{" .. str .. "}}" )
    end
end

local metatable = {
    ["GetReason"] = function( self, ip, sid64, nickname )
        return gsub( self.message, "{{([%w_]+)}}", reasonFormatter( {
            ["list_length"] = self.length,
            ["list_name"] = self.name,
            ["server_name"] = GetHostName(),
            ["server_address"] = server_address,
            ["server_map"] = server_map,
            ["player_reason"] = self.reasons[ sid64 ] or "unknown",
            ["player_steamid"] = SteamIDFrom64( sid64 ),
            ["player_steamid64"] = sid64,
            ["player_nick"] = nickname,
            ["player_ip"] = ip
        } ) )
    end,
    ["Fetch"] = function( self, url )
        local localFilePath = match( url, "file://(.+)" )
        if localFilePath and Exists( localFilePath, "GAME" ) then
            AsyncRead( localFilePath, "GAME", function( _, __, code, str )
                if code == 0 then
                    self:Parse( str )
                    return nil
                end

                ErrorNoHaltWithStack( format( "AsyncRead from '%s' failed with code: %d", localFilePath, code ) )
                return nil
            end )

            return nil
        end

        Fetch( url, function( str, _, __, code )
            if code == 200 then
                self:Parse( str )
                return nil
            end

            ErrorNoHaltWithStack( format( "GET request to '%s' failed with code: %d", url, code ) )
            return nil
        end, function( msg )
            ErrorNoHaltWithStack( format( "GET request to '%s' failed with error: %s", url, msg ) )
            return nil
        end )

        return nil
    end,
    ["AddSteamID"] = function( self, sid, reason )
        if find( sid, "^STEAM_%d+:%d+:%d+$" ) ~= nil then
            sid = SteamIDTo64( sid )
        end

        if bans[ sid ] == nil then
            self.length = self.length + 1
            bans[ sid ] = self
        end

        if reason then
            self.reasons[ sid ] = reason
        end

        return nil
    end,
    ["RemoveSteamID"] = function(self, sid)
        if find( sid, "^STEAM_%d+:%d+:%d+$" ) ~= nil then
            sid = SteamIDTo64( sid )
        end

        if bans[ sid ] ~= nil then
            self.length = self.length - 1
            self.reasons[ sid ] = nil
            bans[ sid ] = nil
        end

        return nil
    end,
    ["Perform"] = function( self )
        for _, ply in Iterator() do
            if ply.SteamID64 ~= nil then
                local sid64 = ply:SteamID64()
                if bans[ sid64 ] ~= nil then
                    ply:Kick( self:GetReason( ply:IPAddress(), sid64, ply:Nick() ) )
                end
            end
        end

        return nil
    end,
    ["Parse"] = function( self, str )
        str = gsub( str, "\r", "" )

        local startPos, endPos, config = find( str, "<config>(.+)</config>", 1, false )
        if config ~= nil then
            str = sub( str, 1, startPos - 1 ) .. sub( str, endPos + 1 )
            self.name = match( config, "<name>(.+)</name>" ) or self.name
            self.message = Trim( gsub( gsub( match( config, "<message>(.+)</message>" ), "\n[ \t]+", "\n" ), "\n$", "" ) ) or self.message
        end

        local sid

        for line in gmatch( str, "(.-)\n" ) do
            if len( line ) > 8 then
                line = gsub( line, "^%s*banid%s+%d+%s+", "" )
                startPos, endPos, sid = find( line, "([%w_:]+)" )
                if sid ~= nil then
                    line = sub( line, endPos + 1 )

                    local reason = match( line, "^%s+%p+%s+(.+)%s*$" )
                    if reason == nil then
                        reason = match( line, "^%s(.+)%s*$" )
                    end

                    self:AddSteamID( sid, reason )
                end
            end
        end

        print( format( "[CBL/%s] Added %d banned SteamID's, took %f seconds.", self.name, self.length, SysTime() - self.start_time ) )
        self:Perform()
        return nil
    end
}

metatable.__index = metatable

local communityBanList = function( url )
    local obj = setmetatable( {
        ["message"] = "Your SteamID is on the community ban list used on this server. Contact the server owner for more information.",
        ["name"] = gsub( url, "%w+://", "" ),
        ["start_time"] = SysTime(),
        ["reasons"] = {},
        ["length"] = 0
    }, metatable )

    if isstring( url ) then
        obj:Fetch( url )
    end

    return obj
end

util.CommunityBanList = communityBanList
local Run = hook.Run

local loadLists = function()
    for index = 1, #urls do
        communityBanList( urls[ index ] )
    end

    Run( "Community Ban Lists - Loaded" )
    print( "[CBL] Loaded " .. #urls .. " community ban lists." )
    return nil
end

hook.Add( "CheckPassword", "Community Ban Lists - Connect", function( sid64, ip, _, __, nickname )
    local obj = bans[ sid64 ]
    if obj and Run( "Community Ban Lists - Connect", obj, sid64, ip, nickname ) ~= false then
        return false, obj:GetReason( ip, sid64, nickname )
    end

    return nil
end )

concommand.Add( "cbl_reload", function( ply )
    if not ( ply and ply:IsValid() and not ply:IsSuperAdmin() ) then
        table.Empty( bans )
        loadConfig()
        loadLists()
    end
end )

_G.timer.Simple( 0, loadLists )
loadConfig()
return nil
