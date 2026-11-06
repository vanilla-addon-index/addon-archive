-- Minimap-Knopf: Aufbau, Position aus dem gespeicherten Winkel, Ein-
-- und Ausblenden, Bild vorhanden.
string.gmatch = nil; select = nil
local function obj()
  local o = { shown = true, pts = {}, scripts = {} }
  return setmetatable(o, { __index = function(t, k)
    local m = {
      Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end,
      SetPoint = function(self, a, rel, b, x, y) self.pts = { a, x, y } end,
      ClearAllPoints = function(self) self.pts = {} end,
      SetScript = function(self, n, f) self.scripts[n] = f end,
      SetTexture = function(self, v) self.tex = v end,
      CreateTexture = function() return obj() end,
      GetCenter = function() return 100, 100 end,
      GetEffectiveScale = function() return 1 end,
    }
    if m[k] then return m[k] end
    return function() end
  end })
end
CreateFrame = function() return obj() end
Minimap = obj()
GetCursorPosition = function() return 100, 180 end   -- genau ueber der Mitte
BananaLootline = { L = setmetatable({}, { __index = function(t, k) return k end }) }
BananaLootlineDB = {}
dofile("MinimapButton.lua")
local MB = BananaLootline.Minimap
local ok = true
local function check(c, m) if not c then ok = false; print("FEHLER: " .. m) end end

MB:Init()
check(MB.button ~= nil, "Knopf entsteht")
check(MB.button.icon.tex == "Interface\\AddOns\\BananaLootline\\Images\\Minimap", "Logo als Bild")
check(MB.button.shown, "standardmaessig sichtbar")

-- Winkel 0 = rechts von der Karte
BananaLootlineDB.minimap.angle = 0
MB:Place()
check(math.abs(MB.button.pts[2] - 80) < 0.01 and math.abs(MB.button.pts[3]) < 0.01,
  "Winkel 0 liegt rechts")

-- Ziehen: Maus direkt ueber der Mitte -> 90 Grad
this = MB.button
MB.button.scripts.OnDragStart()
MB.button.scripts.OnUpdate()
check(math.abs(BananaLootlineDB.minimap.angle - 90) < 0.01, "Ziehen speichert den Winkel")

check(MB:Toggle() == false and not MB.button.shown, "ausblenden")
check(MB:Toggle() == true and MB.button.shown, "wieder einblenden")

local f = io.open("Images/Minimap.tga", "rb")
check(f ~= nil, "Images/Minimap.tga ist vorhanden")
if f then
  local head = f:read(18); f:close()
  check(string.byte(head, 3) == 2, "TGA unkomprimiert")
  check(string.byte(head, 17) == 32, "TGA mit Alphakanal")
  check(string.byte(head, 13) == 64 and string.byte(head, 15) == 64, "64 x 64 Pixel")
end
print(ok and "ALLE TESTS OK" or "TESTS FEHLGESCHLAGEN")
