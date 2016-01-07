spooktator = {}

include("spooktator/sh_ghostanimations.lua")
include("spooktator/sh_spooktator.lua")

if SERVER then
	-- Pool the strings early so we don't get errors.
	util.AddNetworkString("GhostStateUpdateSingle")
	util.AddNetworkString("GhostStateUpdateBatch")
	util.AddNetworkString("GhostStateUpdateBatchRequest")

	AddCSLuaFile("spooktator/sh_ghostanimations.lua")
	AddCSLuaFile("spooktator/sh_spooktator.lua")
	AddCSLuaFile("spooktator/cl_spooktator.lua")

	include("spooktator/sv_config.lua")
	include("spooktator/sv_spooktator.lua")
else
	include("spooktator/cl_spooktator.lua")
end
