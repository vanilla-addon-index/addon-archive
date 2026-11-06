local A = OctoQuestRewards
local G = getfenv(0)
local panels = {
  detail = { "QuestFrameDetailPanel", "QuestDetailScrollChildFrame", "QuestDetailScrollFrame", "QuestDescription", "QuestDetailRewardTitleText" },
  progress = { "QuestFrameProgressPanel", "QuestProgressScrollChildFrame", "QuestProgressScrollFrame", "QuestProgressText" },
  reward = { "QuestFrameRewardPanel", "QuestRewardScrollChildFrame", "QuestRewardScrollFrame", "QuestRewardText", "QuestRewardRewardTitleText" },
  log = { "QuestLogFrame", "QuestLogDetailScrollChildFrame", "QuestLogDetailScrollFrame", "QuestLogQuestDescription", "QuestLogRewardTitleText" },
}

-- Copy the live font, including addon overrides, rather than just its template.
local function CopyFont(target, source)
  if not source or not source.GetFont then return end
  local font, size, flags = source:GetFont()
  if font and size then target:SetFont(font, size, flags or "") end
end

function A.Number(value)
  local s = tostring(math.floor(value))
  local count
  repeat s, count = string.gsub(s, "^(%-?%d+)(%d%d%d)", "%1,%2") until count == 0
  return s
end

function A.Money(copper)
  copper = math.floor(copper)
  local gold = math.floor(copper / 10000)
  local silver = math.floor(copper / 100) - gold * 100
  local coins = copper - math.floor(copper / 100) * 100
  local parts = {}
  if gold > 0 then table.insert(parts, gold .. "g") end
  if silver > 0 then table.insert(parts, silver .. "s") end
  if coins > 0 then table.insert(parts, coins .. "c") end
  return table.concat(parts, " ")
end

-- Read actual visible content extents, including the nested fading reward area.
-- Ignore textures and spacer frames, whose bounds aren't content bounds.
local function ContentBottom(object, block, top, scale, depth)
  if object == block or not object:IsShown() or depth > 5 then return 0 end
  local name = object:GetName() or ""
  if string.find(name, "Spacer") then return 0 end
  local bottom = 0
  local isText = object:IsObjectType("FontString")
  if (isText and object:GetText() and object:GetText() ~= "")
    or object:IsObjectType("Button") or string.find(name, "MoneyFrame$") then
    local b = object:GetBottom()
    if b then
      -- FontStrings inherit their parent's scale; don't assume Frame-only
      -- methods exist on Vanilla regions.
      local owner = isText and object:GetParent() or object
      bottom = (top * scale - b * owner:GetEffectiveScale()) / scale
    end
  end
  if object.GetRegions then
    for _, region in ipairs({object:GetRegions()}) do
      bottom = math.max(bottom, ContentBottom(region, block, top, scale, depth + 1))
    end
  end
  if object.GetChildren then
    for _, child in ipairs({object:GetChildren()}) do
      bottom = math.max(bottom, ContentBottom(child, block, top, scale, depth + 1))
    end
  end
  return bottom
end

function A.Render(kind)
  local cfg = panels[kind]
  local panel, child, scroll = G[cfg[1]], G[cfg[2]], G[cfg[3]]
  if not panel or not child or not scroll then return end
  if cfg.block then cfg.block:Hide() end
  if not panel:IsVisible() then return end
  local r = A.GetRecord(kind)
  A.current = r
  if A.db.debug and r then A.DebugRecord(r) end
  local lines = {}
  if r and r.xp and r.xp > 0 then table.insert(lines, "Estimated XP: " .. A.Number(r.xp)) end
  if not cfg.block then
    cfg.block = CreateFrame("Frame", nil, child)
    cfg.block:SetWidth(child:GetWidth() - 15)
    cfg.block.title = cfg.block:CreateFontString(nil, "ARTWORK", "QuestTitleFont")
    cfg.block.title:SetPoint("TOPLEFT", cfg.block, "TOPLEFT", 0, 0)
    cfg.block.title:SetText("Rewards")
    cfg.block.text = cfg.block:CreateFontString(nil, "ARTWORK", "QuestFont")
    cfg.block.text:SetJustifyH("LEFT")
    cfg.baseHeight = child:GetHeight()
  end
  local block = cfg.block
  -- Keep our previous extension out of the next layout calculation.
  if cfg.lastHeight and child:GetHeight() == cfg.lastHeight then child:SetHeight(cfg.baseHeight) end
  if table.getn(lines) == 0 then
    block:Hide()
    scroll:UpdateScrollChildRect()
    return
  end
  local top, scale = child:GetTop(), child:GetEffectiveScale()
  if not top then block:Hide(); return end
  local bottom = ContentBottom(child, block, top, scale, 0)
  local heading = cfg[5] and G[cfg[5]]
  local example = G[cfg[4]]
  CopyFont(block.text, example)
  CopyFont(block.title, heading or G.QuestProgressTitleText)
  local titleHeight = 0
  if heading and heading:IsShown() then block.title:Hide()
  else
    block.title:Show()
    titleHeight = block.title:GetHeight() + 5
  end
  block:ClearAllPoints()
  block:SetPoint("TOPLEFT", child, "TOPLEFT", 5, -bottom - 12)
  block:SetWidth(child:GetWidth() - 15)
  block.text:ClearAllPoints()
  block.text:SetPoint("TOPLEFT", block, "TOPLEFT", 0, -titleHeight)
  block.text:SetWidth(block:GetWidth())
  block.text:SetText(table.concat(lines, "\n"))
  if example and example.GetTextColor then
    block.text:SetTextColor(example:GetTextColor())
  else block.text:SetTextColor(0, 0, 0) end
  if heading and heading.GetTextColor then block.title:SetTextColor(heading:GetTextColor()) end
  block:SetHeight(titleHeight + block.text:GetHeight())
  cfg.lastHeight = math.max(cfg.baseHeight, bottom + 12 + block:GetHeight() + 12)
  child:SetHeight(cfg.lastHeight)
  block:Show()
  scroll:UpdateScrollChildRect()
end

function A.RenderAll()
  for kind in pairs(panels) do A.Render(kind) end
end

function A.HookScript(frame, script, callback)
  if not frame then return end
  if frame.HookScript then frame:HookScript(script, callback); return end
  -- Vanilla has no HookScript. Chain the existing script with its original args.
  local old = frame:GetScript(script)
  frame:SetScript(script, function(...)
    if old then old(unpack(arg)) end
    callback()
  end)
end

function A.SetupUI()
  for _, cfg in pairs(panels) do
    A.HookScript(G[cfg[1]], "OnShow", A.Schedule)
  end
end
