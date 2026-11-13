local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local HookAddonOrVariable = ShaguTweaks.HookAddonOrVariable
local GetExpansion = ShaguTweaks.GetExpansion
local AddBorder = ShaguTweaks.AddBorder

local module = ShaguTweaks:register({
  title = T["Darkened UI"],
  description = T["Turns the entire interface into darker colors."],
  expansions = { ["vanilla"] = true },
  category = T["Interface"],
  enabled = nil,
  config = {
    ["darkmode.color"] = { r = .3, g = .3, b = .3, a = .9 }
  }
})

-- Golden UI runs the same recolor pass with a gold palette (like the WoW
-- Forever client): textures are tinted gold, borders and tooltip edges get a
-- softer gold, and backgrounds keep their own colors.
local golden = ShaguTweaks:register({
  title = T["Golden UI"],
  description = T["Turns the borders of the interface, tooltips and dialogs gold, like the WoW Forever client. Darkened UI takes priority when both are enabled."],
  expansions = { ["vanilla"] = true },
  category = T["Interface"],
  enabled = nil,
  config = {
    ["goldmode.color"] = { r = 1, g = .78, b = .4, a = 1 },
    ["goldmode.border"] = { r = .8, g = .62, b = .32, a = 1 },
    ["goldmode.bar"] = { r = .8, g = .63, b = .62, a = 1 },
  }
})

-- Active palette, set by whichever of the two modules is enabled:
-- tint goes on textures, edge on backdrop borders and added button borders.
local tint, edge

local function StyleActionButton(button, texture, extra)
  if not button or not texture then return end
  texture:SetWidth(60)
  texture:SetHeight(60)
  texture:ClearAllPoints()
  texture:SetPoint("CENTER", button, "CENTER", 0, 0)
  AddBorder(button, 3, extra and edge or nil)
end

local blacklist = {
  ["Solid Texture"] = true,
  ["WHITE8X8"] = true,
  ["StatusBar"] = true,
  ["BarFill"] = true,
  ["Portrait"] = true,
  ["Button"] = true,
  ["Icon"] = true,
  ["AddOns"] = true,
  ["StationeryTest"] = true,
  ["TargetDead"] = true, -- LootFrame Icon
  ["^KeyRing"] = true, -- bag frame
  ["GossipIcon"] = true,
  ["WorldMap\\(.+)\\"] = true,
  ["PetHappiness"] = true,
  ["Elite"] = true,
  ["Rare"] = true,
  ["ColorPickerWheel"] = true,
  ["ComboPoint"] = true,
  ["Skull"] = true,

  -- LFT:
  ["battlenetworking0"] = true,
  ["damage"] = true,
  ["tank"] = true,
  ["healer"] = true,
}

local regionskips = {
  -- colorpicker gradient
  ["ColorPickerFrame"] = { [15] = true },
  -- EQL3: background art tiles on the main frame - BookIcon(1), TopLeft(2), Top_Switch_Off(3), BottomLeft(4), Bottom_Switch_Off(5), Top_Switch_On(6), Bottom_Switch_On(7)
  ["EQL3_QuestLogFrame"] = { [1]=true, [2]=true, [3]=true, [4]=true, [5]=true, [6]=true, [7]=true },
  -- EQL3: parchment tiles on the description panel - TopMiddle(1), TopRight(2), BottomMiddle(3), BottomRight(4)
  ["EQL3_QuestLogFrame_Description"] = { [1]=true, [2]=true, [3]=true, [4]=true },
}

local backgrounds = {
  ["^ItemTextFrame$"] = { 300, 355, 24, -74 },
}

local borders = {
  ["ShapeshiftButton"] = 3,
  ["BuffButton"] = 3,
  ["TargetFrameBuff"] = 3,
  ["TempEnchant"] = 3,
  ["SpellButton"] = 3,
  ["SpellBookSkillLineTab"] = 3,
  ["ActionButton%d+$"] = 3,
  ["MultiBar(.+)Button%d+$"] = 3,
  ["KeyRingButton"] = 2,
  ["ActionBarUpButton"] = -3,
  ["ActionBarDownButton"] = -3,
  ["MainMenuBarPerformanceBarFrameButton"] = { -12, -1, -8, 4 },
  ["Character(.+)Slot$"] = 3,
  ["Inspect(.+)Slot$"] = 3,
  ["ContainerFrame(.+)Item"] = 3,
  ["MainMenuBarBackpackButton$"] = 3,
  ["CharacterBag(.+)Slot$"] = 3,
  ["ChatFrame(.+)Button"] = -2,
  ["PetFrameHappiness"] = 2,
  ["MicroButton"] = { -21, 0, 0, 0 },
  -- VCB's buff and weapon-buff buttons, like the Blizzard buff buttons
  ["^VCB_BF_BUFF_BUTTON%d+$"] = 3,
  ["^VCB_BF_WEAPON_BUTTON%d+$"] = 3,
}

local addonframes = {
  ["Blizzard_TalentUI"] = { "TalentFrame" },
  ["Blizzard_AuctionUI"] = { "AuctionFrame", "AuctionDressUpFrame" },
  ["Blizzard_CraftUI"] = { "CraftFrame" },
  ["Blizzard_InspectUI"] = {
    "InspectPaperDollFrame",
    "InspectHonorFrame",
    "InspectFrameTab1",
    "InspectFrameTab2",
  },
  ["Blizzard_MacroUI"] = { "MacroFrame", "MacroPopupFrame" },
  ["Blizzard_RaidUI"] = { "ReadyCheckFrame" },
  ["Blizzard_TradeSkillUI"] = { "TradeSkillFrame" },
  ["Blizzard_TrainerUI"] = { "ClassTrainerFrame" },
  ["Artisan"] = { "ArtisanFrame" },
}

-- Turtle WoW exposes these extra inspect pages. Keep them out of the generic
-- Vanilla path so missing Turtle-only frames don't leave compatibility lurkers
-- registered for the whole session.
local isTurtle = TargetHPText and TargetHPPercText
if isTurtle then
  table.insert(addonframes["Blizzard_InspectUI"], "InspectArenaFrame")
  table.insert(addonframes["Blizzard_InspectUI"], "InspectTalentsFrame")
  table.insert(addonframes["Blizzard_InspectUI"], "InspectFrameTab3")
  table.insert(addonframes["Blizzard_InspectUI"], "InspectFrameTab4")
end

