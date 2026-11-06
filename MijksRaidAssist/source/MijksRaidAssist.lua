
--This is a consume check addon for TurtleWoW, by mijk (<Thunderhorn Clan>, 7 April 2023, v0.4 Alpha
--As there was no decent other addon for this i made one myself.


SLASH_MRA1 = "/fc" --fc because at first i named it Flaskchecker, but then i expanded it.
SLASH_MRA2 = "/mra" --so became Mijk's Raid Assist abbreviated; MRA, both commands work tho.

local frame = CreateFrame("Frame", "Mijk's Raid Assist", UIParent) --gui var
local version = "0.4 Alpha"
--Lets setup the most important var's here.
local Cbuff
local name = {}
local missingBuffs = {}
local primaryBuffs = {}
local littleBuffs = {}
local buffs = {}
local buffedPlayers = {}
local notbuffedPlayers = {}
local buffed
local class
local data
local color
--local spelltype This is used in functions as local, thats why i commented it out, is dangerous to use this while also local functions use it.
local Consume
local Consumearray
local flasks = {	"Interface\\Icons\\INV_Potion_41", --Supreme power
					"Interface\\Icons\\INV_Potion_97", --Distilled wisdom
					"Interface\\Icons\\INV_Potion_62", --Titans
					--"Interface\\Icons\\Spell_Holy_WordFortitude" -- testing with fortitude as flask is too expensive to test with.		
			}

local GPP = { 	"Interface\\Icons\\Spell_Fire_FireArmor", --GFPP				FIRE
				"Interface\\Icons\\Spell_Shadow_RagingScream", --GSPP				SHADOW
				"Interface\\Icons\\Spell_Nature_SpiritArmor", --GNPP				NATURE
				"Interface\\Icons\\Spell_Holy_PrayerOfHealing02", --GAPP				ARCANE
				"Interface\\Icons\\Spell_Frost_FrostArmor02", --GFRPP			FROST
				
				--"Spell_Shadow_AntiShadow", --Testing this with shadow
				--"Spell_Holy_InnerFire",
			
				"inv_potion_16", --Little FPP		fire
				--"INV_Potion_44", --Little SPP		shadow --> This one is a problem, this is in conflict with another pot
				"INV_Potion_06", --Little NPP		nature
				"INV_Potion_13", --Little FRPP		frost
				
				--"Spell_Holy_DivineSpirit" --testing this with DivineSpirit
			}
local MAGEMON = {	"Interface\\Icons\\INV_Potion_45", 			--Mageblood
					"Interface\\Icons\\INV_Potion_32", 			--Mongoose
				}
local Mageblood = "Interface\\Icons\\INV_Potion_45" 			--Mageblood
local Mongoose = "Interface\\Icons\\INV_Potion_32"				--Mongoose

local GFPP = "Interface\\Icons\\Spell_Fire_FireArmor" 			--GFPP				FIRE
local GSPP = "Interface\\Icons\\Spell_Shadow_RagingScream" 		--GSPP				SHADOW
local GNPP = "Interface\\Icons\\Spell_Nature_SpiritArmor" 		--GNPP				NATURE
local GAPP = "Interface\\Icons\\Spell_Holy_PrayerOfHealing02" --GAPP				ARCANE	
local GFRPP = "Interface\\Icons\\Spell_Frost_FrostArmor02" --GFRPP 			FROST
	


--so these don't work, but i'll let them in as information	
local FPP = "inv_potion_16" --Little FPP		fire
--local SPP = "INV_Potion_44" --Little SPP		shadow  --> This one is a problem, this is in conflict with another pot
local NPP = "INV_Potion_06" --Little NPP		nature
local FRPP = "INV_Potion_13" --Little FRPP	frost
			


-- inv_potion_24 GFPP                        FIRE
	-- inv_potion_16 little FPP               fire
-- inv_potion_23 GSPP						 SHADOW
	--  inv_potion_44 little spp			  shadow
-- inv_potion_22 GNPP						 NATURE
	-- inv_potion_06 little npp				  nature
--  inv_potion_83 GAPP						 ARCANE
-- inv_potion_20 GFRPP						 FROST
	-- inv_potion_12 little frpp			  frost
	
-- inv_potion_45 MAGEBLOOD potion
-- inv_potion_32 Mongoose



--This should be the SpellID's, unfortunately i cannot use them, its fixed in i believe WoW1.13 or WoW2+
--If this would work, the addon would be much better, as i could see the differences in Normal pot and Greater pot, which i can't now.
--Thats why the code is way more complex than needed, coz i first made it work, then i realized the same icon is used for both pots lol.

--Flask of the Titans: 17626
--Flask of Distilled Wisdom: 17627
--Flask of Supreme Power: 17628
--Elixir of the Mongoose: 17539
--Mageblood Potion: 17538
--Fire Protection Potion: 723
--Greater Fire Protection Potion: 17543
--Shadow Protection Potion: 7242
--Greater Shadow Protection Potion: 17548
--Nature Protection Potion: 7254
--Greater Nature Protection Potion: 17544
--Arcane Protection Potion: 17543
--Greater Arcane Protection Potion: 28509
--Frost Protection Potion: 7245
--Greater Frost Protection Potion: 17546


--big important one here as well
local itemTranslations = {
  ["Interface\\Icons\\INV_Potion_41"] = "Flask of Supreme Power",
  ["Interface\\Icons\\INV_Potion_97"] = "Flask of Distilled Wisdom",
  ["Interface\\Icons\\INV_Potion_62"] = "Flask of the Titans",
  ["Interface\\Icons\\Spell_Fire_FireArmor"] = "GFPP",
  ["Interface\\Icons\\Spell_Shadow_RagingScream"] = "GSPP",
  ["Interface\\Icons\\Spell_Nature_SpiritArmor"] = "GNPP",
  ["Interface\\Icons\\Spell_Holy_PrayerOfHealing02"] = "GAPP",
  ["Interface\\Icons\\Spell_Frost_FrostArmor02"] = "GFRPP",
  ["Interface\\Icons\\INV_Potion_45"] = "Mageblood",
  ["Interface\\Icons\\INV_Potion_32"] = "Mongoose",
  
  --These don't work, as said before.
  ["inv_potion_16"] = "FPP",
  --["INV_Potion_44"] = "SPP", This one is a problem, this is in conflict with another pot
  ["INV_Potion_06"] = "NPP",
  ["INV_Potion_13"] = "FRPP",

  -- these below are for testing
  --["Interface\\Icons\\Spell_Holy_DivineSpirit"] = "Spirit", --Double backslash because else it will use it as Regex.
  --["Interface\\Icons\\Spell_Shadow_AntiShadow"] = "Shadow prot buff",
  --["Interface\\Icons\\Spell_Holy_WordFortitude"] = "Fortitude",
  --["Interface\\Icons\\Spell_Holy_InnerFire"] = "Inner Fire",
}



function Translate(item)
  return itemTranslations[item] or item -- Return the translated item, or the original item if it is not in the translations table
end

function table.shallow_copy(t) --easy table copy
  local t2 = {}
  for k,v in pairs(t) do
    t2[k] = v
  end
  return t2
end

function firstToUpper(str) --This isn't used, but will leave it in for the future.
  return string.upper(string.sub(str, 1, 1)) .. string.sub(str, 2)
end


function getTableSize(t) --name says it all.
    local count = 0
    for _, __ in pairs(t) do
        count = count + 1
    end
    return count
end

function tableContains(table, element) --if an array contains an entry which im looking for
    if type(table) ~= "table" then
        return false
    end
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

function striparrayduplicate(array1, array2) --i believe this isn't used anymore, and its very ugly to code this way, big workaround.
for _, value in ipairs(array1) do
  for i = getTableSize(array2), 1, -1 do
    if array2[i] == value then
      table.remove(array2, i)
    end
  end
end

end
function isArray(var) --is the var an array or not?
  if type(var) ~= "table" then
    return false
  end
  local count = 0
  for _, _ in pairs(var) do
    count = count + 1
  end
  for i = 1, count do
    if var[i] == nil then
      return false
    end
  end
  return true
end

function ClassDefiner(player) --speaks for itself.
	--Druid	255	125	10	1.00	0.49	0.04		#FF7D0A	Orange
	--Hunter	171	212	115	0.67	0.83	0.45	#ABD473	Green
	--Mage	105	204	240	0.41	0.80	0.94		#69CCF0	Light blue
	--Paladin	245	140	186	0.96	0.55	0.73	#F58CBA	Pink
	--Priest	255	255	255	1.00	1.00	1.00	#FFFFFF	White
	--Rogue	255	245	105	1.00	0.96	0.41		#FFF569	Light yellow
	--Shaman	0	112	222	0.0	0.44	0.87		#0070DE	Blue
	--Warlock	148	130	201	0.58	0.51	0.79	#9482C9	Purple
	--Warrior	199	156	110	0.78	0.61	0.43	#C79C6E	Tan

	if player == "Druid" then color = "FF7D0A" 
	elseif player == "Hunter" then color = "ABD473"
	elseif player == "Mage" then color = "69CCF0"
	elseif player == "Paladin" then color = "F58CBA"
	elseif player == "Priest" then color = "FFFFFF"
	elseif player == "Rogue" then color = "FFF569"
	elseif player == "Shaman" then color = "0070DE"
	elseif player == "Warlock" then color = "9482C9"
	elseif player == "Warrior" then color = "C79C6E"
	end --should use return here as well, but im lazy, variable is filled anyway.
end

function contains_1(tabel, val) --Similar to tablecontains, but made it seperate because this is used for spell/buff-checking, the other isnt.
   for i=1,getTableSize(Consumearray) do
	--DEFAULT_CHAT_FRAME:AddMessage("LOOPING : " .. tabel[i] .." ".. val) -- this is for testing to see all buffs
      if string.find(val, tabel[i]) then 
         return true
      end
   end
   return false
end

local function HasBuff(unit) --this loops one player to check all their buffs.
  local allbuffs = {}
  for j = 1, 40 do
    Cbuff = UnitBuff(unit, j)
    if not Cbuff then break; end
    if contains_1(Consumearray, Cbuff) then
	  local buffName = Translate(Cbuff) -- translate the buff name
	  --DEFAULT_CHAT_FRAME:AddMessage(buffName .. " should be translated")
      table.insert(allbuffs, buffName) -- add the translated buff name to the table
    end
  end

  return allbuffs
end

local function multibuffcheck(desiredBuffs, secondaryBuffs, typebuff)
		
		--DEFAULT_CHAT_FRAME:AddMessage(getTableSize(buffs))
		
		--table.insert (buffs, "GSPP")	-- <-- simulating buffs to see if all goes well
		
		--DEFAULT_CHAT_FRAME:AddMessage(table.concat(buffs, ", "),1.0,1.0,0.0)
		--DEFAULT_CHAT_FRAME:AddMessage("tablecat in multibuff" .. table.concat(desiredBuffs, ", "),1.0,1.0,0.0)
		--DEFAULT_CHAT_FRAME:AddMessage("does reach this point -->" .. table.concat(secondaryBuffs, ", "),1.0,1.0,0.0)
		--DEFAULT_CHAT_FRAME:AddMessage(getTableSize(buffs))
		  for i = 1, getTableSize(buffs) do
			local currentBuff = buffs[i]
			if tableContains(desiredBuffs, currentBuff) then
			  table.insert(primaryBuffs, currentBuff)
			elseif tableContains(secondaryBuffs, currentBuff) then
			  table.insert(littleBuffs, currentBuff)
			end
			 
		  end

			for i = 1, getTableSize(desiredBuffs) do
			  local desiredBuff = desiredBuffs[i]
			  local correspondingSecondaryBuff = secondaryBuffs[i]

			  if tableContains(desiredBuffs, desiredBuff) and tableContains(secondaryBuffs, correspondingSecondaryBuff) then
				local buffPresent = tableContains(buffs, desiredBuff)
				local secondaryBuffFound = false

				-- This code is made to see secondary buffs as well, but i couldnt seperate Greater and Normal pots as WOW 1.12
				-- has only the icon as output. But i'll leave this code in case other buffs are good alternatives to main ones.
				for j = 1, getTableSize(buffs) do
				  local currentBuff = buffs[j]
				  if currentBuff == correspondingSecondaryBuff and currentBuff ~= desiredBuff then
					secondaryBuffFound = true
					break
				  end
				end

				if not buffPresent and not secondaryBuffFound then
				  table.insert(missingBuffs, desiredBuff)
				end
			  end
			end
			  --table.insert(missingBuffs, correspondingSecondaryBuff)

	  
	  --return primaryBuffs, littleBuffs, missingBuffs <-- i know i should do it like this, but im erroring out at such level 
	  --i even get errors in PFUI as my script seems to conflict it seems to not properly return arrays to the other function which is requesting it.
		
end




local function CheckBuffs(spelltype, typebuff, desiredBuffs, secondaryBuffs)
	local unit = "raid" .. 1
    local name = GetUnitName(unit)
 
	if name == nil then 
		DEFAULT_CHAT_FRAME:AddMessage("|cffE0B0FFMijk's Raid Assist; You seem not to be in a raid.")
		return
	end
	LineOpen()
  --DEFAULT_CHAT_FRAME:AddMessage("tablecat in checkbuff" .. table.concat(desiredBuffs, ", "),1.0,1.0,0.0)
  for i = 1, 40 do
    local unit = "raid" .. i
    local name = GetUnitName(unit)
	
	local addstring = ""
	local message = ""
    if name then
		--DEFAULT_CHAT_FRAME:AddMessage(table.concat(desiredBuffs, ", "))
		buffs = HasBuff(unit) --get all buffs (we need to strip some out tho) <-- fixed that by using prio buffs
		--DEFAULT_CHAT_FRAME:AddMessage(table.concat(buffs, ", "),0.0,0.0,1.0)
		if getTableSize(buffs) > 0 then --look if any buffs are present
			ClassDefiner(UnitClass(unit))

			multibuffcheck(desiredBuffs, secondaryBuffs, typebuff)
			
				--Easter egg
				local MageMon = table.concat(primaryBuffs, ",")
				local omg = ""
				if  string.find(MageMon, "Mageblood") and string.find(MageMon, "Mongoose") then 
					omg = " - OMG, this player has both, no slacker!"
				end
				--/Easter egg (please take note that i wrote this script during Easter lol).
				
			
				--Yes, i know it might be better to do this in another function, but im quite done with coding atm.
				if typebuff == "single" then --with single buffs we're counting so not the whole screen gets spammed.

				--this is empty for now, single buffs are handled below this loop.
				
				
					--message = "|cff" .. color .. UnitName(unit) .. "|cffE0B0FF is buffed with "
					--if getTableSize(primaryBuffs) > 0 then -- it is possible one doesnt have primary buffs, only little ones
					--	message = message .. "|cff00FF00" .. table.concat(primaryBuffs, ", ") .. omg; 
					--	addstring = ", " --add string to make it look correctly in chat.
					--end 
				else
					message = message .. table.concat(primaryBuffs, ", ", 1.0, 0.5, 0.5)
					message = "|cff" .. color .. UnitName(unit) .. "|cffE0B0FF is buffed with "
					if getTableSize(primaryBuffs) > 0 then -- it is possible one doesnt have primary buffs, only little ones
						message = message .. "|cff00FF00" .. table.concat(primaryBuffs, ", ") .. omg; 
						addstring = ", " --add string to make it look correctly in chat.
					end 
					if getTableSize(littleBuffs) > 0 then -- adding little buffs in yellow
						message = message .. addstring .. "|cffFFFF00" .. table.concat(littleBuffs, ", ")
						if addstring == "" then addstring = ", "; end--add string to make it look correctly in chat.
					end 
					if getTableSize(missingBuffs) > 0 then message = message ..addstring .. "|cffFF0000" .. table.concat(missingBuffs, ", ") .. "."; end --adding missing buffs in red
				end
				--player has buff's, so we're happy and show that in green (RGB - R0.0 - G1.0 - B0.0, blizzards funny way of using RGB, just use HEX ffs.)
				DEFAULT_CHAT_FRAME:AddMessage(message, 0.0, 1.0, 0.0)
				table.insert(buffedPlayers,"|cff" .. color .. name) --this is for the counting, color goes with it in the table already.
		  else
			ClassDefiner(UnitClass(unit))
			spelltype = string.upper(spelltype) --player doesn't have buffs, we're mad >:(
			if spelltype == "MM" then spelltype = "Mageblood / Mongoose"; end --ugly , i know.
			if typebuff == "multi" then
				DEFAULT_CHAT_FRAME:AddMessage("|cff" .. color .. UnitName(unit) .. "|cffE0B0FF is not buffed with |cffFF0000" .. spelltype, 1.0, 0.0, 0.0)
			end
			
			table.insert(notbuffedPlayers,"|cff" .. color .. name)--this is for the counting, color goes with it in the table already.
			if spelltype == "Mageblood / Mongoose" then spelltype = "MM"; end --reset to match the next ugly line above this.
		  end
		  --reset vars here, else we get alot of duplicates in the next round.
		  littleBuffs = {}
		  missingBuffs = {}
		  primaryBuffs = {}
		
	end		
  end

	--Single buffs here;
	
	 --at this point we looped the whole table and know shit, now we're gonna display it correctly. For single buffs that is, 
	 --with multibuffs we loop through the whole thing and post the chat every loop
	if spelltype == "MM" then spelltype = "Mageblood / Mongoose"; end --ugly , i know, make chat look properly -_-
	
	local buffedAantal = getTableSize(buffedPlayers)
	local unbuffedAantal = getTableSize(notbuffedPlayers)
	local totalplayers = buffedAantal + unbuffedAantal
	local message = "" 

	--buffed players here
	if buffedAantal == 0 then
		message = "\n|cffFF0000None of the players are buffed with " .. spelltype .. ", shame on the raid >:("
		DEFAULT_CHAT_FRAME:AddMessage(message)
	else 
		message = "\n|cffE0B0FFThe buffed players with |cff00FF00" .. spelltype .. "|cffE0B0FF are; \n"
		for i = 1,buffedAantal do
			local separator = ", "
			if i == buffedAantal then separator = ".\n"; end --to make it correctly in chat.
			
			message = message .. buffedPlayers[i] .. separator
		end
		DEFAULT_CHAT_FRAME:AddMessage(message)
	end
	
	--unbuffed players here
	if unbuffedAantal == 0 then
		message = "\n|cff00FF00All players are buffed with " .. spelltype .. ", woohoo, be proud of them :D"
		DEFAULT_CHAT_FRAME:AddMessage(message)
	else 
		message = "\n|cffE0B0FFSo [" .. buffedAantal .. "/" .. totalplayers .. "] of the players are buffed, there are " .. unbuffedAantal .. " players without the |cffFF0000" .. spelltype .. "|cffE0B0FF, those players are; \n"
		for i = 1,unbuffedAantal do
			local separator = ", "
			if i == unbuffedAantal then separator = ".\n"; end --to make it correctly in chat.
			message = message .. notbuffedPlayers[i] .. separator
		end
		
		if string.sub(spelltype, -2) == "PP" and spelltype ~= "GPP" then message = message .. "\n|cffE0B0FFIf you wish to see more detailed information about GxPP potions on players, please use /mra gpp."; end
		DEFAULT_CHAT_FRAME:AddMessage(message)
	end
	if spelltype == "Mageblood / Mongoose" then spelltype = "MM"; end --reset to match the next ugly line above this.

	 

  --Reset var's for the new round.
  buffedPlayers = {}
  notbuffedPlayers = {}
  buffs = {}

  LineClose() --seperation
end


			
local function MRA(spelltype) --So it begins...
local valid = true
local typebuff
local requiredbuffs = {}
local alternativebuffs = {}
spelltype = string.lower(spelltype)
if spelltype == "" or spelltype == "help" then
	--spelltype not given, so only /mra or /fc given, so we're gonna explain how to use this.
	Consumearray = table.shallow_copy(flasks)
	DEFAULT_CHAT_FRAME:AddMessage("|cffE0B0FF----------------------------------------------------")
	DEFAULT_CHAT_FRAME:AddMessage("|cffE0B0FFWelcome to Mijk's Raid Assist " .. version)
	DEFAULT_CHAT_FRAME:AddMessage("|cffE0B0FF----------------------------------------------------")
	DEFAULT_CHAT_FRAME:AddMessage("|cffE0B0FFUse '/mra FLASK' to show Flasks on players.")
	DEFAULT_CHAT_FRAME:AddMessage("|cffE0B0FFUse '/mra GPP' to show All Greater Protection Potions on players.\n\n")
	DEFAULT_CHAT_FRAME:AddMessage("|cffE0B0FFUse '/mra GFPP' to show Greater Fire Protection Potion on players.")
	DEFAULT_CHAT_FRAME:AddMessage("|cffE0B0FFUse '/mra GSPP' to show Greater Shadow Protection Potion on players.")
	DEFAULT_CHAT_FRAME:AddMessage("|cffE0B0FFUse '/mra GNPP' to show Greater Nature Protection Potion on players.")
	DEFAULT_CHAT_FRAME:AddMessage("|cffE0B0FFUse '/mra GAPP' to show Greater Arcane Protection Potion on players.")
	DEFAULT_CHAT_FRAME:AddMessage("|cffE0B0FFUse '/mra GFRPP' to show Greater Frost Protection Potion on players.")
	DEFAULT_CHAT_FRAME:AddMessage("|cffE0B0FFUse '/mra MM' to show Mongoose on Melee & Mageblood on Casters.\n\n")
	DEFAULT_CHAT_FRAME:AddMessage("|cffE0B0FFType '/mra GUI' if you're lazy, all commands are NOT CaseSensitive.")
	DEFAULT_CHAT_FRAME:AddMessage("|cffE0B0FF----------------------------------------------------")
	
else
	--DEFAULT_CHAT_FRAME:AddMessage("Spelltype = " .. spelltype)
	if spelltype == "flask" then Consumearray = table.shallow_copy(flasks); typebuff = "single"; requiredbuffs = ({"Flask of Supreme Power", "Flask of Distilled Wisdom", "Flask of the Titans"})
	elseif spelltype == "gpp" then Consumearray = table.shallow_copy(GPP); typebuff = "multi"; requiredbuffs = {"GFPP", "GSPP", "GNPP", "GAPP", "GFRPP"}; alternativebuffs = {"FPP", "SPP", "NPP", "APP", "FRPP"}
	elseif spelltype == "gspp" then Consumearray = { GSPP }; typebuff = "single"; requiredbuffs = {"GSPP"}; alternativebuffs = {"SPP"}
	elseif spelltype == "gfpp" then Consumearray = { GFPP }; typebuff = "single"; requiredbuffs = {"GFPP"}; alternativebuffs = {"FPP"}
	elseif spelltype == "gnpp" then Consumearray = { GNPP }; typebuff = "single"; requiredbuffs = {"GNPP"}; alternativebuffs = {"NPP"}
	elseif spelltype == "gapp" then Consumearray = { GAPP }; typebuff = "single"; requiredbuffs = {"GAPP"}; alternativebuffs = {"APP"}
	elseif spelltype == "gfrpp" then Consumearray = { GFRPP }; typebuff = "single"; requiredbuffs = {"GFRPP"}; alternativebuffs = {"FPP"}
	elseif spelltype == "mm" then Consumearray = table.shallow_copy(MAGEMON); typebuff = "multi"; requiredbuffs = {"Mageblood", "Mongoose"}; alternativebuffs = {"nothing", "nothing"}
	elseif spelltype == "gui" then frame:Show(); return; 
	else --if parameter doesn't match the above, dont start checking, start telling them how to use.
		DEFAULT_CHAT_FRAME:AddMessage("|cffE0B0FFMijk's Raid Assist: Please type '/fc Help' to see how to use this")
		valid = false
	end
	if valid then --and off we go !
		CheckBuffs(spelltype, typebuff, requiredbuffs, alternativebuffs)
	end
end


	
end

function LineOpen()
	DEFAULT_CHAT_FRAME:AddMessage("|cffE0B0FF---------------Mijk's Raid Assist---------------", 0.5, 1.0, 1.0)
end
function LineClose()
	DEFAULT_CHAT_FRAME:AddMessage("|cffE0B0FF----------------------------------------------------", 0.5, 1.0, 1.0)
end

SlashCmdList["MRA"] = MRA;


	----------------------------------------START GUI HERE

frame:SetHeight(300)
frame:SetWidth(200)
frame:SetPoint("RIGHT", UIParent, "RIGHT", -50, 0)
frame:EnableMouse(true)
frame:SetBackdrop({
    bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
    edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = {
        left = 4,
        right = 4,
        top = 4,
        bottom = 4,
    },
})
frame:SetBackdropBorderColor(1, 0, 0, 1)
frame:SetBackdropColor(0, 0, 0, 0.7)

-- set the title
frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.title:SetPoint("TOP", 0, -8)
frame.title:SetText("Mijk's Raid Assist\n|cff008000 <Thunderhorn Clan>")
frame.title:SetTextColor(0, 1, 0) -- set green color
frame.title:SetJustifyH("CENTER") -- center the title


-- make the frame draggable
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnMouseDown", function()
    if arg1 == "LeftButton" then
        frame:StartMoving()
    end
end)
frame:SetScript("OnMouseUp", function()
    if arg1 == "LeftButton" then
        frame:StopMovingOrSizing()
    end
end)

-- create buttons and set their properties
local button1 = CreateFrame("Button", "MyButton1", frame, "UIPanelButtonTemplate")
button1:SetWidth(150)
button1:SetHeight(25)
button1:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, -40)
button1:SetText("Check for Flasks")
button1:SetScript("OnClick", function(self, button, down)
    MRA("flask")
end)


