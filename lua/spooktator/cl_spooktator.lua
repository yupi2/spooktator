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

local function PlayerUpdateGhostState()
	local plr = net.ReadEntity()
	local isGhost = net.ReadBool()

	if IsValid(plr) and plr:IsPlayer() then
		plr:SetGhostState(isGhost)
	end
end

net.Receive("PlayerUpdateGhostState", PlayerUpdateGhostState)

-- This net-message is received when the player's game
-- won't break from being sent net-messages.
net.Receive("PlayerBatchUpdateGhostState", function()
	--[[ Net stream
		uint8_t: number of players in batch
			255 max players should be fineeee
		entity: the player
		boolean: is the player a ghost
		entity
		boolean
		etc...
	]]

	-- TODO: Pack entities at the beginning of net-stream with
	-- the bits/booleans packed together at the end.

	local count = net.ReadUInt(8)

	for i = 0, count do
		PlayerUpdateGhostState()
	end
end)

-- Use this hook to inform the server that we're all setup. Using a drawing
-- hook because it should come later in the cycle and thus less will be broken.
hook.Add("PreDrawHUD", "gimme update", function()
	hook.Remove("PreDrawHUD", "gimme update")
	--timer.Simple(1, function()
		net.Start("gimmebatchupdate")
		net.SendToServer()
	--end)
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
	if LocalPlayer():GetGhostState() then
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

	if ((lp:Team() == TEAM_TERROR) and (GetRoundState() ~= ROUND_POST)) or
			(seeghosts:GetInt() ~= 1) then
		for k,v in ipairs(plrs) do
			if v ~= lp then
				PlayerShouldBeDrawn(v, (v:Team() == TEAM_TERROR))
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
	if LocalPlayer():GetGhostState() then
		pos.z = pos.z + (math.sin((CurTime() * 3)) * 2)
	end
end)

local function DrawPropSpecLabels(client)
	if (not client:IsSpec()) and (GetRoundState() != ROUND_POST) then return end

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

local old_HUDDrawTargetID = util.noop

hook.Add("Initialize", "Initialize cuk", function()
	old_HUDDrawTargetID = GAMEMODE.HUDDrawTargetID
	function GAMEMODE:HUDDrawTargetID()
		local trace = LocalPlayer():GetEyeTrace(MASK_SHOT)
		local ent = trace.Entity

		if not (IsValid(ent) and ent:IsPlayer()) or ent:Team() == TEAM_SPEC then
			DrawPropSpecLabels(LocalPlayer())
			return
		end

		old_HUDDrawTargetID(self)
	end

	function GAMEMODE:PlayerBindPress(ply, bind, pressed)
		if not IsValid(ply) then return end

		if bind == "invnext" and pressed then
			if ply:IsSpec() then
				TIPS.Next()
			else
				WSWITCH:SelectNext()
			end
			return true
		elseif bind == "invprev" and pressed then
			if ply:IsSpec() then
				TIPS.Prev()
			else
				WSWITCH:SelectPrev()
			end
			return true
		elseif bind == "+attack" then
			if WSWITCH:PreventAttack() then
				if not pressed then
					WSWITCH:ConfirmSelection()
				end
				return true
			end
		elseif bind == "+sprint" then
			-- set voice type here just in case shift is no longer down when the
			-- PlayerStartVoice hook runs, which might be the case when switching to
			-- steam overlay
			ply.traitor_gvoice = false
			RunConsoleCommand("tvog", "0")
			return true
		elseif bind == "+use" and pressed then
			if ply:IsSpec() then
				RunConsoleCommand("ttt_spec_use")
				return true
			elseif TBHUD:PlayerIsFocused() then
				return TBHUD:UseFocused()
			end
		elseif string.sub(bind, 1, 4) == "slot" and pressed then
			local idx = tonumber(string.sub(bind, 5, -1)) or 1

			-- if radiomenu is open, override weapon select
			if RADIO.Show then
				RADIO:SendCommand(idx)
			else
				WSWITCH:SelectSlot(idx)
			end
			return true
		elseif string.find(bind, "zoom") and pressed then
			-- open or close radio
			RADIO:ShowRadioCommands(not RADIO.Show)
			return true
		elseif bind == "+voicerecord" then
			if not VOICE.CanSpeak() then
				return true
			end
		elseif bind == "gm_showteam" and pressed and ply:IsSpec() then
			local m = VOICE.CycleMuteState()
			RunConsoleCommand("ttt_mute_team", m)
			return true
		elseif bind == "+duck" and pressed and ply:IsSpec() and not ply:GetGhostState() then
			if not IsValid(ply:GetObserverTarget()) then
				if GAMEMODE.ForcedMouse then
					gui.EnableScreenClicker(false)
					GAMEMODE.ForcedMouse = false
				else
					gui.EnableScreenClicker(true)
					GAMEMODE.ForcedMouse = true
				end
			end
		elseif bind == "noclip" and pressed then
			if not GetConVar("sv_cheats"):GetBool() then
				RunConsoleCommand("ttt_equipswitch")
				return true
			end
		elseif (bind == "gmod_undo" or bind == "undo") and pressed then
			RunConsoleCommand("ttt_dropammo")
			return true
		end
	end


	function ScoreGroup(p)
		if not IsValid(p) then return -1 end -- will not match any group panel

		local group = hook.Call( "TTTScoreGroup", nil, p )

		if group then -- If that hook gave us a group, use it
			return group
		end

		if p:GetGhostState() or (DetectiveMode() and p:IsSpec() and
				p:GetNWBool("playedfuckboiround") and (not p:Alive())) then
			if not p:GetNWBool("playedfuckboiround") then return GROUP_SPEC end
			if p:GetNWBool("body_found", false) then
				return GROUP_FOUND
			else
				-- To terrorists, missing players show as alive
				local lp = LocalPlayer()
				if ((GAMEMODE.round_state ~= ROUND_ACTIVE) and lp:IsTerror()) or
						lp:IsSpec() or lp:IsActiveTraitor() then
					return GROUP_NOTFOUND
				else
					return GROUP_TERROR
				end
			end
		end

		return p:IsTerror() and GROUP_TERROR or GROUP_SPEC
	end
end)
