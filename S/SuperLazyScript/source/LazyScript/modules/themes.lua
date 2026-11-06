-- Themes
-- ---
lazyScript = lazyScript or {}
lazyScript.theme = lazyScript.theme or {}
lazyScript.theme.themes = {}

-- [Solarized Dark](https://ethanschoonover.com/solarized)
-- ---
lazyScript.theme.themes.solarizedDark = {
    ui = {
        border = {0.027, 0.212, 0.259, 0.6},
        bg = {0, 0.169, 0.212, 0.9},
        bghighlight = {0.027, 0.212, 0.259, 0.9},
        element = {0.027, 0.212, 0.259, 0.6},
        minion = {0.8, 0.8, 0.8, 0.5}
    },
    text = {
        bg = "|cff002b36", -- base03
        bghighlight = "|cff073642", -- base02
        primary = "|cff839496", -- base0
        secondary = "|cff586e75", -- base01
        emphasis = "|cff93a1a1", -- base1
        success = "|cff859900", -- green
        danger = "|cffdc322f", -- red
        warning = "|cffb58900", -- yellow
        info = "|cff268bd2" -- blue
    },
    textRGB = {
    primary   = {0.514, 0.580, 0.588},
    secondary = {0.345, 0.431, 0.459},
    emphasis  = {0.576, 0.631, 0.631},
    success   = {0.522, 0.600, 0.000},
    danger    = {0.863, 0.196, 0.184},
    warning   = {0.710, 0.537, 0.000},
    info      = {0.149, 0.545, 0.824}
    },
    fonts = {
        PTSans = "Interface\\Addons\\LazyScript\\fonts\\PT-Sans-Narrow-Bold.ttf",
        envyCode = "Interface\\Addons\\LazyScript\\fonts\\Envy-Code-R.ttf"
    },
    fontSizes = {
        h1 = 18,
        h2 = 14,
        h3 = 11,
        p = 11
    }
}

-- Pitch Black Theme
-- ---
lazyScript.theme.themes.pitchBlack = {
    ui = {
        border = {0.02, 0.2, 0.3, 0.6},
        bg = {0.05, 0.05, 0.05, 0.9},
        bghighlight = {0, 0, 0, 0.9},
        element = {0.2, 0.1, 0.1, 1},
        minion = {0.8, 0.8, 0.8, 0.5}
    },
    text = {
        bg = "|cff002b36", -- base03
        bghighlight = "|cff073642", -- base02
        primary = "|cff839496", -- base0
        secondary = "|cff586e75", -- base01
        emphasis = "|cffeee8d5", -- base3
        success = "|cff859900", -- green
        danger = "|cffdc322f", -- red
        warning = "|cffb58900", -- yellow
        info = "|cff268bd2", -- blue
        nogcd = "|cff40ff40" -- bright green
    },
    textRGB = {
        primary   = {0.514, 0.580, 0.588},
        secondary = {0.345, 0.431, 0.459},
        emphasis  = {0.576, 0.631, 0.631},
        success   = {0.522, 0.600, 0.000},
        danger    = {0.863, 0.196, 0.184},
        warning   = {0.710, 0.537, 0.000},
        info      = {0.149, 0.545, 0.824}
    },
    fonts = {
        PTSans = "Interface\\Addons\\LazyScript\\fonts\\PT-Sans-Narrow-Bold.ttf",
        envyCode = "Interface\\Addons\\LazyScript\\fonts\\Envy-Code-R.ttf"
    },
    fontSizes = {
        h1 = 18,
        h2 = 14,
        h3 = 11,
        p = 11
    }
}

lazyScript.theme.active = "pitchBlack"

--
-- ---

-- Switch active theme & re-skin frames
function lazyScript.theme.setActive(name)
    if not lazyScript.theme.themes[name] then
        lazyScript.p("Unknown theme '".. tostring(name) .. "'")
    end
    lazyScript.theme.active = name
    if lazyScript.skin and lazyScript.skin.refresh then
        lazyScript.skin.refresh()
    end
end
