-- dict_cn_phrases.lua
-- Chinese (Simplified) → English PHRASE rules (ordered, applied before misc)
-- Ported from TranslateCN by Gangasrotogati
-- Format: { cn = "<pattern>", en = "<replacement>" }
-- Patterns are Lua string patterns (% escapes special chars).

dict_cn_phrases = {
    -- ============================================================================
    -- CRITICAL: Dungeon & Custom Zone Phrasing (Must be evaluated first!)
    -- ============================================================================
    { cn = "诺莫瑞根任务队", en = "Gnomeregan quest group " },
    { cn = "监狱任务队",     en = "Stockades quest group " },
    { cn = "霜鬃谷任务队",   en = "Frostmane Hollow quest group " },
    { cn = "新月来人",       en = "Crescent Grove LFG" },
    { cn = "小树林来TND",      en = "Crescent Grove need Tank, Healer, DPS " },
    { cn = "小树林",           en = "Crescent Grove " },
    { cn = "翡翠圣地开团",   en = "Forming Emerald Sanctum" },
    { cn = "仇恨熔炉速刷",   en = "Hateforge Quarry speedrun" },
    { cn = "死矿任务(%d)=(%d)", en = "Deadmines quest LFM (Need %2 more) " },
    { cn = "死矿任务队",     en = "Deadmines quest group " },
    { cn = "剃刀高地来人", en = "Razorfen Downs LFM, " },
    { cn = "新月小树林任务队", en = "Crescent Grove quest group " },
    { cn = "诺莫瑞根任务队",   en = "Gnomeregan quest group " },
    { cn = "监狱任务队",       en = "Stockades quest group " },
    { cn = "霜鬃谷任务队",     en = "Frostmane Hollow quest group " },
    { cn = "死矿任务队",       en = "Deadmines quest group " },
    { cn = "祖尔",           en = "ZF " },
    { cn = "来[nN]和[dD]",   en = "need Healer and DPS " },
    { cn = "来[tT]和[nN]",   en = "need Tank and Healer " },
    { cn = "来[tT]和[dD]",   en = "need Tank and DPS " },
    { cn = "有锤子",         en = "ZF Hammer ready " },
    { cn = "龙吼任务队",       en = "Dragonmaw Retreat quest group " },
    { cn = "龙吼",             en = "Dragonmaw Retreat " },
    { cn = "黑上全通",       en = "UBRS full run " },
    { cn = "许愿%+1",        en = "SR+1 " }, -- Note the '%' to escape the magic '+' character
{ cn = "新月小树林", en = "Crescent Grove" },  -- already have it but no "CG" abbreviation guard
{ cn = "霜鬃", en = "Frostmane Hollow" },       -- FH not covered
{ cn = "仇恨采石场", en = "Hateforge Quarry" }, -- HQ not covered

    -- ============================================================================
    -- Open-World Elite Quests & Hinterlands Specifics
    -- ============================================================================
    { cn = "辛特兰",         en = "Hinterlands " },
    { cn = "辛特兰JY",         en = "Hinterlands Elite quests " },
    { cn = "JY任务",         en = "Elite quests " },
    { cn = "来的[mM]",       en = "PST to join " },
    { cn = "另收",           en = "Also buying " },

    -- ============================================================================
    -- LFG Question Formats & Spacing Fixes
    -- ============================================================================
    { cn = "有没有死矿队伍啊", en = "Any Deadmines group? " },
    { cn = "有没有死矿队伍",   en = "Any Deadmines group " },
    
    -- Universal question fallbacks (handles any dungeon variant)
    { cn = "有没有",           en = "Any " },
    { cn = "队伍啊",           en = "group? " },
    { cn = "队伍",             en = "group " },

    -- ============================================================================
    -- Standalone English / Number Guard Rules (Protects words from corruption)
    -- ============================================================================
    { cn = "%f[%a][eE][sS]%f[%A]", en = "Emerald Sanctum" }, -- Only matches standalone "es" / "ES"
    { cn = "%f[%a][tT]%f[%A]",     en = "Tank" },            -- Only matches standalone "t" / "T"
    { cn = "%f[%a][nN]%f[%A]",     en = "Healer" },          -- Only matches standalone "n" / "N"
    { cn = "%f[%a][gG]%f[%A]",     en = "Gold" },            -- Only matches standalone "g" / "G"
    { cn = "(%d+)[gG]%f[%W]",      en = "%1 Gold" },         -- Formats gold safely (e.g., 20g -> 20 Gold)
    { cn = "%f[%a][aA][hH]%f[%A]", en = "WC" },              -- Only swaps "AH" if it's a standalone group tag
    { cn = "%f[%w]6%f[%W]",        en = "nice" },            -- Matches standalone "6", leaves "60+" perfectly safe
    { cn = "%f[%a][nN][dD]%f[%A]", en = "Resto Druid" },     -- Only matches standalone "nd" / "ND"
    { cn = "%f[%a][sS][tT]%f[%A]", en = "Sunken Temple " },  -- Only matches standalone "st" / "ST"

    -- ============================================================================
    -- Air-Tight Standalone Guard Rules (Protects system text and English sentences)
    -- ============================================================================
    { cn = "%f[%a][sS][sS]%f[%A]", en = "Warlock" },
    { cn = "%f[%a][sS][mM]%f[%A]", en = "Shaman" },
    { cn = "%f[%a][aA][mM]%f[%A]", en = "Shadow Priest" },
    { cn = "%f[%a][nN][dD]%f[%A]", en = "Resto Druid" },
    { cn = "%f[%a][hH][cC]%f[%A]", en = "Hardcore" },
    { cn = "%f[%a][eE][yY]%f[%A]", en = "Dire Maul" },
    { cn = "%f[%a][iI][fF]%f[%A]", en = "Ironforge" },
    { cn = "%f[%a][mM][cC]%f[%A]", en = "Molten Core" },
    { cn = "%f[%a][aA][bB]%f[%A]", en = "Arathi Basin" },
    { cn = "%f[%a][aA][vV]%f[%A]", en = "Alterac Valley" },
    { cn = "%f[%a][sS][wW]%f[%A]", en = "Stormwind" },
    { cn = "%f[%a][uU][cC]%f[%A]", en = "Undercity" },
    { cn = "%f[%a][oO][rR][gG]%f[%A]", en = "Orgrimmar" },
    { cn = "%f[%a][tT][lL]%f[%A]", en = "Scholomance" },
    { cn = "%f[%a][yY][sS]%f[%A]", en = "need water" },
    { cn = "%f[%a][fF][sS]%f[%A]", en = "Mage" },
    { cn = "%f[%a][lL][rR]%f[%A]", en = "Hunter" },
    { cn = "%f[%a][mM][nN]%f[%A]", en = "Main Healer" },   -- standalone "mn"/"MN" only
    { cn = "%f[%a][fF][nN]%f[%A]", en = "Off Healer" },    -- standalone "fn"/"FN" only
    { cn = "%f[%a][dD][dD]%f[%A]", en = "DPS" },           -- standalone "dd"/"DD" only
    { cn = "%f[%a][oO][kK]%f[%A]", en = "OK" },            -- standalone "ok"/"OK" only

    -- ============================================================================
    -- Advanced LFG Role Combos & Verbs
    -- ============================================================================
    { cn = "来[nN]%s?=%s?(%d+)", en = "LF%1M Healer " },
    { cn = "来[tT]%s?=%s?(%d+)", en = "LF%1M Tank " },
    { cn = "来[dD][pP][sS]%s?=%s?(%d+)", en = "LF%1M DPS " },
    { cn = "来[mM][sS]%s?=%s?(%d+)", en = "LF%1M Healer " }, -- Catching shorthand 'MS' (Priest/Healer)
    { cn = "需来个DPS或者奶", en = "need DPS or healer" },
    { cn = "需来个T或者奶",   en = "need tank or healer" },
    { cn = "需来个T",         en = "need a tank" },
    { cn = "需来个N",         en = "need a healer" },
    { cn = "需来个奶",        en = "need a healer" },
    { cn = "需来个DPS",       en = "need a DPS" },
    { cn = "有没有T来",       en = "any tanks for" },
    { cn = "有没有N来",       en = "any healers for" },
    { cn = "来个T或者N",      en = "need tank or healer" },
    { cn = "T或者N",          en = "tank or healer" },
    { cn = "来T%s?N",         en = "need Tank or Healer " },
    { cn = "来个T%s?N",       en = "need Tank or Healer " },
    { cn = "来点DPS",         en = "need some DPS" },
    { cn = "来个能拉人的",    en = "need someone who can summon" },
    { cn = "有没有大佬带",    en = "any pros to carry me?" },
    { cn = "来(%d)个",        en = "need %1 more" },
    { cn = "来T来奶",        en = "need Tank and Healer " },
    { cn = "来奶",           en = "need healer " },
    { cn = "来[tT]%s?[nN]", en = "need Tank and Healer " },
    { cn = "来[nN]%s?[tT]", en = "need Healer and Tank " },
    { cn = "%f[%a][tT][nN]%f[%A]", en = "Tank/Healer" },
    { cn = "来[tT][dD][nN]",   en = "need Tank, DPS, Healer " },
    { cn = "来[tT][nN][dD]",   en = "need Tank, Healer, DPS " },
    { cn = "任务队",           en = "quest group " },
    { cn = "来[dD]%s+[nN]",   en = "need DPS and Healer " },
    { cn = "来[tT]%s+[nN]%s?=%s?(%d+)", en = "LF%1M (Tank + Healer) " },
    { cn = "来[nN]%s+[tT]%s?=%s?(%d+)", en = "LF%1M (Healer + Tank) " },
    { cn = "来[dD]%s+[nN]%s?=%s?(%d+)", en = "LF%1M (DPS + Healer) " },
    { cn = "3BB护驾",          en = "3 party spots open " },
 
    -- ============================================================================
    -- Base LFG Role Requests
    -- ============================================================================
    { cn = "需要T",        en = "need tank" },
    { cn = "需要N",        en = "need healer" },
    { cn = "需要DPS",      en = "need dps" },
    { cn = "来个N",        en = "need a healer" },
    { cn = "来个T",        en = "need a tank" },
    { cn = "来个DPS",      en = "need a DPS" },
    { cn = "来个奶",       en = "need a healer" },
    { cn = "来[nN]",         en = "need Healer " },
    { cn = "来[tT]",         en = "need Tank " },
    { cn = "来[dD][pP][sS]", en = "need DPS " },
    { cn = "强力T",       en = "strong Tank" },
    { cn = "强力N",       en = "strong Healer" },
    { cn = "强力奶",      en = "strong Healer" },
    { cn = "来的[mM]+",        en = "PST " },
    { cn = "全通",           en = "full run " },
{ cn = "拉人", en = "summoning" },
{ cn = "没有传送", en = "no warlock for summon" },{ cn = "缺奶", en = "need healer" },
{ cn = "缺T", en = "need tank" },
{ cn = "缺DPS", en = "need DPS" },
{ cn = "奶满了", en = "healers full" },
{ cn = "T满了", en = "tanks full" },
{ cn = "满员了", en = "group full" },
{ cn = "已满", en = "full" },
{ cn = "消费团", en = "GDKP run" },   -- already in phrases but missing from misc
{ cn = "点数团", en = "DKP run" },
{ cn = "SR", en = "Soft Reserve" },
{ cn = "软保", en = "Soft Reserve" },
{ cn = "硬保", en = "Hard Reserve" },
{ cn = "许愿", en = "Soft Reserve" }, -- you have SR+1 but not the base term


    -- ============================================================================
    -- High-Level & Inferno Progression Farming Callouts
    -- ============================================================================
    { cn = "黑下宝钻",       en = "LBRS Diamond farm " },
    { cn = "刷装备",         en = "gear farm " },
    { cn = "炼狱饰品",       en = "Inferno trinket " },
    { cn = "第一步",         en = "step 1 " },
    { cn = "打信",           en = "farming quest drop " },
    { cn = "已开工",         en = "run in progress " },
    { cn = "能拉",           en = "can summon " },
    { cn = "可以拉",         en = "can summon " },
    { cn = "55%+即可",       en = "lvl 55+ welcome " },
{ cn = "HC队", en = "HC group" },
{ cn = "HC专用", en = "HC only" },
{ cn = "非HC勿扰", en = "HC players only, please" },
{ cn = "HC新手", en = "HC newbie" },

    -- ============================================================================
    -- Homophone & Slang Dungeon Fixes (Fixes "Noob Market" typo)
    -- ============================================================================
    { cn = "新月小树林",       en = "Crescent Grove " },
    { cn = "菜市场",         en = "Hateforge Quarry " }, -- Catches the caishichang typo for 采石场
    { cn = "NY任务队",       en = "RFC quest group " },  -- Stops NY from squishing into text
    { cn = "外围也做",       en = "doing outer quests too " },
    { cn = "YY任务队",       en = "SFK quest group " },
    { cn = "强T带队",       en = "strong Tank leading group " },
    { cn = "各种",           en = "all roles " },
    { cn = "新月小树林任务队", en = "Crescent Grove quest group " },
    { cn = "血色外围任务来人", en = "SM outer quests LFM, " },
    { cn = "血色外围任务",     en = "SM outer quests " },
    { cn = "外围任务",         en = "outer quests " },
    { cn = "一起",             en = "together " },

    -- ============================================================================
    -- Punctuation Role Combos & Better Level Scaling
    -- ============================================================================
    { cn = "来[tT]%.[dD]",   en = "need Tank and DPS " }, -- Catches punctuated "T.D" styles cleanly
    { cn = "来(%d+)%+",      en = "need lvl %1+ " },      -- Converts "来52+" into "need lvl 52+" instead of "to 52+"

    -- ============================================================================
    -- Profession Material & Trade Phrasing (Fixes "Middle-Skinned People")
    -- ============================================================================
    { cn = "收中皮",         en = "WTB Medium Leather " },
    { cn = "一组",           en = "1 stack " },
    { cn = "人在幽暗",       en = "currently in Undercity " },
{ cn = "收材料", en = "WTB mats" },
{ cn = "卖装备", en = "WTS gear" },
{ cn = "收装备", en = "WTB gear" },
{ cn = "出售", en = "WTS" },
{ cn = "收购", en = "WTB" },
{ cn = "私聊", en = "PST" },
{ cn = "低价出", en = "selling cheap" },
{ cn = "高价收", en = "buying at good price" },
{ cn = "议价", en = "price negotiable" },

    -- ============================================================================
    -- Original Base Phrases & Movements
    -- ============================================================================
    { cn = "来的组我",     en = "group with me" },
    { cn = "一起刷",       en = "run together" },
    { cn = "组队",         en = "group up" },
    { cn = "新建公会",     en = "New guild" },
    { cn = "其他也欢迎",   en = "others welcome" },
    { cn = "G团",          en = "GDKP" },
    { cn = "消费团",       en = "GDKP run" },
    { cn = "晚7%-11",      en = "7 to 11 pm" },
    { cn = "晚7",          en = "7 pm" },
    { cn = "绝不加班",     en = "no overtime" },
    { cn = "我吃饱了",     en = "I'm full" },
    { cn = "或者",         en = "or" },
    { cn = "号",           en = "" },
{ cn = "晚8", en = "8 pm" },
{ cn = "晚9", en = "9 pm" },
{ cn = "晚10", en = "10 pm" },
{ cn = "下午", en = "afternoon" },
{ cn = "明天", en = "tomorrow" },
{ cn = "今晚", en = "tonight" },
{ cn = "周末", en = "this weekend" },

    -- ============================================================================
    -- Tactical & Combat Callouts
    -- ============================================================================
    { cn = "全力输出",     en = "full DPS" },
    { cn = "全灭",         en = "wipe" },
    { cn = "推倒",         en = "boss down" },
{ cn = "战士T", en = "Warrior tank" },
{ cn = "圣骑T", en = "Paladin tank" },
{ cn = "德鲁伊T", en = "Druid tank" },
{ cn = "牧师奶", en = "Priest healer" },
{ cn = "萨满奶", en = "Shaman healer" },
{ cn = "德鲁伊奶", en = "Druid healer" },


    -- ============================================================================
    -- General Social Status / Group Coordination
    -- ============================================================================
    { cn = "有没有人",     en = "anyone want to" },
    { cn = "带我",         en = "carry me" },
    { cn = "有位置吗",     en = "any spots open?" },
    { cn = "还缺人吗",     en = "still need people?" },
    { cn = "等人",         en = "waiting for people" },

    -- ============================================================================
    -- Loot Contexts & Trade
    -- ============================================================================
    { cn = "需要还是贪婪", en = "need or greed" },
    { cn = "可以需要",     en = "you can need it" },
    { cn = "别需要",       en = "don't need it" },
    { cn = "这是我的",     en = "that's mine" },
    { cn = "你先要",       en = "you take it" },
    { cn = "给我",         en = "give it to me" },
    { cn = "卖多少",       en = "how much?" },
    { cn = "多少金",       en = "how much gold?" },
    { cn = "可以便宜吗",   en = "can you go cheaper?" },
    { cn = "不卖",         en = "not for sale" },

    -- ============================================================================
    -- Social Reactions & Greetings
    -- ============================================================================
    { cn = "干得好",       en = "good job" },
    { cn = "打得好",       en = "well played" },
    { cn = "真厉害",       en = "impressive" },
    { cn = "新手",         en = "newbie" },
    { cn = "大佬",         en = "pro player" },
    { cn = "带我飞",       en = "carry me" },
    { cn = "没关系",       en = "it's fine" },
    { cn = "没事",         en = "no worries" },
    { cn = "我知道了",     en = "I understand" },
    { cn = "不知道",       en = "I don't know" },
    { cn = "你好",         en = "hello" },
    { cn = "再见",         en = "goodbye" },
    { cn = "晚安",         en = "good night" },
    { cn = "早上好",       en = "good morning" },

    -- ============================================================================
    -- Lockouts & Group Sizing Metrics
    -- ============================================================================
    { cn = "全程带",       en = "full carry" },
    { cn = "带飞",         en = "carry run" },
    { cn = "自己有本",     en = "have lockout" },
    { cn = "没有本",       en = "no lockout" },
    { cn = "没本",         en = "no lockout" },
    { cn = "满5",          en = "full 5/5" },
    { cn = "缺(%d)",       en = "need %1 more" },

    -- ============================================================================
    -- Hardcore Survival Warnings
    -- ============================================================================
    { cn = "HC模式注意安全", en = "HC mode, play safe" },
    { cn = "别引怪会害死人", en = "Don't ninja pull, you'll kill us" },
    { cn = "求稳不要求快",   en = "Safety first, don't rush" },
    { cn = "珠宝大师",       en = "Zhubao (Master Crafter) " },
    { cn = "珠宝商人",       en = "Zhubao (Merchant) " },
    { cn = "一个珠宝",       en = "one Zhubao " },
    { cn = "少了一个珠宝",   en = "one less Zhubao " },

    -- ============================================================================
    -- Economy & Strategic Warnings
    -- ============================================================================
    { cn = "免费代工",     en = "Free crafting (your mats)" },
    { cn = "自带材料",     en = "Bring your own mats" },
    { cn = "代工做极品",   en = "Crafting high tier gear" },
}