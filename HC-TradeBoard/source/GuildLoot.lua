-- Passive Guild/World/Trade offers; notifications never send chat or peer traffic.
local TB = TradeBoard
local FOLLOWUP_SECONDS = 60
local DISPLAY_SECONDS = 60
local DEDUP_SECONDS = 120
local MAX_QUEUE = 20
local MAX_ITEMS = 12
local ROWS = 4
local QUESTION_TEXTURE = "Interface\\Icons\\INV_Misc_QuestionMark"
local OFFER_WORDS = { "anyone", "anybody", "any1", "need", "needs", "free", "giving", "giveaway" }

TB.GuildLoot = { queue = {}, contexts = {}, recent = {}, page = 1 }

local function PlainOfferText(message)
    local text = string.gsub(message or "", "|c%x+|Hitem:[^|]+|h%[[^]]+%]|h|r", " ")
    return string.lower(text)
end

local function HasWord(text, word)
    return string.find(" " .. text .. " ", "[%s%p]" .. word .. "[%s%p]") ~= nil
end

local function OfferKind(text, channel)
    if HasWord(text, "wtb") or string.find(text, "want to buy", 1, 1) then return nil end
    local tagged = string.find(text, "give away", 1, 1) ~= nil
    local i
    for i = 1, table.getn(OFFER_WORDS) do
        if HasWord(text, OFFER_WORDS[i]) then tagged = true; break end
    end
    local selling = HasWord(text, "wts") or HasWord(text, "selling") or string.find(text, "for sale", 1, 1)
    -- Public channels use offer tags; routine WTS traffic stays in Browse.
    if selling and (channel == "Guild" or tagged) then return "SELL" end
    if tagged then return "GIVE" end
    return nil
end

function TB:GetLootMessageColor(offer)
    if offer.channel == "Guild" then return 0.25, 1.00, 0.25 end
    local number = tonumber(offer.channelNumber)
    local info
    if ChatTypeInfo then
        if number and number > 0 then info = ChatTypeInfo["CHANNEL" .. math.floor(number)] end
        info = info or ChatTypeInfo.CHANNEL
    end
    if info and info.r and info.g and info.b then return info.r, info.g, info.b end
    return 1.00, 0.75, 0.75
end

local function PruneRecords(records, now, ttl, limit)
    local result = {}
    local i
    for i = 1, table.getn(records) do
        if now - records[i].at <= ttl then table.insert(result, records[i]) end
    end
    while table.getn(result) > limit do table.remove(result, 1) end
    return result
end

function TB:IsGuildLootEnabled()
    return not TradeBoardDB or TradeBoardDB.guildLootEnabled ~= 0
end

function TB:SetGuildLootEnabled(enabled)
    TradeBoardDB = TradeBoardDB or {}
    TradeBoardDB.guildLootEnabled = enabled and 1 or 0
    if not enabled then self:ClearGuildLoot() end
end

function TB:ClearGuildLoot()
    self.GuildLoot.queue = {}
    self.GuildLoot.contexts = {}
    self.GuildLoot.recent = {}
    self.GuildLoot.active = nil
    if self.GuildLoot.frame then self.GuildLoot.frame:Hide() end
end

function TB:CaptureGuildLootMessage(message, sender)
    return self:CaptureLootMessage(message, sender, "Guild")
end

