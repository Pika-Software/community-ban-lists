# Community Ban Lists - Core
 Garry's Mod global ban system based on public lists.

## How to create your first ban list
- Install [Community Ban Lists](https://github.com/Pika-Software/gmod_community_ban_lists)
- Create empty folder in Garry's Mod/garrysmod/addons
- In this folder create file by path /lua/community_bans/lists/{your_ban_list_short_name}.lua
- In this file write your settings, example
```lua
 Name = 'My Awesome Ban List'
 Source = 'https://your-host.com/my_awesome_ban_list.txt'
 Silent = false
 Reason = [[
     Hello {nickname},
     your account has been blocked on this server,
     please contact with us to know your block reason.
    
     my_awesome_support@email.com
 ]]
```
- All extra reason tags: {nickname}, {steamid64}, {ip}, {listname}, {serverip}, {servername}, {steamid}
