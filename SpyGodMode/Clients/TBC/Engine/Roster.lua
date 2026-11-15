local __sgmBuild = select(4, GetBuildInfo())
if __sgmBuild ~= 20505 and __sgmBuild ~= 20506 then return end
if not _G.SpyGodModeClientOK then return end
local _,SGM=...
local M={nearby={},nearbyOrder={},history={}}; SGM:RegisterModule("Roster",M)
local function NearbyTTL()
 -- Enemy retention in Nearby is independent from the window auto-hide delay.
 -- removeAfter is the actual Nearby timeout (60s by default).
 return math.max(5,tonumber(SGM.cfg and SGM.cfg.removeAfter) or 60)
end
function M:Get(name) return SGM.db.players[name] end
function M:Upsert(name,data)
 name=SGM:ShortName(name); if not name or name==SGM.playerName or SGM.db.ignore[name] then return nil,false end
 local p=SGM.db.players[name] or {firstSeen=time(),wins=0,losses=0,detections=0}
 if data and data.guid and (not data.class or data.class=="") and GetPlayerInfoByGUID then
  local _,englishClass,_,englishRace=GetPlayerInfoByGUID(data.guid)
  if englishClass then data.class=englishClass end
  if englishRace then data.race=englishRace end
 end
 local now=time()
 local previousNearby=self.nearby[name]
 local ttl=NearbyTTL()
 local enteredNearby=not previousNearby or (now-previousNearby)>ttl
 for k,v in pairs(data or {}) do if v~=nil and v~="" then p[k]=v end end
 p.lastSeen=now; p.zone=p.zone or SGM:Zone(); if enteredNearby or not p.lastDetectionAt or now-p.lastDetectionAt>=30 then p.detections=(p.detections or 0)+1; p.lastDetectionAt=now end; SGM.db.players[name]=p
 self.nearby[name]=p.lastSeen; self.history[name]=p.lastSeen
 -- Combat-log events can arrive dozens of times per second. Rebuilding/sorting the
 -- Nearby list (and therefore the large Statistics DB) on every event caused CPU
 -- spikes. A newly-entered enemy refreshes immediately; existing enemies are
 -- maintained by the lightweight 1-second Nearby tick below.
 if enteredNearby then self:Rebuild() end
 return p,enteredNearby
end
function M:Rebuild(silent)
 wipe(self.nearbyOrder); local now=time(); local ttl=NearbyTTL()
 for n,t in pairs(self.nearby) do if now-t<=ttl and not SGM.db.ignore[n] then self.nearbyOrder[#self.nearbyOrder+1]=n else self.nearby[n]=nil end end
 table.sort(self.nearbyOrder,function(a,b)
  if SGM.cfg.prioritizeKos then local ak=SGM.db.kos[a] and 1 or 0; local bk=SGM.db.kos[b] and 1 or 0; if ak~=bk then return ak>bk end end
  if SGM.cfg.stealthPriority then
   local ap=SGM.db.players[a] or {}; local bp=SGM.db.players[b] or {}
   local as=(ap.class=="ROGUE" or ap.class=="DRUID" or (ap.stealthSpellId and time()-(ap.lastSeen or 0)<60)) and 1 or 0
   local bs=(bp.class=="ROGUE" or bp.class=="DRUID" or (bp.stealthSpellId and time()-(bp.lastSeen or 0)<60)) and 1 or 0
   if as~=bs then return as>bs end
  end
  return (self.nearby[a] or 0)>(self.nearby[b] or 0)
 end)
 if not silent then SGM:Fire("SGM_LIST_UPDATE") end
end
function M:SetKos(name,reason)
 name=SGM:ShortName(name); if not name then return end
 local old=SGM.db.kos[name] or {}
 -- Preserve tags/shared metadata when only the reason is edited.
 SGM.db.kos[name]={reason=reason or old.reason or "",added=old.added or time(),updated=time(),tags=old.tags,sharedBy=old.sharedBy}
 SGM.db.ignore[name]=nil
 self:Rebuild(); SGM:Fire("SGM_KOS_CHANGED",name)
end
function M:RemoveKos(name) name=SGM:ShortName(name); if name then SGM.db.kos[name]=nil; self:Rebuild() end end
function M:SetIgnore(name) name=SGM:ShortName(name); if not name then return end; SGM.db.ignore[name]={added=time()}; SGM.db.kos[name]=nil; self.nearby[name]=nil; self:Rebuild() end
function M:RemoveIgnore(name) name=SGM:ShortName(name); if name then SGM.db.ignore[name]=nil; self:Rebuild() end end
function M:ClearNearby() wipe(self.nearby); self:Rebuild() end
function M:Names(view)
 local out={}; local now=time()
 if view=="NEARBY" then for i=1,#self.nearbyOrder do out[#out+1]=self.nearbyOrder[i] end
 elseif view=="HOUR" then for n,p in pairs(SGM.db.players) do if now-(p.lastSeen or 0)<=3600 then out[#out+1]=n end end
 elseif view=="KOS" then for n in pairs(SGM.db.kos) do out[#out+1]=n end
 elseif view=="IGNORE" then for n in pairs(SGM.db.ignore) do out[#out+1]=n end
 else for n in pairs(SGM.db.players) do out[#out+1]=n end end
 table.sort(out,function(a,b) return ((SGM.db.players[a] or {}).lastSeen or 0)>((SGM.db.players[b] or {}).lastSeen or 0) end); return out
end

SGM:On("SGM_READY",function()
 if C_Timer and C_Timer.NewTicker then
  M.cleanupTicker=C_Timer.NewTicker(1,function()
   if next(M.nearby) then
    -- Keep expiry/order/age current without forcing the 3k+ Statistics database
    -- to filter+sort once every second.
    M:Rebuild(true)
    local W=SGM.modules.MainFrame
    if W and W.frame and W.frame:IsShown() then W:Refresh() end
   end
  end)
 end
end)