-- sizing is a bit different on tbc
if GetExpansion() == "tbc" then
  borders["BuffButton"] = 2
  borders["TempEnchant"] = 2
  borders["MicroButton"] = { -21, 0, 0, 0 }
end

-- Frame art that ships inside an addon (the "AddOns" entry above skips
-- addon textures, which are mostly icons) but should follow the palette.
local whitelist = {
  "outfitter\\textures\\outfitterframe",
  "outfitter\\textures\\scrollbartrench",
  -- Artisan swaps in its own lower half of the profession window
  "artisan\\textures\\bottomleft",
  "artisan\\textures\\bottomright",
  -- RollFor's classic loot window
  "rollfor\\assets\\og-loot-frame",
}

-- Addon windows that build their rows while opening: recolored every time
-- they are shown (and once more on the next frame, after the rows exist).
local showframes = {
  ["RollForLootFrameHeader"] = true,
}

local PATH_CACHE_LIMIT = 256
local pathCache, pathKeys, pathCursor = {}, {}, 0
local function ClassifyPath(path)
  local result = pathCache[path]
  local capture = ShaguTweaks.RecolorCapture
  if capture then
    if result then capture.cacheHits = capture.cacheHits + 1
    else capture.cacheMisses = capture.cacheMisses + 1 end
  end
  if result then return result end
  local lower = string.lower(path)
  result = 3 -- Candidate: name exclusions must still be evaluated per region.
  if string.find(lower, "interface\\questframe\\ui-questlog-empty-", 1, true)
    or string.find(lower, "interface\\stationery\\", 1, true)
    or string.find(lower, "interface\\mailframe\\mailitemborder", 1, true) then
    result = 2 -- Paper/insets always remain native.
  else
    for i = 1, table.getn(whitelist) do
      if string.find(lower, whitelist[i], 1, true) then result = 1; break end
    end
    if result == 3 then
      for entry in pairs(blacklist) do
        if string.find(path, entry, 1) then result = 2; break end
      end
    end
  end
  pathCursor = math.mod(pathCursor, PATH_CACHE_LIMIT) + 1
  local previous = pathKeys[pathCursor]
  if previous then pathCache[previous] = nil end
  pathKeys[pathCursor], pathCache[path] = path, result
  return result
end
local function IsBlacklisted(texture)
  local path = texture:GetTexture()
  if type(path) ~= "string" then return true end
  local name = texture:GetName()
  if name and string.find(name, "StationeryBackground", 1, true) then return true end
  local result = ClassifyPath(path)
  if result == 1 then return nil end -- Explicit artwork whitelist wins over names.
  if result == 2 then return true end
  if name then
    for entry in pairs(blacklist) do
      if string.find(name, entry, 1) then return true end
    end
  end
  return nil
end

local function AddSpecialBackground(frame, w, h, x, y)
  frame.Material = frame.Material or frame:CreateTexture(nil, "OVERLAY")
  frame.Material:SetTexture("Interface\\Stationery\\StationeryTest1")
  frame.Material:SetWidth(w)
  frame.Material:SetHeight(h)
  frame.Material:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
  frame.Material:SetVertexColor(.8, .8, .8)
end

local function IsSlotArtwork(path)
  if type(path) ~= "string" then return end
  path = string.lower(path)
  return string.find(path, "interface\\buttons\\ui-slot-background", 1, true)
    or string.find(path, "bagshui\\images\\itemslot\\emptyslot", 1, true)
end

-- Leave the original artwork white. Four narrow copies color only its rim.
-- Anchor to the owning button (not a Texture region), so pooled Bagshui
-- buttons carry every strip with them when resized, moved or hidden.
local function TintSlotBorder(texture, button)
  local path = texture:GetTexture()
  local strips = texture.stSlotEdges
  if not IsSlotArtwork(path) then
    if strips then
      for i = 1, 4 do strips[i]:Hide() end
    end
    return
  end
  if not strips then
    strips = {}
    texture.stSlotEdges = strips
    for i = 1, 4 do
      strips[i] = button:CreateTexture(nil, "BORDER")
      strips[i].stSlotEdge = true
    end
    strips[1]:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
    strips[1]:SetPoint("TOPRIGHT", button, "TOPRIGHT", 1, 1)
    strips[1]:SetHeight(3)
    strips[2]:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", -1, -1)
    strips[2]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
    strips[2]:SetHeight(3)
    strips[3]:SetPoint("TOPLEFT", button, "TOPLEFT", -1, -2)
    strips[3]:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", -1, 2)
    strips[3]:SetWidth(3)
    strips[4]:SetPoint("TOPRIGHT", button, "TOPRIGHT", 1, -2)
    strips[4]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, 2)
    strips[4]:SetWidth(3)
  end
  local left, top, bottomLeft, bottom, right = texture:GetTexCoord()
  local w, h = button:GetWidth() + 2, button:GetHeight() + 2
  if w <= 6 or h <= 6 then w, h = 39, 39 end
  local dx, dy = (right - left) * 3 / w, (bottom - top) * 3 / h
  texture:SetVertexColor(1, 1, 1, 1)
  strips[1]:SetTexCoord(left, right, top, top + dy)
  strips[2]:SetTexCoord(left, right, bottom - dy, bottom)
  strips[3]:SetTexCoord(left, left + dx, top + dy, bottom - dy)
  strips[4]:SetTexCoord(right - dx, right, top + dy, bottom - dy)
  for i = 1, 4 do
    strips[i]:SetTexture(path)
    strips[i]:SetVertexColor(edge.r, edge.g, edge.b, 1)
    strips[i]:SetAlpha(texture:GetAlpha())
    strips[i]:Show()
  end
end

-- TrinketMenu owns its styling; its future fork must not compete with this
-- palette, including the initial recursive pass over UIParent.
local function IsExcludedFrame(frame)
  local name = frame and frame.GetName and frame:GetName()
  return name and string.find(name, "TrinketMenu", 1, true) == 1
end

-- The Spellbook's metal frame and torn paper share four 256px-high tiles.
local spellbookPaper = {
  topleft = {22, 74, 256, 256, 256},
  topright = {0, 74, 85, 256, 128},
  botleft = {22, 0, 256, 175, 256},
  botright = {0, 0, 85, 175, 128},
}

