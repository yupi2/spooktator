local PlayerMTbl = FindMetaTable("Player")

function PlayerMTbl:AnimateGhost(vel)
	local len2d = vel:Length2D()

	local seq = "idle1"
	local cup = self:GetBodygroup(1) == 1

	if len2d > 0 then
		if cup then
			seq = "walk2";
		else
			seq = "walk";
		end
	else
		if cup then
			seq = "idle2"
		end
	end

	self.LastSippyCup = self.LastSippyCup or 0
	self.LastOogly = self.LastOogly or 0

	if cup and (CurTime() >= self.LastSippyCup) then
		self.LastSippyCup = CurTime() + math.Rand(20, 40)
		self:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD,
			ACT_GESTURE_MELEE_ATTACK1, true)
	end

	if CurTime() >= self.LastOogly then
		self.LastOogly = CurTime() + math.Rand(10, 20)
		self:AnimRestartGesture(GESTURE_SLOT_GRENADE,
			ACT_GESTURE_RANGE_ATTACK2, true)
	end

	if CLIENT then
		self:AnimRestartGesture(GESTURE_SLOT_JUMP, ACT_GESTURE_MELEE_ATTACK2)
	end

	self.CalcSeqOverride = seq
end

function PlayerMTbl:PlaybackRateOV(rate)
	self:SetNWInt("PlaybackRate", rate)
	self:SetNWBool("PlaybackOV", true)
end

function PlayerMTbl:PlaybackReset()
	self:SetNWInt("PlaybackRate", 1)
	self:SetNWBool("PlaybackOV", false)
end

hook.Add("UpdateAnimation", "ghost animations", function(plr, vel, maxSeqGroundSpeed)
	if not plr:IsGhost() then
		return
	end

	local eye = plr:EyeAngles()

	local estyaw = math.Clamp(math.atan2(vel.y, vel.x) * 180 / math.pi, -180, 180)
	local myaw = math.NormalizeAngle(math.NormalizeAngle(eye.y) - estyaw)

	-- set the move_yaw (because it's not an hl2mp model)
	plr:SetPoseParameter("move_yaw", -myaw)

	local len2d = vel:Length2D()
	local rate = 1.0

	if len2d > 0.5 then
		rate = (len2d * 0.8) / maxSeqGroundSpeed
	end

	plr.SmoothBodyAngles = plr.SmoothBodyAngles or eye.y

	local pp = plr:GetPoseParameter("head_yaw")

	if (pp > .9) or (pp < .1) or (len2d > 0) then
		plr.SmoothBodyAngles = math.ApproachAngle(plr.SmoothBodyAngles, eye.y, 5)
		local y = plr.SmoothBodyAngles

		-- correct player angles
		plr:SetLocalAngles(Angle(0, y, 0))

		if CLIENT then
			-- set rendering angles for zombie

			local rang = plr:GetRenderAngles()
			--local diff = (math.abs(eye.y) - math.abs(rang.y))

			if len2d <= 0 then
				local num = 65

				if plr:IsGhost() then
					num = 25
				end

				if (pp < .1) then
					rang.y = (rang.y - num)
				else
					rang.y = (rang.y + num)
				end
			end

			local diff = math.abs(math.AngleDifference(eye.y, rang.y))
			local num = (diff * .12)
			plr.SmoothBodyAnglesCL = plr.SmoothBodyAnglesCL or eye.y

			-- Used to be plr.SmoothBodyAnglesCL = math.ApproachAngle(plr.SmoothBodyAnglesCL, eye.y, num)
			-- Look here to fix animations!!!
			plr.SmoothBodyAnglesCL = math.ApproachAngle(plr.SmoothBodyAnglesCL, eye.y, 65)

			plr:SetRenderAngles(Angle(0, plr.SmoothBodyAnglesCL, 0))
		end
	end

	rate = math.Clamp(rate, 0, 1)

	if plr:GetNWBool("PlaybackOV", false) then
		rate = plr:GetNWInt("PlaybackRate", 1)
	end

	plr:SetPlaybackRate(rate)
end)

hook.Add("CalcMainActivity", "ghost calc thing", function(plr, vel)
	if plr:IsGhost() then
		plr.CalcIdeal = ACT_IDLE
		plr.CalcSeqOverride = "idle"
		plr:AnimateGhost(vel)
		return plr.CalcIdeal, plr:LookupSequence(plr.CalcSeqOverride)
	end
end)

hook.Add("DoAnimationEvent", "ghost animation event", function(plr, event, data)
	if plr:IsGhost() then
		if event == PLAYERANIMEVENT_ATTACK_PRIMARY then
			plr:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD,
				ACT_MELEE_ATTACK1)
			return ACT_VM_PRIMARYATTACK
		elseif event == PLAYERANIMEVENT_JUMP then
			plr:AnimRestartMainSequence()
			return ACT_INVALID
		end
	end
end)
