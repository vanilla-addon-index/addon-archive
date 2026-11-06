-- pandaUI :: modules/characterstats.lua
--
-- The Character window's stat readout: what the stats side panel
-- (modules/characterstatspanel.lua) lists. Data only -- nothing here draws.
--
-- The list follows ForeverFrameXML's Camelot PAPERDOLL_STATCATEGORIES, cut to
-- what this client can answer (knowledge.json / character.modern_stat_apis_absent,
-- FOCUSED_RUNTIME_PROBE 2026-09-28): none of the 41 post-1.12 stat functions
-- that panel calls exist here. Three kinds of value therefore appear:
--
--   * read   -- a 1.12 getter measured on this client
--               (character.stat_api_1_12_return_shapes): health, power,
--               attributes, damage, speed, attack power, weapon skill, armor,
--               defense, dodge/parry/block, resistances.
--   * parsed -- a number the client prints in a tooltip, read through a
--               private scanner (statsrc probe, 2026-09-28): melee crit from
--               the Attack spell's tooltip, and each weapon's base Speed,
--               which turns the live attack speed into a haste figure.
--   * calculated -- built from equipped-item, current-rank talent, buff and
--               debuff tooltip text plus the same 1.12 class formulas as
--               BetterCharacterStats. These values are displayed normally.
--
-- Tooltip text is read only through U.TooltipRegionText: this client leaves a
-- hidden right-hand region holding the previous tooltip's text (statsrc run:
-- a shirt reported "30 yd range", an off-hand the main hand's "Speed 2.00").
-- Line colour is not usable (every line reported white), so an inactive set
-- bonus is recognised by its "(n) Set:" prefix, not by its grey.
--
-- BetterCharacterStats' matching table is English-only, so this parity path
-- intentionally has the same limitation on other client languages.
--
-- One top-level table (rules/pandaui.md, Lua local budget).

local U = PandaUI

local CS = {
  SCANNER = "PandaUICharacterStatsScanner",
  MAX_LINES = 30,
  -- Equipment slots whose tooltips can carry a bonus: head .. ranged. The
  -- ammo slot (0) and the tabard (19) never do.
  GEAR_FIRST = 1,
  GEAR_LAST = 19,
  SLOT_OFFHAND = 17,
  SLOT_RANGED = 18,
  MAX_SPELLS = 300,
  -- UnitResistance school ids in the order the panel lists them, with the
  -- locale key of each label.
  -- The third field is the school's GEAR_BONUS key.
  RESISTANCES = {
    { 6, "CHARSTATS_RES_ARCANE", "res_arcane" },
    { 2, "CHARSTATS_RES_FIRE", "res_fire" },
    { 3, "CHARSTATS_RES_NATURE", "res_nature" },
    { 4, "CHARSTATS_RES_FROST", "res_frost" },
    { 5, "CHARSTATS_RES_SHADOW", "res_shadow" },
  },
  ATTRIBUTES = {
    "CHARSTATS_STR", "CHARSTATS_AGI", "CHARSTATS_STA", "CHARSTATS_INT",
    "CHARSTATS_SPI",
  },
  -- GEAR_BONUS keys of the five UnitStat indices.
  ATTRIBUTE_BONUS = { "str", "agi", "sta", "int", "spi" },
  POWER_LABEL = {
    [0] = "CHARSTATS_MANA", [1] = "CHARSTATS_RAGE", [2] = "CHARSTATS_FOCUS",
    [3] = "CHARSTATS_ENERGY",
  },
  -- Spellbook names whose tooltip prints a crit chance. 1.12 prints it on
  -- Attack ("5.00%  chance to crit", statsrc run 2026-09-28, enUS); the
  -- ranged names are the same convention and are not yet verified -- a name
  -- whose tooltip has no percentage simply leaves the row out.
  MELEE_SPELLS = { ["Attack"] = true, ["Attaque"] = true,
                   ["Атака"] = true, ["攻击"] = true },
  RANGED_SPELLS = { ["Auto Shot"] = true, ["Shoot"] = true, ["Throw"] = true,
                    ["Shoot Bow"] = true, ["Shoot Gun"] = true,
                    ["Shoot Crossbow"] = true, ["Tir automatique"] = true,
                    ["Автоматическая стрельба"] = true, ["自动射击"] = true },
  SCHOOLS = { holy = true, fire = true, nature = true, frost = true,
              shadow = true, arcane = true },
  SPELL_SCHOOLS = {
    { "arcane", "CHARSTATS_SCHOOL_ARCANE" },
    { "fire", "CHARSTATS_SCHOOL_FIRE" },
    { "frost", "CHARSTATS_SCHOOL_FROST" },
    { "holy", "CHARSTATS_SCHOOL_HOLY" },
    { "nature", "CHARSTATS_SCHOOL_NATURE" },
    { "shadow", "CHARSTATS_SCHOOL_SHADOW" },
  },
  -- BetterCharacterStats' six selectable native pages. The Modern and
  -- Modern WoW panels list the same values as continuous categories; the
  -- Classic panel uses these definitions for its two dropdown columns.
  PAGES = {
    { key = "base", title = "CHARSTATS_PAGE_BASE",
      rows = { "CHARSTATS_STR", "CHARSTATS_AGI", "CHARSTATS_STA",
               "CHARSTATS_INT", "CHARSTATS_SPI", "CHARSTATS_ARMOR" } },
    { key = "melee", title = "CHARSTATS_CAT_MELEE",
      rows = { "CHARSTATS_SKILL", "CHARSTATS_DAMAGE", "CHARSTATS_SPEED",
               "CHARSTATS_AP", "CHARSTATS_HIT", "CHARSTATS_CRIT" } },
    { key = "ranged", title = "CHARSTATS_CAT_RANGED",
      rows = { "CHARSTATS_SKILL", "CHARSTATS_DAMAGE", "CHARSTATS_SPEED",
               "CHARSTATS_AP", "CHARSTATS_HIT", "CHARSTATS_CRIT" } },
    { key = "spell", title = "CHARSTATS_CAT_SPELL",
      rows = { "CHARSTATS_SPELL_DAMAGE", "CHARSTATS_SPELL_HIT",
               "CHARSTATS_SPELL_CRIT", "CHARSTATS_HEALING",
               "CHARSTATS_REGEN", "CHARSTATS_SPELL_HASTE" } },
    { key = "schools", title = "CHARSTATS_CAT_SCHOOLS",
      rows = { "CHARSTATS_SCHOOL_ARCANE", "CHARSTATS_SCHOOL_FIRE",
               "CHARSTATS_SCHOOL_FROST", "CHARSTATS_SCHOOL_HOLY",
               "CHARSTATS_SCHOOL_NATURE", "CHARSTATS_SCHOOL_SHADOW" } },
    { key = "defense", title = "CHARSTATS_CAT_DEFENSE",
      rows = { "CHARSTATS_ARMOR", "CHARSTATS_DEFENSE", "CHARSTATS_DODGE",
               "CHARSTATS_PARRY", "CHARSTATS_BLOCK",
               "CHARSTATS_AVOIDANCE" } },
  },
  -- 1.12 item wording, lower-cased, most specific first; one match per line.
  -- `both` is shared spell damage/healing, `school` one school's damage.
  GEAR_PATTERNS = {
    { "increases damage and healing done by magical spells and effects by up to (%d+)", "both" },
    { "increases healing done by spells and effects by up to (%d+)", "healing" },
    { "increases damage done by (%a+) spells and effects by up to (%d+)", "school" },
    { "healing and spell damage %+(%d+)", "both" },
    { "spell damage %+(%d+)", "both" },
    { "^%+(%d+) spell power", "both" },
    { "%+(%d+) damage and healing spells", "both" },
    { "%+(%d+) spell damage and healing", "both" },
    { "increases damage done by magical spells and effects by up to (%d+)", "damageOnly" },
    { "%+(%d+) healing spells", "healing" },
    { "healing spells %+(%d+)", "healing" },
    { "healing %+(%d+)", "healing" },
    { "%+(%d+) (%a+) spell damage", "school" },
    { "(%a+) damage %+(%d+)", "school" },
    { "improves your chance to hit with spells by (%d+)%%", "spellHit" },
    { "spell hit %+(%d+)", "spellHit" },
    { "improves your chance to get a critical strike with spells by (%d+)%%", "spellCrit" },
    { "(%d+)%% spell critical strike", "spellCrit" },
    { "improves your chance to hit by (%d+)%%", "hit" },
    { "%+(%d+)%% ranged hit", "rangedHit" },
    { "chance to get a critical strike with missile weapons by (%d+)%%", "rangedCrit" },
    { "%+(%d+)%% ranged crit", "rangedCrit" },
    { "%+(%d+)%% critical strike", "rangedCrit" },
    { "chance to get a critical strike by (%d+)%%", "crit" },
    { "restores (%d+) mana per 5 sec", "mp5" },
    { "%+(%d+) mana every 5 sec", "mp5" },
    { "mana regen (%d+) per 5 sec", "mp5" },
    { "allows (%d+)%% of your mana regeneration to continue while casting", "casting" },
    { "increases your attack and casting speed by (%d+)%%", "haste" },
    { "increases your casting speed by (%d+)%%", "spellHaste" },
    { "^%+(%d+)%% haste", "haste" },
    { "^attack speed %+(%d+)%%", "haste" },
    { "increases the block value of your shield by (%d+)", "blockValue" },
    { "block value %+(%d+)", "blockValue" },
    { "^(%d+) block$", "blockValue" },
    { "decreases the magical resistances of your spell targets by (%d+)", "spellPen" },
    { "%+(%d+) spell penetration", "spellPen" },
  },
  -- Item bonuses that only decide a row's colour (CS.GearColor): a value is
  -- green when an equipped item's own bonus line -- stat suffix, enchant,
  -- Equip: or active Set: line -- raises it, and white otherwise. An item's
  -- base armor or weapon damage is not a bonus. Every pattern is tried on
  -- every line; `skip` drops a conditional bonus, `not` a line that belongs
  -- to another row. A `damage` bonus counts for the hand it sits in.
  GEAR_BONUS = {
    { "%+(%d+) all stats", { "str", "agi", "sta", "int", "spi" } },
    { "%+(%d+) strength", "str" },
    { "%+(%d+) agility", "agi" },
    { "%+(%d+) stamina", "sta" },
    { "%+(%d+) intellect", "int" },
    { "%+(%d+) spirit", "spi" },
    { "%+(%d+) health%.?$", "health" },
    { "%+(%d+) mana%.?$", "mana" },
    { "%+(%d+) ranged attack power", "rangedAp" },
    { "%+(%d+) attack power", "ap", skip = { "when fighting", "forms only" } },
    { "%+(%d+) armor", "armor" },
    { "%+(%d+) defense", "defense" },
    { "increased defense %+(%d+)", "defense" },
    { "chance to dodge an attack by (%d+)%%", "dodge" },
    { "chance to parry an attack by (%d+)%%", "parry" },
    { "chance to block attacks with a shield by (%d+)%%", "block" },
    { "chance to get a critical strike by (%d+)%%", "crit" },
    { "increases your attack and casting speed by (%d+)%%", "haste" },
    { "increases your casting speed by (%d+)%%", "spellHaste" },
    { "^%+(%d+)%% haste", "haste" },
    { "^attack speed %+(%d+)%%", "haste" },
    { "increases the block value of your shield by (%d+)", "blockValue" },
    { "block value %+(%d+)", "blockValue" },
    { "^(%d+) block$", "blockValue" },
    { "^equip: increased [%a%- ]+ %+(%d+)", "skill", ["not"] = "defense" },
    { "%+(%d+) weapon damage", "damage" },
    { "^%+(%d+) damage%.?$", "damage" },
    { "%+(%d+) all resistances", { "res_arcane", "res_fire", "res_nature",
                                   "res_frost", "res_shadow" } },
    { "%+(%d+) arcane resistance", "res_arcane" },
    { "%+(%d+) fire resistance", "res_fire" },
    { "%+(%d+) nature resistance", "res_nature" },
    { "%+(%d+) frost resistance", "res_frost" },
    { "%+(%d+) shadow resistance", "res_shadow" },
  },
  -- BetterCharacterStats' vMaNGOS spell-crit curves: class base plus
  -- Intellect divided by a level-adjusted coefficient.
  SPELL_CRIT = {
    MAGE = { base = 3.70, coefficient = 14.77, level = 0.65 },
    WARLOCK = { base = 3.18, coefficient = 11.30, level = 0.82 },
    PRIEST = { base = 2.97, coefficient = 10.03, level = 0.82 },
    DRUID = { base = 3.33, coefficient = 12.41, level = 0.79 },
    SHAMAN = { base = 3.54, coefficient = 11.51, level = 0.80 },
    PALADIN = { base = 3.70, coefficient = 14.77, level = 0.65 },
  },
  -- Agility needed for one percent ranged crit, interpolated from level 1 to
  -- 60 as BetterCharacterStats does. Classes without a ranged weapon attack
  -- do not need an entry.
  RANGED_CRIT = {
    MAGE = { first = 12.9, last = 20, base = 3.2 },
    ROGUE = { first = 2.2, last = 29, base = 0 },
    HUNTER = { first = 3.5, last = 53, base = 0 },
    PRIEST = { first = 11, last = 20, base = 3 },
    WARLOCK = { first = 8.4, last = 20, base = 2 },
    WARRIOR = { first = 3.9, last = 20, base = 0 },
  },
  -- 1.12 Spirit regeneration per 2-second tick: `base` + Spirit / `div`.
  SPIRIT_REGEN = {
    PRIEST = { base = 12.5, div = 4 }, MAGE = { base = 12.5, div = 4 },
    WARLOCK = { base = 15, div = 5 }, DRUID = { base = 15, div = 5 },
    HUNTER = { base = 15, div = 5 }, PALADIN = { base = 15, div = 5 },
    SHAMAN = { base = 17, div = 5 },
  },
  scanner = nil,
  gearKey = nil,
  gear = nil,
  talentKey = nil,
  talents = nil,
  talentSpecial = nil,
  auras = nil,
  auraNames = nil,
  aurasDirty = true,
  meleeSpell = nil,
  rangedSpell = nil,
}
U.CharacterStats = CS

