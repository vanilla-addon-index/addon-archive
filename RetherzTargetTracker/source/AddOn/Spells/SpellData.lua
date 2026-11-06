RTT_SpellData = {
  ["Sunder Armor"] = {
    name = "Sunder Armor";
    duration = 30;
    class = "WARRIOR";
    icon = "Interface\\Icons\\Ability_Warrior_Sunder";
  },
  ["Faerie Fire"] = {
    name = "Faerie Fire";
    duration = 40;
    class = "DRUID";
    icon = "Interface\\Icons\\Spell_Nature_FaerieFire";
  },
  ["Curse of Recklessness"] = {
    name = "Curse of Recklessness";
    duration = 120;
    class = "WARLOCK";
    icon = "Interface\\Icons\\Spell_Shadow_UnholyStrength";
  },
  ["Curse of Shadow"] = {
    name = "Curse of Shadow";
    duration = 300;
    class = "WARLOCK";
    icon = "Interface\\Icons\\Spell_Shadow_CurseOfAchimonde";
  },
  ["Curse of the Elements"] = {
    name = "Curse of the Elements";
    duration = 300;
    class = "WARLOCK";
    icon = "Interface\\Icons\\Spell_Shadow_ChillTouch";
  },
  ["Curse of Tongues"] = {
    name = "Curse of Tongues";
    duration = 30;
    class = "WARLOCK";
    icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges";
  },
  ["Armor Shatter"] = {
    name = "Armor Shatter";
    duration = 30;
    class = "PROC";
    icon = "Interface\\Icons\\Inv_Axe_12";
  },
  ["Spell Vulnerability"] = {
    name = "Spell Vulnerability";
    duration = 5;
    class = "PROC";
    icon = "Interface\\Icons\\Spell_Holy_ElunesGrace";
  },
}

local classSpellTable = {};

function RTT_SpellData_GetDuration(name)
  return RTT_SpellData[name].duration;
end

function RTT_SpellData_GetIcon(name)
  return RTT_SpellData[name].icon;
end

function RTT_SpellData_SetSpellTable(class)
  for k, v in pairs(RTT_SpellData) do
    if(RTT_SpellData[k].class == class) then
      table.insert(classSpellTable, k)
    end
  end
end

function RTT_SpellData_GetSpellTable(class)
  local t = {}
  for k, v in pairs(RTT_SpellData) do
    if(RTT_SpellData[k].class == class) then
      table.insert(t, RTT_SpellData[k])
    end
  end
  return t;
end

function RTT_SpellIsTrackable(string)
  for k, v in pairs(classSpellTable) do
    if(strfind(string, v)) then
      return true;
    end
  end
end
