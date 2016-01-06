util.AddNetworkString("GhostStateUpdateSingle")
util.AddNetworkString("GhostStateUpdateBatch")
util.AddNetworkString("GhostStateUpdateBatchRequest")

local clamp = math.Clamp

local PlayerMTbl = FindMetaTable("Player")

local function ghostsAreAllowed()
	local state = GetRoundState()
	return (state == ROUND_ACTIVE or state == ROUND_POST)
end

local function shouldSpawnAsGhost(plr)
	-- This flag is checked to see if plr is toggling out of ghost-mode.
	if plr.diedAsGhost then
		return false
	end

	if not spooktator.cfg.spawn_as_ghost then
		return false
	end

	-- Client-side CVar to enable/disable ghost-mode.
	if plr:GetInfoNum("spawnasghost", 0) ~= 1 then
		return false
	end

	return true
end

function PlayerMTbl:IsFancyGhost()
	return self.isFancyGhost == true
end

function PlayerMTbl:SetFancyGhostState(boolean)
	self.isFancyGhost = boolean

	if self:IsGhost() then
		-- Bodygroup value 1 for fancy. Value 0 for non-fancy.
		self:SetBodygroup(1, boolean and 1 or 0)
	end
end

function PlayerMTbl:Ghostify()
	if self:IsGhost() then
		return
	end

	self:SetRagdollSpec(false)
	self:SetGhostState(true)
	self:Spawn()
	-- Have projectiles and melee pass through.
	self:SetNotSolid(true)
end

function PlayerMTbl:UnGhostify()
	if not self:IsGhost() then
		return
	end

	-- Re-enable projectile/melee collision.
	self:SetNotSolid(false)
	self:SetGhostState(false)
	-- This flag is set so hooks called on a player's death won't
	-- respawn ghosts or do any silly killcam/deathbadge stuff.
	self.diedAsGhost = true
	self:Kill()
end

function PlayerMTbl:ToggleGhost()
	if self:IsGhost() then
		self:UnGhostify()
	else
		self:Ghostify()
	end
end

local function playerGroup(plr)
	-- ULib/ULX and maestro
	if plr.GetUserGroup then
		return plr:GetUserGroup()
	end

	-- Insert other group stuff here.
	-- I haven't used anything other than ULib/ULX so I can't be bothered.

	return "user"
end

local function maybe(percent)
	-- percent of 100 always returns true.
	-- percent of 0 always returns false.
	return (clamp(percent, 0, 100) >= math.random(1, 100))
end

-- Uses the fancy config values in "sv_config.lua" to determine
--  if the player will be fancy for the round.
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

-- Setup each player's fanciness for the round.
hook.Add("TTTBeginRound", "Do some ghost stuff", function()
	for k,v in ipairs(player.GetAll()) do
		v:SetNWBool("SpawnedForRound", (v:Alive() and not v:IsGhost()))
		v:SetFancyGhostState(willPlayerBeFancy(v))
	end
end)

