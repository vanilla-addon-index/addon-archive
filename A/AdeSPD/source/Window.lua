-- AdeSPD output window: long command output (probe, explain, why, ...) in a scrollable, selectable text box
-- instead of the chat frame. Click into the text and use Ctrl+A / Ctrl+C to copy it.

local A = AdeSPD

local function Build()
  local f = CreateFrame("Frame", "AdeSPDWindow", UIParent)
  f:SetWidth(640)
  f:SetHeight(440)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetFrameStrata("DIALOG")
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

  local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  t:SetPoint("TOP", f, "TOP", 0, -16)
  f.title = t

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

  local scroll = CreateFrame("ScrollFrame", "AdeSPDWindowScroll", f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -40)
  scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -36, 20)

  local eb = CreateFrame("EditBox", "AdeSPDWindowEdit", scroll)
  eb:SetMultiLine(true)
  eb:SetAutoFocus(false)
  eb:SetFontObject(ChatFontNormal)
  eb:SetWidth(570)
  eb:SetHeight(400)
  eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  scroll:SetScrollChild(eb)
  f.eb = eb

  if UISpecialFrames then table.insert(UISpecialFrames, "AdeSPDWindow") end
  return f
end

-- lines: table of strings. Returns true when the window could be shown.
function A.ShowWindow(title, lines)
  local ok, res = pcall(function()
    local f = getglobal("AdeSPDWindow") or Build()
    f.title:SetText(title or "AdeSPD")
    local text = ""
    local rows = 0
    local i
    for i = 1, table.getn(lines) do
      local ln = lines[i]
      ln = string.gsub(ln, "|c%x%x%x%x%x%x%x%x", "")
      ln = string.gsub(ln, "|r", "")
      text = text .. ln .. "\n"
      rows = rows + 1 + math.floor(string.len(ln) / 78)
    end
    f.eb:SetText(text)
    local h = rows * 14 + 20
    if h < 400 then h = 400 end
    f.eb:SetHeight(h)
    f:Show()
    return true
  end)
  return ok and res
end