local button2 = CreateFrame("Button", "MyButton2", frame, "UIPanelButtonTemplate")
button2:SetWidth(150)
button2:SetHeight(25)
button2:SetPoint("TOPLEFT", button1, "BOTTOMLEFT", 0, -5)
button2:SetText("Check All Greater PP")
button2:SetScript("OnClick", function(self, button, down)
    MRA("gpp")
end)

local button3 = CreateFrame("Button", "MyButton3", frame, "UIPanelButtonTemplate")
button3:SetWidth(75)
button3:SetHeight(25)
button3:SetPoint("TOPLEFT", button2, "BOTTOMLEFT", 0, -5)
button3:SetText("GFPP")
button3:SetScript("OnClick", function(self, button, down)
    MRA("gfpp")
end)

local button4 = CreateFrame("Button", "MyButton4", frame, "UIPanelButtonTemplate")
button4:SetWidth(75)
button4:SetHeight(25)
button4:SetPoint("TOPRIGHT", button2, "BOTTOMRIGHT", 0, -5)
button4:SetText("GSPP")
button4:SetScript("OnClick", function(self, button, down)
    MRA("gspp")
end)

-- create button 5 and set its properties
local button5 = CreateFrame("Button", "MyButton5", frame, "UIPanelButtonTemplate")
button5:SetWidth(75)
button5:SetHeight(25)
button5:SetPoint("TOPLEFT", button3, "BOTTOMLEFT", 0, -5)
button5:SetText("GNPP")
button5:SetScript("OnClick", function(self, button, down)
    MRA("gnpp")
end)

