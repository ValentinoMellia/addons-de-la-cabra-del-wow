local __sgmBuild = select(4, GetBuildInfo())
if __sgmBuild ~= 50503 and __sgmBuild ~= 50504 then return end
if not _G.SpyGodModeClientOK then return end
local _,SGM=...
local I={}; SGM:RegisterModule("SpyImport",I)

local function cleanName(name)
 if type(name)~="string" or name=="" then return nil end
 return SGM:ShortName(name)
end

local function reasonText(data)
 if type(data)~="table" then return "Imported from Spy" end
 local reason=data.reason
 if type(reason)=="string" and reason~="" then return reason end
 if type(reason)~="table" then return "Imported from Spy" end
 local out={}
 for k,v in pairs(reason) do
  if type(v)=="string" and v~="" then
   out[#out+1]=v
  elseif v==true and type(k)=="string" and k~="" then
   out[#out+1]=k
  end
 end
 table.sort(out)
 if #out==0 then return "Imported from Spy" end
 return table.concat(out,"; ")
end

local function tryLoadSpy()
 if type(SpyPerCharDB)=="table" or type(SpyDB)=="table" then return true end
 if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn,"Spy")
 elseif LoadAddOn then pcall(LoadAddOn,"Spy") end
 return type(SpyPerCharDB)=="table" or type(SpyDB)=="table"
end

local function mergeMeta(dst,src,added)
 if type(src)~="table" then return dst end
 dst=dst or {}
 for _,k in ipairs({"class","race","guild","zone","mapID","mapX","mapY","faction"}) do
  if dst[k]==nil and src[k]~=nil then dst[k]=src[k] end
 end
 if type(src.level)=="number" then dst.level=math.max(tonumber(dst.level) or 0,src.level) end
 local wins=tonumber(src.wins)
 local losses=tonumber(src.losses or src.loses)
 if wins then dst.wins=math.max(tonumber(dst.wins) or 0,wins) end
 if losses then dst.losses=math.max(tonumber(dst.losses) or 0,losses) end
 local seen=tonumber(src.time)
 if seen and seen>0 then dst.lastSeen=math.max(tonumber(dst.lastSeen) or 0,seen) end
 if added and tonumber(added) and tonumber(added)>0 then dst.firstSeen=dst.firstSeen or tonumber(added) end
 return dst
end

local function ensurePlayer(name,meta,added)
 SGM.db.players=SGM.db.players or {}
 local p=SGM.db.players[name] or {firstSeen=tonumber(added) or time(),wins=0,losses=0,detections=0}
 p.wins=tonumber(p.wins) or 0
 p.losses=tonumber(p.losses) or 0
 p.detections=tonumber(p.detections) or 0
 p=mergeMeta(p,meta,added)
 p.importedFromSpy=true
 SGM.db.players[name]=p
 return p
end

function I:Import()
 tryLoadSpy()
 local imported,skipped=0,0
 local candidates={}

 local function addCandidate(rawName,pd,added)
  local n=cleanName(rawName); if not n then return end
  local c=candidates[n]
  if not c then c={reason=reasonText(pd),meta={},added=tonumber(added)}; candidates[n]=c end
  if c.reason=="Imported from Spy" then c.reason=reasonText(pd) end
  c.meta=mergeMeta(c.meta,pd,added)
  if not c.added and tonumber(added) then c.added=tonumber(added) end
 end

 -- Per-character Spy KoS list.
 if type(SpyPerCharDB)=="table" and type(SpyPerCharDB.KOSData)=="table" then
  for name,added in pairs(SpyPerCharDB.KOSData) do
   local pd=type(SpyPerCharDB.PlayerData)=="table" and SpyPerCharDB.PlayerData[name] or nil
   addCandidate(name,pd,added)
  end
 end

 -- Spy's shared realm/faction KoS store. This also catches entries created on other characters.
 if type(SpyDB)=="table" and type(SpyDB.kosData)=="table" then
  local realm=GetRealmName and GetRealmName() or nil
  local faction=UnitFactionGroup and UnitFactionGroup("player") or nil
  local r=realm and SpyDB.kosData[realm]
  local f=r and faction and r[faction]
  if type(f)=="table" then
   for _,charData in pairs(f) do
    if type(charData)=="table" then
     for name,pd in pairs(charData) do
      if name~="unit" and type(pd)=="table" and (pd.added or pd.kos or pd.reason) then
       addCandidate(name,pd,pd.added)
      end
     end
    end
   end
  end
 end

 for name,c in pairs(candidates) do
  -- Every imported KoS must also exist in players, otherwise Statistics hides it.
  ensurePlayer(name,c.meta,c.added)
  if SGM.db.kos[name] then
   skipped=skipped+1
  else
   SGM.modules.Roster:SetKos(name,c.reason)
   if c.added and SGM.db.kos[name] then SGM.db.kos[name].added=c.added end
   imported=imported+1
  end
 end

 if SGM.modules.Roster then SGM.modules.Roster:Rebuild() end
 if SGM.modules.MainFrame then SGM.modules.MainFrame:Refresh() end
 if SGM.modules.Statistics and SGM.modules.Statistics.Refresh then SGM.modules.Statistics:Refresh() end

 local found=0; for _ in pairs(candidates) do found=found+1 end
 if found==0 then
  SGM:Print("No old Spy KoS entries were found. Keep the old Spy addon installed, then press Import again.")
 else
  SGM:Print("Spy import complete: "..imported.." KoS imported, "..skipped.." already existed. Total KoS available: "..tostring(found)..".")
 end
 return imported,skipped,found
end
