if game.SinglePlayer() or game.MaxPlayers() < 2 then
	return
end
local lower, gsub, format, find, sub, match, Trim, gmatch
do
	local _obj_0 = string
	lower, gsub, format, find, sub, match, Trim, gmatch = _obj_0.lower, _obj_0.gsub, _obj_0.format, _obj_0.find, _obj_0.sub, _obj_0.match, _obj_0.Trim, _obj_0.gmatch
end
local SteamIDFrom64, SteamIDTo64
do
	local _obj_0 = util
	SteamIDFrom64, SteamIDTo64 = _obj_0.SteamIDFrom64, _obj_0.SteamIDTo64
end
local AsyncRead, Exists
do
	local _obj_0 = file
	AsyncRead, Exists = _obj_0.AsyncRead, _obj_0.Exists
end
local Fetch = http.Fetch
local Run = hook.Run
local isstring = isstring
local istable = istable
local SysTime = SysTime
local print = print
local addonName = "Community Ban Lists"
local bans, urls = { }, { }
local loadConfig
loadConfig = function()
	local fileName = gsub(lower(addonName), "[%s%p]+", "_") .. ".json"
	if Exists(fileName, "DATA") then
		local json = file.Read(fileName, "DATA")
		if isstring(json) then
			local data = util.JSONToTable(json)
			if istable(data) then
				return table.Merge(urls, data)
			end
		end
	else
		return file.Write(fileName, "[]")
	end
end
local List
do
	local _class_0
	local _base_0 = {
		GetReasonFormatter = function(self, data)
			return function(str)
				return data[lower(str)] or "{{" .. str .. "}}"
			end
		end,
		GetReason = function(self, player_ip, player_steamid64, player_nick)
			return gsub(self.Message, "{{([%w_]+)}}", self:GetReasonFormatter({
				list_name = self.Name,
				list_length = self.Length,
				server_address = game.GetIPAddress(),
				server_name = GetHostName(),
				server_map = game.GetMap(),
				player_reason = self.Reasons[player_steamid64] or "unknown",
				player_steamid = SteamIDFrom64(player_steamid64),
				player_steamid64 = player_steamid64,
				player_nick = player_nick,
				player_ip = player_ip
			}))
		end,
		Fetch = function(self, url)
			local filePath = match(url, "file://(.+)")
			if filePath and Exists(filePath, "GAME") then
				return AsyncRead(filePath, "GAME", function(_, __, code, data)
					if code ~= 0 then
						ErrorNoHaltWithStack(format("AsyncRead from '%s' failed with code: %d", filePath, code))
						return
					end
					return self:Parse(data)
				end)
			end
			return Fetch(url, function(data, _, __, code)
				if code ~= 200 then
					ErrorNoHaltWithStack(format("GET request to '%s' failed with code: %d", url, code))
					return
				end
				return self:Parse(data)
			end, function(msg)
				return ErrorNoHaltWithStack(format("GET request to '%s' failed with error: %s", url, msg))
			end)
		end,
		IsBanned = function(self, sid)
			return bans[sid] ~= nil
		end,
		AddSteamID = function(self, sid, reason)
			if find(sid, "^STEAM_%d+:%d+:%d+$") ~= nil then
				sid = SteamIDTo64(sid)
			end
			if bans[sid] == nil then
				bans[sid] = self
				self.Length = self.Length + 1
			end
			if reason then
				self.Reasons[sid] = reason
			end
		end,
		RemoveSteamID = function(self, sid)
			if find(sid, "^STEAM_%d+:%d+:%d+$") ~= nil then
				sid = SteamIDTo64(sid)
			end
			if bans[sid] ~= nil then
				self.Reasons[sid] = nil
				bans[sid] = nil
				self.Length = self.Length - 1
			end
		end,
		Perform = function(self)
			local _list_0 = player.GetHumans()
			for _index_0 = 1, #_list_0 do
				local ply = _list_0[_index_0]
				local player_steamid64 = ply:SteamID64()
				if self:IsBanned(player_steamid64) then
					ply:Kick(self:GetReason(ply:IPAddress(), player_steamid64, ply:Nick()))
				end
			end
		end,
		Parse = function(self, data)
			data = gsub(data, "\r", "")
			local startPos, endPos, config = find(data, "<config>(.+)</config>")
			if config ~= nil then
				data = sub(data, 1, startPos - 1) .. sub(data, endPos + 1)
				self.Name = match(config, "<name>(.+)</name>") or self.Name
				self.Message = Trim(gsub(gsub(match(config, "<message>(.+)</message>"), "\n[ \t]+", "\n"), "\n$", "")) or self.Message
			end
			for line in gmatch(data, "(.-)\n") do
				if #line < 8 then
					goto _continue_0
				end
				line = gsub(line, "^%s*banid%s+%d+%s+", "")
				local sid
				startPos, endPos, sid = find(line, "([%w_:]+)")
				if not (sid ~= nil) then
					goto _continue_0
				end
				line = sub(line, endPos + 1)
				local reason = match(line, "^%s+%p+%s+(.+)%s*$")
				if not (reason ~= nil) then
					reason = match(line, "^%s(.+)%s*$")
				end
				self:AddSteamID(sid, reason)
				::_continue_0::
			end
			print(format("[%s/%s] Added %d banned SteamID's, took %f seconds.", addonName, self.Name, self.Length, SysTime() - self.StartTime))
			return self:Perform()
		end
	}
	if _base_0.__index == nil then
		_base_0.__index = _base_0
	end
	_class_0 = setmetatable({
		__init = function(self, url)
			self.Message = "Your SteamID is on the community ban list used on this server. Contact the server owner for more information."
			self.Name = gsub(url, "%w+://", "")
			self.StartTime = SysTime()
			self.Reasons = { }
			self.Length = 0
			if isstring(url) then
				return self:Fetch(url)
			end
		end,
		__base = _base_0,
		__name = "List"
	}, {
		__index = _base_0,
		__call = function(cls, ...)
			local _self_0 = setmetatable({ }, _base_0)
			cls.__init(_self_0, ...)
			return _self_0
		end
	})
	_base_0.__class = _class_0
	List = _class_0
end
CommunityBanList = List
local loadLists
loadLists = function()
	for _index_0 = 1, #urls do
		local url = urls[_index_0]
		List(url)
	end
	Run("CBL:Reload")
	return
end
timer.Simple(0, loadLists)
loadConfig()
hook.Add("CheckPassword", addonName, function(player_steamid64, player_ip, _, __, player_nick)
	local list = bans[player_steamid64]
	if not list then
		return
	end
	if Run("CBL:Connect", list, player_steamid64, player_ip, player_nick) ~= false then
		return
	end
	return false, list:GetReason(player_ip, player_steamid64, player_nick)
end)
return concommand.Add("cbl_reload", function(self)
	if IsValid(self) and not self:IsSuperAdmin() then
		return
	end
	table.Empty(bans)
	loadConfig()
	return loadLists()
end)