-- create button 6 and set its properties
local button6 = CreateFrame("Button", "MyButton6", frame, "UIPanelButtonTemplate")
button6:SetWidth(75)
button6:SetHeight(25)
button6:SetPoint("TOPLEFT", button4, "BOTTOMLEFT", 0, -5)
button6:SetText("GAPP")
button6:SetScript("OnClick", function(self, button, down)
    MRA("gapp")
end)

-- create button 7 and set its properties
local button7 = CreateFrame("Button", "MyButton7", frame, "UIPanelButtonTemplate")
button7:SetWidth(150)
button7:SetHeight(25)
button7:SetPoint("TOPLEFT", button5, "BOTTOMLEFT", 0, -5)
button7:SetText("GFRPP")
button7:SetScript("OnClick", function(self, button, down)
    MRA("gfrpp")
end)

-- create button 7 and set its properties
local button8 = CreateFrame("Button", "Mybutton8", frame, "UIPanelButtonTemplate")
button8:SetWidth(150)
button8:SetHeight(25)
button8:SetPoint("TOPLEFT", button7, "BOTTOMLEFT", 0, -5)
button8:SetText("Mageblood/Mongoose")
button8:SetScript("OnClick", function(self, button, down)
    MRA("mm")
end)


-- create button 7 and set its properties
local button9 = CreateFrame("Button", "Mybutton9", frame, "UIPanelButtonTemplate")
button9:SetWidth(75)
button9:SetHeight(25)
button9:SetPoint("TOPLEFT", button8, "BOTTOMLEFT", 0, -25)
button9:SetText("Help")
button9:SetScript("OnClick", function(self, button, down)
    MRA("help")
end)

