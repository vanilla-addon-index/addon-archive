--[[----------------------------------------------------------------------
OctoPad Spells  -  known helpful / harmful spells for smart target

Smart target first looks a spell up here by its (English, lower-case) name; only unknown spells fall back to
guessing from tooltip words.  "help" = cast on a friend (soft target, friendly target, else yourself),
"harm" = cast on an enemy.  Spells that work both ways (Holy Shock, Dispel Magic ...) are left out on purpose.

Add a spell: one line, ["spell name"] = "help" or "harm".  Lua 5.0.
------------------------------------------------------------------------]]

local H, X = "help", "harm"

OctoPad.SPELL_KIND = {
  -- Priest
  ["lesser heal"] = H, ["heal"] = H, ["greater heal"] = H, ["flash heal"] = H, ["renew"] = H,
  ["prayer of healing"] = H, ["power word: shield"] = H, ["power word: fortitude"] = H,
  ["prayer of fortitude"] = H, ["divine spirit"] = H, ["prayer of spirit"] = H, ["shadow protection"] = H,
  ["prayer of shadow protection"] = H, ["cure disease"] = H, ["abolish disease"] = H, ["resurrection"] = H,
  ["fear ward"] = H, ["levitate"] = H, ["power infusion"] = H,
  ["smite"] = X, ["holy fire"] = X, ["mind blast"] = X, ["mind flay"] = X, ["shadow word: pain"] = X,
  ["devouring plague"] = X, ["mind control"] = X, ["mind soothe"] = X, ["mana burn"] = X, ["shackle undead"] = X,
  ["vampiric embrace"] = X, ["silence"] = X, ["hex of weakness"] = X, ["touch of weakness"] = X,
  -- Druid
  ["healing touch"] = H, ["rejuvenation"] = H, ["regrowth"] = H, ["mark of the wild"] = H, ["gift of the wild"] = H,
  ["thorns"] = H, ["remove curse"] = H, ["abolish poison"] = H, ["cure poison"] = H, ["rebirth"] = H,
  ["innervate"] = H,
  ["wrath"] = X, ["moonfire"] = X, ["starfire"] = X, ["entangling roots"] = X, ["faerie fire"] = X,
  ["faerie fire (feral)"] = X, ["insect swarm"] = X, ["hibernate"] = X, ["soothe animal"] = X, ["claw"] = X,
  ["rake"] = X, ["rip"] = X, ["shred"] = X, ["ravage"] = X, ["pounce"] = X, ["ferocious bite"] = X, ["maul"] = X,
  ["swipe"] = X, ["bash"] = X, ["growl"] = X, ["demoralizing roar"] = X, ["feral charge"] = X, ["cower"] = X,
  -- Paladin
  ["holy light"] = H, ["flash of light"] = H, ["lay on hands"] = H, ["cleanse"] = H, ["purify"] = H,
  ["redemption"] = H, ["divine intervention"] = H, ["blessing of might"] = H, ["blessing of wisdom"] = H,
  ["blessing of kings"] = H, ["blessing of salvation"] = H, ["blessing of light"] = H,
  ["blessing of sanctuary"] = H, ["blessing of freedom"] = H, ["blessing of protection"] = H,
  ["blessing of sacrifice"] = H, ["greater blessing of might"] = H, ["greater blessing of wisdom"] = H,
  ["greater blessing of kings"] = H, ["greater blessing of salvation"] = H, ["greater blessing of light"] = H,
  ["greater blessing of sanctuary"] = H,
  ["judgement"] = X, ["exorcism"] = X, ["hammer of justice"] = X, ["hammer of wrath"] = X, ["turn undead"] = X,
  ["holy wrath"] = X,
  -- Shaman
  ["healing wave"] = H, ["lesser healing wave"] = H, ["chain heal"] = H, ["ancestral spirit"] = H,
  ["water breathing"] = H, ["water walking"] = H,
  ["lightning bolt"] = X, ["chain lightning"] = X, ["earth shock"] = X, ["flame shock"] = X, ["frost shock"] = X,
  ["purge"] = X, ["stormstrike"] = X,
  -- Mage
  ["arcane intellect"] = H, ["arcane brilliance"] = H, ["amplify magic"] = H, ["dampen magic"] = H,
  ["remove lesser curse"] = H, ["slow fall"] = H,
  ["fireball"] = X, ["frostbolt"] = X, ["arcane missiles"] = X, ["fire blast"] = X, ["scorch"] = X,
  ["pyroblast"] = X, ["polymorph"] = X, ["counterspell"] = X, ["detect magic"] = X,
  -- Warlock
  ["unending breath"] = H, ["detect lesser invisibility"] = H, ["detect invisibility"] = H,
  ["detect greater invisibility"] = H,
  ["shadow bolt"] = X, ["immolate"] = X, ["corruption"] = X, ["curse of agony"] = X, ["curse of weakness"] = X,
  ["curse of recklessness"] = X, ["curse of tongues"] = X, ["curse of the elements"] = X,
  ["curse of shadow"] = X, ["curse of exhaustion"] = X, ["curse of doom"] = X, ["drain life"] = X,
  ["drain mana"] = X, ["drain soul"] = X, ["fear"] = X, ["banish"] = X, ["searing pain"] = X,
  ["soul fire"] = X, ["death coil"] = X, ["siphon life"] = X, ["shadowburn"] = X, ["conflagrate"] = X,
  ["enslave demon"] = X,
  -- Hunter
  ["arcane shot"] = X, ["serpent sting"] = X, ["viper sting"] = X, ["scorpid sting"] = X, ["wyvern sting"] = X,
  ["concussive shot"] = X, ["aimed shot"] = X, ["multi-shot"] = X, ["hunter's mark"] = X, ["scatter shot"] = X,
  ["distracting shot"] = X, ["tranquilizing shot"] = X, ["raptor strike"] = X, ["mongoose bite"] = X,
  ["wing clip"] = X, ["counterattack"] = X, ["scare beast"] = X, ["beast lore"] = X, ["tame beast"] = X,
  -- Rogue
  ["sinister strike"] = X, ["backstab"] = X, ["eviscerate"] = X, ["gouge"] = X, ["kick"] = X,
  ["kidney shot"] = X, ["cheap shot"] = X, ["garrote"] = X, ["ambush"] = X, ["sap"] = X, ["blind"] = X,
  ["rupture"] = X, ["expose armor"] = X, ["hemorrhage"] = X, ["ghostly strike"] = X, ["riposte"] = X,
  ["pick pocket"] = X, ["distract"] = X,
  -- Warrior
  ["heroic strike"] = X, ["cleave"] = X, ["slam"] = X, ["mortal strike"] = X, ["bloodthirst"] = X,
  ["shield slam"] = X, ["revenge"] = X, ["overpower"] = X, ["execute"] = X, ["rend"] = X, ["hamstring"] = X,
  ["sunder armor"] = X, ["taunt"] = X, ["mocking blow"] = X, ["charge"] = X, ["intercept"] = X,
  ["pummel"] = X, ["shield bash"] = X, ["disarm"] = X, ["concussion blow"] = X, ["intimidating shout"] = X,
  ["demoralizing shout"] = X, ["thunder clap"] = X, ["piercing howl"] = X,
}
