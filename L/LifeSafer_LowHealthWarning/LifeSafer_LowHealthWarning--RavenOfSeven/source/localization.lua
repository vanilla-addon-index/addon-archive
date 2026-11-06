

-- LowHealthWarning localization
--------------------------------------------------------------------------------

LifeSafer_LowHealthSettings_Labels = {
  [1] = "Low Health Warning",
  [2] = "Version",
}

LifeSafer_LowHealthSettings_Buttons = {
  [1] = DEFAULTS,
  [2] = CANCEL,
  [3] = OKAY,
}

LifeSafer_LowHealthSettings_Sliders = {
  ["Sound"] = {
    [1] = { "Health", "Activate heartbeat when health is below: %d%%", },
  },
  ["Health"] = {
    [1] = { "Health", "Health: %d%%", },
    [2] = { "Critical health", "Critical health: %d%%", },
  },
  ["Mana"] = {
    [1] = { "Mana", "Mana: %d%%", },
    [2] = { "Critical mana", "Critical mana: %d%%", },
  },
}

LifeSafer_LowHealthSettings_CheckButtons = {
  ["General"] = {
    [1] = { "Enable Low Health Warning", "Check to enable the addon.", },
    [2] = { "Large effects", "Check to use bolder textures.", },
  },
  ["Sound"] = {
    [1] = { "Enable heartbeat effect", "Check to enable a heartbeat sound effect.", },
    [2] = { "Only in combat", "Check to play sounds when in combat only.", },
  },
  ["Health"] = {
    [1] = { "Enable health effect", "Check to enable the health warning effect.", },
    [2] = { "Only in combat", "Check to display health warning in combat only.", },
    [3] = { "Variable flash rate", "Check to smoothly increase or decrease flash rate instead of using the two thresholds. This will synchronize the flash with the heartbeat." },
    [4] = { "Emote when critical", "Check to automatically perform the /healme emote when your health is critical.", },
  },
  ["Mana"] = {
    [1] = { "Enable mana effect", "Check to enable the health warning effect.", },
    [2] = { "Only in combat", "Check to display mana warning in combat only.", },
    [3] = { "Variable flash rate", "Check to smoothly increase or decrease flash rate instead of using the two thresholds.", },
    [4] = { "Emote when critical", "Check to automatically perform the /oom emote when your mana is below critical.", },
  },
}

if (GetLocale() == "deDE") then 

  -- German localization originally by Myr of European Gul'dan

  LifeSafer_LowHealthSettings_Labels = {
    [1] = "Low Health Warnung",
    [2] = "Version",
  }

  LifeSafer_LowHealthSettings_Buttons = {
    [1] = "Standard",
    [2] = "Abbrechen",
    [3] = "Ok",
  }

  LifeSafer_LowHealthSettings_Sliders = {
    ["Sound"] = { -- do not translate this line
      [1] = { "Leben", "Activate heartbeat when health is below: %d%%", },
    },
    ["Health"] = { -- do not translate this line
      [1] = { "Leben", "Leben: %d%%", },
      [2] = { "Kritische Lebenspunkte", "Kritische Lebenspunkte: %d%%", },
    },
    ["Mana"] = { -- do not translate this line
      [1] = { "Mana", "Mana: %d%%", },
      [2] = { "Kritisches Mana", "Kritisches Mana: %d%%", },
    },
  }

  LifeSafer_LowHealthSettings_CheckButtons = {
    ["General"] = { -- do not translate this line
      [1] = { "Enable Low Health Warning", "Check to enable the addon.", },
      [2] = { "Large effects", "Check to use bolder textures.", },
    },
    ["Sound"] = { -- do not translate this line
      [1] = { "Enable heartbeat effect", "Check to enable a heartbeat sound effect.", },
      [2] = { "Only in combat", "Check to play sounds when in combat only.", },
    },
    ["Health"] = { -- do not translate this line
      [1] = { "Enable health effect", "Check to enable the health warning effect.", },
      [2] = { "Only in combat", "Check to display health warning in combat only.", },
      [3] = { "Variable flash rate", "Check to smoothly increase or decrease flash rate instead of using the two thresholds. This will synchronize the flash with the heartbeat." },
      [4] = { "Emote when critical", "Check to automatically perform the /healme emote when your health is critical.", },
    },
    ["Mana"] = { -- do not translate this line
      [1] = { "Enable mana effect", "Check to enable the health warning effect.", },
      [2] = { "Only in combat", "Check to display mana warning in combat only.", },
      [3] = { "Variable flash rate", "Check to smoothly increase or decrease flash rate instead of using the two thresholds.", },
      [4] = { "Emote when critical", "Check to automatically perform the /oom emote when your mana is below critical.", },
    },
  }