-- BetterCharacterStats reads the current-rank talent descriptions instead of
-- relying on talent names. Turtle WoW can therefore change a talent tree
-- without requiring a hard-coded rank table here.
CS.TALENT_PATTERNS = {
  { "Increases your chance to hit with melee weapons by (%d)%%%.", { hit = 1 } },
  { "Increases hit chance by (%d+)%%, and by an additional (%d+)%% while dual wielding", { hit = 1, surefooted = 2 } },
  { "Also increases chance to hit with melee attacks and spells by (%d+)%%%.", { hit = 1, spellHit = 1 } },
  { "Increases your chance to hit with melee attacks and spells by (%d+)%%%.", { hit = 1, spellHit = 1 } },
  { "Increases your chance to hit with spells and melee attacks by (%d+)%%", { hit = 1, spellHit = 1 } },
  { "Reduces the chance that the opponent can resist your Frost and Fire spells by (%d)%%%.", { spellHitFire = 1, spellHitFrost = 1 } },
  { "Reduces the chance that the opponent can resist your Arcane spells by (%d+)%%%.", { spellHitArcane = 1 } },
  { "Reduces the chance for enemies to resist your Holy and Discipline spells by (%d+)%%%.", { spellHitHoly = 1 } },
  { "Reduces your target's chance to resist your Shadow spells by (%d+)%%%.", { spellHitShadow = 1 } },
  { "Reduces the chance for enemies to resist your Affliction spells by (%d+)%%%.", { spellHitShadow = 1 } },
  { "Increases your critical strike chance with ranged weapons by (%d)%%%.", { rangedCrit = 1 } },
  { "Increases your critical strike chance with all attacks by (%d)%%%.", { rangedCrit = 1 } },
  { "Increases your spell damage and critical srike chance by (%d+)%%%.", { spellCrit = 1 } },
  { "Allows (%d+)%% of your Mana regeneration to continue while casting%.", { casting = 1, waterShieldRank = "rank" } },
  { "Increases your total intellect by %d+%% and your spell casting speed by (%d+)%%", { spellHaste = 1 } },
  { "Zeal increases your attack and casting speed by an additional (%d+)%% per stack", { vengefulStrikes = 1 } },
  { "Increases your melee attack speed by (%d+)%%", { haste = 1 } },
  { "Causes your attacks to ignore (%d+) of your target's Armor per level", { armorPenPerLevel = 1 } },
  { "Increases spell damage and healing by up to (%d+)%% of your total Spirit%.", { spiritualGuidance = 1 } },
  { "Increases the effects of your Inner Fire spell by (%d+)%%%.", { improvedInnerFire = 1 } },
  { "Increases healing done by spells and effects by up to (%d+)%% of your Armor from items", { ironclad = 1 } },
  { "Increases your armor value from items by (%d+)%%%.", { toughness = 1 } },
  { "increases block amount by (%d+)%%", { enhancingTotems = 1 } },
  { "amount of damage absorbed by your shield by (%d+)%%", { blockMod = 1 } },
  { "increases the amount blocked by (%d+)%%", { blockMod = 1 } },
}

-- Class-specific spell critical bonuses are tooltip-only details in the
-- reference addon. Some of them also change its primary displayed value.
CS.TALENT_CRIT_PATTERNS = {
  PALADIN = {
    { "Increases the critical effect chance of your Holy Light and Flash of Light by (%d+)%%%.", { paladinHoly = 1, paladinFlash = 1 } },
    { "Improves your chance to get a critical strike with Holy Shock by (%d+)%%%.", { paladinShock = 1 } },
  },
  DRUID = {
    { "Increases the damage and critical strike chance of your Moonfire spell by (%d+)%%%.", { druidMoonfire = 1 } },
    { "Increases the critical effect chance of your Regrowth spell by (%d+)%%%.", { druidRegrowth = 1 } },
  },
  WARLOCK = {
    { "Increases the critical strike chance of your Destruction spells by (%d+)%%%.", { warlockDestruction = 1, warlockSearing = 1 } },
    { "Increases the critical strike chance of your Searing Pain spell by (%d+)%%%.", { warlockSearing = 1 } },
  },
  MAGE = {
    { "Increases the critical strike chance of your Arcane Explosion and Arcane Missiles spells by an additional (%d+)%%%.", { mageArcane = 1 } },
    { "Increases the critical strike chance of your Fire Blast and Scorch spells by (%d+)%%%.", { mageFireBlast = 1, mageScorch = 1 } },
    { "Increases the critical strike chance of your Flamestrike spell by (%d+)%%%.", { mageFlamestrike = 1 } },
    { "Increases the critical strike chance of your Fire spells by (%d+)%%%.", { mageFire = 1, mageFireBlast = 1, mageScorch = 1, mageFlamestrike = 1 } },
    { "Increases the critical strike chance of all your spells against frozen targets by (%d+)%%%.", { mageShatter = 1 } },
  },
  PRIEST = {
    { "Increases the critical effect chance of your Holy and Discipline spells by (%d+)%%%.", { priestHoly = 1, priestDiscipline = 1 } },
    { "Increases your spell damage and the critical strike chance of your offensive spells by (%d+)%%", { priestOffensive = 1 } },
  },
  SHAMAN = {
    { "Increases the critical strike chance of your Lightning Bolt and Chain Lightning spells by an additional (%d+)%%%.", { shamanLightningBolt = 1, shamanChainLightning = 1 } },
    { "Increases the critical effect chance of your healing and lightning spells by (%d+)%%%.", { shamanLightningBolt = 1, shamanChainLightning = 1, shamanLightningShield = 1, shamanHealing = 1 } },
  },
}

