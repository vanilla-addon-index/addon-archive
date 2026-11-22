-- pfUI Octo in a folder with the wrong name (26 Oct 2026, user: a friend's
-- download came out as "pfUI-Octo-octo" and OctoLauncher said "Missing .toc
-- file"). The game and OctoLauncher only load a folder that has a .toc of its
-- own name, and pfUI's pictures and fonts live at Interface\AddOns\pfUI\..., so
-- the folder must be called exactly pfUI. The .toc files named after the
-- folders the downloads make (GitHub's Download ZIP: pfUI-Octo-octo, pfUI-octo;
-- a pfUI-Octo clone...) load only this file: it says what to do instead of
-- leaving a broken UI. In a folder called pfUI the game reads only pfUI.toc,
-- so this file never runs there.

local function Folder()
  -- this addon's folder: the one whose title says "rename this folder"
  for i = 1, (GetNumAddOns and GetNumAddOns() or 0) do
    local name, title = GetAddOnInfo(i)
    if title and string.find(title, "rename this folder", 1, true) and IsAddOnLoaded(name) then return name end
  end
  return "this folder"
end

local function Text()
  local folder = Folder()
  local real = IsAddOnLoaded("pfUI")
  if real then
    return "pfUI Octo is in two folders: |cff33b3ffpfUI|r (the right one, in use) and |cffff6060" .. folder .. "|r.\n\n" ..
      "Close the game and delete the folder |cffff6060" .. folder .. "|r in Interface\\AddOns."
  end
  return "pfUI Octo is in the folder |cffff6060" .. folder .. "|r, so it can't start.\n\n" ..
    "1. Close the game.\n" ..
    "2. In Interface\\AddOns, rename |cffff6060" .. folder .. "|r to |cff33ffccpfUI|r (delete an older pfUI folder first).\n" ..
    "3. If you renamed a .toc file inside it, rename it back to pfUI.toc.\n" ..
    "4. Start the game from OctoLauncher.\n\n" ..
    "Or install it with OctoLauncher: Addons, Add custom git addon, https://github.com/bdot89/pfUI"
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
  this:UnregisterAllEvents()
  local text = Text()
  DEFAULT_CHAT_FRAME:AddMessage("|cff33b3ffpfUI Octo|r: " .. string.gsub(text, "\n+", " "), 1, .82, 0)
  StaticPopupDialogs["PFUI_OCTO_WRONG_FOLDER"] = {
    text = text,
    button1 = OKAY,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
  }
  StaticPopup_Show("PFUI_OCTO_WRONG_FOLDER")
end)
