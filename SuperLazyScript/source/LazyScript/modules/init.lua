-- local _G = getfenv(0)

-- SuperWoW provides: UNIT_CASTEVENT, UnitPosition, SetMouseoverUnit, SpellInfo, etc.
if not SUPERWOW_VERSION then return lazyScript.p("SuperWoW not detected!") end

-- === ---------------- =====
-- === Simple Functions =====
-- === ---------------- =====
local gfind = string.gmatch or string.gfind
--local mod = math.mod or mod

local format, sgsub = string.format, string.gsub

-- ### Split x.y.z and returns x and y
-- -- disposes z bc i cba lowk
local function split(versionNumber)
    local iter = gfind(versionNumber, "(%d+)%.(%d+)%.?(%d*)")
    local major, minor, patch = iter()

    if not major or not minor then
        return nil, nil--,nil
    end

    major = tonumber(major)
    minor = tonumber(minor)
    --patch = tonumber(patch)

    return major, minor
end

-- ### Compare Version
-- -- Compares given version number to target
-- -- Returns boolean, nil otherwise
local function CompareVersion(version, target)
    local major, minor = split(version)
    local tmajor, tminor = split(target)

    major, minor = tonumber(major) or 0 , tonumber(minor) or 0
    tmajor, tminor = tonumber(tmajor) or 0 , tonumber(tminor) or 0

    if not (major and minor and tmajor and tminor) then
        lazyScript.p("Invalid SuperWoW version string")
    end

    if major ~= tmajor then
        return major > tmajor
    end

    return minor >= tminor
end

-- run

if SUPERWOW_STRING then
    lazyScript.p("LazyScript detected "..SUPERWOW_STRING) end
if not CompareVersion(SUPERWOW_VERSION, 2.2) then
    lazyScript.p("An outdated version of SuperWoW was detected. Please visit |cffffffff[https://github.com/balakethelock/SuperWoW/releases/tag/Release]|r")
end

local palette = {
    base01  = "|cff586e75",
    base00  = "|cff657b83",
    base1   = "|cff93a1a1",
    yellow  = "|cffb58900",
    orange  = "|cffcb4b16",
    red     = "|cffdc322f",
    magenta = "|cffd33682",
    violet  = "|cff6c71c4",
    blue    = "|cff268bd2",
    cyan    = "|cff2aa198",
    green   = "|cff859900",
    -- arimbaud: custom colors
    primary  = "|cffff8c69", -- salmon
    secondary= "|cffffffff", -- white
    close   = "|r",
}

-- # arimbaud: monkeypatching metadata for superLazyScript
-- ---
local orig_lazyScript = { metadata = { } }

orig_lazyScript.metadata.name = lazyScript.metadata.name
orig_lazyScript.metadata.version = lazyScript.metadata.version
orig_lazyScript.metadata.revision = lazyScript.metadata.revision

-- ### Monkeypatching lazyScript metadata & localisation
local function updateMetadata()
    lazyScript.metadata.name = palette.primary.."super"..palette.close..palette.secondary.."LazyScript"..palette.close
    lazyScript.metadata.version = "2.0" --v2.0
    lazyScript.metadata.revision = "1"  --r1
    -- luacheck: ignore
    LOADED = " loaded. All the rope you need...\n...and then a couple more feet, just to be sure.\nType |cffffff00/lazyscript help|r to get a list of commands."
    ABOUT_ALL_ROPE = "... and then a couple more feet, just to be sure."
end

-- #### Utility function for undoing meta changes
-- luacheck: ignore
local function restoreMetadata()
    lazyScript.metadata.name = orig_lazyScript.metadata.name
     lazyScript.metadata.version = orig_lazyScript.metadata.version
     lazyScript.metadata.revision = orig_lazyScript.metadata.revision
end


-- === run ===
updateMetadata()
