BINDING_HEADER_CS_MEETING_HEADER = "Meeting"
BINDING_NAME_CS_MEETING_NAME = "Show/Hide"

MEETING_DB = {}

local _, class = UnitClass("player")

Meeting = {
    VERSION = {
        MAJOR = 1,
        MINOR = 1,
        PATCH = 5,
    },

    player = UnitName("player"),

    playerClass = class,

    APPLICANT_STATUS = { None = 1, Invited = 2, Declined = 3, Joined = 4 },

    createInfo = {},

    searchInfo = {},

    activities = {},

    playerIsHC = false,

    channel = "LFT",

    isAFK = false,

    members = {},

    blockWords = {}, -- 添加屏蔽词引用 by 武藤纯子酱 2025.12.30
}

local classNameMap = {
    [1] = "WARLOCK",
    [2] = "HUNTER",
    [3] = "PRIEST",
    [4] = "PALADIN",
    [5] = "MAGE",
    [6] = "ROGUE",
    [7] = "DRUID",
    [8] = "SHAMAN",
    [9] = "WARRIOR",
}

local classNumberMap = {
    ["WARLOCK"] = 1,
    ["HUNTER"] = 2,
    ["PRIEST"] = 3,
    ["PALADIN"] = 4,
    ["MAGE"] = 5,
    ["ROGUE"] = 6,
    ["DRUID"] = 7,
    ["SHAMAN"] = 8,
    ["WARRIOR"] = 9,
}

local classChineseNameMap = {
    [1] = "Warlock",
    [2] = "Hunter",
    [3] = "Priest",
    [4] = "Paladin",
    [5] = "Mage",
    [6] = "Rogue",
    [7] = "Druid",
    [8] = "Shaman",
    [9] = "Warrior",
}

function Meeting.NumberToClass(n)
    return classNameMap[n]
end

function Meeting.ClassToNumber(class)
    return classNumberMap[class]
end

function Meeting.GetClassRGBColor(class, unitname)
    local rgb = RAID_CLASS_COLORS[class]
    if not class or not rgb then
        if SCCN_storage then
            local cache = SCCN_storage[unitname]
            if cache then
                return Meeting.GetClassRGBColor(Meeting.NumberToClass(cache.c))
            end
        end
        rgb = RAID_CLASS_COLORS[nil]
    end
    if not rgb then
        rgb = { r = 0.6, g = 0.6, b = 0.6 }
    end
    return rgb
end

