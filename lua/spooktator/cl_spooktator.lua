local spawnasghost = CreateClientConVar("spawnasghost", "1", true, true)
local seeghosts = CreateClientConVar("seeghosts", "1", true, true)

hook.Add("TTTSettingsTabs", "Ghost settings menu", function(dtabs)
	local dsettings = dtabs.Items[2].Panel
	local dgui = vgui.Create("DForm", dsettings)
	dgui:SetName("Spooktator stuff")

	if tttCustomSettings then
		dgui:TTTCustomUI_FormatForm()
	end

	dgui:CheckBox("Auto spawn as ghost when dead", "spawnasghost")
	dgui:CheckBox("See other ghosts", "seeghosts")
	dsettings:AddItem(dgui)

	if tttCustomSettings then
		for k, v in pairs(dgui.Items) do
			for i, j in pairs(v:GetChildren()) do
				j.Label:TTTCustomUI_FormatLabel()
			end
		end
	end
end)

-- ghost visibility changing
local function PlayerShouldBeDrawn(plr, boolean)
	--plr:SetNoDraw(not boolean)
	--plr:DrawShadow(boolean)
	plr:SetRenderMode(boolean and RENDERMODE_NORMAL or RENDERMODE_NONE)
end

local function GhostStateUpdateSingle()
	local plr = net.ReadEntity()
	local isGhost = net.ReadBool()

	if IsValid(plr) and plr:IsPlayer() then
		plr:SetGhostState(isGhost)
	end
end

net.Receive("GhostStateUpdateSingle", GhostStateUpdateSingle)

-- This net-message is received when the player's game
-- won't break from being sent net-messages.
net.Receive("GhostStateUpdateBatch", function()
	--[[ Net stream
		uint8_t - number of players in batch
		entity  - the player
		boolean - is the player a ghost
		entity
		boolean
		etc...
	]]

	-- TODO: Pack entities at the beginning of net-stream with
	-- the bits/booleans packed together at the end.

	local count = net.ReadUInt(8)

	for i = 0, count do
		GhostStateUpdateSingle()
	end
end)

-- Use this hook to inform the server that we're all setup. Using a drawing
-- hook because it should come later in the cycle and thus less will be broken.
hook.Add("PreDrawHUD", "gimme update", function()
	hook.Remove("PreDrawHUD", "gimme update")
	net.Start("GhostStateUpdateBatchRequest")
	net.SendToServer()
end)

local color_modification = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = (10 / 255) * 4,
	["$pp_colour_addb"] = (30 / 255) * 4,
	["$pp_colour_brightness"] = -.25,
	["$pp_colour_contrast"] = 1.5,
	["$pp_colour_colour"] = .32,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0
}

-- Deal with doing color and bloom stuff.
hook.Add("RenderScreenspaceEffects", "Ghost view or something", function()
	if LocalPlayer():IsGhost() then
		DrawColorModify(color_modification)
		DrawBloom(.75,  1,  .65,  .65,  3,  0,  0, (72 / 255), 1)
	end
end)

hook.Add("Think", "Ghost view 2 or something", function()
	local lp = LocalPlayer()
	if not IsValid(lp) then return end
	local plrs = player.GetAll()

	--[[ How a ghost is decided to be drawn:
		If any of the conditions (read from top to bottom) in this comment
		are met then the following action on the line is done.

		If the cvar "seeghosts" does not equal "1" then do not draw ghosts.
		If it's post-round draw the ghosts.
		If the LocalPlayer alive do not draw the ghosts.
		Draw the ghosts.
	]]

	if lp:IsTerror() and (GetRoundState() ~= ROUND_POST) or
			(seeghosts:GetInt() ~= 1) then
		for k,v in ipairs(plrs) do
			if v ~= lp then
				PlayerShouldBeDrawn(v, v:IsTerror())
			end
		end
	else
		for k,v in ipairs(plrs) do
			if v ~= lp then
				PlayerShouldBeDrawn(v, true)
			end
		end
	end
end)

