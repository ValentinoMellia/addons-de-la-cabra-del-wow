local __sgmBuild = select(4, GetBuildInfo())
if __sgmBuild ~= 120007 and __sgmBuild ~= 120100 and __sgmBuild ~= 120105 then return end
if not _G.SpyGodModeClientOK then return end
local _,SGM=...
local L=_G.SpyGodMode_L
local M={nameplates={},liveUnits={}}; SGM:RegisterModule("Scanner",M)
local plateTokens,arenaTokens={},{}
for i=1,40 do plateTokens[i]="nameplate"..i end
for i=1,5 do arenaTokens[i]="arena"..i end

local function relativeDirection(unit)
 if not UnitPosition or not GetPlayerFacing then return nil end
 local ux,uy=SGM:SafeCall(UnitPosition,unit)
 local px,py=SGM:SafeCall(UnitPosition,"player")
 local facing=SGM:SafeCall(GetPlayerFacing)
 if type(ux)~="number" or type(uy)~="number" or type(px)~="number" or type(py)~="number" or type(facing)~="number" then return nil end
 local dx,dy=ux-px,uy-py
 if dx==0 and dy==0 then return nil end
 local angle
 if math.atan2 then angle=math.atan2(dy,dx)
 elseif dx>0 then angle=math.atan(dy/dx)
 elseif dx<0 and dy>=0 then angle=math.atan(dy/dx)+math.pi
 elseif dx<0 then angle=math.atan(dy/dx)-math.pi
 elseif dy>0 then angle=math.pi/2
 else angle=-math.pi/2 end
 local rel=(angle-facing+math.pi)%(2*math.pi)-math.pi
 local a=math.abs(rel)
 if a<=math.pi/4 then return L["IN FRONT OF YOU"] end
 if a>=3*math.pi/4 then return L["BEHIND YOU"] end
 return rel>0 and L["ON YOUR LEFT"] or L["ON YOUR RIGHT"]
end

function M:Inspect(unit,stealthSpellID)
 if not SGM.cfg or not SGM.cfg.enabled or not SGM:CanDetectHere() or not SGM:IsValidEnemyUnit(unit) then return end
 if SGM.cfg.detectNonPvp==false and UnitIsPVP and SGM:SafeCall(UnitIsPVP,unit)~=true then return end
 local name=SGM:SafeCall(UnitName,unit)
 local fullName=SGM:GetUnitFullName(unit) or name
 if not name or name=="" then return end
 local shortName=SGM:ShortName(name)
 if shortName then self.liveUnits[shortName]=unit end
 local _,class=SGM:SafeCall(UnitClass,unit)
 local race=SGM:SafeCall(UnitRace,unit)
 local guild=SGM:SafeCall(GetGuildInfo,unit)
 local level=SGM:SafeCall(UnitLevel,unit)
 local guid=SGM:SafeCall(UnitGUID,unit)
 local direction=relativeDirection(unit)
 local isStealth=stealthSpellID and SGM.stealthSpells and SGM.stealthSpells[stealthSpellID]==true
 local p,new=SGM.modules.Roster:Upsert(name,{guid=guid,class=class,race=race,guild=guild,level=level,zone=SGM:Zone(),source="unit",targetName=fullName or name,lastDirection=direction,lastDirectionAt=direction and time() or nil,stealthSpellId=isStealth and stealthSpellID or nil})
 if p then SGM:Fire("SGM_DETECTED",SGM:ShortName(name),p,isStealth,new); if SGM.modules.Intelligence then SGM.modules.Intelligence:CheckUnit(unit) end end
end

function M:ResyncNameplates()
 -- NAME_PLATE_UNIT_ADDED can be missed during login/reload/phase transitions on
 -- modern clients. Rebuild the live set from both the nameplate API and unit
 -- tokens so nearby enemies do not require mouseover/target to be discovered.
 if C_NamePlate and C_NamePlate.GetNamePlates then
  local ok,plates=pcall(C_NamePlate.GetNamePlates)
  if ok and type(plates)=="table" then
   for _,plate in ipairs(plates) do
    local unit=plate and (plate.namePlateUnitToken or plate.unitToken)
    if unit then self.nameplates[unit]=true end
   end
  end
 end
 for i=1,40 do
  local unit=plateTokens[i]
  if UnitExists and SGM:SafeCall(UnitExists,unit) then self.nameplates[unit]=true end
 end
end

function M:ScanVisibleUnits()
 self:ResyncNameplates()
 self:Inspect("target")
 self:Inspect("focus")
 self:Inspect("mouseover")
 for i=1,5 do self:Inspect(arenaTokens[i]) end
 for unit in pairs(self.nameplates) do
  if UnitExists and SGM:SafeCall(UnitExists,unit) then self:Inspect(unit) else self.nameplates[unit]=nil end
 end
end

for _,e in ipairs({"PLAYER_TARGET_CHANGED","PLAYER_FOCUS_CHANGED","UPDATE_MOUSEOVER_UNIT","NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED"}) do SGM:RegisterEvent(e) end
SGM:On("PLAYER_TARGET_CHANGED",function() M:Inspect("target") end)
SGM:On("PLAYER_FOCUS_CHANGED",function() M:Inspect("focus") end)
SGM:On("UPDATE_MOUSEOVER_UNIT",function() M:Inspect("mouseover") end)
SGM:On("NAME_PLATE_UNIT_ADDED",function(unit) if unit then M.nameplates[unit]=true end; M:Inspect(unit) end)
SGM:On("NAME_PLATE_UNIT_REMOVED",function(unit) if unit then M.nameplates[unit]=nil; for name,u in pairs(M.liveUnits) do if u==unit then M.liveUnits[name]=nil end end end end)

-- Midnight does not expose the old unrestricted combat log to addons. Visible
-- unit scanning is therefore the reliable retail path. Classic/TBC still use
-- combat-log detection in addition to this scanner.
SGM:On("SGM_READY",function()
 if SGM.isMidnight and C_Timer and C_Timer.NewTicker then
  -- Keep the visible nameplate set synchronized continuously. This repairs
  -- missed add/remove events after reloads, phasing and modern client updates.
  M:ResyncNameplates()
  M.scanTicker=C_Timer.NewTicker(0.35,function() M:ScanVisibleUnits() end)
 else
  M:Inspect("target")
  M:Inspect("focus")
  M:Inspect("mouseover")
 end
end)

for _,e in ipairs({"UNIT_SPELLCAST_SUCCEEDED","UNIT_SPELLCAST_START"}) do SGM:RegisterEvent(e) end
local function spellcast(unit,_,spellID)
 spellID=SGM:SafeValue(spellID)
 if type(spellID)=="number" and SGM.stealthSpells and SGM.stealthSpells[spellID] then M:Inspect(unit,spellID) end
end
SGM:On("UNIT_SPELLCAST_SUCCEEDED",spellcast)
SGM:On("UNIT_SPELLCAST_START",spellcast)
