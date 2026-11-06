"""What each dungeon boss does, and what it means for each role, for the boss
steps build_dungeon_guides.py writes inside a dungeon.

Written from what the fights do: InstanceJournal's abilities
(https://github.com/Arthur-Helias/InstanceJournal, public domain), and, for
the original game's bosses, CMaNGOS -- each boss's spells in classic-db
(names, schools, what they dispel as, whom they hit) and its fight script in
mangos-classic's ScriptDevAI, which says when a phase starts or adds come.
Tools/build/build_dungeon_bosses.py gathers them into
Tools/data/dungeon_bosses.json.

Keyed by InstanceJournal's id for the boss. Each is the note -- what it does
-- then what the tank, the healer and damage dealers should do; any can be
empty. A boss with nothing here gets a step all the same, saying there are
no notes on it yet: Turtle WoW's own dungeons are mostly in that state, as
neither source covers them.

Words to keep to: "near him" is melee range, "in front" a cone, "dispel"
says what kind (Magic, Curse, Poison, Disease) and which classes can.
"""

# Whose death ticks a boss's step, where it is not the boss's own name: the
# Seven's step when Doom'rel, the last, dies; the Ring of Law's when the
# champion does, whichever of the six it is. None: the step is ticked by hand
# -- three dwarves die in any order, a family or an arena is not one creature.
WATCH = {
    "9040": ["Doom'rel"],
    "9031": ["Gorosh the Dervish", "Grizzle", "Eviscerator", "Ok'thor the Breaker", "Anub'shiah",
             "Hedrum the Creeper"],
    "6906": None,
    "61263": None,     # Harlow Family
    "62498": None,     # Farraki Arena
}

# Who removes what, in 1.12.
MAGIC = "Magic: Priest, Paladin"
CURSE = "Curse: Mage, Druid"
POISON = "Poison: Druid, Shaman, Paladin"
DISEASE = "Disease: Priest, Shaman, Paladin"


def T(note, tank="", heal="", dps=""):
    return {"note": note, "tank": tank, "heal": heal, "dps": dps}