function TB:CaptureLootMessage(message, sender, channelName, channelNumber)
    local channel
    if string.lower(channelName or "") == "guild" then channel = "Guild"
    elseif self:IsWorldChannel(channelName) then channel = "World"
    elseif self:IsTradeChannel(channelName) then channel = "Trade"
    else return nil end
    if not self:IsGuildLootEnabled() or (self.IsLootSourceEnabled and not self:IsLootSourceEnabled(channel)) or not message or not sender or sender == "" then return nil end
    if string.lower(sender) == string.lower(UnitName("player") or "") then return nil end
    local state = self.GuildLoot
    local now = GetTime()
    local author = string.lower(sender)
    state.contexts = PruneRecords(state.contexts, now, FOLLOWUP_SECONDS, 31)
    state.recent = PruneRecords(state.recent, now, DEDUP_SECONDS, 99)
    local plain = PlainOfferText(message)
    local kind = OfferKind(plain, channel)
    local links = self:ExtractWorldItemLinks(message)
    local context, i
    for i = 1, table.getn(state.contexts) do
        if state.contexts[i].author == author and state.contexts[i].channel == channel then context = state.contexts[i]; break end
    end
    if kind then
        if not context then
            context = { author = author, channel = channel }
            table.insert(state.contexts, context)
        end
        context.kind = kind
        context.at = now
    elseif context and table.getn(links) > 0 and not string.find(plain, "%a") then
        kind = context.kind
        context.at = now
    else
        -- An unrelated message ends this author's offer continuation.
        if context then context.at = now - FOLLOWUP_SECONDS - 1 end
        return nil
    end
    if table.getn(links) == 0 then return nil end
    local uniqueLinks = {}
    for i = 1, math.min(table.getn(links), MAX_ITEMS) do
        local key = channel .. ":" .. author .. ":" .. kind .. ":" .. (self:ExtractItemKey(links[i]) or links[i])
        local duplicate = nil
        local j
        for j = 1, table.getn(state.recent) do
            if state.recent[j].key == key then duplicate = 1; break end
        end
        if not duplicate then
            table.insert(uniqueLinks, links[i])
            table.insert(state.recent, { key = key, at = now })
        end
    end
    while table.getn(state.recent) > 100 do table.remove(state.recent, 1) end
    if table.getn(uniqueLinks) == 0 then return nil end
    local offer
    if state.active and state.active.author == author and state.active.kind == kind and state.active.channel == channel then offer = state.active end
    if not offer then
        for i = 1, table.getn(state.queue) do
            if state.queue[i].author == author and state.queue[i].kind == kind and state.queue[i].channel == channel then offer = state.queue[i]; break end
        end
    end
    if offer and table.getn(offer.links) + table.getn(uniqueLinks) > MAX_ITEMS then offer = nil end
    if not offer then
        if not tonumber(channelNumber) then
            local _, _, prefix = string.find(channelName or "", "^(%d+)%.")
            channelNumber = tonumber(prefix)
        end
        offer = { author = author, sender = sender, kind = kind, links = {}, at = now, message = message,
            channel = channel, channelNumber = tonumber(channelNumber) }
        table.insert(state.queue, offer)
        while table.getn(state.queue) > MAX_QUEUE do table.remove(state.queue, 1) end
    end
    for i = 1, table.getn(uniqueLinks) do table.insert(offer.links, uniqueLinks[i]) end
    self:ShowGuildLootPopup()
    return offer
end

local function Text(parent, font)
    return parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
end

local function Button(parent, label, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetWidth(width)
    button:SetHeight(23)
    button:SetText(label)
    return button
end

local MUTE_DURATIONS = {
    { label = "5 minutes", seconds = 300 },
    { label = "10 minutes", seconds = 600 },
    { label = "60 minutes", seconds = 3600 },
    { label = "2 hours", seconds = 7200 },
    { label = "Until enabled", seconds = -1 },
}

-- Kept local to the popup so it does not depend on the main window being open.
local function MuteDurationDropdown(parent)
    local button = Button(parent, "", 145)
    local arrow = button:CreateTexture(nil, "ARTWORK")
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    arrow:SetWidth(18)
    arrow:SetHeight(18)
    arrow:SetPoint("RIGHT", button, "RIGHT", -3, 0)
    local menu = CreateFrame("Frame", nil, button)
    menu:SetWidth(145)
    menu:SetHeight(table.getn(MUTE_DURATIONS) * 23 + 8)
    menu:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, 2)
    menu:SetFrameStrata("TOOLTIP")
    menu:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    menu:SetBackdropColor(0.04, 0.03, 0.02, 1)
    menu:EnableMouse(true)
    menu:Hide()
    button.menu = menu
    button.options = {}

    function button:SetDuration(seconds)
        self.seconds = tonumber(seconds) or 600
        local i
        for i = 1, table.getn(MUTE_DURATIONS) do
            if MUTE_DURATIONS[i].seconds == self.seconds then
                self:SetText(MUTE_DURATIONS[i].label)
                break
            end
        end
        TradeBoardDB = TradeBoardDB or {}
        TradeBoardDB.popupMuteSeconds = self.seconds
    end

    local i
    for i = 1, table.getn(MUTE_DURATIONS) do
        local option = Button(menu, MUTE_DURATIONS[i].label, 135)
        option:SetPoint("TOPLEFT", menu, "TOPLEFT", 5, -4 - (i - 1) * 23)
        option.seconds = MUTE_DURATIONS[i].seconds
        option:SetScript("OnClick", function()
            button:SetDuration(this.seconds)
            menu:Hide()
        end)
        button.options[i] = option
    end
    button:SetScript("OnClick", function()
        if menu:IsShown() then menu:Hide() else menu:Show() end
    end)
    button:SetScript("OnHide", function() menu:Hide() end)
    local saved = TradeBoardDB and tonumber(TradeBoardDB.popupMuteSeconds) or 600
    button:SetDuration(saved)
    return button