-- This function sends every player's ghost-state to the messageTarget player.
-- If the messageTarget parameter was not passed then the batch is sent to
--  every player.
local function GhostStateUpdateBatch(messageTarget)
	local plrs = player.GetAll()

	net.Start("GhostStateUpdateBatch")
	net.WriteUInt(count, #plrs)

	for k,v in ipairs(plrs) do
		net.WriteEntity(v)
		net.WriteBool(v:IsGhost())
	end

	if IsValid(messageTarget) then
		net.Send(messageTarget)
	else
		net.Broadcast()
	end
end

-- A player sends this message when their client isn't
--  going to break for receiving net-messages.
net.Receive("GhostStateUpdateBatchRequest", function(size, plr)
	if IsValid(plr) then
		GhostStateUpdateBatch(plr)
		plr:SetFancyGhostState(PlayerWillBeFancy(plr))
	end
end)

-- This hook is called right before players are spawned in the TTTPrepareRound
--  gamemode function. We resend ghost-states to fix models or whatever.
hook.Add("TTTDelayRoundStartForVote", "make everyone nots ghosties", function()
	for k,v in ipairs(player.GetAll()) do
		-- The second argument (the "true" boolean) disables the
		--  net-message that is done inside of the SetGhostState function.
		-- This is done so we can batch update this shit.
		v:SetGhostState(false, true)

		-- Clear this flag.
		v.diedAsGhost = nil
	end

	GhostStateUpdateBatch(nil)
end)

-- Set the ghost's model.
hook.Add("PlayerSpawn", "Ghost spawn", function(plr)
	if plr:IsGhost() then
		plr:UnSpectate()

		local timerid = "ghostmodel" .. plr:SteamID()
		if timer.Exists(timerid) then
			timer.Remove(timerid)
		end

		timer.Create(timerid, 1, 1, function()
			if IsValid(plr) and plr:IsPlayer() and plr:IsGhost() then
				plr:SetModel("models/UCH/mghost.mdl")
				-- Setup the fancy-ghost bodygroup.
				plr:SetFancyGhostState(plr:IsFancyGhost())
			end
		end)
	end
end)

hook.Add("EntityTakeDamage", "No damage for ghosts", function(ent, dmg)
	if ent:IsPlayer() and ent:IsGhost() then
		return true -- block damage
	end
end)

hook.Add("OnPlayerHitGround", "Ghost fall damage", function(plr)
	if plr:IsGhost() then
		return true -- block
	end
end)

-- Only players on the terrorist team can suicide so we don't
--  have to do anything here to prevent it.
hook.Add("CanPlayerSuicide", "Toggle ghost on kill-bind", function(plr)
	if plr:Team() == TEAM_SPEC and ghostsAreAllowed() then
		plr:ToggleGhost()
	end
end)

hook.Add("PostPlayerDeath", "ghost die thing", function(plr)
	if plr.diedAsGhost then
		plr.diedAsGhost = nil
		return
	end

	if ghostsAreAllowed() and shouldSpawnAsGhost(plr) then
		plr:Ghostify()
	end
end)

-- NOTE: The local player must be a superadmin.
-- Usage in console:
-- <command>
--   This toggles fancy on the local player.
-- <command> <user-id>
--   This toggles fancy on the player given.\
--   You can get user-id's from the console command "status".
local function PlayerFancyGhostCommand(plr, cmd, argtbl, argstr)
	if not (IsValid(plr) and plr:IsSuperAdmin()) then
		return
	end

	if argstr ~= "" then
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

		tgt:SetFancyGhostState(not tgt:IsFancyGhost())
		return
	end

	plr:SetFancyGhostState(not plr:IsFancyGhost())
end

local fancycmd = spooktator.cfg.fancy.command
concommand.Add(fancycmd, PlayerFancyGhostCommand)

hook.Add("PlayerSay", "Ghost fancy toggle", function(plr, text, isteam)
	if text[1] ~= "/" and text[1] ~= "!" then
		return
	end

	if string.find(text, fancycmd, 2, true) == 2 then
		local userid
		-- "ohyaknow 13"
		--           ^^--- example userid we'll try to clip out
		--          ^--- the location spaceIndex points to
		--  ^^^^^^^^--- the fancycmd
		local spaceIndex = fancycmd:len() + 1 -- skips "!cmd"

		if string.sub(text, spaceIndex, spaceIndex) == ' ' then
			userid = string.sub(text, spaceIndex + 1)
		end

		PlayerFancyGhostCommand(plr, nil, nil, userid)
		return ""
	end
end)

local function toggleSpookyGhost(plr)
	if ghostsAreAllowed() then
		plr:ToggleGhost()
	end
end

for k,v in ipairs(spooktator.cfg.commands) do
	concommand.Add(v, toggleSpookyGhost, nil, "toggle spooky ghost")
end

hook.Add("PlayerSay", "Ghost toggle", function(plr, text, isteam)
	if text[1] ~= "/" and text[1] ~= "!" then
		return
	end

	for k,v in ipairs(spooktator.cfg.commands) do
		if string.find(text, v, 2, true) == 2 then
			toggleSpookyGhost(plr)
			return ""
		end
	end
end)

local deathbadgehook
local function dbhReplacement(vic, att, dmg)
	if not vic.diedAsGhost then
		deathbadgehook(vic, att, dmg)
	emd
end

local killcamhook
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
		-- the deathbadge thing shows death info (dmg, attacker, etc)
		-- we don't want this if some ghost death things happened
		deathbadgehook = dpd["DMSG.SV"]
		if deathbadgehook then
			hook.Add("DoPlayerDeath", "DMSG.SV", dbhReplacement)
		end

		-- the killcam thing aims the camera at the killer
		-- we don't want this if some ghost death things happened
		killcamhook = dpd["WKC_SendKillCamData"]
		if killcamhook then
			hook.Add("DoPlayerDeath", "WKC_SendKillCamData", kchReplacement)
		end
	end

	-- Prevent next/prev player-view spectator binds for ghosts.
	GAMEMODE.oldKeyPress = GAMEMODE.KeyPress
	function GAMEMODE:KeyPress(plr, key)
		if not plr:IsGhost() then
			return self:oldKeyPress(plr, key)
		end
	end

	-- Prevent some more spectator stuff from happening.
	GAMEMODE.oldSpectatorThink = GAMEMODE.SpectatorThink
	function GAMEMODE:SpectatorThink(plr)
		if not plr:IsGhost() then
			self:oldSpectatorThink(plr)
		end
	end

	-- Prevent ghosts from picking up weapons.
	GAMEMODE.oldPlayerCanPickupWeapon = GAMEMODE.PlayerCanPickupWeapon
	function GAMEMODE:PlayerCanPickupWeapon(plr, wep)
		if IsValid(plr) and plr:IsGhost() then
			return false
		end
		return self:oldPlayerCanPickupWeapon(plr, wep)
	end

	-- Prevents and players being spawned into TEAM_TERROR from remaining
	--  ghosts. We've got a few pre-round hooks to unghostify people, but
	--  this also unghostifies players being respawned mid-round by admins.
	PlayerMTbl.oldSpawnForRound = PlayerMTbl.SpawnForRound
	function PlayerMTbl:SpawnForRound(dead_only)
		if self:IsGhost() then
			self:UnGhostify()
		end
		return self:oldSpawnForRound(dead_only)
	end

	-- Honestly, who knows...
	PlayerMTbl.oldResetRoundFlags = PlayerMTbl.ResetRoundFlags
	function PlayerMTbl:ResetRoundFlags()
		if self:IsGhost() then return end
		self:oldResetRoundFlags()
	end

	-- Again, who knows...
	PlayerMTbl.oldSpectate = PlayerMTbl.Spectate
	function PlayerMTbl:Spectate(mode)
		if self:IsGhost() then return end
		return self:oldSpectate(mode)
	end

	-- Prevent players from getting items when spawning as a ghost.
	GAMEMODE.oldGiveLoadout = GAMEMODE.PlayerLoadout
	function GAMEMODE:PlayerLoadout(plr)
		if plr:IsGhost() then return end
		self:oldGiveLoadout(plr)
	end

	KARMA.oldHurt = KARMA.Hurt
	function KARMA.Hurt(attacker, victim, dmginfo)
		if not (IsValid(attacker) and IsValid(victim)) then return end
		if attacker == victim then return end
		if not (attacker:IsPlayer() and victim:IsPlayer()) then return end
		if attacker:IsGhost() or victim:IsGhost() then return end
		return KARMA.oldHurt(attacker, victim, dmginfo)
	end
end)

-- too many damn scripts override this function on Initialize
-- so I had the idea of putting this here
hook.Add("TTTBeginRound", "TTTBeginRound_Ghost", function()
	oldHasteMode = HasteMode
	GAMEMODE.oldPlayerDeath = GAMEMODE.PlayerDeath
	function GAMEMODE:PlayerDeath(plr, infl, attacker)
		if plr:IsGhost() then
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

hook.Add("EntityEmitSound", "Block sounds spawned from ghosts", function(tbl)
	local ent = tbl.Entity
	local soundName = tbl.SoundName
	if IsValid(ent) and ent:IsPlayer() and ent:IsGhost() then
		for k,v in ipairs(sounds_to_block) do
			if string.find(soundName, v, 1, true) ~= nil then
				return false
			end
		end
	end
end)
