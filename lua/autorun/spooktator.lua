--if false then
	spooktator = {}

	include("spooktator/sh_spooktator.lua")

	if SERVER then
		AddCSLuaFile("spooktator/sh_spooktator.lua")
		AddCSLuaFile("spooktator/cl_spooktator.lua")
		include("spooktator/sv_config.lua")
		include("spooktator/sv_spooktator.lua")
	else
		include("spooktator/cl_spooktator.lua")
	end

	print("[spooktator] stuff all good")
--end