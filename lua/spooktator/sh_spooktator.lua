local PlayerMTbl = FindMetaTable("Player")

function PlayerMTbl:GhostGet()
	return self.isSpookyGhost == true
end

function PlayerMTbl:GhostSet(boolean, skip_update)
	if self:GhostGet() == boolean then return end
	self.isSpookyGhost = boolean

	if SERVER and not skip_update then
		net.Start("PlayerGhostUpdate")
			net.WriteEntity(self)
			net.WriteBool(boolean)
		net.Broadcast()
	end
end

hook.Add("Move", "Ghost movies", function(plr, mv)
	if CLIENT and plr ~= LocalPlayer() then return end -- is this possible?
	if not plr:GhostGet() then return end

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
