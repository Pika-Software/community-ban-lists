# Community Ban Lists
Garry's Mod global ban system based on public lists.

### List config
```
<config>
    <title>My List</title>
    <message>
        Your SteamID is on the community ban list used on this server. Contact the server owner for more information.
    </message>
</config>

... banned steamids
```

### Disconnect message tags
#### Usage example
```
<config>
    <title>My List</title>
    <message>
        Hello {{player_nick}}!
    </message>
</config>

... banned steamids
```

#### Ban List
- `list_name` - Ban list name
- `list_length` - Banned player count

#### Server
- `server_address` - Server address
- `server_name` - Server name
- `server_map` - Current server map

#### Banned Player
- `player_reason` - Banned player ban reason
- `player_steamid` - Banned player steamid
- `player_steamid64` - Banned player steamid64
- `player_nick` - Banned player nickname
- `player_ip` - Banned player ip address