end

if (GetLocale() == "frFR") then

  -- French localization originally by Trucifix
  -- Updated for 2.0+ by Feu

  LifeSafer_LowHealthSettings_Labels = {
    [1] = "Low Health Warning",
    [2] = "Version",
  }

  LifeSafer_LowHealthSettings_Buttons = {
    [1] = DEFAULTS,
    [2] = CANCEL,
    [3] = OKAY,
  }

  LifeSafer_LowHealthSettings_Sliders = {
    ["Sound"] = { -- do not translate this line
      [1] = { "Vie", "Active le battement de coeur lorsque la vie est en-dessous de %d%%", },
    },
    ["Health"] = { -- do not translate this line
      [1] = { "Vie", "Vie : %d%%", },
      [2] = { "Vie critique", "Vie critique : %d%%", },
    },
    ["Mana"] = { -- do not translate this line
      [1] = { "Mana", "Mana : %d%%", },
      [2] = { "Mana critique", "Mana critique : %d%%", },
    },
  }

  LifeSafer_LowHealthSettings_CheckButtons = {
    ["General"] = { -- do not translate this line
      [1] = { "Activer Low Health Warning", "Cocher pour activer l'addon.", },
      [2] = { "Effets larges", "Cocher pour utiliser des textures plus fonc\195\169es.", },
    },
    ["Sound"] = { -- do not translate this line
      [1] = { "Effet Battement de coeur", "Cocher pour activer l'effet sonore de battement de coeur.", },
      [2] = { "Seulement en combat", "Cocher pour jouer les sons seulement en combat.", },
    },
    ["Health"] = { -- do not translate this line
      [1] = { "Effet Vie faible", "Cocher pour activer l'effet d'avertissement de la vie.", },
      [2] = { "Seulement en combat", "Cocher pour afficher l'effet d'avertissement de la vie seulement en combat.", },
      [3] = { "Taux de clignotement", "Cocher pour doucement augmenter ou diminuer le tauxde clignotement au lieu d'utiliser les deux limites. Ceci synchronisera le clignotement avec le battement de coeur." },
      [4] = { "Emote critique", "Cocher pour faire automatiquement l'emote /healme lorsque votre vie est critique.", },
    },
    ["Mana"] = { -- do not translate this line
      [1] = { "Effet Mana faible", "Cocher pour activer l'effet d'avertissement de la mana.", },
      [2] = { "Seulement en combat", "Cocher pour afficher l'effet d'avertissement de la mana seulement en combat.", },
      [3] = { "Taux de clignotement", "Cocher pour doucement augmenter ou diminuer le tauxde clignotement au lieu d'utiliser les deux limites.", },
      [4] = { "Emote critique", "Cocher pour faire automatiquement l'emote /healme lorsque votre mana est critique.", },
    },
  }

end

if (GetLocale() == "koKR") then

  -- Korean localization originally by Mars

  LifeSafer_LowHealthSettings_Labels = {
    [1] = "Low Health Warning",
    [2] = "버젼",
  }

  LifeSafer_LowHealthSettings_Buttons = {
    [1] = DEFAULTS,
    [2] = CANCEL,
    [3] = OKAY,
  }
  
  LifeSafer_LowHealthSettings_Sliders = {
    ["Sound"] = { -- do not translate this line
      [1] = { "생명력", "생명력이 다음과 같을 때 심장박동 효과가 작동합니다: %d%%", },
    },
    ["Health"] = { -- do not translate this line
      [1] = { "생명력", "생명력: %d%%", },
      [2] = { "치명적인 생명력", "치명적인 생명력: %d%%", },
    },
    ["Mana"] = { -- do not translate this line
      [1] = { "마나", "마나: %d%%", },
      [2] = { "치명적인 마나", "치명적인 마나: %d%%", },
    },
  }

  LifeSafer_LowHealthSettings_CheckButtons = {
    ["General"] = { -- do not translate this line
      [1] = { "Low Life Warning 활성화", "Low Life Warning를 활성화시키려면 체크하세요.", },
      [2] = { "큰 화면효과", "굵은 화면텍스쳐를 사용하려면 체크하세요.", },
    },
    ["Sound"] = { -- do not translate this line
      [1] = { "심장박동 효과 활성화", "심장박동 사운드 효과를 활성화시키려면 체크하세요.", },
      [2] = { "전투시에만 사용", "전투시에만 음향효과를 재생하려면 체크하세요.", },
    },
    ["Health"] = { -- do not translate this line
      [1] = { "생명력 효과 활성화", "생명력 경고 효과를 활성화시키려면 체크하세요.", },
      [2] = { "전투시에만 사용", "전투시에만 생명력 경고를 표시하려면 체크하세요.", },
      [3] = { "부드러운 플래시 효과", "두 한계값을 이용하는 대신에 부드럽게 증가 또는 감소되는 플래시 효과를 사용하려면 체크하세요. 심장박동 음향효과와 플래시 시각효과는 일치됩니다." },
      [4] = { "치명적 상태시 감정표현", "생명력이 치명적인 상태 시 자동으로 '/치료' 감정표현을 이용하여 알리려면 체크하세요.", },
    },
    ["Mana"] = { -- do not translate this line
      [1] = { "마나 효과 활성화", "마나 경고 효과를 활성화시키려면 체크하세요.", },
      [2] = { "전투시에만 사용", "전투시에만 마나 경고를 표시하려면 체크하세요.", },
      [3] = { "부드러운 플래시 효과", "두 한계값을 이용하는 대신에 부드럽게 증가 또는 감소되는 플래시 효과를 사용하려면 체크하세요.", },
      [4] = { "치명적 상태시 감정표현", "마나가 치명적인 상태시 자동으로 '마나' 감정표현을 이용하여 알리려면 체크하세요.", },
    },
  }

