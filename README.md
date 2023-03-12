# Community Ban Lists - Core
 Garry's Mod global ban system based on public lists.

## How to create your first ban list
- Install this addon from [Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=2878187032) or [GitHub](https://github.com/Pika-Software/gmod_community_ban_lists)
- Create empty folder in **Garry's Mod/garrysmod/addons**
- In this folder create file by path **/lua/community_bans/lists/{your_ban_list_short_name}.lua**
- In this file write your settings, example
```lua
 Name = 'My Awesome Ban List'
 Source = 'https://your-host.com/my_awesome_ban_list.txt'
 ReasonSeparator = ' - '
 Message = [[
     Hello {nickname},
     your account has been blocked on this server,
     please contact with us to know your block reason.
    
     my_awesome_support@email.com
 ]]
```

### Disconnect message tags:
- **{nickname}** - Steam nickname of the blocked player
- **{steamid64}** - SteamID64 of the blocked player
- **{ip}** - IP address of the blocked player
- **{listname}** - Ban list name
- **{serverip}** - Server address
- **{servername}** - Server name
- **{steamid}** - SteamID of the blocked player
- **{reason}** - Reason why this player is blocked
