if not GearRack.enabled then return end

-- The included event templates. /gr reset events restores them.
-- UNVERIFIED: test in game. Item, zone and buff-icon names in these scripts
-- (Insignia, Plaguelands, Ahn'Qiraj, Zul'Gurub, Evocation, Spirit Tap) are not
-- checked against the server; edit a template if one never fires.

GearRackUI = GearRackUI or {}

GearRackUI_DefaultEvents = {
	["Druid:Caster Form"] = {
		["trigger"] = "PLAYER_AURAS_CHANGED",
		["delay"] = 0,
		["script"] = "if not GearRackUI_GetForm() and GEARRACK_FORM then GearRack.EquipSet() GEARRACK_FORM=nil end --[[Equip a set when not in an animal form.]]",
	},
	["Druid:Aquatic Form"] = {
		["trigger"] = "PLAYER_AURAS_CHANGED",
		["delay"] = 0,
		["script"] = "local form=GearRackUI_GetForm() if form==\"Aquatic Form\" and GEARRACK_FORM~=form then GearRack.EquipSet() GEARRACK_FORM=form end --[[Equip a set when in aquatic form.]]",
	},
	["Druid:Moonkin Form"] = {
		["trigger"] = "PLAYER_AURAS_CHANGED",
		["delay"] = 0,
		["script"] = "local form=GearRackUI_GetForm() if form==\"Moonkin Form\" and GEARRACK_FORM~=form then GearRack.EquipSet() GEARRACK_FORM=form end --[[Equip a set when in moonkin form.]]",
	},
	["Insignia Used"] = {
		["trigger"] = "GEARRACK_ITEMUSED",
		["delay"] = 0.5,
		["script"] = "if arg1==\"Insignia of the Alliance\" or arg1==\"Insignia of the Horde\" then GearRack.EquipSet() end --[[Equips a set when the Insignia of the Alliance/Horde has been used.]]",
	},
	["Plaguelands"] = {
		["trigger"] = "ZONE_CHANGED_NEW_AREA",
		["delay"] = 1,
		["script"] = "local zone = GetRealZoneText()\nlocal plague = zone==\"Western Plaguelands\" or zone==\"Eastern Plaguelands\" or zone==\"Scholomance\" or zone==\"Stratholme\"\nif plague and not GEARRACK_PLAGUE then\n  GearRack.EquipSet() GEARRACK_PLAGUE=1\nelseif not plague and GEARRACK_PLAGUE then\n  GearRack.LoadSet() GEARRACK_PLAGUE=nil\nend\n--[[Equips set to be worn while in plaguelands.]]",
	},
	["Druid:Cat Form"] = {
		["trigger"] = "PLAYER_AURAS_CHANGED",
		["delay"] = 0,
		["script"] = "local form=GearRackUI_GetForm() if form==\"Cat Form\" and GEARRACK_FORM~=form then GearRack.EquipSet() GEARRACK_FORM=form end --[[Equip a set when in cat form.]]",
	},
	["Low Mana"] = {
		["trigger"] = "UNIT_POWER_UPDATE",
		["delay"] = 0.5,
		["script"] = "if arg1~=\"player\" or UnitPowerType(\"player\")~=0 then return end\nlocal maximum = UnitManaMax(\"player\")\nif not maximum or maximum<=0 then return end\nlocal mana = UnitMana(\"player\") / maximum\nif mana < .5 and not GEARRACK_OOM then\n  GearRack.EquipSet()\n  GEARRACK_OOM = 1\nelseif GEARRACK_OOM and mana > .75 then\n  GearRack.LoadSet()\n  GEARRACK_OOM = nil\nend\n--[[Equips a set below 50% mana and restores gear above 75%. Non-weapons wait for combat to end.]]",
	},
	["Rogue:Stealth"] = {
		["trigger"] = "PLAYER_AURAS_CHANGED",
		["delay"] = 0,
		["script"] = "local _,_,isActive = GetShapeshiftFormInfo(1)\nif isActive and not GEARRACK_FORM then\n  GearRack.EquipSet() GEARRACK_FORM=1\nelseif not isActive and GEARRACK_FORM then\n  GearRack.LoadSet() GEARRACK_FORM=nil\nend\n--[[Equips set to be worn while stealthed.]]",
	},
	["Mage:Evocation"] = {
		["trigger"] = "GEARRACK_BUFFS_CHANGED",
		["delay"] = 0.25,
		["script"] = "local evoc=arg1[\"Interface\\\\Icons\\\\Spell_Nature_Purge\"]\nif evoc and not GEARRACK_EVOC then\n  GearRack.EquipSet() GEARRACK_EVOC=1\nelseif not evoc and GEARRACK_EVOC then\n  GearRack.LoadSet() GEARRACK_EVOC=nil\nend\n--[[Equips a set to wear while channeling Evocation.]]",
	},
	["Warrior:Berserker"] = {
		["trigger"] = "PLAYER_AURAS_CHANGED",
		["delay"] = 0,
		["script"] = "local _,_,isActive = GetShapeshiftFormInfo(3) if isActive and GEARRACK_FORM~=\"Berserker\" then GearRack.EquipSet() GEARRACK_FORM=\"Berserker\" end --[[Equips set to be worn in Berserker stance.]]",
	},
	["Druid:Bear Form"] = {
		["trigger"] = "PLAYER_AURAS_CHANGED",
		["delay"] = 0,
		["script"] = "local form = GearRackUI_GetForm()\nif (form==\"Dire Bear Form\" or form==\"Bear Form\") and GEARRACK_FORM~=\"Bear Form\" then GearRack.EquipSet() GEARRACK_FORM=\"Bear Form\" end --[[Equip a set when in bear form.]]",
	},
	["Priest:Spirit Tap Begin"] = {
		["trigger"] = "PLAYER_REGEN_ENABLED",
		["delay"] = 0.25,
		["script"] = "local found=GearRackUI.Buffs[\"Interface\\\\Icons\\\\Spell_Shadow_Requiem\"]\nif not GEARRACK_SPIRIT and found then\nGearRack.EquipSet() GEARRACK_SPIRIT=1\nend\n--[[Equips a set when you leave combat with Spirit Tap. Associate a set of spirit gear to this event.]]",
	},
	["Priest:Spirit Tap End"] = {
		["trigger"] = "GEARRACK_BUFFS_CHANGED",
		["delay"] = 0.5,
		["script"] = "local found=arg1[\"Interface\\\\Icons\\\\Spell_Shadow_Requiem\"]\nif GEARRACK_SPIRIT and not found then\nGearRack.LoadSet() GEARRACK_SPIRIT = nil\nend\n--[[Returns to normal gear when Spirit Tap ends. Associate the same spirit set as Spirit Tap Begin.]]",
	},
	["Warrior:Battle"] = {
		["trigger"] = "PLAYER_AURAS_CHANGED",
		["delay"] = 0,
		["script"] = "local _,_,isActive = GetShapeshiftFormInfo(1) if isActive and GEARRACK_FORM~=\"Battle\" then GearRack.EquipSet() GEARRACK_FORM=\"Battle\" end --[[Equips set to be worn in battle stance.]]",
	},
	["Skinning"] = {
		["trigger"] = "UPDATE_MOUSEOVER_UNIT",
		["delay"] = 0,
		["script"] = "if UnitIsDead(\"mouseover\") and GameTooltipTextLeft3:GetText()==UNIT_SKINNABLE then\n  local r,g,b = GameTooltipTextLeft3:GetTextColor()\n  if r>.9 and g<.2 and b<.2 and not GEARRACK_SKIN then\n    GearRack.EquipSet() GEARRACK_SKIN=1\n  end\nelseif GEARRACK_SKIN then\n  GearRack.LoadSet() GEARRACK_SKIN=nil\nend\n--[[Equips a set when you mouseover something that can be skinned but you have insufficient skill.]]\n",
	},
	["Warrior:Overpower End"] = {
		["trigger"] = "GEARRACK_DODGED",
		["delay"] = 5,
		["script"] = "--[[Equip a set five seconds after opponent dodged: your normal weapons. ]]\nif GEARRACK_OVERPOWER==1 then\nGearRack.EquipSet()\nGEARRACK_OVERPOWER=nil\nend",
	},
	["Druid:Travel Form"] = {
		["trigger"] = "PLAYER_AURAS_CHANGED",
		["delay"] = 0,
		["script"] = "local travel = GearRackUI_GetForm()==\"Travel Form\"\nif travel and not GEARRACK_TRAVEL then\n  GearRack.EquipSet()\nelseif not travel and GEARRACK_TRAVEL then\n  GearRack.LoadSet()\nend\nGEARRACK_TRAVEL=travel\n--[[Equips a set while in travel form and restores it on leaving.]]",
	},
	["Mount"] = {
		["trigger"] = "PLAYER_MOUNT_DISPLAY_CHANGED",
		["delay"] = 0,
		["script"] = "local mount = IsMounted()\nif not GEARRACK_MOUNT and mount then\n  GearRack.EquipSet()\nelseif GEARRACK_MOUNT and not mount then\n  GearRack.LoadSet()\nend\nGEARRACK_MOUNT=mount\n--[[Equips set to be worn while mounted.]]",
	},
	["Swimming"] = {
		["trigger"] = "MIRROR_TIMER_START",
		["delay"] = 0,
		["script"] = "if arg1==\"BREATH\" then\n  GearRack.EquipSet()\nend\n--[[Equips a set when the breath timer starts. Does not restore gear when leaving water.]]",
	},
	["Eating-Drinking"] = {
		["trigger"] = "GEARRACK_BUFFS_CHANGED",
		["delay"] = 0,
		["script"] = "local found=arg1[\"Interface\\\\Icons\\\\INV_Misc_Fork&Knife\"] or arg1[\"Drink\"]\nif not GEARRACK_DRINK and found then\nGearRack.EquipSet() GEARRACK_DRINK=1\nelseif GEARRACK_DRINK and not found then\nGearRack.LoadSet() GEARRACK_DRINK=nil\nend\n--[[Equips a set while eating or drinking.]]",
	},
	["Warrior:Defensive"] = {
		["trigger"] = "PLAYER_AURAS_CHANGED",
		["delay"] = 0,
		["script"] = "local _,_,isActive = GetShapeshiftFormInfo(2) if isActive and GEARRACK_FORM~=\"Defensive\" then GearRack.EquipSet() GEARRACK_FORM=\"Defensive\" end --[[Equips set to be worn in Defensive stance.]]",
	},
	["Insignia"] = {
		["trigger"] = "GEARRACK_NOTIFY",
		["delay"] = 0,
		["script"] = "if arg1==\"Insignia of the Alliance\" or arg1==\"Insignia of the Horde\" then GearRack.EquipSet() end --[[Equips a set when the Insignia of the Alliance/Horde finishes cooldown.]]",
	},
	["Priest:Shadowform"] = {
		["trigger"] = "GEARRACK_BUFFS_CHANGED",
		["delay"] = 0,
		["script"] = "local f=arg1[\"Interface\\\\Icons\\\\Spell_Shadow_Shadowform\"]\nif not GEARRACK_Shadowform and f then\n  GearRack.EquipSet() GEARRACK_Shadowform=1\nelseif GEARRACK_Shadowform and not f then\n  GearRack.LoadSet() GEARRACK_Shadowform=nil\nend\n--[[Equips a set while under Shadowform]]",
	},

	["Warrior:Overpower Begin"] = {
		["trigger"] = "GEARRACK_DODGED",
		["delay"] = 0,
		["script"] = "--[[Equip a set when the opponent dodges.  Associate a heavy-hitting 2h set with this event. ]]\nlocal _,_,i = GetShapeshiftFormInfo(1)\nif i then\nGearRack.EquipSet()\nGEARRACK_OVERPOWER=1\nend",
	},
	["About Town"] = {
		["trigger"] = "PLAYER_UPDATE_RESTING",
		["delay"] = 0,
		["script"] = "local resting=IsResting()\nif resting and not GEARRACK_TOWN then\n  GearRack.EquipSet() GEARRACK_TOWN=1\nelseif not resting and GEARRACK_TOWN then\n  GearRack.LoadSet() GEARRACK_TOWN=nil\nend\n--[[Equips a set while in a city or inn.]]"
	},
	["Brainwashing 1"] = {
    ["trigger"] = "GEARRACK_GBD",
    ["delay"] = 0.1,
    ["script"] =
        "local spec = tonumber(arg1)\n" ..
        "if spec == 1 then\n" ..
        "  GearRack.EquipSet()\n" ..
        "  DEFAULT_CHAT_FRAME:AddMessage(\"GearRack - 1st Goblin Brainwashing Device set requested\")\n" ..
        "end",
	},
	["Brainwashing 2"] = {
    ["trigger"] = "GEARRACK_GBD",
    ["delay"] = 0.1,
    ["script"] =
        "local spec = tonumber(arg1)\n" ..
        "if spec == 2 then\n" ..
        "  GearRack.EquipSet()\n" ..
        "  DEFAULT_CHAT_FRAME:AddMessage(\"GearRack - 2nd Goblin Brainwashing Device set requested\")\n" ..
        "end",
	},
	["Brainwashing 3"] = {
    ["trigger"] = "GEARRACK_GBD",
    ["delay"] = 0.1,
    ["script"] =
        "local spec = tonumber(arg1)\n" ..
        "if spec == 3 then\n" ..
        "  GearRack.EquipSet()\n" ..
        "  DEFAULT_CHAT_FRAME:AddMessage(\"GearRack - 3rd Goblin Brainwashing Device set requested\")\n" ..
        "end",
	},
	["Brainwashing 4"] = {
    ["trigger"] = "GEARRACK_GBD",
    ["delay"] = 0.1,
    ["script"] =
        "local spec = tonumber(arg1)\n" ..
        "if spec == 4 then\n" ..
        "  GearRack.EquipSet()\n" ..
        "  DEFAULT_CHAT_FRAME:AddMessage(\"GearRack - 4th Goblin Brainwashing Device set requested\")\n" ..
        "end",
	},
	["Mount(Not ZG/AQ)"] = {
	["trigger"] = "PLAYER_AURAS_CHANGED",
	["delay"] = 0,
	["script"] =
		"local mount = IsMounted()\n"..
		"local zone = GetRealZoneText()\n"..
		"local outdoorRaid = (zone == \"Ahn'Qiraj\" or zone == \"Zul'Gurub\" or zone == \"Ruins of Ahn'Qiraj\")\n"..
		"\n"..
		"if outdoorRaid then\n"..
		"  if GEARRACK_MOUNT and not mount then\n"..
		"    GearRack.LoadSet()\n"..
		"  end\n"..
		"  GEARRACK_MOUNT = mount\n"..
		"  return\n"..
		"end\n"..
		"if not GEARRACK_MOUNT and mount then\n"..
		"  GearRack.EquipSet()\n"..
		"elseif GEARRACK_MOUNT and not mount then\n"..
		"  GearRack.LoadSet()\n"..
		"end\n"..
		"GEARRACK_MOUNT = mount\n"..
		"--[[Equips mount set as normal unless in ZG or AQ]]",
	},
}
