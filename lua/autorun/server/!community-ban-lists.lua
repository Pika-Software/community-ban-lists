local addon_name = "Community Ban Lists"

local string_gmatch = string.gmatch
local string_format = string.format
local string_match = string.match
local string_lower = string.lower
local string_gsub = string.gsub
local string_find = string.find
local string_sub = string.sub
local string_len = string.len

local setmetatable = setmetatable
local hook_Run = hook.Run
local SysTime = SysTime

local color_msg_time = { r = 100, g = 100, b = 100, a = 255 }
local color_msg_title = { r = 150, g = 150, b = 250, a = 255 }
local color_msg_text = { r = 220, g = 220, b = 220, a = 255 }

local type_to_color = {
    info = { r = 50, g = 150, b = 255, a = 255 },
    error = { r = 255, g = 100, b = 100, a = 255 },
    warn = { r = 200, g = 100, b = 50, a = 255 }
}

---@param msg_type "info" | "error" | "warn"
---@param msg_text string
---@param ... any
local function log_message( msg_type, msg_text, ... )
    MsgC( color_msg_time, string_format( "%s.%03d ", os.date( "%H:%M:%S" ), (SysTime() % 1) * 1000 ), color_msg_title, addon_name .. "@", type_to_color[ msg_type ], msg_type, color_msg_text, ": ", string_format( msg_text, ... ), "\n" )
end

if game.SinglePlayer() or (game.MaxPlayers() < 2) then
    log_message( "warn", "Turning off, singleplayer game cannot support community ban lists." )
    return
end

---@type table<string, integer>
local account_ids = {}

setmetatable( account_ids, {
    __index = function( self, steamid_str )
        local account_id

        local x, y, z = string_match( steamid_str, "STEAM_([0-5]):([01]):(%d+)" )
        if x == nil then
            account_id = math.max( 0, (tonumber( string_sub( steamid_str, 4 ), 10 ) or 0) - 61197960265728 )
        else
            account_id = (tonumber( z, 10 ) * 2) + (y == "1" and 1 or 0)
        end

        self[ steamid_str ] = account_id
        return account_id
    end
} )

timer.Create( addon_name .. "::Cache", 60, 0, function()
    table.Empty( account_ids )
end )

---@class CBanList
---@field Name string
---@field Message string
---@field InitTime number
---@field URL string
---@field Length integer
---@field Reasons table<integer, string>
local CBanList = {}
CBanList.__index = CBanList

do

    ---@class CBanList.Buffer
    ---@field list_name string
    ---@field list_length integer
    ---@field server_name string
    ---@field server_address string
    ---@field server_map string
    ---@field player_reason string
    ---@field player_steamid string
    ---@field player_nick string
    ---@field player_ip string
    local buffer = {
        server_address = game.GetIPAddress(),
        server_map = game.GetMap(),
    }

    local function formatter( str )
        return buffer[ string_lower( str ) ] or ("{{" .. str .. "}}")
    end

    ---@param ip string
    ---@param account_id integer
    ---@param nickname string
    function CBanList:getReason( ip, account_id, nickname )
        buffer.list_name = self.Name
        buffer.list_length = self.Length

        buffer.server_name = GetHostName()

        buffer.player_reason = self.Reasons[ account_id ] or "unknown"
        buffer.player_steamid = string_format( "U:1:%d", account_id )
        buffer.player_nick = nickname
        buffer.player_ip = ip

        local reason = string_gsub( self.Message, "{{([%w_]+)}}", formatter )
        return reason
    end

end

---@type table<integer, CBanList>
local banned = {}

do

    local hook_name = addon_name .. "::Connect" -- "Community Ban Lists::Connect"

    ---@param steamid64 string
    ---@param ip string
    ---@param nickname string
    hook.Add( "CheckPassword", hook_name, function( steamid64, ip, _, __, nickname )
        local account_id = account_ids[ steamid64 ]

        local ban_list = banned[ account_id ]
        if ban_list == nil or hook_Run( hook_name, ban_list, account_id, ip, nickname ) == false then return end

        local reason = ban_list:getReason( ip, account_id, nickname )
        return false, reason

        ---@diagnostic disable-next-line: undefined-global, redundant-parameter
    end, PRE_HOOK_RETURN or HOOK_MONITOR_HIGH )

