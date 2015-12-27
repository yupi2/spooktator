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

function PlayerMTbl:Ghostify()
	if self:GetGhostState() then return end

	self:SetRagdollSpec(false)
	self:SetGhostState(true)
	self:Spawn()
	self:SetNotSolid(true)
end

function PlayerMTbl:UnGhostify()
	if not self:GetGhostState() then return end

	self:SetNotSolid(false)
	self:SetGhostState(false)
	self.diedAsGhost = true
	self:Kill()
end

function PlayerMTbl:ToggleGhost()
	if self:Team() ~= TEAM_SPEC then return end

	if self:GetGhostState() then
		self:UnGhostify()
	else
		self:Ghostify()
	end
end

local function playerGroup(plr)
	-- ULib/ULX thing
	if plr.GetUserGroup then
		return plr:GetUserGroup()
	end

	-- Insert other group stuff here.
	-- I haven't used anything other than ULib/ULX so I can't be bothered.
end

local function maybe(percent)
	-- percent of 100 always returns true.
	-- percent of 0 always returns false.
	return (clamp(percent, 0, 100) >= math.random(1, 100))
end

local function willPlayerBeFancy(plr)
	local chance = spooktator.cfg.fancy.player_chance[plr:SteamID()]

	if not isnumber(chance) then
		chance = spooktator.cfg.fancy.group_chance[playerGroup(plr)]
		if not isnumber(chance) then
			chance = spooktator.cfg.fancy.chance
		end
	end

	return maybe(chance)
end

hook.Add("OnPlayerHitGround", "Ghost fall damage", function(plr)
	if plr:GetGhostState() then
		return true -- block
	end
end)

-- Setup each player's fanciness for the round.
hook.Add("TTTBeginRound", "Ghost fanciness setup", function()
	for k,v in ipairs(player.GetAll()) do
		v:SetFancyGhostState(willPlayerBeFancy(v))
	end
end)

local function ghostModelStuff(plr)
	plr:SetModel("models/UCH/mghost.mdl")
	plr:SetBodygroup(1, plr:GetFancyGhostState() and 1 or 0)
end

hook.Add("PlayerSpawn", "Ghost spawn", function(plr)
	if plr:GetGhostState() then
		plr:UnSpectate()
		timer.Simple(1, function()
			if IsValid(plr) and plr:IsPlayer() and plr:GetGhostState() then
				ghostModelStuff(plr)
			end
		end)
	end
end)

hook.Add("EntityTakeDamage", "ghostie ghost", function(ent, dmg)
	if ent:IsPlayer() and ent:GetGhostState() then
		return true -- block damage
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
		-- net-message that is done inside of the SetGhostState function.
		-- This is done so we can batch update this shit.
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

		local tgt = Player(userid)
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
			local userid = ""
			-- "ohyaknow 13"
			--           ^^--- example userid we'll try to clip out
			--          ^--- the location spaceIndex points to
			--  ^^^^^^^^--- the fancycmd
			local spaceIndex = fancycmd:len() + 1

			if string.sub(text, spaceIndex, spaceIndex) == ' ' then
				userid = string.sub(text, spaceIndex + 1)
			end

			PlayerFancyGhostCommand(plr, nil, nil, userid)
			return ""
		end
	end)
end

for k,v in ipairs(spooktator.cfg.commands) do
	concommand.Add(v, PlayerMTbl.ToggleGhost, nil, "toggle spooky ghost")
end

hook.Add("PlayerSay", "Ghost toggle", function(plr, text, isteam)
	if text[1] ~= "/" and text[1] ~= "!" then return end

	for k,v in ipairs(spooktator.cfg.commands) do
		if string.find(text, v, 2, true) == 2 then
			plr:ToggleGhost()
			return ""
		end
	end
end)

-- Only players on the terrorist team can suicide so we don't
-- have to do anything here to prevent it.
hook.Add("CanPlayerSuicide", "Toggle ghost on kill-bind", function(plr)
	if plr:Team() == TEAM_SPEC then
		plr:ToggleGhost()
	end
end)

local function shouldSpawnAsGhost(plr)
	if plr.diedAsGhost then return false end
	if not spooktator.cfg.spawn_as_ghost then return false end
	if plr:GetInfoNum("spawnasghost", 0) ~= 1 then return false end

	local state = GetRoundState()
	return (state == ROUND_ACTIVE or state == ROUND_POST)
end

