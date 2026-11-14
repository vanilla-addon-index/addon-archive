-- GearRack. Engine extensions are DLLs, not addon Dependencies: each must be
-- loaded; the player always runs the latest release, so no version is checked.
GearRack = {version=GetAddOnMetadata("GearRack","Version"), enabled=false}
local failure
if type(CLASSIC_API_VERSION)~="number" then
    failure="ClassicAPI"
elseif not SUPERWOW_VERSION then
    failure="SuperWoW"
elseif type(GetNampowerVersion)~="function" then
    failure="NamPower"
end
if failure then
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4040GearRack requires "..failure..". Load the required DLL and restart the client.|r",1,.25,.25)
    end
    return
end
GearRack.enabled=true
GearRack.Requests={}
GearRack.DirtyBags={}
GearRack.Bags={}
GearRack.BagItemIDs={}
GearRack.EquippedItemIDs={}
GearRack.BagContainerIDs={}
GearRack.Items={}
GearRack.ByID={}
GearRack.ByName={}
GearRack.ByGUID={}
GearRackDB={bars={},settings={},events={},sets={},trinketOptions={}}
GearRackCharDB={trinkets={},queues={}}