CS.AURA_PATTERNS = {
  { "Chance to hit increased by (%d)%%%.", { hit = 1 } },
  { "Improves your chance to hit by (%d+)%%%.", { hit = 1 } },
  { "Increases attack power by %d+ and chance to hit by (%d+)%%%.", { hit = 1 } },
  { "Spell hit chance increased by (%d+)%%%.", { spellHit = 1 } },
  { "Increases your chance to hit with spells by (%d+)%%", { spellHit = 1 } },
  { "Agility increased by 25, Critical hit chance increases by (%d)%%%.", { rangedCrit = 1 } },
  { "Increases chance for a melee, ranged, or spell critical by (%d+)%% and all attributes by %d+%.", { rangedCrit = 1, spellCrit = 1 } },
  { "Critical strike chance increased by (%d+)%%%.", { rangedCrit = 1 } },
  { "Increases ranged and melee critical chance by (%d+)%%%.", { rangedCrit = 1 } },
  { "Chance for a critical hit with a spell increased by (%d+)%%%.", { spellCrit = 1 } },
  { "Increases spell critical chance by (%d)%%%.", { spellCrit = 1 } },
  { "Chance to get a critical strike with spells is increased by (%d+)%%", { spellCrit = 1 } },
  { "Critical strike chance with spells and melee attacks increased by (%d+)%%%.", { spellCrit = 1 } },
  { "Magical damage dealt is increased by up to (%d+)%.", { damageOnly = 1 } },
  { "Increases damage and healing done by magical spells and effects by up to (%d+)", { spellDamage = 1 } },
  { "Your damage and healing done by magical spells and effects is increased by up to (%d+)", { spellDamage = 1 } },
  { "Spell damage and healing increased by up to (%d+)", { spellDamage = 1 } },
  { "Magical damage dealt by spells and abilities is increased by up to (%d+)", { damageOnly = 1 } },
  { "Spell damage is increased by up to (%d+)", { damageOnly = 1 } },
  { "Spell damage increased by up to (%d+)", { damageOnly = 1 } },
  { "Spell Damage increased by (%d+)", { damageOnly = 1 } },
  { "Increased damage done by magical spells and effects by (%d+)%.", { innerFire = 1 } },
  { "Arcane damage dealt by spells and abilities is increased by up to (%d+)", { arcane = 1 } },
  { "Fire damage dealt by spells and abilities is increased by up to (%d+)", { fire = 1 } },
  { "Frost damage dealt by spells and abilities is increased by up to (%d+)", { frost = 1 } },
  { "Holy damage dealt by spells and abilities is increased by up to (%d+)", { holy = 1 } },
  { "Nature damage dealt by spells and abilities is increased by up to (%d+)", { nature = 1 } },
  { "Shadow damage dealt by spells and abilities is increased by up to (%d+)", { shadow = 1 } },
  { "Healing done by magical spells is increased by up to (%d+)%.", { healing = 1 } },
  { "Increases healing done by magical spells by up to (%d+) for 3600 sec%.", { healing = 1 } },
  { "Healing increased by up to (%d+)%.", { healing = 1 } },
  { "Healing spells increased by up to (%d+)%.", { healing = 1 } },
  { "Increases healing done by magical spells and effects by up to (%d+)%.", { healing = 1 } },
  { "Healing done is increased by up to (%d+)", { healing = 1 } },
  { "Healing Bonus increased by (%d+)", { healing = 1 } },
  { "Restores (%d+) mana per 5 sec%.", { mp5 = 1 } },
  { "Regenerating (%d+) Mana every 5 seconds%.", { mp5Tick = 1 } },
  { "Regenerate (%d+) mana per 5 sec%.", { mp5 = 1 } },
  { "Mana Regeneration increased by (%d+) every 5 seconds%.", { mp5Tick = 1 } },
  { "Restores (%d+) mana every 1 sec%.", { mp1 = 1 } },
  { "Restores (%d+) mana per 5 seconds%.", { mp5 = 1 } },
  { "(%d+)%% of your Mana regeneration continuing while casting%.", { casting = 1 } },
  { "(%d+)%% of your mana regeneration to continue while casting%.", { casting = 1 } },
  { "Allows (%d+)%% of mana regeneration while casting%.", { casting = 1 } },
  { "continue (%d+)%% of their Mana regeneration", { casting = 1 } },
  { "^Increases attack speed by (%d+)%% and spell casting speed by (%d+)%%", { haste = 1 } },
  { "^Increases attack and spell casting speed by (%d+)%%", { haste = 1 } },
  { "increases casting speed by (%d+)%%", { spellHaste = 1 } },
  { "^Increases casting and attack speed by (%d+)%%", { haste = 1 } },
  { "^Increases attack and casting speed by (%d+)%%", { haste = 1 } },
  { "^Casting speed increased by (%d+)%%", { spellHaste = 1 } },
  { "^Attack and casting speed increased by (%d+)%%", { zealHaste = 1 } },
  { "^Increases your attack and casting speed by (%d+)%%", { haste = 1 } },
  { "^Ignore (%d+) of enemies' armor", { armorPen = 1 } },
  { "^Current target's armor is reduced by (%d+)", { armorPen = 1 } },
  { "Block value increased by (%d+)", { blockValue = 1 } },
  { "Block Value increased by (%d+)", { blockValue = 1 } },
}

CS.DEBUFF_PATTERNS = {
  { "Chance to hit reduced by (%d+)%%%.", { hitDebuff = 1 } },
  { "Chance to hit decreased by (%d+)%% and %d+ Nature damage every %d+ sec%.", { hitDebuff = 1 } },
  { "Spell critical%-hit chance reduced by (%d+)%%%.", { spellCritDebuff = 1 } },
}

-- ---------------------------------------------------------------------------
-- Guarded client reads
-- ---------------------------------------------------------------------------
function CS.Call(name, a, b)
  local fn = U.G(name)
  if type(fn) ~= "function" then return false end
  return pcall(fn, a, b)
end

function CS.Number(value)
  return tonumber(value) or 0
end

function CS.AddValue(target, key, value)
  value = CS.Number(value)
  if value ~= 0 then target[key] = (target[key] or 0) + value end
end

-- Applies a BetterCharacterStats-style tooltip pattern. A field maps to one
-- of the pattern's captures; "rank" stores the learned talent rank instead.
function CS.ApplyPattern(target, text, entry, rank)
  local _, _, a, b, c, d = string.find(text, entry[1])
  if not a then return false end
  local values = { a, b, c, d }
  local key, source
  for key, source in pairs(entry[2]) do
    local value = source == "rank" and rank or values[source]
    CS.AddValue(target, key, value)
  end
  return true
end

function CS.ApplyPatterns(target, text, patterns, rank)
  local found = false
  local i
  for i = 1, table.getn(patterns) do
    if CS.ApplyPattern(target, text, patterns[i], rank) then found = true end
  end
  return found
end

function CS.Scanner()
  if CS.scanner then return CS.scanner end
  CS.scanner = U.CreateScannerTooltip(CS.SCANNER)
  return CS.scanner
end

-- The shown left and right texts of the scanner after `setter` filled it, in
-- core/itemsort.lua's verified order: ClearLines, SetOwner, then the setter.
-- U.ScanWithTooltip arms the scanner and hides it on every exit path.
function CS.ScanLines(setter)
  return U.ScanWithTooltip(CS.Scanner(), CS.ReadLines, setter)
end

function CS.ReadLines(tip, setter)
  if not pcall(setter, tip) then return nil end
  local countOk, count = pcall(tip.NumLines, tip)
  count = countOk and tonumber(count) or 0
  if count > CS.MAX_LINES then count = CS.MAX_LINES end
  local left, right = {}, {}
  local i
  for i = 1, count do
    left[i] = U.TooltipLineText(CS.SCANNER, "Left", i)
    right[i] = U.TooltipLineText(CS.SCANNER, "Right", i)
  end
  return left, right, count
end

-- ---------------------------------------------------------------------------
-- Equipment
-- ---------------------------------------------------------------------------

-- The equipped item id, or nil. An empty slot answers GetInventoryItemLink
-- with a placeholder link to item 0 rather than nil
-- (inventory.empty_slot_link_returns_item_zero), so its icon decides.
function CS.ItemId(slot)
  local okTexture, texture = CS.Call("GetInventoryItemTexture", "player", slot)
  if not okTexture or not texture then return nil end
  local ok, link = CS.Call("GetInventoryItemLink", "player", slot)
  if not ok or type(link) ~= "string" then return nil end
  local _, _, id = string.find(link, "item:(%d+)")
  id = tonumber(id)
  if not id or id <= 0 then return nil end
  return id, link
end

-- GetItemInfo's eighth return is the INVTYPE_* equip location on this client
-- (statsrc run 2026-09-28).
function CS.EquipLoc(slot)
  local id = CS.ItemId(slot)
  if not id then return nil end
  local ok, _, _, _, _, _, _, _, equipLoc = CS.Call("GetItemInfo", id)
  if not ok or type(equipLoc) ~= "string" then return nil end
  return equipLoc
end

function CS.GearKey()
  local parts = {}
  local slot
  for slot = CS.GEAR_FIRST, CS.GEAR_LAST do
    local id, link = CS.ItemId(slot)
    table.insert(parts, link or "-")
  end
  local enchant = U.G("GetWeaponEnchantInfo")
  if type(enchant) == "function" then
    local ok, main, _, mainCharges, off, _, offCharges = pcall(enchant)
    if ok then
      table.insert(parts, table.concat({ tostring(main), tostring(mainCharges),
                                         tostring(off), tostring(offCharges) }, ":"))
    end
  end
  return table.concat(parts, "|")
end

-- Records the line's GEAR_BONUS matches in totals.bonus.
function CS.AddGearBonus(totals, line, slot)
  local i, j
  for i = 1, table.getn(CS.GEAR_BONUS) do
    local entry = CS.GEAR_BONUS[i]
    local _, _, amount = string.find(line, entry[1])
    amount = amount and CS.Number(amount) or 0
    local skipped = entry["not"] and string.find(line, entry["not"], 1, true)
    if entry.skip then
      for j = 1, table.getn(entry.skip) do
        if string.find(line, entry.skip[j], 1, true) then skipped = true end
      end
    end
    if amount > 0 and not skipped then
      local keys = entry[2]
      if keys == "damage" then
        keys = (slot == CS.SLOT_RANGED) and "rangedDamage" or "meleeDamage"
      end
      if type(keys) ~= "table" then keys = { keys } end
      for j = 1, table.getn(keys) do
        totals.bonus[keys[j]] = (totals.bonus[keys[j]] or 0) + amount
      end
    end
  end
end

