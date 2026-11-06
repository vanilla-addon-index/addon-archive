pfUI_profiles = pfUI_profiles or {}

local apex_loader = CreateFrame("Frame")
apex_loader:RegisterEvent("VARIABLES_LOADED")
apex_loader:SetScript("OnEvent", function()
  apex_loader:UnregisterAllEvents()

  -- Base: Modern como fundación garantizada
  local apex = pfUI.api.CopyTable(pfUI_profiles["Modern"])
  if not apex then return end

  -------------------------------------------------------------
  -- 1. POSICIONES DEL LAYOUT (APEX v4.0)                    --
  -- Filosofía: HUD centrado inferior, espacio superior libre.--
  -------------------------------------------------------------
  apex["position"] = apex["position"] or {}

  -- UnitFrames: simétricos, centrados tácticos, posicionados más abajo
  apex.position["pfPlayer"]       = { anchor = "BOTTOM",      parent = "UIParent",            xpos = -190, ypos = 200 }
  apex.position["pfTarget"]       = { anchor = "BOTTOM",      parent = "UIParent",            xpos =  190, ypos = 200 }
  apex.position["pfTargetTarget"] = { anchor = "BOTTOM",      parent = "UIParent",            xpos =  380, ypos = 175 }
  apex.position["pfPet"]          = { anchor = "BOTTOM",      parent = "UIParent",            xpos = -350, ypos = 175 }
  apex.position["pfFocus"]        = { anchor = "TOPLEFT",     parent = "UIParent",            xpos =  14,  ypos = -230 }

  -- Castbars: player centrado, target anclado sobre el frame
  apex.position["pfPlayerCastbar"] = { anchor = "BOTTOM",    parent = "UIParent",             xpos = 0, ypos = 150 }
  apex.position["pfTargetCastbar"] = { anchor = "BOTTOM",    parent = "pfTarget",             xpos = 0, ypos = 55 }

  -- ActionBars: flotantes en el fondo, apiladas
  apex.position["pfActionBarMain"]        = { anchor = "BOTTOM",      parent = "UIParent",            xpos = 0,  ypos = 45 }
  apex.position["pfActionBarBottomLeft"]  = { anchor = "BOTTOM",      parent = "pfActionBarMain",     xpos = 0,  ypos = 42 }
  apex.position["pfActionBarBottomRight"] = { anchor = "BOTTOM",      parent = "pfActionBarBottomLeft", xpos = 0, ypos = 42 }
  apex.position["pfActionBarLeft"]        = { anchor = "BOTTOMLEFT",  parent = "UIParent",            xpos =  3, ypos = 190 }
  apex.position["pfActionBarRight"]       = { anchor = "BOTTOMRIGHT", parent = "UIParent",            xpos = -3, ypos = 190 }

  -- Microbar y Bags (esquina inferior derecha)
  apex.position["pfMicroBar"] = { anchor = "BOTTOMRIGHT", parent = "UIParent",   xpos = -10, ypos = 45 }
  apex.position["pfBagBar"]   = { anchor = "BOTTOMRIGHT", parent = "pfMicroBar", xpos = 0,   ypos = 30 }

  -- Minimap: circular, esquina superior derecha
  apex.position["pfMinimap"] = { anchor = "TOPRIGHT", parent = "UIParent", xpos = -22, ypos = -22 }

  -- Swing Timer: debajo del castbar del jugador
  apex.position["pfSwingTimerMainhand"] = { anchor = "BOTTOM", parent = "UIParent", xpos = -205, ypos = 212 }
  apex.position["pfSwingTimerRanged"]   = { anchor = "BOTTOM", parent = "UIParent", xpos = -205, ypos = 192 }

  -- Mark Tracking: borde izquierdo, a media pantalla
  apex.position["pfMarkTracking"] = { anchor = "LEFT", parent = "UIParent", xpos = 4, ypos = 17 }

  -------------------------------------------------------------
  -- 2. UNITFRAMES (Dragonflight Style, completo)            --
  -------------------------------------------------------------
  apex["unitframes"] = apex["unitframes"] or {}

  -- Globales de unitframes
  apex.unitframes.disable         = "0"
  apex.unitframes.pastel          = "0"
  apex.unitframes.animation_speed = "3"
  apex.unitframes.customfade      = "1"
  apex.unitframes.customfullhp    = "1"
  apex.unitframes.custom          = "2"
  apex.unitframes.custombg        = "1"

  -- Paleta de colores de recurso (vibrantes y premium, Ultimate-Tier)
  apex.unitframes.manacolor      = "0.05,0.65,1.00,1"
  apex.unitframes.ragecolor      = "1.00,0.15,0.15,1"
  apex.unitframes.energycolor    = "1.00,0.85,0.10,1"
  apex.unitframes.focuscolor     = "1.00,0.50,0.15,1"
  apex.unitframes.customcolor    = "0.08,0.08,0.08,1"
  apex.unitframes.custombgcolor  = "0.15,0.05,0.05,0.4"
  apex.unitframes.custompbgcolor = "0.05,0.05,0.20,0.4"

  -- Combo points
  apex.unitframes.combowidth  = "12"
  apex.unitframes.comboheight = "5"

  -- PLAYER ---------------------------------------------------
  apex.unitframes["player"] = apex.unitframes["player"] or {}
  apex.unitframes.player.width         = "230"
  apex.unitframes.player.height        = "50"
  apex.unitframes.player.pheight       = "8"
  apex.unitframes.player.pspace        = "1"
  apex.unitframes.player.panchor       = "TOPRIGHT"
  apex.unitframes.player.portrait      = "bar"
  apex.unitframes.player.portraitalpha = "0.35"
  apex.unitframes.player.txthpright    = "curmax"
  apex.unitframes.player.txthpcenter   = "none"
  apex.unitframes.player.txthpleft     = "none"
  apex.unitframes.player.txtpowerright = "powerdyn"
  apex.unitframes.player.buffsize      = "14"
  apex.unitframes.player.buffperrow    = "8"
  apex.unitframes.player.debuffs       = "TOPRIGHT"
  apex.unitframes.player.showPVP       = "1"
  apex.unitframes.player.bartexture    = "Interface\\AddOns\\pfUI\\img\\bar_gradient"
  apex.unitframes.player.pbartexture   = "Interface\\AddOns\\pfUI\\img\\bar_gradient"

  -- TARGET ---------------------------------------------------
  apex.unitframes["target"] = apex.unitframes["target"] or {}
  apex.unitframes.target.width         = "230"
  apex.unitframes.target.height        = "50"
  apex.unitframes.target.pheight       = "8"
  apex.unitframes.target.pspace        = "1"
  apex.unitframes.target.panchor       = "TOPLEFT"
  apex.unitframes.target.portrait      = "bar"
  apex.unitframes.target.portraitalpha = "0.35"
  apex.unitframes.target.txthpleft     = "curmax"
  apex.unitframes.target.txthpcenter   = "none"
  apex.unitframes.target.txthpright    = "unitrev"
  apex.unitframes.target.txtpowerright = "powerdyn"
  apex.unitframes.target.buffsize      = "14"
  apex.unitframes.target.buffperrow    = "8"
  apex.unitframes.target.buffs         = "TOPRIGHT"
  apex.unitframes.target.debuffs       = "TOPRIGHT"
  apex.unitframes.target.bartexture    = "Interface\\AddOns\\pfUI\\img\\bar_gradient"
  apex.unitframes.target.pbartexture   = "Interface\\AddOns\\pfUI\\img\\bar_gradient"

  -- TARGET OF TARGET -----------------------------------------
  apex.unitframes["ttarget"] = apex.unitframes["ttarget"] or {}
  apex.unitframes.ttarget.width      = "130"
  apex.unitframes.ttarget.height     = "22"
  apex.unitframes.ttarget.pheight    = "5"
  apex.unitframes.ttarget.pspace     = "1"
  apex.unitframes.ttarget.portrait   = "off"
  apex.unitframes.ttarget.bartexture  = "Interface\\AddOns\\pfUI\\img\\bar_gradient"
  apex.unitframes.ttarget.pbartexture = "Interface\\AddOns\\pfUI\\img\\bar_gradient"

  -- TARGET OF TARGET OF TARGET (TttTarget) -------------------
  apex.unitframes["tttarget"] = apex.unitframes["tttarget"] or {}
  apex.unitframes.tttarget.width      = "120"
  apex.unitframes.tttarget.height     = "16"
  apex.unitframes.tttarget.pheight    = "4"
  apex.unitframes.tttarget.pspace     = "1"
  apex.unitframes.tttarget.portrait   = "off"
  apex.unitframes.tttarget.bartexture  = "Interface\\AddOns\\pfUI\\img\\bar_gradient"
  apex.unitframes.tttarget.pbartexture = "Interface\\AddOns\\pfUI\\img\\bar_gradient"

  -- PET ------------------------------------------------------
  apex.unitframes["pet"] = apex.unitframes["pet"] or {}
  apex.unitframes.pet.width         = "130"
  apex.unitframes.pet.height        = "22"
  apex.unitframes.pet.pheight       = "5"
  apex.unitframes.pet.pspace        = "1"
  apex.unitframes.pet.portrait      = "off"
  apex.unitframes.pet.bufflimit     = "8"
  apex.unitframes.pet.buffsize      = "9"
  apex.unitframes.pet.buffs         = "BOTTOMLEFT"
  apex.unitframes.pet.debuffs       = "BOTTOMRIGHT"
  apex.unitframes.pet.bartexture    = "Interface\\AddOns\\pfUI\\img\\bar_gradient"
  apex.unitframes.pet.pbartexture   = "Interface\\AddOns\\pfUI\\img\\bar_gradient"
  apex.unitframes.pet.txtpowercenter = "healthdyn"

  -- PET TARGET (ptarget) --------------------------------------
  apex.unitframes["ptarget"] = apex.unitframes["ptarget"] or {}
  apex.unitframes.ptarget.width      = "130"
  apex.unitframes.ptarget.height     = "8"
  apex.unitframes.ptarget.pheight    = "-1"
  apex.unitframes.ptarget.pspace     = "-1"
  apex.unitframes.ptarget.portrait   = "off"
  apex.unitframes.ptarget.bartexture  = "Interface\\AddOns\\pfUI\\img\\bar_gradient"
  apex.unitframes.ptarget.pbartexture = "Interface\\AddOns\\pfUI\\img\\bar_gradient"

  -- FOCUS ----------------------------------------------------
  apex.unitframes["focus"] = apex.unitframes["focus"] or {}
  apex.unitframes.focus.width       = "185"
  apex.unitframes.focus.height      = "32"
  apex.unitframes.focus.pheight     = "7"
  apex.unitframes.focus.pspace      = "1"
  apex.unitframes.focus.portrait    = "off"
  apex.unitframes.focus.buffsize    = "11"
  apex.unitframes.focus.bartexture  = "Interface\\AddOns\\pfUI\\img\\bar_gradient"
  apex.unitframes.focus.pbartexture = "Interface\\AddOns\\pfUI\\img\\bar_gradient"

  -- FOCUS TARGET ---------------------------------------------
  apex.unitframes["focustarget"] = apex.unitframes["focustarget"] or {}
  apex.unitframes.focustarget.width      = "120"
  apex.unitframes.focustarget.height     = "14"
  apex.unitframes.focustarget.pheight    = "-1"
  apex.unitframes.focustarget.portrait   = "off"
  apex.unitframes.focustarget.bartexture  = "Interface\\AddOns\\pfUI\\img\\bar_gradient"
  apex.unitframes.focustarget.pbartexture = "Interface\\AddOns\\pfUI\\img\\bar_gradient"

  -- RAID FRAMES (40 hombres, compactos) ----------------------
  apex.unitframes["raid"] = apex.unitframes["raid"] or {}
  apex.unitframes.raid.width          = "44"
  apex.unitframes.raid.height         = "30"
  apex.unitframes.raid.pheight        = "5"
  apex.unitframes.raid.pspace         = "1"
  apex.unitframes.raid.verticalbar    = "1"
  apex.unitframes.raid.txthpleft      = "none"
  apex.unitframes.raid.txthpright     = "none"
  apex.unitframes.raid.txthpcenter    = "namehealthbreak"
  apex.unitframes.raid.customfade     = "1"
  apex.unitframes.raid.customfullhp   = "1"
  apex.unitframes.raid.glowaggro      = "0"
  apex.unitframes.raid.indicator_pos  = "TOPRIGHT"
  apex.unitframes.raid.raidpadding    = "5"
  apex.unitframes.raid.defcolor       = "0"
  apex.unitframes.raid.custom         = "2"
  apex.unitframes.raid.manacolor      = "0.22,0.32,0.68,1"
  apex.unitframes.raid.ragecolor      = "0.68,0.12,0.12,1"
  apex.unitframes.raid.energycolor    = "0.78,0.60,0.08,1"
  apex.unitframes.raid.focuscolor     = "0.50,0.30,0.70,1"
  apex.unitframes.raid.customcolor    = "0.06,0.06,0.06,1"
  apex.unitframes.raid.clickcast      = "1"
  apex.unitframes.raid.debuff_indicator  = "3"
  apex.unitframes.raid.debuff_ind_pos    = "BOTTOM"
  apex.unitframes.raid.debuff_ind_size   = "0.50"
  apex.unitframes.raid.bartexture     = "Interface\\AddOns\\pfUI\\img\\bar_gradient"
  apex.unitframes.raid.pbartexture    = "Interface\\AddOns\\pfUI\\img\\bar_gradient"

  -- GROUP (party 5) ------------------------------------------
  apex.unitframes["group"] = apex.unitframes["group"] or {}
  apex.unitframes.group.width         = "115"
  apex.unitframes.group.height        = "22"
  apex.unitframes.group.pheight       = "5"
  apex.unitframes.group.pspace        = "1"
  apex.unitframes.group.portrait      = "off"
  apex.unitframes.group.bartexture    = "Interface\\AddOns\\pfUI\\img\\bar_gradient"
  apex.unitframes.group.pbartexture   = "Interface\\AddOns\\pfUI\\img\\bar_gradient"

  -- GROUP TARGET ---------------------------------------------
  apex.unitframes["grouptarget"] = apex.unitframes["grouptarget"] or {}
  apex.unitframes.grouptarget.width      = "100"
  apex.unitframes.grouptarget.height     = "12"
  apex.unitframes.grouptarget.pheight    = "3"
  apex.unitframes.grouptarget.pspace     = "1"
  apex.unitframes.grouptarget.portrait   = "off"
  apex.unitframes.grouptarget.bartexture  = "Interface\\AddOns\\pfUI\\img\\bar_gradient"
  apex.unitframes.grouptarget.pbartexture = "Interface\\AddOns\\pfUI\\img\\bar_gradient"

  -- GROUP PET ------------------------------------------------
  apex.unitframes["grouppet"] = apex.unitframes["grouppet"] or {}
  apex.unitframes.grouppet.width      = "80"
  apex.unitframes.grouppet.height     = "8"
  apex.unitframes.grouppet.pheight    = "-1"
  apex.unitframes.grouppet.pspace     = "-1"
  apex.unitframes.grouppet.portrait   = "off"
  apex.unitframes.grouppet.bartexture  = "Interface\\AddOns\\pfUI\\img\\bar_gradient"
  apex.unitframes.grouppet.pbartexture = "Interface\\AddOns\\pfUI\\img\\bar_gradient"

  -------------------------------------------------------------
  -- 3. CASTBARS                                             --
  -------------------------------------------------------------
  apex["castbar"] = apex["castbar"] or {}

  apex.castbar["player"] = apex.castbar["player"] or {}
  apex.castbar.player.height   = "22"
  apex.castbar.player.showrank = "1"
  apex.castbar.player.showlag  = "1"
  apex.castbar.player.showicon = "1"

  apex.castbar["target"] = apex.castbar["target"] or {}
  apex.castbar.target.height   = "16"
  apex.castbar.target.showicon = "1"

  -------------------------------------------------------------
  -- 4. APARIENCIA GENERAL                                   --
  -------------------------------------------------------------
  apex["appearance"] = apex["appearance"] or {}

  -- Minimap
  apex.appearance["minimap"] = apex.appearance["minimap"] or {}
  apex.appearance.minimap.size      = "165"
  apex.appearance.minimap.square    = "0"
  apex.appearance.minimap.coordsloc = "bottomleft"

  -- Bordes unificados: negro profundo + sombra
  apex.appearance["border"] = apex.appearance["border"] or {}
  apex.appearance.border.color       = "0.06,0.06,0.06,1"
  apex.appearance.border.background  = "0.04,0.04,0.04,0.96"
  apex.appearance.border.default     = "2"
  apex.appearance.border.bags        = "3"
  apex.appearance.border.chat        = "3"
  apex.appearance.border.unitframes  = "1"
  apex.appearance.border.actionbars  = "1"
  apex.appearance.border.panels      = "1"
  apex.appearance.border.shadow      = "1"

  -- Castbar texture
  apex.appearance["castbar"] = apex.appearance["castbar"] or {}
  apex.appearance.castbar.texture = "Interface\\AddOns\\pfUI\\img\\bar_gradient"

  -- In-combat: sólo efecto de elementos comunes, no pantalla completa
  apex.appearance["infight"] = apex.appearance["infight"] or {}
  apex.appearance.infight.screen = "0"
  apex.appearance.infight.common = "1"

  -- Cooldown countdown font
  apex.appearance["cd"] = apex.appearance["cd"] or {}
  apex.appearance.cd.font = "Interface\\AddOns\\pfUI\\fonts\\ZhunYuan.ttf"

  -- Bag borders sin límite artificial
  apex.appearance["bags"] = apex.appearance["bags"] or {}
  apex.appearance.bags.borderlimit = "0"

  -- Worldmap: exploración de zona activa
  apex.appearance["worldmap"] = apex.appearance["worldmap"] or {}
  apex.appearance.worldmap.mapexploration = "1"

  -------------------------------------------------------------
  -- 5. CHAT                                                  --
  -------------------------------------------------------------
  apex["chat"] = apex["chat"] or {}

  apex.chat["global"] = apex.chat["global"] or {}
  apex.chat.global.custombg   = "1"
  apex.chat.global.border     = "0.06,0.06,0.06,0.65"
  apex.chat.global.background = "0.04,0.04,0.04,0.28"
  apex.chat.global.tabmouse   = "1"
  apex.chat.global.tabdock    = "0"

  apex.chat["left"] = apex.chat["left"] or {}
  apex.chat.left.width  = "420"
  apex.chat.left.height = "155"

  apex.chat["right"] = apex.chat["right"] or {}
  apex.chat.right.width  = "420"
  apex.chat.right.height = "155"

  apex.chat["text"] = apex.chat["text"] or {}
  apex.chat.text.outline     = "0"
  apex.chat.text.timecolor   = "0.35,0.35,0.35,0.6"
  apex.chat.text.timebracket = ""

  -------------------------------------------------------------
  -- 6. BARRAS DE ACCIÓN                                     --
  -------------------------------------------------------------
  apex["bars"] = apex["bars"] or {}
  apex.bars.icon_size  = "36"
  apex.bars.spacing    = "3"
  apex.bars.background = "0"
  apex.bars.macro_size = "8"
  apex.bars.count_size = "9"
  apex.bars.font       = "Interface\\AddOns\\pfUI\\fonts\\ZhunYuan.ttf"

  apex.bars["bar1"] = apex.bars["bar1"] or {}
  apex.bars.bar1.icon_size   = "36"
  apex.bars.bar1.background  = "0"

  apex.bars["bar3"] = apex.bars["bar3"] or {}
  apex.bars.bar3.formfactor = "12 x 1"
  apex.bars.bar3.buttons    = "6"
  apex.bars.bar3.icon_size  = "36"
  apex.bars.bar3.background = "0"

  apex.bars["bar4"] = apex.bars["bar4"] or {}
  apex.bars.bar4.enable = "0"

  apex.bars["bar5"] = apex.bars["bar5"] or {}
  apex.bars.bar5.formfactor = "12 x 1"
  apex.bars.bar5.buttons    = "6"
  apex.bars.bar5.icon_size  = "36"
  apex.bars.bar5.background = "0"

  apex.bars["bar6"] = apex.bars["bar6"] or {}
  apex.bars.bar6.icon_size  = "24"
  apex.bars.bar6.background = "0"

  apex.bars["bar11"] = apex.bars["bar11"] or {}
  apex.bars.bar11.background = "0"
  apex.bars.bar11.spacing    = "3"

  apex.bars["bar12"] = apex.bars["bar12"] or {}
  apex.bars.bar12.icon_size  = "20"
  apex.bars.bar12.background = "0"

  -- Microbar horizontal
  apex.bars["micro"] = apex.bars["micro"] or {}
  apex.bars.micro.enable     = "1"
  apex.bars.micro.horizontal = "1"

  -- Gryphons: DESACTIVADOS (look minimalista)
  apex.bars["gryphons"] = apex.bars["gryphons"] or {}
  apex.bars.gryphons.texture = "none"

  -------------------------------------------------------------
  -- 7. PANEL XP / REP                                       --
  -------------------------------------------------------------
  apex["panel"] = apex["panel"] or {}

  -- Ocultar paneles inferiores de chat y microbar
  apex.panel.use_left  = "0"
  apex.panel.use_right = "0"
  apex.panel.hide_leftpanel  = "1"
  apex.panel.hide_rightpanel = "1"
  apex.panel.hide_minimappanel = "1"
  apex.panel.hide_microbar   = "1"

  apex.panel["left"] = apex.panel["left"] or {}
  apex.panel.left.left = "exp"

  apex.panel["xp"] = apex.panel["xp"] or {}
  apex.panel.xp.dont_overlap = "1"
  apex.panel.xp.xp_always    = "1"
  apex.panel.xp.xp_mode      = "HORIZONTAL"
  apex.panel.xp.xp_position  = "TOP"
  apex.panel.xp.xp_anchor    = "pfActionBarLeft"
  apex.panel.xp.xp_color     = "0.40,0.60,0.85,1"
  apex.panel.xp.xp_height    = "4"
  apex.panel.xp.rest_color   = "0.28,0.40,0.55,0.55"
  apex.panel.xp.rep_always   = "1"
  apex.panel.xp.rep_mode     = "HORIZONTAL"
  apex.panel.xp.rep_position = "TOP"
  apex.panel.xp.rep_anchor   = "pfActionBarRight"
  apex.panel.xp.rep_height   = "4"
  apex.panel.xp.rep_display  = "FLEX"

  -------------------------------------------------------------
  -- 8. NAMEPLATES                                           --
  -------------------------------------------------------------
  apex["nameplates"] = apex["nameplates"] or {}
  apex.nameplates.heighthealth   = "10"
  apex.nameplates.selfdebuff     = "1"
  apex.nameplates.healthtexture  = "Interface\\AddOns\\pfUI\\img\\bar_gradient"
  apex.nameplates.combatofftank  = "0.50,0.00,0.72,1"
  apex.nameplates.use_unitfonts  = "0"
  apex.nameplates["health"] = apex.nameplates["health"] or {}
  apex.nameplates.health.offset  = "10"

  -------------------------------------------------------------
  -- 9. BUFF BARS                                            --
  -------------------------------------------------------------
  apex["buffbar"] = apex["buffbar"] or {}

  apex.buffbar["pbuff"] = apex.buffbar["pbuff"] or {}
  apex.buffbar.pbuff.enable = "1"
  apex.buffbar.pbuff.height = "14"

  apex.buffbar["pdebuff"] = apex.buffbar["pdebuff"] or {}
  apex.buffbar.pdebuff.enable = "1"
  apex.buffbar.pdebuff.height = "14"

  apex.buffbar["tdebuff"] = apex.buffbar["tdebuff"] or {}
  apex.buffbar.tdebuff.enable     = "1"
  apex.buffbar.tdebuff.height     = "14"
  apex.buffbar.tdebuff.selfdebuff = "1"

  -------------------------------------------------------------
  -- 10. TIPOGRAFÍA Y GLOBALS                                --
  -------------------------------------------------------------
  apex["global"] = apex["global"] or {}
  apex.global.font_unit      = "Interface\\AddOns\\pfUI\\fonts\\ZhunYuan.ttf"
  apex.global.font_size      = "12"
  apex.global.font_unit_size = "13"
  apex.global.pixelperfect   = "1"
  apex.global.offcolor       = "0.04,0.04,0.04,1"

  -------------------------------------------------------------
  -- 11. TOOLTIP                                             --
  -------------------------------------------------------------
  apex["tooltip"] = apex["tooltip"] or {}
  apex.tooltip.position = "default"
  apex.tooltip["statusbar"] = apex.tooltip["statusbar"] or {}
  apex.tooltip.statusbar.texture = "Interface\\AddOns\\pfUI\\img\\bar_gradient"

  -------------------------------------------------------------
  -- 12. ADDON BUTTONS                                       --
  -------------------------------------------------------------
  apex["abuttons"] = apex["abuttons"] or {}
  apex.abuttons.enable       = "1"
  apex.abuttons.hideincombat = "0"

  -------------------------------------------------------------
  -- 13. THIRDPARTY ADDON SKINS                             --
  -- Unifica ventanas de otros addons con la estética Apex. --
  -------------------------------------------------------------
  apex["thirdparty"] = apex["thirdparty"] or {}
  apex.thirdparty.chatbg  = "1"  -- Aplica fondo de chat a ventanas de meters

  apex.thirdparty["dpsmate"] = apex.thirdparty["dpsmate"] or {}
  apex.thirdparty.dpsmate.skin = "1"

  apex.thirdparty["swstats"] = apex.thirdparty["swstats"] or {}
  apex.thirdparty.swstats.skin = "1"

  apex.thirdparty["shagudps"] = apex.thirdparty["shagudps"] or {}
  apex.thirdparty.shagudps.skin = "1"

  -------------------------------------------------------------
  -- 14. REGISTRO DEL PERFIL                                 --
  -------------------------------------------------------------
  pfUI_profiles["Apex"] = apex

  pfUI_profiles["Apex"].new_module_positions = {
    pfPlayer             = apex.position["pfPlayer"],
    pfTarget             = apex.position["pfTarget"],
    pfTargetTarget       = apex.position["pfTargetTarget"],
    pfPet                = apex.position["pfPet"],
    pfFocus              = apex.position["pfFocus"],
    pfPlayerCastbar      = apex.position["pfPlayerCastbar"],
    pfTargetCastbar      = apex.position["pfTargetCastbar"],
    pfActionBarMain      = apex.position["pfActionBarMain"],
    pfActionBarLeft      = apex.position["pfActionBarLeft"],
    pfActionBarRight     = apex.position["pfActionBarRight"],
    pfMinimap            = apex.position["pfMinimap"],
    pfSwingTimerMainhand = apex.position["pfSwingTimerMainhand"],
    pfSwingTimerRanged   = apex.position["pfSwingTimerRanged"],
    pfMarkTracking       = apex.position["pfMarkTracking"],
  }
end)
