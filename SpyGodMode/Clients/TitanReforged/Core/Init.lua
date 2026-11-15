local __sgmBuild = select(4, GetBuildInfo())
if __sgmBuild ~= 38002 then return end
if not _G.SpyGodModeClientOK then return end
local addonName, SGM = ...
_G.SpyGodMode = SGM
SGM.addonName, SGM.version = addonName, "1.2.16"
SGM.modules, SGM.listeners = {}, {}
SGM.eventFrame = CreateFrame("Frame")
function SGM:RegisterModule(name, module) self.modules[name] = module end
function SGM:On(name, fn) self.listeners[name] = self.listeners[name] or {}; self.listeners[name][#self.listeners[name]+1] = fn end
function SGM:Fire(name, ...)
  local list = self.listeners[name]; if not list then return end
  for i=1,#list do local ok,err=pcall(list[i],...); if not ok then geterrorhandler()(err) end end
end
function SGM:RegisterEvent(name)
  if not name then return false end
  local ok=pcall(self.eventFrame.RegisterEvent,self.eventFrame,name)
  return ok
end
SGM.eventFrame:SetScript("OnEvent", function(_, event, ...) SGM:Fire(event, ...) end)
for _,e in ipairs({"ADDON_LOADED","PLAYER_LOGIN","PLAYER_ENTERING_WORLD","ZONE_CHANGED","ZONE_CHANGED_INDOORS","ZONE_CHANGED_NEW_AREA"}) do SGM:RegisterEvent(e) end
SGM:On("ADDON_LOADED", function(name) if name==addonName then SGM:Fire("SGM_DATABASE") end end)

function SGM:PurgeOldHistory()
  if not SGM.db or not SGM.cfg then return 0 end
  local days=tonumber(SGM.cfg.historyRetentionDays) or 30
  if days<=0 then return 0 end -- 0 = Forever
  local cutoff=time()-(days*86400)
  local removed=0
  SGM.db.players=SGM.db.players or {}
  for name,p in pairs(SGM.db.players) do
    local protected=(SGM.db.kos and SGM.db.kos[name]) or (p.guild and SGM.db.guildKos and SGM.db.guildKos[p.guild])
    if not protected and (tonumber(p.lastSeen) or 0)>0 and (tonumber(p.lastSeen) or 0)<cutoff then
      SGM.db.players[name]=nil
      if SGM.db.timelines then SGM.db.timelines[name]=nil end
      if SGM.db.sightings then SGM.db.sightings[name]=nil end
      removed=removed+1
    end
  end
  -- Also trim timestamped timeline/sighting entries for retained players.
  for _,bucketName in ipairs({"timelines","sightings"}) do
    local buckets=SGM.db[bucketName]
    if buckets then
      for name,list in pairs(buckets) do
        local p=SGM.db.players[name] or {}
        local protected=(SGM.db.kos and SGM.db.kos[name]) or (p.guild and SGM.db.guildKos and SGM.db.guildKos[p.guild])
        if not protected and type(list)=="table" then
          for i=#list,1,-1 do if (tonumber(list[i] and list[i].time) or 0)>0 and list[i].time<cutoff then table.remove(list,i) end end
          if #list==0 and not SGM.db.players[name] then buckets[name]=nil end
        end
      end
    end
  end
  return removed
end

SGM:On("PLAYER_LOGIN", function()
  SGM.playerName = UnitName("player"); SGM.playerGUID=UnitGUID("player"); SGM.playerFaction=UnitFactionGroup("player")
  SGM:PurgeOldHistory()
  SGM:Fire("SGM_READY")
end)

local wasInEnemyCity=false
local function CheckEnemyCity()
 if not SGM.cfg or not SGM.IsEnemyCity then return end
 local inEnemyCity=SGM:IsEnemyCity()
 if inEnemyCity and not wasInEnemyCity and SGM.cfg.enemyCityMode~=true then
  SGM.cfg.enemyCityMode=true
  SGM:Fire("SGM_ENEMY_CITY_ENABLED")
 end
 wasInEnemyCity=inEnemyCity
end
SGM:On("SGM_READY",function()
 if C_Timer and C_Timer.After then C_Timer.After(1,CheckEnemyCity) else CheckEnemyCity() end
end)
SGM:On("PLAYER_ENTERING_WORLD",function()
 if C_Timer and C_Timer.After then C_Timer.After(1,CheckEnemyCity) else CheckEnemyCity() end
end)
SGM:On("ZONE_CHANGED",CheckEnemyCity)
SGM:On("ZONE_CHANGED_INDOORS",CheckEnemyCity)
SGM:On("ZONE_CHANGED_NEW_AREA",CheckEnemyCity)