function CS.AddSetBonus(totals, line, setName, seen)
  if not setName or not string.find(line, "^set:") then return end
  local patterns = {
    { "^set: improves your chance to hit by (%d)%%", "hit" },
    { "^set: improves your chance to hit with spells by (%d)%%", "spellHit" },
    { "^set: improves your chance to get a critical strike by (%d)%%", "rangedCrit" },
    { "^set: improves your chance to get a critical strike with spells by (%d)%%", "spellCrit" },
    { "^set: increases damage and healing done by magical spells and effects by up to (%d+)", "spellDamage" },
    { "^set: increases healing done by spells and effects by up to (%d+)", "healing" },
    { "^set: allows (%d+)%% of your mana regeneration to continue while casting", "casting" },
    { "^set: restores (%d+) mana per 5 sec", "mp5" },
    { "^set: increases your attack and casting speed by (%d+)%%", "haste" },
    { "^set: your attacks ignore (%d+) of the target's armor", "armorPen" },
    { "^set: decreases the magical resistances of your spell targets by (%d+)", "spellPen" },
    { "^set: increases the block value of your shield by (%d+)", "blockValue" },
    { "^set: improves your chance to get a critical strike with holy spells by (%d)%%", "priestHoly" },
    { "^set: increases your chance of a critical hit with prayer of healing by (%d+)%%", "priestPrayer" },
  }
  local i
  for i = 1, table.getn(patterns) do
    local _, _, amount = string.find(line, patterns[i][1])
    if amount then
      local token = setName .. ":" .. patterns[i][2]
      if not seen[token] then
        seen[token] = true
        CS.AddValue(totals, patterns[i][2], amount)
      end
    end
  end
end

function CS.AddGearSpecial(totals, line, slot)
  local _, _, amount, second
  _, _, amount = string.find(line, "improves your chance to hit and get a critical strike with spells by (%d+)%%")
  if amount then
    CS.AddValue(totals, "spellHit", amount)
    CS.AddValue(totals, "spellCrit", amount)
    return true
  end
  _, _, amount = string.find(line, "improves your chance to hit with spells and attacks by (%d+)%%")
  if amount then
    CS.AddValue(totals, "hit", amount)
    CS.AddValue(totals, "spellHit", amount)
    return true
  end
  _, _, amount, second = string.find(line, "increases your spell damage by up to (%d+) and your healing by up to (%d+)")
  if amount then
    CS.AddValue(totals, "damageOnly", amount)
    CS.AddValue(totals, "healing", second)
    return true
  end
  _, _, amount, second = string.find(line, "^healing %+(%d+) and (%d+) mana per 5 sec")
  if amount then
    CS.AddValue(totals, "healing", amount)
    CS.AddValue(totals, "mp5", second)
    return true
  end
  if string.find(line, "^brilliant wizard oil") then
    CS.AddValue(totals, "spellDamage", 36)
    CS.AddValue(totals, "spellCrit", 1)
    return true
  elseif string.find(line, "^lesser wizard oil") then
    CS.AddValue(totals, "spellDamage", 16)
    return true
  elseif string.find(line, "^minor wizard oil") then
    CS.AddValue(totals, "spellDamage", 8)
    return true
  elseif string.find(line, "^wizard oil") then
    CS.AddValue(totals, "spellDamage", 24)
    return true
  elseif string.find(line, "^brilliant mana oil") then
    CS.AddValue(totals, "healing", 25)
    CS.AddValue(totals, "mp5", 12)
    return true
  elseif string.find(line, "^lesser mana oil") then
    CS.AddValue(totals, "mp5", 8)
    return true
  elseif string.find(line, "^minor mana oil") then
    CS.AddValue(totals, "mp5", 4)
    return true
  end
  _, _, amount = string.find(line, "^equip: your attacks ignore (%d+) of the target's armor")
  if amount then CS.AddValue(totals, "armorPen", amount); return true end
  return false
end

function CS.AddGearLine(totals, text, slot, setName, setSeen)
  local line = string.lower(text)
  local _, _, foundSet = string.find(line, "(.+) %(%d+/%d+%)")
  if foundSet then setName = foundSet end
  -- On-use and proc effects are not standing bonuses, and "(3) Set:" is a
  -- set bonus the player has not completed.
  if string.find(line, "^use:") or string.find(line, "^chance on hit:")
     or string.find(line, "^%(%d+%)") then
    return setName
  end
  if string.find(line, "restores %d+ mana per 5 sec") and
     string.find(line, "to all party members", 1, true) then return setName end
  CS.AddSetBonus(totals, line, setName, setSeen or {})
  if string.find(line, "^set:") then return setName end
  if CS.AddGearSpecial(totals, line, slot) then return setName end
  CS.AddGearBonus(totals, line, slot)
  local i
  for i = 1, table.getn(CS.GEAR_PATTERNS) do
    local entry = CS.GEAR_PATTERNS[i]
    local _, _, a, b = string.find(line, entry[1])
    if a then
      local kind = entry[2]
      if kind == "school" then
        -- The two school patterns capture in different orders.
        local school, amount = a, b
        if tonumber(a) then school, amount = b, a end
        if CS.SCHOOLS[school] then
          totals.school[school] = (totals.school[school] or 0) + CS.Number(amount)
        end
      elseif kind == "both" then
        totals.spellDamage = totals.spellDamage + CS.Number(a)
      else
        totals[kind] = totals[kind] + CS.Number(a)
      end
      return setName
    end
  end
  return setName
end

-- Weapon base speed: the one shown right-hand text holding a decimal number
-- ("Speed 2.00", "Vitesse 2,00"). Every other right text on an item is a word.
function CS.WeaponSpeed(right, count)
  local i
  for i = 1, count do
    local text = right[i]
    if text then
      local _, _, whole, frac = string.find(text, "(%d+)[%.,](%d%d)%s*$")
      if whole then return tonumber(whole .. "." .. frac) end
    end
  end
  return nil
end

function CS.ScanGear()
  local key = CS.GearKey()
  if CS.gear and key == CS.gearKey then return CS.gear end
  local totals = { spellDamage = 0, damageOnly = 0, healing = 0,
                   spellHit = 0, spellCrit = 0,
                   hit = 0, rangedHit = 0, crit = 0, rangedCrit = 0,
                   mp5 = 0, casting = 0, spellPen = 0, haste = 0,
                   spellHaste = 0, blockValue = 0, armorPen = 0,
                   priestHoly = 0, priestPrayer = 0,
                   school = {}, speed = {},
                   bonus = {} }
  local setSeen = {}
  local slot
  for slot = CS.GEAR_FIRST, CS.GEAR_LAST do
    if CS.ItemId(slot) then
      local left, right, count = CS.ScanLines(function(tip)
        tip:SetInventoryItem("player", slot)
      end)
      if left then
        local i, setName
        for i = 1, count do
          if left[i] then
            setName = CS.AddGearLine(totals, left[i], slot, setName, setSeen)
          end
        end
        totals.speed[slot] = CS.WeaponSpeed(right, count)
      end
    end
  end
  CS.gearKey, CS.gear = key, totals
  return totals
end

-- ---------------------------------------------------------------------------
-- Talents
-- ---------------------------------------------------------------------------
function CS.TalentKey()
  local parts = {}
  local okTabs, tabs = CS.Call("GetNumTalentTabs")
  tabs = okTabs and tonumber(tabs) or 0
  local tab, index
  for tab = 1, tabs do
    local okCount, count = CS.Call("GetNumTalents", tab)
    count = okCount and tonumber(count) or 0
    for index = 1, count do
      local ok, _, _, _, _, rank = CS.Call("GetTalentInfo", tab, index)
      table.insert(parts, ok and tostring(rank) or "?")
    end
  end
  return table.concat(parts, "/")
end

function CS.AddTalentLine(totals, text, rank, class)
  CS.ApplyPatterns(totals, text, CS.TALENT_PATTERNS, rank)
  local patterns = CS.TALENT_CRIT_PATTERNS[class]
  if patterns then CS.ApplyPatterns(totals, text, patterns, rank) end
end

-- Reads the current-rank text of every learned talent, matching the exact
-- BetterCharacterStats sources rather than a shortened name list.
function CS.ReadTalents()
  local key = CS.TalentKey()
  if CS.talents and key == CS.talentKey then return CS.talents end
  local totals = {}
  local okClass, _, class = CS.Call("UnitClass", "player")
  class = okClass and class or ""
  local okTabs, tabs = CS.Call("GetNumTalentTabs")
  tabs = okTabs and tonumber(tabs) or 0
  local tab, index
  for tab = 1, tabs do
    local okCount, count = CS.Call("GetNumTalents", tab)
    count = okCount and tonumber(count) or 0
    for index = 1, count do
      local ok, _, _, _, _, rank = CS.Call("GetTalentInfo", tab, index)
      rank = ok and tonumber(rank) or 0
      if rank > 0 then
        local left, _, lines = CS.ScanLines(function(tip)
          tip:SetTalent(tab, index)
        end)
        if left then
          local line
          for line = 1, lines do
            local text = left[line]
            if text == U.G("TOOLTIP_TALENT_NEXT_RANK") then break end
            if text then CS.AddTalentLine(totals, text, rank, class) end
          end
        end
      end
    end
  end
  CS.talentKey, CS.talents, CS.talentSpecial = key, totals, totals
  return totals
end

function CS.TalentSum(class, field, notes)
  local totals = CS.ReadTalents()
  local map = {
    hit = "hit", rangedHit = "hit", rangedCrit = "rangedCrit",
    spellHit = "spellHit", spellCrit = "spellCrit",
    castRegen = "casting", spellHaste = "spellHaste",
  }
  local key = map[field] or field
  return totals[key] or 0
end

