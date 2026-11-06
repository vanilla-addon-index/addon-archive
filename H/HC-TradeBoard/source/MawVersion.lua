-- Shared, lightweight peer version discovery for MawAddons.
-- Every Maw addon ships this file. The first copy loaded owns the single
-- channel/frame; later copies only register their addon in the shared manifest.

if not MawAddonVersionCheck then
    MawAddonVersionCheck = {
        PROTOCOL = "MAV1",
        CHANNEL = "MawAddons",
        addons = {},
        warned = {},
        pendingNeeds = {},
        started = nil,
        announced = nil,
        nextJoin = 0,
        replyAt = nil,
        elapsed = 0,
    }

    local MVC = MawAddonVersionCheck

    local function Trim(value)
        value = tostring(value or "")
        value = string.gsub(value, "^%s+", "")
        value = string.gsub(value, "%s+$", "")
        return value
    end

    local function VersionParts(version)
        local parts = {}
        version = string.gsub(string.lower(Trim(version)), "^v", "")
        for number in string.gfind(version, "(%d+)") do
            table.insert(parts, tonumber(number) or 0)
        end
        return parts
    end

    function MVC:CompareVersions(left, right)
        local a, b = VersionParts(left), VersionParts(right)
        local count = math.max(table.getn(a), table.getn(b))
        local index
        for index = 1, count do
            local av, bv = a[index] or 0, b[index] or 0
            if av > bv then return 1 end
            if av < bv then return -1 end
        end
        return 0
    end

    function MVC:Register(slug, name, version)
        if type(slug) ~= "string" or type(name) ~= "string" or type(version) ~= "string" then return end
        self.addons[slug] = {
            slug = slug,
            name = name,
            version = version,
            url = "https://github.com/MawAddons/" .. slug,
        }
    end

    function MVC:RegisterKnown()
        if HCBlackBox and HCBlackBox.VERSION then self:Register("HC-BlackBox", "HC Black Box", HCBlackBox.VERSION) end
        if HCChallenger and HCChallenger.VERSION then self:Register("HC-Challenger", "HC Challenger", HCChallenger.VERSION) end
        if HCDangerMap and HCDangerMap.VERSION then self:Register("HC-DangerMap", "HC Danger Map", HCDangerMap.VERSION) end
        if HCCommunityDetector and HCCommunityDetector.VERSION then self:Register("HC-Detector", "HC Detector", HCCommunityDetector.VERSION) end
        if HCGhostBuddy and HCGhostBuddy.VERSION then self:Register("HC-GhostBuddy", "HC Ghost Buddy", HCGhostBuddy.VERSION) end
        if HCMapper and HCMapper.VERSION then self:Register("HC-Mapper", "HC Mapper", HCMapper.VERSION) end
        if TradeBoard and TradeBoard.VERSION then self:Register("HC-Tradeboard", "HC TradeBoard", TradeBoard.VERSION) end
    end

    function MVC:HideChannel()
        if type(ChatFrame_RemoveChannel) ~= "function" then return end
        local count = tonumber(NUM_CHAT_WINDOWS) or 7
        local index
        for index = 1, count do
            local frame = getglobal and getglobal("ChatFrame" .. index) or nil
            if frame then ChatFrame_RemoveChannel(frame, self.CHANNEL) end
        end
        if DEFAULT_CHAT_FRAME then ChatFrame_RemoveChannel(DEFAULT_CHAT_FRAME, self.CHANNEL) end
    end

    function MVC:Manifest()
        local slugs, fields = {}, {}
        local slug
        for slug in pairs(self.addons) do table.insert(slugs, slug) end
        table.sort(slugs)
        local index
        for index = 1, table.getn(slugs) do
            slug = slugs[index]
            table.insert(fields, slug .. "=" .. self.addons[slug].version)
        end
        return self.PROTOCOL .. "~H~" .. table.concat(fields, ",")
    end

    function MVC:SendManifest()
        local channel = GetChannelName and GetChannelName(self.CHANNEL) or 0
        if not channel or channel == 0 or type(SendChatMessage) ~= "function" then return nil end
        local message = self:Manifest()
        if string.len(message) > 240 then return nil end
        SendChatMessage(message, "CHANNEL", nil, channel)
        return 1
    end

    function MVC:ParseManifest(message)
        if type(message) ~= "string" or string.len(message) > 240 then return nil end
        if string.sub(message, 1, 7) ~= self.PROTOCOL .. "~H~" then return nil end
        local remote = {}
        local payload = string.sub(message, 8)
        for field in string.gfind(payload, "([^,]+)") do
            local _, _, slug, version = string.find(field, "^([%w%-]+)=([%w%.%-]+)$")
            if slug and version then remote[slug] = version end
        end
        return remote
    end

    function MVC:Notify(addon, remoteVersion)
        local warnedVersion = self.warned[addon.slug]
        if warnedVersion and self:CompareVersions(warnedVersion, remoteVersion) >= 0 then return end
        self.warned[addon.slug] = remoteVersion
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffd200" .. addon.name .. "|r: New version is available. Please keep up to date. |cff66ccff" .. addon.url .. "|r")
        end
    end

    function MVC:HandleManifest(message)
        local remote = self:ParseManifest(message)
        if not remote then return end
        local needsReply = nil
        local slug, addon
        for slug, addon in pairs(self.addons) do
            local remoteVersion = remote[slug]
            if remoteVersion then
                local comparison = self:CompareVersions(remoteVersion, addon.version)
                if comparison > 0 then
                    self.pendingNeeds[slug] = nil
                    self:Notify(addon, remoteVersion)
                elseif comparison < 0 then
                    self.pendingNeeds[slug] = addon.version
                    needsReply = 1
                elseif self.pendingNeeds[slug] then
                    self.pendingNeeds[slug] = nil
                end
            end
        end
        if needsReply and not self.replyAt then
            local name = UnitName and UnitName("player") or "Maw"
            local hash, index = 0, 1
            while index <= string.len(name) do hash = hash + string.byte(name, index); index = index + 1 end
            self.replyAt = GetTime() + 2 + math.mod(hash, 7)
        end
        if self.replyAt then
            local waiting = nil
            for slug in pairs(self.pendingNeeds) do waiting = 1 end
            if not waiting then self.replyAt = nil end
        end
    end

    function MVC:OnEvent(eventName, one)
        if eventName == "VARIABLES_LOADED" or eventName == "PLAYER_ENTERING_WORLD" then
            self:RegisterKnown()
            self.started = 1
            self.nextJoin = GetTime() + 3
        elseif eventName == "CHAT_MSG_CHANNEL" then
            self:HandleManifest(one)
        elseif eventName == "CHAT_MSG_CHANNEL_NOTICE" then
            self:HideChannel()
        end
    end

    function MVC:OnUpdate(elapsed)
        if not self.started then return end
        self.elapsed = self.elapsed + (tonumber(elapsed) or 0)
        if self.elapsed < 0.25 then return end
        self.elapsed = 0
        local now = GetTime()
        if not self.announced and now >= self.nextJoin then
            local channel = GetChannelName and GetChannelName(self.CHANNEL) or 0
            if not channel or channel == 0 then
                if type(JoinChannelByName) == "function" then JoinChannelByName(self.CHANNEL, nil, DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME:GetID() or 1) end
                self.nextJoin = now + 3
            else
                self:HideChannel()
                if self:SendManifest() then self.announced = 1 end
            end
        end
        if self.replyAt and now >= self.replyAt then
            self.replyAt = nil
            self.pendingNeeds = {}
            self:SendManifest()
        end
    end

    local frame = CreateFrame("Frame", "MawAddonVersionFrame", UIParent)
    frame:RegisterEvent("VARIABLES_LOADED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("CHAT_MSG_CHANNEL")
    frame:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
    frame:SetScript("OnEvent", function() MVC:OnEvent(event, arg1) end)
    frame:SetScript("OnUpdate", function() MVC:OnUpdate(arg1) end)
    MVC.frame = frame
end

MawAddonVersionCheck:RegisterKnown()
