local SpellID = nil;
local playerClass = "";

local GCDSpell = {
  ["WARRIOR"]  = {
    spell = "Sunder Armor"
  },
  ["HUNTER"]  = {
    spell = "Hunter's Mark"
  },
  ["PRIEST"]  = {
    spell = "Renew"
  },
  ["SHAMAN"]  = {
    spell = "Lightning Bolt"
  },
  ["WARLOCK"]  = {
    spell = "Shadow Bolt"
  },
  ["DRUID"]  = {
    spell = "Wrath"
  },
  ["PALADIN"]  = {
    spell = "Seal of Righteousness"
  },
  ["ROGUE"]  = {
    spell = "Sinister Strike"
  },
  ["MAGE"]  = {
    spell = "Fireball"
  },
}

RTT_LastFail = 0;

RTT_CastSpellData = {
  name = "",
  sent = true,
  timestamp = 0,
  symbol = 0;
}

function RTT_CastSpell(spell)
  CastSpellByName(spell);
  if(SpellID == nil or not RTT_SpellIsTrackable(spell) or GetRaidTargetIndex("target") == nil) then
    return
  end
  local start, _ = GetSpellCooldown(SpellID, "spell");
  if(GetTime() - start == 0) then
    --store timestamp, unitname and unit symbol
    RTT_CastSpellData.name = spell;
    RTT_CastSpellData.timestamp = GetTime();
    RTT_CastSpellData.symbol = GetRaidTargetIndex("target");
    RTT_CastSpellData.sent = false;
    --success, test with self_damage fail (miss, dodge)
  end
end

function RTT_CastFFFeral()
    CastSpellByName("Faerie Fire (Feral)");
    if(SpellID == nil or playerClass ~= "DRUID" or GetRaidTargetIndex("target") == nil) then
      return
    end
    local start, _ = GetSpellCooldown(SpellID, "spell");
    if(GetTime() - start == 0) then
      --store timestamp, unitname and unit symbol
      RTT_CastSpellData.name = "Faerie Fire";
      RTT_CastSpellData.timestamp = GetTime();
      RTT_CastSpellData.symbol = GetRaidTargetIndex("target");
      RTT_CastSpellData.sent = false;
      --success, test with self_damage fail (miss, dodge)
    end

end

function RTT_SetSpellID()
  _, playerClass = UnitClass("player");
  local i = 1
  while true do
   local spellName = GetSpellName(i, "spell")
    if(spellName == GCDSpell[playerClass].spell) then
      SpellID = i;
      return i;
    end
    if not spellName then
      break
    end
   i = i + 1
 end
end
