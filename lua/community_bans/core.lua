local util_SteamIDTo64 = util.SteamIDTo64
local isstring = isstring
local ipairs = ipairs
local assert = assert

module( 'community_bans', package.seeall )

do

    local logColors = { Color( 0, 103, 221 ), Color( 224, 182, 42 ) }
    local MsgC = MsgC

    function Log( str )
        MsgC( logColors[1], '[Community Ban Lists] ', logColors[2], str, '\n' )
    end

end

do
    local lists = {}
    function Get( name )
        assert( isstring( name ), 'Argument #1 must be a \'string\'' )
        return lists[ name ]
    end

    do
        local istable = istable
        function Set( name, tbl )
            assert( isstring( name ), 'Argument #1 must be a \'string\'' )
            assert( istable( tbl ), 'Argument #2 must be a \'table\'' )
            lists[ name ] = tbl
        end
    end

    function Clear( name )
        assert( isstring( name ), 'Argument #1 must be a \'string\'' )
        lists[ name ] = nil
    end

    function CheckSteamID64( steamID64 )
        assert( isstring( steamID64 ), 'Argument #1 must be a \'string\'' )

        for name, tbl in pairs( lists ) do
            local steamIDs = tbl.SteamIDs
            if istable( steamIDs ) then
                if steamIDs[ steamID64 ] then
                    return true, tbl.Reason, tbl.Silent, tbl.Name
                end
            else
                table.remove( lists, num )
            end
        end

        return false, '', false
    end
end

function CheckSteamID( steamID )
    assert( isstring( steamID64 ), 'Argument #1 must be a \'string\'' )
    return CheckSteamID64( util_SteamIDTo64( steamID ) )
end

do

    local timer_Simple = timer.Simple
    local http_Fetch = http.Fetch

    function Download( url, callback )
        timer_Simple(0, function()
            http_Fetch( url, function( data, _, __, code )
                if (code < 200) then return callback() end
                if (code >= 300) then return callback() end
                callback( data )
            end)
        end)
    end

end

do

    local string_gmatch = string.gmatch
    local string_gsub = string.gsub
    local string_find = string.find
    local string_sub = string.sub

    function Install( name, url, reason, silent )
        if isstring( url ) then
            if not isstring( name ) then
                name = url
            end

            Download(url, function( data )
                if isstring( data ) then
                    if (#data > 3) then

                        local tbl = {}
                        tbl.Name = name
                        tbl.Source = url
                        tbl.Reason = reason
                        tbl.Silent = silent
                        tbl.SteamIDs = {}

                        local counter = 0
                        for str in string_gmatch( data, '(.-)\n' ) do
                            local line = string_gsub( str, '\r', '' )
                            if isstring( line ) then
                                local start = string_find( line, 'STEAM_', 1 )
                                if (start == nil) then
                                    tbl.SteamIDs[ line ] = true
                                else
                                    tbl.SteamIDs[ util_SteamIDTo64( string_sub( line, start, #line ) ) ] = true
                                end

                                counter = counter + 1
                            end
                        end

                        if (counter > 0) then
                            Log( '\'' .. tbl.Name .. '\' ban list successfully installed!' )
                            Set( name, tbl )
                            return
                        end
                    end
                end

                Log( '\'' .. name .. '\' is does not contain a list of blocked users.' )
            end)
        end
    end

end

function InstallLocal( path )
    assert( isstring( path ), 'Argument #1 must be a \'string\'' )

    local lists = {}
    for num, fl in ipairs( file.Find( path .. '*', 'LUA' ) ) do
        local env = {}
        local func = CompileFile( path .. fl )
        if isfunction( func ) then
            debug.setfenv( func, env )
            if pcall( func ) then
                for key, value in pairs( env ) do
                    if isstring( key ) then
                        env[ string.lower( key ) ] = value
                    end
                end

                table.insert( lists, env )
            end
        end
    end

    for num, tbl in ipairs( lists ) do
        Install( tbl.name, tbl.source, tbl.reason, tbl.silent )
    end
end