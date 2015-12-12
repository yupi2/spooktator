local spawnasghost = CreateClientConVar("spawnasghost", "1", true, true)
local seeghosts = CreateClientConVar("seeghosts", "1", true, true)

hook.Add("TTTSettingsTabs", "Ghost settings menu", function(dtabs)
	local dsettings = dtabs.Items[2].Panel

	local dgui = vgui.Create("DForm", dsettings)
	dgui:SetName("Spooktator stuff")
	dgui:TTTCustomUI_FormatForm()
	dgui:CheckBox("Auto spawn as ghost when dead", "spawnasghost")
	dgui:CheckBox("See other ghosts", "seeghosts")
	dsettings:AddItem(dgui)
	for k, v in pairs(dgui.Items) do
		for i, j in pairs(v:GetChildren()) do
			j.Label:TTTCustomUI_FormatLabel()
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

-- This net-message is received when the player initially spawns.
-- It sends every player's ghost state
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

-- Use this hook to inform the client that we're all setup. Using a drawing
-- hook because it should come later in the cycle and thus less will be broken.
hook.Add("PreDrawHUD", "gimme update", function()
	hook.Remove("PreDrawHUD", "gimme update")
	net.Start("gimmebatchupdate")
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

-- Deal with ghost visibility along with doing color and bloom stuff.
hook.Add("RenderScreenspaceEffects", "Ghost view or something", function()
	local lp = LocalPlayer()
	local plrs = player.GetAll()

	if lp:GetGhostState() then
		DrawColorModify(color_modification)
		DrawBloom(.75,  1,  .65,  .65,  3,  0,  0, (72 / 255), 1)
	end

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
			PlayerShouldBeDrawn(v, (v:Team() == TEAM_TERROR))
		end
	else
		for k,v in ipairs(plrs) do
			PlayerShouldBeDrawn(v, true)
		end
	end
end)

-- Adds a bobbing effect to ghosts.
hook.Add("CalcView", "Ghost bob", function(plr, pos, ang, fov)
	if LocalPlayer():GetGhostState() then
		local view = {}
		local bob = (math.sin((CurTime() * 3)) * 2)

		-- view.origin = Vector(pos.x, pos.y, (pos.z + bob))
		-- view.angles = ang
		-- view.fov = fov
		-- return view

		pos.z = pos.z + bob
	end
end)