end

---@param steamid string
---@param reason? string
function CBanList:insert( steamid, reason )
    local account_id = account_ids[ steamid ]

    if reason then
        self.Reasons[ account_id ] = reason
    end

    if banned[ account_id ] == nil then
        self.Length = self.Length + 1
        banned[ account_id ] = self
        return true
    end

    return false
end

---@param steamid string
function CBanList:remove( steamid )
    local account_id = account_ids[ steamid ]

    if banned[ account_id ] ~= nil then
        self.Length = self.Length - 1
        self.Reasons[ account_id ] = nil
        banned[ account_id ] = nil
        return true
    end

    return false
end

function CBanList:apply()
    for _, pl in player.Iterator() do
        local fn = pl.AccountID
        if fn ~= nil then
            local account_id = fn( pl )
            local ban_list = banned[ account_id ]
            if ban_list ~= nil then
                pl:Kick( ban_list:getReason( pl:IPAddress(), account_id, pl:Nick() ) )
            end
        end
    end
end

---@param data string
function CBanList:parse( data )
    data = string_gsub( data, "\r", "" )

    local strart_position, end_position, config = string_find( data, "<config>(.+)</config>", 1, false )
    if config ~= nil then
        data = string_sub( data, 1, strart_position - 1 ) .. string_sub( data, end_position + 1 )
        self.Name = string_match( config, "<name>(.+)</name>" ) or self.Name
        self.Message = string_gsub( string_gsub( string_match( config, "<message>(.+)</message>" ), "\n[ \t]+", "\n" ), "\n$", "" ) or self.Message
    end

    local sid

    for line in string_gmatch( data, "(.-)\n" ) do
        if string_len( line ) > 8 then
            line = string_gsub( line, "^%s*banid%s+%d+%s+", "" )
            strart_position, end_position, sid = string_find( line, "([%w_:]+)" )
            if sid ~= nil then
                line = string_sub( line, end_position + 1 )

                local reason = string_match( line, "^%s+%p+%s+(.+)%s*$" )
                if reason == nil then
                    reason = string_match( line, "^%s(.+)%s*$" )
                end

                self:insert( sid, reason )
            end
        end
    end

    log_message( "info", "Fetched %d banned users from '%s', took %0.3f seconds.", self.Length, self.Name, CurTime() - self.InitTime )
    self:apply()
end

function CBanList:fetch()
    local location = self.URL

    local file_path = string.match( location, "file://(.+)" )
    if file_path ~= nil then
        if not file.Exists( file_path, "GAME" ) then
            log_message( "error", "File '%s' does not exist.", file_path )
            return
        end

        file.AsyncRead( file_path, "GAME", function( _, _, status, content )
            if status == 0 then
                self:parse( content )
                return
            end

            log_message( "error", "File '%s' read failed with status: %d", file_path, status )
        end )

        return
    end

    http.Fetch( location, function( content, size, _, status )
        if status == 200 then
            if size == 0 then
                log_message( "error", "GET request to '%s' returned empty content.", location )
                return
            end

            self:parse( content )
            return
        end

        log_message( "error", "GET request to '%s' failed with status: %d", location, status )
    end, function( msg )
        log_message( "error", "GET request to '%s' failed with error: %s", location, msg )
    end )
end

---@param str string
---@return boolean
local function isURL( str )
    return string_match( str, "^%l[%l+-.]+%:[^%z\x01-\x20\x7F-\xFF\"<>^`:{-}]*$" ) ~= nil
end

---@type table<string, CBanList>
local ban_lists = {}

---@param url string
---@return CBanList
function util.CommunityBanList( url )
    assert( isURL( url ), string_format( "attempt to create ban list with invalid URL '%s'", url ) )

    ---@type CBanList
    local object = {
        InitTime = SysTime(),
        Name = string_gsub( url, "%w+://", "" ),
        Message = "Your SteamID is on the community ban list used on this server. Contact the server owner for more information.",
        URL = url,
        Reasons = {},
        Length = 0,
    }

    setmetatable( object, CBanList )
    object:fetch()
    return object