end

function TB:CreateGuildLootPopup()
    local state = self.GuildLoot
    if state.frame then return state.frame end
    local frame = CreateFrame("Frame", "HCTradeBoardGuildLoot", UIParent)
    state.frame = frame
    frame:SetWidth(330)
    frame:SetHeight(337)
    frame:SetPoint("RIGHT", UIParent, "RIGHT", -30, 70)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
    frame:SetBackdropColor(0.05, 0.04, 0.02, 1)
    frame.title = Text(frame)
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
    frame.title:SetText("Guild loot offers")
    frame.close = Button(frame, "X", 24)
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -9, -9)
    frame.close:SetScript("OnClick", function() TB:DismissGuildLoot() end)
    frame.seller = Text(frame, "GameFontHighlightSmall")
    frame.seller:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -38)
    frame.seller:SetWidth(295)
    frame.seller:SetJustifyH("LEFT")
    frame.message = Text(frame, "GameFontHighlightSmall")
    frame.message:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -56)
    frame.message:SetWidth(295)
    frame.message:SetHeight(30)
    frame.message:SetJustifyH("LEFT")
    frame.rows = {}
    local i
    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, frame)
        row:SetWidth(296)
        row:SetHeight(34)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -94 - (i - 1) * 35)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetWidth(30)
        row.icon:SetHeight(30)
        row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.label = Text(row, "GameFontHighlightSmall")
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 7, 0)
        row.label:SetWidth(255)
        row.label:SetHeight(30)
        row.label:SetJustifyH("LEFT")
        row:SetScript("OnEnter", function()
            if not this.itemLink then return end
            local _, _, hyperlink = string.find(this.itemLink, "|H([^|]+)|h")
            if hyperlink then
                GameTooltip:SetOwner(this, "ANCHOR_LEFT")
                GameTooltip:SetHyperlink(hyperlink)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnClick", function()
            if not this.itemLink then return end
            if IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsShown() then
                ChatFrameEditBox:Insert(this.itemLink)
            elseif SetItemRef then
                local _, _, hyperlink = string.find(this.itemLink, "|H([^|]+)|h")
                if hyperlink then SetItemRef(hyperlink, this.itemLink, "LeftButton") end
            end
        end)
        frame.rows[i] = row
    end
    frame.previous = Button(frame, "<", 25)
    frame.previous:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 15, 70)
    frame.previous:SetScript("OnClick", function() state.page = math.max(1, state.page - 1); TB:ShowGuildLootPopup() end)
    frame.next = Button(frame, ">", 25)
    frame.next:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -15, 70)
    frame.next:SetScript("OnClick", function() state.page = state.page + 1; TB:ShowGuildLootPopup() end)
    frame.count = Text(frame, "GameFontHighlightSmall")
    frame.count:SetPoint("BOTTOM", frame, "BOTTOM", 0, 76)
    frame.muteDuration = MuteDurationDropdown(frame)
    frame.muteDuration:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 41)
    frame.mute = Button(frame, "Mute Guild", 137)
    frame.mute:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 41)
    frame.mute:SetScript("OnClick", function()
        if state.active and TB.SetLootMute then
            TB:SetLootMute(state.active.channel, frame.muteDuration.seconds)
        end
    end)
    frame.whisper = Button(frame, "Whisper", 137)
    frame.whisper:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 12)
    frame.whisper:SetScript("OnClick", function()
        if state.active then TB:OpenWorldWhisper(state.active.sender) end
    end)
    frame.dismiss = Button(frame, "Dismiss", 137)
    frame.dismiss:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 12)
    frame.dismiss:SetScript("OnClick", function() TB:DismissGuildLoot() end)
    frame:SetScript("OnUpdate", function()
        if state.active and GetTime() - state.shownAt >= DISPLAY_SECONDS then TB:DismissGuildLoot() end
    end)
    frame:Hide()
    return frame
