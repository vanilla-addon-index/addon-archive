--[[
	
	Atlas, a World of Warcraft instance map browser
	Email me at m4r3lk4@gmail.com
	
	This file is part of Atlas.
	
	Atlas is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.
	
	Atlas is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.
	
	You should have received a copy of the GNU General Public License
	along with Atlas; if not, write to the Free Software
	Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
	
--]]

-- Atlas Chinese Localization
-- Many thanks to all contributors!

--************************************************
-- 全局字符串
--************************************************
local AL = AceLibrary("AceLocale-2.2"):new("Atlas");
if ( GetLocale() ==	"zhCN" ) then
	AtlasSortIgnore = {"the (.+)"};

	BINDING_HEADER_ATLAS_TITLE = "Atlas 按键绑定";
	BINDING_NAME_ATLAS_TOGGLE = "切换 Atlas";
	BINDING_NAME_ATLAS_OPTIONS = "切换选项";
	BINDING_NAME_ATLAS_AUTOSEL = "自动选择";

	ATLAS_SUBTITLE = "副本地图浏览器";
	ATLAS_DESC = "Atlas 是一款副本地图浏览器。";

	ATLAS_STRING_LOCATION = "位置";
	ATLAS_STRING_LEVELRANGE = "等级范围";
	ATLAS_STRING_PLAYERLIMIT = "人数上限";
	ATLAS_STRING_SELECT_CAT = "选择分类";
	ATLAS_STRING_SELECT_MAP = "选择地图";
	ATLAS_STRING_SEARCH = "搜索";
	ATLAS_STRING_CLEAR = "清除";
	ATLAS_STRING_MINLEVEL = "最低等级";

	ATLAS_OPTIONS_BUTTON = "选项";
	ATLAS_OPTIONS_SHOWBUT = "在小地图显示按钮";
	ATLAS_OPTIONS_AUTOSEL = "自动选择副本地图";
	ATLAS_OPTIONS_BUTPOS = "按钮位置";
	ATLAS_OPTIONS_TRANS = "透明度";
	ATLAS_OPTIONS_DONE = "完成";
	ATLAS_OPTIONS_RCLICK = "右键点击打开世界地图";
	ATLAS_OPTIONS_SHOWMAPNAME = "显示地图名称";
	ATLAS_OPTIONS_RESETPOS = "重置位置";
	ATLAS_OPTIONS_ACRONYMS = "显示缩写";
	ATLAS_OPTIONS_SCALE = "缩放比例";
	ATLAS_OPTIONS_BUTRAD = "按钮半径";
	ATLAS_OPTIONS_CLAMPED = "窗口限制在屏幕内";
	ATLAS_OPTIONS_HELP = "左键点击并拖动可移动此窗口。";

	ATLAS_BUTTON_TOOLTIP_TITLE = "Atlas";
	ATLAS_BUTTON_TOOLTIP_HINT = "左键点击打开 Atlas。\n中键点击打开 Atlas 选项。\n右键点击并拖动可移动此按钮。";
	ATLAS_TITAN_HINT = "左键点击打开 Atlas。\n中键点击打开 Atlas 选项。\n右键点击打开显示菜单。";

	ATLAS_OPTIONS_CATDD = "副本地图排序方式：";
	ATLAS_DDL_CONTINENT = "大陆";
	ATLAS_DDL_CONTINENT_EASTERN = "东部王国副本";
	ATLAS_DDL_CONTINENT_KALIMDOR = "卡利姆多副本";
	ATLAS_DDL_LEVEL = "等级";
	ATLAS_DDL_PARTYSIZE = "队伍规模";
	ATLAS_DDL_PARTYSIZE_5 = "5人副本";
	ATLAS_DDL_PARTYSIZE_10 = "10人副本";
	ATLAS_DDL_PARTYSIZE_20 = "20人副本";
	ATLAS_DDL_PARTYSIZE_40 = "40人副本";
	ATLAS_DDL_ALL = "全部";
	ATLAS_DDL_ALL_MENU = "显示所有副本";
	ATLAS_DDL_TYPE = "类型";
	ATLAS_DDL_TYPE_DUNGEONS = "地下城";
	ATLAS_DDL_TYPE_RAIDS = "团队副本";
	ATLAS_DDL_WORLDBOSSES = "世界首领";
	ATLAS_DDL_TYPE_ENTRANCE = "入口";
	ATLAS_DDL_BGS = "战场";
	ATLAS_DDL_DUNGEON_LOCATIONS = "副本位置";
	ATLAS_DDL_FLIGHT_PATHS = "飞行航线";
	ATLAS_DDL_TRANSPORT_ROUTES = "运船航线";
	ATLAS_INSTANCE_BUTTON = "副本";
	ATLAS_ENTRANCE_BUTTON = "入口";
	ATLAS_SEARCH_UNAVAIL = "搜索不可用";

	AtlasZoneSubstitutions = {
		["The Temple of Atal'Hakkar"] = "沉没的神庙";
	};
end