hook.Add("PostPlayerDeath", "playe die thing", function(plr)
	if plr.diedAsGhost then
		plr.diedAsGhost = nil
		return
	end

	if shouldSpawnAsGhost(plr) then
		plr:Ghostify()
	end
end)

local noop = function() end

local deathbadgehook = noop
local function dbhReplacement(vic, att, dmg)
	if vic.diedAsGhost then return end
	deathbadgehook(vic, att, dmg)
end

local killcamhook = noop
local function kchReplacement(vic, att, dmg)
	if not shouldSpawnAsGhost(plr) then
		killcamhook(vic, att, dmg)
	end
end

-- We overwrite some other addon's hooks so they don't
-- execute if the player used their kill bind to toggle ghost.
hook.Add("Initialize", "player death things", function()
	local dpd = hook.GetTable()["DoPlayerDeath"]
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

	GAMEMODE.oldKeyPress = GAMEMODE.KeyPress
	function GAMEMODE:KeyPress(plr, key)
		if IsValid(plr) and plr:GetGhostState() then return end
		return self:oldKeyPress(plr, key)
	end

	GAMEMODE.oldSpectatorThink = GAMEMODE.SpectatorThink
	function GAMEMODE:SpectatorThink(plr)
		if IsValid(plr) and plr:GetGhostState() then return true end
		self:oldSpectatorThink(plr)
	end

	GAMEMODE.oldPlayerCanPickupWeapon = GAMEMODE.PlayerCanPickupWeapon
	function GAMEMODE:PlayerCanPickupWeapon(plr, wep)
		if not IsValid(plr) or not IsValid(wep) then return end
		if plr:GetGhostState() then return end
		return self:oldPlayerCanPickupWeapon(plr, wep)
	end

	PlayerMTbl.oldSpawnForRound = PlayerMTbl.SpawnForRound
	function PlayerMTbl:SpawnForRound(dead_only)
		if self:GetGhostState() then
			self:UnGhostify()
		end
		return self:oldSpawnForRound(dead_only)
	end

	PlayerMTbl.oldResetRoundFlags = PlayerMTbl.ResetRoundFlags
	function PlayerMTbl:ResetRoundFlags()
		if self:GetGhostState() then return end
		self:oldResetRoundFlags()
	end

	PlayerMTbl.oldSpectate = PlayerMTbl.Spectate
	function PlayerMTbl:Spectate(mode)
		if self:GetGhostState() then return end
		return self:oldSpectate(mode)
	end

	GAMEMODE.oldGiveLoadout = GAMEMODE.PlayerLoadout
	function GAMEMODE:PlayerLoadout(plr)
		if plr:GetGhostState() then return end
		self:oldGiveLoadout(plr)
	end

	KARMA.oldHurt = KARMA.Hurt
	function KARMA.Hurt(attacker, victim, dmginfo)
		if not (IsValid(attacker) and IsValid(victim)) then return end
		if attacker == victim then return end
		if not (attacker:IsPlayer() and victim:IsPlayer()) then return end
		if attacker:GetGhostState() or victim:GetGhostState() then return end
		return KARMA.oldHurt(attacker, victim, dmginfo)
	end
end)

hook.Add("TTTBeginRound", "unknown ghost thing", function()
	for k,v in ipairs(player.GetAll()) do
		v:SetNWBool("SpawnedForRound", (v:Alive() and not v:GetGhostState()))
	end
end)

-- too many damn scripts override this function on Initialize
-- so I had the idea of putting this here
hook.Add("TTTBeginRound", "TTTBeginRound_Ghost", function()
	oldHasteMode = HasteMode
	GAMEMODE.oldPlayerDeath = GAMEMODE.PlayerDeath
	function GAMEMODE:PlayerDeath(plr, infl, attacker)
		if plr:GetGhostState() then
			HasteMode = function()
				return false
			end
		end
		self:oldPlayerDeath(plr, infl, attacker)
		HasteMode = oldHasteMode
	end
	hook.Remove("TTTBeginRound", "TTTBeginRound_Ghost")
end)

-- The only sounds I know of to block are water sounds.
local sounds_to_block = {
	"player/footsteps/wade",
	"player/footsteps/slosh",
}

hook.Add("EntityEmitSound", "Block sounds originating from ghosts", function(tbl)
	local ent = tbl.Entity
	local soundName = tbl.SoundName
	if IsValid(ent) and ent:IsPlayer() and ent:GetGhostState() then
		for k,v in ipairs(sounds_to_block) do
			if string.find(soundName, v, 1, true) ~= nil then
				return false
			end
		end
	end
end)
