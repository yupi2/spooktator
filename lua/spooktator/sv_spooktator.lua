util.AddNetworkString("PlayerUpdateGhostState")
util.AddNetworkString("PlayerBatchUpdateGhostState")

local clamp = math.Clamp

local PlayerMTbl = FindMetaTable("Player")

function PlayerMTbl:GetFancyGhostState()
	return self.isFancyGhost == true
end

function PlayerMTbl:SetFancyGhostState(boolean)
	self.isFancyGhost = boolean

	if self:GetGhostState() then
		self:SetBodygroup(1, boolean and 1 or 0)
	end
end

local function getPlayerGroup(plr)
	-- ULib/ULX thing
	if plr.GetUserGroup then
		return plr:GetUserGroup()
	end

	-- Insert other group stuff here.
	-- I haven't used anything other than ULib/ULX so I can't be bothered.
end

local function randomChance(percent)
	return (clamp(randomChance(ret), 0, 100) >= math.random(1, 100))
end

local function PlayerGetFancyConfigChance(plr)
	local chance = spooktator.cfg.fancy.player_chance[plr:SteamID()]
	if isnumber(chance) then
		return clamp(chance, 0, 100)
	end

	chance = spooktator.cfg.fancy.group_chance[getPlayerGroup(plr)]
	if isnumber(chance) then
		return clamp(chance, 0, 100)
	end

	return clamp(spooktator.cfg.fancy.chance, 0, 100)
end

local function PlayerWillBeFancy(plr)
	local retPre = hook.Call("PrePlayerFancyChance", nil, plr)
	if isnumber(retPre) then
		return randomChance(retPre)
	end

	local chance = PlayerGetFancyConfigChance(plr)

	local retPost = hook.Call("PostPlayerFancyChance", nil, plr, chance)
	if isnumber(retPost) then
		chance = retPost
	end

	return randomChance(chance)
end

hook.Add("PlayerInitialSpawn", "setup fancy stuff", function(plr)
	plr:SetFancyGhostState(PlayerWillBeFancy(plr))
end)

hook.Add("TTTBeginRound", "setup fancy stuff", function()
	for k,v in ipairs(player.GetAll()) do
		v:SetFancyGhostState(PlayerWillBeFancy(v))
	end
end)

hook.Add("PlayerSetModel", "Ghost model", function(plr)
	if plr:GetGhostState() then
		plr:SetModel("models/UCH/mghost.mdl")
		plr:SetBodygroup(1, plr:GetFancyGhostState() and 1 or 0)
	end
end)

-- If plr is not valid then the batch is sent to all players.
local function PlayerBatchUpdateGhostState(plr,)
	local plrs = player.GetAll()
	local count = #plrs

	if count >= 255 then
		error("what the literal fuck?")
	end

	net.Start("PlayerBatchUpdateGhostState")
	net.WriteUInt(count, 8)

	for k,v in ipairs(plrs) do
		net.WriteEntity(v)
		net.WriteBool(v:GetGhostState())
	end

	if IsValid(plr) then
		net.Send(plr)
	else
		net.Broadcast()
	end
end

hook.Add("PlayerInitialSpawn", "Batch update ghosts", function(plr)
	PlayerBatchUpdateGhostState(plr)
end)

-- A hook called before TTTPrepareRound and player spawns.
hook.Add("TTTDelayRoundStartForVote", "make everyone nots ghosties", function()
	for k,v in ipairs(player.GetAll()) do
		-- The second argument (the "true" boolean) disables the
		-- net-message that is done inside of the GhostSet function.
		-- This is done so we can batch update this shit
		v:SetGhostState(false, true)
	end

	PlayerBatchUpdateGhostState(nil)
end)

-- I should probably just use ULib/ULX for this...
local function PlayerFancyGhostCommand(plr, cmd, argtbl, argstr)
	if not IsValid(plr) then return end

	if argstr ~= "" then
		if not plr:IsSuperAdmin() then
			return
		end

		local userid = tonumber(argstr)
		if userid == nil then
			plr:PrintMessage(HUD_PRINTTALK, "Invalid user-id")
			return
		end

		local tgt = player.GetByID(userid)
		if not (IsValid(tgt) and tgt:IsPlayer()) then
			plr:PrintMessage(HUD_PRINTTALK, "Invalid player")
			return
		end

		tgt:SetFancyGhostState(not tgt:GetFancyGhostState())
		return
	end

	plr:SetFancyGhostState(not plr:GetFancyGhostState())
end

if spooktator.cfg.fancy.enable_secret_command == true then
	local fancycmd = spooktator.cfg.fancy.secret_command
	concommand.Add(fancycmd, PlayerFancyGhostCommand)

	hook.Add("PlayerSay", "Ghost fancy toggle", function(plr, text, isteam)
		if text[1] ~= "/" and text[1] ~= "!" then return end

		if string.find(text, fancycmd, 2, true) == 2 then
			local argstr = ""
			local spaceIndex = fancycmd:len() + 2

			if string.sub(text, spaceIndex, spaceIndex) == ' ' then
				argstr = string.sub(text, spaceIndex + 1)
			end

			PlayerFancyGhostCommand(plr, nil, nil, argstr)
			return ""
		end
	end)
end

local function PlayerGhostify(plr)
	plr:SetRagdollSpec(false)
	plr:Spectate(OBS_MODE_ROAMING)
	plr:SpectateEntity(nil)
	plr:SetGhostState(true)
	plr:Spawn()
end

local function PlayerUnGhostify(plr)
	plr:SetGhostState(false)
	plr:Kill()
	plr:SetRagdollSpec(false)
	plr:Spectate(OBS_MODE_ROAMING)
	plr:SpectateEntity(nil)
end

local function PlayerToggleGhost(plr)
	if not IsValid(plr) then return end

	if plr:GetGhostState() then
		PlayerUnGhostify(plr)
	else
		PlayerGhostify(plr)
	end
end

for k,v in ipairs(spooktator.cfg.commands) do
	concommand.Add(v, PlayerToggleGhost, nil, "toggle spooky ghost")
end

hook.Add("PlayerSay", "Ghost toggle", function(plr, text, isteam)
	if text[1] ~= "/" and text[1] ~= "!" then return end

	for k,v in ipairs(spooktator.cfg.commands) do
		if string.find(text, v, 2, true) == 2 then
			PlayerToggleGhost(plr)
			return ""
		end
	end
end)

hook.Add("CanPlayerSuicide", "Toggle ghost on kill-bind", function(plr)
	if plr:Team() == TEAM_SPEC then
		PlayerToggleGhost(plr)
	end
end)

hook.Add("PostPlayerDeath", "playe die thing", function(plr)
	if not spooktator.cfg.spawn_as_ghost then return end
	if plr:GetInfoNum("spawnasghost", 0) == 1 then
		PlayerGhostify(plr)
	end
end)
