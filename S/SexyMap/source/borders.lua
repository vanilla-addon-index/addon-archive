local _G = getfenv(0)
local defaultSize = 180
local math = math
local sin = math.sin
local cos = math.cos
borderTextures = {
	["AURARUNE256.BLP"] = "SPELLS\\AURARUNE256.BLP",
	["AuraRune256b.blp"] = "SPELLS\\AuraRune256b.blp",
	["AuraRune_A.blp"] = "SPELLS\\AuraRune_A.blp",
	["AuraRune_B.blp"] = "SPELLS\\AuraRune_B.blp",
	["Elite"] = "Interface\\TargetingFrame\\UI-TargetingFrame-Elite",
	["GENERICGLOW5.BLP"] = "PARTICLES\\GENERICGLOW5.BLP",
	["GENERICGLOW64.BLP"] = "SPELLS\\GENERICGLOW64.BLP",
	["gradientCircle.blp"] = "Interface\\GLUES\\MODELS\\UI_Tauren\\gradientCircle.blp",
	["Nature_Rune_128.blp"] = "SPELLS\\Nature_Rune_128.blp",
	["Rare"] = "Interface\\TargetingFrame\\UI-TargetingFrame-Rare",
	["ShamanStoneAir.blp"] = "World\\GENERIC\\PASSIVEDOODADS\\ShamanStone\\ShamanStoneAir.blp",
	["SHAMANSTONEEARTH.blp"] = "World\\GENERIC\\PASSIVEDOODADS\\ShamanStone\\SHAMANSTONEEARTH.blp",
	["ShamanStoneFlame.blp"] = "World\\GENERIC\\PASSIVEDOODADS\\ShamanStone\\ShamanStoneFlame.blp",
	["ShamanStoneWater.blp"] = "World\\GENERIC\\PASSIVEDOODADS\\ShamanStone\\ShamanStoneWater.blp",
	["Shockwave4.blp"] = "SPELLS\\Shockwave4.blp",
	["Shockwave_blue.blp"] = "World\\ENVIRONMENT\\DOODAD\\GENERALDOODADS\\ELEMENTALRIFTS\\Shockwave_blue.blp",
	["SHOCKWAVE_INVERTGREY.BLP"] = "SPELLS\\SHOCKWAVE_INVERTGREY.BLP",
	["TREANTLEAVES.BLP"] = "SPELLS\\TREANTLEAVES.BLP",
	["T_VFX_HERO_CIRCLE.BLP"] = "SPELLS\\T_VFX_HERO_CIRCLE.BLP",
	-- Diablo preset textures (addon-local BLP files)
	["MAP_OVERLAY"] = "Interface\\AddOns\\SexyMap\\media\\map_overlay",
	["MAP_GLOSS"] = "Interface\\AddOns\\SexyMap\\media\\map_gloss",
	["MAP_INNERSHADOW"] = "Interface\\AddOns\\SexyMap\\media\\map_innershadow",
	["ZAHNRAD"] = "Interface\\AddOns\\SexyMap\\media\\zahnrad",
	-- Renaitre textures (addon-local BLP files)
	["RENAITRE_FADE_BORDER"] = "Interface\\AddOns\\SexyMap\\media\\RenaitreFadeBorder",
	["RENAITRE_FADE_NORMAL"] = "Interface\\AddOns\\SexyMap\\media\\RenaitreFadeNormal",
	["RENAITRE_FADE_GLOSS"] = "Interface\\AddOns\\SexyMap\\media\\RenaitreFadeGloss",
	-- Classic media textures (addon-local BLP files)
	["AUCHINDOUN_VORTEXCLOUD01"] = "Interface\\AddOns\\SexyMap\\media\\classic\\auchindoun_vortexcloud01",
	["AURA_01"] = "Interface\\AddOns\\SexyMap\\media\\classic\\aura_01",
	["BLADESEDGEPLANET04"] = "Interface\\AddOns\\SexyMap\\media\\classic\\bladesedgeplanet04",
	["DEATHSKY_VORTEXCLOUD01"] = "Interface\\AddOns\\SexyMap\\media\\classic\\deathsky_vortexcloud01",
	["DEATHWINGFIGHTSKY_CLOUDSMASK03"] = "Interface\\AddOns\\SexyMap\\media\\classic\\deathwingfightsky_cloudsmask03",
	["DEATHWINGFIGHTSKY_PARTICLECLOUD"] = "Interface\\AddOns\\SexyMap\\media\\classic\\deathwingfightsky_particlecloud",
	["DEEPHOLMSKY_NEBULA01"] = "Interface\\AddOns\\SexyMap\\media\\classic\\deepholmsky_nebula01",
	["GALAXY_02"] = "Interface\\AddOns\\SexyMap\\media\\classic\\galaxy_02",
	["HELLFIREPLANET03"] = "Interface\\AddOns\\SexyMap\\media\\classic\\hellfireplanet03",
	["HELLFIREPLANET_BLUE01"] = "Interface\\AddOns\\SexyMap\\media\\classic\\hellfireplanet_blue01",
	["HELLFIREPLANET_RED01"] = "Interface\\AddOns\\SexyMap\\media\\classic\\hellfireplanet_red01",
	["ICECROWN_CLOUDSA02_MASK01"] = "Interface\\AddOns\\SexyMap\\media\\classic\\icecrown_cloudsa02_mask01",
	["ICECROWN_CLOUDSA02_MASK02"] = "Interface\\AddOns\\SexyMap\\media\\classic\\icecrown_cloudsa02_mask02",
	["LIGHTNING_NEW"] = "Interface\\AddOns\\SexyMap\\media\\classic\\lightning_new",
	["ROGUERUNE2"] = "Interface\\AddOns\\SexyMap\\media\\classic\\roguerune2",
	["SWATHSMALLSTONES"] = "Interface\\AddOns\\SexyMap\\media\\classic\\swathsmallstones",
	["TREANTLEAVES"] = "Interface\\AddOns\\SexyMap\\media\\classic\\treantleaves",
	["T_VFX_HERO_CIRCLE"] = "Interface\\AddOns\\SexyMap\\media\\classic\\t_vfx_hero_circle",
	["UL_SPINNINGROOMRINGS_RING07"] = "Interface\\AddOns\\SexyMap\\media\\classic\\ul_spinningroomrings_ring07",
	["WINTERGRASP_CLOUDMASK01"] = "Interface\\AddOns\\SexyMap\\media\\classic\\wintergrasp_cloudmask01",
}

