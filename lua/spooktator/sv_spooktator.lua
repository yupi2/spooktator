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
	--self:Spectate(OBS_MODE_ROAMING)
	self:SetGhostState(true)
	self:Spawn()
end

function PlayerMTbl:UnGhostify()
	if not self:GetGhostState() then return end
	self:SetGhostState(false)
	self.diedAsGhost = true
	self:Kill()
	--self:Spectate(OBS_MODE_ROAMING)
end

function PlayerMTbl:ToggleGhost()
	if self:Team() ~= TEAM_SPEC then return end

	if self:GetGhostState() then
		self:UnGhostify()
	else
		self:Ghostify()
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

local function maybe(percent)
	return (clamp(percent, 0, 100) >= math.random(1, 100))
end

local function PlayerWillBeFancy(plr)
	local chance = spooktator.cfg.fancy.player_chance[plr:SteamID()]

	if not isnumber(chance) then
		chance = spooktator.cfg.fancy.group_chance[getPlayerGroup(plr)]
		if not isnumber(chance) then
			chance = spooktator.cfg.fancy.chance
		end
	end

	return maybe(chance)
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

hook.Add("PostPlayerDeath", "playe die thing", function(plr)
	if plr.diedAsGhost then
		plr.diedAsGhost = nil
		return
	end

	if not spooktator.cfg.spawn_as_ghost then return end
	if plr:GetInfoNum("spawnasghost", 0) ~= 1 then return end

	local state = GetRoundState()
	if state == ROUND_ACTIVE or state == ROUND_POST then
		plr:Ghostify()
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

local old_KeyPress = util.noop
local old_SpectatorThink = util.noop
local old_PlayerCanPickupWeapon = util.noop
local old_SpawnForRound = util.noop
local old_ResetRoundFlags = util.noop
local old_spectate = util.noop
--local old_ShouldSpawn = util.noop
local old_GiveLoadout = util.noop
local old_KarmaHurt = util.noop

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

	old_KeyPress = GAMEMODE.KeyPress
	function GAMEMODE:KeyPress(plr, key)
		if IsValid(plr) and plr:GetGhostState() then return end
		return old_KeyPress(self, plr, key)
	end

	old_SpectatorThink = GAMEMODE.SpectatorThink
	function GAMEMODE:SpectatorThink(plr)
		if IsValid(plr) and plr:GetGhostState() then return true end
		old_SpectatorThink(self, plr)
	end

	old_PlayerCanPickupWeapon = GAMEMODE.PlayerCanPickupWeapon
	function GAMEMODE:PlayerCanPickupWeapon(plr, wep)
		if not IsValid(plr) or not IsValid(wep) then return end
		if plr:GetGhostState() then return end
		return old_PlayerCanPickupWeapon(self, plr, wep)
	end

	old_SpawnForRound = PlayerMTbl.SpawnForRound
	function PlayerMTbl:SpawnForRound(dead_only)
		if self:GetGhostState() then
			self:SetGhostState(false)
		end
		return old_SpawnForRound(self, dead_only)
	end

	old_ResetRoundFlags = PlayerMTbl.ResetRoundFlags
	function PlayerMTbl:ResetRoundFlags()
		if self:GetGhostState() then return end
		old_ResetRoundFlags(self)
	end

	old_spectate = PlayerMTbl.Spectate
	function PlayerMTbl:Spectate(mode)
		if self:GetGhostState() then return end
		return old_spectate(self, mode)
	end

	-- old_ShouldSpawn = PlayerMTbl.ShouldSpawn
	-- function PlayerMTbl:ShouldSpawn()
		-- if self:GetGhostState() then return true end
		-- return old_ShouldSpawn(self)
	-- end

	old_GiveLoadout = GAMEMODE.PlayerLoadout
	function GAMEMODE:PlayerLoadout(plr)
		if plr:GetGhostState() then return end
		old_GiveLoadout(self, plr)
	end

	old_KarmaHurt = KARMA.Hurt
	function KARMA.Hurt(attacker, victim, dmginfo)
		if not (IsValid(attacker) and IsValid(victim)) then return end
		if attacker == victim then return end
		if not (attacker:IsPlayer() and victim:IsPlayer()) then return end
		if attacker:GetGhostState() or victim:GetGhostState() then return end
		return old_KarmaHurt(attacker, victim, dmginfo)
	end
end)

-- too many damn scripts override this function on Initialize
-- so I had the idea of putting this here
hook.Add("TTTBeginRound", "TTTBeginRound_Ghost", function()
	local old_haste = HasteMode
	local old_PlayerDeath = GAMEMODE.PlayerDeath
	function GAMEMODE:PlayerDeath(ply, infl, attacker)
		if ply:GetGhostState() then
			HasteMode = function()
				return false
			end
		end
		old_PlayerDeath(self, ply, infl, attacker)
		HasteMode = old_haste
	end
	hook.Remove("TTTBeginRound", "TTTBeginRound_Ghost")
end)