end

sql.Query( "CREATE TABLE IF NOT EXISTS community_ban_lists ( url TEXT PRIMARY KEY )" )

---@param url string
---@param no_warns? boolean
---@return boolean
local function sql_insert( url, no_warns )
    if not isURL( url ) then
        error( string_format( "attempt to insert invalid URL '%s'", url ), 2 )
    end

    local base64_str = util.Base64Encode( url, true )

    if sql.Query( "SELECT * FROM community_ban_lists WHERE url = '" .. base64_str .. "'" ) ~= nil then
        if not no_warns then
            log_message( "warn", "URL '%s' is already in the database, skipping insert.", url )
        end

        return false
    end

    if sql.Query( "INSERT OR IGNORE INTO community_ban_lists ( url ) VALUES ( '" .. base64_str .. "' )" ) == false then
        log_message( "error", "Failed to insert URL '%s' into the database, %s.", url, sql.LastError() or "unknown error" )
        return false
    end

    log_message( "info", "Successfully inserted URL '%s' into the database.", url )
    return true
end

---@param url string
---@param no_warns? boolean
---@return boolean
local function sql_delete( url, no_warns )
    if not isURL( url ) then
        error( string_format( "attempt to remove invalid URL '%s'", url ), 2 )
    end

    local base64_str = util.Base64Encode( url, true )

    if sql.Query( "SELECT * FROM community_ban_lists WHERE url = '" .. base64_str .. "'" ) == nil then
        if not no_warns then
            log_message( "warn", "URL '%s' is not in the database, skipping delete.", url )
        end

        return false
    end

    if sql.Query( "DELETE FROM community_ban_lists WHERE url = '" .. base64_str .. "'" ) == false then
        log_message( "error", "Failed to remove URL '%s' from the database, %s.", url, sql.LastError() )
        return false
    end

    log_message( "info", "Successfully removed URL '%s' from the database.", url )
    return true
end

---@class CBanList.Source
---@field url string

---@type string[]
local sources = {}

---@param file_path string
---@param no_warns boolean
---@return boolean
local function update_lists_from_file( file_path, no_warns )
    log_message( "info", "Updating ban lists from '%s'...", file_path )

    if not file.Exists( file_path, "GAME" ) then
        log_message( "warn", "No '%s' found, creating an empty file.", file_path )

        local file_name = string_match( file_path, "^data/([^/]+%.json)$" )
        if file_name ~= nil then
            file.Write( file_name, "[]" )
        end

        return false
    end

    local json = file.Read( file_path, "GAME" )
    if not isstring( json ) then
        log_message( "error", "Failed to read '%s', possibly corrupt or file system error.", file_path )
        return false
    end

    local data = util.JSONToTable( json )
    if not istable( data ) then
        log_message( "error", "Failed to parse '%s', file is not a valid JSON array.", file_path )
        return false
    end

    ---@cast data table

    local data_len = #data
    if data_len == 0 then
        if not no_warns then
            log_message( "warn", "JSON array in file '%s' is empty, no data to merge.", file_path )
        end

        return false
    end

    for i = 1, data_len, 1 do
        local source_url = data[ i ]
        if isURL( source_url ) then
            sql_insert( source_url, true )
        else
            log_message( "warn", "Invalid URL '%s' found in '%s', skipping.", source_url, file_path )
        end
    end

    return true
end

