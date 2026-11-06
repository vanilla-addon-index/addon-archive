-- pandaUI :: modules/castbartargetnampower.lua
--
-- Optional Nampower target cast backend. It adds exact spell IDs and caster
-- GUIDs to the shared tracker; modules/castbar.lua also registers its complete
-- stock combat-text path here, so a missing or suppressed DLL event still has
-- the same fallback and PandaUI never depends on the DLL merely to load.

local U = PandaUI
if not U.hasNampower then return end

local Nampower = U.RegisterModule("castbar-target-nampower")

function Nampower:OnEnable()
  if type(U.EnableNampowerTargetCastbarBackend) ~= "function" then
    U.Error("Nampower target castbar backend unavailable")
    return
  end
  U.EnableNampowerTargetCastbarBackend()
end