Meeting.Categories = {
    {
        key = "DUNGENO",
        name = "Dungeons",
        members = 5,
        children = {
            {
                key = "RFC",
                name = "Ragefire Chasm",
                minLevel = 13,
                match = { "怒焰", "ny", "rfc", "ragefire" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "FH",
                name = "Frostmane Hollow",
                minLevel = 13,
                match = { "霜鬃", "szg", "fh", "frostmane", "fmh" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "WC",
                name = "Wailing Caverns",
                minLevel = 17,
                match = { "哀嚎", "ah", "wc", "wailing" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "DM",
                name = "The Deadmines",
                minLevel = 17,
                match = { "死矿", "sw", "dm", "deadmines" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "SFK",
                name = "Shadowfang Keep",
                minLevel = 22,
                match = { "影牙", "sfk", "shadowfang" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "STOCKS",
                name = "The Stockade",
                minLevel = 22,
                match = { "监狱", "stocks", "stockade" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "BFD",
                name = "Blackfathom Deeps",
                minLevel = 23,
                match = { "深渊", "bfd", "blackfathom" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "DR",
                name = "Dragonmaw Retreat",
                minLevel = 27,
                match = { "龙喉","格瑞姆巴托", "dragonmaw", "dr", "dmr" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },	
            {
                key = "WINDCAN",
                name = "Windhorn Canyon",
                minLevel = 27,
                match = { "风角","峡谷","牛头本", "windhorn", "windcan", "whc" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },				
            {
                key = "SMGY",
                name = "Scarlet Monastery Graveyard",
                minLevel = 27,
                match = { "血色", "sm", "scarlet", "smgy" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "SMLIB",
                name = "Scarlet Monastery Library",
                minLevel = 28,
                match = { "血色", "sm", "scarlet", "smlib", "lib" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "GNOMER",
                name = "Gnomeregan",
                minLevel = 29,
				match = { "矮子本", "gnomer", "gnomeregan" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "RFK",
                name = "Razorfen Kraul",
                minLevel = 29,
                match = { "剃刀", "rfk", "rfd", "razorfen" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "TCG",
                name = "The Crescent Grove",
                minLevel = 32,
                match = { "新月", "cg", "crescent" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "SMARMORY",
                name = "Scarlet Monastery Armory",
                minLevel = 32,
                match = { "血色", "sm", "scarlet", "smarms", "arms" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "STORM",
                name = "Ruins of Storm",
                minLevel = 35,
                match = { "风暴","风暴废墟","风暴之临","风暴城堡","巴洛", "storm", "barov" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },				
            {
                key = "SMCATH",
                name = "Scarlet Monastery Cathedral",
                minLevel = 35,
                match = { "血色","教堂", "sm", "cath", "smcath" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "RFD",
                name = "Razorfen Downs",
                minLevel = 36,
                match = { "剃刀", "rfk", "rfd", "razorfen" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "ULDA",
                name = "Uldaman",
                minLevel = 40,
                match = { "奥达曼", "ulda", "uldaman" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "GILNEAS",
                name = "Gilneas City",
                minLevel = 42,
				match = { "吉尔尼斯", "狼人", "gilneas" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "ZF",
                name = "Zul'Farrak",
                minLevel = 44,
                match = { "祖尔", "zul", "zf" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "MARA",
                name = "Maraudon",
                minLevel = 45,
                match = { "玛拉顿", "mara", "princess" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "ST",
                name = "Sunken Temple",
                minLevel = 50,
                match = { "神庙", "st", "sunken" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "HFQ",
                name = "Hateforge Quarry",
                minLevel = 50,
                match = { "采石场", "hfq", "hateforge" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "BRD",
                name = "Blackrock Depths",
                minLevel = 52,
				match = { "黑石深渊", "brd", "depths" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "UBRS",
                name = "Upper Blackrock Spire",
                minLevel = 55,
                members = 10,
                match = { "黑上", "ubrs" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "LBRS",
                name = "Lower Blackrock Spire",
                minLevel = 55,
                match = { "黑下", "lbrs" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22

            },
            {
                key = "DME",
                name = "Dire Maul East",
                minLevel = 55,
                match = { "厄运东", "dme" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "DMN",
                name = "Dire Maul North",
                minLevel = 57,
                match = { "厄运北", "dmn" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "DMW",
                name = "Dire Maul West",
                minLevel = 57,
                match = { "厄运西", "dmw" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "SCHOLO",
                name = "Scholomance",
                minLevel = 58,
                members = 10,
                match = { "通灵", "tl", "scholo" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "STRAT",
                name = "Stratholme",
                minLevel = 58,
                members = 10,
                match = { "斯坦索姆", "stsm", "strat" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "KC",
                name = "Karazhan Crypt",
                minLevel = 58,
                match = { "卡拉赞墓穴", "klz", "墓穴", "kc", "crypt" },
				nomatch = {"卡上", "卡下", "40人卡拉赞", "40人klz", "40klz", "klz40", "klz上层", "上层klz", "上层卡拉赞", "卡拉赞上层", "卡拉赞之塔", "k40"}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "COTBM",
                name = "Black Morass",
                minLevel = 60,
                match = { "时光", "沼泽", "bm", "morass" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "SWV",
                name = "Stormwind Vault",
                minLevel = 60,
				match = { "大监狱", "地牢", "swv", "vault" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
        }
    },
    {
        key = "RAID",
        name = "Raids",
        members = 40,
        children = {
            {
                key = "MC",
                name = "Molten Core",
                minLevel = 60,
                match = { "mc", "molten core" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "ONY",
                name = "Onyxia's Lair",
                minLevel = 60,
                match = { "黑龙", "ony", "onyxia" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "BWL",
                name = "Blackwing Lair",
                minLevel = 60,
                match = { "黑翼", "bwl", "blackwing" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "AQ40",
                name = "Temple of Ahn'Qiraj",
                minLevel = 60,
                match = { "安其拉", "taq", "aq40" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "NAXX",
                name = "Naxxramas",
                minLevel = 60,
                match = { "naxx", "naxxramas" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "ZUG",
                name = "Zul'Gurub",
                minLevel = 60,
                members = 20,
                match = { "祖格", "zug", "zg", "龙虎金", "zg" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "AQ20",
                name = "Ruins of Ahn'Qiraj",
                minLevel = 60,
                members = 20,
                match = { "废墟", "fx", "aq20" },
				nomatch = { "风暴废墟" }  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "TH",
                name = "Timbermaw Hold",
                minLevel = 60,
                members = 20,
                match = { "木喉", "要塞", "熊怪", "timbermaw", "th" },
				nomatch = { "风暴要塞" }  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "LKH",
                name = "Lower Karazhan Halls",
                minLevel = 60,
                members = 10,
                match = { "10人卡拉赞", "10人klz", "10klz", "klz10", "klz下层", "下层klz", "下层卡拉赞", "卡拉赞上层", "卡拉赞", "klz", "卡下", "lkh", "lower kara" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "ES",
                name = "Emerald Sanctum",
                minLevel = 60,
                match = { "翡翠", "es", "emerald" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
			{
				key = "TOK",              -- 唯一标识符（需唯一）
				name = "Tower of Karazhan",        -- 显示名称
				minLevel = 60,              -- 最低等级要求（根据实际设定调整）
				match = { "40人卡拉赞", "40人klz", "40klz", "klz40", "klz上层", "上层klz", "上层卡拉赞", "卡拉赞上层", "卡拉赞之塔", "k40", "卡上", "tok", "upper kara"  },	 -- 匹配关键词（用户搜索时会触发）
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
			}		
        }
    },
    {
        key = "QUEST",
        name = "Quests",
        members = 5,
        children = {
            {
                key = "PartyQuest",
                name = "Party Quests",
                members = 5,
				match = { "任务", "quest" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "RaidQuest",
                name = "Raid Quests",
                members = 40,
				match = { "任务", "quest" },		
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
			{
				key = "QuestLink",  -- 新增任务链接追踪
				name = "Quest Link",
				members = 5,
				match = { "quest:" },  -- 匹配任务链接特征
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
			},			
        }
    },
    {
        key = "BOSS",
        name = "World Bosses",
        members = 40,
        children = {
            {
                key = "Azuregos",
                name = "Azuregos",
                members = 40,
				match = { "蓝龙", "艾萨拉", "世界BOSS", "azuregos", "azshara", "wb" },		
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "Emeriss",
                name = "Emeriss",
                members = 40,
				match = { "绿龙", "菲拉斯", "辛特兰", "暮色森林", "灰谷", "世界BOSS", "green dragon", "wb" },	
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "Lethon",
                name = "Lethon",
                members = 40,
				match = { "绿龙", "菲拉斯", "辛特兰", "暮色森林", "灰谷", "世界BOSS", "green dragon", "wb" },		
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "Taerar",
                name = "Taerar",
                members = 40,
				match = { "绿龙", "菲拉斯", "辛特兰", "暮色森林", "灰谷", "世界BOSS", "green dragon", "wb" },	
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "Ysondre",
                name = "Ysondre",
                members = 40,
				match = { "绿龙", "菲拉斯", "辛特兰", "暮色森林", "灰谷", "世界BOSS", "green dragon", "wb" },	
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "Kazzak",
                name = "Lord Kazzak",
                members = 40,
				match = { "卡扎克", "诅咒之地", "世界BOSS", "kazzak", "wb" },			
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },	
            {
                key = "Nerubian",
                name = "Nerubian Overseer",
                members = 40,
				match = { "蛛魔监工", "东瘟疫", "世界BOSS", "nerubian", "wb" },	
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },	
            {
                key = "DarkReaver",
                name = "Dark Reaver of Karazhan",
                members = 40,
				match = { "黑暗掠夺者", "逆风小径", "世界BOSS", "dark reaver", "wb" },	
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "Ostarius",
                name = "Ostarius",
                members = 40,
				match = { "奥兹塔里亚斯", "奥丹姆", "塔纳利斯", "世界BOSS", "ostarius", "wb" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "Concavius",
                name = "Concavius",
                members = 40,
				match = { "空卡维斯", "虚空之子", "凄凉之地", "世界BOSS", "concavius", "wb" },	
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "Cow",
                name = "Cow King",
                members = 40,
				match = { "奶牛", "艾尔文森林", "世界BOSS", "cow", "wb" },	
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "Cla'ckora",
                name = "Cla'ckora",
                members = 40,
				match = { "克拉科拉", "鱼人", "艾萨拉", "世界BOSS", "clackora", "murloc", "wb" },	
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },			
        }
    },
    {
        key = "PVP",
        name = "PvP",
        children = {
            {
                key = "AV",
                name = "Alterac Valley",
                minLevel = 51,
                members = 40,
				match = { "奥特兰克", "奥山", "大战场", "av", "alterac" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "WSG",
                name = "Warsong Gulch",
                minLevel = 10,
                members = 10,
				match = { "战歌", "小战场", "wsg", "warsong" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "AB",
                name = "Arathi Basin",
                minLevel = 20,
                members = 15,
				match = { "阿拉希", "ALX", "ab", "arathi" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "BR",
                name = "Blood Ring",
                minLevel = 11,
                members = 3,
				match = { "血环", "竞技场", "blood ring", "arena" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
            {
                key = "PVP",
                name = "World PvP",
                minLevel = 1,
                members = 40,
				match = { "PVP", "pvp", "world pvp" },
				nomatch = {}  -- 新增排除关键词 by 武藤纯子酱 2025.9.22
            },
        }
    },
    {
        key = "OTHER",
        name = "Other",
        members = 40,
        children = {
            {
                key = "OTHER",
                name = "Other",
                minLevel = 1,
            },
        }
    },
    {
        key = "CHAT",
        name = "Channels",
        members = 40,
        hide = true,
        children = {
            {
                key = "WORLD",
                name = "World Channel",
                minLevel = 1,
            },
            {
                key = "CHINA",
                name = "Chinese Channel",
                minLevel = 1,
            },
            {
                key = "HARDCORE",
                name = "Hardcore Channel",
                minLevel = 1,
            },
        }
    }
}

local activityCategoryMap = {}

for _, value in ipairs(Meeting.Categories) do
    for _, child in ipairs(value.children) do
        activityCategoryMap[child.key] = { key = value.key, members = value.members }
    end
end

function Meeting.GetActivityCategory(code)
    return activityCategoryMap[code]
end

function Meeting.GetActivityMaxMembers(code)
    local info = Meeting.GetActivityInfo(code)
    if info and info.members then
        return info.members
    end

    local category = Meeting.GetActivityCategory(code)
    if category then
        return category.members
    end

    return 40
end

local activityInfoMap = {}

function Meeting.GetActivityInfo(code)
    if activityInfoMap[code] then
        return activityInfoMap[code]
    end
    for _, value in pairs(Meeting.Categories) do
        for _, value in pairs(value.children) do
            if value.key == code then
                activityInfoMap[code] = value
                return value
            end
        end
    end
    local other = Meeting.GetActivityInfo("OTHER")
    activityInfoMap[code] = other
    return other
end

function Meeting.GetPlayerScore()
    if ItemSocre and ItemSocre.ScanUnit then
        local score = ItemSocre:ScanUnit("player")
        if score and score > 0 then
            return score
        end
    end
    return 0
end

local Role = {
    Tank = bit.lshift(1, 1),
    Healer = bit.lshift(1, 2),
    Damage = bit.lshift(1, 3)
}
Meeting.Role = Role

local classRoleMap = {
    ["WARLOCK"] = Role.Damage,
    ["HUNTER"] = Role.Damage,
    ["PRIEST"] = bit.bor(Role.Healer, Role.Damage),
    ["PALADIN"] = bit.bor(Role.Tank, Role.Healer, Role.Damage),
    ["MAGE"] = Role.Damage,
    ["ROGUE"] = Role.Damage,
    ["DRUID"] = bit.bor(Role.Tank, Role.Healer, Role.Damage),
    ["SHAMAN"] = bit.bor(Role.Healer, Role.Damage),
    ["WARRIOR"] = bit.bor(Role.Tank, Role.Damage),
}

function Meeting.GetClassRole(class)
    return classRoleMap[class]
end

local fortyone = { "0",
    "1", "2", "3", "4", "5",
    "6", "7", "8", "9", "a",
    "b", "c", "d", "e", "f",
    "g", "h", "i", "j", "k",
    "l", "m", "n", "o", "p",
    "q", "r", "s", "t", "u",
    "v", "w", "x", "y", "z",
    "A", "B", "C", "D", "E" }
local fortyoneIndexes = {}
for index, value in ipairs(fortyone) do
    fortyoneIndexes[value] = index - 1
end

function Meeting.EncodeGroupClass()
    local raid = false
    local arr = {}
    for _, value in ipairs(classNameMap) do
        if value == Meeting.playerClass then
            arr[value] = 1
        else
            arr[value] = 0
        end
    end

	for i = 1, GetNumRaidMembers() do
		raid = true
		local _, class = UnitClass("raid" .. i)
		if class then
			arr[class] = (arr[class] or 0) + 1
		end
	end

	if not raid then
		for i = 1, GetNumPartyMembers() do
			local _, class = UnitClass("party" .. i)
			if class then
				arr[class] = (arr[class] or 0) + 1
			end
		end
	end

    local result = ""
    for _, v in ipairs(classNameMap) do
        local num = arr[v]
        result = result .. fortyone[num + 1]
    end
    return result
end

function Meeting.DecodeGroupClass(str)
    if not str then
        return
    end
    local arr = {}
    for i = 1, string.len(str) do
        local c = string.sub(str, i, i)
        local num = fortyoneIndexes[c]
        if num ~= nil and num > 0 then
            arr[i] = num
        end
    end
    return arr
end

local colorCache = {}

function Meeting.GetClassLocaleName(i)
    if colorCache[i] then
        return colorCache[i]
    end
    local color = Meeting.GetClassRGBColor(Meeting.NumberToClass(i))
    local str = string.format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, classChineseNameMap
        [i])
    colorCache[i] = str
    return str
end

-- 添加初始化 by 武藤纯子酱 2025.9.22
Meeting.searchInfo.codes = {}  -- 初始化多选状态