-- Adds a bobbing effect to ghosts.
hook.Add("CalcView", "Ghost bob", function(plr, pos, ang, fov)
	if LocalPlayer():IsGhost() then
		-- Just editing the table's value because we don't want to block
		--  any other hooks. Tables are basically references/pointers so
		--  that's why it's possible to just edit the value.
		pos.z = pos.z + (math.sin((CurTime() * 3)) * 2)
	end
end)

-- This function is duplicated from the TTT core gamemode files. In the core
--  files, this function is not a global function so we can't call it.
local function DrawPropSpecLabels(client)
	if (not client:IsSpec()) and (GetRoundState() ~= ROUND_POST) then
		return
	end

	surface.SetFont("TabLarge")

	local tgt = nil
	local scrpos = nil
	local text = nil
	local w = 0

	for _, ply in pairs(player.GetAll()) do
		if ply:IsSpec() then
			surface.SetTextColor(220,200,0,120)
			tgt = ply:GetObserverTarget()
			if IsValid(tgt) and tgt:GetNWEntity("spec_owner", nil) == ply then
				scrpos = tgt:GetPos():ToScreen()
			else
				scrpos = nil
			end
		else
			local _, healthcolor = util.HealthToString(ply:Health())
			surface.SetTextColor(clr(healthcolor))

			scrpos = ply:EyePos()
			scrpos.z = scrpos.z + 20
			scrpos = scrpos:ToScreen()
		end

		if scrpos and (not IsOffScreen(scrpos)) then
			text = ply:Nick()
			w, _ = surface.GetTextSize(text)
			surface.SetTextPos(scrpos.x - w / 2, scrpos.y)
			surface.DrawText(text)
		end
	end
end

hook.Add("Initialize", "Initialize cuk", function()
	-- Hide HUD thing when your crosshair is over a ghost and you're alive.
	GAMEMODE.oldHUDDrawTargetID = GAMEMODE.HUDDrawTargetID
	function GAMEMODE:HUDDrawTargetID()
		local trace = LocalPlayer():GetEyeTrace(MASK_SHOT)
		local ent = trace.Entity

		-- Check if the targeted player is in spectator-mode.
		-- If so then we'll call DrawPropSpecLabels so they'll show without
		--  having to call the rest of the HUDDrawTargetID function.
		if not (IsValid(ent) and ent:IsPlayer())
				or ent:IsSpec() then
			DrawPropSpecLabels(LocalPlayer())
			return
		end

		self:oldHUDDrawTargetID()
	end

	-- Disable the +duck bind unfocusing the cursor when a ghost.
	GAMEMODE.oldPlayerBindPress = GAMEMODE.PlayerBindPress
	function GAMEMODE:PlayerBindPress(ply, bind, pressed)
		if IsValid(ply) and not (ply:IsGhost() and bind == "+duck") then
			return self:oldPlayerBindPress(ply, bind, pressed)
		end
	end

	-- Have a player's status on the scoreboard not be affected by their
	--  ghost state.
	-- GROUP_SPEC:     didn't play in round (joining late or spectator-only)
	-- GROUP_FOUND:    someone identified the player's body
	-- GROUP_TERROR:   player = alive (or dead and body not identified)
	-- GROUP_NOTFOUND: LocalPlayer = traitor or spec; player = dead; not id'd
	function ScoreGroup(plr)
		if not IsValid(plr) then return -1 end -- will not match any group panel

		local group = hook.Call("TTTScoreGroup", nil, plr)

		if group then -- If that hook gave us a group, use it
			return group
		end

		local SpawnedForRound = plr:GetNWBool("SpawnedForRound")

		if plr:IsGhost() or (DetectiveMode() and plr:IsSpec() and
				SpawnedForRound and not plr:Alive()) then
			if not SpawnedForRound then
				return GROUP_SPEC
			end

			if plr:GetNWBool("body_found", false) then
				return GROUP_FOUND
			else
				-- To terrorists, missing players show as alive
				local lp = LocalPlayer()
				if lp:IsSpec() or lp:IsActiveTraitor() or (lp:IsTerror() and
						(GetRoundState() ~= ROUND_ACTIVE)) then
					return GROUP_NOTFOUND
				else
					return GROUP_TERROR
				end
			end
		end

		return plr:IsTerror() and GROUP_TERROR or GROUP_SPEC
	end
end)