end

-- Nightfall localization
--------------------------------------------------------------------------------

-- To localize this addon:
--   1: copy all the data to the language you're localizing to,
--   2: make sure the strings keep their order,
--   3: write a short comment somewhere in this file; let me know
--      under what name you want to be credited, and anything else
--      you'd like to add,
--   4: save and send this whole file to: silentaddons@gmail.com
--   5: Thank you :)


LifeSafer_NightfallSettings_Labels = {
  [1] = "Nightfall",
  [2] = "Version",
}

LifeSafer_NightfallSettings_ButtonStrings = {
  [1] = "Defaults",
  [2] = "Cancel",
  [3] = "Okey",
}

LifeSafer_NightfallSettings_CheckButtonStrings = {
  [1] = "Enable Shadow Trance effect",
  [2] = "Use large effect",
  [3] = "Enable sound effect",
  [4] = "Enable Soul Shard creation effect",
}

LifeSafer_NightfallSettings_CheckButtonTooltipStrings = {
  [1] = "Check to enable Shadow Trance effect.",
  [2] = "Check to use a larger effect for Shadow Trance.",
  [3] = "Check to play a sound effect when you gain Shadow Trance.",
  [4] = "Check to show an effect each time you create a shard.",
}

LifeSafer_Nightfall_String_SoulShard = "Soul Shard"
LifeSafer_Nightfall_String_ShadowTrance = "Shadow Trance"
LifeSafer_Nightfall_String_YouCreate = "You create"


if (GetLocale() == "deDE") then 

  -- German localization (originally by Citanul of Krag'jin)
  -- Thanks to Gafarion (Alleria, EU) for adjustments

  LifeSafer_NightfallSettings_Labels = {
    [1] = "Nightfall",
    [2] = "Version",
  }
  
  LifeSafer_NightfallSettings_ButtonStrings = {
    [1] = "Standard",
    [2] = "Abbrechen",
    [3] = "OK",
  }
  
  LifeSafer_NightfallSettings_CheckButtonStrings = {
    [1] = "Effekt fuer Schattentrance aktivieren",
    [2] = "Grossen Effekt verwenden",
    [3] = "Soundeffekt aktivieren",
    [4] = "Herstellungseffekt fuer Seelensplitter aktivieren",
  }
  
  LifeSafer_NightfallSettings_CheckButtonTooltipStrings = {
    [1] = "Klicken um den Effekt fuer Schattentrance einzuschalten.",
    [2] = "Klicken um einen grossen Effekt fuer Schattentrance zu verwenden.",
    [3] = "Klicken um einen Soundeffekt abspielen zu lassen, wenn man in Schattentrance versetzt wird.",
    [4] = "Klicken um jedes Mal, wenn ein Seelensplitter hergestellt wird, einen Effekt anzeigen zu lassen.",
  }

  LifeSafer_Nightfall_String_SoulShard = "Seelensplitter"
  LifeSafer_Nightfall_String_ShadowTrance = "Schattentrance"
  LifeSafer_Nightfall_String_YouCreate = "Ihr stellt her"

end

if (GetLocale() == "frFR") then

  LifeSafer_Nightfall_String_SoulShard = "Fragment d' me"
  LifeSafer_Nightfall_String_ShadowTrance = "Transe de l'ombre"
  LifeSafer_Nightfall_String_YouCreate = "Vous cr ez"

end

if (GetLocale() == "koKR") then

end

