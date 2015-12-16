util.AddNetworkString("PlayerUpdateGhostState")
util.AddNetworkString("PlayerBatchUpdateGhostState")
util.AddNetworkString("gimmebatchupdate")

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
	return (clamp(percent, 0, 100) >= math.random(1, 100))
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

-- Setup each player's fanciness for the round.
hook.Add("TTTBeginRound", "setup fancy stuff", function()
	for k,v in ipairs(player.GetAll()) do
		v:SetFancyGhostState(PlayerWillBeFancy(v))
	end
end)

-- Ghost model stuff.
-- TODO: Make sure it works.
hook.Add("PlayerSetModel", "Ghost model", function(plr)
	if plr:GetGhostState() then
		plr:SetModel("models/UCH/mghost.mdl")
		plr:SetBodygroup(1, plr:GetFancyGhostState() and 1 or 0)
	end
end)

hook.Add("PlayerSpawn", "Ghost spawn", function(plr)
	if plr:GetGhostState() then
		plr:UnSpectate()
		hook.Call("PlayerSetModel", GAMEMODE, plr)
	--else
	--	plr:SetBloodColor(0)
	end
end)

-- This function sends every player's ghost-state to the plr entity.
-- If plr is not valid then the batch is sent to every player.
local function PlayerBatchUpdateGhostState(plr)
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

-- A player sends this message when their client isn't
-- going to break for receiving net-messages.
net.Receive("gimmebatchupdate", function(size, plr)
	if IsValid(plr) then
		PlayerBatchUpdateGhostState(plr)
		plr:SetFancyGhostState(PlayerWillBeFancy(plr))
	end
end)

-- This hook is called right before players are spawned in the TTTPrepareRound
-- gamemode function. We resend ghost-states to fix models or whatever.
hook.Add("TTTDelayRoundStartForVote", "make everyone nots ghosties", function()
	for k,v in ipairs(player.GetAll()) do
		-- The second argument (the "true" boolean) disables the
		-- net-message that is done inside of the GhostSet function.
		-- This is done so we can batch update this shit
		v:SetGhostState(false, true)
	end

	PlayerBatchUpdateGhostState(nil)
end)

-- Command for a player to use to change their fanciness.
-- Also with the possibility to change someone else's with a user-id.
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
	plr:SetGhostState(true)
	plr:Spawn()
end

local function PlayerUnGhostify(plr)
	plr:SetGhostState(false)
	plr.diedAsGhost = true
	plr:Kill()
	plr:Spectate(OBS_MODE_ROAMING)
end

local function PlayerToggleGhost(plr)
	if not IsValid(plr) then return end
	if plr:Team() ~= TEAM_SPEC then return end

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

-- Only players on the terrorist team can suicide so we don't
-- have to do anything here to prevent it.
hook.Add("CanPlayerSuicide", "Toggle ghost on kill-bind", function(plr)
	if plr:Team() == TEAM_SPEC then
		PlayerToggleGhost(plr)
	end
end)

hook.Add("PostPlayerDeath", "playe die thing", function(plr)
	if plr.diedAsGhost then
		plr.diedAsGhost = nil
		return
	end

	if not spooktator.cfg.spawn_as_ghost then return end
	if plr:GetInfoNum("spawnasghost", 0) ~= 1 then return end

	local state = GetRoundState()
	if state == ROUND_ACTIVE or state == ROUND_POST then
		PlayerGhostify(plr)
	end
end)

local deathbadgehook = util.noop
local function dbhReplacement(vic, att, dmg)
	if vic.diedAsGhost then return end
	deathbadgehook(vic, att, dmg)
end

local killcamhook = util.noop
local function kchReplacement(vic, att, dmg)
	if vic.diedAsGhost then return end
	killcamhook(vic, att, dmg)
end

-- We overwrite some other addon's hooks so they don't
-- execute if the player used their kill bind to toggle ghost.
timer.Create("player death things", 1, 1, function()
	local tbl = hook.GetTable()
	local dpd = tbl["DoPlayerDeath"]
	if dpd then
		deathbadgehook = dpd["DMSG.SV"]
		if deathbadgehook then
			hook.Add("DoPlayerDeath", "DMSG.SV", dbhReplacement)
		end

		killcamhook = dpd["WKC_SendKillCamData"]
		if killcamhook then
			hook.Add("DoPlayerDeath", "WKC_SendKillCamData", kchReplacement)
		end
	end
end)