local function RestoreSpellbookParchment(frame, source)
  if source.stSpellbookPaper then return end
  local path = source:GetTexture()
  if type(path) ~= "string" then return end
  local _, _, side = string.find(string.lower(path), "^interface\\spellbook\\ui%-spellbookpanel%-(%a+)$")
  local crop = spellbookPaper[side]
  if not crop then return end
  local width, height = source:GetWidth(), source:GetHeight()
  if not width or width <= 0 or not height or height <= 0 then return end

  -- Keep the art below the paper and the page number above it.
  source:SetDrawLayer("BORDER")
  if _G.SpellBookPageText then _G.SpellBookPageText:SetDrawLayer("OVERLAY") end
  local paper = frame:CreateTexture(nil, "ARTWORK")
  paper.stOriginalQuestPaper = true
  paper:SetTexture(path)
  paper:SetVertexColor(1, 1, 1, 1)
  local x1, y1, x2, y2, tileWidth = unpack(crop)
  local sx, sy = width / tileWidth, height / 256
  paper:SetTexCoord(x1 / tileWidth, x2 / tileWidth, y1 / 256, y2 / 256)
  paper:SetWidth((x2 - x1) * sx)
  paper:SetHeight((y2 - y1) * sy)
  paper:SetPoint("TOPLEFT", source, "TOPLEFT", x1 * sx, -y1 * sy)
  source.stSpellbookPaper = paper
end

local function RestoreQuestParchment(frame)
  local name = frame.GetName and frame:GetName()
  if not name or not (string.find(name, "^QuestFrame.*Panel$")
    or name == "GossipFrameGreetingPanel") then return end
  for _, source in pairs({frame:GetRegions()}) do
    local path = source.GetTexture and source:GetTexture()
    if type(path) == "string" and not source.stQuestPaper and not source.stOriginalQuestPaper then
      local lower = string.lower(path)
      local left = string.find(lower, "%-topleft$") or string.find(lower, "%-botleft$")
      local right = string.find(lower, "%-topright$") or string.find(lower, "%-botright$")
      local top = string.find(lower, "%-topleft$") or string.find(lower, "%-topright$")
      if (left or right) and (string.find(lower, "quest", 1, true) or string.find(lower, "gossip", 1, true)) then
        -- Native 256px tiles contain both the frame and torn parchment.
        -- Copy only the paper area; leave the palette on the outer artwork.
        local x1, x2 = left and 22 or 0, left and 256 or 67
        -- Native paper starts below the header and includes the torn lower
        -- edge through row 159. Stopping at 148 leaves a tinted bottom band.
        local y1, y2 = top and 82 or 0, top and 256 or 160
        -- Use a higher layer than both the native BACKGROUND tiles and
        -- BORDER material textures. Equal-layer texture batching can draw
        -- tinted native tiles over only some of our restored paper pieces.
        local paper = frame:CreateTexture(nil, "ARTWORK")
        paper.stOriginalQuestPaper = true
        paper:SetTexture(path)
        local tileWidth = left and 256 or 128
        paper:SetTexCoord(x1/tileWidth, x2/tileWidth, y1/256, y2/256)
        local sx, sy = source:GetWidth()/tileWidth, source:GetHeight()/256
        paper:SetWidth((x2-x1)*sx)
        paper:SetHeight((y2-y1)*sy)
        paper:SetPoint("TOPLEFT", source, "TOPLEFT", x1*sx, -y1*sy)
        paper:SetVertexColor(1, 1, 1, 1)
        source.stQuestPaper = paper
      end
    end
  end
end

local function RestoreQuestLogParchment(frame)
  if not frame.GetName or frame:GetName() ~= "QuestLogFrame" then return end
  for _, source in pairs({frame:GetRegions()}) do
    local path = source.GetTexture and source:GetTexture()
    if type(path) == "string" and not source.stQuestLogCrops and not source.stOriginalQuestPaper then
      local lower = string.lower(path)
      local crops, tileWidth
      -- Turtle's two native tiles, verified against its shipped artwork.
      -- Keep the list surface and both parchment halves; exclude metal rims.
      if string.find(lower, "interface\\questframe\\ui-questlog-left", 1, true)
        and string.find(lower, "ui%-questlog%-left$") then
        crops, tileWidth = {{19,74,320,436},{348,74,512,456}}, 512
      elseif string.find(lower, "interface\\questframe\\ui-questlog-right", 1, true)
        and string.find(lower, "ui%-questlog%-right$") then
        crops, tileWidth = {{0,74,136,456}}, 256
      end
      if crops then
        local w,h = source:GetWidth(), source:GetHeight()
        if w and h and w > 0 and h > 0 then
          source.stQuestLogCrops = {}
          for _, rect in ipairs(crops) do
            local paper = frame:CreateTexture(nil, "OVERLAY")
            paper.stOriginalQuestPaper = true
            paper:SetTexture(path)
            paper:SetTexCoord(rect[1]/tileWidth,rect[3]/tileWidth,rect[2]/512,rect[4]/512)
            paper:SetWidth((rect[3]-rect[1])*w/tileWidth)
            paper:SetHeight((rect[4]-rect[2])*h/512)
            paper:SetPoint("TOPLEFT",source,"TOPLEFT",rect[1]*w/tileWidth,-rect[2]*h/512)
            paper:SetVertexColor(1,1,1,1)
            table.insert(source.stQuestLogCrops,paper)
          end
        end
      end
    end
  end
end

