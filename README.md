# Community Ban Lists
Garry's Mod global ban system based on public lists.

## Where is Lua code?
Written in [Yuescript](https://github.com/pigpigyyy/Yuescript), compiled Lua code can be found in [releases](https://github.com/Pika-Software/community-ban-lists/releases), or you can compile it yourself using compiled [Yuescript Compiler](https://github.com/pigpigyyy/Yuescript/releases/latest).

### Usage
Simply add your banlist urls to the json list in the `data/community_ban_lists.json` file.
#### Example:
![image](https://github.com/Pika-Software/community-ban-lists/assets/44779902/c66b1b21-27a5-4bf4-983d-09fbb7266bde)

### List config
```
<config>
    <name>My List</name>
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
    <name>My List</name>
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
