spooktator.cfg = {}
spooktator.cfg.fancy = {}

-- The lowest fancy chance is 0 which disallows that person from being fancy.
-- The highest fancy chance is 100 which forces that person to be fancy.

--[[ The player fancy shit is picked as follows:
 If player has a set chance then set their chance to that and exit.
  (spooktator.cfg.fancy.player_chance)

 If a player's group has a set chance then set their chance to that and exit.
  (spooktator.cfg.fancy.group_chance)

 Set a player's chance to the default.
  (spooktator.cfg.fancy.chance)
]]

-- Should players spawn as a ghost by default when they die?
-- Players can still disable auto-spawn-as-ghost with the "spawnasghost" CVar.
-- DEFAULT VALUE: true
spooktator.cfg.spawn_as_ghost = true

-- Commands that can be used in like "!<COMMAND>" or "/<COMMAND>" or
--  in the console like "<COMMAND>".
spooktator.cfg.commands = {
	"toggleghost",
	"spoopy",
}

-- The chance (0 through 100) to be a fancy ghost.
-- DEFAULT VALUE: 5
spooktator.cfg.fancy.chance = 5

-- Give players (by SteamID) a different fancy-chance than the default.
spooktator.cfg.fancy.player_chance = {
	["STEAMID1"] = 100,
	["STEAMID2"] = 0,
	["STEAMID3"] = 50,
}

-- Give players in a group a different fancy-chance than the default.
spooktator.cfg.fancy.group_chance = {
	["owner"] = 100,
	["dev"] = 69,
	["superadmin"] = 69,
	["executive"] = 69,
	["admin"] = 40,
	["mod"] = 30,
	["purpleheart"] = 40,
	["veteran"] = 30,
	["extravagant"] = 40,
	["supporter"] = 30,	
	["donor"] = 20,
	["exceptional"] = 10,
}

-- Command for superadmins to toggle fanciness on themself or others.
spooktator.cfg.fancy.command = "ohyaknow"
