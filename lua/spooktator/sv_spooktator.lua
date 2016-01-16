local clamp = math.Clamp

local PlayerMTbl = FindMetaTable("Player")

local function ghostsAreAllowed()
	local state = GetRoundState()
	return (state == ROUND_ACTIVE or state == ROUND_POST)
end

local function shouldSpawnAsGhost(plr)
	-- This flag is checked to see if plr is toggling out of ghost-mode.
	-- if plr.diedAsGhost then
	-- 	return false
	-- end

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
	if self:IsGhost() or not ghostsAreAllowed() or (not self:IsSpec()) then
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

	-- Stop this fucking thing from happening.
	self:SetRagdollSpec(false)
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
	net.WriteUInt(#plrs, 8)

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
		plr:SetFancyGhostState(willPlayerBeFancy(plr))
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
		-- Flag set when a player is spectating a prop from ghost.
		v.propGhostFlag = nil
		-- Clear this table with position and angles and shit.
		v.propGhost = nil
		-- This flag is set when a player dies. *EVERY* player! This means
		--  if you start respawning players during the round shit is going
		--  to get fucky. The flag indicates if the player has a neutral
		--  relationship with npcs. It's useful for shit so shit doesn't
		--  fly around and attack ghosts and shit.
		v.npcNeutral = nil
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
	if plr:IsSpec() and ghostsAreAllowed() then
		plr:ToggleGhost()
	end
end)

hook.Add("PostPlayerDeath", "ghost die thing", function(plr)
	if plr.diedAsGhost then
		plr.diedAsGhost = nil
		return
	end

	if not plr.npcNeutral then
		for k,v in pairs(ents.FindByClass("npc_*")) do
			if v.AddEntityRelationship then
				v:AddEntityRelationship(plr, D_NU, 99)
			end
		end

		plr.npcNeutral = true
	end

	if ghostsAreAllowed() and shouldSpawnAsGhost(plr) then
		--plr:CreateRagdoll()
		-- Subtract some units on the z-axis to move out of ceiling.
		local pos = plr:GetPos() - Vector(0, 0, 16)
		local ang = plr:GetAngles()
		timer.Simple(.3, function()
			plr:Ghostify()
			plr:SetPos(pos)
			plr:SetAngles(ang)
		end)
	end
end)

-- NOTE: The local player must be a superadmin, dev, or owner.
-- Usage in console:
-- <command>
--   This toggles fancy on the local player.
-- <command> <user-id>
--   This toggles fancy on the player given.\
--   You can get user-id's from the console command "status".
local function PlayerFancyGhostCommand(plr, cmd, argtbl, argstr)
	local isRcon = not IsValid(plr)
	-- plr is IsValid if console or something.
	if not isRcon then
		local group = playerGroup(plr)
		-- Can't be bothered to improve...
		if not plr:IsSuperAdmin() and
				group ~= "superadmin" and
				group ~= "owner" and
				group ~= "dev" then
			return
		end
	end

	if argstr ~= "" then
		local userid = tonumber(argstr)
		if userid == nil then
			if isRcon then
				print("Invalid user-id")
			else
				plr:PrintMessage(HUD_PRINTTALK, "Invalid user-id")
			end
			return
		end

		local tgt = Player(userid)
		if not (IsValid(tgt) and tgt:IsPlayer()) then
			if isRcon then
				print("Invalid player")
			else
				plr:PrintMessage(HUD_PRINTTALK, "Invalid player")
			end
			return
		end

		tgt:SetFancyGhostState(not tgt:IsFancyGhost())
		return
	end

	if not isRcon then
		plr:SetFancyGhostState(not plr:IsFancyGhost())
	end
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
	end
end

local killcamhook
local function kchReplacement(vic, att, dmg)
	if not vic.diedAsGhost or not shouldSpawnAsGhost(vic) then
		killcamhook(vic, att, dmg)
	end
end

local dmglogshit
local function dlgReplacement(vic, infl, att)
	if not vic:IsGhost() and not vic.diedAsGhost then
		dmglogshit(vic, infl, att)
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

		-- the killcam thing aims the camera at the killer
		-- we don't want this if some ghost death things happened
		killcamhook = dpd["WKC_SendKillCamData"]

		if deathbadgehook then
			hook.Add("DoPlayerDeath", "DMSG.SV", dbhReplacement)
		end

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
		if not self:IsGhost() then
			self:oldResetRoundFlags()
		end
	end

	-- Again, who knows...
	PlayerMTbl.oldSpectate = PlayerMTbl.Spectate
	function PlayerMTbl:Spectate(mode)
		if not self:IsGhost() then
			return self:oldSpectate(mode)
		end
	end

	-- Prevent players from getting items when spawning as a ghost.
	GAMEMODE.oldGiveLoadout = GAMEMODE.PlayerLoadout
	function GAMEMODE:PlayerLoadout(plr)
		if not plr:IsGhost() then
			self:oldGiveLoadout(plr)
		end
	end

	KARMA.oldHurt = KARMA.Hurt
	function KARMA.Hurt(attacker, victim, dmginfo)
		if not (IsValid(attacker) and IsValid(victim)) then return end
		if attacker == victim then return end
		if not (attacker:IsPlayer() and victim:IsPlayer()) then return end
		if attacker:IsGhost() or victim:IsGhost() then return end
		return KARMA.oldHurt(attacker, victim, dmginfo)
	end

	PROPSPEC.oldTarget = PROPSPEC.Target
	function PROPSPEC.Target(plr, ent)
		if IsValid(plr) and plr:IsGhost() then
			plr.propGhostFlag = true
			plr:UnGhostify()
		end
		return PROPSPEC.oldTarget(plr, ent)
	end

	PROPSPEC.oldEnd = PROPSPEC.End
	function PROPSPEC.End(plr)
		if plr.propGhostFlag then
			plr.propGhost = {}
			plr.propGhost.pos = plr:GetPos()
			plr.propGhost.ang = plr:GetAngles()
		end

		PROPSPEC.Clear(plr)
		plr:Spectate(OBS_MODE_ROAMING)
		plr:ResetViewRoll()

		timer.Simple(0.1, function()
			if IsValid(plr) then
				plr:ResetViewRoll()
				if plr.propGhostFlag then
					plr:Ghostify()
					plr:SetPos(plr.propGhost.pos)
					plr:SetAngles(plr.propGhost.ang)
					plr.propGhostFlag = nil
					plr.propGhost = nil
				end
			end
		end)
	end

	local pd = hook.GetTable()["PlayerDeath"]
	if pd then
		dmglogshit = pd["Damagelog_PlayerDeathLastLogs"]
		if dmglogshit then
			hook.Add("PlayerDeath", "Damagelog_PlayerDeathLastLogs",
				dlgReplacement)
		end
	end
end)

hook.Add("OnEntityCreated", "OnEntityCreated_Ghost", function(ent)
	if not (SERVER and ent:IsNPC()) then
		return
	end

	for k,v in pairs(player.GetAll()) do
		if v:IsGhost() then
			ent:AddEntityRelationship(v, D_NU, 99)
		end
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
