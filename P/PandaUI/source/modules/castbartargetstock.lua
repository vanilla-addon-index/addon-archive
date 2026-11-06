-- pandaUI :: modules/castbartargetstock.lua
--
-- Stock-client target cast backend. The shared tracker and both consumers live
-- in modules/castbar.lua; this module only selects combat-text reconstruction
-- when Nampower's documented feature function is absent.

local U = PandaUI
if U.hasNampower then return end

local Stock = U.RegisterModule("castbar-target-stock")

function Stock:OnEnable()
  if type(U.EnableStockTargetCastbarBackend) ~= "function" then
    U.Error("stock target castbar backend unavailable")
    return
  end
  U.EnableStockTargetCastbarBackend()
end