local function DarkenFrame(frame, r, g, b, a, scan)
  -- dont't do anything if neither Darkened UI nor Golden UI is enabled
  if not tint then return end
  if IsExcludedFrame(frame) then return end
  local capture = ShaguTweaks.RecolorCapture
  if capture and frame then
    if not scan then
      scan = capture.rootIndex[frame]
      if not scan then
        scan = { name = frame.GetName and frame:GetName() or tostring(frame), calls = 0, frames = 0, regions = 0, tables = 0 }
        capture.rootIndex[frame] = scan
        table.insert(capture.roots, scan)
      end
      scan.calls = scan.calls + 1
    end
    scan.frames = scan.frames + 1
    capture.frameVisits = capture.frameVisits + 1
    if capture.seen[frame] then capture.repeatVisits = capture.repeatVisits + 1
    else capture.seen[frame] = true; capture.uniqueFrames = capture.uniqueFrames + 1 end
  end

  -- set defaults
  if not r and not g and not b then
    r, g, b, a = tint.r, tint.g, tint.b, tint.a
  end

  -- iterate through all subframes
  if frame and frame.GetChildren then
    if capture then scan.tables = scan.tables + 1 end
    for _, frame in pairs({frame:GetChildren()}) do
      DarkenFrame(frame, r, g, b, a, scan)
    end
  end

  -- set vertex on all regions
  if frame and frame.GetRegions then
    if capture then scan.tables = scan.tables + 1 end
    -- read name
    local name = frame.GetName and frame:GetName()

    -- set the palette's backdrop border color everywhere
    if not frame.stPreserveRarityColor then
      if capture then capture.borderWrites = capture.borderWrites + 1 end
      frame:SetBackdropBorderColor(edge.r, edge.g, edge.b, edge.a)
    end

    -- add special backgrounds to quests and such
    for pattern, inset in pairs(backgrounds) do
      if name and string.find(name, pattern) then
        AddSpecialBackground(frame, inset[1], inset[2], inset[3], inset[4])
      end
    end

    -- add black borders around specified buttons
    for pattern, inset in pairs(borders) do
      if name and string.find(name, pattern) then AddBorder(frame, inset, edge) end
    end

    -- scan through all regions (textures)
    for id, region in pairs({frame:GetRegions()}) do
      if capture then scan.regions = scan.regions + 1 end
      if region.SetVertexColor and region:GetObjectType() == "Texture" then
        if region:GetTexture() and string.find(region:GetTexture(), "UI%-Panel%-Button%-Up") then
          -- monochrome buttons
          -- region:SetDesaturated(true)
        elseif region.stOriginalQuestPaper then
          -- Untinted copies of native quest/gossip parchment.
        elseif region.stSlotEdge then
          -- Border strips are maintained by their source texture.
        elseif IsSlotArtwork(region:GetTexture()) then
          TintSlotBorder(region, frame)
        elseif name == "InboxFrame" then
          -- The inbox artwork includes its parchment. Tinting it turns the
          -- paper orange; covering it with stationery leaves a straight seam.
          -- Keep these regions stock; child buttons and the mail header still
          -- receive the palette through their own frames.
        elseif name and id and regionskips[name] and regionskips[name][id] then
          -- skip special regions
        elseif region.GetBlendMode and region:GetBlendMode() == "ADD" then
          -- skip blend over textures
        elseif IsBlacklisted(region) then
          -- skip blacklisted texture names
        else
          if capture then capture.textureWrites = capture.textureWrites + 1 end
          region:SetVertexColor(r,g,b,a)
          if name == "SpellBookFrame" then RestoreSpellbookParchment(frame, region) end
        end
      end
    end
  end
  if frame and frame.GetRegions then RestoreQuestParchment(frame) end
  if frame and frame.GetRegions then RestoreQuestLogParchment(frame) end
end

-- register darken frame to global
ShaguTweaks.DarkenFrame = DarkenFrame

-- Other addons that draw their own tooltip-style borders. Their frames (and
-- everything inside them) keep following the palette even when the addon
-- sets its border color again later, or builds a window only when opened.
local ADDON_PREFIXES = {
  "ShaguDPS", "Bagshui", "Outfitter", "SoulstoneTracker", "SSWarlock",
  "SSTClassic", "SSTracker", "OctoBus", "RollFor", "VCB_",
  "aux_frame", "AuxCraft", "AuxDragOutline",
  -- Filled mail slots get rarity borders after their item texture changes.
  "MailAttachment", "SendMailPackageButton",
}

local function IsAddonFrameName(name)
  if not name then return end
  for i = 1, table.getn(ADDON_PREFIXES) do
    if string.find(name, ADDON_PREFIXES[i], 1, true) == 1 then return true end
  end
end

-- Only light grey/white/silver borders follow the palette. Colored borders
-- (item quality, hover highlights, class or theme colors) and dark ones stay
-- as the addon set them.
local function IsLightNeutral(r, g, b)
  r, g, b = tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0
  local hi, lo = math.max(r, g, b), math.min(r, g, b)
  return hi - lo < .1 and hi >= .35
end

local function LockBorder(frame)
  if not frame or frame.stBorderLock or not frame.SetBackdropBorderColor then return end
  frame.stBorderLock = true

  local setColor, setBackdrop = frame.SetBackdropBorderColor, frame.SetBackdrop

  frame.SetBackdropBorderColor = function(self, r, g, b, a)
    if not self.stPreserveRarityColor and IsLightNeutral(r, g, b) then
      setColor(self, edge.r, edge.g, edge.b, a or 1)
    else
      setColor(self, r, g, b, a)
    end
  end

  -- a new backdrop starts with a white border
  if setBackdrop then
    frame.SetBackdrop = function(self, backdrop)
      local r, g, b, a
      if self.stPreserveRarityColor and self.GetBackdropBorderColor then
        r, g, b, a = self:GetBackdropBorderColor()
      end
      setBackdrop(self, backdrop)
      if backdrop and backdrop.edgeFile then
        if r then
          setColor(self, r, g, b, a)
        else
          setColor(self, edge.r, edge.g, edge.b, 1)
        end
      end
    end
  end

  -- run the current color through the filter once
  if frame.GetBackdropBorderColor then
    local ok, r, g, b, a = pcall(frame.GetBackdropBorderColor, frame)
    if ok and r then frame:SetBackdropBorderColor(r, g, b, a) end
  end
end

