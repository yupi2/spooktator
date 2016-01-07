local PlayerMTbl = FindMetaTable("Player")

function PlayerMTbl:IsGhost()
	return self.isGhost == true
end

function PlayerMTbl:SetGhostState(boolean, skip_update)
	self.isGhost = boolean

	if SERVER and not skip_update then
		net.Start("GhostStateUpdateSingle")
		net.WriteEntity(self)
		net.WriteBool(boolean)
		net.Broadcast()
	end
end

-- If the player is holding the jump key then they will float upwards.
-- If the player is not holding their jump key but they are holding their
-- duck key then they will remain floating at the current height.
hook.Add("Move", "Ghost movement", function(plr, mv)
	-- The IsSpec check should be left here in case of any regressions
	--  so alive players can't just float around like ghosts.
	if not (plr:IsSpec() and plr:IsGhost()) then
		return
	end

	local vel = plr:GetVelocity()

	if plr:KeyDown(IN_JUMP) then
		local num = math.Clamp((vel.z * -0.18), 0, 75) * 0.1
		vel.z = math.Clamp((vel.z + (32 + (5 * num))), -250, 125)
	elseif plr:KeyDown(IN_DUCK) then
		vel.z = 5
	end

	mv:SetVelocity(vel)
	return mv
end)

hook.Add("OnEntityCreated", "Ghost collision check stuff", function(ent)
	if ent:IsPlayer() then
		ent:SetCustomCollisionCheck(true)
	end
end)

hook.Add("ShouldCollide", "Ghost collide", function(ent1, ent2)
	if not (IsValid(ent1) and IsValid(ent2)) then
		return
	end

	if (ent1.Team and ent1:Team() == TEAM_SPEC) or
			(ent2.Team and ent2:Team() == TEAM_SPEC) then
		return false
	end
end)

hook.Add("PlayerFootstep", "Block spectator footsteps", function(plr)
	if plr:Team() == TEAM_SPEC then
		return true -- mutes the steppies
	end
end)
