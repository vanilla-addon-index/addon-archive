-- pfQuest xpGuide: a small notice when you pick up the first quest of a chain (Settings, Helpers: "Popup on a chain's first
-- quest"). It says how long the chain is and what comes next.

local ER = pfQuest_xpGuide
local GOLD, GREY, WHITE, END = ER.GOLD, ER.GREY, ER.WHITE, ER.END

local function Opaque(f)
  local solid = f:CreateTexture(nil, "BACKGROUND")
  solid:SetTexture(0.05, 0.05, 0.07, 1)
  solid:SetPoint("TOPLEFT", f, "TOPLEFT", 11, -11)
  solid:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -11, 11)
end

local function Button(name, parent, width, text)
  local b = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
  b:SetWidth(width)
  b:SetHeight(22)
  b:SetText(text)
  return b
end

------------------------------------------------------------------------------------------------------
-- A small notice when you pick up the first quest of a chain
------------------------------------------------------------------------------------------------------

local notice, noticeText

function ER.ShowChainNotice(title, total, nextTitle)
  if not notice then
    notice = CreateFrame("Frame", "pfQuest_xpGuideChainNotice", UIParent)
    notice:SetWidth(360)
    notice:SetHeight(156)
    notice:SetPoint("TOP", UIParent, "TOP", 0, -140)
    notice:SetFrameStrata("DIALOG")
    notice:SetClampedToScreen(true)
    notice:EnableMouse(true)
    notice:SetMovable(true)
    notice:RegisterForDrag("LeftButton")
    notice:SetScript("OnDragStart", function() this:StartMoving() end)
    notice:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    Opaque(notice)
    notice:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    if ER.Skin then ER.Skin.Window(notice, nil) end
    table.insert(UISpecialFrames, "pfQuest_xpGuideChainNotice")

    local head = notice:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    head:SetPoint("TOP", notice, "TOP", 0, -18)
    head:SetText("Chain quest")
    noticeText = notice:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    noticeText:SetPoint("TOP", head, "BOTTOM", 0, -8)
    noticeText:SetWidth(320)
    noticeText:SetJustifyV("TOP")
    local hint = notice:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOP", noticeText, "BOTTOM", 0, -2)
    hint:SetText(GREY .. "Turn this off in Settings, under Helpers." .. END)
    local ok = Button("pfQuest_xpGuideChainNoticeOk", notice, 100, "Got it")
    ok:SetPoint("BOTTOM", notice, "BOTTOM", 0, 30)
    ok:SetScript("OnClick", function() notice:Hide() end)
  end
  local text = GOLD .. title .. END .. WHITE .. " starts a chain of " .. total .. " quests." .. END
  if nextTitle then text = text .. GREY .. " Next: " .. nextTitle .. "." .. END end
  -- The box grows with the text, so a long title is never cut at big text size.
  notice:SetHeight(116 + ER.FitHeight(noticeText, text, 320, 14))
  notice:Show()
  PlaySound("igQuestListOpen")
end

ER.Loaded("ChainNotice.lua")