-- Border textures (VCB's buff and weapon borders): same rule, on the
-- texture's vertex color.
local function LockTextureBorder(texture)
  if texture.stBorderLock or not texture.SetVertexColor then return end
  texture.stBorderLock = true

  local setColor = texture.SetVertexColor
  texture.SetVertexColor = function(self, r, g, b, a)
    if IsLightNeutral(r, g, b) then
      setColor(self, edge.r, edge.g, edge.b, a or 1)
    else
      setColor(self, r, g, b, a)
    end
  end

  if texture.GetVertexColor then
    local ok, r, g, b, a = pcall(texture.GetVertexColor, texture)
    if ok and r then texture:SetVertexColor(r, g, b, a) end
  end
end

local function LockTree(frame)
  if not frame then return end
  if IsExcludedFrame(frame) then return end
  local capture = ShaguTweaks.RecolorCapture
  if capture then capture.lockVisits = capture.lockVisits + 1 end
  LockBorder(frame)
  if frame.GetRegions then
    if capture then capture.lockTables = capture.lockTables + 1 end
    local regions = { frame:GetRegions() }
    for i = 1, table.getn(regions) do
      local region = regions[i]
      local name = region.GetName and region:GetName()
      if name and string.find(name, "Border$") and region.GetObjectType and region:GetObjectType() == "Texture" then
        LockTextureBorder(region)
      end
    end
  end
  if frame.GetChildren then
    if capture then capture.lockTables = capture.lockTables + 1 end
    local children = { frame:GetChildren() }
    for i = 1, table.getn(children) do LockTree(children[i]) end
  end
end

-- find the addon frames that exist already, anywhere below UIParent
local function FindAddonFrames(frame)
  local capture = ShaguTweaks.RecolorCapture
  if capture then
    capture.discoveryVisits = capture.discoveryVisits + 1
    capture.discoveryTables = capture.discoveryTables + 1
  end
  local children = { frame:GetChildren() }
  for i = 1, table.getn(children) do
    local child = children[i]
    if IsExcludedFrame(child) then
      -- Leave the whole TrinketMenu subtree to its own styling code.
    elseif IsAddonFrameName(child.GetName and child:GetName()) then
      LockTree(child)
    else
      FindAddonFrames(child)
    end
  end
end

-- These buttons need explicit discovery when created by XML or nested below
-- a minimap child frame. Outfitter and TrinketMenu bake the rim into their art.
local addonMinimapButtons = {
  OutfitterMinimapButton = true,
  TrinketMenu_IconFrame = true,
  AtlasCFMMinimapButton = true,
}

local function TintMinimapButton(frame)
  if not tint or not frame or not frame.GetRegions then return end
  local name = frame.GetName and frame:GetName()
  if name == "OutfitterMinimapButton" or name == "TrinketMenu_IconFrame" then
    local normal = frame:GetNormalTexture()
    local pushed = frame:GetPushedTexture()
    if normal then normal:SetVertexColor(tint.r, tint.g, tint.b, 1) end
    if pushed then pushed:SetVertexColor(tint.r, tint.g, tint.b, 1) end
    return
  end
  if IsExcludedFrame(frame) then return end
  local regions = { frame:GetRegions() }
  for i = 1, table.getn(regions) do
    local region = regions[i]
    local texture = region.GetTexture and region:GetTexture()
    if texture and string.find(string.lower(texture), "minimap%-trackingborder") then
      region:SetVertexColor(tint.r, tint.g, tint.b, 1)
    end
  end
end

local function TintLoadedMinimapButton(name)
  HookAddonOrVariable(name, function() TintMinimapButton(_G[name]) end)
end

local function RecolorOnShow(frame)
  if not frame or frame.stRecolorOnShow then return end
  frame.stRecolorOnShow = true
  if golden.rollforLoot and frame:GetName() == "RollForLootFrameHeader" then golden.rollforLoot(frame) end
  local pending
  local function Trailing()
    pending = nil
    DarkenFrame(frame)
  end
  ShaguTweaks.HookScript(frame, "OnShow", function()
    DarkenFrame(frame)
    if not pending and _G.C_Timer and _G.C_Timer.After then
      pending = true
      _G.C_Timer.After(0, Trailing)
    end
  end)
  if frame:IsShown() then DarkenFrame(frame) end
end

local function LockAddonFrames()
  FindAddonFrames(UIParent)

  for name in pairs(showframes) do RecolorOnShow(_G[name]) end

  if Minimap then
    local buttons = { Minimap:GetChildren() }
    for i = 1, table.getn(buttons) do TintMinimapButton(buttons[i]) end
  end
  for name in pairs(addonMinimapButtons) do
    local button = _G[name]
    if not button then
      TintLoadedMinimapButton(name)
    elseif button:GetParent() ~= Minimap then
      TintMinimapButton(button)
    end
  end

  -- frames those addons create later: named after the addon, or created
  -- inside one of their frames (templates bring their children along)
  local create = CreateFrame
  CreateFrame = function(a1, a2, a3, a4, a5, a6)
    local frame = create(a1, a2, a3, a4, a5, a6)
    if frame and (IsAddonFrameName(a2) or (type(a3) == "table" and a3.stBorderLock)) then
      LockTree(frame)
    end
    if frame and type(a2) == "string" and showframes[a2] then RecolorOnShow(frame) end
    -- buttons that get an extra border (VCB buffs made after login)
    if frame and type(a2) == "string" then
      for pattern, inset in pairs(borders) do
        if string.find(a2, pattern) then AddBorder(frame, inset, edge) end
      end
    end
    -- minimap buttons get their border texture right after they are made
    if frame and ((a3 and a3 == Minimap) or addonMinimapButtons[a2]) then
      if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(0, function() TintMinimapButton(frame) end)
      end
    end
    return frame
  end
end

local function Apply(tintColor, edgeColor, darkBackgrounds)
  if tint then return end
  tint, edge = tintColor, edgeColor
  ShaguTweaks.UITint = tint
  ShaguTweaks.UIBorder = edge
  ShaguTweaks.StyleActionButton = StyleActionButton

  local name, original, r, g, b
  local hookBuffButton_Update = BuffButton_Update
  function BuffButton_Update(buttonName, index, filter)
    hookBuffButton_Update(buttonName, index, filter)

    -- tbc passes buttonName and index arguments, vanilla uses "this" context
    name = buttonName and index and buttonName .. index or this:GetName()
    original = _G[name.."Border"]

    if original and this.ShaguTweaks_border then
      r, g, b = original:GetVertexColor()
      this.ShaguTweaks_border:SetBackdropBorderColor(r, g, b, 1)
      original:SetAlpha(0)
    elseif not original and _G[name] then
      -- tbc buff buttons don't have borders, so we
      -- need to manually add a dark one.
      AddBorder(_G[name], 2, edge)
    end
  end

  TOOLTIP_DEFAULT_COLOR.r = edge.r
  TOOLTIP_DEFAULT_COLOR.g = edge.g
  TOOLTIP_DEFAULT_COLOR.b = edge.b

  -- Darkened UI also greys the tooltip background; Golden UI keeps it.
  if darkBackgrounds then
    TOOLTIP_DEFAULT_BACKGROUND_COLOR.r = tint.r
    TOOLTIP_DEFAULT_BACKGROUND_COLOR.g = tint.g
    TOOLTIP_DEFAULT_BACKGROUND_COLOR.b = tint.b
  end

  DarkenFrame(UIParent)
  DarkenFrame(WorldMapFrame)
  DarkenFrame(DropDownList1)
  DarkenFrame(DropDownList2)
  DarkenFrame(DropDownList3)
  LockAddonFrames()

  -- Bagshui restores its empty-slot artwork to white whenever items are
  -- assigned. Reapply only to that background, leaving icons, quality
  -- borders and user-configured solid background colors alone.
  HookAddonOrVariable("Bagshui", function()
    local ui = _G.Bagshui and _G.Bagshui.prototypes and _G.Bagshui.prototypes.Ui
    if not ui or not ui.UpdateItemButtonColorsAndBadges then return end
    ShaguTweaks.hooksecurefunc(ui, "UpdateItemButtonColorsAndBadges", function(self, button)
      local data = button and button.bagshuiData
      local background = data and data.buttonComponents and data.buttonComponents.background
      if background then TintSlotBorder(background, button) end
    end)
  end)

  -- the loot window gets its art set again when it opens
  if LootFrame then
    ShaguTweaks.HookScript(LootFrame, "OnShow", function() DarkenFrame(LootFrame) end)
  end

  -- align all actionbutton textures
  local bars = { "Action", "BonusAction", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight", "Shapeshift" }
  for _, prefix in pairs(bars) do
    for i = 1, NUM_ACTIONBAR_BUTTONS do
      local button = _G[prefix .. "Button" .. i]
      local texture = _G[prefix.."Button"..i.."NormalTexture"]

      StyleActionButton(button, texture)
    end
  end

  for _, button in pairs({ MinimapZoomOut, MinimapZoomIn }) do
    for _, func in pairs({ "GetNormalTexture", "GetDisabledTexture", "GetPushedTexture" }) do
      if button[func] then
        local tex = button[func](button)
        if tex then
          tex:SetVertexColor(math.min(tint.r+.2, 1), math.min(tint.g+.2, 1), math.min(tint.b+.2, 1), 1)
        end
      end
    end
  end

  HookAddonOrVariable("Blizzard_AuctionUI", function()
    for i = 1, 15 do
      local tex = _G["AuctionFilterButton"..i]:GetNormalTexture()
      tex:SetVertexColor(tint.r, tint.g, tint.b, 1)
    end

    for i = 1, 8 do
      _G["BrowseButton"..i.."Left"]:SetVertexColor(tint.r, tint.g, tint.b, 1)
      _G["BrowseButton"..i.."Right"]:SetVertexColor(tint.r, tint.g, tint.b, 1)
    end
  end)

  for addon, data in pairs(addonframes) do
    for _, frame in pairs(data) do
      local frame = frame
      HookAddonOrVariable(frame, function()
        DarkenFrame(_G[frame])
      end)
    end
  end

  -- Turtle's inspect talent tree is rebuilt by TWTalentFrame_Update().
  -- Its background textures are assigned during that update, so the initial
  -- InspectTalentsFrame pass may happen too early. Re-darken the parent after
  -- each rebuild; it already contains TWTalentFrame, so one recursive scan is
  -- sufficient and avoids traversing the same tree twice.
  if isTurtle then
    HookAddonOrVariable("TWTalentFrame", function()
      if not _G.TWTalentFrame or not _G.TWTalentFrame_Update then return end

      if not _G.TWTalentFrame.ShaguTweaksDarkHook then
        _G.TWTalentFrame.ShaguTweaksDarkHook = true
        ShaguTweaks.hooksecurefunc("TWTalentFrame_Update", function()
          DarkenFrame(_G.InspectTalentsFrame or _G.TWTalentFrame)
        end)
      end

      DarkenFrame(_G.InspectTalentsFrame or _G.TWTalentFrame)
    end)
  end

  HookAddonOrVariable("Blizzard_TimeManager", function()
    DarkenFrame(TimeManagerClockButton)
  end)

  HookAddonOrVariable("GameTooltipStatusBarBackdrop", function()
    DarkenFrame(_G["GameTooltipStatusBarBackdrop"])
  end)

  -- Prefer BlizzNameplatesPlus' own nameplate provider whenever available.
  -- This is capability-based instead of version-based, so BNP updates keep
  -- working as long as its public libnameplate callback API remains available.
  local bnpNameplates = BNP
    and BNP.libnameplate
    and BNP.libnameplate.OnInit
    and BNP.libnameplate.OnShow

  if bnpNameplates then
    local pending = {}
    local updater = CreateFrame("Frame")

    local function StopUpdaterIfIdle()
      if not next(pending) then
        updater:SetScript("OnUpdate", nil)
      end
    end

    local function ReapplyBNPDarkMode(plate)
      plate = plate or this
      if not plate or not plate:IsShown() then return end
      if plate.darkened then return end

      plate.darkened = true
      DarkenFrame(plate)

      -- Blizzard can restore some nameplate textures immediately after OnShow.
      -- Queue one delayed pass, then stop completely. If BNP's own Shagu
      -- compatibility already darkened the plate first, the marker above makes
      -- this path a no-op and avoids duplicate work.
      pending[plate] = GetTime() + 0.08
      if not updater:GetScript("OnUpdate") then
        updater:SetScript("OnUpdate", function()
          local now = GetTime()
          local current, due
          for current, due in pairs(pending) do
            if now >= due then
              pending[current] = nil
              if current and current:IsShown() then
                current.darkened = nil
                DarkenFrame(current)
                current.darkened = true
              end
            end
          end
          StopUpdaterIfIdle()
        end)
      end
    end

    table.insert(BNP.libnameplate.OnInit, ReapplyBNPDarkMode)
    table.insert(BNP.libnameplate.OnShow, ReapplyBNPDarkMode)
  else
    -- Native ShaguTweaks nameplates only need darkening when a plate is first
    -- discovered or shown. Avoid keeping a per-frame libnameplate callback
    -- alive just to test the permanent "darkened" marker.
    local pending = {}
    local updater = CreateFrame("Frame")

    local function StopUpdaterIfIdle()
      if not next(pending) then
        updater:SetScript("OnUpdate", nil)
      end
    end

    local function ReapplyShaguDarkMode(plate)
      plate = plate or this
      if not plate or not plate:IsShown() then return end

      plate.darkened = nil
      DarkenFrame(plate)
      plate.darkened = true

      -- Some clients restore nameplate textures immediately after OnShow.
      -- Re-apply once after that short window, then stop completely.
      pending[plate] = GetTime() + 0.08
      if not updater:GetScript("OnUpdate") then
        updater:SetScript("OnUpdate", function()
          local now = GetTime()
          local current, due
          for current, due in pairs(pending) do
            if now >= due then
              pending[current] = nil
              if current and current:IsShown() then
                current.darkened = nil
                DarkenFrame(current)
                current.darkened = true
              end
            end
          end
          StopUpdaterIfIdle()
        end)
      end
    end

    table.insert(ShaguTweaks.libnameplate.OnInit, ReapplyShaguDarkMode)
    table.insert(ShaguTweaks.libnameplate.OnShow, ReapplyShaguDarkMode)
  end
end

-- Title bars: the dark strips the window titles sit on. Golden UI
-- multiplies them toward WoW Forever's red-brown with a MOD layer. Measured
-- from the window art: rows below the frame's top edge, and how far the strip
-- runs from the left (after the portrait) and from the right (before the
-- close button).
local STRIP_A = { 72, -16, -60, -34 }   -- character, spellbook, mail, quest log art
local STRIP_B = { 72, -15, -62, -33 }   -- merchant, friends art

local function Shade(parent, layer, color)
  local shade = parent:CreateTexture(nil, layer)
  shade:SetTexture(1, 1, 1, 1)
  shade:SetVertexColor(tonumber(color.r) or .8, tonumber(color.g) or .63, tonumber(color.b) or .62, 1)
  shade:SetBlendMode("MOD")
  return shade
end

local function PlaceStrip(shade, frame, strip)
  shade:ClearAllPoints()
  shade:SetPoint("TOPLEFT", frame, "TOPLEFT", strip[1], strip[2])
  shade:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", strip[3], strip[4])
end

-- The shade has to sit above the window art, which would darken a title
-- that is drawn in the same frame. Those titles are drawn again on top and
-- the original is kept, invisible, for its position and text.
local function RedrawTitle(holder, title)
  if not title then return end
  local copy = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local font = title.GetFontObject and title:GetFontObject()
  if font then copy:SetFontObject(font) end
  copy:SetAllPoints(title)
  if title.GetJustifyH then copy:SetJustifyH(title:GetJustifyH()) end
  copy:SetText(title:GetText())
  title:SetAlpha(0)

  local setText = title.SetText
  title.SetText = function(self, text)
    setText(self, text)
    copy:SetText(self:GetText())
  end
  local setFormattedText = title.SetFormattedText
  if type(setFormattedText) == "function" then
    title.SetFormattedText = function(self, ...)
      setFormattedText(self, unpack(arg))
      copy:SetText(self:GetText())
    end
  end
  return copy
end

local function ShadeTitleBar(frame, strip, title, color, level)
  if not frame or frame.stTitleBar then return end
  local bar = CreateFrame("Frame", nil, frame)
  bar:SetAllPoints(frame)
  if level then bar:SetFrameLevel(level) end
  frame.stTitleBar = bar
  bar.shade = Shade(bar, "BACKGROUND", color)
  PlaceStrip(bar.shade, frame, strip)
  bar.title = RedrawTitle(bar, title)
  return bar
end

-- frames whose titles live in child frames (or above the art layer): the
-- shade is a plain texture in the window itself, nothing to redraw
local function ShadeStripInFrame(frame, strip, layer, color)
  if not frame or frame.stTitleShade then return end
  frame.stTitleShade = Shade(frame, layer, color)
  PlaceStrip(frame.stTitleShade, frame, strip)
end

-- MailFrame's four art tiles contain both the metal frame and the paper.
-- Restore cropped copies of the original paper above the tinted tiles, below
-- the inbox's child frames. Parent them to InboxFrame so they hide on the
-- Send Mail and TurtleMail Log tabs. Matching the original pixels preserves the torn
-- edges and tile seams without replacing the parchment with stationery.
local function RestoreMailParchment()
  if not InboxFrame then return end
  if not InboxFrame.stParchmentRetryHook then
    InboxFrame.stParchmentRetryHook = true
    ShaguTweaks.HookScript(InboxFrame, "OnShow", RestoreMailParchment)
  end
  if InboxFrame.stOriginalParchment then return end
  InboxFrame.stParchmentTiles = InboxFrame.stParchmentTiles or {}
  local copies = InboxFrame.stParchmentTiles
  local complete = true
  local tiles = {
    { "MailFrameTopLeft", 22, 74, 256, 256 },
    { "MailFrameTopRight", 0, 74, 80, 256 },
    { "MailFrameBotLeft", 22, 0, 256, 170 },
    { "MailFrameBotRight", 0, 0, 80, 170 },
  }
  for i = 1, table.getn(tiles) do
    local tile = tiles[i]
    local source = _G[tile[1]]
    if not copies[i] and source and source:GetTexture() then
      local w, h = source:GetWidth(), source:GetHeight()
      if w and h and w > 0 and h > 0 then
        local paper = InboxFrame:CreateTexture(nil, "BACKGROUND")
        paper:SetTexture(source:GetTexture())
        paper:SetVertexColor(1, 1, 1, 1)
        paper:SetTexCoord(tile[2] / w, tile[4] / w, tile[3] / h, tile[5] / h)
        paper:SetWidth(tile[4] - tile[2])
        paper:SetHeight(tile[5] - tile[3])
        paper:SetPoint("TOPLEFT", source, "TOPLEFT", tile[2], -tile[3])
        copies[i] = paper
      end
    end
    if not copies[i] then complete = false end
  end
  InboxFrame.stOriginalParchment = complete or nil
end

module.enable = function(self)
  ShaguTweaks.DarkMode = true
  Apply(module.config["darkmode.color"], module.config["darkmode.color"], true)
  RestoreMailParchment()
end

local function ShadeNpcTitleBar(frame, nameFrame, panels, color)
  if not frame or not nameFrame or frame.stTitleBar then return end
  local level = frame:GetFrameLevel() + 1
  for _, panel in pairs(panels) do
    if panel then level = math.max(level, panel:GetFrameLevel() + 1) end
  end
  -- NPC names already live in a separate frame. Keep that native title above
  -- both the panel artwork and shade, without creating another text copy.
  if nameFrame:GetFrameLevel() <= level then nameFrame:SetFrameLevel(level + 1) end
  ShadeTitleBar(frame, {72,-22,-60,-39}, nil, color, level)
end

local function ShadeTitleBars(color)
  -- world map: its strip is 3 to 21 px below the top of its art (384 above
  -- the frame center), from the left corner to the window buttons
  if WorldMapFrame and WorldMapFrameTitle and not WorldMapFrame.stTitleBar then
    local bar = ShadeTitleBar(WorldMapFrame, { 0, 0, 0, 0 }, WorldMapFrameTitle, color)
    bar.shade:ClearAllPoints()
    bar.shade:SetPoint("TOPLEFT", WorldMapFrame, "CENTER", -510, 381)
    bar.shade:SetPoint("BOTTOMRIGHT", WorldMapFrame, "CENTER", 455, 363)

    -- the stone art is lighter around the seam of its first two pieces
    -- (measured in 8 px columns): darken those columns a bit more so the
    -- bar comes out even
    local even = {
      { -272, .81 }, { -264, .76 },
      { -256, .66 }, { -248, .52 }, { -240, .49 }, { -232, .47 }, { -224, .53 }, { -216, .54 },
      { -208, .52 }, { -200, .58 }, { -192, .69 }, { -184, .76 }, { -176, .68 }, { -168, .68 },
      { -160, .69 }, { -152, .71 }, { -144, .78 }, { -136, .86 },
    }
    for i = 1, table.getn(even) do
      local x, f = even[i][1], even[i][2]
      local fix = Shade(bar, "BACKGROUND", { r = f, g = f, b = f })
      fix:SetPoint("TOPLEFT", WorldMapFrame, "CENTER", x, 381)
      fix:SetPoint("BOTTOMRIGHT", WorldMapFrame, "CENTER", x + 8, 363)
    end
  end

  ShadeTitleBar(MerchantFrame, STRIP_B, MerchantNameText, color)
  ShadeTitleBar(SpellBookFrame, STRIP_A, SpellBookTitleText, color)
  ShadeTitleBar(FriendsFrame, STRIP_B, FriendsFrameTitleText, color)
  ShadeNpcTitleBar(QuestFrame, _G.QuestNpcNameFrame,
    { _G.QuestFrameGreetingPanel, _G.QuestFrameDetailPanel, _G.QuestFrameProgressPanel, _G.QuestFrameRewardPanel }, color)
  ShadeNpcTitleBar(GossipFrame, _G.GossipNpcNameFrame, { _G.GossipFrameGreetingPanel }, color)
  -- the quest log is wider: its strip ends before the close button
  ShadeTitleBar(QuestLogFrame, { 72, -16, -121, -34 }, QuestLogTitleText, color)

  -- mail: the art is on the BORDER layer, the titles are on the page frames
  ShadeStripInFrame(MailFrame, STRIP_A, "ARTWORK", color)

  -- character: the art is on the tab pages (PaperDollFrame and the others),
  -- the name on CharacterNameFrame. The shade goes between the two.
  if CharacterFrame and PaperDollFrame and CharacterNameFrame then
    local level = PaperDollFrame:GetFrameLevel() + 1
    if CharacterNameFrame:GetFrameLevel() <= level then CharacterNameFrame:SetFrameLevel(level + 1) end
    ShadeTitleBar(CharacterFrame, STRIP_A, nil, color, level)
  end
end

-- RollFor's classic loot window: the art is on the BACKGROUND layer and the
-- "Items" title on ARTWORK, so the shade fits between them. The strip runs
-- 12 to 30 px down, from the portrait to 25 px before the right edge (the
-- window width changes with the item names).
local function ShadeRollForLoot(frame, color)
  ShadeStripInFrame(frame, { 68, -12, -25, -30 }, "BORDER", color)
end

local function GoldenUnitNameBar(frame)
  local title = frame and frame.name
  if not title or frame.stGoldenNameBar then return end
  local parent = title:GetParent()
  local point, relative, relativePoint, x, y = title:GetPoint(1)
  if not parent or not point then return end
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetFrameLevel(parent:GetFrameLevel() + 1)
  bar:SetWidth(119)
  bar:SetHeight(14)
  bar:SetPoint(point, relative, relativePoint, x, y)
  bar.texture = bar:CreateTexture(nil, "BACKGROUND")
  -- Opaque stone from the same native title strip used by the character
  -- window, excluding its metal edges and portrait. No world bleed-through.
  bar.texture:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-General-TopLeft")
  bar.texture:SetTexCoord(80/256, 255/256, 18/256, 32/256)
  bar.texture:SetAllPoints(bar)
  local color = golden.config["goldmode.bar"]
  bar.texture:SetVertexColor((tonumber(tint.r) or 1) * (tonumber(color.r) or .8),
    (tonumber(tint.g) or .78) * (tonumber(color.g) or .63),
    (tonumber(tint.b) or .4) * (tonumber(color.b) or .62), 1)
  local originalAlpha = title:GetAlpha()
  bar.title = RedrawTitle(bar, title)
  frame.stGoldenNameBar = bar
  local function UpdateNameBar()
    if UnitExists("target") and not UnitIsPlayer("target") then
      title:SetAlpha(0)
      bar:Show()
    else
      bar:Hide()
      title:SetAlpha(originalAlpha)
    end
  end
  bar:RegisterEvent("PLAYER_TARGET_CHANGED")
  bar:RegisterEvent("PLAYER_ENTERING_WORLD")
  bar:SetScript("OnEvent", UpdateNameBar)
  ShaguTweaks.HookScript(frame, "OnShow", UpdateNameBar)
  UpdateNameBar()
end

golden.enable = function(self)
  -- Both recolor the same textures; Darkened UI wins when both are ticked.
  if ShaguTweaks_config and ShaguTweaks_config[T["Darkened UI"]] == 1 then return end
  ShaguTweaks.GoldMode = true
  Apply(golden.config["goldmode.color"], golden.config["goldmode.border"], false)

  ShadeTitleBars(golden.config["goldmode.bar"])
  -- The opaque title artwork is only for NPC targets. Player names retain
  -- their native/class-colored background, including our own player frame.
  -- Big Health moves the name into the enlarged health fill. An opaque
  -- header there would cover its upper portion, regardless of module order.
  if not ShaguTweaks_config or ShaguTweaks_config[T["Unit Frame Big Health for Target"]] ~= 1 then
    GoldenUnitNameBar(TargetFrame)
  end
  RestoreMailParchment()
  golden.rollforLoot = function(frame) ShadeRollForLoot(frame, golden.config["goldmode.bar"]) end
  if _G.RollForLootFrameHeader then golden.rollforLoot(_G.RollForLootFrameHeader) end
end

-- Function references for the optional companion; no profiling starts here.
ShaguTweaks.RecolorProfileFunctions = {
  DarkenFrame = DarkenFrame, LockTree = LockTree,
  FindAddonFrames = FindAddonFrames, ClassifyPath = ClassifyPath,
}
