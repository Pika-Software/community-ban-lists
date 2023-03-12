local isstring = isstring
local string = string
local Either = Either
local pairs = pairs

module( 'community_bans', package.seeall )

do

    local logColors = { Color( 100, 150, 250 ), Color( 220, 220, 220 ) }
    local MsgC = MsgC

    function Log( str, ... )
        MsgC( logColors[ 1 ], '[Community Ban Lists] ', logColors[ 2 ], string.format( str, ... ), '\n' )
    end

end

do

    local lists = {}

    function GetList( name )
        return lists[ name ]
    end

    function SetList( name, tbl )
        lists[ name ] = tbl
    end

    local istable = istable
    local assert = assert

    function GetResult( sid64 )
        assert( isstring( sid64 ), 'Argument #1 must be a \'string\'' )

        for _, tbl in pairs( lists ) do
            if not istable( tbl ) then continue end

            local steamids = tbl.SteamIDs
            if not steamids then continue end

            local result = steamids[ sid64 ]
            if not result then continue end

            return {
                ['Banned'] = true,
                ['ListName'] = tbl.Name,
                ['Message'] = tbl.Message,
                ['Reason'] = Either( isstring( result ), result, 'unknown' )
            }
        end

        return {
            ['Banned'] = false
        }
    end

end

do

    local timer_Simple = timer.Simple
    local http_Fetch = http.Fetch

    function Download( source, callback )
        timer_Simple( 0, function()
            http_Fetch( source, function( body, _, __, code )
                if (code == 200) then
                    callback( body )
                    return
                end

                callback()
            end )
        end)
    end

end

do

    local util_SteamIDTo64 = util.SteamIDTo64

    function Install( name, source, message, reasonSeparator )
        if not isstring( source ) then return end

        Download( source, function( body )
            if not body then return end
            local tbl = {
                ['Source'] = source,
                ['SteamIDs'] = {},
                ['Message'] = message,
                ['Name'] = string.Trim( name or source ),
                ['ReasonSeparator'] = reasonSeparator or ' - '
            }

            local counter = 0
            for line in string.gmatch( body, '(.-)\n' ) do
                counter = counter + 1

                local userData = string.Split( string.gsub( line, '\r', '' ), tbl.ReasonSeparator )
                local reason = Either( userData[ 2 ] ~= nil, userData[ 2 ], true )
                local sid = string.Trim( userData[ 1 ] )

                local start = string.find( sid, 'STEAM_' )
                if start then
                    tbl.SteamIDs[ util_SteamIDTo64( string.sub( sid, start, #sid ) ) ] = reason
                    continue
                end

                tbl.SteamIDs[ sid ] = reason
            end

            if (counter == 0) then
                Log( '\'%s\' is does not contain a list of blocked users.', tbl.Name )
                return
            end

            Log( '\'%s\' ban list successfully installed!', tbl.Name )
            SetList( tbl.Name, tbl )
        end)
    end

end

do

    local ErrorNoHaltWithStack = ErrorNoHaltWithStack
    local CompileFile = CompileFile
    local setfenv = setfenv
    local pcall = pcall

    function InstallLocal( filePath )
        local func = CompileFile( filePath )
        if not func then
            Log( 'Installing \'%s\' failed, file is non exist.' )
            return false
        end

        local environment = {}
        setfenv( func, environment )

        local ok, result = pcall( func )
        if not ok then
            ErrorNoHaltWithStack( result )
            return false
        end

        local banList = {}
        for key, value in pairs( environment ) do
            if not isstring( key ) then continue end
            banList[ string.lower( key ) ] = value
        end

        Install( banList.name, banList.source, banList.message or banList.reason, banList.reasonseparator )
        return true
    end

end