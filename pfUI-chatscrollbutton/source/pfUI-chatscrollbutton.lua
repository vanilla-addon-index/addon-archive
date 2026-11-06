local chatFrames = {}

local function CreateScrollButton(chatFrame, id)
  local btn = CreateFrame("Button", "pfChatScrollDownBtn" .. id, chatFrame)

  btn:SetWidth(22)
  btn:SetHeight(22)
  btn:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT", -2, 2)
  btn:SetFrameStrata(chatFrame:GetFrameStrata())

  btn:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false,
    tileSize = 0,
    edgeSize = 1,
    insets = {
      left = 0,
      right = 0,
      top = 0,
      bottom = 0
    }
  })

  btn:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
  btn:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.6)

  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(pfUI.media["img:down"])
  icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
  icon:SetWidth(14)
  icon:SetHeight(14)
  icon:SetVertexColor(1, 1, 1, 0.9)
  btn.icon = icon

  local glow = btn:CreateTexture(nil, "OVERLAY")
  glow:SetTexture("Interface\\Buttons\\WHITE8X8")
  glow:SetAllPoints(btn)
  glow:SetVertexColor(0.2, 0.8, 0.6, 0.25)
  glow:Hide()

  btn.glow = glow
  btn.isMouseOver = false
  btn.pulseTime = 0
  btn.hasUnread = false
  btn.borderState = "idle" -- "idle" | "hover" | "unread"

  btn:SetScript("OnEnter", function()
    btn.isMouseOver = true
    icon:SetVertexColor(1, 1, 1, 1)
  end)

  btn:SetScript("OnLeave", function()
    btn.isMouseOver = false
    icon:SetVertexColor(1, 1, 1, 0.9)
  end)

  btn:SetScript("OnClick", function()
    chatFrame:ScrollToBottom()
    btn.hasUnread = false
    btn:Hide()
  end)

  btn:Hide()
  chatFrame.scrollDownBtn = btn
end

for i = 1, 7 do
  local chatFrame = getglobal("ChatFrame" .. i)

  if chatFrame then
    CreateScrollButton(chatFrame, i)
    table.insert(chatFrames, chatFrame)
  end
end

for _, chatFrame in ipairs(chatFrames) do
  local originalAddMessage = chatFrame.AddMessage

  chatFrame.AddMessage = function(self, ...)
    local wasScrolledUp = self:IsVisible() and not self:AtBottom()

    originalAddMessage(self, ...)

    if wasScrolledUp and self.scrollDownBtn and self ~= ChatFrame2 then
      self.scrollDownBtn.hasUnread = true

      if self.scrollDownBtn.pulseTime <= 0 then
        self.scrollDownBtn.pulseTime = 0.45
      end

      self.scrollDownBtn:Show()
    end
  end
end

local watcher = CreateFrame("Frame")

watcher:SetScript("OnUpdate", function()
  for _, chatFrame in ipairs(chatFrames) do
    local btn = chatFrame.scrollDownBtn
    local shouldShow = chatFrame:IsVisible() and not chatFrame:AtBottom()
    local glowAlpha = 0

    if shouldShow and not btn:IsShown() then
      btn:Show()
    elseif not shouldShow and btn:IsShown() then
      btn:Hide()
    end

    if not shouldShow then
      btn.hasUnread = false
      btn.pulseTime = 0
    end

    local targetBorderState

    if btn.hasUnread then
      targetBorderState = "unread"
    elseif btn.isMouseOver then
      targetBorderState = "hover"
    else
      targetBorderState = "idle"
    end

    if targetBorderState ~= btn.borderState then
      if targetBorderState == "unread" then
        btn:SetBackdropBorderColor(0.2, 0.8, 0.6, 1)
      elseif targetBorderState == "hover" then
        btn:SetBackdropBorderColor(0.7, 0.7, 0.7, 0.9)
      else
        btn:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.6)
      end

      btn.borderState = targetBorderState
    end

    if btn.hasUnread then
      if btn.isMouseOver then
        glowAlpha = 0.25
      end

      if btn.pulseTime > 0 then
        btn.pulseTime = btn.pulseTime - arg1

        if btn.pulseTime < 0 then
          btn.pulseTime = 0
        end

        local pulseProgress = 1 - (btn.pulseTime / 0.45)
        local pulseAlpha = 0.15 + (math.sin(pulseProgress * math.pi) * 0.55)

        if pulseAlpha > glowAlpha then
          glowAlpha = pulseAlpha
        end
      end
    end

    if glowAlpha > 0 then
      btn.glow:SetVertexColor(0.2, 0.8, 0.6, glowAlpha)
      btn.glow:Show()
    else
      btn.glow:Hide()
    end
  end
end)