TACTICS = {
    # Ragefire Chasm -----------------------------------------------------------------
    "11517": T("Oggleflint cleaves everyone in front of him.",
               tank="Face him away from the group.",
               dps="Stay behind him."),
    "11520": T("Fire Nova burns everyone near him, and Uppercut knocks his target back.",
               tank="Keep your back to a wall so Uppercut doesn't throw you into another pack.",
               heal="Fire Nova hits everyone in melee: keep the melee topped up.",
               dps="Ranged stand back, out of Fire Nova."),
    "11518": T("Jergosh casts Immolate and puts Curse of Weakness on his targets.",
               heal="Remove Curse of Weakness (%s) and Immolate (%s)." % (CURSE, MAGIC),
               dps="Interrupt Immolate."),
    "11519": T("A rogue: Sinister Strike, and poison on his blows.",
               heal="Cure the poison (%s)." % POISON),

    # Wailing Caverns ----------------------------------------------------------------
    "3669": T("A Fanglord: Lightning Bolt, Druid's Slumber (a sleep), Healing Touch on himself, and poison on his "
              "blows. At 30% he turns into a serpent that hits harder and faster.",
              tank="Be ready for his serpent form at 30%.",
              heal="Dispel Druid's Slumber (%s) and cure the poison (%s)." % (MAGIC, POISON),
              dps="Interrupt Healing Touch first, then Lightning Bolt."),
    "3670": T("A Fanglord: Sleep, Lightning Bolt, Healing Touch, and Thunderclap, which hits and slows everyone near "
              "him.",
              heal="Dispel Sleep and Thunderclap's slow (%s)." % MAGIC,
              dps="Interrupt Healing Touch and Lightning Bolt."),
    "3674": T("Skum casts Chained Bolt, which jumps from player to player.",
              heal="Don't stand bunched up, or Chained Bolt hits more of you.",
              dps="Interrupt Chained Bolt."),
    "3673": T("A Fanglord: Sleep, Lightning Bolt and Healing Touch.",
              heal="Dispel Sleep (%s)." % MAGIC,
              dps="Interrupt Healing Touch and Lightning Bolt."),
    "3671": T("A Fanglord: Sleep, Lightning Bolt, Healing Touch, and a Thorns Aura that hurts whoever hits her in "
              "melee.",
              heal="Dispel Sleep (%s); the melee lose health to her thorns." % MAGIC,
              dps="Interrupt Healing Touch."),
    "5775": T("Grasping Vines hits and knocks down everyone near him.",
              heal="The vines hit the whole melee group: heal through them.",
              dps="Ranged stand back; interrupt Grasping Vines when you can."),
    "3654": T("He comes at the end of the Disciple of Naralex's ritual, which the disciple starts once the four "
              "Fanglords are dead. Terrify fears, Naralex's Nightmare sleeps a player, and Thundercrack hits and "
              "stuns everyone near him.",
              tank="Thundercrack stuns you and Terrify can send you running: Berserker Rage or Fear Ward help.",
              heal="Dispel Naralex's Nightmare and Terrify (%s)." % MAGIC,
              dps="Interrupt Naralex's Nightmare."),

    # The Deadmines ------------------------------------------------------------------
    "644": T("Rhahk'Zor Slam hits hard and stuns his target for 3 seconds.",
             tank="Build threat before the others go all out: you'll be stunned now and then.",
             heal="Expect sudden damage on the tank."),
    "3586": T("Pierce Armor lowers his target's armour by 10%.",
              tank="He hits harder as your armour drops."),
    "643": T("Sneed fights in his Shredder first, and jumps out when it breaks. He disarms his target.",
             tank="Disarm takes your weapon for 5 seconds: have threat to spare when it comes."),
    "1763": T("Molten Metal burns his target and slows their movement and attacks.",
              heal="Molten Metal burns the tank for 15 seconds.",
              dps="Interrupt Molten Metal."),
    "646": T("At two-thirds and at one-third health he stuns everyone with Smite Stomp and goes to his chest to "
             "change weapons: two axes, then a hammer whose Smite Slam stuns. He parries far more at first.",
             tank="Pick him up again when he comes back from his chest.",
             heal="Use his trips to the chest to top everyone up and drink.",
             dps="Attack from behind: he parries a lot early on."),
    "647": T("Captain Greenskin cleaves everyone in front of him, and his Poisoned Harpoon ticks for a minute.",
             tank="Face him away from the group.",
             heal="Cure the harpoon's poison (%s)." % POISON,
             dps="Interrupt Poisoned Harpoon; stay behind him."),
    "639": T("At half health he calls two Defias Blackguards, and Thrash gives him extra attacks.",
             tank="Pick up the Blackguards when they come.",
             heal="Thrash makes his damage spiky: keep the tank topped up.",
             dps="Kill the Blackguards, then VanCleef."),
    "645": T("Acid Splash poisons everyone near him; at half health he eats to heal himself.",
             heal="Cure the Acid Splash poison (%s)." % POISON,
             dps="Interrupt Cookie's Cooking."),

    # Shadowfang Keep ----------------------------------------------------------------
    "3914": T("Soul Drain roots a player and drains their health.",
              heal="Dispel Soul Drain (%s)." % MAGIC,
              dps="Interrupt Soul Drain."),
    "3886": T("Razorclaw drains his target with Butcher Drain.",
              heal="Keep the tank topped up through the drain."),
    "3887": T("Veil of Shadow, a curse, cuts the healing his target takes.",
              heal="Remove Veil of Shadow (%s) before you heal the tank." % CURSE,
              dps="Interrupt Veil of Shadow."),
    "4278": T("A paladin: he heals with Holy Light and stuns with Hammer of Justice.",
              heal="Dispel Hammer of Justice (%s) from the tank." % MAGIC,
              dps="Interrupt Holy Light."),
    "4279": T("At three-quarters health Howling Rage makes him, and those with him, hit harder.",
              tank="His damage climbs after Howling Rage: save a cooldown for it.",
              heal="Expect heavier hits on the tank later in the fight."),
    "3872": T("A warrior: Cleave and Hamstring.",
              tank="Face him away from the group."),
    "4274": T("Toxic Saliva poisons a player and drains their mana.",
              heal="Cure Toxic Saliva (%s)." % POISON,
              dps="Interrupt Toxic Saliva."),
    "3927": T("Nandos calls his worgs into the fight: Bleak Worgs, Slavering Worgs and a Lupine Horror.",
              tank="Gather the worgs on you.",
              dps="Interrupt his calls when you can, and kill the worgs before Nandos."),
    "4275": T("Arugal casts Void Bolt, and Thundershock hits and stuns everyone near him.",
              heal="Void Bolt hits hard: keep everyone topped up.",
              dps="Interrupt Void Bolt; ranged stand back from Thundershock."),

    # The Stockade -------------------------------------------------------------------
    "1696": T("He dual wields with Thrash, and enrages at 30% health.",
              tank="Save a cooldown for his enrage at 30%.",
              heal="Damage on the tank jumps when he enrages.",
              dps="Burn him down from 30%."),
    "1666": T("A warrior in Defensive Stance: Shield Slam stuns for 2 seconds, and Shield Wall cuts the damage he "
              "takes by 60% for 12 seconds.",
              dps="Hold your big cooldowns while Shield Wall is up."),
    "1717": T("Chain Lightning jumps between three players, and Bloodlust speeds up him and his allies.",
              heal="Don't stand bunched up, or Chain Lightning hits more of you.",
              dps="Interrupt Chain Lightning; Purge or Dispel Magic his Bloodlust (Shaman, Priest)."),
    "1716": T("Smoke Bomb stuns everyone near him for 4 seconds, and Battle Shout raises his attack power.",
              heal="Stand out of Smoke Bomb's reach so you can keep healing.",
              dps="Ranged stand back from the smoke."),
    "1663": T("Intimidating Shout fears everyone near him for 6 seconds.",
              tank="Clear the cells around him first: feared players run into more prisoners.",
              heal="Fear Ward or Tremor Totem help; stand at range.",
              dps="Ranged stand back out of the shout."),

    # Blackfathom Deeps --------------------------------------------------------------
    "4887": T("Trample hits everyone near him.",
              heal="Trample hits the melee group."),
    "4831": T("Frost Nova roots everyone near her, Slow slows a player, and Forked Lightning hits everyone in front "
              "of her.",
              tank="Face her away from the group.",
              heal="Dispel Frost Nova and Slow (%s)." % MAGIC,
              dps="Interrupt Forked Lightning; keep out of her front."),
    "6243": T("Gelihast throws a Net that roots a player."),
    "12902": T("A shaman: Lightning Bolt, and a Lightning Shield that hurts whoever hits him.",
               dps="Interrupt Lightning Bolt; Purge or Dispel Magic his Lightning Shield (Shaman, Priest)."),
    "4832": T("Sleep puts players near him to sleep, and Mind Blast hits hard.",
              heal="Dispel Sleep (%s), the tank first." % MAGIC,
              dps="Interrupt Sleep and Mind Blast."),
    "4829": T("Poison Cloud poisons everyone near her; at 30% Frenzied Rage makes her hit harder and faster.",
              tank="Save a cooldown for 30%.",
              heal="Cure Poison Cloud (%s); damage jumps at 30%%." % POISON,
              dps="Burn her down from 30%."),

    # Gnomeregan ---------------------------------------------------------------------
    "7361": T("He comes at the end of Emi Shortfuse's event by the entrance, with his basilisk Chomper.",
              tank="Pick up Chomper as well."),
    "6235": T("Megavolt hits everyone in front of him, Chain Bolt jumps between players, and Shock hits his target.",
              tank="Face him away from the group.",
              heal="It's all Nature damage: Nature resistance helps.",
              dps="Interrupt Chain Bolt; keep out of his front."),
    "6229": T("Crowd Pummel knocks back and interrupts everyone near it, Arcing Smash hits in front, and Trample hits "
              "those near.",
              tank="Face it away, with your back to a wall.",
              heal="Stand out of Crowd Pummel's reach, or your heals are interrupted.",
              dps="Casters stand back out of Crowd Pummel."),
    "6228": T("Fire Shield burns those near him, he casts Fireball, and he summons Burning "
              "Servants.",
              dps="Kill the Burning Servants; interrupt Fireball."),
    "7800": T("Knock Away throws his target back. The bomb faces round the room let out Walking Bombs that run at "
              "you and explode; the buttons by the faces shut them off.",
              tank="Keep your back to a wall.",
              dps="Kill the Walking Bombs before they reach the group, and press the buttons by the bomb faces."),

    # Razorfen Kraul -----------------------------------------------------------------
    "4428": T("Dominate Mind takes control of a player, and he casts Shadow Bolt.",
              heal="Dispel Dominate Mind (%s)." % MAGIC,
              dps="Interrupt Dominate Mind; slow or crowd-control a controlled player rather than killing them."),
    "4424": T("He heals with Chain Heal from 75%, summons a Boar Spirit, and uses Battle Shout.",
              tank="Pick up the Boar Spirit.",
              dps="Interrupt Chain Heal; kill the Boar Spirit."),
    "4420": T("Thunderclap hits and slows everyone near him, and Battle Shout raises his attack power.",
              heal="Dispel Thunderclap's slow (%s)." % MAGIC,
              dps="Ranged stand back."),
    "4842": T("He drops an Earthbind Totem, summons an Earth Rumbler, and casts Lightning Bolt.",
              dps="Kill the Earthbind Totem; interrupt Lightning Bolt."),
    "4422": T("Rampage hits and stuns everyone near him, he charges, and he frenzies at 60% and at 40%.",
              tank="He hits harder each time he frenzies.",
              heal="Rampage hits the melee too.",
              dps="Ranged stand back out of Rampage."),
    "4421": T("She casts Chain Bolt, heals her allies with Renew, and restores her mana with Mana Spike.",
              dps="Interrupt Chain Bolt; dispel or Purge her Renew (Priest, Shaman)."),

    # Scarlet Monastery: Graveyard ---------------------------------------------------
    "3983": T("Shadow Word: Pain, and Immolate burns on his blows.",
              heal="Dispel both (%s)." % MAGIC),
    "6489": T("Poison Cloud and Curse of Weakness hit everyone near him.",
              heal="Cure the poison (%s) and remove the curse (%s)." % (POISON, CURSE)),
    "6490": T("Terrify fears, Call of the Grave curses, and Soul Siphon drains a player.",
              heal="Remove Call of the Grave (%s) and dispel Terrify (%s)." % (CURSE, MAGIC),
              dps="Interrupt Soul Siphon."),
    "6488": T("A warrior: Cleave, Rend, and Execute on targets below 20% health.",
              tank="Face him away, and keep your health above 20%."),
    "4543": T("Fire Nova and Flame Spike hit everyone near him; Flame Shock and Shadow Bolt hit one player.",
              heal="Dispel Flame Shock (%s); the melee take fire damage." % MAGIC,
              dps="Interrupt Shadow Bolt and Flame Spike; ranged stand back from Fire Nova."),

    # Scarlet Monastery: Library -----------------------------------------------------
    "3974": T("He fights with his hounds; Bloodlust speeds them up, and Battle Shout raises his attack power.",
              tank="Gather the hounds on you.",
              dps="Kill the hounds; Purge or Dispel Magic his Bloodlust (Shaman, Priest)."),
    "6487": T("He silences, polymorphs, and casts Arcane Explosion around him. At half health he shields himself in "
              "an Arcane Bubble, then Detonation blasts everyone near him.",
              heal="Dispel Polymorph and Silence (%s)." % MAGIC,
              dps="When the bubble goes up, run away from him until Detonation has gone off."),

    # Scarlet Monastery: Armory ------------------------------------------------------
    "3975": T("Whirlwind hits everyone near him, Cleave hits in front, and he enrages at 30%. When he dies, Scarlet "
              "Trainees rush in.",
              tank="Face him away from the group; save a cooldown for 30%.",
              heal="Whirlwind hits all the melee.",
              dps="Melee step away while he whirlwinds; be ready to deal with the trainees after he dies."),

    # Scarlet Monastery: Cathedral ---------------------------------------------------
    "4542": T("Fear, Sleep, Curse of Blood, and Dispel Magic on your buffs; at low health he shields and heals "
              "himself.",
              heal="Remove Curse of Blood (%s); dispel Sleep and Fear (%s)." % (CURSE, MAGIC),
              dps="Interrupt his Heal."),
    "3976": T("A paladin: Crusader Strike, Hammer of Justice and Retribution Aura. When he dies, High Inquisitor "
              "Whitemane comes in.",
              heal="Dispel Hammer of Justice (%s) from the tank." % MAGIC,
              dps="Retribution Aura hurts whoever hits him."),
    "3977": T("At half health she puts everyone to sleep with Deep Sleep and raises Mograine; then they fight "
              "together. She heals, shields, and casts Holy Smite.",
              tank="Be ready to pick up Mograine when he rises.",
              heal="Deep Sleep can't be stopped: heal straight after it.",
              dps="Interrupt her Heal and Holy Smite."),

    # Razorfen Downs -----------------------------------------------------------------
    "7356": T("Putrid Stench, a disease, silences everyone near him, and Withered Touch drains mana.",
              heal="Cure the diseases (%s); stay out of the stench so you can cast." % DISEASE,
              dps="Casters stand back."),
    "7355": T("He comes after you ring the gong. Web Spray roots everyone in front of him, his bites poison, and "
              "Curse of Tuten'kash slows casting.",
              tank="Face him away from the group.",
              heal="Remove the curse (%s) and cure the poison (%s)." % (CURSE, POISON)),
    "7357": T("Fireball and Fire Nova.",
              dps="Interrupt Fireball; ranged stand back from Fire Nova."),
    "8567": T("A Disease Cloud hurts everyone near him, Thrash gives him extra attacks, and he frenzies at 15%.",
              heal="The cloud hurts the melee all fight.",
              dps="Burn the last 15% fast."),
    "7354": T("Dominate Mind, Shadow Bolt, Shadow Word: Pain, and he heals.",
              heal="Dispel Dominate Mind (%s)." % MAGIC,
              dps="Interrupt Dominate Mind and Heal."),
    "7358": T("Frostbolt, Frost Nova and Amnennar's Wrath; at 66% and at 33% he calls Frost Spectres.",
              tank="Pick up the Frost Spectres.",
              heal="Dispel Frost Nova and Frostbolt's slow (%s)." % MAGIC,
              dps="Kill the spectres; interrupt Frostbolt."),

    # Uldaman ------------------------------------------------------------------------
    "6906": T("Baelog, Eric and Olaf fight together.",
              tank="Gather all three on you.",
              dps="Kill them one at a time."),
    "6910": T("Lightning Bolt and Chain Lightning.",
              dps="Interrupt both."),
    "7228": T("War Stomp stuns everyone near her, Knock Away throws her target, and Arcing Smash hits in front.",
              tank="Face her away, with your back to a wall.",
              heal="Stand out of War Stomp's reach.",
              dps="Melee from behind; ranged back from the stomp."),
    "7023": T("At every fifth of its health it breaks off an Obsidian Shard.",
              tank="Pick up each shard.",
              dps="Kill the shards as they come."),
    "7206": T("Sand Storms send whirling storms round the room.",
              heal="Keep away from the storms.",
              dps="Keep away from the storms."),
    "7291": T("Fire Nova around him, Flame Shock, Flame Lash, and Amplify Flames, which raises the fire damage you "
              "take.",
              heal="Dispel Amplify Flames and Flame Shock (%s)." % MAGIC,
              dps="Interrupt Flame Lash; ranged stand back from Fire Nova."),
    "4854": T("A trogg shaman: Lightning Bolt, Chain Bolt, Shrink (a curse) and a Tremor Totem; Bloodlust when his "
              "basilisk dies.",
              heal="Remove Shrink (%s)." % CURSE,
              dps="Interrupt Lightning Bolt and Chain Bolt; kill the Tremor Totem so fears work."),
    "2748": T("While he stands above a third of his health he wakes earthen dwarves; at two-thirds he wakes the "
              "Earthen Guardians, at one-third the Vault Warders. Ground Tremor stuns everyone near him.",
              tank="Pick up what he wakes.",
              heal="Stand out of Ground Tremor.",
              dps="Kill what he wakes; the Vault Warders are tough."),

    # Zul'Farrak ---------------------------------------------------------------------
    "10082": T("Net roots a player, and Frost Shot slows.",
               heal="Dispel Frost Shot's slow (%s)." % MAGIC),
    "7272": T("Fevered Plague is a disease; at 30% he turns into a beetle that physical damage can't hurt.",
              heal="Cure Fevered Plague (%s)." % DISEASE,
              dps="From 30% only spells hurt him: casters finish him."),
    "8127": T("He drops Healing Wards and Earthgrab Totems, calls basilisks at 75% and 25%, and heals himself at "
              "20%.",
              tank="Pick up the basilisks.",
              dps="Kill each Healing Ward at once; interrupt his heal."),
    "7271": T("He raises zombies from the graves, drops a Ward of Zum'rah, heals his allies, and casts Shadow Bolt "
              "Volley.",
              tank="Gather the zombies.",
              heal="Shadow Bolt Volley hits everyone.",
              dps="Kill the ward; interrupt Healing Wave and Shadow Bolt Volley."),
    "7275": T("He heals and renews his allies, casts Shadow Bolt, and Psychic Scream fears everyone near him.",
              heal="Fear Ward or Tremor Totem help.",
              dps="Interrupt his Heal; dispel or Purge his Renew."),
    "7267": T("Wide Slash hits in front, he frenzies at 60%, calls Sandfury Slaves at 30%, and now and then drops "
              "his threat.",
              tank="Taunt him back when he drops threat; face him away.",
              dps="Kill the slaves."),
    "7273": T("Summoned with the Mallet of Zul'Farrak at his pool. Gahz'rilla Slam knocks back everyone near, Freeze "
              "Solid freezes a player, and Icicle hits.",
              tank="Keep your back to a wall.",
              heal="Dispel Freeze Solid (%s)." % MAGIC),

    # Maraudon -----------------------------------------------------------------------
    "13282": T("Toxic Volley poisons everyone, Uppercut knocks his target back, and he splits into Noxxion's Spawns.",
               tank="Keep your back to a wall.",
               heal="Cure the poison (%s)." % POISON,
               dps="Kill the spawns when he splits."),
    "12258": T("Cleave hits in front, Thrash gives him extra attacks, and Puncture makes his target bleed.",
               tank="Face him away from the group."),
    "12237": T("War Stomp stuns everyone near him.",
               heal="Stand out of the stomp."),
    "12236": T("He fights from range with Shoot and Multi-Shot, Blinks away, and Smoke Bomb stuns everyone near him; "
               "his breath carries a disease.",
               tank="When he Blinks off, go after him.",
               heal="Cure the disease (%s)." % DISEASE),
    "12225": T("Entangling Roots, Wrath, and Twisted Tranquility, which hits and slows everyone; he summons "
               "corrupted treants.",
               heal="Dispel Entangling Roots (%s)." % MAGIC,
               dps="Interrupt Twisted Tranquility and Wrath; kill the treants."),
    "13601": T("He throws bombs, Goblin Dragon Gun burns everyone in front of him, and Flash Bomb fears everyone near.",
               tank="Face him away from the group.",
               heal="Stand back from Flash Bomb.",
               dps="Interrupt Bomb."),
    "12203": T("Trample and Knock Away; Landslide stuns everyone near him and brings out Theradrim Shardlings.",
               tank="Back to a wall; pick up the shardlings.",
               dps="Kill the shardlings."),
    "13596": T("Fatal Bite drains health, and Puncture makes his target bleed.",
               heal="Expect heavy damage on the tank."),
    "12201": T("Boulder knocks a player down and interrupts them, Dust Field hits and knocks back everyone near her, "
               "and Repulsive Gaze fears those near her.",
               tank="Berserker Rage or Fear Ward for her gaze.",
               heal="Stay at range, out of Dust Field.",
               dps="Ranged stand back."),

    # The Temple of Atal'Hakkar ------------------------------------------------------
    "8580": T("Summoned by touching the statues in the right order. Ground Tremor stuns everyone near him, and "
              "Sweeping Slam knocks back everyone in front.",
              tank="Face him away, with your back to a wall.",
              heal="Stand out of Ground Tremor."),
    "5708": T("Acid of Hakkar burns a player over time.",
              heal="Heal through the acid."),
    "5713": T("One of the six trolls on the balcony: Strike, and nothing else to watch for."),
    "5717": T("One of the six trolls on the balcony: Thorns Aura, Renew and Healing Wave, and a Healing Ward.",
              dps="Kill the Healing Ward; interrupt Healing Wave."),
    "5712": T("One of the six trolls on the balcony: Chain Lightning, and an Atal'ai Skeleton Totem.",
              dps="Interrupt Chain Lightning; kill the totem."),
    "5716": T("One of the six trolls on the balcony: Cleave in front, and Frailty, which lowers your stats.",
              tank="Face him away from the group."),
    "5715": T("One of the six trolls on the balcony: Shadow Bolt Volley, Shadow Bolt, Curse of Blood, and Hukku's "
              "Guardians.",
              heal="Remove Curse of Blood (%s)." % CURSE,
              dps="Interrupt Shadow Bolt Volley; kill the guardians."),
    "5714": T("One of the six trolls on the balcony: Shield Slam stuns, and now and then he drops his threat.",
              tank="Taunt him back when he drops threat."),
    "5710": T("His door opens once the six trolls are dead. Hex of Jammal'an turns a player against the group, "
              "Flamestrike burns a spot, he drops an Earthgrab Totem, and he heals at 50%. Ogom the Wretched fights "
              "with him.",
              heal="Move out of Flamestrike.",
              dps="Interrupt Healing Wave; kill the totem."),
    "5721": T("A dragon: Acid Breath burns everyone in front, and Wing Flap knocks back those in front.",
              tank="Face it away from the group, with your back to a wall.",
              dps="Stand at its side or behind."),
    "5720": T("A dragon: Acid Breath burns everyone in front, and Wing Flap knocks back those in front.",
              tank="Face it away from the group, with your back to a wall.",
              dps="Stand at its side or behind."),
    "5719": T("A dragon: Acid Breath burns everyone in front, and Wing Flap knocks back those in front.",
              tank="Face it away from the group, with your back to a wall.",
              dps="Stand at its side or behind."),
    "5722": T("A dragon: Acid Breath burns everyone in front, and Wing Flap knocks back those in front.",
              tank="Face it away from the group, with your back to a wall.",
              dps="Stand at its side or behind."),
    "5709": T("Acid Breath in front, War Stomp around him, Deep Slumber sleeps a player, and Thrash gives him extra "
              "attacks.",
              tank="Face him away from the group.",
              heal="Dispel Deep Slumber (%s)." % MAGIC,
              dps="Stand behind him."),
    "8443": T("He comes after the four Eternal Flames are put out with Hakkari Blood from the Bloodkeepers. Cause "
              "Insanity turns a player against the group, Curse of Tongues slows casters, and Lash stuns and "
              "disarms.",
              tank="Lash stuns and disarms you.",
              heal="Remove Curse of Tongues (%s); dispel Shadow Word: Pain (%s)." % (CURSE, MAGIC),
              dps="Crowd-control a player under Cause Insanity rather than killing them."),

    # Blackrock Depths ---------------------------------------------------------------
    "9018": T("Psychic Scream fears, Mana Burn, Shadow Word: Pain, and a Shadow Shield that absorbs damage and hurts "
              "whoever hits her.",
              heal="Fear Ward or Tremor Totem help; keep out of Mana Burn's range.",
              dps="Interrupt Mana Burn; dispel her Shadow Shield (Priest)."),
    "9025": T("Ground Tremor stuns everyone near him, Earth Shock interrupts, and Flame Shock "
              "burns.",
              heal="Dispel Flame Shock (%s); stand back from Ground Tremor." % MAGIC),
    "9319": T("He fights with his hounds: Bloodlust, Pummel and Demoralizing Shout.",
              tank="Gather the hounds on you.",
              dps="Kill the hounds; Purge or Dispel Magic his Bloodlust."),
    "9031": T("The arena: waves of creatures, then a champion picked at random from six.",
              tank="Gather each wave on you.",
              dps="Kill each wave quickly, before the champion comes."),
    "9024": T("Scorching Totem, Fire Ward, Molten Blast and Flame Shock.",
              heal="Dispel Flame Shock (%s)." % MAGIC,
              dps="Kill the Scorching Totem; interrupt Molten Blast."),
    "9041": T("Frost Nova, Frostbolt, Frost Armor and Frost Ward; Verek, his hound, fights "
              "with him.",
              heal="Dispel Frost Nova and Frostbolt's slow (%s)." % MAGIC,
              dps="Interrupt Frostbolt."),
    "9476": T("Sunder Armor wears down his target's armour, and he drinks healing potions.",
              tank="Each Sunder Armor lowers your armour."),
    "9056": T("A paladin: Holy Strike, Holy Light at 60% and 40%, Seal of Reckoning at 20%, and he kicks casters.",
              heal="Stay out of his reach: he kicks casters.",
              dps="Interrupt Holy Light."),
    "9017": T("Fire Storm and Fiery Burst hit everyone near; Mighty Blow knocks back; Curse of the Elemental Lord "
              "lowers your resistances.",
              tank="Keep your back to a wall.",
              heal="Remove the curse (%s); fire resistance helps." % CURSE,
              dps="Ranged spread out."),
    "9016": T("At every fifth of his health he calls Spawns of Bael'Gar; Magma Splash burns his target.",
              tank="Pick up the spawns.",
              dps="Kill the spawns, then the boss."),
    "9033": T("Sunder Armor and Flurry, and he enrages; at 30% Anvilrage reservists and medics come to help him.",
              tank="Gather the reinforcements.",
              dps="Kill the Anvilrage Medics first."),
    "8983": T("Chain Lightning, Shock, and Lightning Shield; he wakes the golems in his room.",
              tank="Pick up the golems he wakes.",
              dps="Interrupt Chain Lightning; Purge his Lightning Shield."),
    "9537": T("He and his cronies come when the kegs of Thunderbrew Lager are broken. Flame Breath burns everyone in "
              "front, and Drunken Rage makes him hit harder.",
              tank="Face him away from the group.",
              heal="Flame Breath hits everyone in front."),
    "9543": T("Gouge stuns his target, and Hamstring slows; his cronies fight with him.",
              tank="Gouge drops you off him for a moment: be ready to taunt."),
    "9502": T("Fireball Volley hits everyone, Thunderclap around him, and Mighty Blow knocks back.",
              tank="Keep your back to a wall.",
              heal="Fireball Volley hits the whole group."),
    "9499": T("A warlock: Shadow Bolt, Immolate, Curse of Tongues and Banish; he sets Phalanx on you if the bar turns "
              "on you.",
              heal="Remove Curse of Tongues (%s)." % CURSE,
              dps="Interrupt Shadow Bolt."),
    "9156": T("Burning Spirits come out of the runes round the room and walk to him; Fire Blast burns his target.",
              tank="Hold him in the middle of the room.",
              dps="Kill the Burning Spirits before they reach him."),
    "9040": T("Talk to Doom'rel to start: the seven ghosts fight you one at a time, Doom'rel last.",
              tank="Pick up each ghost as it comes.",
              dps="Kill them one by one."),
    "9938": T("War Stomp and Fiery Burst; the Ironhall Guardians along the hall breathe fire while you fight him.",
              tank="Hold him away from the guardians' fire.",
              heal="Stand out of the fire and War Stomp's reach."),
    "9019": T("Hand of Thaurissan stuns his target, and Avatar of Flame burns those who hit him. Princess Moira "
              "heals him.",
              tank="You'll be stunned now and then.",
              dps="Stop Moira's heals: interrupt or crowd-control her, and kill the Emperor first."),

    # Frostmane Hollow ---------------------------------------------------------------
    "tansha": T("Tan'sha the Sleek fights with Handler Oboka."),
    "ubukaz": T("At 20% he enrages and hits much harder.",
                tank="Save a cooldown for 20%.",
                heal="Expect big hits from 20%.",
                dps="Burn the last 20% fast."),
    "kanza": T("He starts with two Frostmane Snowcallers, and casts Blizzard and Frostbolt.",
               heal="Move out of Blizzard.",
               dps="Kill the Snowcallers first; interrupt Blizzard and Frostbolt."),
    "hailar": T("Five Frostmane Ritualists heal him while they live. Flash Freeze hits and freezes everyone within "
                "10 yards for up to 5 seconds.",
                tank="Flash Freeze roots you: keep him away from the group.",
                heal="Stand more than 10 yards from him.",
                dps="Kill the Ritualists first: he can't die while they heal him. Interrupt Frostbolt."),

    # Windhorn Canyon ----------------------------------------------------------------
    "vortalus": T("Gust of Wind stuns a player for 4 seconds, and Chain Lightning jumps between everyone.",
                  heal="Chain Lightning hits the whole group.",
                  dps="Interrupt both, Gust of Wind first."),
    "stormhoof": T("Corruption, a curse, burns a player over time.",
                   heal="Remove Corruption (%s)." % CURSE),
}
