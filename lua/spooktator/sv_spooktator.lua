util.AddNetworkString("PlayerGhostUpdate")
util.AddNetworkString("PlayerGhostUpdateBatch")

local PlayerMTbl = FindMetaTable("Player")

function PlayerMTbl:GhostFancyGet()
	return self.isFancyGhost == true
end

function PlayerMTbl:GhostFancySet(boolean)
	self.isFancyGhost = boolean

	if self:GhostGet() then
		self:SetBodygroup(1, boolean and 1 or 0)
	end
end

hook.Add("PlayerSetModel", "Ghost model", function(plr)
	if plr:GhostGet() then
		plr:SetModel("models/UCH/mghost.mdl")
		plr:SetBodygroup(1, plr:GhostFancyGet() and 1 or 0)
	end
end)

-- If plr is not valid then the batch is sent to all players.
-- If boolean's type is "boolean" then that is sent as the player's
-- ghost-state instead of using v:GhostGet().
local function batchUpdatePlayerGhostState(plr, boolean)
	local plrs = player.GetAll()
	local count = #plrs

	if count >= 255 then
		error("what the literal fuck?")
	end

	net.Start("PlayerGhostUpdateBatch")
		net.WriteUInt(count, 8)

	if isbool(boolean) then
		for k,v in ipairs(plrs) do
			net.WriteEntity(v)
			net.WriteBool(boolean)
		end
	else
		for k,v in ipairs(plrs) do
			net.WriteEntity(v)
			net.WriteBool(v:GhostGet())
		end
	end

	if IsValid(plr) then
		net.Send(plr)
	else
		net.Broadcast()
	end
end

hook.Add("PlayerInitialSpawn", "Batch update ghosts", function(plr)
	batchUpdatePlayerGhostState(plr)
end)

-- A hook called before TTTPrepareRound and player spawns.
hook.Add("TTTDelayRoundStartForVote", "make everyone nots ghosties", function()
	for k,v in ipairs(player.GetAll()) do
		-- The second argument (the "true" boolean) disables the
		-- net-message that is done inside of the GhostSet function.
		-- This is done so we can batch update this shit
		v:GhostSet(false, true)
	end

	batchUpdatePlayerGhostState(nil, false)
end)

local function PlayerGhostFancyCommand(plr, cmd, argtbl, argstr)
	if not IsValid(plr) then return end

	if argstr ~= "" then
		--if not plr:IsSuperAdmin() then
			--plr:message about asldjkalsdjklasjdklasjd
		--end

		local userid = tonumber(argstr)
		if userid == nil then
			plr:message baouaotoia sudi uoasid
		end

		local tgt = player.GetByID(userid)
		if not (IsValid(tgt) and tgt:IsPlayer()) then
			plr:mesagakjlkj
		end

		
	end

	
end

if spooktator.cfg.fancy.enable_secret_command == true then
	local shorter = spooktator.cfg.fancy.secret_command
	concommand.Add(shorter, PlayerGhostFancyCommand)

	hook.Add("PlayerSay", "Ghost fancy toggle", function(plr, text, isteam)
		if text[1] ~= "/" and text[1] ~= "!" then return end

		if string.find(text, shorter, 2, true) == 2 then
			local argstr = ""
			local spaceIndex = shorter:len() + 2

			if string.sub(text, spaceIndex, spaceIndex) == ' ' then
				argstr = string.sub(text, spaceIndex + 1)
			end

			PlayerGhostFancyCommand(plr, nil, nil, argstr)
			return ""
		end
	end)
end

local function PlayerGhostToggle(plr)
	if not IsValid(plr) then return end

end

for k,v in ipairs(spooktator.cfg.commands) do
	concommand.Add(v, PlayerGhostToggle, nil, "toggle spooky ghost")
end

hook.Add("PlayerSay", "Ghost toggle", function(plr, text, isteam)
	if text[1] ~= "/" and text[1] ~= "!" then return end

	for k,v in ipairs(spooktator.cfg.commands) do
		if string.find(text, v, 2, true) == 2 then
			PlayerGhostToggle(plr)
			return ""
		end
	end
end)
