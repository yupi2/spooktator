local PlayerMTbl = FindMetaTable("Player")

function PlayerMTbl:IsGhost()
	return self.isGhost == true
end

function PlayerMTbl:SetGhostState(boolean, skip_update)
	if self:IsGhost() == boolean then
		return
	end

	self.isGhost = boolean

	if SERVER and not skip_update then
		net.Start("GhostStateUpdateSingle")
		net.WriteEntity(self)
		net.WriteBool(boolean)
		net.Broadcast()
	end
end

function util._tracething(f, TraceData)
	local tr = f(TraceData)
	local ent = tr.Entity

	if IsValid(ent) and ent:IsPlayer() and ent:IsGhost() then
		return {}
	end

	return tr
end

hook.Add("Initialize", "gimme your funicies", function()
	util.origTraceLine = util.TraceLine
	util.TraceLine = function(TraceData)
		return util._tracething(util.origTraceLine, TraceData)
	end

	util.origTraceHull = util.TraceHull
	util.TraceHull = function(TraceData)
		return util._tracething(util.origTraceHull, TraceData)
	end
end)

-- If the player is holding the jump key then they will float upwards.
-- If the player is not holding their jump key but they are holding their
-- duck key then they will remain floating at the current height.
hook.Add("Move", "Ghost movement", function(plr, mv)
	if not (plr:Team() == TEAM_SPEC and plr:IsGhost()) then
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
	if not (IsValid(ent1) and IsValid(ent2)) then return end
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