function CCreateBorder(t)
	texture = _G[t.name] or Minimap:CreateTexture(t.name)
	-- Clamp scale to 0.0 minimum; 0.0 means invisible
	local effectiveScale = t.scale or 1
	if effectiveScale < 0 then effectiveScale = 0 end
	if effectiveScale == 0 then
		texture:Hide()
		-- Still register in CTextures so we can update later
		texture.settings = t
		texture.angle = 0
		CTextures[t.name] = t.name
		return
	end
	texture:Show()
	texture:SetBlendMode(t.blendMode or "ADD")
	local texPath = borderTextures[t.texture] or t.texture
	-- For addon-local paths (extensionless), append .blp for SetTexture compatibility in classic WoW
	if texPath and not string.find(string.lower(texPath), ".blp") and not string.find(string.lower(texPath), ".tga") and string.find(texPath, "AddOns") then
		texPath = texPath .. ".blp"
	end
	texture:SetTexture(texPath)
	texture:SetWidth((t.width or defaultSize) * effectiveScale)
	texture:SetHeight((t.height or defaultSize) * effectiveScale)
	texture:SetVertexColor(t.r or 1, t.g or 1, t.b or 1)
	texture:SetAlpha(t.a or 1)
	texture:SetPoint(t.anchorPoint or "CENTER", 
		t.relativeTo or Minimap, 
		t.relativePoint or "CENTER",
		t.xOffset or 0, t.yOffset or 0)
	texture:SetDrawLayer(t.drawLayer or "ARTWORK")
	texture.settings = t
	texture.angle = 0
	CTextures[t.name] = t.name
	if t.rotSpeed and t.rotSpeed ~= 0 and not t.disableRotation then
		CRotateTextures[t.name] = t.rotSpeed
	end
	if t.disableRotation then
		texture:SetTexCoord(0, 1, 0, 1)
	end
	if t.rotation then
		CRotateTexture(texture, t.rotation)
	end
end

function CRotateTexture(self, change)
	self.angle = (self.angle or 0) - change
	if self.angle < 0 then self.angle = self.angle + 360 end
	if self.angle > 360 then self.angle = self.angle - 360 end
	--self.angle = self.angle % 360
	s = sin(rad(self.angle))
	c = cos(rad(self.angle))
	self:SetTexCoord(
		0.5 - s, 0.5 + c, --Top Left Corner
		0.5 + c, 0.5 + s, --Bottom Left Corner
		0.5 - c, 0.5 - s, --Top Right Corner
		0.5 + s, 0.5 - c  --Bottom Right Corner
	)
end
