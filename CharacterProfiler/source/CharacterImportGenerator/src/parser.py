import datetime
import math
import time
import re
import ast

from src.constants import *


def clean(mystr, chars_to_remove=("\n",)):
    return "".join([e for e in mystr if e not in chars_to_remove])

def parse_file(f, exp, world_db_name, turtle_version):
    slotCache = {}
    for slot in slots:
        slotCache[slot] = 0

    # 1. Extract the table part
    data_string = f.split('myProfile =')[1].strip()
    if data_string.endswith(';'):
            data_string = data_string[:-1].strip()
    # 2. Transform Lua syntax to Python syntax:
    # Change ["Key"] = to "Key":
    python_str = re.sub(r'\["(.*?)"\]\s*=', r'"\1":', data_string)
    python_str = re.sub(r'\[(\d+)\]\s*=', r'\1:', python_str)
    python_str = re.sub(r'\btrue\b', '1', python_str)
    python_str = re.sub(r'\bfalse\b', '0', python_str)
    python_str = re.sub(r'\bnil\b', 'None', python_str)

    # 3. Now literal_eval will work
    myProfile = ast.literal_eval(python_str)
    
    # Function to iterate through each character and its subkeys
    def iterate_profile(profile):
        # Iterate over each key-value pair in the top-level dictionary
        for realm, data in profile.items():
            if isinstance(data, dict):
                print(f"Realm: {realm}")
                for char_name, char in data.items():
                    print(f"  Character: {char_name}")
                    global inventory_list, instance_list, itemguiditr, cskills, quests, creputation
                    inventory_list = ""
                    instance_list = ""
                    cskills = ""
                    quests=""
                    creputation=""
                    itemguiditr = 1

                    def get_char_info():
                        global skills, class_name
                        char_class = char["Class"].lower()
                        class_name = char_class
                        char_race = char["Race"]
                        armor_skill = skillmap[char_class]["armor"]
                        weapon_skills = skillmap[char_class]["weapons"]

                        # calculate bank slots
                        bank_data = char.get("Bank", {})
                        bank_keys = bank_data.keys()
                        bank_bags_count = sum(1 for key in bank_keys if key.startswith("Bag"))
                        bank_bags_count = min(6, bank_bags_count)
                        player_bytes_2_value = bank_bags_count << 16

                        xp_string = char.get("XP", "0:0:0")
                        xp_splits = xp_string.split(":")
                        current_xp = int(xp_splits[0])
                        total_xp = int(xp_splits[1])
                        rest_xp = int(xp_splits[2])

                        char_total_time = char.get("TimePlayed", "0")
                        char_level_time = char.get("TimeLevelPlayed", "0")

                        result = dict(
                            char_name=clean(char_name, ["\n", '"']),
                            char_gender=0 if char["Sex"] == "Male" else 1,
                            char_class=classes[char_class],
                            char_race=races[char_race],
                            char_level=char["Level"],
                            char_money=char["Money"]["Copper"] + (char["Money"]["Silver"] * 10) + (char["Money"]["Gold"] * 100),
                            char_expansion=1,
                            char_locale='enUS',
                            char_health=char["Health"],
                            char_power=0 if char["Power"] == "Rage" else char["Mana"],
                            player_bytes_2=player_bytes_2_value,
                            char_xp=current_xp,
                            char_rest_xp=rest_xp,
                            char_total_time=char_total_time,
                            char_level_time=char_level_time
                        )

                        if len(armor_skill):
                            skills += skillsTemplate.fill(
                                skill_id=armor_skill[0],
                                current_skill=1,
                                max_skill=1,
                            )
                        for weaponSkill in weapon_skills:
                            skills += skillsTemplate.fill(
                                skill_id=weaponSkill,
                                current_skill=int(result["char_level"]) * 5,
                                max_skill=int(result["char_level"]) * 5,
                            )

                        return result

                    def add_to_itemlists(
                        slot_id,
                        item_entry,
                        suffix,
                        enchant,
                        gems,
                        buckle,
                        bag_id="0",
                        item_count=1,
                        bagno=5,
                        worn=False,
                        bag_offset=0,
                    ):
                        global inventory_list, instance_list, itemguiditr
                        bagMap = {
                            "0": 0,
                            "1": 10000 + ((bag_offset + 0) * 2),
                            "2": 10000 + ((bag_offset + 1) * 2),
                            "3": 10000 + ((bag_offset + 2) * 2),
                            "4": 10000 + ((bag_offset + 3) * 2),
                        }
                        slot_id = int(slot_id)
                        socketBonus = 0
                        if (bag_id != "99"): # MailBox
                            if bag_id != "0" and bagno > 3 and not worn:
                                inventory_list += wornTemplate.fill(
                                    slot_id=slot_id,
                                    item_guid=itemguiditr,
                                    item_entry=item_entry,
                                    bag_id=bagMap[str(bag_id)],
                                )
                            elif bag_id == "0" and bagno <= 3 and worn: # Equipment ???
                                inventory_list += wornTemplate.fill(
                                    slot_id=slot_id - 1,
                                    item_guid=itemguiditr,
                                    item_entry=item_entry,
                                    bag_id=bag_id,
                                )
                            elif bag_id == "0" and bagno > 3 and not worn: # BackPack
                                inventory_list += wornTemplate.fill(
                                    slot_id=((slot_id - 1) + 23),
                                    item_guid=itemguiditr,
                                    item_entry=item_entry,
                                    bag_id=bag_id,
                                )
                            else:
                                inventory_list += wornTemplate.fill(
                                    slot_id=slot_id,
                                    item_guid=itemguiditr,
                                    item_entry=item_entry,
                                    bag_id=bag_id,
                                )
                        sockets = [gems[0].split(":")[1], gems[1].split(":")[1], gems[2].split(":")[1]] if gems else []
                        suffix = abs(int(suffix))
                        enchantments = ""
                        if exp == 0:
                            if str(suffix) in suffixTable2:
                                enchantments = instanceEnchantTemplateVan.fill(
                                    main_enchant=enchant,
                                    enchant_1=suffixTable2[str(suffix)][0],
                                    enchant_2=suffixTable2[str(suffix)][1],
                                    enchant_3=suffixTable2[str(suffix)][2],
                                )
                            elif str(suffix) in suffixTable:
                                enchantments = instanceEnchantTemplateVan.fill(
                                    main_enchant=enchant,
                                    enchant_1=suffixTable[str(suffix)][0],
                                    enchant_2=suffixTable[str(suffix)][1],
                                    enchant_3=suffixTable[str(suffix)][2],
                                )
                            else:
                                enchantments = instanceEnchantTemplateVan.fill(
                                    main_enchant=enchant, enchant_1=0, enchant_2=0, enchant_3=0
                                )
                        elif exp == 1:
                            if "false" not in sockets and "true" in sockets:
                                socketBonus = itemSocketBonusMap[int(item_entry)]
                            #            if str(suffix) not in suffixTable:
                            #                suffix = 0
                            if str(suffix) in suffixTable:
                                enchantments = instanceEnchantTemplateTBC.fill(
                                    main_enchant=enchant,
                                    gem1=gemPropertyMap[gemIDPropertyMap[int(gems[0].split(":")[0])]],
                                    gem2=gemPropertyMap[gemIDPropertyMap[int(gems[1].split(":")[0])]],
                                    gem3=gemPropertyMap[gemIDPropertyMap[int(gems[2].split(":")[0])]],
                                    socket_bonus=socketBonus,
                                    enchant_1=suffixTable[str(suffix)][0],
                                    enchant_2=suffixTable[str(suffix)][1],
                                    enchant_3=suffixTable[str(suffix)][2],
                                )
                            else:
                                enchantments = instanceEnchantTemplateTBC.fill(
                                    main_enchant=enchant,
                                    gem1=gemPropertyMap[gemIDPropertyMap[int(gems[0].split(":")[0])]],
                                    gem2=gemPropertyMap[gemIDPropertyMap[int(gems[1].split(":")[0])]],
                                    gem3=gemPropertyMap[gemIDPropertyMap[int(gems[2].split(":")[0])]],
                                    socket_bonus=socketBonus,
                                    enchant_1=suffixTable[str(suffix)][0],
                                    enchant_2=suffixTable[str(suffix)][1],
                                    enchant_3=suffixTable[str(suffix)][2],
                                )
                        elif exp == 2:
                            if (
                                "false" not in sockets
                                and "true" in sockets
                                and int(item_entry) in itemSocketBonusMapWotlk
                            ):
                                socketBonus = itemSocketBonusMapWotlk[int(item_entry)]
                            if str(suffix) not in suffixTable:
                                suffix = 0
                            if buckle == "false":
                                enchantments = instanceEnchantTemplateWOTLK.fill(
                                    main_enchant=enchant,
                                    gem1=gemPropertyMapWotLK[
                                        gemIDPropertyMapWotlk[int(gems[0].split(":")[0])]
                                    ],
                                    gem2=gemPropertyMapWotLK[
                                        gemIDPropertyMapWotlk[int(gems[1].split(":")[0])]
                                    ],
                                    gem3=gemPropertyMapWotLK[
                                        gemIDPropertyMapWotlk[int(gems[2].split(":")[0])]
                                    ],
                                    socket_bonus=socketBonus,
                                    enchant_1=suffixTable[str(suffix)][0],
                                    enchant_2=suffixTable[str(suffix)][1],
                                    enchant_3=suffixTable[str(suffix)][2],
                                )
                            else:
                                enchantments = instanceEnchantTemplateWOTLK.fill(
                                    main_enchant=enchant,
                                    gem1=gemPropertyMapWotLK[
                                        gemIDPropertyMapWotlk[int(gems[0].split(":")[0])]
                                    ],
                                    gem2=gemPropertyMapWotLK[
                                        gemIDPropertyMapWotlk[int(gems[1].split(":")[0])]
                                    ],
                                    gem3=gemPropertyMapWotLK[
                                        gemIDPropertyMapWotlk[int(gems[2].split(":")[0])]
                                    ],
                                    socket_bonus=socketBonus,
                                    enchant_1=3729,
                                    enchant_2=suffixTable[str(suffix)][1],
                                    enchant_3=suffixTable[str(suffix)][2],
                                )
                        if exp == 0:
                            instance_list += instanceTemplateTurtle.fill(
                                item_guid=itemguiditr,
                                item_entry=item_entry,
                                item_count=item_count,
                                item_suffix=suffix,
                                enchantments=enchantments,
                            )
                        elif exp == 1:
                            instance_list += instanceTemplate.fill(
                                item_guid=itemguiditr,
                                item_entry=item_entry,
                                item_count=item_count,
                                item_suffix=(-suffix),
                                enchantments=enchantments,
                            )
                        elif exp == 2:
                            instance_list += instanceTemplateWotLK.fill(
                                item_guid=itemguiditr,
                                item_entry=item_entry,
                                item_count=item_count,
                                item_suffix=-suffix,
                                enchantments=enchantments,
                            )
                        itemguiditr += 2

                    def parse_slots_equipped():
                        global inventory_list
                        inventory_list += "\n\n"
                        def parse_slots_base():
                            item_info = char["Equipment"][slot[0].upper() + slot[1:]]["Item"].split(":")
                            suffix = "0"
                            enchant = "0"
                            gems = []
                            buckle = "false"
                            if len(item_info) == 4:
                                suffix = item_info[2]
                                enchant = item_info[1]
                            elif len(item_info) == 9:
                                suffix = item_info[2].split("=")[1]
                                enchant = item_info[4].split("=")[1]
                                gems = [
                                    item_info[5].split("=")[1],
                                    item_info[6].split("=")[1],
                                    item_info[7].split("=")[1],
                                ]
                                buckle = [item_info[8].split("=")[1]]
                            elif len(item_info) == 7:
                                enchant = item_info[2].split("=")[1]
                                gems = [
                                    item_info[3].split("=")[1],
                                    item_info[4].split("=")[1],
                                    item_info[5].split("=")[1],
                                ]
                                buckle = [item_info[6].split("=")[1]]

                            item_entry = item_info[0]
                            add_to_itemlists(
                                slotMap[slot],
                                item_entry,
                                suffix,
                                enchant,
                                gems,
                                buckle[0].rstrip(),
                                worn=True,
                            )
                            slotCache[slot] = item_entry

                        for slot in slots:
                            if (slot[0].upper() + slot[1:]) not in (char["Equipment"]):
                                    continue
                            parse_slots_base()

                    def get_all_items():
                        all_items = dict(
                            # [header, start, end, file lines]
                            gear=["GEAR FROM BAG", 0, 0, []],
                            talents=["TALENTS", 0, 0, []],
                            actions=["ACTIONS", 0, 0, []],
                            macros=["MACROS", 0, 0, []],
                            spells=["SPELLS", 0, 0, []],
                            factions=["FACTIONS", 0, 0, []],
                            quests=["QUESTS", 0, 0, []],
                            glyphs=["GLYPHS", 0, 0, []],
                            achievements=["ACHIEVEMENTS", 0, 0, []],
                            cskills=["SKILLS", 0, len(f) - 2, []],
                        )
                        previous_k = ""
                        for k, v in all_items.items():
                            for line in char:
                                all_items[k][1] += 1
                                if v[0] in line:
                                    if previous_k:
                                        all_items[previous_k][2] = all_items[k][1]
                                    previous_k = k
                                    break
                        for k, v in all_items.items():
                            for i in range(v[1], v[2] - 1):
                                text = f[i].rstrip("\n")
                                if text:
                                    v[3].append(text)

                        return all_items

                    def parse_bag():
                        global inventory_list
                        inventory_list += "\n\n"
                        def parse_bag_base(bag_offset):
                            global inventory_list
                            bag_info = char["Inventory"]["Bag"+str(bag_offset)]["Item"].split(":")
                            suffix = "0"
                            enchant = "0"
                            gems = []
                            buckle = "false"
                            bag_entry = bag_info[0]
                            bag_item_count = char["Inventory"]["Bag"+str(bag_offset)]["Slots"]
                            slotID = INVENTORY_SLOT_BAG_START + bag_offset
                            bagID = bag_offset
                            
                            # skip backpack
                            if bag_offset > 0 and bag_offset != 5:
                                inventory_list += "\n\n"
                                bagID = itemguiditr
                                # Add bag itself
                                add_to_itemlists(
                                    slotID,
                                    bag_entry,
                                    suffix,
                                    enchant,
                                    gems,
                                    buckle[0],
                                    bagno=1,
                                    worn=True,
                                    bag_offset=bag_offset
                                    # item_count=item_count,
                                    # bag_offset=bag_offset,
                                )

                            # Add items in bag
                            inventory_list += "\n\n"
                            bag_contents = char["Inventory"]["Bag"+str(bag_offset)]["Contents"]
                            for i in range(0, bag_item_count):
                                item_data = bag_contents.get(i + 1, None)
                                if item_data is None:
                                    continue

                                item_info = item_data["Item"].split(":")
                                suffix = "0"
                                enchant = "0"
                                gems = []
                                buckle = "false"
                                if len(item_info) == 4:
                                    suffix = item_info[2]
                                    enchant = item_info[1]
                                elif len(item_info) == 9:
                                    suffix = item_info[2].split("=")[1]
                                    enchant = item_info[4].split("=")[1]
                                    gems = [
                                        item_info[5].split("=")[1],
                                        item_info[6].split("=")[1],
                                        item_info[7].split("=")[1],
                                    ]
                                    buckle = [item_info[8].split("=")[1]]
                                elif len(item_info) == 7:
                                    enchant = item_info[2].split("=")[1]
                                    gems = [
                                        item_info[3].split("=")[1],
                                        item_info[4].split("=")[1],
                                        item_info[5].split("=")[1],
                                    ]
                                    buckle = [item_info[6].split("=")[1]]

                                item_entry = item_info[0]
                                item_count = item_data["Quantity"]
                                item_slot = i
                                if bagID == 0:
                                    item_slot += 1
                                    bagno = 5
                                else:
                                    bagno = 1

                                if bag_offset == 5: # Keyring
                                    item_slot = KEYRING_SLOT_START + i
                                    bagID = 0
                                    bagno = 1

                                add_to_itemlists(
                                    item_slot,
                                    item_entry,
                                    suffix,
                                    enchant,
                                    gems,
                                    buckle[0],
                                    bagno=bagno,
                                    bag_id=str(bagID),
                                    item_count=item_count,
                                    bag_offset=bag_offset,
                                )

                        for i in range(6):
                            if (f"Bag"+str(i)) not in (char["Inventory"]):
                                continue
                            parse_bag_base(i)

                    def parse_bank():
                        global inventory_list
                        inventory_list += "\n\n"
                        def parse_bank_self():
                            global inventory_list
                            inventory_list += "\n\n"
                            if not char.get("Bank"):
                                return
                            
                            # Add items in bank
                            bag_contents = char["Bank"]["Contents"]
                            for i in range(0, 25):
                                item_data = bag_contents.get(i + 1, None)
                                if item_data is None:
                                    continue

                                item_info = item_data["Item"].split(":")
                                suffix = "0"
                                enchant = "0"
                                gems = []
                                buckle = "false"
                                if len(item_info) == 4:
                                    suffix = item_info[2]
                                    enchant = item_info[1]
                                elif len(item_info) == 9:
                                    suffix = item_info[2].split("=")[1]
                                    enchant = item_info[4].split("=")[1]
                                    gems = [
                                        item_info[5].split("=")[1],
                                        item_info[6].split("=")[1],
                                        item_info[7].split("=")[1],
                                    ]
                                    buckle = [item_info[8].split("=")[1]]
                                elif len(item_info) == 7:
                                    enchant = item_info[2].split("=")[1]
                                    gems = [
                                        item_info[3].split("=")[1],
                                        item_info[4].split("=")[1],
                                        item_info[5].split("=")[1],
                                    ]
                                    buckle = [item_info[6].split("=")[1]]

                                item_entry = item_info[0]
                                item_count = item_data["Quantity"]
                                item_slot = BANK_SLOT_ITEM_START + i
                                bagno = 1

                                add_to_itemlists(
                                    item_slot,
                                    item_entry,
                                    suffix,
                                    enchant,
                                    gems,
                                    buckle[0],
                                    bagno=bagno,
                                    bag_id=str(0),
                                    item_count=item_count
                                )

                        def parse_bank_base(bag_offset):
                            global inventory_list
                            bag_info = char["Bank"]["Bag"+str(bag_offset)]["Item"].split(":")
                            suffix = "0"
                            enchant = "0"
                            gems = []
                            buckle = "false"
                            bag_entry = bag_info[0]
                            bag_item_count = char["Bank"]["Bag"+str(bag_offset)]["Slots"]
                            slotID = BANK_SLOT_BAG_START + bag_offset
                            bagID = bag_offset
                            
                            # skip backpack
                            if bag_offset > 0:
                                inventory_list += "\n\n"
                                bagID = itemguiditr
                                # Add bag itself
                                add_to_itemlists(
                                    slotID,
                                    bag_entry,
                                    suffix,
                                    enchant,
                                    gems,
                                    buckle[0],
                                    bagno=1,
                                    worn=True,
                                    bag_offset=bag_offset
                                    # item_count=item_count,
                                    # bag_offset=bag_offset,
                                )

                            # Add items in bag
                            inventory_list += "\n\n"
                            bag_contents = char["Bank"]["Bag"+str(bag_offset)]["Contents"]
                            for i in range(0, bag_item_count):
                                item_data = bag_contents.get(i + 1, None)
                                if item_data is None:
                                    continue

                                item_info = item_data["Item"].split(":")
                                suffix = "0"
                                enchant = "0"
                                gems = []
                                buckle = "false"
                                if len(item_info) == 4:
                                    suffix = item_info[2]
                                    enchant = item_info[1]
                                elif len(item_info) == 9:
                                    suffix = item_info[2].split("=")[1]
                                    enchant = item_info[4].split("=")[1]
                                    gems = [
                                        item_info[5].split("=")[1],
                                        item_info[6].split("=")[1],
                                        item_info[7].split("=")[1],
                                    ]
                                    buckle = [item_info[8].split("=")[1]]
                                elif len(item_info) == 7:
                                    enchant = item_info[2].split("=")[1]
                                    gems = [
                                        item_info[3].split("=")[1],
                                        item_info[4].split("=")[1],
                                        item_info[5].split("=")[1],
                                    ]
                                    buckle = [item_info[6].split("=")[1]]

                                item_entry = item_info[0]
                                item_count = item_data["Quantity"]
                                item_slot = i
                                bagno = 1

                                add_to_itemlists(
                                    item_slot,
                                    item_entry,
                                    suffix,
                                    enchant,
                                    gems,
                                    buckle[0],
                                    bagno=bagno,
                                    bag_id=str(bagID),
                                    item_count=item_count,
                                    bag_offset=bag_offset,
                                )

                        for i in range(7):
                            if not char.get("Bank") or (f"Bag"+str(i)) not in (char["Bank"]):
                                continue

                            parse_bank_base(i)
                        
                        parse_bank_self()

                    def parse_and_add_spells():
                        global inventory_list
                        inventory_list += "\n\n"
                        
                        spell_book = char.get("SpellBook", {})
                        
                        for skill_line, skill_data in spell_book.items():
                            spells = skill_data.get("Spells", {})
                            
                            for spell_name, spell_info in spells.items():
                                # Экранируем апострофы
                                safe_spell_name = spell_name.replace("'", "\\'")
                                rank = spell_info.get("Rank", "")
                                
                                # Базовое условие: совпадение имени и наличие в таблице скиллов игрока
                                # Мы делаем JOIN или IN, чтобы отсечь NPC-спеллы
                                sql_base = (
                                    f"SELECT st.`entry` FROM `{world_db_name}`.`spell_template` st "
                                    f"INNER JOIN `{world_db_name}`.`skill_line_ability` sla ON st.`entry` = sla.`spell_id` "
                                    f"WHERE st.`name` = '{safe_spell_name}'"
                                )
                                
                                if rank:
                                    safe_rank = rank.replace("'", "\\'")
                                    # Ищем по имени, ранку и проверяем привязку к скиллам
                                    subquery = f"(SELECT COALESCE(({sql_base} AND st.`nameSubtext` = '{safe_rank}' LIMIT 1), 0))"
                                else:
                                    # Если ранка нет (пассивки), ищем только по имени + скиллам
                                    subquery = f"(SELECT COALESCE(({sql_base} LIMIT 1), 0))"
                                
                                # Подставляем в твой spellTemplate
                                inventory_list += spellTemplate.substitute(
                                    char_guid=char_guid,
                                    spell_id=subquery
                                )
                    
                    def parse_and_add_crafts():
                        global inventory_list
                        inventory_list += "\n\n"
                        
                        # Задаем шаблон, который сервер кушает без проблем
                        craftTemplate = Template(
                            "INSERT INTO `character_spell` VALUES ('$char_guid', $spell_id, '1', '0');\n"
                        )
                        
                        # Проверяем, есть ли вообще данные профессий (например, "Tradeskills" или "Crafts")
                        # Подставь сюда точное имя корневого ключа для проф из твоего Lua (допустим, "Professions")
                        prof_data = char.get("Professions", {}) 
                        
                        for prof_name, categories in prof_data.items():
                            # prof_name — это, например, "Survival"
                            
                            for category_name, recipes in categories.items():
                                # category_name — это, например, "Fishing Pole"
                                
                                for recipe_name, recipe_info in recipes.items():
                                    # recipe_name — это сам крафт, например, "Driftwood Fishing Pole"
                                    
                                    # Экранируем апострофы в названии рецепта
                                    safe_recipe_name = recipe_name.replace("'", "\\'")
                                    
                                    # Собираем SQL-подзапрос.
                                    # Ищем заклинание в spell_template, которое привязано к умениям (skill_line_ability)
                                    subquery = (
                                        f"(SELECT COALESCE(("
                                        f"SELECT st.`entry` FROM `{world_db_name}`.`spell_template` st "
                                        f"INNER JOIN `{world_db_name}`.`skill_line_ability` sla ON st.`entry` = sla.`spell_id` "
                                        f"WHERE st.`name` = '{safe_recipe_name}' LIMIT 1"
                                        f"), 0))"
                                    )
                                    
                                    # Заполняем шаблон и пихаем в общий пул
                                    inventory_list += craftTemplate.substitute(
                                        char_guid=char_guid,
                                        spell_id=subquery
                                    )

                    def parse_and_add_mailbox():
                        global inventory_list, itemguiditr, mailguiditr

                        mailbox = char.get("MailBox", {})
                        if not mailbox:
                            return

                        for mail_index, mail_info in mailbox.items():
                            # Читаем данные письма
                            sender_name = mail_info.get("Sender", "Unknown").replace("'", "\\'")
                            subject = mail_info.get("Subject", "No Subject").replace("'", "\\'")
                            money = int(mail_info.get("Coin", 0))
                            days = float(mail_info.get("Days", 30.0)) # Если дней нет, даем месяц по дефолту

                            item_data = mail_info.get("Item", {})
                            has_items = 1 if item_data else 0

                            # Шаг 1: Генерируем запись в таблицу `mail`
                            # Используем наш mailguiditr как жесткий ID письма
                            inventory_list += (
                                f"INSERT INTO `mail` (`id`, `messageType`, `stationery`, `mailTemplateId`, `sender`, `receiver`, `subject`, `itemTextId`, `has_items`, `expire_time`, `deliver_time`, `money`, `cod`, `checked`, `isDeleted`) "
                                f"VALUES ({mailguiditr}, 0, 41, 0, 0, {char_guid}, '{subject}', 0, {has_items}, UNIX_TIMESTAMP() + CAST({days} * 86400 AS UNSIGNED), UNIX_TIMESTAMP(), {money}, 0, 0, 0);\n"
                            )

                            # Шаг 2: Если к письму прикреплен предмет
                            if has_items:
                                item_name = item_data.get("Name", "").replace("'", "\\'")
                                quantity = int(item_data.get("Quantity", 1))

                                # Нам нужен ID предмета из базы мира (`item_template`)
                                # Ищем его по имени через вложенный SELECT
                                item_template_subquery = f"(SELECT COALESCE((SELECT `entry` FROM `{world_db_name}`.`item_template` WHERE `name` = '{item_name}' LIMIT 1), 0))"

                                # 2.1 Создаем сам предмет в `character_inventory`. 
                                # В MaNGOS для писем принято использовать специальное состояние. 
                                # Но так как сервер при импорте сам перестроит GUID-ы, мы свяжем его через наш сквозной itemguiditr.
                                # ВНИМАНИЕ: в оригинальном .pdump для вещей на почте строки character_inventory могут не требоваться,
                                # если ядро генерирует их из mail_items. Но для надежности запишем инстанс (в MaNGOS это таблица `item_instance`, 
                                # но раз у тебя всё в character_inventory, пишем туда в виртуальный слот почты, обычно это bag=0, slot=0 для почты, 
                                # либо сервер сам подхватит по item_guid из таблицы mail_items).
                                
                                # Пишем связь в `mail_items`
                                item_guid = itemguiditr
                                inventory_list += (
                                    f"INSERT INTO `mail_items` (`mail_id`, `item_guid`, `item_template`, `receiver`) "
                                    f"VALUES ({mailguiditr}, {itemguiditr}, {item_template_subquery}, {char_guid});\n"
                                )

                                add_to_itemlists(
                                    0,
                                    item_template_subquery,
                                    0,
                                    0,
                                    gems=[],
                                    buckle="false",
                                    bag_id=str(99),
                                    item_count=quantity
                                )

                            # Тратим один уникальный ID письма
                            mailguiditr += 1

                    def parse_and_add_talents():
                        global inventory_list
                        inventory_list += "\n\n"
                        
                        talentTemplate = Template(
                            "INSERT INTO `character_spell` VALUES ('$char_guid', $spell_id, '1', '0');\n"
                        )
                        
                        talents_data = char.get("Talents", {})
                        if not talents_data:
                            return
                            
                        for tree_name, tree_data in talents_data.items():
                            # tree_name — это "Balance"
                            # tree_data — это словарь со всеми талантами этой ветки
                            
                            # Защита: если ветка пустая или распарсилась не как словарь, пропускаем
                            if not isinstance(tree_data, dict):
                                continue
                                
                            for talent_name, talent_info in tree_data.items():
                                # talent_name — это "Moonglow"
                                # talent_info — это словарь с параметрами таланта (Location, Rank, Texture...)
                                
                                # Жестко проверяем, что talent_info — это словарь, у которого можно взять .get()
                                if not isinstance(talent_info, dict):
                                    continue
                                    
                                rank_str = talent_info.get("Rank", "0:0")
                                
                                # Разбираем строку ранга (например, "2:3" -> 2)
                                current_rank = int(rank_str.split(":")[0])
                                
                                if current_rank == 0:
                                    continue
                                    
                                safe_talent_name = talent_name.replace("'", "\\'")
                                db_rank_name = f"Rank {current_rank}"

                                sql_base = (
                                    f"SELECT st.`entry` FROM `{world_db_name}`.`spell_template` st "
                                    f"INNER JOIN `{world_db_name}`.`skill_line_ability` sla ON st.`entry` = sla.`spell_id` "
                                    f"WHERE st.`name` = '{safe_talent_name}'"
                                )
                                
                                if current_rank > 1:
                                    subquery = f"(SELECT COALESCE(({sql_base} AND st.`nameSubtext` = '{db_rank_name}' LIMIT 1), 0))"
                                else:
                                    subquery = f"(SELECT COALESCE(({sql_base} LIMIT 1), 0))"
                                
                                # subquery = (
                                #     f"(SELECT COALESCE(("
                                #     f"SELECT st.`entry` FROM `{world_db_name}`.`spell_template` st "
                                #     f"INNER JOIN `{world_db_name}`.`skill_line_ability` sla ON st.`entry` = sla.`spell_id` "
                                #     f"WHERE st.`name` = '{safe_talent_name}' AND st.`nameSubtext` = '{db_rank_name}' LIMIT 1"
                                #     f"), 0))"
                                # )
                                
                                inventory_list += talentTemplate.substitute(
                                    char_guid=char_guid,
                                    spell_id=subquery
                                )

                    def parse_skills(char_info):
                        global cskills, class_name  # используем твои глобальные переменные
                        
                        locale = char_info["char_locale"]
                        if locale not in vanillaSkillMap and locale not in tbcSkillMap:
                            print("Your client's language is not currently supported for skill export")
                            return

                        skills_root = char.get("Skills", {})
                        if not skills_root:
                            return
                            
                        # Проходим по категориям ("Secondary Skills", "Class Skills", "Professions" и т.д.)
                        for category_name, category_data in skills_root.items():
                            if not isinstance(category_data, dict):
                                continue
                                
                            for skill_name, skill_value in category_data.items():
                                # 1. Пропускаем технический маркер сортировки аддона
                                if skill_name == "Order":
                                    continue
                                    
                                # 2. Валидируем строку рангов (должна быть "текущий:макс")
                                if not isinstance(skill_value, str) or ":" not in skill_value:
                                    continue
                                    
                                # Парсим ранги из нашего формата
                                skillRank, maxRank = map(int, skill_value.split(":"))
                                
                                # 3. Чистим имя скилла от префикса аддона для языков, 
                                # чтобы мапа (например, vanillaSkillMap) могла его найти по чистому имени
                                clean_skill_name = skill_name.replace("Language: ", "")
                                
                                skill_id = 0
                                
                                # 4. Твоя родная логика проверки по константам парсера
                                if exp == 0:
                                    if clean_skill_name in duplicateSkills:
                                        skill_id = duplicateSkills[locale][clean_skill_name][class_name]
                                    elif clean_skill_name in vanillaSkillMap[locale]:
                                        skill_id = vanillaSkillMap[locale][clean_skill_name]
                                    else:
                                        print(f"Skill '{clean_skill_name}' not found in Vanilla skill map")
                                        continue  # Пропускаем, чтобы не спамить нулевыми ID
                                elif exp == 1:
                                    if clean_skill_name in duplicateSkills:
                                        skill_id = duplicateSkills[locale][clean_skill_name][class_name]
                                    elif clean_skill_name in tbcSkillMap[locale]:
                                        skill_id = tbcSkillMap[locale][clean_skill_name]
                                    else:
                                        print(f"Skill '{clean_skill_name}' not found in TBC skill map")
                                        continue
                                else:
                                    print("WotLK not supported for skill export yet")
                                    return

                                # Если скилл успешно определился, заполняем шаблон
                                if skill_id > 0:
                                    cskills += skillsTemplate.fill(
                                        skill_id=skill_id,
                                        current_skill=skillRank,
                                        max_skill=maxRank,
                                    )

                    def parse_quests():
                        global quests  # Используем твои глобальные переменные

                        # ==========================================
                        # ЧАСТЬ 1: АКТИВНЫЕ КВЕСТЫ (Ищем ID по имени + уровню)
                        # ==========================================
                        quests_active = char.get("Quests", {})
                        
                        for category_name, category_data in quests_active.items():
                            if not isinstance(category_data, dict):
                                continue
                                
                            for quest_index, quest_info in category_data.items():
                                if not isinstance(quest_info, dict):
                                    continue
                                    
                                title = quest_info.get("Title", "")
                                level = quest_info.get("Level", 0)
                                
                                if not title:
                                    continue
                                    
                                safe_title = title.replace("'", "\\'")
                                
                                # Строим подзапрос: ищем по имени и уровню квеста для точности
                                quest_id_subquery = (
                                    f"(SELECT COALESCE(("
                                    f"SELECT `entry` FROM `{world_db_name}`.`quest_template` "
                                    f"WHERE `Title` = '{safe_title}' AND `QuestLevel` = {level} LIMIT 1"
                                    f"), 0))"
                                )
                                
                                # Заполняем шаблон для активного квеста (rewarded = 0 или статус "активен")
                                # Если твои шаблоны принимают кастомные флаги, можно передать rewarded=0
                                if exp > 1:
                                    quests += questTemplateWotLK.fill(quest_id=quest_id_subquery, quest_status=3, quest_rewarded=0)
                                else:
                                    quests += questTemplateTurtle.fill(quest_id=quest_id_subquery, quest_status=3, quest_rewarded=0)

                        # ==========================================
                        # ЧАСТЬ 2: ВЫПОЛНЕННЫЕ КВЕСТЫ (ID уже есть в ключах!)
                        # ==========================================
                        quests_completed = char.get("QuestsCompleted", {})
                        
                        for quest_id_str, comp_info in quests_completed.items():
                            # Защита: проверяем, что ключ действительно числовой ID квеста
                            if not quest_id_str.isdigit():
                                continue
                                
                            quest_id = int(quest_id_str)
                            
                            # Здесь мы точно знаем, что квест сдан.
                            # Если твой .fill() умеет принимать параметр состояния, передаем туда флаг выполненного квеста.
                            # Например, если в шаблоне есть переменная rewarded, можно вызвать:
                            # questTemplate.fill(quest_id=quest_id, rewarded=1)
                            # Если шаблон жесткий, он просто сгенерирует дефолтную строку, которую ты просил:
                            
                            if exp > 1:
                                quests += questTemplateWotLK.fill(quest_id=quest_id, quest_status=0, quest_rewarded=1)
                            else:
                                quests += questTemplateTurtle.fill(quest_id=quest_id, quest_status=0, quest_rewarded=1)
                    
                    def parse_honor():
                        
                        honor_data = char.get("Honor", {})
                        if not honor_data:
                            return {
                                "honorRankPoints": 0.0, "honorHighestRank": 0, "honorStanding": 0,
                                "honorLastWeekHK": 0, "honorLastWeekCP": 0.0, "honorStoredHK": 0, "honorStoredDK": 0
                            }
                            
                        # 1. Вычисляем текущий ранг (парсим цифру из "(Rank 6)" или берем из Lifetime)
                        current_rank_desc = honor_data.get("Current", {}).get("Description", "(Rank 0)")
                        try:
                            # Извлекаем "6" из строки "(Rank 6)"
                            current_rank = int(current_rank_desc.split("Rank ")[1].replace(")", ""))
                        except (IndexError, ValueError):
                            current_rank = 0

                        # 2. Парсим прогресс внутри ранга (например, "0.00" -> 0.0)
                        try:
                            progress = float(honor_data.get("Current", {}).get("Progress", "0.00"))
                        except ValueError:
                            progress = 0.0

                        # Мапа базовых очков для каждого ранга (Rank -> Base RP)
                        rank_rp_map = {
                            0: 0,     1: 15,     2: 2000,  3: 5000,  4: 10000,
                            5: 15000, 6: 20000, 7: 25000, 8: 30000, 9: 35000,
                            10: 40000, 11: 45000, 12: 50000, 13: 55000, 14: 60000
                        }

                        # Вычисляем финальные очки чести с учетом прогресса полоски
                        base_rp = rank_rp_map.get(current_rank, 0)
                        
                        # Если ранг больше 2, то до следующего ранга надо набрать 5000 очков (для 1->2 нужно 2000)
                        rp_gap = 2000 if current_rank == 1 else 5000
                        
                        # Итоговые очки для honorRankPoints
                        honor_rank_points = base_rp + (progress * rp_gap)

                        # 3. Наивысший ранг за всю историю
                        highest_rank = int(honor_data.get("LifetimeHighestRank", current_rank))

                        # 4. Складываем HK текущей недели и прошлой
                        this_week_hk = int(honor_data.get("ThisWeek", {}).get("HK", 0))
                        last_week_hk = int(honor_data.get("LastWeek", {}).get("HK", 0))
                        total_last_week_hk = this_week_hk + last_week_hk

                        # 5. Складываем Contribution Points (CP / Контрибуция)
                        this_week_cp = float(honor_data.get("ThisWeek", {}).get("Contribution", 0))
                        last_week_cp = float(honor_data.get("LastWeek", {}).get("Contribution", 0))
                        total_last_week_cp = this_week_cp + last_week_cp

                        # 6. Убийства за всё время (Stored HK / DK)
                        stored_hk = int(honor_data.get("Lifetime", {}).get("HK", 0))
                        stored_dk = int(honor_data.get("Lifetime", {}).get("DK", 0))

                        # Возвращаем готовый словарь с переменными
                        return {
                            "honorRankPoints": round(honor_rank_points, 4),
                            "honorHighestRank": highest_rank,
                            "honorStanding": 0,  # Стендинг сервер пересчитает сам во время PvP-обновления в среду
                            "honorLastWeekHK": total_last_week_hk,
                            "honorLastWeekCP": round(total_last_week_cp, 1),
                            "honorStoredHK": stored_hk,
                            "honorStoredDK": stored_dk
                        }
                    
                    def parse_reputation():
                        global creputation, factionTemplate
                        
                        reputation_root = char.get("Reputation", {})
                        if not reputation_root:
                            return

                        # Мапа базовых очков для каждого статуса
                        standing_base_map = {
                            "Hated": -42000,
                            "Hostile": -6000,
                            "Unfriendly": -3000,
                            "Neutral": 0,
                            "Friendly": 3000,
                            "Honored": 9000,
                            "Revered": 12000,
                            "Exalted": 21000
                        }

                        # Обходим категории ("Other", "Steamwheedle Cartel", "Horde Forces" и т.д.)
                        for category_name, category_data in reputation_root.items():
                            if not isinstance(category_data, dict):
                                continue
                                
                            for faction_name, faction_info in category_data.items():
                                if not isinstance(faction_info, dict):
                                    continue
                                    
                                standing_str = faction_info.get("Standing", "Neutral")
                                value_str = faction_info.get("Value", "0/3000")
                                
                                # 1. Считаем чистую репутацию для базы
                                try:
                                    current_value = int(value_str.split("/")[0])
                                except (ValueError, IndexError):
                                    current_value = 0
                                    
                                base_points = standing_base_map.get(standing_str, 0)
                                final_standing_value = base_points + current_value

                                # Флаги видимости / AtWar (в твоем шаблоне стоит хардкод '1' в конце, 
                                # но если захочешь учесть AtWar, можно добавить его флагом)
                                # at_war = faction_info.get("AtWar", 0)

                                # 2. Экранируем имя фракции для SQL
                                safe_faction_name = faction_name.replace("'", "\\'")

                                # 3. Строим подзапрос к таблице мира `faction`
                                faction_id_subquery = (
                                    f"(SELECT COALESCE(("
                                    f"SELECT `id` FROM `{world_db_name}`.`faction` "
                                    f"WHERE `name1` = '{safe_faction_name}' LIMIT 1"
                                    f"), 0))"
                                )

                                # 4. Заливаем в твой factionTemplate
                                # В зависимости от того, как у тебя написан template (fill или substitute):
                                try:
                                    creputation += factionTemplate.fill(
                                        char_guid=char_guid,
                                        faction_id=faction_id_subquery,
                                        faction_standing=final_standing_value
                                    )
                                except AttributeError:
                                    creputation += factionTemplate.substitute(
                                        char_guid=char_guid,
                                        faction_id=faction_id_subquery,
                                        faction_standing=final_standing_value
                                    )

                    def parse_spells(all_items):
                        global skills, spells, action_list, faction_list, talents
                        spellList = []
                        if exp > 0 and str(34093) not in all_items["spells"][3]:
                            spells += spellTemplate.fill(spell_id=34093)
                        for spell in all_items["spells"][3]:
                            spell = int(spell)
                            if spell == 348700:
                                spell = 31892
                            if spell == 348704:
                                spell = 31801
                            if spell in spellList:
                                continue
                            if exp == 0 and spell in ridingSpellMap:
                                riding_skill = 75
                                riding_spell = 33388
                                if char_info["char_level"] == 60:
                                    riding_skill = 150
                                    riding_spell = 33391
                                skills += skillsTemplate.fill(
                                    skill_id=ridingSpellMap[spell],
                                    current_skill=riding_skill,
                                    max_skill=riding_skill,
                                )
                                if riding_spell not in spellList:
                                    spells += spellTemplate.fill(spell_id=riding_spell)
                                    spellList.append(riding_spell)
                            spellList.append(spell)
                            spells += spellTemplate.fill(spell_id=spell)
                            if exp > 1:
                                for index in range(len(talentArray)):
                                    talent = talentArray[index]
                                    if int(talent["r0"]) == spell:
                                        talents += talentTemplate.fill(
                                            talent_id=talent["id"], current_rank=0
                                        )
                                    elif int(talent["r1"]) == spell:
                                        talents += talentTemplate.fill(
                                            talent_id=talent["id"], current_rank=1
                                        )
                                    elif int(talent["r2"]) == spell:
                                        talents += talentTemplate.fill(
                                            talent_id=talent["id"], current_rank=2
                                        )
                                    elif int(talent["r3"]) == spell:
                                        talents += talentTemplate.fill(
                                            talent_id=talent["id"], current_rank=3
                                        )
                                    elif int(talent["r4"]) == spell:
                                        talents += talentTemplate.fill(
                                            talent_id=talent["id"], current_rank=4
                                        )

                        for action in all_items["actions"][3]:
                            actionInfo = action.split(",")
                            slot = actionInfo[0].split("=")[1]
                            actiontype = actionInfo[1].split("=")[1]
                            actionId = actionInfo[2].split("=")[1].replace("\n", "")
                            slot = int(slot) - 1
                            if exp != 2:
                                action_list += actionTemplate.fill(
                                    slot_id=slot,
                                    action_id=actionId,
                                    action_type=actionMap[actiontype],
                                )
                            else:
                                action_list += actionTemplateWotLK.fill(
                                    slot_id=slot,
                                    action_id=actionId,
                                    action_type=actionMap[actiontype],
                                )

                        for faction in all_items["factions"][3]:
                            factionInfo = faction.split(",")
                            factionId = factionInfo[0]
                            factionStanding = factionInfo[1]
                            faction_list += factionTemplate.fill(
                                faction_id=factionId,
                                faction_standing=factionStanding,
                            )

                    def write_pdump(char_info):
                        default_pos = startPosMap[exp][factions[char["Race"]]]
                        def_x, def_y, def_z, def_map = default_pos
                        current_zone = char.get("Zone", "").replace(" ", "")
                        hearth_zone = char.get("Hearth", "").replace(" ", "")

                        if current_zone:
                            safe_zone = current_zone.replace("'", "\\'")
                            pos_x_sql = f"COALESCE((SELECT `position_x` FROM `{world_db_name}`.`game_tele` WHERE `name` LIKE '{safe_zone}%' LIMIT 1), {def_x})"
                            pos_y_sql = f"COALESCE((SELECT `position_y` FROM `{world_db_name}`.`game_tele` WHERE `name` LIKE '{safe_zone}%' LIMIT 1), {def_y})"
                            pos_z_sql = f"COALESCE((SELECT `position_z` FROM `{world_db_name}`.`game_tele` WHERE `name` LIKE '{safe_zone}%' LIMIT 1), {def_z})"
                            pos_map_sql = f"COALESCE((SELECT `map` FROM `{world_db_name}`.`game_tele` WHERE `name` LIKE '{safe_zone}%' LIMIT 1), {def_map})"
                        else:
                            # Если зоны в Lua вообще не было
                            pos_x_sql, pos_y_sql, pos_z_sql, pos_o_sql, pos_map_sql = def_x, def_y, def_z, def_map

                        if hearth_zone:
                            safe_hearth = hearth_zone.replace("'", "\\'")
                            home_x_sql = f"COALESCE((SELECT `position_x` FROM `{world_db_name}`.`game_tele` WHERE `name` LIKE '{safe_hearth}%' LIMIT 1), {def_x})"
                            home_y_sql = f"COALESCE((SELECT `position_y` FROM `{world_db_name}`.`game_tele` WHERE `name` LIKE '{safe_hearth}%' LIMIT 1), {def_y})"
                            home_z_sql = f"COALESCE((SELECT `position_z` FROM `{world_db_name}`.`game_tele` WHERE `name` LIKE '{safe_hearth}%' LIMIT 1), {def_z})"
                            home_map_sql = f"COALESCE((SELECT `map` FROM `{world_db_name}`.`game_tele` WHERE `name` LIKE '{safe_hearth}%' LIMIT 1), {def_map})"
                        else:
                            home_x_sql, home_y_sql, home_z_sql, home_map_sql = def_x, def_y, def_z, def_map

                        p_pve_vp = parse_honor()

                        version = ""
                        charactersRow = ""
                        enchantments = ""
                        textIns = ""
                        equipmentCache = equipmentTemplate.fill(
                            head=slotCache["head"],
                            neck=slotCache["neck"],
                            shoulder=slotCache["shoulder"],
                            shirt=slotCache["shirt"],
                            chest=slotCache["chest"],
                            belt=slotCache["waist"],
                            legs=slotCache["legs"],
                            feet=slotCache["feet"],
                            wrist=slotCache["wrist"],
                            gloves=slotCache["hands"],
                            back=slotCache["back"],
                            mainhand=slotCache["MainHand"],
                            offhand=slotCache["OffHand"],
                            ranged=slotCache["Ranged"],
                            tabard=slotCache["tabard"],
                        )
                        bagId = 23162
                        if exp == 0:
                            version = "required_z2819_01_characters_item_instance_text_id_fix"
                            enchantments = instanceEnchantTemplateVan.fill(
                                main_enchant=0, enchant_1=0, enchant_2=0, enchant_3=0
                            )
                            bagId = 14156
                            
                            if turtle_version == 1:
                                charactersRow = charactersTemplateTurtle.fill(
                                    **char_info,
                                    pos_x=pos_x_sql,
                                    pos_y=pos_y_sql,
                                    pos_z=pos_z_sql,
                                    start_map=pos_map_sql,
                                    equipmentCache=equipmentCache,
                                    char_rank_points=p_pve_vp["honorRankPoints"],
                                    char_highest_rank=p_pve_vp["honorHighestRank"],
                                    char_lastweek_hk=p_pve_vp["honorLastWeekHK"],
                                    char_lastweek_cp=p_pve_vp["honorLastWeekCP"],
                                    char_stored_hk=p_pve_vp["honorStoredHK"],
                                    char_stored_dk=p_pve_vp["honorStoredDK"]
                                )
                            if turtle_version == 0:
                                charactersRow = charactersTemplateTurtle_OLD.fill(
                                    **char_info,
                                    pos_x=pos_x_sql,
                                    pos_y=pos_y_sql,
                                    pos_z=pos_z_sql,
                                    start_map=pos_map_sql,
                                    equipmentCache=equipmentCache,
                                    char_rank_points=p_pve_vp["honorRankPoints"],
                                    char_highest_rank=p_pve_vp["honorHighestRank"],
                                    char_lastweek_hk=p_pve_vp["honorLastWeekHK"],
                                    char_lastweek_cp=p_pve_vp["honorLastWeekCP"],
                                    char_stored_hk=p_pve_vp["honorStoredHK"],
                                    char_stored_dk=p_pve_vp["honorStoredDK"]
                                )
                        elif exp == 1:
                            version = "required_s2473_01_characters_item_instance_text_id_fix"
                            enchantments = instanceEnchantTemplateTBC.fill(
                                main_enchant=0,
                                gem1=0,
                                gem2=0,
                                gem3=0,
                                socket_bonus=0,
                                enchant_1=0,
                                enchant_2=0,
                                enchant_3=0,
                            )
                            charactersRow = charactersTemplateTBC.fill(
                                **char_info,
                                pos_x=pos_x_sql,
                                pos_y=pos_y_sql,
                                pos_z=pos_z_sql,
                                start_map=pos_map_sql,
                                equipmentCache=equipmentCache,
                            )
                        else:
                            version = "required_14061_01_characters_fishingSteps"
                            enchantments = instanceEnchantTemplateWOTLK.fill(
                                main_enchant=0,
                                gem1=0,
                                gem2=0,
                                gem3=0,
                                socket_bonus=0,
                                enchant_1=0,
                                enchant_2=0,
                                enchant_3=0,
                                equipmentCache=equipmentCache,
                            )
                            charactersRow = charactersTemplateWOTLK.fill(
                                **char_info,
                                pos_x=pos_x_sql,
                                pos_y=pos_y_sql,
                                pos_z=pos_z_sql,
                                start_map=pos_map_sql,
                            )
                            textIns = ", ''"

                        result = pdumpTemplate.fill(
                            bag_id=bagId,
                            characters_row=charactersRow,
                            enchantments=enchantments,
                            database_version=version,
                            pos_x=home_x_sql,
                            pos_y=home_y_sql,
                            pos_z=home_z_sql,
                            start_map=home_map_sql,
                            skills=cskills,
                            actions=action_list,
                            quests=quests,
                            inventory_list=inventory_list,
                            pet_list=pet_list,
                            spells=spells,
                            talents=talents,
                            instance_list=instance_list,
                            factions=creputation,
                            text=textIns,
                            glyphs=glyphs,
                            achievements=achievements,
                        )

                        randNo = datetime.datetime.now().strftime("%H%M%S")

                        with open(char_info["char_name"] + ".pdump", "w") as writer:
                            writer.write(result)
                            print(
                                "  Character conversion successful! Export written to: "
                                + char_info["char_name"]
                                # + randNo
                                + ".pdump"
                            )

                    char_info = get_char_info()
                    parse_slots_equipped()
                    print(f"  Character {char_name} parsed")
                    # parse_pet()
                    # all_items = get_all_items()
                    parse_bag()
                    parse_bank()
                    # parse_spells(all_items)
                    parse_and_add_spells()
                    parse_and_add_crafts()
                    parse_and_add_talents()
                    # parse_and_add_mailbox()
                    parse_skills(char_info)
                    parse_quests()
                    parse_reputation()
                    # parse_macros()
                    # parse_quests()
                    # parse_glyphs()
                    # parse_achievements()
                    # parse_skills()
                    write_pdump(char_info)

    # Iterate over the entire profile starting from the top-level dictionary
    iterate_profile(myProfile)

    return