local function update_lists()
    update_lists_from_file( "data_static/community_ban_lists.json", false )
    update_lists_from_file( "data/community_ban_lists.json", false )

    log_message( "info", "Fetching ban lists from database..." )

    local result = sql.Query( "SELECT url FROM community_ban_lists" )
    if result == false then
        log_message( "error", "Failed to fetch ban lists from database." )
        return false
    end

    sources = {}

    if istable( result ) then
        ---@cast result CBanList.Source[]

        for i = 1, #result, 1 do
            sources[ i ] = util.Base64Decode( result[ i ].url )
        end
    else
        log_message( "warn", "No ban lists found in the database, using empty list." )
    end

    log_message( "info", "Initializing & clearing ban lists..." )

    table.Empty( ban_lists )
    table.Empty( banned )

    for i = 1, #sources, 1 do
        local source_url = sources[ i ]
        ban_lists[ source_url ] = util.CommunityBanList( source_url )
    end

    log_message( "info", "Got %d ban lists from database.", #sources )
end

---@class CBanList.Command
---@field name string
---@field fn fun( a: string, b: string ): string
---@field access "any" | "admin" | "superadmin" | "console"

local access_to_integer = {
    any = 0,
    admin = 1,
    superadmin = 2,
    console = 3,
}

---@type CBanList.Command[]
local commands = {
    {
        name = "all",
        fn = function()
            local lists_info = {}

            for url, list in pairs( ban_lists ) do
                lists_info[ #lists_info + 1 ] = string_format(
                    "%d. '%s' [%d banned] (%s)",
                    #lists_info + 1,
                    list.Name,
                    list.Length,
                    url
                )
            end

            return string_format(
                "\nTotal players banned: %d\nTotal lists: %d\n\nLists:\n%s\n",
                table.Count( banned ),
                #lists_info,
                table.concat( lists_info, "\n" )
            )
        end,
        access = "admin",
    },
    {
        name = "clr",
        fn = function()
            local count = table.Count( banned )
            if count == 0 then
                return "There are no banned players."
            end

            table.Empty( banned )

            return string_format(
                "Banned players cleaned up (%d players removed).",
                count
            )
        end,
        access = "superadmin",
    },
    {
        name = "rel",
        fn = function()
            update_lists()

            return string_format(
                "Started full update for %d ban lists, please wait...",
                #sources
            )
        end,
        access = "superadmin",
    },
    {
        name = "add",
        fn = function( url )
            if string.byte( url, 1, 1 ) == nil or not isURL( url ) then
                return string_format(
                    "URL '%s' is not valid, please provide a valid URL.",
                    url
                )
            end

            if sql_insert( url, true ) then
                return string_format(
                    "URL '%s' added to the ban list.",
                    url
                )
            end

            return string_format(
                "Failed to add URL '%s' to the ban list. %s.",
                url,
                sql.LastError()
            )
        end,
        access = "superadmin",
    },
    {
        name = "del",
        fn = function( url )
            if string.byte( url, 1, 1 ) == nil or not isURL( url ) then
                return string_format(
                    "URL '%s' is not valid, please provide a valid URL.",
                    url
                )
            end

            if sql_delete( url, true ) then
                return string_format( "URL '%s' removed from the ban list.", url )
            else
                return string_format( "Failed to remove URL '%s' from the ban list. %s.", url, sql.LastError() )
            end
        end,
        access = "superadmin",
    },
    {
        name = "who",
        fn = function( steamid )
            local account_id = account_ids[ steamid ]

            local ban_list = banned[ account_id ]
            if ban_list == nil then
                return string_format(
                    "Player '%s' is not banned.",
                    string_format( "U:1:%d", account_id )
                )
            end

            return string_format(
                "Player '%s' was banned in '%s'.",
                string_format( "U:1:%d", account_id ),
                ban_list.Name
            )
        end,
        access = "admin",
    }
}

for i = 1, #commands, 1 do
    local data = commands[ i ]

    local required_access = access_to_integer[ data.access ]
    local exec_fn = data.fn

    concommand.Add( "cbl." .. data.name, function( pl, _, args )
        if pl ~= nil and pl:IsValid() then
            local access_type = 0

            if pl:IsListenServerHost() then
                access_type = 3
            elseif pl:IsSuperAdmin() then
                access_type = 2
            elseif pl:IsAdmin() then
                access_type = 1
            end

            if access_type < required_access then
                pl:PrintMessage( 2, "[CBL] You do not have access to this command." )
                return
            end

            pl:PrintMessage( 2, "[CBL] " .. exec_fn( args[ 1 ] or "", args[ 2 ] or "" ) )
            return
        end

        log_message( "info", exec_fn( args[ 1 ] or "", args[ 2 ] or "" ) )
    end )
end

timer.Simple( 0, update_lists )
