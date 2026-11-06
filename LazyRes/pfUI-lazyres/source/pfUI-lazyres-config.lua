-- load pfUI environment
setfenv(1, pfUI:GetEnvironment())

function pfUI.lazyres:LoadConfig()
    -- pfUI:UpdateConfig("MODULE", "SUBGROUP", "key", "value")
    pfUI:UpdateConfig("lazyres", nil, "notification", "1")
    pfUI:UpdateConfig("lazyres", nil, "debug", "0")
end

pfUI.lazyres:LoadConfig()
