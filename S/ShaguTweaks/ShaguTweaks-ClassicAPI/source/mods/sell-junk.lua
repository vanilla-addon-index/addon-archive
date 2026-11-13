local _G = ShaguTweaks.GetGlobalEnv()
local T = ShaguTweaks.T
local API = ShaguTweaks.API

local module = ShaguTweaks:register({
  title = T["Sell Junk"],
  description = T["Adds a “Sell Junk” button to every merchant window, that sells all grey items."],
  expansions = { ["vanilla"] = true },
  category = T["Tooltip & Items"],
  enabled = true,
})

local function CreateGoldString(money)
  if type(money) ~= "number" then return "-" end

  local gold = floor(money/ 100 / 100)
  local silver = floor(mod((money/100),100))
  local copper = floor(mod(money,100))

  local string = ""
  if gold > 0 then string = string .. "|cffffffff" .. gold .. "|cffffd700g" end
  if silver > 0 or gold > 0 then string = string .. "|cffffffff " .. silver .. "|cffc7c7cfs" end
  string = string .. "|cffffffff " .. copper .. "|cffeda55fc"

  return string
end

local function HasGreyItems()
  return API.GetNumJunkItems() > 0
end

module.enable = function(self)
  local autovendor = CreateFrame("Frame", nil, nil)
  autovendor:Hide()

  autovendor:SetScript("OnShow", function()
    this.startMoney = GetMoney()
    this.lastCount = API.GetNumJunkItems()
    this.started = this.lastCount > 0
    this.elapsed = 0
    this.progressUntil = GetTime() + 5

    if not this.started then
      this:Hide()
      return
    end

    -- ClassicAPI performs a real merchant sale and drains the queue one item
    -- per frame, without abusing UseContainerItem or a manual throttle.
    API.SellAllJunkItems()
    this.button:Update()
  end)

  autovendor:SetScript("OnHide", function()
    if this.started and this.startMoney then
      local earned = GetMoney() - this.startMoney
      if earned > 0 then
        DEFAULT_CHAT_FRAME:AddMessage(T["Your vendor trash has been sold and you earned"] .. " " .. CreateGoldString(earned))
      end
    end

    this.started = nil
    this.startMoney = nil
    this.lastCount, this.elapsed, this.progressUntil = nil, nil, nil
    if this.button then this.button:Update() end
  end)

  -- Native code owns sale pacing. Check completion ten times per second and
  -- stop waiting after five seconds without progress; never resubmit the sale.
  autovendor:SetScript("OnUpdate", function()
    if not this.started then return end
    this.elapsed = this.elapsed + arg1
    if this.elapsed < .1 then return end
    this.elapsed = 0
    local count = API.GetNumJunkItems()
    local now = GetTime()
    if count < this.lastCount then this.progressUntil = now + 5 end
    this.lastCount = count
    if count == 0 or now >= this.progressUntil then this:Hide() end
  end)

  autovendor:RegisterEvent("MERCHANT_SHOW")
  autovendor:RegisterEvent("MERCHANT_CLOSED")
  autovendor:RegisterEvent("MERCHANT_UPDATE")
  autovendor:SetScript("OnEvent", function()
    if event == "MERCHANT_CLOSED" then
      autovendor.merchant = nil
      autovendor:Hide()
    elseif event == "MERCHANT_SHOW" then
      autovendor.merchant = true
      autovendor.button:Show()
    end

    autovendor.button:Update()

    MerchantRepairText:SetText("")
    if MerchantRepairItemButton:IsShown() then
      autovendor.button:ClearAllPoints()
      autovendor.button:SetPoint("RIGHT", MerchantRepairItemButton, "LEFT", -4, 0)
    else
      autovendor.button:ClearAllPoints()
      autovendor.button:SetPoint("RIGHT", MerchantBuyBackItemItemButton, "LEFT", -14, 0)
    end
  end)

  -- Setup Autosell button
  autovendor.button = CreateFrame("Button", nil, MerchantFrame)
  autovendor.button:SetWidth(36)
  autovendor.button:SetHeight(36)
  autovendor.button:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
  autovendor.button:SetNormalTexture("Interface\\Icons\\Spell_Shadow_SacrificialShield")
  autovendor.button:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(T["Sell Grey Items"])
    GameTooltip:Show()
  end)

  autovendor.button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  autovendor.button:SetScript("OnClick", function()
    autovendor:Show()
  end)

  autovendor.button.Update = function()
    if not autovendor:IsVisible() then
      if HasGreyItems() then
        autovendor.button:Enable()
        autovendor.button:GetNormalTexture():SetDesaturated(false)
      else
        autovendor.button:Disable()
        autovendor.button:GetNormalTexture():SetDesaturated(true)
      end
    else
      autovendor.button:Disable()
      autovendor.button:GetNormalTexture():SetDesaturated(true)
    end
  end

  -- Hook MerchantFrame_Update
  if not HookMerchantFrame_Update then
    local HookMerchantFrame_Update = MerchantFrame_Update
    function _G.MerchantFrame_Update()
      if MerchantFrame.selectedTab == 1 then
        autovendor.button:Show()
      else
        autovendor.button:Hide()
      end
      HookMerchantFrame_Update()
    end
  end
end
