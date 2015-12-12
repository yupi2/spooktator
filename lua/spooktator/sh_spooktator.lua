local PlayerMTbl = FindMetaTable("Player")

function PlayerMTbl:GetGhostState()
	return self.isGhost == true
end

function PlayerMTbl:SetGhostState(boolean, skip_update)
	if self:GetGhostState() == boolean then return end
	self.isGhost = boolean

	if SERVER and not skip_update then
		net.Start("PlayerUpdateGhostState")
			net.WriteEntity(self)
			net.WriteBool(boolean)
		net.Broadcast()
	end
end

-- Hook is shared because it might make it look better on the client.
hook.Add("Move", "Ghost movies", function(plr, mv)
	if CLIENT and plr ~= LocalPlayer() then return end -- is this possible?
	if not plr:GetGhostState() then return end

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