end

function TB:ShowGuildLootPopup()
    local state = self.GuildLoot
    if not self:IsGuildLootEnabled() then return end
    if not state.active then
        state.active = table.remove(state.queue, 1)
        while state.active and self.IsLootSourceEnabled and not self:IsLootSourceEnabled(state.active.channel) do
            state.active = table.remove(state.queue, 1)
        end
        state.page = 1
        state.shownAt = GetTime()
    end
    if not state.active then
        if state.frame then state.frame:Hide() end
        return
    end
    local frame = self:CreateGuildLootPopup()
    local offer = state.active
    frame.mute:SetText(offer.channel == "Guild" and "Mute Guild" or "Mute World/Trade")
    local count = table.getn(offer.links)
    local pages = math.max(1, math.ceil(count / ROWS))
    state.page = math.min(state.page, pages)
    if offer.kind == "WANTED" then
        frame.title:SetText("Wanted item found - " .. (offer.channel or "World"))
        frame.seller:SetText("Match for " .. (offer.wanted or "your subscription") .. " from " .. offer.sender)
    else
        frame.title:SetText((offer.channel or "Guild") .. " loot offers")
        local verb = offer.kind == "SELL" and " is selling" or " is offering loot"
        frame.seller:SetText(offer.sender .. verb .. (offer.channel == "Guild" and " to guildmates" or ""))
    end
    local r, g, b = self:GetLootMessageColor(offer)
    frame.seller:SetTextColor(r, g, b)
    frame.message:SetTextColor(r, g, b)
    -- Item rows carry the links; the small chat excerpt retains prices/conditions.
    local excerpt = string.gsub(offer.message or "", "|c%x+|Hitem:[^|]+|h(%[[^]]+%])|h|r", "%1")
    excerpt = string.gsub(excerpt, "|c%x%x%x%x%x%x%x%x", "")
    excerpt = string.gsub(excerpt, "|r", "")
    frame.message:SetText(excerpt)
    local i
    for i = 1, ROWS do
        local row = frame.rows[i]
        row.itemLink = offer.links[(state.page - 1) * ROWS + i]
        if row.itemLink then
            local item = self.GetItemMetadata and self:GetItemMetadata(row.itemLink)
            row.icon:SetTexture(item and item.texture or QUESTION_TEXTURE)
            row.label:SetText(row.itemLink)
            row:Show()
        else
            row:Hide()
        end
    end
    frame.count:SetText(state.page .. "/" .. pages .. "  -  " .. count .. " items  -  " .. table.getn(state.queue) .. " queued")
    if state.page > 1 then frame.previous:Enable() else frame.previous:Disable() end
    if state.page < pages then frame.next:Enable() else frame.next:Disable() end
    frame:Show()
end

function TB:DismissGuildLoot()
    GameTooltip:Hide()
    self.GuildLoot.active = nil
    self:ShowGuildLootPopup()
end

local events = CreateFrame("Frame")
TB.GuildLoot.events = events
events:RegisterEvent("CHAT_MSG_GUILD")
events:RegisterEvent("CHAT_MSG_CHANNEL")
events:RegisterEvent("PLAYER_GUILD_UPDATE")
events:SetScript("OnEvent", function()
    if event == "CHAT_MSG_GUILD" then TB:CaptureGuildLootMessage(arg1, arg2)
    elseif event == "CHAT_MSG_CHANNEL" then
        local channel = arg9 and arg9 ~= "" and arg9 or arg4
        if TB:IsWorldChannel(channel) or TB:IsTradeChannel(channel) then
            TB:CaptureLootMessage(arg1, arg2, channel, arg8)
        end
    elseif event == "PLAYER_GUILD_UPDATE" and (not arg1 or arg1 == "player") then TB:ClearGuildLoot() end
end)
