if not pfUI or type(pfUI.gui) ~= "table" or type(pfUI.gui.dropdowns) ~= "table" then return end

local addonpath
local tocs = { "", "-master", "-tbc", "-wotlk" }
for _, name in ipairs(tocs) do
  local current = string.format("pfUI-CustomMedia%s", name)
  local _, title = GetAddOnInfo(current)
  if title then
    addonpath = "Interface\\AddOns\\" .. current
    break
  end
end

if addonpath then
  local fonts = {
    { "AtkinsonHyperlegible-Regular.ttf", "Atkinson Hyperlegible" },
    { "Alegreya-Regular.ttf", "Alegreya" },
    { "Alegreya-Bold.ttf", "Alegreya Bold" },
    { "AlegreyaSans-Regular.ttf", "Alegreya Sans" },
    { "AlegreyaSans-Bold.ttf", "Alegreya Sans Bold" },
    { "Almendra-Regular.ttf", "Almendra" },
    { "BarlowCondensed-Regular.ttf", "Barlow Condensed" },
    { "BarlowCondensed-Medium.ttf", "Barlow Condensed Medium" },
    { "CelestiaMediumRedux1.55.ttf", "Celestia" },
    { "Cinzel-Regular.ttf", "Cinzel" },
    { "Cinzel-Bold.ttf", "Cinzel Bold" },
    { "EBGaramond-Regular.ttf", "EB Garamond" },
    { "EBGaramond-SemiBold.ttf", "EB Garamond Semibold" },
    { "Exo2-Regular.ttf", "Exo 2" },
    { "Exo2-Bold.ttf", "Exo 2 Bold" },
    { "ExocetBlizzardMedium.ttf", "Exocet Blizzard" },
    { "FiraSans-Regular.ttf", "Fira Sans" },
    { "FiraSans-SemiBold.ttf", "Fira Sans Semibold" },
    { "FiraSansCondensed-Regular.ttf", "Fira Sans Condensed" },
    { "FiraSansCondensed-SemiBold.ttf", "Fira Sans Condensed Semibold" },
    { "IBMPlexSansCondensed-Regular.ttf", "IBM Plex Sans Condensed" },
    { "IBMPlexSansCondensed-SemiBold.ttf", "IBM Plex Sans Condensed Semibold" },
    { "Lato-Regular.ttf", "Lato" },
    { "Lato-Bold.ttf", "Lato Bold" },
    { "Lexend-Regular.ttf", "Lexend" },
    { "Marcellus-Regular.ttf", "Marcellus" },
    { "MarcellusSC-Regular.ttf", "Marcellus Small Caps" },
    { "MedievalSharp-Regular.ttf", "Medieval Sharp" },
    { "Metamorphous-Regular.ttf", "Metamorphous" },
    { "NotoSans-Regular.ttf", "Noto Sans" },
    { "NotoSans-Bold.ttf", "Noto Sans Bold" },
    { "OpenSans-Regular.ttf", "Open Sans" },
    { "OpenSans-SemiBold.ttf", "Open Sans Semibold" },
    { "Oswald-Regular.ttf", "Oswald" },
    { "Oswald-SemiBold.ttf", "Oswald Semibold" },
    { "PirataOne-Regular.ttf", "Pirata One" },
    { "PTSans-Regular.ttf", "PT Sans" },
    { "PTSans-Bold.ttf", "PT Sans Bold" },
    { "PTSansNarrow-Regular.ttf", "PT Sans Narrow" },
    { "PTSansNarrow-Bold.ttf", "PT Sans Narrow Bold" },
    { "Rajdhani-Regular.ttf", "Rajdhani" },
    { "Rajdhani-Bold.ttf", "Rajdhani Bold" },
    { "Roboto.ttf", "Roboto" },
    { "RobotoCondensed-Regular.ttf", "Roboto Condensed" },
    { "RobotoCondensed-Bold.ttf", "Roboto Condensed Bold" },
    { "Signika-Regular.ttf", "Signika" },
    { "Signika-SemiBold.ttf", "Signika Semibold" },
    { "SourceSans3-Regular.ttf", "Source Sans 3" },
    { "SourceSans3-Bold.ttf", "Source Sans 3 Bold" },
    { "UncialAntiqua-Regular.ttf", "Uncial Antiqua" },
    { "Acme-Regular.ttf", "Acme" },
    { "Alegreya-Medium.ttf", "Alegreya Medium" },
    { "AlegreyaSansSC-Bold.ttf", "Alegreya Sans Small Caps Bold" },
    { "AveriaLibre-Regular.ttf", "Averia Libre" },
    { "FjallaOne-Regular.ttf", "Fjalla One" },
    { "FTY.ttf", "FTY" },
    { "im-fell-english-sc.ttf", "IM Fell English Small Caps" },
    { "itcquorum_bold.ttf", "ITC Quorum Bold" },
    { "Kingthings Foundation.ttf", "Kingthings Foundation" },
    { "LibreBaskerville-Regular.ttf", "Libre Baskerville" },
    { "NiceDamage.ttf", "Nice Damage" },
    { "NovaFlat.ttf", "Nova Flat" },
    { "PathwayGothicOne-Regular.ttf", "Pathway Gothic One" },
    { "Share.ttf", "Share" },
    { "ShareBold.ttf", "Share Bold" },
    { "SquadaOne.ttf", "Squada One" },
    { "US101.ttf", "US 101" },
    { "BalooBhaina.ttf", "Baloo Bhaina" },
    { "Bangers-Regular.ttf", "Bangers" },
    { "BubblegumSans-Regular.ttf", "Bubblegum Sans" },
    { "Bungee.ttf", "Bungee" },
    { "CaesarDressing.ttf", "Caesar Dressing" },
    { "CoveredByYourGrace.ttf", "Covered By Your Grace" },
    { "Grandstander-Regular.ttf", "Grandstander" },
    { "JotiOne.ttf", "Joti One" },
    { "LondrinaSolid.ttf", "Londrina Solid" },
    { "Pangolin-Regular.ttf", "Pangolin" },
    { "RoadRage-Regular.ttf", "Road Rage" },
    { "SedgwickAveDisplay.ttf", "Sedgwick Ave Display" },
    { "Sniglet.ttf", "Sniglet" },
    { "Verdana.ttf", "Verdana" },
  }

  local dropdown = pfUI.gui.dropdowns.fonts
  if type(dropdown) == "table" then
    for _, font in ipairs(fonts) do
      table.insert(dropdown, string.format("%s\\fonts\\%s:%s", addonpath, font[1], font[2]))
    end
  end
end