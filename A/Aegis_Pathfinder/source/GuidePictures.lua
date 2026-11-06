--[[
	GuidePictures.lua -- the picture of a guide, at the top of the guide
	browser's right pane.

	Every picture is the game's art, from the client's own files but for
	Turtle WoW's dungeon loading screens and custom zone maps, which the
	addon carries:

	  * a zone guide shows its zone's map with every area explored -- the
	    map's twelve tiles, and each area's overlay where pfUI's map reveal
	    data puts it (MapOverlays.lua) -- cropped to the explored part; a
	    custom zone, Turtle WoW's explored map of it (Theme.zonemap);
	  * a dungeon guide shows its dungeon's loading screen, or one of the
	    client's generic ones;
	  * a class quest guide shows the class's crest and colour, and the
	    chain's spell or reward;
	  * a profession guide shows the profession's icon;
	  * anything else, and nothing at all, the addon's logo.
]]

local AegisPathfinder = AegisPathfinder
local Theme = AegisPathfinder.Theme

local Pictures = {}
AegisPathfinder.Pictures = Pictures

local ICONS = "Interface\\Icons\\"
local WORLDMAP = "Interface\\WorldMap\\"
local SCREENS = "Interface\\Glues\\LoadingScreens\\"
local CREST = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"

--[[ Loading screens ---------------------------------------------------------

	1.12 has a loading screen of its own for a few instances only, the raids
	and the later dungeons; every other instance used one of six generic
	ones. Which generic one each dungeon had is a best guess from the art --
	the cave for the caves, the ruined city for the troll and titan ruins.
	Turtle WoW shows a loading screen of its own for every dungeon, which
	the addon carries (Theme.loadscreen); this is for one it has none for,
	and for the raids, when they have guides. ]]
Pictures.SCREEN_FOR = {
	["Ragefire Chasm"] = "LoadScreenCave",
	["Wailing Caverns"] = "LoadScreenCave",
	["The Deadmines"] = "LoadScreenCave",
	["Blackfathom Deeps"] = "LoadScreenCave",
	["Razorfen Kraul"] = "LoadScreenCave",
	["Razorfen Downs"] = "LoadScreenCave",
	["Maraudon"] = "LoadScreenCave",
	["Scarlet Monastery"] = "LoadScreenMonastery",
	["Uldaman"] = "LoadScreenRuinedCity",
	["Zul'Farrak"] = "LoadScreenRuinedCity",
	["Sunken Temple"] = "LoadScreenRuinedCity",
	["Dire Maul"] = "LoadScreenDireMaul",
	["Scholomance"] = "LoadScreenScholomance",
	["Stratholme"] = "LoadScreenStrathome",          -- sic: the client's spelling
	-- The raids, for when they have guides.
	["Onyxia's Lair"] = "LoadScreenCave",
	["Molten Core"] = "LoadScreenMoltenCore",
	["Blackwing Lair"] = "LoadScreenBlackWingLair",
	["Zul'Gurub"] = "LoadScreenZulGurub",
	["Ruins of Ahn'Qiraj"] = "LoadScreenAhnQiraj20man",
	["Temple of Ahn'Qiraj"] = "LoadScreenAhnQiraj40man",
	["Naxxramas"] = "LoadScreenNaxxramas",
}
Pictures.SCREEN_DEFAULT = "LoadScreenDungeon"
--[[ A loading screen is a 512x512 texture the client stretches to 4:3, its
	art between two bars. This is the art's middle at about 16:9, the
	picture's shape. The addon's own pictures are 16:9 already, squeezed into
	2:1, and are shown whole. ]]
Pictures.SCREEN_COORDS = { 0.144, 0.856, 0.2656, 0.7969 }
Pictures.ART_COORDS = { 0, 1, 0, 1 }

