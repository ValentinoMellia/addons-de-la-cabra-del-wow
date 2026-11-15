local __sgmBuild = select(4, GetBuildInfo())
if __sgmBuild ~= 30405 then return end
if not _G.SpyGodModeClientOK then return end
local _,SGM=...
local A={targeting={},recent={},lastSOS=0,lastTargetAlert={},lastSightingAt={}}; SGM:RegisterModule("Intelligence",A)

local function trimHistory(t,limit)
 while #t>limit do table.remove(t,1) end
end
local function playerData(name) return SGM.db.players and SGM.db.players[name] or nil end

function A:RecordTimeline(name,kind,detail)
 name=SGM:ShortName(name); if not name or not SGM.db then return end
 SGM.db.timelines=SGM.db.timelines or {}
 local t=SGM.db.timelines[name] or {}; SGM.db.timelines[name]=t
 local last=t[#t]
 local now=time()
 if last and last.kind==kind and last.detail==detail and now-(last.time or 0)<5 then return end
 t[#t+1]={time=now,kind=kind,detail=detail or "",zone=SGM:Zone()}
 trimHistory(t,tonumber(SGM.cfg and SGM.cfg.historyLimit) or 30)
end

function A:RecordSighting(name,p,source)
 if not SGM.cfg or not SGM.cfg.mapIntel then return end
 name=SGM:ShortName(name); if not name or not p then return end
 local now=time(); if self.lastSightingAt[name] and now-self.lastSightingAt[name]<5 then return end; self.lastSightingAt[name]=now
 local mapID,x,y
 if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
  local ok,id=pcall(C_Map.GetBestMapForUnit,"player"); if ok then mapID=id end
  if mapID then
   local ok2,pos=pcall(C_Map.GetPlayerMapPosition,mapID,"player")
   if ok2 and pos and pos.GetXY then local ok3,px,py=pcall(pos.GetXY,pos); if ok3 then x,y=px,py end end
  end
 end
 p.lastMapID=mapID or p.lastMapID; p.lastMapX=x or p.lastMapX; p.lastMapY=y or p.lastMapY
 p.lastSightingSource=source or p.source or "local"
 SGM.db.sightings=SGM.db.sightings or {}
 local list=SGM.db.sightings[name] or {}; SGM.db.sightings[name]=list
 list[#list+1]={time=now,zone=p.zone or SGM:Zone(),mapID=mapID,x=x,y=y,source=p.lastSightingSource}
 trimHistory(list,10)
end


function A:IsTargeting(name)
 name=SGM:ShortName(name); if not name then return false end
 local t=self.targetingAt and self.targetingAt[name]
 if self.targeting[name] and t and GetTime()-t<=5 then return true end
 self.targeting[name]=nil
 if self.targetingAt then self.targetingAt[name]=nil end
 local p=playerData(name); if p then p.targetingYou=nil end
 return false
end

function A:ThreatScore(name,p)
 if SGM.cfg and SGM.cfg.intelligence==false then return 0 end
 p=p or playerData(name) or {}; local score=0
 if SGM.db.kos and SGM.db.kos[name] then score=score+50 end
 if p.guild and SGM.db.guildKos and SGM.db.guildKos[p.guild] then score=score+30 end
 if SGM.db.favorites and SGM.db.favorites[name] then score=score+8 end
 if self:IsTargeting(name) then score=score+25 end
 if p.stealthSpellId or p.class=="ROGUE" or p.class=="DRUID" then score=score+12 end
 local my=UnitLevel and UnitLevel("player") or 0; local lv=tonumber(p.level) or 0
 if my>0 and lv>my then score=score+math.min(15,(lv-my)*3) end
 score=score+math.min(15,math.floor((p.detections or 0)/3))
 score=score+math.min(20,(p.losses or 0)*4)
 score=score-math.min(10,(p.wins or 0)*2)
 return math.max(0,math.min(100,score))
end
function A:ThreatLabel(name,p)
 local s=self:ThreatScore(name,p)
 if s>=(tonumber(SGM.cfg.highThreatScore) or 70) then return "EXTREME",s end
 if s>=(tonumber(SGM.cfg.mediumThreatScore) or 40) then return "HIGH",s end
 if s>=20 then return "MEDIUM",s end
 return "LOW",s
end

function A:CheckUnit(unit)
 if not SGM.cfg or not SGM.cfg.targetWarnings or not SGM:IsValidEnemyUnit(unit) then return end
 local name=SGM:SafeCall(UnitName,unit); if not name then return end; name=SGM:ShortName(name)
 local onMe=SGM:SafeCall(UnitIsUnit,unit.."target","player")==true
 local old=self.targeting[name]; self.targeting[name]=onMe or nil
 self.targetingAt=self.targetingAt or {}
 if onMe then self.targetingAt[name]=GetTime() else self.targetingAt[name]=nil end
 local p=playerData(name); if p then p.targetingYou=onMe or nil end
 if onMe and not old then
  local now=GetTime(); if not self.lastTargetAlert[name] or now-self.lastTargetAlert[name]>8 then
   self.lastTargetAlert[name]=now; self:RecordTimeline(name,"TARGET","Targeting you")
   if SGM.cfg.warnings then SGM:Fire("SGM_ALERT","TARGET",name,p or {}) end
   SGM:SafeSound("HIGH")
  end
 end
end

function A:NearbyCounts()
 local total,stealth,kos,targeting=0,0,0,0
 for _,name in ipairs((SGM.modules.Roster and SGM.modules.Roster.nearbyOrder) or {}) do
  total=total+1; local p=playerData(name) or {}
  if p.class=="ROGUE" or p.class=="DRUID" or p.stealthSpellId then stealth=stealth+1 end
  if (SGM.db.kos and SGM.db.kos[name]) or (p.guild and SGM.db.guildKos and SGM.db.guildKos[p.guild]) then kos=kos+1 end
  if self:IsTargeting(name) then targeting=targeting+1 end
 end
 return total,stealth,kos,targeting
end

SGM:On("SGM_DETECTED",function(name,p,stealth,isNew)
 A:RecordSighting(name,p,p.source)
 if isNew then
  A:RecordTimeline(name,"SEEN",(p.zone or SGM:Zone()))
  local now=GetTime(); A.recent[name]=now
  for n,t in pairs(A.recent) do if now-t>7 then A.recent[n]=nil end end
  local c=0; for _ in pairs(A.recent) do c=c+1 end
  local threshold=tonumber(SGM.cfg.sosThreshold) or 4
  if SGM.cfg.sosWarnings and c>=threshold and now-A.lastSOS>15 then
   A.lastSOS=now
   if SGM.cfg.warnings then SGM:Fire("SGM_ALERT","SOS",tostring(c).." ENEMIES",{level=0,zone=p.zone or SGM:Zone(),class=p.class}) end
   SGM:SafeSound("HIGH")
  end
 end
end)

for _,e in ipairs({"PLAYER_TARGET_CHANGED","PLAYER_FOCUS_CHANGED","UPDATE_MOUSEOVER_UNIT","NAME_PLATE_UNIT_ADDED"}) do SGM:RegisterEvent(e) end
SGM:On("PLAYER_TARGET_CHANGED",function() A:CheckUnit("target") end)
SGM:On("PLAYER_FOCUS_CHANGED",function() A:CheckUnit("focus") end)
SGM:On("UPDATE_MOUSEOVER_UNIT",function() A:CheckUnit("mouseover") end)
SGM:On("NAME_PLATE_UNIT_ADDED",function(unit) A:CheckUnit(unit) end)

function A:GetRecentTargeter(maxAge)
 local now=GetTime(); local candidate=nil
 for name,t in pairs(self.targetingAt or {}) do
  if now-(t or 0)<= (tonumber(maxAge) or 5) then
   if candidate and candidate~=name then return nil end
   candidate=name
  end
 end
 return candidate
end
