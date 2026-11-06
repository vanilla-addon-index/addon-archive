local PP = PizzaPocket

PP.nameplates = {}

local hooked = false

function PP.nameplates.hook()
  if hooked then return end
  if not pfUI or not pfUI.nameplates or not pfUI.nameplates.OnDataChanged then return end
  hooked = true

  local orig = pfUI.nameplates.OnDataChanged
  pfUI.nameplates.OnDataChanged = function (self, plate)
    orig(self, plate)

    -- SuperWoW: GetName(1) returns the plate's unit GUID.
    local guid = plate.parent:GetName(1)
    if guid and PP.picked[guid] then
      plate.health:SetStatusBarColor(0.3, 0.3, 0.3, 1)
      plate.cache.r, plate.cache.g, plate.cache.b = 0.3, 0.3, 0.3
      plate.name:SetTextColor(0.5, 0.5, 0.5, 1)
      plate.ppGreyed = true
    elseif plate.ppGreyed then
      plate.name:SetTextColor(1, 1, 1, 1)
      plate.ppGreyed = nil
    end
  end
end