-- create button 7 and set its properties
local button10 = CreateFrame("Button", "Mybutton10", frame, "UIPanelButtonTemplate")
button10:SetWidth(75)
button10:SetHeight(25)
button10:SetPoint("TOPRIGHT", button8, "BOTTOMRIGHT", 0, -25)
button10:SetText("Hide")
button10:SetScript("OnClick", function(self, button, down)
    frame:Hide()
end)


-- create a font object
--local font = CreateFont("MyAddonFont")
--font:SetFont("Fonts\\FRIZQT__.TTF", 10)

-- create a text label
local myLabel = CreateFrame("Frame", "MyAddonLabel", frame)
myLabel:SetWidth(150)
myLabel:SetHeight(25)
myLabel:SetPoint("TOPLEFT", button9, "BOTTOMLEFT", 0, -5)

local text = myLabel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
--text:SetFontObject(font)
text:SetPoint("CENTER", myLabel, "CENTER", 0, 0)
text:SetText("|cff008000Version " .. version)
text:SetTextColor(0, 1, 0) -- set green color


-- create a close button and set its properties
local closeButton = CreateFrame("Button", "MyCloseButton", frame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
closeButton:SetScript("OnClick", function()
    frame:Hide()
end)
----------------------------------------END GUI HERE

frame:Hide()