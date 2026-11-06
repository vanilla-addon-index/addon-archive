local callbacks = {}
local auras = {}
local removed = 0
local pending = {}
Cursive = { nampower = true, db = {profile = {enabled=true,useclassicapi=true}},
	core = {addGuid=function() end},
	curses = {trackedCurseIds={[172]={name="corruption",rank=1}},guids={},pendingCast=pending} }
function Cursive.curses:ApplyCurse(id,guid,start,duration)
	self.pendingCast = {}
	self.guids[guid] = self.guids[guid] or {}
	self.guids[guid].corruption = {currentPlayer=true,start=start,duration=duration}
end
function Cursive.curses:RemoveCurse(guid,name) self.guids[guid][name]=nil; removed=removed+1 end
function CreateFrame() return {RegisterEvent=function() end,SetScript=function(self,key,fn) callbacks[key]=fn end} end
function UnitExists(unit) return true,"mob" end
function UnitIsUnit(a,b) return a==b end
function GetTime() return 100 end
C_UnitAuras = {
	GetAuraSlots=function(unit,filter,a,b,out) for i=1,table.getn(auras) do out[i]=i end; return nil,table.getn(auras) end,
	UnitAuraBySlot=function(unit,slot) return unpack(auras[slot]) end,
	GetAuraDataByAuraInstanceID=function() end,
}
dofile("classicapi.lua")
auras[1]={"Corruption","icon",1,"Magic",18,118,"player",false,false,172}
Cursive.ReconcileClassicAuras("target")
assert(Cursive.curses.guids.mob.corruption.start==100)
auras[1][6]=125
Cursive.ReconcileClassicAuras("target")
assert(Cursive.curses.guids.mob.corruption.start==107)
auras={}
Cursive.ReconcileClassicAuras("target")
assert(removed==1)
Cursive.curses.guids.mob.corruption={currentPlayer=true}
Cursive.ReconcileClassicAuras("target")
assert(Cursive.curses.guids.mob.corruption)
auras[1]={"Corruption","icon",1,"Magic",18,118,"party1",false,false,172}
Cursive.ReconcileClassicAuras("target")
assert(not Cursive.curses.guids.mob.corruption.classicConfirmed)
C_UnitAuras=nil
Cursive.ReconcileClassicAuras("target")
print("ClassicAPI reconciliation tests passed")