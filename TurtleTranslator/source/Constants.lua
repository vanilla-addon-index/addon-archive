-- Constants.lua (loaded FIRST)

ADDON_VERSION = GetAddOnMetadata("TurtleTranslator", "Version") or "Unknown"

lookups = lookups or {}
translations = translations or {}

langNames = {"es","fr","de","it","pt","pl","ru","ro","cs"}

TurtleTranslatorDB = TurtleTranslatorDB or {
    enabled = true,
    channels = {
        whisper = true,
        say     = true,
        yell    = true,
        party   = true,
		guild	= true,
		emote	= true,
		officer = false,
		raid	= false,
		raidwarning = false,
		battleground = false,
		otherchannels = false,
    },
    targetLangIndex = 0,  -- 0=English, 1=Spanish, etc.
	sourceLangs = {     -- NEW: which source languages to translate FROM
        [0] = false,    -- English → usually don't translate
        [1] = true,
        [2] = true,
        [3] = true,
        [4] = true,
        [5] = true,
        [6] = true,
        [7] = true,
        [8] = true,
        [9] = true,
    },
	debugEnabled = false,  -- new: debug prints off by default
	windowPos = { x = 0, y = 0 },  -- default position (center)
}

-- Ensure channels defaults (your existing code)
defaultChannels = {
    whisper = true,
    say     = true,
    yell    = true,
    party   = true,
    guild   = true,
	emote	= true,
    officer = false,
    raid    = false,
    raidwarning = false,
    battleground = false,
    otherchannels = false,
}

-- Language list – define here so EVERYONE sees it
langs = {
    {index = 0, name = "English"},
    {index = 1, name = "Spanish"},
    {index = 2, name = "French"},
    {index = 3, name = "German"},
    {index = 4, name = "Italian"},
    {index = 5, name = "Portuguese"},
    {index = 6, name = "Polish"},
    {index = 7, name = "Russian"},
	{index = 8, name = "Romanian"},
    {index = 9, name = "Czech"},
}

numLangs = 0
for _ in ipairs(langs) do
    numLangs = numLangs + 1
end