-- ---------------------------------------------------------------------------
-- Active buffs and debuffs
-- ---------------------------------------------------------------------------
function CS.AddAuraLine(totals, names, text, harmful, state, class)
  names[text] = (names[text] or 0) + 1
  if harmful then
    CS.ApplyPatterns(totals, text, CS.DEBUFF_PATTERNS)
    if string.find(text, "Lowered chance to hit%.") then
      CS.AddValue(totals, "hitDebuff", 25)
    end
    return
  end

  CS.ApplyPatterns(totals, text, CS.AURA_PATTERNS)
  local _, _, regen, casting = string.find(text,
    "Mana regeneration increased by (%d+)%%%.[ ]+[ ]?(%d+)%% Mana regeneration may continue while casting%.")
  if regen then
    CS.AddValue(totals, "manaRegenPercent", regen)
    CS.AddValue(totals, "casting", casting)
  end
  if string.find(text, "Inner Focus", 1, true) then
    CS.AddValue(totals, "spellCrit", 25)
  end
  if string.find(text, "While active, target's critical hit chance with spells and attacks increases by 10%%%.") then
    CS.AddValue(totals, "spellCrit", 10)
  end
  if string.find(text, "Increases critical chance of spells by 10%%, melee and ranged by 5%% and grants 140 attack power%. 120 minute duration%.") then
    CS.AddValue(totals, "rangedCrit", 5)
    CS.AddValue(totals, "spellCrit", 10)
  end
  if string.find(text, "Increases hitpoints by 300%. 15%% haste to melee attacks%. %d+ mana regen every 5 seconds%.") then
    CS.AddValue(totals, "mp5", 10)
  end
  if class == "WARLOCK" then
    local _, _, amount = string.find(text, "Increases critical strike chance of Fire spells by (%d+)%%")
    CS.AddValue(totals, "warlockFire", amount)
  elseif class == "MAGE" then
    local _, _, amount = string.find(text, "Increases critical strike chance from Fire damage spells by (%d+)%%%.")
    CS.AddValue(totals, "mageFire", amount)
  elseif class == "SHAMAN" and string.find(text, "Elemental Mastery", 1, true) then
    totals.shamanElementalMastery = 1
  end
end

function CS.HasAura(pattern, harmful)
  local names = CS.auraNames
  if not names then return false end
  local text
  for text in pairs(names) do
    if (not harmful or string.find(text, "@harmful@", 1, true)) and
       string.find(text, pattern) then return true end
  end
  return false
end

function CS.HasLearnedSpell(name)
  local tabs = U.G("GetNumSpellTabs")
  local info = U.G("GetSpellTabInfo")
  local spellName = U.G("GetSpellName")
  if type(tabs) ~= "function" or type(info) ~= "function" or
     type(spellName) ~= "function" then return false end
  local okTabs, count = pcall(tabs)
  count = okTabs and tonumber(count) or 0
  local tab
  for tab = 1, count do
    local ok, _, _, offset, spells = pcall(info, tab)
    if ok then
      local index
      for index = CS.Number(offset) + 1, CS.Number(offset) + CS.Number(spells) do
        local okName, current = pcall(spellName, index, U.G("BOOKTYPE_SPELL") or "spell")
        if okName and current == name then return true end
      end
    end
  end
  return false
end

function CS.ScanAuras()
  if CS.auras and not CS.aurasDirty then return CS.auras end
  local totals, names = {}, {}
  local okClass, _, class = CS.Call("UnitClass", "player")
  class = okClass and class or ""
  local getBuff = U.G("GetPlayerBuff")
  if type(getBuff) == "function" then
    local harmful, limit
    for harmful = 0, 1 do
      limit = harmful == 1 and 6 or 31
      local slot
      for slot = 0, limit do
        local okIndex, index = pcall(getBuff, slot, harmful == 1 and "HARMFUL" or "HELPFUL")
        if okIndex and tonumber(index) and tonumber(index) > -1 then
          if harmful == 0 then
            local unitBuff = U.G("UnitBuff")
            if type(unitBuff) == "function" then
              local okIcon, icon, stacks = pcall(unitBuff, "player", slot)
              if okIcon and icon == "Interface\\Icons\\Spell_Holy_CrusaderStrike" then
                totals.zealStacks = CS.Number(stacks)
              elseif okIcon and icon == "Interface\\Icons\\Ability_Shaman_WaterShield" then
                totals.waterShieldStacks = CS.Number(stacks)
              end
            end
          end
          local left, _, count = CS.ScanLines(function(tip)
            tip:SetPlayerBuff(index)
          end)
          if left then
            local line
            for line = 1, count do
              if left[line] then
                local value = harmful == 1 and (left[line] .. "@harmful@") or left[line]
                CS.AddAuraLine(totals, names, value, harmful == 1, totals, class)
              end
            end
          end
        end
      end
    end
  end

  local talents = CS.ReadTalents()
  if totals.innerFire then
    local bonus = totals.innerFire
    if (talents.improvedInnerFire or 0) > 0 then
      bonus = math.floor(bonus + bonus * talents.improvedInnerFire / 100)
    end
    CS.AddValue(totals, "damageOnly", bonus)
  end
  if totals.zealHaste then
    local haste = totals.zealHaste
    if (talents.vengefulStrikes or 0) > 0 and (totals.zealStacks or 0) > 0 then
      haste = haste + talents.vengefulStrikes * totals.zealStacks
    end
    CS.AddValue(totals, "haste", haste)
  end
  if (talents.waterShieldRank or 0) > 0 and (totals.waterShieldStacks or 0) > 0 then
    CS.AddValue(totals, "casting", talents.waterShieldRank * totals.waterShieldStacks)
  end
  if class == "PRIEST" and names.Shadowform and
     CS.HasLearnedSpell("Improved Shadowform") then
    CS.AddValue(totals, "casting", 15)
  end
  if totals.shamanElementalMastery then
    totals.shamanLightningBolt = 100
    totals.shamanChainLightning = 100
    totals.shamanFireFrost = 100
  end
  CS.auras, CS.auraNames, CS.aurasDirty = totals, names, false
  return totals
end

-- ---------------------------------------------------------------------------
-- Spellbook crit
-- ---------------------------------------------------------------------------
function CS.SpellName(index)
  local ok, name = CS.Call("GetSpellName", index, U.G("BOOKTYPE_SPELL") or "spell")
  if ok then return name end
  return nil
end

-- The spellbook slot of the first spell named in `names`, remembered in
-- `cacheKey` and re-found whenever that slot's name no longer matches.
function CS.FindSpell(names, cacheKey)
  local cached = CS[cacheKey]
  if cached and names[CS.SpellName(cached) or ""] then return cached end
  CS[cacheKey] = nil
  local i
  for i = 1, CS.MAX_SPELLS do
    local name = CS.SpellName(i)
    if not name then return nil end
    if names[name] then
      CS[cacheKey] = i
      return i
    end
  end
  return nil
end

-- The first "<number>%" at the start of a tooltip line below the name.
function CS.SpellCrit(names, cacheKey)
  local slot = CS.FindSpell(names, cacheKey)
  if not slot then return nil end
  local bookType = U.G("BOOKTYPE_SPELL") or "spell"
  local left, _, count = CS.ScanLines(function(tip)
    tip:SetSpell(slot, bookType)
  end)
  if not left then return nil end
  local i
  for i = 2, count do
    local text = left[i]
    if text then
      local _, _, whole, frac = string.find(text, "^%s*(%d+)[%.,]?(%d*)%%")
      if whole then
        if frac ~= "" then return tonumber(whole .. "." .. frac) end
        return tonumber(whole)
      end
    end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Row construction
--
-- A row is { label, value, color?, estimate?, tip? }. `estimate` is the list
-- of breakdown lines the "?" hover shows; `tip` is the row's own hover.
-- ---------------------------------------------------------------------------
CS.GREEN = { 0.13, 1.00, 0.13, 1 }

function CS.Percent(value)
  return string.format("%.2f%%", value or 0)
end

function CS.Signed(value)
  if value >= 0 then return "+" .. value end
  return tostring(value)
end

-- Green when equipped gear raises the value, white (nil) otherwise (user
-- request, 2026-09-28). The client's own positive/negative figures are not
-- used: they mix gear with buffs and debuffs, so the colour changed with
-- whatever was active. Each argument is a GEAR_BONUS key, or a number
-- already summed from gear (hit, spell damage, mp5 ...).
function CS.GearColor(gear, a, b)
  local function amount(key)
    if type(key) == "number" then return key end
    if key and gear and gear.bonus then return gear.bonus[key] or 0 end
    return 0
  end
  if amount(a) > 0 or amount(b) > 0 then return CS.GREEN end
  return nil
end

function CS.Row(rows, label, value, color, estimate, tip)
  table.insert(rows, { key = label, label = U.L(label), value = value, color = color,
                       estimate = estimate, tip = tip })
end

-- ---------------------------------------------------------------------------
-- Native paper-doll hovers
--
-- The stock sheet explains attributes, armor, attack power, weapon skill,
-- defense and resistances on hover; the panel keeps that detail (user
-- request, 2026-09-28). Each tip is rebuilt the way 1.12 PaperDollFrame.lua
-- builds its tooltip / tooltipSubtext (WORKING_SOURCE: stock 1.12 FrameXML,
-- not read on this client), from the client's own localized strings: every
-- global below is present in this client's 2026-08-16 global dump
-- (ARMOR_TOOLTIP, RESISTANCE_TOOLTIP_SUBTEXT, MELEE/RANGED_ATTACK_POWER_
-- TOOLTIP, ATTACK_TOOLTIP(_SUBTEXT), <CLASS>_/DEFAULT_<STAT>_TOOLTIP, ...).
-- A missing global drops that line; the numbers are the 1.12 getters'
-- (character.stat_api_1_12_return_shapes).
-- ---------------------------------------------------------------------------
CS.STAT_TOOLTIP = { "STRENGTH", "AGILITY", "STAMINA", "INTELLECT", "SPIRIT" }

function CS.Global(name)
  local value = U.G(name)
  if type(value) == "string" and value ~= "" then return value end
  return nil
end

-- "Name 45 (40+5)", as PaperDollFormatStat prints it: white, the buff green
-- and the debuff red, the breakdown only when there is one.
function CS.Breakdown(name, shown, base, positive, negative)
  local text = "|cffffffff" .. name .. " " .. shown
  if positive > 0 or negative < 0 then
    text = text .. " (" .. base
    if positive > 0 then text = text .. "|cff20ff20+" .. positive .. "|cffffffff" end
    if negative < 0 then text = text .. "|cffff2020 " .. negative .. "|cffffffff" end
    text = text .. ")"
  end
  return text .. "|r"
end

-- A tip with the native heading and, if given, its explanation.
function CS.NativeTip(title, subtext)
  local tip = { title = title }
  if subtext then table.insert(tip, { subtext, note = true }) end
  return tip
end

function CS.Format(pattern, a, b, c)
  if not pattern then return nil end
  local ok, text = pcall(string.format, pattern, a, b, c)
  if ok then return text end
  return nil
end