--[[ Class quests ------------------------------------------------------------

	The crest is the class's square on the character creation screen's
	sheet. The icon is the chain's spell, mount or reward where it has one,
	by the milestone's name; else one that says the class. ]]
Pictures.CREST_COORDS = {
	WARRIOR = { 0, 0.25, 0, 0.25 },     MAGE    = { 0.25, 0.5, 0, 0.25 },
	ROGUE   = { 0.5, 0.75, 0, 0.25 },   DRUID   = { 0.75, 1, 0, 0.25 },
	HUNTER  = { 0, 0.25, 0.25, 0.5 },   SHAMAN  = { 0.25, 0.5, 0.25, 0.5 },
	PRIEST  = { 0.5, 0.75, 0.25, 0.5 }, WARLOCK = { 0.75, 1, 0.25, 0.5 },
	PALADIN = { 0, 0.25, 0.5, 0.75 },
}
Pictures.CLASS_ICON = {
	WARRIOR = "Ability_Warrior_BattleShout", PALADIN = "Spell_Holy_HolyBolt",
	HUNTER = "Ability_Marksmanship", ROGUE = "Ability_Stealth",
	PRIEST = "Spell_Holy_PowerWordShield", SHAMAN = "Spell_Nature_LightningShield",
	MAGE = "Spell_Frost_FrostBolt02", WARLOCK = "Spell_Shadow_ShadowBolt",
	DRUID = "Spell_Nature_HealingTouch",
}
Pictures.MILESTONE_ICON = {
	["Voidwalker"] = "Spell_Shadow_SummonVoidWalker",
	["Succubus"] = "Spell_Shadow_SummonSuccubus",
	["Felhunter"] = "Spell_Shadow_SummonFelHunter",
	["Felsteed"] = "Spell_Nature_Swiftness",
	["Dreadsteed"] = "Ability_Mount_Dreadsteed",
	["Infernal"] = "Spell_Shadow_SummonInfernal",
	["Doomguard"] = "Spell_Shadow_AntiMagicShell",
	["Bear Form"] = "Ability_Racial_BearForm",
	["Aquatic Form"] = "Ability_Druid_AquaticForm",
	["Cure Poison"] = "Spell_Nature_NullifyPoison",
	["Redemption"] = "Spell_Holy_Resurrection",
	["Warhorse"] = "Spell_Nature_Swiftness",
	["Charger"] = "Ability_Mount_Charger",
	["Sense Undead"] = "Spell_Holy_SenseUndead",
	["Tome of Valor"] = "Spell_Holy_DivineIntervention",
	["Verigan's Fist"] = "INV_Mace_01",
	["Taming the Beast"] = "Ability_Hunter_BeastTaming",
	["Rhok'delar"] = "INV_Weapon_Bow_02",
	["Earth Totem"] = "Spell_Nature_StoneSkinTotem",
	["Fire Totem"] = "Spell_Fire_SearingTotem",
	["Water Totem"] = "INV_Spear_04",
	["Air Totem"] = "Spell_Nature_InvisibilityTotem",
	["Defensive Stance"] = "Ability_Warrior_DefensiveStance",
	["Berserker Stance"] = "Ability_Racial_Avatar",
	["Whirlwind Weapon"] = "Ability_Whirlwind",
	["Benediction"] = "INV_Staff_13",
	["Polymorph: Pig"] = "Spell_Magic_PolymorphPig",
	["Mage's Wand"] = "INV_Wand_01",
	["Poisons"] = "Ability_Poisons",
}

-- Professions, by the first part of a guide's name.
Pictures.PROFESSION_ICON = {
	["Alchemy"] = "Trade_Alchemy", ["Blacksmithing"] = "Trade_BlackSmithing",
	["Enchanting"] = "Trade_Engraving", ["Engineering"] = "Trade_Engineering",
	["Herbalism"] = "Trade_Herbalism", ["Leatherworking"] = "Trade_LeatherWorking",
	["Mining"] = "Trade_Mining", ["Tailoring"] = "Trade_Tailoring",
	["Fishing"] = "Trade_Fishing", ["Cooking"] = "INV_Misc_Food_15",
	["First Aid"] = "Spell_Holy_SealOfSacrifice", ["Skinning"] = "INV_Misc_Pelt_Wolf_01",
	["Jewelcrafting"] = "INV_Misc_Gem_01", ["Survival"] = "Spell_Fire_Fire",
}

--[[ What to show ------------------------------------------------------------ ]]

local CLASS_KEYS = {
	["Warrior"] = "WARRIOR", ["Paladin"] = "PALADIN", ["Hunter"] = "HUNTER",
	["Rogue"] = "ROGUE", ["Priest"] = "PRIEST", ["Shaman"] = "SHAMAN",
	["Mage"] = "MAGE", ["Warlock"] = "WARLOCK", ["Druid"] = "DRUID",
}

-- A dungeon's loading screen: the addon's art for it, else the client's.
local function Screen(dungeon)
	local art = dungeon and Theme.loadscreen[dungeon]
	if art then return { kind = "screen", texture = art, coords = Pictures.ART_COORDS } end
	return { kind = "screen", texture = SCREENS .. (Pictures.SCREEN_FOR[dungeon or ""] or Pictures.SCREEN_DEFAULT),
		coords = Pictures.SCREEN_COORDS }
end

--- The picture for guide `name`: { kind = "map", map }, { kind = "screen",
--- texture, coords } (a loading screen), { kind = "image", texture, coords }
--- (a map the addon carries), { kind = "class", class, icon }, { kind =
--- "icon", icon } or { kind = "logo" }.
function AegisPathfinder:GuidePicture(name)
	if not name or not self.guides or not self.guides[name] then return { kind = "logo" } end
	local cat = self:GetGuideCategory(name)
	local title = self.Browser and self.Browser.Title(name) or name
	if cat == "dungeon" then
		local _, _, dungeon = string.find(title, "^(.-)%s*%(")
		return Screen(dungeon or title)
	elseif cat == "class" then
		local _, _, class, milestone = string.find(title, "^(%a+): (.-)%s*%(")
		local key = CLASS_KEYS[class or ""]
		if key then
			return { kind = "class", class = key,
				icon = ICONS .. (Pictures.MILESTONE_ICON[milestone or ""] or Pictures.CLASS_ICON[key]) }
		end
	elseif cat == "attunement" then
		-- What it opens: "Attunement/Molten Core: Attunement to the Core (55)".
		local _, _, instance = string.find(title, "^(.-):")
		return Screen(instance or title)
	elseif cat == "profession" then
		local _, _, prof = string.find(title, "^(.-)%s*%(")
		local icon = Pictures.PROFESSION_ICON[prof or title]
		if icon then return { kind = "icon", icon = ICONS .. icon } end
	else
		-- A route leg named for a dungeon -- "Optimized/Uldaman (45-46)" --
		-- is its loading screen, not the city its steps start in.
		local dungeon = self.Browser.DungeonIn(title)
		if dungeon then return Screen(dungeon) end
		local zone = self.GuideBrowserZone and self:GuideBrowserZone(name)
		-- A custom zone whose map the client cannot build: the addon's own.
		if zone and Theme.zonemap[zone] then
			return { kind = "image", texture = Theme.zonemap[zone], coords = Pictures.ART_COORDS }
		end
		local info = zone and self.Browser.ZONES[zone]
		-- A custom zone is shown as itself or not at all: one without map
		-- data must not borrow the map of the zone its steps start in.
		if info and not (cat == "turtle" and info[2]) then return { kind = "map", map = info[1] } end
	end
	return { kind = "logo" }
end

--[[ The explored map ----------------------------------------------------------

	The client draws a zone's map as twelve 256px tiles, four across and
	three down, of which the top left 1002x668 is the map. An explored area
	is an overlay over them, cut into 256px tiles of its own, the last ones
	in each row and column only as big as is left -- in files the next power
	of two up, so a texture coordinate crops each. This is the client's own
	WorldMapFrame_Update, without the client having to have seen the area. ]]
Pictures.MAP_W, Pictures.MAP_H = 1002, 668
local PAD = 24            -- map pixels kept round the explored areas
local MIN_CROP = 560      -- the narrowest crop, so a small zone is not blown up

local function ParseOverlay(entry)
	local _, _, tex, w, h, x, y = string.find(entry or "", "^([^:]+):(%d+):(%d+):(%d+):(%d+)$")
	if not tex then return nil end
	return tex, tonumber(w), tonumber(h), tonumber(x), tonumber(y)
end

local function FileSize(pixels)
	local size = 16
	while size < pixels do size = size * 2 end
	return size
end

-- The overlay's last row or column: what is left of `total` after the full tiles.
local function Remainder(total)
	local r = math.mod(total, 256)
	return r == 0 and 256 or r
end

--- The textures that draw `map` explored: { path, x, y, width, height, u, v,
--- base }, in map pixels from its top left; u and v crop each texture's file.
function Pictures.MapPieces(map)
	local out, dir = {}, WORLDMAP .. map .. "\\"
	for i = 1, 12 do
		table.insert(out, { dir .. map .. i, math.mod(i - 1, 4) * 256, math.floor((i - 1) / 4) * 256,
			256, 256, 1, 1, base = true })
	end
	local overlays = AegisPathfinder.MAP_OVERLAYS and AegisPathfinder.MAP_OVERLAYS[map]
	for _, entry in ipairs(overlays or {}) do
		local tex, w, h, x, y = ParseOverlay(entry)
		if tex then
			local wide, tall = math.ceil(w / 256), math.ceil(h / 256)
			for j = 1, tall do
				local ph = j < tall and 256 or Remainder(h)
				for k = 1, wide do
					local pw = k < wide and 256 or Remainder(w)
					table.insert(out, { dir .. tex .. ((j - 1) * wide + k), x + 256 * (k - 1), y + 256 * (j - 1),
						pw, ph, pw / FileSize(pw), ph / FileSize(ph) })
				end
			end
		end
	end
	return out
end

--- The part of `map` a picture `ratio` wide to its height shows: its
--- explored areas and a margin, at the picture's shape, inside the map --
--- the whole map, for one without areas. Left, top, width, height.
function Pictures.Crop(map, ratio)
	local x0, y0, x1, y1
	local overlays = AegisPathfinder.MAP_OVERLAYS and AegisPathfinder.MAP_OVERLAYS[map]
	for _, entry in ipairs(overlays or {}) do
		local tex, w, h, x, y = ParseOverlay(entry)
		if tex then
			x0, y0 = math.min(x0 or x, x), math.min(y0 or y, y)
			x1, y1 = math.max(x1 or x + w, x + w), math.max(y1 or y + h, y + h)
		end
	end
	local MW, MH = Pictures.MAP_W, Pictures.MAP_H
	if not x0 then x0, y0, x1, y1 = 0, 0, MW, MH end
	x0, y0 = math.max(0, x0 - PAD), math.max(0, y0 - PAD)
	x1, y1 = math.min(MW, x1 + PAD), math.min(MH, y1 + PAD)
	local cw = math.max(x1 - x0, (y1 - y0) * ratio, MIN_CROP)
	cw = math.min(cw, MW, MH * ratio)
	local ch = cw / ratio
	local cx = math.max(0, math.min((x0 + x1 - cw) / 2, MW - cw))
	local cy = math.max(0, math.min((y0 + y1 - ch) / 2, MH - ch))
	return cx, cy, cw, ch
end

--[[ The picture frame ---------------------------------------------------------- ]]

-- Texture `i` of `pool`, made on `canvas` the first time it is wanted.
local function Pooled(pool, i, canvas, layer)
	if not pool[i] then pool[i] = canvas:CreateTexture(nil, layer) end
	return pool[i]
end

local function HideFrom(pool, i)
	for n = i, table.getn(pool) do pool[n]:Hide() end
end

local function DrawMap(pic, map)
	local cx, cy, cw, ch = Pictures.Crop(map, pic.w / pic.h)
	local scale = pic.w / cw
	local nb, no = 0, 0
	for _, p in ipairs(Pictures.MapPieces(map)) do
		local x, y, w, h = p[2], p[3], p[4], p[5]
		-- Only what falls in the crop; the clip hides the edges of the rest.
		if x < cx + cw and x + w > cx and y < cy + ch and y + h > cy then
			local t
			if p.base then
				nb = nb + 1
				t = Pooled(pic.tiles, nb, pic.canvas, "BORDER")
			else
				no = no + 1
				t = Pooled(pic.overlays, no, pic.canvas, "ARTWORK")
			end
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", pic.canvas, "TOPLEFT", (x - cx) * scale, (cy - y) * scale)
			t:SetWidth(w * scale)
			t:SetHeight(h * scale)
			t:SetTexture(p[1])
			t:SetTexCoord(0, p[6], 0, p[7])
			t:Show()
		end
	end
	HideFrom(pic.tiles, nb + 1)
	HideFrom(pic.overlays, no + 1)
end

-- An icon framed in the theme's border, for the class and profession pictures.
local function ShowIcon(pic, path, size)
	pic.iconFrame:SetWidth(size + 4)
	pic.iconFrame:SetHeight(size + 4)
	pic.icon:SetTexture(path)
	pic.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	pic.iconFrame:Show()
end

local function Paint(pic, picture)
	pic.kind = picture.kind
	for _, part in ipairs({ pic.screen, pic.strip, pic.crest, pic.logo }) do part:Hide() end
	pic.iconFrame:Hide()
	HideFrom(pic.tiles, 1)
	HideFrom(pic.overlays, 1)
	Theme:Tint(pic.bg, "panel3")
	if picture.kind == "map" then
		DrawMap(pic, picture.map)
	elseif picture.kind == "screen" or picture.kind == "image" then
		pic.screen:SetTexture(picture.texture)
		local c = picture.coords or Pictures.SCREEN_COORDS
		pic.screen:SetTexCoord(c[1], c[2], c[3], c[4])
		pic.screen:Show()
	elseif picture.kind == "class" or picture.kind == "icon" then
		local color = picture.class and Theme.CLASS_COLORS[picture.class] or Theme.BADGES.pf.bg
		pic.bg:SetVertexColor(color[1] * 0.22, color[2] * 0.22, color[3] * 0.22, 1)
		Theme:Tint(pic.strip, color)
		pic.strip:Show()
		if picture.class then
			local c = Pictures.CREST_COORDS[picture.class]
			pic.crest:SetTexCoord(c[1], c[2], c[3], c[4])
			pic.crest:Show()
		end
		ShowIcon(pic, picture.icon, math.floor(pic.h * 0.56))
	else
		pic.logo:Show()
	end
end

--- A picture `w` by `h` on `parent`. `pic:SetGuide(name)` shows guide
--- `name`'s; nil shows the logo.
function Pictures:Create(parent, w, h)
	local pic = CreateFrame("Frame", nil, parent)
	pic:SetWidth(w)
	pic:SetHeight(h)
	pic.w, pic.h = w, h

	pic.bg = pic:CreateTexture(nil, "BACKGROUND")
	pic.bg:SetTexture(Theme.texture.solid)
	pic.bg:SetAllPoints(pic)

	-- A scroll frame clips what is drawn in it, which is how the map's tiles
	-- are cut to the picture's edges.
	local clip = CreateFrame("ScrollFrame", nil, pic)
	clip:SetWidth(w)
	clip:SetHeight(h)
	clip:SetPoint("TOPLEFT", pic, "TOPLEFT", 0, 0)
	local canvas = CreateFrame("Frame", nil, clip)
	canvas:SetWidth(w)
	canvas:SetHeight(h)
	clip:SetScrollChild(canvas)
	pic.clip, pic.canvas = clip, canvas
	pic.tiles, pic.overlays = {}, {}

	pic.screen = canvas:CreateTexture(nil, "ARTWORK")
	pic.screen:SetAllPoints(canvas)

	pic.strip = canvas:CreateTexture(nil, "ARTWORK")
	pic.strip:SetTexture(Theme.texture.solid)
	pic.strip:SetHeight(3)
	pic.strip:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, 0)
	pic.strip:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", 0, 0)

	pic.crest = canvas:CreateTexture(nil, "ARTWORK")
	pic.crest:SetTexture(CREST)
	pic.crest:SetWidth(30)
	pic.crest:SetHeight(30)
	pic.crest:SetPoint("TOPLEFT", canvas, "TOPLEFT", 10, -12)

	local iconFrame = CreateFrame("Frame", nil, canvas)
	iconFrame:SetPoint("CENTER", canvas, "CENTER", 0, 0)
	local edge = iconFrame:CreateTexture(nil, "BACKGROUND")
	edge:SetTexture(Theme.texture.solid)
	edge:SetAllPoints(iconFrame)
	Theme:Tint(edge, "border")
	pic.icon = iconFrame:CreateTexture(nil, "ARTWORK")
	pic.icon:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 2, -2)
	pic.icon:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -2, 2)
	pic.iconFrame = iconFrame

	pic.logo = canvas:CreateTexture(nil, "ARTWORK")
	pic.logo:SetTexture(Theme.texture.logo)
	pic.logo:SetWidth(math.floor(h * 0.8))
	pic.logo:SetHeight(math.floor(h * 0.8))
	pic.logo:SetPoint("CENTER", canvas, "CENTER", 0, 0)

	function pic:SetGuide(name)
		self.guide = name
		Paint(self, AegisPathfinder:GuidePicture(name))
	end

	--- A dungeon's loading screen, as its guide has it (the Gear Finder's
	--- suggested dungeon); nil shows the logo.
	function pic:SetDungeon(name)
		self.guide = nil
		Paint(self, name and Screen(name) or { kind = "logo" })
	end

	pic:SetGuide(nil)
	return pic
end
