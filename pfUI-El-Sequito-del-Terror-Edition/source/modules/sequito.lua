pfUI:RegisterModule("sequito", "vanilla:tbc:wotlk", function ()
  local T = pfUI.env.T
  local L = pfUI.env.L
  local C = pfUI.env.C

  -- Branding Colors
  local color_sequito = "00ccff"
  local color_pink = "ff00cc"
  
  -- Séquito Translations (Lua 5.0 Compatible)
  local locale = GetLocale()
  local SL = {
    ["enUS"] = {
      ["WELCOME"] = "pfUI v%s-Terror detected. Elnazzareno welcomes you to the tactical ecosystem.",
      ["BRAIN_MISSING"] = "|cffff4444[ALERT]|r: WCS_Brain not detected. The abyssal core is missing.",
      ["ARSENAL_HEADER"] = "THE ARSENAL OF THE SEQUITO",
      ["LORE_HEADER"] = "LORE OF THE SHIRTLESS",
      ["LORE_TEXT"] = "Born from cheese. Forged in revenge. Written shirtless.",
      ["STATUS_ACTIVE"] = "|cff00ff00[ACTIVE]|r",
      ["STATUS_MISSING"] = "|cffff4444[MISSING]|r",
      ["CLAN_TAB"] = "Séquito del Terror",
      ["NAMPOWER_TITLE"] = "|cffff0000!!! SETUP REQUIRED !!!|r",
      ["NAMPOWER_BODY"] = "Nampower DLL (v3.0.0+) is missing. To fix the 'Nampower Not Found' error and enable full UI power:",
      ["NAMPOWER_STEP1"] = "1. Click the button below to copy the link.",
      ["NAMPOWER_STEP2"] = "2. Download and place the .dll in your WoW folder (where WoW.exe is).",
      ["NAMPOWER_COPY"] = "COPY DOWNLOAD LINK",
    },
    ["esES"] = {
      ["WELCOME"] = "pfUI v%s-Terror detectado. Elnazzareno te da la bienvenida al ecosistema táctico.",
      ["BRAIN_MISSING"] = "|cffff4444[ALERTA]|r: WCS_Brain no detectado. El núcleo abismal está ausente.",
      ["ARSENAL_HEADER"] = "EL ARSENAL DEL SEQUITO",
      ["LORE_HEADER"] = "LORE DEL DESCAMISADO",
      ["LORE_TEXT"] = "Nacido del queso. Forjado en la venganza. Escrito sin camisa.",
      ["STATUS_ACTIVE"] = "|cff00ff00[ACTIVO]|r",
      ["STATUS_MISSING"] = "|cffff4444[AUSENTE]|r",
      ["CLAN_TAB"] = "Séquito del Terror",
      ["NAMPOWER_TITLE"] = "|cffff0000!!! REQUIERE CONFIGURACIÓN !!!|r",
      ["NAMPOWER_BODY"] = "Falta la DLL de Nampower (v3.0.0+). Para arreglar el error y activar todo el poder del UI:",
      ["NAMPOWER_STEP1"] = "1. Pulsa el botón de abajo para copiar el enlace.",
      ["NAMPOWER_STEP2"] = "2. Descarga y pon la .dll en la carpeta de tu WoW (donde está el WoW.exe).",
      ["NAMPOWER_COPY"] = "COPIAR ENLACE DE DESCARGA",
    },
  }
  -- Fallback to enUS for everything else
  local ST = SL[locale] or SL["esES"] or SL["enUS"]
  if locale == "esMX" then ST = SL["esES"] end

  -- Welcome Message
  local welcome = CreateFrame("Frame")
  welcome:RegisterEvent("PLAYER_ENTERING_WORLD")
  welcome:SetScript("OnEvent", function()
    this:UnregisterEvent("PLAYER_ENTERING_WORLD")
    local ver = GetAddOnMetadata(pfUI.name, "Version") or "5.1.4 [Omni-Tier]"
    DEFAULT_CHAT_FRAME:AddMessage("|cff" .. color_sequito .. "[Séquito del Terror]|r: |cffffffff" .. string.format(ST["WELCOME"], ver) .. "|r")
    
    if not IsAddOnLoaded("WCS_Brain") then
      DEFAULT_CHAT_FRAME:AddMessage(ST["BRAIN_MISSING"])
    end
  end)

  -- Slash Command /sequito
  SLASH_SEQUITO1 = "/sequito"
  SlashCmdList["SEQUITO"] = function(msg)
    if not pfUI.gui:IsShown() then
      pfUI.gui:Show()
    end
    
    if pfUI.gui.frames and pfUI.gui.frames[ST["CLAN_TAB"]] then
      pfUI.gui.frames[ST["CLAN_TAB"]]:Click()
    end
  end

  -- GUI Integration
  pfUI.gui.CreateGUIEntry(ST["CLAN_TAB"], nil, function()
    -- Nampower Setup Wizard (Only show if missing)
    if not GetNampowerVersion then
      pfUI.gui.CreateConfig(nil, ST["NAMPOWER_TITLE"], nil, nil, "header")
      pfUI.gui.CreateConfig(nil, ST["NAMPOWER_BODY"], nil, nil, "header")
      pfUI.gui.CreateConfig(nil, ST["NAMPOWER_STEP1"], nil, nil, "header")
      pfUI.gui.CreateConfig(nil, ST["NAMPOWER_STEP2"], nil, nil, "header")
      pfUI.gui.CreateConfig(nil, " ", nil, nil, "header")
      
      -- Copy Link Button
      local copy = CreateFrame("Button", nil, this)
      copy:SetWidth(200)
      copy:SetHeight(20)
      pfUI.api.CreateBackdrop(copy)
      local copyFS = copy:CreateFontString(nil, "OVERLAY")
      copyFS:SetFont("Fonts\\ARIALN.TTF", 11, "OUTLINE")
      copyFS:SetAllPoints(copy)
      copyFS:SetText("|cff00ccff" .. ST["NAMPOWER_COPY"] .. "|r")
      copy:SetScript("OnClick", function()
        pfUI.chat.urlcopy.CopyText("https://gitea.com/avitasia/nampower/releases")
      end)
      
      -- Sistema Manual de Anclaje pfUI (Fix Error 145)
      copy:SetPoint("TOPLEFT", this, "TOPLEFT", 25, this.objectCount * -15)
      this.objectCount = this.objectCount + 1

      pfUI.gui.CreateConfig(nil, " ", nil, nil, "header")
      pfUI.gui.CreateConfig(nil, " ", nil, nil, "header")
    end

    pfUI.gui.CreateConfig(nil, "|cff" .. color_pink .. ST["ARSENAL_HEADER"] .. "|r", nil, nil, "header")
    
    local arsenal = {
      { name = "WCS_Brain", label = "WCS_Brain" },
      { name = "WCS_BrainIntegrations", label = "WCS_Integrations" },
      { name = "DoTimer", label = "DoTimer" },
      { name = "BigWigs", label = "BigWigs" },
      { name = "TerrorSquadAI", label = "TerrorSquadAI" },
      { name = "TerrorMeter", label = "TerrorMeter" },
      { name = "Atlas-TW", label = "Atlas-TW" },
      { name = "aux-addon", label = "AUX-Trading" },
      { name = "HealBot", label = "HealBot" },
      { name = "pfQuest", label = "pfQuest Séquito" },
      { name = "Nampower", label = "Nampower (DLL)", check = function() return GetNampowerVersion ~= nil end },
      { name = "SuperWoW", label = "SuperWoW (DLL)", check = function() return GetSuperWoWVersion ~= nil end },
    }

    for i, addon in ipairs(arsenal) do
      local loaded = false
      if addon.check then
        loaded = addon.check()
      else
        loaded = IsAddOnLoaded(addon.name)
      end
      
      local status = loaded and ST["STATUS_ACTIVE"] or ST["STATUS_MISSING"]
      pfUI.gui.CreateConfig(nil, addon.label .. " " .. status, nil, nil, "header")
    end

    pfUI.gui.CreateConfig(nil, " ", nil, nil, "header")
    -- Botón Abrir Cerebro
    local openBrain = CreateFrame("Button", nil, this)
    openBrain:SetWidth(200)
    openBrain:SetHeight(25)
    pfUI.api.CreateBackdrop(openBrain)
    local brainFS = openBrain:CreateFontString(nil, "OVERLAY")
    brainFS:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE")
    brainFS:SetAllPoints(openBrain)
    brainFS:SetText("|cff00ccffABRIR EL CEREBRO |cffffd700(v5.1.4)|r")
    openBrain:SetScript("OnClick", function()
      if WCS_BrainUI and WCS_BrainUI.Toggle then
        WCS_BrainUI:Toggle()
      end
    end)
    
    -- Sistema Manual de Anclaje pfUI (Fix Error 145)
    openBrain:SetPoint("TOPLEFT", this, "TOPLEFT", 25, this.objectCount * -15)
    this.objectCount = this.objectCount + 1

    pfUI.gui.CreateConfig(nil, " ", nil, nil, "header")
    pfUI.gui.CreateConfig(nil, "|cff" .. color_sequito .. ST["LORE_HEADER"] .. "|r", nil, nil, "header")
    pfUI.gui.CreateConfig(nil, ST["LORE_TEXT"], nil, nil, "header")
    
    pfUI.gui.CreateConfig(nil, " ", nil, nil, "header")
    pfUI.gui.CreateConfig(nil, "|cff00ccffDiscord:|r |cffffffffdiscord.gg/SfY8vfFWTC|r", nil, nil, "header")
  end)
end)