function CS.ClassToken()
  local ok, _, class = CS.Call("UnitClass", "player")
  return ok and class and string.upper(class) or ""
end

function CS.PlayerLevel()
  local ok, level = CS.Call("UnitLevel", "player")
  return ok and CS.Number(level) or 1
end

-- Attack power: PaperDollFormatStat's heading, and the damage per second it
-- adds (effective / ATTACK_POWER_MAGIC_NUMBER, 14 in this client's dump).
function CS.PowerTip(nameKey, subtextKey, base, plus, minus)
  local effective = base + plus + minus
  local magic = tonumber(U.G("ATTACK_POWER_MAGIC_NUMBER")) or 14
  return CS.NativeTip(
    CS.Breakdown(CS.Global(nameKey) or U.L("CHARSTATS_AP"), effective, base, plus, minus),
    CS.Format(CS.Global(subtextKey), math.max(effective, 0) / magic))
end

-- Weapon skill and defense: the rating's name over base + modifier.
function CS.RatingTip(nameKey, subtextKey, base, mod)
  local name = CS.Global(nameKey)
  if not name then return nil end
  return CS.NativeTip(
    CS.Breakdown(name, base + mod, base, math.max(mod, 0), math.min(mod, 0)),
    subtextKey and CS.Global(subtextKey) or nil)
end

-- Armor: the damage reduction against an attacker of the player's level,
-- armor / (85 * level + 400) as a share of itself plus one.
function CS.ArmorTip(base, armor, plus, minus)
  local level = CS.PlayerLevel()
  local reduction = armor / (85 * level + 400)
  reduction = 100 * reduction / (reduction + 1)
  return CS.NativeTip(
    CS.Breakdown(CS.Global("ARMOR") or U.L("CHARSTATS_ARMOR"), armor, base, plus, minus),
    CS.Format(CS.Global("ARMOR_TOOLTIP"), level, reduction))
end

-- A resistance: its rating (Excellent .. None) from the total per level, the
-- level taken as at least 20.
function CS.ResistanceTip(entry, base, total, plus, minus)
  local level = math.max(CS.PlayerLevel(), 20)
  local ratio = total / level
  local rating = "RESISTANCE_NONE"
  if ratio > 5 then rating = "RESISTANCE_EXCELLENT"
  elseif ratio > 3.75 then rating = "RESISTANCE_VERYGOOD"
  elseif ratio > 2.5 then rating = "RESISTANCE_GOOD"
  elseif ratio > 1.25 then rating = "RESISTANCE_FAIR"
  elseif ratio > 0 then rating = "RESISTANCE_POOR" end
  local name = CS.Global("RESISTANCE" .. entry[1] .. "_NAME") or U.L(entry[2])
  local school = CS.Global("RESISTANCE_TYPE" .. entry[1])
  local subtext
  if school and CS.Global(rating) then
    subtext = CS.Format(CS.Global("RESISTANCE_TOOLTIP_SUBTEXT"), school, level,
                        CS.Global(rating))
  end
  return CS.NativeTip(CS.Breakdown(name, total, base, plus, minus), subtext)
end

function CS.General(rows, unit, gear)
  local ok, health = CS.Call("UnitHealthMax", unit)
  CS.Row(rows, "CHARSTATS_HEALTH", tostring(ok and CS.Number(health) or 0),
         CS.GearColor(gear, "health"))
  local okType, powerType = CS.Call("UnitPowerType", unit)
  local okPower, power = CS.Call("UnitManaMax", unit)
  local label = CS.POWER_LABEL[okType and tonumber(powerType) or 0] or "CHARSTATS_MANA"
  CS.Row(rows, label, tostring(okPower and CS.Number(power) or 0),
         label == "CHARSTATS_MANA" and CS.GearColor(gear, "mana") or nil)
end

function CS.Attributes(rows, gear)
  local class = CS.ClassToken()
  local i
  for i = 1, 5 do
    local ok, stat, effective, positive, negative = CS.Call("UnitStat", "player", i)
    if ok then
      stat, effective = CS.Number(stat), CS.Number(effective)
      positive, negative = CS.Number(positive), CS.Number(negative)
      -- PaperDollFrame_SetStat: the base shown is stat - posBuff - negBuff.
      local name = CS.Global("SPELL_STAT" .. (i - 1) .. "_NAME") or U.L(CS.ATTRIBUTES[i])
      local key = CS.STAT_TOOLTIP[i]
      local subtext = CS.Global(class .. "_" .. key .. "_TOOLTIP") or
                      CS.Global("DEFAULT_" .. key .. "_TOOLTIP")
      CS.Row(rows, CS.ATTRIBUTES[i], tostring(effective),
             CS.GearColor(gear, CS.ATTRIBUTE_BONUS[i]), nil,
             CS.NativeTip(CS.Breakdown(name, effective, stat - positive - negative,
                                       positive, negative), subtext))
    end
  end
end

function CS.DamageText(low, high)
  return string.format("%d - %d", math.max(math.floor(low), 1),
                       math.max(math.ceil(high), 1))
end

function CS.Haste(base, current)
  if not base or not current or current <= 0 then return nil end
  local haste = (base / current - 1) * 100
  if math.abs(haste) < 0.05 then haste = 0 end
  return haste
end

function CS.OffhandHasWeapon()
  local loc = CS.EquipLoc(CS.SLOT_OFFHAND)
  return loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONOFFHAND"
end

function CS.HitTotal(gear, ranged)
  local talents = CS.ReadTalents()
  local auras = CS.ScanAuras()
  local hit = (gear.hit or 0) + (talents.hit or 0) + (auras.hit or 0)
  if CS.OffhandHasWeapon() then hit = hit + (talents.surefooted or 0) end
  if ranged then hit = hit + (gear.rangedHit or 0) end
  hit = hit - (auras.hitDebuff or 0)
  return math.max(hit, 0)
end

function CS.SpellPowerParts(gear)
  local talents = CS.ReadTalents()
  local auras = CS.ScanAuras()
  local common = (gear.spellDamage or 0) + (auras.spellDamage or 0)
  if (talents.spiritualGuidance or 0) > 0 then
    local ok, _, spirit = CS.Call("UnitStat", "player", 5)
    if ok then
      common = common + math.floor(talents.spiritualGuidance * CS.Number(spirit) / 100)
    end
  end
  local damageOnly = (gear.damageOnly or 0) + (auras.damageOnly or 0)
  local schools, highest = {}, 0
  local school
  for school in pairs(CS.SCHOOLS) do
    schools[school] = (gear.school[school] or 0) + (auras[school] or 0)
    if schools[school] > highest then highest = schools[school] end
  end
  return common, damageOnly, schools, highest
end

function CS.HealingTotal(gear)
  local common = CS.SpellPowerParts(gear)
  local talents = CS.ReadTalents()
  local auras = CS.ScanAuras()
  local healing = common + (gear.healing or 0) + (auras.healing or 0)
  if (talents.ironclad or 0) > 0 then
    local okArmor, baseArmor = CS.Call("UnitArmor", "player")
    local okAgi, _, agility = CS.Call("UnitStat", "player", 2)
    if okArmor and okAgi then
      local fromGear = CS.Number(baseArmor) - CS.Number(agility) * 2
      if (talents.toughness or 0) > 0 then
        fromGear = fromGear / (1 + talents.toughness / 100)
      end
      healing = healing + math.floor(talents.ironclad * fromGear / 100)
    end
  end
  if CS.auraNames and CS.auraNames["Tree of Life Form"] and
     CS.auraNames["Tree of Life Aura"] then
    local ok, _, spirit = CS.Call("UnitStat", "player", 5)
    if ok then healing = healing + CS.Number(spirit) * 0.2 end
  end
  return healing
end

function CS.RangedCrit(class, gear)
  local curve = CS.RANGED_CRIT[class]
  if not curve then return 0 end
  local level = math.max(1, math.min(CS.PlayerLevel(), 60))
  local okAgi, _, agility = CS.Call("UnitStat", "player", 2)
  agility = okAgi and CS.Number(agility) or 0
  local rate = curve.first * (60 - level) / 59 +
               curve.last * (level - 1) / 59
  local crit = curve.base + (rate > 0 and agility / rate or 0) +
               (gear.crit or 0) + (gear.rangedCrit or 0) +
               (CS.ReadTalents().rangedCrit or 0) +
               (CS.ScanAuras().rangedCrit or 0)
  local okSkill, skill, mod = CS.Call("UnitRangedAttack", "player")
  if okSkill then
    local difference = CS.Number(skill) + CS.Number(mod) - level * 5
    if difference >= 0 then crit = crit + difference * 0.04
    else crit = crit + difference * 0.2 end
  end
  return math.max(crit, 0)
end

function CS.BlockValue(gear)
  local ok, _, strength = CS.Call("UnitStat", "player", 1)
  strength = ok and CS.Number(strength) or 0
  local talents = CS.ReadTalents()
  local auras = CS.ScanAuras()
  local modifier = talents.blockMod or 0
  if (talents.enhancingTotems or 0) > 0 and CS.HasAura("^Stoneskin$") then
    modifier = modifier + talents.enhancingTotems
  end
  local value = (gear.blockValue or 0) + (auras.blockValue or 0) + strength / 20 - 1
  value = math.floor(value + value * modifier / 100)
  return math.max(0, value)
end

function CS.Avoidance()
  local okDef, base, mod = CS.Call("UnitDefense", "player")
  local defense = okDef and (CS.Number(base) + CS.Number(mod)) or 0
  local miss = 5 + (defense - CS.PlayerLevel() * 5) * 0.04
  local okDodge, dodge = CS.Call("GetDodgeChance")
  local okParry, parry = CS.Call("GetParryChance")
  local okBlock, block = CS.Call("GetBlockChance")
  local total = miss + (okDodge and CS.Number(dodge) or 0) +
                (okParry and CS.Number(parry) or 0) +
                (okBlock and CS.Number(block) or 0)
  return math.max(total, 0)
end

function CS.SpellHaste(gear, class)
  local talents = CS.ReadTalents()
  local auras = CS.ScanAuras()
  local haste = (gear.haste or 0) + (auras.haste or 0) +
                (talents.haste or 0)
  haste = haste + (gear.spellHaste or 0) + (auras.spellHaste or 0) +
          (talents.spellHaste or 0)
  local ok, _, race = CS.Call("UnitRace", "player")
  if ok and race == "NightElf" then haste = haste + 1 end
  return haste
end

function CS.Melee(rows, gear, class)
  local ok, low, high, offLow, offHigh = CS.Call("UnitDamage", "player")
  local okSpeed, speed, offSpeed = CS.Call("UnitAttackSpeed", "player")
  speed = okSpeed and CS.Number(speed) or 0
  local offLoc = CS.EquipLoc(CS.SLOT_OFFHAND)
  -- UnitAttackSpeed reports an off-hand speed with nothing in that hand
  -- (character.stat_api_1_12_return_shapes), so the item decides.
  local dual = offLoc == "INVTYPE_WEAPON" or offLoc == "INVTYPE_WEAPONOFFHAND"
  -- No hover on damage or DPS (user request, 2026-09-28): everything the
  -- native damage tooltip gave -- each hand's damage, speed and DPS -- is a
  -- row here, the off hand's damage on its own "Off Hand" row and its speed
  -- and DPS after the main hand's on theirs.
  if ok then
    low, high = CS.Number(low), CS.Number(high)
    offLow, offHigh, offSpeed = CS.Number(offLow), CS.Number(offHigh), CS.Number(offSpeed)
    local offHand = dual and offHigh > 0 and offSpeed > 0
    CS.Row(rows, "CHARSTATS_DAMAGE", CS.DamageText(low, high),
           CS.GearColor(gear, "meleeDamage"))
    if offHand then
      CS.Row(rows, "CHARSTATS_OFFHAND", CS.DamageText(offLow, offHigh),
             CS.GearColor(gear, "meleeDamage"))
    end
    if speed > 0 then
      local dps = string.format("%.1f", (low + high) / 2 / speed)
      if offHand then
        dps = dps .. " / " .. string.format("%.1f", (offLow + offHigh) / 2 / offSpeed)
      end
      CS.Row(rows, "CHARSTATS_DPS", dps, CS.GearColor(gear, "meleeDamage"))
    end
  end
  if speed > 0 then
    local text = string.format("%.2f", speed)
    if dual and CS.Number(offSpeed) > 0 then
      text = text .. " / " .. string.format("%.2f", CS.Number(offSpeed))
    end
    CS.Row(rows, "CHARSTATS_SPEED", text)
  end
  local okPower, base, plus, minus = CS.Call("UnitAttackPower", "player")
  if okPower then
    base, plus, minus = CS.Number(base), CS.Number(plus), CS.Number(minus)
    CS.Row(rows, "CHARSTATS_AP", tostring(base + plus + minus),
           CS.GearColor(gear, "ap"), nil,
           CS.PowerTip("ATTACK_POWER_TOOLTIP", "MELEE_ATTACK_POWER_TOOLTIP",
                       base, plus, minus))
  end
  local crit = CS.SpellCrit(CS.MELEE_SPELLS, "meleeSpell")
  if crit then
    CS.Row(rows, "CHARSTATS_CRIT", CS.Percent(crit), CS.GearColor(gear, "crit"))
  end

  CS.Row(rows, "CHARSTATS_HIT", CS.Percent(CS.HitTotal(gear, false)),
         CS.GearColor(gear, gear.hit))

  local haste = CS.Haste(gear.speed[16], speed)
  if haste and haste ~= 0 then CS.Row(rows, "CHARSTATS_HASTE", CS.Percent(haste)) end

  local okSkill, skill, mod, offSkill, offMod =
    CS.Call("UnitAttackBothHands", "player")
  if okSkill then
    skill, mod = CS.Number(skill), CS.Number(mod)
    local value = tostring(skill + mod)
    if dual and offSkill then
      value = value .. " / " .. tostring(CS.Number(offSkill) + CS.Number(offMod))
    end
    CS.Row(rows, "CHARSTATS_SKILL", value, CS.GearColor(gear, "skill"),
           nil, CS.RatingTip("ATTACK_TOOLTIP", "ATTACK_TOOLTIP_SUBTEXT", skill, mod))
  end
end

function CS.Ranged(rows, gear, class)
  local unavailable = false
  local relic = U.G("UnitHasRelicSlot")
  if type(relic) == "function" then
    local ok, hasRelic = pcall(relic, "player")
    unavailable = ok and hasRelic and true or false
  end
  if not CS.ItemId(CS.SLOT_RANGED) then unavailable = true end
  if unavailable then
    local value = CS.Global("NOT_APPLICABLE") or "--"
    CS.Row(rows, "CHARSTATS_SKILL", value)
    CS.Row(rows, "CHARSTATS_DAMAGE", value)
    CS.Row(rows, "CHARSTATS_SPEED", value)
    CS.Row(rows, "CHARSTATS_AP", value)
    CS.Row(rows, "CHARSTATS_HIT", value)
    CS.Row(rows, "CHARSTATS_CRIT", value)
    return false
  end
  local ok, speed, low, high = CS.Call("UnitRangedDamage", "player")
  speed = ok and CS.Number(speed) or 0
  if speed <= 0 then
    local value = CS.Global("NOT_APPLICABLE") or "--"
    CS.Row(rows, "CHARSTATS_SKILL", value)
    CS.Row(rows, "CHARSTATS_DAMAGE", value)
    CS.Row(rows, "CHARSTATS_SPEED", value)
    CS.Row(rows, "CHARSTATS_AP", value)
    CS.Row(rows, "CHARSTATS_HIT", value)
    CS.Row(rows, "CHARSTATS_CRIT", value)
    return false
  end
  low, high = CS.Number(low), CS.Number(high)
  -- No hover on damage or DPS: the damage tooltip's three figures are the
  -- three rows (user request, 2026-09-28), DPS under the speed.
  CS.Row(rows, "CHARSTATS_DAMAGE", CS.DamageText(low, high),
         CS.GearColor(gear, "rangedDamage"))
  CS.Row(rows, "CHARSTATS_SPEED", string.format("%.2f", speed))
  CS.Row(rows, "CHARSTATS_DPS", string.format("%.1f", (low + high) / 2 / speed),
         CS.GearColor(gear, "rangedDamage"))
  local okPower, base, plus, minus = CS.Call("UnitRangedAttackPower", "player")
  if okPower then
    base, plus, minus = CS.Number(base), CS.Number(plus), CS.Number(minus)
    CS.Row(rows, "CHARSTATS_AP", tostring(base + plus + minus),
           CS.GearColor(gear, "ap", "rangedAp"), nil,
           CS.PowerTip("RANGED_ATTACK_POWER", "RANGED_ATTACK_POWER_TOOLTIP",
                       base, plus, minus))
  end
  local crit = CS.RangedCrit(class, gear)
  CS.Row(rows, "CHARSTATS_CRIT", CS.Percent(crit), CS.GearColor(gear, "crit"),
         nil)

  local rangedHit = (gear.hit or 0) + (gear.rangedHit or 0)
  CS.Row(rows, "CHARSTATS_HIT", CS.Percent(CS.HitTotal(gear, true)),
         CS.GearColor(gear, rangedHit))

  local haste = CS.Haste(gear.speed[CS.SLOT_RANGED], speed)
  if haste and haste ~= 0 then CS.Row(rows, "CHARSTATS_HASTE", CS.Percent(haste)) end

  local okSkill, skill, mod = CS.Call("UnitRangedAttack", "player")
  if okSkill then
    skill, mod = CS.Number(skill), CS.Number(mod)
    CS.Row(rows, "CHARSTATS_SKILL", tostring(skill + mod), CS.GearColor(gear, "skill"),
           nil, CS.RatingTip("RANGED_ATTACK_TOOLTIP", "ATTACK_TOOLTIP_SUBTEXT", skill, mod))
  end
  return true
end

function CS.Spell(rows, gear, class, level)
  local okType, powerType = CS.Call("UnitPowerType", "player")
  local manaUser = okType and (tonumber(powerType) == 0 or class == "DRUID")

  local talents = CS.ReadTalents()
  local auras = CS.ScanAuras()
  local common, damageOnly, schools, highest = CS.SpellPowerParts(gear)
  CS.Row(rows, "CHARSTATS_SPELL_DAMAGE",
         tostring(math.floor(common + damageOnly + highest)),
         CS.GearColor(gear, gear.spellDamage, highest))
  CS.Row(rows, "CHARSTATS_HEALING", tostring(math.floor(CS.HealingTotal(gear))),
         CS.GearColor(gear, gear.spellDamage, gear.healing))

  local spellHit = (gear.spellHit or 0) + (talents.spellHit or 0) +
                   (auras.spellHit or 0)
  CS.Row(rows, "CHARSTATS_SPELL_HIT", tostring(spellHit) .. "%",
         CS.GearColor(gear, gear.spellHit))

  local crit = CS.SPELL_CRIT[class]
  do
    local fromInt = 0
    if crit then
      local okInt, _, intellect = CS.Call("UnitStat", "player", 4)
      intellect = okInt and CS.Number(intellect) or 0
      fromInt = crit.base + intellect /
                (crit.coefficient + crit.level * math.max(1, level))
    end
    local totalCrit = fromInt + (gear.spellCrit or 0) +
                      (talents.spellCrit or 0) + (auras.spellCrit or 0) -
                      (auras.spellCritDebuff or 0)
    if class == "WARLOCK" and (talents.warlockDestruction or 0) > 0 then
      totalCrit = totalCrit + talents.warlockDestruction
    elseif class == "PRIEST" and (talents.priestOffensive or 0) > 0 and
           (talents.priestDiscipline or 0) > 0 then
      totalCrit = totalCrit + math.min(talents.priestOffensive,
                                       talents.priestDiscipline)
    end
    CS.Row(rows, "CHARSTATS_SPELL_CRIT",
           CS.Percent(totalCrit), CS.GearColor(gear, gear.spellCrit))
  end

  if gear.spellPen > 0 then
    CS.Row(rows, "CHARSTATS_SPELL_PEN", tostring(gear.spellPen), CS.GearColor(gear, gear.spellPen),
           nil)
  end

  local spellHaste = CS.SpellHaste(gear, class)
  CS.Row(rows, "CHARSTATS_SPELL_HASTE", string.format("%d%%", spellHaste),
         CS.GearColor(gear, gear.haste, gear.spellHaste))

  local regen = CS.SPIRIT_REGEN[class]
  if not manaUser then
    CS.Row(rows, "CHARSTATS_REGEN", CS.Global("NOT_APPLICABLE") or "--")
  elseif regen then
    local okSpi, _, spirit = CS.Call("UnitStat", "player", 5)
    spirit = okSpi and CS.Number(spirit) or 0
    local fromSpirit = regen.base + spirit / regen.div
    if (auras.manaRegenPercent or 0) > 0 then
      fromSpirit = fromSpirit + fromSpirit * auras.manaRegenPercent / 100
    end
    local mp5 = (gear.mp5 or 0) + (auras.mp5 or 0) +
                (auras.mp5Tick or 0) * 2.5 + (auras.mp1 or 0) * 5
    local mp2 = mp5 * 0.4
    local total = fromSpirit + mp2
    local kept = (talents.casting or 0) + (auras.casting or 0) +
                 (gear.casting or 0)
    local okRace, _, race = CS.Call("UnitRace", "player")
    if okRace and race == "Human" then kept = kept + 5 end
    kept = math.min(kept, 100)
    local whileCasting = fromSpirit * kept / 100 + mp2
    CS.Row(rows, "CHARSTATS_REGEN", tostring(math.floor(total)),
           CS.GearColor(gear, gear.mp5))
    if whileCasting ~= total then
      CS.Row(rows, "CHARSTATS_REGEN_CASTING",
             tostring(math.floor(whileCasting)), CS.GearColor(gear, gear.mp5))
    end
  end
  return true
end

function CS.SpellSchools(rows, gear)
  local common, damageOnly, schools = CS.SpellPowerParts(gear)
  local i
  for i = 1, table.getn(CS.SPELL_SCHOOLS) do
    local entry = CS.SPELL_SCHOOLS[i]
    local school = schools[entry[1]] or 0
    local total = common + damageOnly + school
    CS.Row(rows, entry[2], tostring(total),
           CS.GearColor(gear, gear.spellDamage, gear.school[entry[1]] or 0))
  end
end

function CS.Defense(rows, gear)
  local ok, baseArmor, armor, _, plus, minus = CS.Call("UnitArmor", "player")
  if ok then
    armor = CS.Number(armor)
    CS.Row(rows, "CHARSTATS_ARMOR", tostring(armor),
           CS.GearColor(gear, "armor"), nil,
           CS.ArmorTip(CS.Number(baseArmor), armor, CS.Number(plus), CS.Number(minus)))
  end
  local okDef, base, mod = CS.Call("UnitDefense", "player")
  if okDef then
    base, mod = CS.Number(base), CS.Number(mod)
    CS.Row(rows, "CHARSTATS_DEFENSE", tostring(base + mod),
           CS.GearColor(gear, "defense"), nil,
           CS.RatingTip("DEFENSE_TOOLTIP", nil, base, mod))
  end
  local okDodge, dodge = CS.Call("GetDodgeChance")
  if okDodge then
    CS.Row(rows, "CHARSTATS_DODGE", CS.Percent(CS.Number(dodge)), CS.GearColor(gear, "dodge"))
  end
  local okParry, parry = CS.Call("GetParryChance")
  if okParry then
    CS.Row(rows, "CHARSTATS_PARRY", CS.Percent(CS.Number(parry)), CS.GearColor(gear, "parry"))
  end
  local okBlock, block = CS.Call("GetBlockChance")
  if okBlock then
    local tip = CS.NativeTip(U.L("CHARSTATS_BLOCK"), nil)
    table.insert(tip, { U.L("CHARSTATS_BLOCK_VALUE"),
                        tostring(CS.BlockValue(gear)) })
    CS.Row(rows, "CHARSTATS_BLOCK", CS.Percent(CS.Number(block)),
           CS.GearColor(gear, "block"), nil, tip)
  end
  CS.Row(rows, "CHARSTATS_AVOIDANCE", CS.Percent(CS.Avoidance()))
end

function CS.Resistances(rows, gear)
  local i
  for i = 1, table.getn(CS.RESISTANCES) do
    local entry = CS.RESISTANCES[i]
    local ok, base, total, plus, minus = CS.Call("UnitResistance", "player", entry[1])
    if ok then
      total = CS.Number(total)
      CS.Row(rows, entry[2], tostring(total), CS.GearColor(gear, entry[3]), nil,
             CS.ResistanceTip(entry, CS.Number(base), total, CS.Number(plus),
                              CS.Number(minus)))
    end
  end
end

function CS.EmptyGear()
  return { spellDamage = 0, damageOnly = 0, healing = 0,
           spellHit = 0, spellCrit = 0,
           hit = 0, rangedHit = 0, crit = 0, rangedCrit = 0,
           mp5 = 0, casting = 0, spellPen = 0, haste = 0,
           spellHaste = 0, blockValue = 0, armorPen = 0,
           priestHoly = 0, priestPrayer = 0,
           school = {}, speed = {},
           bonus = {} }
end

function CS.Context()
  local okClass, _, class = CS.Call("UnitClass", "player")
  class = okClass and class or ""
  local okLevel, level = CS.Call("UnitLevel", "player")
  level = okLevel and CS.Number(level) or 60
  pcall(CS.ReadTalents)
  local okGear, gear = pcall(CS.ScanGear)
  if not okGear or type(gear) ~= "table" then gear = CS.EmptyGear() end
  pcall(CS.ScanAuras)
  return gear, class, level
end

function CS.PageSource(key, gear, class, level)
  local rows = {}
  if key == "base" then
    CS.Attributes(rows, gear)
    CS.Defense(rows, gear)
  elseif key == "melee" then
    CS.Melee(rows, gear, class)
  elseif key == "ranged" then
    CS.Ranged(rows, gear, class)
  elseif key == "spell" then
    CS.Spell(rows, gear, class, level)
  elseif key == "schools" then
    CS.SpellSchools(rows, gear)
  elseif key == "defense" then
    CS.Defense(rows, gear)
  end
  return rows
end

function CS.PageRows(definition, gear, class, level)
  local ok, source = pcall(CS.PageSource, definition.key, gear, class, level)
  if not ok or type(source) ~= "table" then
    U.Debug("characterstats page " .. definition.key .. ": " .. tostring(source))
    source = {}
  end
  local byKey = {}
  local i
  for i = 1, table.getn(source) do
    local row = source[i]
    if row.key and not byKey[row.key] then byKey[row.key] = row end
  end
  local rows = {}
  for i = 1, table.getn(definition.rows) do
    local key = definition.rows[i]
    local row = byKey[key]
    if definition.key == "spell" and key == "CHARSTATS_REGEN" and row and
       byKey.CHARSTATS_REGEN_CASTING then
      row = { key = row.key, label = row.label,
              value = row.value .. " (" .. byKey.CHARSTATS_REGEN_CASTING.value .. ")",
              color = row.color, estimate = row.estimate, tip = row.tip }
    end
    table.insert(rows, row or {
      key = key, label = U.L(key), value = CS.Global("NOT_APPLICABLE") or "--",
    })
  end
  return rows
end

-- BetterCharacterStats-compatible page data for the native Classic panel.
function CS.GetPages()
  local gear, class, level = CS.Context()
  local pages = {}
  local i
  for i = 1, table.getn(CS.PAGES) do
    local definition = CS.PAGES[i]
    table.insert(pages, {
      key = definition.key,
      title = U.L(definition.title),
      rows = CS.PageRows(definition, gear, class, level),
    })
  end
  return pages
end

-- The whole readout: a list of { title, rows }. Categories with no rows are
-- left out. Every section is guarded on its own, so one failing read costs
-- that section, not the panel.
function CS.Collect()
  local gear, class, level = CS.Context()

  local sections = {
    { "CHARSTATS_CAT_GENERAL", function(rows) CS.General(rows, "player", gear) end },
    { "CHARSTATS_CAT_ATTRIBUTES", function(rows) CS.Attributes(rows, gear) end },
    { "CHARSTATS_CAT_MELEE", function(rows) CS.Melee(rows, gear, class) end },
    { "CHARSTATS_CAT_RANGED", function(rows) CS.Ranged(rows, gear, class) end },
    { "CHARSTATS_CAT_SPELL", function(rows) CS.Spell(rows, gear, class, level) end },
    { "CHARSTATS_CAT_SCHOOLS", function(rows) CS.SpellSchools(rows, gear) end },
    { "CHARSTATS_CAT_DEFENSE", function(rows) CS.Defense(rows, gear) end },
    { "CHARSTATS_CAT_RESIST", function(rows) CS.Resistances(rows, gear) end },
  }
  local out = {}
  local i
  for i = 1, table.getn(sections) do
    local rows = {}
    local ok, err = pcall(sections[i][2], rows)
    if not ok then U.Debug("characterstats " .. sections[i][1] .. ": " .. tostring(err)) end
    if table.getn(rows) > 0 then
      table.insert(out, { title = U.L(sections[i][1]), rows = rows })
    end
  end
  return out
end

-- Forgets the cached equipment and talent readings, so the next Collect
-- rescans them (the panel calls this whenever it opens).
function CS.Invalidate()
  CS.gearKey, CS.gear = nil, nil
  CS.talentKey, CS.talents = nil, nil
  CS.talentSpecial = nil
  CS.auras, CS.auraNames, CS.aurasDirty = nil, nil, true
end

-- Keep the same dirty-source model as BetterCharacterStats. The visible
-- panel's existing half-second refresh performs the actual scans.
U.RegisterEvent("UNIT_INVENTORY_CHANGED", function(event, unit)
  if not unit or unit == "player" then CS.gearKey, CS.gear = nil, nil end
end)
U.RegisterEvent("CHARACTER_POINTS_CHANGED", function()
  CS.talentKey, CS.talents, CS.talentSpecial = nil, nil, nil
  CS.aurasDirty = true
end)
U.RegisterEvent("PLAYER_LEVEL_UP", function()
  CS.talentKey, CS.talents, CS.talentSpecial = nil, nil, nil
  CS.aurasDirty = true
end)
U.RegisterEvent("UNIT_AURA", function(event, unit)
  if not unit or unit == "player" then CS.aurasDirty = true end
end)
U.RegisterEvent("PLAYER_AURAS_CHANGED", function() CS.aurasDirty = true end)