AL:RegisterTranslations("zhCN", function() return {
	
	--************************************************
	-- 区域名, 缩写词, 通用字符串
	--************************************************
	["Transport Routes"] = "交通路线";
	["Azeroth"] = "艾泽拉斯";
	["Sparkwater Port"] = "怒水港";
	--通用字符串
	["Atlas Options"] = "Atlas 选项";
	--颜色
	["Blue"] = "蓝色";
	["Purple"] = "紫色";
	["Red"] = "红色";
	["Orange"] = "橙色";
	["White"] = "白色";
	--生物类型
	["Boss"] = "首领";
	["Rare"] = "稀有";
	["Bat"] = "蝙蝠";
	["Snake"] = "蛇";
	["Raptor"] = "迅猛龙";
	["Spider"] = "蜘蛛";
	["Tiger"] = "丛林虎";
	["Panther"] = "黑豹";
	["Pet"] = "宠物";
	["Engineer"] = "工程师";
	--法术类型
	["Fire"] = "火焰";
	["Nature"] = "自然";
	["Frost"] = "冰霜";
	["Shadow"] = "暗影";
	["Arcane"] = "奥术";
	--活动
	["Hallow's End"] = "万圣节";
	["Scourge Invasion"] = "天灾入侵";		
	["Lunar Festival"] = "春节";
	--其他
	["East"] = "东";
	["North"] = "北";
	["South"] = "南";
	["West"] = "西";		
	["Battlegrounds"] = "战场";		
	["Lower"] = "下层";	
	["Upper"] = "上层";		
	["Entrance"] = "入口";
	["Exit"] = "出口";		
	["Chase Begins"] = "追逐开始";
	["Chase Ends"] = "追逐结束";		
	["AKA"] = "又名";	
	["Attunement Required"] = "需要开门任务";
	["Back"] = "背部";
	["Back1"] = "后退";
	["Blacksmithing Plans"] = "锻造设计图";	
	["Brazier of Invocation"] = "符咒火盆";
	["Connection"] = "连接";
	["Connections"] = "连接点";
	["Damage: "] = "伤害: ";
	["Tier 0.5 Summon"] = "T0.5 召唤";
	["Dungeon Locations"] = "地下城位置";
	["Elevator"] = "升降机";
	["Front"] = "前部";
	["Front1"] = "前部1";
	["Ghost"] = "鬼魂";		
	["Heroic"] = "英雄难度";
	["Instances"] = "副本";
	["Key"] = "钥匙";
	["Meeting Stone"] = "集合石";
	["Moonwell"] = "月亮井";
	["Neutral"] = "中立"; -- NPC 反应
	["Optional"] = "可选";
	["Outside"] = "外面";
	["Portal"] = "传送门";
	["Random"] = "随机";
	["Reputation"] = "声望";
	["Rescued"] = "已营救";
	["Side"] = "侧面";
	["Summon"] = "召唤";
	["Teleport"] = "传送";
	["through "] = "穿过";
	["Trash Mobs"] = "小怪";
	["Unknown"] = "未知";
	["Varies"] = "变化";
	["Various"] = "各种各样";
	["Wanders"] = "游荡";
	
	--特殊副本名称
	["Armory"] = "军械库";
	["Cathedral"] = "大教堂";
	["Graveyard"] = "墓地";
	["Library"] = "图书馆";
	["Sunken Temple"] = "沉没的神庙";
	
	--套装名
	["Set: "] = "套装: ";
	["Tier 0/0.5 Sets"] = "T0/T0.5 套装";
	["Zul'Gurub Sets"] = "祖尔格拉布套装";
	["Zul'Gurub Ring Sets"] = "祖尔格拉布戒指套装";
	["Ruins of Ahn'Qiraj Sets"] = "安其拉废墟套装";
	["Temple of Ahn'Qiraj Sets"] = "安其拉神庙套装";
	["Tier 1 Sets"] = "T1 套装";
	["Tier 2 Sets"] = "T2 套装";
	["Tier 3 Sets"] = "T3 套装";
	
	--************************************************
	-- 卡利姆多副本数据
	--************************************************
	
	--哀嚎洞穴
	["Mysterious Wailing Caverns Chest"] = "神秘的哀嚎洞穴宝箱";
	
	--黑暗深渊
	["Lorgalis Manuscript"] = "洛迦里斯手稿";
	["Argent Guard Thaelrid"] = "银月守卫塞尔瑞德";
	["Shrine of Gelihast"] = "格里哈斯特神殿";
	["Fathom Stone"] = "深渊之石";
	["Morridune"] = "莫瑞杜恩";
	["Altar of the Deeps"] = "玛塞斯特拉祭坛";

	--新月林地
	["Kalanar's Strongbox"] = "卡拉纳尔的保险箱"; -- TurtleWOW

	--剃刀沼泽
	["Razorfen Spearhide"] = "剃刀沼泽刺鬃守卫";
	["Willix the Importer"] = "进口商威利克斯";
	["Heralath Fallowbrook"] = "赫尔拉斯·静水";
	
	--剃刀高地
	["Henry Stern"] = "亨利·斯特恩";
	["Belnistrasz"] = "奔尼斯特拉兹";
	["Sah'rhee"] = "萨哈斯";
	
	--祖尔法拉克
	["Mallet of Zul'Farrak"] = "祖尔法拉克之槌";
	["Theka the Martyr"] = "殉教者塞卡";
	["Zul'Farrak Dead Hero"] = "祖尔法拉克阵亡英雄";
	["Nekrum Gutchewer"] = "耐克鲁姆";
	["Dustwraith"] = "灰尘怨灵";
	["Sergeant Bly"] = "布莱中士";
	["Weegli Blastfuse"] = "维格利·爆管";
	["Murta Grimgut"] = "穆尔塔·酷肠";
	["Raven"] = "渡鸦";
	["Oro Eyegouge"] = "欧罗·血眼";
	["Sandfury Executioner"] = "沙怒刽子手";
	["Hydromancer Velratha"] = "水占师维蕾萨";
	["Elder Wildmane"] = "蛮鬃长者";
	["Zerillis"] = "泽雷利斯";
	["Sandarr Dunereaver"] = "杉达尔·沙掠者";
	
	--玛拉顿
	["Scepter of Celebras"] = "塞雷布拉斯节杖";
	["Veng"] = "温格";
	["Maraudos"] = "玛拉多斯";
	["Elder Splitrock"] = "裂石长者";
	
	--厄运之槌(东)
	["Old Ironbark"] = "老铁皮";
	["A Dusty Tome"] = "布满灰尘的书籍";
	["Felvine Shard"] = "魔藤碎片";
	["Dire Maul Books"] = "厄运之槌书籍";
	
	--厄运之槌(北)
	["Crescent Key"] = "月牙钥匙";--从厄运之槌（西）省略
	["Gordok Courtyard Key"] = "戈多克庭院钥匙";
	["Gordok Inner Door Key"] = "戈多克内门钥匙";
	--由于血色修道院的“图书馆”重复，此处和厄运之槌（西）省略“图书馆”
	["Knot Thimblejack"] = "诺特·希姆加克";
	["Tribute Run"] = "贡品流程";
	
	--厄运之槌(西)
	["J'eevee's Jar"] = "耶维尔的瓶子";
	["Pylons"] = "水晶塔";
	["Shen'dralar Ancient"] = "辛德拉古灵";
	["Ancient Equine Spirit"] = "上古圣马之魂";
	["Ferra"] = "费拉";
	["Falrin Treeshaper"] = "法琳·树形者";
	["Lorekeeper Lydros"] = "博学者莱德罗斯";
	["Lorekeeper Javon"] = "博学者亚沃";
	["Lorekeeper Kildrath"] = "博学者基尔达斯";
	["Lorekeeper Mykos"] = "博学者麦库斯";
	["Shen'dralar Provisioner"] = "辛德拉圣职者";
	["Skeletal Remains of Kariel Winthalus"] = "卡里尔·温萨鲁斯的骸骨";
	["The Prince's Chest"] = "王子的箱子";
	
	--奥妮克希亚的巢穴
	["Drakefire Amulet"] = "龙火护符";
	["Onyxian Warders"] = "奥妮克希亚守卫";
	["Whelp Eggs"] = "幼龙蛋";
	
	--安其拉神殿
	["Bug Trio"] = "虫子三兄弟";
	["Andorgos"] = "安多葛斯";
	["Vethsera"] = "温瑟拉";
	["Kandrostrasz"] = "坎多斯特拉兹";
	["Arygos"] = "亚雷戈斯";
	["Caelestrasz"] = "凯雷斯特拉兹";
	["Merithra of the Dream"] = "梦境之龙麦琳瑟拉";
	["AQ Enchants"] = "安其拉附魔";
	["AQ Opening Quest Chain"] = "安其拉开门任务链";
	
	--安其拉废墟
	["Four Kaldorei Elites"] = "四位卡多雷精英";
	["Captain Qeez"] = "奎兹上尉";
	["Captain Tuubid"] = "图毕德上尉";
	["Captain Drenn"] = "德雷恩上尉";
	["Captain Xurrem"] = "瑟瑞姆上尉";
	["Major Yeggeth"] = "叶吉斯少校";
	["Major Pakkon"] = "帕库少校";
	["Colonel Zerran"] = "泽朗上校";
	["Safe Room"] = "安全屋";
	["Class Books"] = "职业书籍";

	--翡翠圣殿 -- TurtleWOW 1.17.0
	["Gemstone of Ysera"] = "伊瑟拉宝钻";
	["Favor of Erennius (ES Hard Mode)"] = "埃伦纽斯的青睐（翡翠圣殿困难模式）";

	--****************************
	-- 东部王国副本
	--****************************
	
	

	--黑石深渊
	["Shadowforge Key"] = "暗炉钥匙";
	["Prison Cell Key"] = "监狱牢房钥匙";
	["Jail Break!"] = "越狱！";
	["Banner of Provocation"] = "挑战之旗";
	["Kharan Mighthammer"] = "卡兰·巨锤";
	["Commander Gor'shak"] = "指挥官哥沙克";
	["Marshal Windsor"] = "温德索尔元帅";
	["Ring of Law"] = "律法之环";
	["Theldren"] = "瑟尔伦";
	["Lefty"] = "左撇";
	["Malgen Longspear"] = "玛根·长矛";
	["Gnashjaw"] = "碎腭";
	["Korv"] = "考尔夫";
	["Rezznik"] = "雷兹尼克";
	["Rotfang"] = "烂牙";
	["Snokh Blackspine"] = "斯诺恩·黑骨";
	["Va'jashni"] = "瓦加什尼";
	["Volida"] = "沃莉达";
	["Elder Morndeep"] = "晨深长者";
	["High Justice Grimstone"] = "裁决者格里斯通";
	["Monument of Franclorn Forgewright"] = "弗兰克罗恩·铸铁的雕像";
	["The Vault"] = "平民区";
	["The Black Anvil"] = "黑铁砧";
	["Shadowforge Lock"] = "暗炉锁";
	["Field Repair Bot 74A"] = "修理机器人74A型";
	["The Grim Guzzler"] = "冷酷酒鬼酒吧";
	["Lokhtos Darkbargainer"] = "罗克图斯·暗契";
	["Mistress Nagmara"] = "娜玛拉小姐";
	["Private Rocknot"] = "罗克诺特下士";
	["Summoner's Tomb"] = "召唤者之墓";
	["Chest of The Seven"] = "七贤之箱";
	["The Lyceum"] = "讲学厅";
	["High Priestess of Thaurissan"] = "索瑞森高阶女祭司";
	["The Black Forge"] = "黑铁熔炉";
	["Core Fragment"] = "熔火碎片";

	--黑石塔(下层)
	["Vaelan"] = "维埃兰";
	["Warosh"] = "瓦罗什";
	["Elder Stonefort"] = "石垒长者";
	["Roughshod Pike"] = "尖锐长矛";
	["Spirestone Butcher"] = "尖石屠夫";
	["Spirestone Battle Lord"] = "尖石统帅";
	["Spirestone Lord Magus"] = "尖石首席法师";
	["Fifth Mosh'aru Tablet"] = "第五块摩沙鲁石板";
	["Bijou"] = "比修";
	["Sixth Mosh'aru Tablet"] = "第六块摩沙鲁石板";
	["Bijou's Belongings"] = "比修的装置";
	["Human Remains"] = "人类遗骸";
	["Unfired Plate Gauntlets"] = "未淬火的板甲护手";
	["Urok's Tribute Pile"] = "乌洛克的贡品堆";
	["Burning Felguard"] = "燃烧恶魔守卫";
	
	--黑石塔(上层)
	["Seal of Ascension"] = "晋升印章";
	["Father Flame"] = "烈焰之父";
	["Darkstone Tablet"] = "黑暗石板";
	["Doomrigger's Coffer"] = "末日扣环之箱";
	["Awbee"] = "奥比";
	["Finkle Einhorn"] = "芬克·恩霍尔";
	["Drakkisath's Brand"] = "达基萨斯的烙印";
	
	--黑翼之巢
	["Draconic for Dummies"] = "龙语傻瓜教程";
	["Master Elemental Shaper Krixix"] = "大元素师克里希克";
	["Alchemy Lab"] = "炼金实验室";
	
	--诺莫瑞根
	["Workshop Key"] = "车间钥匙";
	["Blastmaster Emi Shortfuse"] = "爆破专家艾米·短线";
	["Clean Room"] = "洁净室";
	["Tink Sprocketwhistle"] = "丁克·铁哨";
	["The Sparklematic 5200"] = "超级清洁器5200型";
	["Mail Box"] = "邮箱";
	["Kernobee"] = "克努比";
	["Alarm-a-bomb 2600"] = "警报炸弹2600型";
	["Matrix Punchograph 3005-B"] = "矩阵式打孔计算机3005-B";
	["Matrix Punchograph 3005-C"] = "矩阵式打孔计算机3005-C";
	["Matrix Punchograph 3005-D"] = "矩阵式打孔计算机3005-D";
	
	--熔火之心
	["Aqual Quintessence"] = "水之精萃";
	["Eternal Quintessence"] = "永恒精萃";
	["Random Boss Loot"] = "随机首领掉落";
	
	--纳克萨玛斯
	["Archmage Tarsis Kir-Moldir"] = "大法师塔希斯·克摩地尔";
	["Mr. Bigglesworth"] = "比格沃斯先生";
	["Abomination Wing"] = "憎恶区";
	["Spider Wing"] = "蜘蛛区";
	["Deathknight Wing"] = "死亡骑士区";
	["Four Horsemen Chest"] = "四骑士的宝箱";
	["Plague Wing"] = "瘟疫区";
	["Frostwyrm Lair"] = "冰霜巨龙巢穴";
	
	--血色修道院-图书馆
	["Doan's Strongbox"] = "杜安的保险箱";
	
	--血色修道院-军械库
	["The Scarlet Key"] = "血色十字军钥匙";--从血色修道院：大教堂省略
	
	--血色修道院-大教堂
	["Vorrel Sengutz"] = "沃瑞尔·森加斯";
	
	--通灵学院
	["Skeleton Key"] = "骷髅钥匙";
	["Viewing Room Key"] = "观察室钥匙";
	["Viewing Room"] = "观察室";
	["Blood of Innocents"] = "无辜者之血";
	["Divination Scryer"] = "预言水晶球";
	["Blood Steward of Kirtonos"] = "基尔图诺斯的卫士";
	["The Deed to Southshore"] = "南海镇地契";
	["Journal of Jandice Barov"] = "詹迪斯·巴罗夫的日记";
	["The Deed to Tarren Mill"] = "塔伦米尔地契";
	["The Deed to Brill"] = "布瑞尔地契";
	["The Deed to Caer Darrow"] = "凯尔达隆地契";
	["Torch Lever"] = "火炬拉杆";
	["Old Treasure Chest"] = "旧宝藏箱";
	
	--影牙城堡
	["Deathstalker Adamant"] = "亡灵哨兵阿达曼特";
	["Landen Stilwell"] = "兰登·斯蒂威尔";
	["Deathstalker Vincent"] = "亡灵哨兵文森特";
	["Fel Steed"] = "地狱战马";
	["Jordan's Hammer"] = "乔丹的铁锤";
	["Crate of Ingots"] = "金属锭箱";
	["Arugal's Voidwalker"] = "阿鲁高的虚空行者";
	["The Book of Ur"] = "乌尔之书";
	
	--斯坦索姆
	["Key to the City"] = "城市大门钥匙";
	["Various Postbox Keys"] = "各种邮筒钥匙";
	["Living Side"] = "生者区域";
	["Undead Side"] = "亡灵区域";
	["Fras Siabi"] = "弗拉斯·希亚比";
	["Elder Farwhisper"] = "遥语长者";
	["Malor's Strongbox"] = "玛洛尔的保险箱";
	["Crimson Hammersmith"] = "红衣铸锤师";
	["Grand Crusader Dathrohan"] = "大十字军战士达索汉";
	["Aurius"] = "奥里克斯";
	["Black Guard Swordsmith"] = "黑衣守卫铸剑师";
	["Ysida Harmon"] = "伊思达·哈尔蒙";
	["Crusaders' Square Postbox"] = "十字军广场邮箱";
	["Market Row Postbox"] = "市场邮箱";
	["Festival Lane Postbox"] = "节日小道邮箱";
	["Elders' Square Postbox"] = "长者广场邮箱";
	["King's Square Postbox"] = "国王广场邮箱";
	["Fras Siabi's Postbox"] = "弗拉斯·希亚比的邮箱";
	["Third Postbox Opened"] = "第三个邮筒已打开";
	
	--死亡矿井
	["Sneed's Shredder"] = "斯尼德的伐木机";
	["Defias Gunpowder"] = "迪菲亚火药";
	
	--沉没的神庙
	["Yeh'kinya's Scroll"] = "叶基亚的卷轴";
	["Balcony Minibosses"] = "阳台小首领";
	["Altar of Hakkar"] = "哈卡祭坛";
	["Essence Font"] = "精华之泉";
	["Spawn of Hakkar"] = "哈卡的后代";
	["Elder Starsong"] = "星歌长者";
	["Statue Activation Order"] = "雕像激活顺序";
	["Malfurion Stormrage"] = "玛法里恩·怒风";
	
	--奥达曼
	["Staff of Prehistoria"] = "史前法杖";
	["Baelog's Chest"] = "巴尔洛戈的箱子";
	["Conspicuous Urn"] = "显眼的石罐";
	["Remains of a Paladin"] = "圣骑士的遗体";
	["Annora"] = "安诺拉";
	["Tablet of Will"] = "意志之匾";
	["Shadowforge Cache"] = "暗影熔炉地窖";
	["The Discs of Norgannon"] = "诺甘农圆盘";
	["Ancient Treasure"] = "古代宝藏";
	
	--祖尔格拉布
	["Mudskunk Lure"] = "臭泥鱼诱饵";
	["Gurubashi Mojo Madness"] = "古拉巴什疯狂魔精";
	["Zanza the Restless"] = "无法安息的赞札";
	["Ohgan"] = "奥根";
	["Edge of Madness"] = "疯狂之缘";
	["Zealot Zath"] = "狂热者札斯";
	["Zealot Lor'Khan"] = "狂热者洛卡恩";
	["Muddy Churning Waters"] = "混浊的水";
	["Jinxed Hoodoo Pile"] = "厄运巫毒堆";
	["ZG Enchants"] = "祖尔格拉布附魔";	

	--卡拉赞大厅 --TurtleWOW 1.17.0
	["LKH Enchants"] = "下层卡拉赞大厅附魔";	
	
	--************************************************
	-- 东部王国副本地图
	--************************************************
	
	--黑石山 (入口)
	["Bodley"] = "布德利";
	["Overmaster Pyron"] = "征服者派隆";
	["Lothos Riftwaker"] = "洛索斯·天痕";
	["Franclorn Forgewright"] = "弗兰克罗恩·铸铁";
	["Orb of Command"] = "命令宝珠";
	["Scarshield Quartermaster"] = "裂盾军需官";
	
	--诺莫瑞根 (入口)
	["Transpolyporter"] = "传送器";
	["Sprok"] = "斯普洛克";
	["Matrix Punchograph 3005-A"] = "矩阵式打孔计算机3005-A";
	["Namdo Bizzfizzle"] = "纳姆杜·比兹菲兹";
	["Techbot"] = "尖端机器人";
	
	--玛拉顿 (入口)
	["The Nameless Prophet"] = "无名预言者";
	["Kolk"] = "考尔克";
	["Gelk"] = "吉尔克";
	["Magra"] = "玛格拉";
	["Cavindra"] = "凯雯德拉";
	["Cursed Centaur"] = "被诅咒的半人马";
	
	--死亡矿井 (入口)
	["Marisa du'Paige"] = "玛里莎·杜派格";
	["Brainwashed Noble"] = "被洗脑的贵族";
	["Foreman Thistlenettle"] = "工头希斯耐特";
	
	--沉没的神庙 (入口)
	["Jade"] = "玉龙";
	["Kazkaz the Unholy"] = "邪恶的卡萨卡兹";
	["Zekkis"] = "泽基斯";
	["Veyzhak the Cannibal"] = "食尸者维萨克";
	
	--奥达曼 (入口)
	["Hammertoe Grez"] = "铁趾格雷兹";
	["Magregan Deepshadow"] = "马格雷甘·深影";
	["Tablet of Ryun'Eh"] = "莱恩之匾";
	["Krom Stoutarm's Chest"] = "克罗姆·粗臂的箱子";
	["Garrett Family Chest"] = "加勒特的宝箱";
	["Digmaster Shovelphlange"] = "挖掘专家舒尔弗拉格";
	
	--哀嚎洞穴 (入口)
	["Mad Magglish"] = "疯狂的马格利什";
	["Trigore the Lasher"] = "鞭笞者特里高雷";
	["Boahn"] = "博艾恩";
	["Above the Entrance:"] = "入口上方：";
	["Ebru"] = "厄布鲁";
	["Nalpak"] = "纳尔帕克";
	["Kalldan Felmoon"] = "卡尔丹·暗月";
	["Waldor"] = "瓦多尔";
	
	--厄运之槌 (入口)
	["Dire Pool"] = "厄运之池";
	["Dire Maul Arena"] = "厄运之槌竞技场";
	["Mushgog"] = "姆斯高格";
	["Skarr the Unbreakable"] = "无敌的斯卡尔";
	["The Razza"] = "拉里尔";
	["Elder Mistwalker"] = "迷雾长者";
	["Griniblix the Spectator"] = "目击者格林比克斯";
	
	--世界首领
	["Emerald Dragons"] = "翡翠巨龙";
	["Spirit of Azuregos"] = "艾索雷葛斯之魂";
	["Emerald Dragons Trash"] = "翡翠巨龙小怪";
	
	--Places
	["Friendly Reputation Rewards"] = "友善声望奖励";
	["Honored Reputation Rewards"] = "尊敬声望奖励";
	["Revered Reputation Rewards"] = "崇敬声望奖励";
	["Exalted Reputation Rewards"] = "崇拜声望奖励";
	
	--奥特兰克山谷 (北)
	["Stormpike Guard"] = "雷矛卫队";
	["Dun Baldar"] = "丹巴达尔";
	["Vanndar Stormpike"] = "范达尔·雷矛";
	["Dun Baldar North Marshal"] = "丹巴达尔北部元帅";
	["Dun Baldar South Marshal"] = "丹巴达尔南部元帅";
	["Icewing Marshal"] = "冰翼元帅";
	["Iceblood Marshal"] = "冰血元帅";
	["Stonehearth Marshal"] = "石炉元帅";
	["East Frostwolf Marshal"] = "霜狼东部统帅";
	["West Frostwolf Marshal"] = "西部霜狼元帅";
	["Tower Point Marshal"] = "哨塔高地元帅";
	["Prospector Stonehewer"] = "勘察员塔雷·石镐";
	["Irondeep Mine"] = "深铁矿洞";
	["Morloch"] = "莫洛克";
	["Umi Thorson"] = "乌米·托尔森";
	["Keetar"] = "基塔尔";
	["Arch Druid Renferal"] = "大德鲁伊雷弗拉尔";
	["Dun Baldar North Bunker"] = "丹巴达尔北部碉堡";
	["Wing Commander Mulverick"] = "空军指挥官穆维里克";--从AVS省略
	["Murgot Deepforge"] = "莫高特·深炉";
	["Dirk Swindle"] = "德尔克·斯温德尔";
	["Athramanis"] = "亚斯拉玛尼斯";
	["Lana Thunderbrew"] = "兰纳·雷酒";
	["Stormpike Aid Station"] = "雷矛急救站";
	["Stormpike Stable Master"] = "雷矛兽栏管理员";
	["Stormpike Ram Rider Commander"] = "雷矛山羊骑兵指挥官";
	["Svalbrad Farmountain"] = "斯瓦尔布莱德·远山";
	["Kurdrum Barleybeard"] = "库德拉姆·麦须";
	["Stormpike Quartermaster"] = "雷矛军需官";
	["Jonivera Farmountain"] = "约尼维拉·远山";
	["Brogus Thunderbrew"] = "布罗古斯·雷酒";
	["Wing Commander Ichman"] = "空军指挥官艾克曼";--从AVS省略
	["Wing Commander Slidore"] = "空军指挥官斯里多尔";--从AVS省略
	["Wing Commander Vipore"] = "空军指挥官维波里";--从AVS省略
	["Dun Baldar South Bunker"] = "丹巴达尔南部碉堡";
	["Corporal Noreg Stormpike"] = "诺雷格·雷矛中尉";
	["Gaelden Hammersmith"] = "盖尔丁";
	["Stormpike Graveyard"] = "雷矛墓地";
	["Icewing Cavern"] = "冰翼洞穴";
	["Stormpike Banner"] = "雷矛军旗";
	["Stormpike Lumber Yard"] = "雷矛伐木场";
	["Wing Commander Jeztor"] = "空军指挥官杰斯托";--从AVS省略
	["Icewing Bunker"] = "冰翼碉堡";
	["Wing Commander Guse"] = "空军指挥官古斯";--从AVS省略
	["Stonehearth Graveyard"] = "石炉墓地";
	["Stonehearth Outpost"] = "石炉哨站";
	["Captain Balinda Stonehearth"] = "巴琳达·斯通赫尔斯";
	["Snowfall Graveyard"] = "落雪墓地";
	["Korrak the Bloodrager"] = "血怒者科尔拉克";
	["Ichman's Beacon"] = "艾克曼的信号灯";
	["Mulverick's Beacon"] = "穆维里克的信号灯法术焦点";
	["Stonehearth Bunker"] = "石炉碉堡";
	["Ivus the Forest Lord"] = "森林之王伊弗斯";
	["Western Crater"] = "西部凹地";
	["Vipore's Beacon"] = "维波里的信号灯";
	["Jeztor's Beacon"] = "杰斯托的信号灯";
	["Eastern Crater"] = "东部凹地";
	["Slidore's Beacon"] = "斯里多尔的信号灯";
	["Guse's Beacon"] = "古斯的信号灯";
	["Graveyards, Capturable Areas"] = "墓地，可占领区域";--从AVS省略
	["Bunkers, Towers, Destroyable Areas"] = "碉堡，塔楼，可摧毁区域";--从AVS省略
	["Assault NPCs, Quest Areas"] = "突袭NPC，任务区域";--从AVS省略
	["Steamsaw"] = "蒸汽锯";--从AVS省略
	
	--奥特兰克山谷 (南)
	["Frostwolf Clan"] = "霜狼氏族";
	["Frostwolf Keep"] = "霜狼要塞";
	["Drek'Thar"] = "德雷克塔尔";
	["Duros"] = "杜洛斯";
	["Drakan"] = "德拉坎";
	["West Frostwolf Warmaster"] = "西部霜狼将领";
	["East Frostwolf Warmaster"] = "东部霜狼将领";
	["Tower Point Warmaster"] = "哨塔高地将领";
	["Iceblood Warmaster"] = "冰血将领";
	["Icewing Warmaster"] = "冰翼将领";
	["Stonehearth Warmaster"] = "石炉将领";
	["Dun Baldar North Warmaster"] = "丹巴达尔北部将领";
	["Dun Baldar South Warmaster"] = "丹巴达尔南部将领";
	["Lokholar the Ice Lord"] = "冰雪之王洛克霍拉";
	["Iceblood Garrison"] = "冰血要塞";
	["Captain Galvangar"] = "加尔范上尉";
	["Iceblood Tower"] = "冰血塔楼";
	["Iceblood Graveyard"] = "冰血墓地";
	["Tower Point"] = "哨塔高地";
	["Coldtooth Mine"] = "冷齿矿洞";
	["Taskmaster Snivvle"] = "工头斯尼维尔";
	["Masha Swiftcut"] = "玛莎·迅切";
	["Aggi Rumblestomp"] = "埃其·重脚";
	["Frostwolf Graveyard"] = "霜狼墓地";
	["Jotek"] = "乔泰克";
	["Smith Regzar"] = "铁匠雷格萨";
	["Primalist Thurloga"] = "指挥官瑟鲁加";
	["Sergeant Yazra Bloodsnarl"] = "亚斯拉·血矛中士";
	["Frostwolf Stable Master"] = "霜狼兽栏管理员";
	["Frostwolf Wolf Rider Commander"] = "霜狼骑兵指挥官";
	["Frostwolf Quartermaster"] = "霜狼军需官";
	["West Frostwolf Tower"] = "西部霜狼塔楼";
	["East Frostwolf Tower"] = "东部霜狼塔楼";
	["Frostwolf Relief Hut"] = "霜狼急救站";
	["Wildpaw Cavern"] = "蛮爪洞穴";
	["Frostwolf Banner"] = "霜狼军旗";
	
	--阿拉希盆地
	["The Defilers"] = "污染者";
	["The League of Arathor"] = "阿拉索联军";
	["Trollbane Hall"] = "托尔贝恩大厅";
	["Defiler's Den"] = "污染者之穴";
	["Stables"] = "兽栏";
	["Gold Mine"] = "金矿";
	["Blacksmith"] = "铁匠铺";
	["Lumber Mill"] = "伐木场";
	["Farm"] = "农场";
	
	--战歌峡谷
	["Warsong Outriders"] = "战歌侦察兵";
	["Silverwing Sentinels"] = "银翼哨兵";
	["Silverwing Hold"] = "银翼要塞";
	["Warsong Lumber Mill"] = "战歌伐木场";
	
	--飞行点
	["Flight Path Maps"] = "飞行路线图";
	["Druid-only"] = "仅德鲁伊";
	["Aerie Peak"] = "鹰巢山";
	["Astranaar"] = "阿斯特兰纳";
	["Bloodvenom Post"] = "血毒岗哨";
	["Brackenwall Village"] = "蕨墙村";
	["Camp Mojache"] = "莫沙彻营地";
	["Camp Taurajo"] = "陶拉祖营地";
	["Cenarion Hold"] = "塞纳里奥要塞";
	["Chillwind Point"] = "冰风岗";
	["Crossroads"] = "十字路口";
	["Darkshire"] = "夜色镇";
	["Feathermoon Stronghold"] = "羽月要塞";
	["Flame Crest"] = "烈焰峰";
	["Freewind Post"] = "乱风岗";
	["Grom'Gol Base Camp"] = "格罗姆高营地";
	["Hammerfall"] = "落锤镇";
	["Kargath"] = "卡加斯";
	["Lakeshire"] = "湖畔镇";
	["Light's Hope Chapel"] = "圣光之愿礼拜堂";
	["Marshal's Refuge"] = "马绍尔营地";
	["Morgan's Vigil"] = "摩根的岗哨";
	["Nethergarde Keep"] = "守望堡";
	["Nighthaven"] = "永夜港";
	["Nijel's Point"] = "尼耶尔前哨站";
	["Refuge Pointe"] = "避难谷地";
	["Revantusk Village"] = "恶齿村";
	["Rut'Theran Village"] = "鲁瑟兰村";
	["Sentinel Hill"] = "哨兵岭";
	["Shadowprey Village"] = "葬影村";
	["Southshore"] = "南海镇";
	["Splintertree Post"] = "碎木岗哨";
	["Stonard"] = "斯通纳德";
	["Stonetalon Peak"] = "石爪峰";
	["Sun Rock Retreat"] = "烈日石居";
	["Talonbranch Glade"] = "刺枝林地";
	["Talrendis Point"] = "塔伦迪斯营地";
	["Tarren Mill"] = "塔伦米尔";
	["Thalanaar"] = "萨兰纳尔";
	["The Sepulcher"] = "瑟伯切尔";
	["The Shimmering Flats"] = "闪光平原";
	["Thelsamar"] = "塞尔萨玛";
	["Thorium Point"] = "瑟银哨塔";
	["Valormok"] = "瓦罗莫克";
	["Zoram'gar Outpost"] = "佐拉姆加前哨站";
	["South of the path along Lake Elune'ara"] = "艾露恩湖沿岸道路以南";
	["West of the path to Timbermaw Hold"] = "通往木喉要塞的道路以西";
	--[[
Name: Babble-Boss-2.2
Revision: 20004
Author(s): ckknight (ckknight@gmail.com)
Website: http://ckknight.wowinterface.com/
Documentation: http://wiki.wowace.com/index.php/Babble-Boss-2.2
SVN: http://svn.wowace.com/root/trunk/Babble-2.2/Babble-Boss-2.2
Description: A library to provide localizations for bosses.
Dependencies: AceLibrary, AceLocale-2.2
]]
	["Avalanchion"] = "阿瓦兰奇奥";
	["The Windreaver"] = "烈风掠夺者";
	["Baron Charr"] = "火焰男爵查尔";
	["Princess Tempestria"] = "泰比斯蒂亚公主";
	["Grethok the Controller"] = "黑翼控制者";
	["Patchwerk"] = "帕奇维克";
	["Grobbulus"] = "格罗布鲁斯";
	["Gluth"] = "格拉斯";
	["Feugen"] = "费尔根";
	["Stalagg"] = "斯塔拉格";
	["Thaddius"] = "塔迪乌斯";
	["Anub'Rekhan"] = "阿努布雷坎";
	["Grand Widow Faerlina"] = "黑女巫法琳娜";
	["Maexxna"] = "迈克斯纳";
	["Instructor Razuvious"] = "教官拉苏维奥斯";
	["Deathknight Understudy"] = "死亡骑士学员";
	["Gothik the Harvester"] = "收割者戈提克";
	["Highlord Mograine"] = "大领主莫格莱尼";
	["Thane Korth'azz"] = "库尔塔兹领主";
	["Lady Blaumeux"] = "女公爵布劳缪克丝";
	["Sir Zeliek"] = "瑟里耶克爵士";
	["The Four Horsemen"] = "四骑士";
	["Noth the Plaguebringer"] = "瘟疫使者诺斯";
	["Heigan the Unclean"] = "肮脏的希尔盖";
	["Loatheb"] = "洛欧塞布";
	["Sapphiron"] = "萨菲隆";
	["Kel'Thuzad"] = "克尔苏加德";
	["Lord Victor Nefarius"] = "维克多·奈法里奥斯领主";
	["Nefarian"] = "奈法利安";
	["Vaelastrasz the Corrupt"] = "堕落的瓦拉斯塔兹";
	["Razorgore the Untamed"] = "狂野的拉佐格尔";
	["Broodlord Lashlayer"] = "勒什雷尔";
	["Chromaggus"] = "克洛玛古斯";
	["Ebonroc"] = "埃博诺克";
	["Firemaw"] = "费尔默";
	["Flamegor"] = "弗莱格尔";
	["Majordomo Executus"] = "管理者埃克索图斯";
	["Ragnaros"] = "拉格纳罗斯";
	["Baron Geddon"] = "迦顿男爵";
	["Golemagg the Incinerator"] = "焚化者古雷曼格";
	["Garr"] = "加尔";
	["Sulfuron Harbinger"] = "萨弗隆先驱者";
	["Shazzrah"] = "沙斯拉尔";
	["Lucifron"] = "鲁西弗隆";
	["Gehennas"] = "基赫纳斯";
	["Magmadar"] = "玛格曼达";
	["Onyxia"] = "奥妮克希亚";
	["Azuregos"] = "艾索雷葛斯";
	["Lord Kazzak"] = "卡扎克";
	["Ysondre"] = "伊森德雷";
	["Emeriss"] = "艾莫莉丝";
	["Taerar"] = "泰拉尔";
	["Lethon"] = "雷索";
	-- TurtleWOW
	["Nerubian"] = "蛛怪";
	["Nerubian Overseer"] = "蛛怪监工";
	["Reaver"] = "掠夺者";
	["Ostarius"] = "奥兹塔里亚斯";
	["Concavius"] = "空卡维斯";
	["Dark Reaver of Karazhan"] = "卡拉赞黑暗掠夺者";
	----------------------
	["High Priestess Jeklik"] = "高阶女祭司耶克里克";
	["High Priest Venoxis"] = "高阶祭司温诺希斯";
	["High Priest Thekal"] = "高阶祭司塞卡尔";
	["High Priestess Arlokk"] = "高阶女祭司娅尔罗";
	["High Priestess Mar'li"] = "高阶女祭司玛尔里";
	["Jin'do the Hexxer"] = "妖术师金度";
	["Bloodlord Mandokir"] = "血领主曼多基尔";
	["Gahz'ranka"] = "加兹兰卡";
	["Gri'lek"] = "格里雷克";
	["Hazza'rah"] = "哈札拉尔";
	["Renataki"] = "雷纳塔基";
	["Wushoolay"] = "乌苏雷";
	["Hakkar"] = "哈卡";
	["Ayamiss the Hunter"] = "狩猎者阿亚米斯";
	["Buru the Gorger"] = "吞咽者布鲁";
	["General Rajaxx"] = "拉贾克斯将军";
	["Lieutenant General Andorov"] = "安多洛夫中将";
	["Moam"] = "莫阿姆";
	["Anubisath Guardian"] = "阿努比萨斯守卫者";
	["Ossirian the Unscarred"] = "无疤者奥斯里安";
	["Lord Kri"] = "克里勋爵";
	["Princess Yauj"] = "亚尔基公主";
	["Vem"] = "维姆";
	["The Bug Family"] = "虫子家族";
	["Eye of C'Thun"] = "克苏恩之眼";
	["C'Thun"] = "克苏恩";
	["Anubisath Defender"] = "阿努比萨斯防御者";
	["Anubisath Warder"] = "阿努比萨斯守卫";
	["Fankriss the Unyielding"] = "顽强的范克瑞斯";
	["Princess Huhuran"] = "哈霍兰公主";
	["Ouro"] = "奥罗";
	["Battleguard Sartura"] = "沙尔图拉";
	["The Prophet Skeram"] = "预言者斯克拉姆";
	["Emperor Vek'lor"] = "维克洛尔大帝";
	["Emperor Vek'nilash"] = "维克尼拉斯大帝";
	["The Twin Emperors"] = "双子皇帝";
	["Viscidus"] = "维希度斯";
	["Alzzin the Wildshaper"] = "奥兹恩";
	["Ambassador Flamelash"] = "弗莱拉斯大使";
	["Anger'rel"] = "安格雷尔";
	["Archivist Galford"] = "档案管理员加尔福特";
	["Atal'alarion"] = "阿塔拉利恩";
	["Avatar of Hakkar"] = "哈卡的化身";
	["Bael'Gar"] = "贝尔加";
	["Balnazzar"] = "巴纳札尔";
	["Baroness Anastari"] = "安娜丝塔丽男爵夫人";
	["Baron Rivendare"] = "瑞文戴尔男爵";
	["Cannon Master Willey"] = "炮手威利";
	["Captain Kromcrush"] = "克罗卡斯";
	["Celebras the Cursed"] = "被诅咒的塞雷布拉斯";
	["Crystal Fang"] = "水晶之牙";
	["Darkmaster Gandling"] = "通灵院长·加丁";
	["Doctor Theolen Krastinov"] = "瑟尔林·卡斯迪诺夫教授";
	["Doom'rel"] = "杜姆雷尔";
	["Dope'rel"] = "多普雷尔";
	["Dreamscythe"] = "德姆塞卡尔";
	["Emperor Dagran Thaurissan"] = "达格兰·索瑞森大帝";
	["Fineous Darkvire"] = "弗诺斯·达克维尔";
	["Gasher"] = "加什尔";
	["General Angerforge"] = "安格弗将军";
	["General Drakkisath"] = "达基萨斯将军";
	["Gloom'rel"] = "格鲁雷尔";
	["Golem Lord Argelmach"] = "傀儡统帅阿格曼奇";
	["Goraluk Anvilcrack"] = "古拉鲁克";
	["Guard Fengus"] = "卫兵芬古斯";
	["Guard Mol'dar"] = "卫兵摩尔达";
	["Guard Slip'kik"] = "卫兵斯里基克";
	["Gyth"] = "盖斯";
	["Halycon"] = "哈雷肯";
	["Hate'rel"] = "黑特雷尔";
	["Hazzas"] = "哈扎斯";
	["Hearthsinger Forresten"] = "弗雷斯特恩";
	["The Unforgiven"] = "不可宽恕者";
	["High Interrogator Gerstahn"] = "审讯官格斯塔恩";
	["Highlord Omokk"] = "欧莫克大王";
	["Hukku"] = "胡库";
	["Hurley Blackbreath"] = "霍尔雷·黑须";
	["Hydrospawn"] = "海多斯博恩";
	["Illyanna Ravenoak"] = "伊琳娜·暗木";
	["Immol'thar"] = "伊莫塔尔";
	["Instructor Malicia"] = "讲师玛丽希亚";
	["Jammal'an the Prophet"] = "预言者迦玛兰";
	["Jandice Barov"] = "詹迪斯·巴罗夫";
    ["Jared Voss"] = "杰里德·维斯",
	["King Gordok"] = "戈多克大王";
	["Kirtonos the Herald"] = "传令官基尔图诺斯";
	["Lady Illucia Barov"] = "伊露希亚·巴罗夫女士";
	["Landslide"] = "兰斯利德";
	["Lethtendris"] = "蕾瑟塔蒂丝";
	["Lord Alexei Barov"] = "阿雷克斯·巴罗夫";
	["Lord Incendius"] = "伊森迪奥斯";
	["Lord Vyletongue"] = "维利塔恩";
	["Lorekeeper Polkelt"] = "博学者普克尔特";
	["Loro"] = "洛若尔";
	["Magister Kalendris"] = "卡雷迪斯镇长";
	["Magistrate Barthilas"] = "巴瑟拉斯镇长";
	["Magmus"] = "玛格姆斯";
	["Maleki the Pallid"] = "苍白的玛勒基";
	["Marduk Blackpool"] = "马杜克·布莱克波尔";
	["Meshlok the Harvester"] = "收割者麦什洛克";
	["Mijan"] = "米杉";
	["Morphaz"] = "摩弗拉斯";
	["Mother Smolderweb"] = "烟网蛛后";
	["Nerub'enkan"] = "奈鲁布恩坎";
	["Noxxion"] = "诺克赛恩";
	["Ogom the Wretched"] = "可悲的奥戈姆";
	["Overlord Wyrmthalak"] = "维姆萨拉克";
	["Phalanx"] = "法拉克斯";
	["Plugger Spazzring"] = "普拉格";
	["Postmaster Malown"] = "邮差马龙";
	["Princess Moira Bronzebeard"] = "铁炉堡公主茉艾拉·铜须";
	["Princess Theradras"] = "瑟莱德丝公主";
	["Prince Tortheldrin"] = "托塞德林王子";
	["Pusillin"] = "普希林";
	["Pyroguard Emberseer"] = "烈焰卫士艾博希尔";
	["Ramstein the Gorger"] = "吞咽者拉姆斯登";
	["Ras Frostwhisper"] = "莱斯·霜语";
	["Rattlegore"] = "血骨傀儡";
	["Razorlash"] = "锐刺鞭笞者";
	["Warchief Rend Blackhand"] = "大酋长雷德·黑手";
	["Ribbly Screwspigot"] = "雷布里·斯库比格特";
	["Rotgrip"] = "洛特格里普";
	["Seeth'rel"] = "西斯雷尔";
	["Shade of Eranikus"] = "伊兰尼库斯的阴影";
	["Shadow Hunter Vosh'gajin"] = "暗影猎手沃许加斯";
	["Solakar Flamewreath"] = "索拉卡·火冠";
	["Stomper Kreeg"] = "践踏者克雷格";
	["Tendris Warpwood"] = "特迪斯·扭木";
	["The Beast"] = "比斯巨兽";
	["The Ravenian"] = "拉文尼亚";
	["Timmy the Cruel"] = "悲惨的提米";
	["Tinkerer Gizlock"] = "工匠吉兹洛克";
	["Tsu'zee"] = "苏斯";
	["Vectus"] = "维克图斯";
	["Vile'rel"] = "瓦勒雷尔";
	["War Master Voone"] = "指挥官沃恩";
	["Weaver"] = "德拉维沃尔";
	["Zevrim Thornhoof"] = "瑟雷姆·刺蹄";
	["Zolo"] = "祖罗";
	["Zul'Lor"] = "祖罗尔";
	-- From Mendeleev
	["Cho'Rush the Observer"] = "观察者克鲁什";
	["Lord Hel'nurath"] = "赫尔努拉斯";
	["Pimgib"] = "匹姆吉布";
	["Knot Thimblejack's Cache"] = "诺特·希姆加克的储物箱";
	["Cannonmaster Willey"] = "炮手威利";
	["Emperor Dagran Thaurissian"] = "达格兰·索瑞森大帝";
	["Archmage Arugal"] = "大法师阿鲁高";
	["Archmage Arugal's Voidwalker"] = "大法师阿鲁高的虚空行者";
	["Baron Silverlaine"] = "席瓦莱恩男爵";
	["Commander Springvale"] = "指挥官斯普林瓦尔";
	["Deathsworn Captain"] = "死亡之誓队长";
	["Fenrus the Devourer"] = "吞噬者芬鲁斯";
	["Odo the Blindwatcher"] = "盲眼守卫奥杜";
	["Razorclaw the Butcher"] = "屠夫拉佐克劳";
	["Wolf Master Nandos"] = "狼王南杜斯";
	["Rend Blackhand"] = "雷德·黑手";
	["Kurinnaxx"] = "库林纳克斯";
	["Maur Grimtotem"] = "玛尔·恐怖图腾";
	["Oggleflint"] = "奥格弗林特";
	["Taragaman the Hungerer"] = "饥饿者塔拉加曼";
	["Jergosh the Invoker"] = "祈求者耶戈什";
	["Bazzalan"] = "巴札兰";
	["Disciple of Naralex"] = "纳拉雷克斯的信徒";
	["Lord Cobrahn"] = "考布莱恩领主";
	["Lady Anacondra"] = "安娜科德拉女士";
	["Kresh"] = "克雷什";
	["Lord Pythas"] = "皮萨斯领主";
	["Skum"] = "斯卡姆";
	["Lord Serpentis"] = "瑟芬迪斯领主";
	["Verdan the Everliving"] = "永生者沃尔丹";
	["Mutanus the Devourer"] = "吞噬者穆坦努斯";
	["Naralex"] = "纳拉雷克斯";
	["Deviate Faerie Dragon"] = "变异精灵龙";
	["Ghamoo-ra"] = "加摩拉";
	["Lady Sarevess"] = "萨利维丝女士";
	["Gelihast"] = "格里哈斯特";
	-- 新月林地 TurtleWOW
	["Grovetender Engryss"] = "护林员恩格里斯";
	["Keeper Ranathos"] = "守护者拉纳苏斯";
	["High Priestess A'lathea"] = "高阶女祭司阿勒西";
	["Fenektis the Deceiver"] = "欺诈者弗纳克提斯";
	["Master Raxxieth"] = "拉克西斯大师";
	-- 仇恨熔炉采石场 TurtleWOW
	["High Foreman Bargul Blackhammer"] = "高级工头巴古·黑锤";
	["Engineer Figgles"] = "工程师菲格尔斯";
	["Hateforge Chemistry Documents"] = "仇恨熔炉化学文档";
	["Corrosis"] = "腐蚀西斯";
	["Hatereaver Annihilator"] = "憎恨歼灭者";
	["Hargesh Doomcaller"] = "哈格什·末日召唤者";
	-- 卡拉赞墓穴 TurtleWOW
	["Marrowspike"] = "髓刺";
	["Hivaxxis"] = "西瓦克西斯";
	["Corpsemuncher"] = "嚼尸鬼";
	["Guard Captain Gort"] = "卫兵长高尔特";
	["Archlich Enkhraz"] = "大巫妖安克瑞兹";
	["Commander Andreon"] = "指挥官安德里昂";
	["Alarus"] = "阿拉鲁斯";
	["Half-Buried Treasure Chest"] = "半埋宝箱";
	-- 黑色沼泽 TurtleWOW
	["Chronar"] = "克罗纳";
	["Harbinger Aph'ygth"] = "先驱者阿菲格斯";
	["Epidamu"] = "埃皮达姆";
	["Drifting Avatar of Sand"] = "沙之漂流化身";
	["Time-Lord Epochronos"] = "时间领主伊波克洛诺斯";
	["Mossheart"] = "莫斯哈特";
	["Rotmaw"] = "腐烂之喉";
	["Antnormi"] = "安特诺米";
	["Infinite Chromie"] = "无限克罗米";
	-- 暴风城地牢 TurtleWOW
	["Aszosh Grimflame"] = "艾丝卓仕·格瑞姆弗雷姆";
	["Tham'Grarr"] = "塞姆格拉";
	["Black Bride"] = "黑色新娘";
	["Tome of Arcane Intricacies and Magical Phenomenon IX"] = "奥术奥秘与魔法现象第九卷";
	["Damian"] = "戴米安";
	["Volkan Cruelblade"] = "沃肯·冷刃";
	["Arc'tiras"] = "阿克提阿斯";
	["Vault Armory Equipment"] = "避难所军械库设备";
	-- 吉尔尼斯城 TurtleWOW 1.17.0
	["Matthias Holtz"] = "马蒂亚斯·霍尔茨";
	["Packmaster Ragetooth"] = "兽群首领怒牙";
	["Dawnstone Plans"] = "黎明石计划";
	["Manuscript of Hydromancy II"] = "水占术手稿第二卷";
	["Judge Sutherland"] = "萨瑟兰法官";
	["Dustivan Blackcowl"] = "达斯蒂万·布莱克考尔";
	["Marshal Magnus Greystone"] = "元帅马格努斯·格雷斯通";
	["Horsemaster Levvin"] = "御马司莱文";
	-- 卡拉赞大厅 TurtleWOW 1.17.0
	["Master Blacksmith Rolfen"] = "锻造大师罗尔芬";
	["Engraved Golden Bracelet"] = "雕花金手镯";
	["Comfortable Pillow"] = "舒适的枕头";
	["Duke Rothlen"] = "公爵罗斯伦";
	["Obsidian Rod"]  = "黑曜石棒";
	["Lord Ebonlocke"] = "埃伯洛克领主";
	["Councilman Kyleson"] = "议员凯尔森";
	["Brood Queen Araxxna"] = "巢穴女王阿拉克萨娜";
	["Grizikil"] = "格里齐基尔";
	["Lord Blackwald II"] = "布莱克沃尔德勋爵二世";
	["Moroes"] = "莫罗斯";
	["Harlow Family Chest"] = "哈洛家庭宝箱";
	["Genn Greymane"] = "吉恩·格雷迈恩";
	-- 翡翠圣殿 TurtleWOW 1.17.0
	["Erennius"] = "埃伦纽斯";
	["Solnius the Awakener"] = "觉醒者索尔纽斯";
	["Clawlord Howlfang"] = "爪王嚎牙";
	-------------------------------------
	["Lorgus Jett"] = "洛古斯·杰特";
	["Baron Aquanis"] = "阿奎尼斯男爵";
	["Twilight Lord Kelris"] = "梦游者克尔里斯";
	["Old Serra'kis"] = "老瑟拉吉斯";
	["Aku'mai"] = "阿库麦尔";
	["Roogug"] = "鲁古格";
	["Aggem Thorncurse"] = "阿格姆·荆棘诅咒";
	["Death Speaker Jargba"] = "亡语者贾格巴";
	["Overlord Ramtusk"] = "主宰拉姆塔斯";
	["Agathelos the Raging"] = "暴怒的阿迦赛罗斯";
	["Blind Hunter"] = "盲眼猎手";
	["Charlga Razorflank"] = "卡尔加·刺肋";
	["Earthcaller Halmgar"] = "唤地者哈穆加";
	["Tuten'kash"] = "图特卡什";
	["Lady Falther'ess"] = "法瑟蕾丝夫人";
	["Mordresh Fire Eye"] = "火眼莫德雷斯";
	["Glutton"] = "暴食者";
	["Ragglesnout"] = "拉戈斯诺特";
	["Amnennar the Coldbringer"] = "寒冰之王亚门纳尔";
	["Plaguemaw the Rotting"] = "腐烂的普雷莫尔";
	["Antu'sul"] = "安图苏尔";
	["Witch Doctor Zum'rah"] = "巫医祖穆拉恩";
	["Shadowpriest Sezz'ziz"] = "暗影祭司塞瑟斯";
	["Gahz'rilla"] = "加兹瑞拉";
	["Chief Ukorz Sandscalp"] = "乌克兹·沙顶";
	["Ruuzlu"] = "卢兹鲁";
	["Isalien"] = "伊萨利恩";
	["Revanchion"] = "雷瓦克安";
	["Lord Roccor"] = "洛考尔";
	["Anub'shiah"] = "阿努希尔";
	["Eviscerator"] = "剜眼者";
	["Gorosh the Dervish"] = "修行者高罗什";
	["Grizzle"] = "格里兹尔";
	["Hedrum the Creeper"] = "爬行者赫杜姆";
	["Ok'thor the Breaker"] = "破坏者奥科索尔";
	["Houndmaster Grebmar"] = "驯犬者格雷布玛尔";
	["Pyromancer Loregrain"] = "控火师罗格雷恩";
	["Warder Stilgiss"] = "典狱官斯迪尔基斯";
	["Verek"] = "维雷克";
	["Watchman Doomgrip"] = "卫兵杜格瑞普";
	["Panzor the Invincible"] = "无敌的潘佐尔";
	["Mor Grayhoof"] = "莫尔·灰蹄";
	["Bannok Grimaxe"] = "班诺克·巨斧";
	["Urok Doomhowl"] = "乌洛克";
	["Quartermaster Zigris"] = "军需官兹格雷斯";
	["Gizrul the Slavener"] = "奴役者基兹卢尔";
	["Ghok Bashguud"] = "霍克·巴什古德";
	["Jed Runewatcher"] = "杰德";
	["Lord Valthalak"] = "瓦萨拉克";
	["Grubbis"] = "格鲁比斯";
	["Chomper"] = "咀嚼者";
	["Viscous Fallout"] = "粘性辐射尘";
	["Electrocutioner 6000"] = "电刑器6000型";
	["Crowd Pummeler 9-60"] = "群体打击者9-60";
	["Dark Iron Ambassador"] = "黑铁大师";
	["Mekgineer Thermaplugg"] = "制造者瑟玛普拉格";
	["Houndmaster Loksey"] = "驯犬者洛克希";
	["Arcanist Doan"] = "秘法师杜安";
	["Herod"] = "赫洛德";
	["High Inquisitor Fairbanks"] = "大检察官法尔班克斯";
	["Scarlet Commander Mograine"] = "血色十字军指挥官莫格莱尼";
	["High Inquisitor Whitemane"] = "大检察官怀特迈恩";
	["Interrogator Vishas"] = "审讯员韦沙斯";
	["Bloodmage Thalnos"] = "血法师萨尔诺斯";
	["Ironspine"] = "铁脊死灵";
	["Azshir the Sleepless"] = "永醒的艾希尔";
	["Fallen Champion"] = "亡灵勇士";
	["Lord Blackwood"] = "布莱克伍德公爵";
	["Death Knight Darkreaver"] = "死亡骑士达克雷尔";
	["Kormok"] = "库尔莫克";
	["Skul"] = "斯库尔";
	["Balzaphon"] = "巴尔萨冯";
	["Malor the Zealous"] = "狂热的玛洛尔";
	["Sothos"] = "索托斯";
	["Jarien"] = "亚雷恩";
	["Stonespine"] = "石脊";
	["Rhahk'Zor"] = "拉克佐";
	["Miner Johnson"] = "矿工约翰森";
	["Sneed"] = "斯尼德";
	["Gilnid"] = "基尔尼格";
	["Captain Greenskin"] = "绿皮队长";
	["Edwin VanCleef"] = "艾德温·范克里夫";
	["Mr. Smite"] = "斯米特先生";
	["Cookie"] = "曲奇";
	["Targorr the Dread"] = "可怕的塔格尔";
	["Kam Deepfury"] = "卡姆·深怒";
	["Hamhock"] = "哈姆霍克";
	["Bazil Thredd"] = "巴基尔·斯瑞德";
	["Dextren Ward"] = "迪克斯特·瓦德";
	["Bruegal Ironknuckle"] = "布鲁戈·艾尔克纳寇";
	["Baelog"] = "巴尔洛戈";
	["Eric \"The Swift\""] = "“迅捷的”埃里克";
	["Olaf"] = "奥拉夫";
	["Revelosh"] = "鲁维罗什";
	["Ironaya"] = "艾隆纳亚";
	["Obsidian Sentinel"] = "黑曜石哨兵";
	["Ancient Stone Keeper"] = "古代的石头看守者";
	["Galgann Firehammer"] = "加加恩·火锤";
	["Grimlok"] = "格瑞姆洛克";
	["Archaedas"] = "阿扎达斯";
	["Sever"] = "斩首者";
	["Scorn"] = "瑟克恩";
	["Rethilgore"] = "雷希戈尔";
	["Atiesh"] = "埃提耶什";
	["Stratholme Courier"] = "斯坦索姆信使";
	["Stoneskin Gargoyle"] = "岩肤石像鬼";
	["Gurubashi Berserker"] = "古拉巴什狂暴者";
	["Elder Mottled Boar"] = "老杂斑野猪";
	["Ancient Core Hound"] = "上古熔火恶犬";
	["Sorcerer Ashcrombe"] = "巫师阿克鲁比";
    ["Masterpiece Harvester"] = "收割者-最后杰作",

--[[
Name: Babble-Zone-2.2
Revision: $Rev: 17779 $
Author(s): ckknight (ckknight@gmail.com)
Website: http://ckknight.wowinterface.com/
Documentation: http://wiki.wowace.com/index.php/Babble-Zone-2.2
SVN: http://svn.wowace.com/root/trunk/Babble-2.2/Babble-Zone-2.2
Description: A library to provide localizations for zones.
Dependencies: AceLibrary, AceLocale-2.2
]]
	["Ahn'Qiraj"] = "安其拉";
	["Alah'Thalas"] = "阿尔萨拉斯"; --TurtleWOW
	["Alterac Mountains"] = "奥特兰克山脉";
	["Alterac Valley"] = "奥特兰克山谷";
	["Arathi Basin"] = "阿拉希盆地";
	["Arathi Highlands"] = "阿拉希高地";
	["Ashenvale"] = "灰谷";
	["Auberdine"] = "奥伯丁";
	["Azshara"] = "艾萨拉";
	["Badlands"] = "荒芜之地";
	["The Barrens"] = "贫瘠之地";
	["The Black Morass"] = "黑色沼泽"; --TurtleWOW
	["Black Morass"] = "黑色沼泽"; -- TurtleWOW
	["Blackfathom Deeps"] = "黑暗深渊";
	["Blackrock Depths"] = "黑石深渊";
	["Blackrock Mountain"] = "黑石山";
	["Blackrock Spire"] = "黑石塔";
	["Blackwing Lair"] = "黑翼之巢";
	["Blasted Lands"] = "诅咒之地";
	["Booty Bay"] = "藏宝海湾";
	["Burning Steppes"] = "燃烧平原";
	["The Crescent Grove"] = "新月林地"; -- TurtleWOW
	["Darkshore"] = "黑海岸";
	["Darnassus"] = "达纳苏斯";
	["The Deadmines"] = "死亡矿井";
	["Deadwind Pass"] = "逆风小径";
	["Deeprun Tram"] = "矿道地铁";
	["Desolace"] = "凄凉之地";
	["Dire Maul"] = "厄运之槌";
	["Dire Maul (East)"] = "厄运之槌（东）";
	["Dire Maul (West)"] = "厄运之槌（西）";
	["Dire Maul (North)"] = "厄运之槌（北）";
	["Dun Morogh"] = "丹莫罗";
	["Dun Agrath"] = "丹阿格拉斯";
	["Durotar"] = "杜隆塔尔";
	["Duskwood"] = "暮色森林";
	["Dustwallow Marsh"] = "尘泥沼泽";
	["Eastern Kingdoms"] = "东部王国";
	["Eastern Plaguelands"] = "东瘟疫之地";
	["Elwynn Forest"] = "艾尔文森林";
	["Emerald Sanctum"] = "翡翠圣殿"; -- TurtleWOW
	["Everlook"] = "永望镇";
	["Felwood"] = "费伍德森林";
	["Feralas"] = "菲拉斯";
	["The Forbidding Sea"] = "禁忌之海";
	["Gadgetzan"] = "加基森";
	["Gates of Ahn'Qiraj"] = "安其拉之门";
	["Gilneas"] = "吉尔尼斯"; --TurtleWOW
	["Gilneas City"] = "吉尔尼斯城"; --TurtleWOW
	["Gnomeregan"] = "诺莫瑞根";
	["The Great Sea"] = "无尽之海";
	["Grom'gol Base Camp"] = "格罗姆高营地";
	["Hall of Legends"] = "传说大厅";
	["Hateforge Quarry"] = "仇恨熔炉采石场"; -- TurtleWOW
	["Hillsbrad Foothills"] = "希尔斯布莱德丘陵";
	["The Hinterlands"] = "辛特兰";
	["Hyjal"] = "海加尔山";
	["Ironforge"] = "铁炉堡";
	["Ironforge Airfields"] = "铁炉堡机场";
	["Kalimdor"] = "卡利姆多";
	["Karazhan Crypt"] = "卡拉赞墓穴"; -- TurtleWOW
	["Loch Modan"] = "洛克莫丹";
	["Lower Blackrock Spire"] = "黑石塔下层";
	["Lower Karazhan Halls"] = "卡拉赞下层大厅"; -- TurtleWOW
	["Maraudon"] = "玛拉顿";
	["Menethil Harbor"] = "米奈希尔港";
	["Molten Core"] = "熔火之心";
	["Moonglade"] = "月光林地";
	["Mulgore"] = "莫高雷";
	["Naxxramas"] = "纳克萨玛斯";
	["Onyxia's Lair"] = "奥妮克希亚的巢穴";
	["Orgrimmar"] = "奥格瑞玛";
	["Ratchet"] = "棘齿城";
	["Ragefire Chasm"] = "怒焰裂谷";
	["Razorfen Downs"] = "剃刀高地";
	["Razorfen Kraul"] = "剃刀沼泽";
	["Redridge Mountains"] = "赤脊山";
	["Ruins of Ahn'Qiraj"] = "安其拉废墟";
	["Scarlet Monastery"] = "血色修道院";
	["Scarlet Monastery Cathedral"] = "血色修道院-大教堂"; -- TurtleWOW
	["Scarlet Monastery Armory"] = "血色修道院-军械库"; -- TurtleWOW
	["Scarlet Monastery Library"] = "血色修道院-图书馆"; -- TurtleWOW
	["Scarlet Monastery Graveyard"] = "血色修道院-墓地"; -- TurtleWOW
	["Scholomance"] = "通灵学院";
	["Searing Gorge"] = "灼热峡谷";
	["Shadowfang Keep"] = "影牙城堡";
	["Silithus"] = "希利苏斯";
	["Silverpine Forest"] = "银松森林";
	["The Stockade"] = "监狱";
	["Stonetalon Mountains"] = "石爪山脉";
	["Stormwind City"] = "暴风城";
	["Stormwind Vault"] = "暴风城地牢"; -- TurtleWOW
	["Stranglethorn Vale"] = "荆棘谷";
	["Stratholme"] = "斯坦索姆";
	["Swamp of Sorrows"] = "悲伤沼泽";
	["Tanaris"] = "塔纳利斯";
	["Teldrassil"] = "泰达希尔";
	["Temple of Ahn'Qiraj"] = "安其拉神庙";
	["The Temple of Atal'Hakkar"] = "阿塔哈卡神庙";
	["Theramore Isle"] = "塞拉摩岛";
	["Thalassian Highlands"] = "萨拉斯高地";
	["Thousand Needles"] = "千针石林";
	["Thunder Bluff"] = "雷霆崖";
	["Tirisfal Glades"] = "提瑞斯法林地";
	["Uldaman"] = "奥达曼";
	["Un'Goro Crater"] = "安戈洛环形山";
	["Undercity"] = "幽暗城";
	["Upper Blackrock Spire"] = "黑石塔上层";
	["Wailing Caverns"] = "哀嚎洞穴";
	["Warsong Gulch"] = "战歌峡谷";
	["Western Plaguelands"] = "西瘟疫之地";
	["Westfall"] = "西部荒野";
	["Wetlands"] = "湿地";
	["Winterspring"] = "冬泉谷";
	["Zul'Farrak"] = "祖尔法拉克";
	["Zul'Gurub"] = "祖尔格拉布";

	["Caelan's Rest"] = "卡兰之墓";
	["Lapidis Isle"] = "拉匹迪斯之岛";
	["Ravenshire"] = "拉文郡";
	["Tel Co. Basecamp"] = "特尔公司营地";
	["Bael Hardul"] = "贝尔哈杜尔";
	["Nordanaar"] = "诺达纳尔";
	["Tel'Abim"] = "泰拉比姆";
	["Gillijim's Isle"] = "吉利吉姆之岛";
	["Maul'ogg Refuge"] = "莫尔奥格避难所";
	["Stillward Church"] = "寂静守卫教堂";
	["Mudsprocket"] = "泥链镇";
	["Moomoo Grove"] = "奶牛树林";
	["Blood Ring Arena"] = "血色竞技场";
	["Sunnyglade Valley"] = "阳光林地山谷";
	-- TBC
	
	-- 用于显示副本的子区域
	["Plaguewood"] = "病木林";
	["Hellfire Citadel"] = "地狱火堡垒";
	["Auchindoun"] = "奥金顿";
	["The Bone Wastes"] = "白骨荒野"; -- 替代奥金顿，因为这是小地图上显示的名称
	["Coilfang Reservoir"] = "盘牙水库"; -- 暂未使用

	["Azuremyst Isle"] = "蓝谜岛";
	["Bloodmyst Isle"] = "血谜岛";
	["Eversong Woods"] = "永歌森林";
	["Ghostlands"] = "幽魂之地";
	["The Exodar"] = "埃索达";
	["Silvermoon City"] = "银月城";
	["Shadowmoon Valley"] = "影月谷";
	["Black Temple"] = "黑暗神殿";
	["Terokkar Forest"] = "泰罗卡森林";
	["Auchenai Crypts"] = "奥金尼地穴";
	["Mana-Tombs"] = "法力陵墓";
	["Shadow Labyrinth"] = "暗影迷宫";
	["Sethekk Halls"] = "塞泰克大厅";
	["Hellfire Peninsula"] = "地狱火半岛";
	["The Dark Portal"] = "黑暗之门";
	["Hellfire Ramparts"] = "地狱火城墙";
	["The Blood Furnace"] = "鲜血熔炉";
	["The Shattered Halls"] = "破碎大厅";
	["Magtheridon's Lair"] = "玛瑟里顿的巢穴";
	["Nagrand"] = "纳格兰";
	["Zangarmarsh"] = "赞加沼泽";
	["The Slave Pens"] = "奴隶围栏";
	["The Underbog"] = "幽暗沼泽";
	["The Steamvault"] = "蒸汽地窟";
	["Serpentshrine Cavern"] = "毒蛇神殿洞穴";
	["Blade's Edge Mountains"] = "刀锋山";
	["Gruul's Lair"] = "格鲁尔的巢穴";
	["Netherstorm"] = "虚空风暴";
	["Tempest Keep"] = "风暴要塞";
	["The Mechanar"] = "机械室";
	["The Botanica"] = "生态船";
	["The Arcatraz"] = "禁魔监狱";
	["Eye of the Storm"] = "风暴之眼";
	["Shattrath City"] = "沙塔斯城";
	["Karazhan"] = "卡拉赞";
	["Caverns of Time"] = "时光之穴";
	["Zul'Aman"] = "祖阿曼";
	["Moo"] = "奶牛之王";
	["Cla'ckora"] = "克拉科拉";
    -- 卡拉赞之塔
    ["Tower of Karazhan"] = "卡拉赞之塔";
	["Upper Karazhan Tower Key"] = "上层卡拉赞塔之钥",
    ["Keeper Gnarlmoon"] = "守护者纳尔穆恩";
    ["Ley-Watcher Incantagos"] = "魔网观察者因塔苟斯";
    ["Anomalus"] = "阿诺玛鲁斯";
    ["Echo of Medivh"] = "麦迪文的回响";
    ["King"] = "国王";
    ["Sanv Tas'dal"] = "桑夫·塔斯达尔";
    ["Rupturan the Broken"] = "破碎者鲁普图兰";
    ["Kruul"] = "库鲁尔";
    ["Mephistroth"] = "孟菲斯托斯";

	-- patch 1.18.0
	["Dun Kithas"] = "丹基塔斯";
	["Shatterblade Post"] = "岩须港";
	["Grim Reaches"] = "冷酷海岸";
	["Slickwick Oil Rig"] = "滑芯石油钻井平台";
	["Gnomeregan Reclamation Facility"] = "诺莫瑞根复兴城";
	["Ambershire"] = "安伯郡";
	["Northwind"] = "北风领";
	["Stormbreaker Point"] = "暴掠角";
	["SI:7 Outpost"] = "军情七处哨站";
	["Steepcliff Port"] = "陡崖港";

	["Champion Razjal the Quick"] = "迅捷的拉扎尔";
	["Death Prophet Rakameg"] = "死亡预言者拉卡梅格";
	["Rotthorn"] = "罗特索恩";
	["Velthelaxx the Defiler"] = "污染者维尔塞拉克斯";
	["Zel'jeb the Ancient"] = "年迈的泽尔杰布";
	["Basalthar"] = "巴萨尔萨";
	["Basalthar & Smoldaris"] = "巴萨尔萨与斯摩达利斯";
    ["Incindis"] = "因辛迪斯";
	["Smoldaris"] = "斯摩达利斯";
	["Sorcerer-Thane Thaurissan"] = "巫王索瑞森";
	
	["Dragonmaw Retreat"] = "龙喉居所";
	["Gowlfang"] = "孤峰";
	["Garlok Flamekeeper"] = "卡洛克·护火者";
	["Cavernweb Broodmother"] = "穴织女王";
	["Halgan Redbrand"] = "哈尔甘·红标";
	["Elder Hollowblood"] = "长者空血";
	["Searistrasz"] = "希瑞斯塔萨";
	["Web Master Torkon"] = "织网大师托尔康";
	["Zuluhed the Whacked"] = "酋长塔尔加斯·龙颅";
	["Slagfist Destroyer"] = "渣拳毁灭者";
	["Overlord Blackheart"] = "黑心大王";
	
	["Stormwrought Ruins"] = "风暴废墟";
	["Balor"] = "巴洛";
	["Dagar the Glutton"] = "暴食的达加尔";
	["Chieftain Stormsong"] = "雷歌酋长";
	["Deathlord Tidebane"] = "死亡领主泰德贝恩";
	["Mycellakos"] = "麦塞拉克斯";
	["Duke Balor the IV"] = "巴洛公爵四世";
	["Ighal'for"] = "伊加尔弗";
	["Lady Drazare"] = "德拉扎尔女士";
	["Librarian Theodorus"] = "图书管理员西奥多鲁斯";
	["Eldermaw the Primordial"] = "原始的老喉巨鳄";
	["Oronok Torn-Heart"] = "欧鲁诺克·裂心";
	["Remains of the Innocent"] = "无辜者的遗骸";
	["Subjugator Halthas Shadecrest"] = "征服者哈尔萨斯·暗影之冠";
	["Mergothid"] = "墨苟斯";
	-- patch 1.18.1
	["Timbermaw Hold"] = "木喉要塞",
	["Karrsh the Sentinel"] = "哨兵卡什",
	["Rotgrowl"] = "腐嚎",
	["Loktanag the Vile"] = "落潭",
	["Ormanos the Cracked"] = "裂地者欧曼诺斯",
	["Chieftain Partath"] = "大酋长帕萨斯",
	["Archdruid Kronn"] = "大德鲁伊科罗恩",
	["Selenaxx Foulheart"] = "塞雷纳克斯·腐心",
	["Trioch the Devourer"] = "吞噬者提里奥克",
	["Ursol"] = "乌索尔",
	["Peroth'arn"] = "佩罗萨恩",
	
	["Frostmane Hollow"] = "霜鬃峡谷",
	["Handler Oboka"] = "训练师奥博卡",
	["Tan'sha the Sleek"] = "灵动的坦莎",
	["Kan'za the Seer"] = "先知坎扎",
	["Battlemaster Ubukaz"] = "战场主宰乌布卡兹",
	["Hailar the Frigid"] = "冰冷的海乐",
	
	["Windhorn Canyon"] = "风角峡谷",
	["Pathun Duskhide"] = "帕斯恩·暮皮",
	["Ahgk'tos the Pure"] = "纯洁者阿格图斯",
	["Ambassador Vortalus"] = "沃尔塔卢斯大使",
	["Walgan Bloodcaller"] = "瓦尔根·唤血者",
	["Bonespeaker Narlgom"] = "骨语者纳尔格姆",
	["Prophet Stormhoof"] = "雷角",
	["Chieftain Shalk Blackwind"] = "酋长沙尔克·黑风",

	["Ezzel Darkbrewer"] = "伊泽尔·黑酿",
	["Broodcommander Axelus"] = "巢穴指挥官阿克塞勒斯",
} end)