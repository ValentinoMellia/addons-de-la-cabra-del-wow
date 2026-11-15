local __sgmBuild = select(4, GetBuildInfo())
if __sgmBuild ~= 11508 and __sgmBuild ~= 11509 then return end
if not _G.SpyGodModeClientOK then return end
local _,SGM=...
local M={lastAttacker=nil,lastAttackerAt=0,lastWinName=nil,lastWinAt=0,lastLossName=nil,lastLossAt=0,lastDetectSignal={}}; SGM:RegisterModule("Combat",M)

local function ensurePlayer(name,seed)
 name=SGM:ShortName(name); if not name then return nil,nil end
 local p=SGM.db.players[name] or {firstSeen=time(),wins=0,losses=0,detections=0}
 p.wins=tonumber(p.wins) or 0; p.losses=tonumber(p.losses) or 0; p.detections=tonumber(p.detections) or 0
 for k,v in pairs(seed or {}) do if v~=nil and v~="" then p[k]=v end end
 SGM.db.players[name]=p
 return name,p
end

local function addWin(name,detail)
 local n,p=ensurePlayer(name); if not n then return end
 local now=GetTime and GetTime() or time()
 if M.lastWinName==n and now-(M.lastWinAt or 0)<1 then return end
 M.lastWinName=n; M.lastWinAt=now
 p.wins=(p.wins or 0)+1; p.lastWin=time()
 if SGM.modules.Intelligence then SGM.modules.Intelligence:RecordTimeline(n,"WIN",detail or "You killed this player") end
 SGM:Fire("SGM_LIST_UPDATE")
end

local function addLoss(name,detail)
 local n,p=ensurePlayer(name); if not n then return end
 local now=GetTime and GetTime() or time()
 -- PARTY_KILL plus PLAYER_DEAD can describe the same death. Never double count it.
 if M.lastLossName==n and now-(M.lastLossAt or 0)<2 then return end
 M.lastLossName=n; M.lastLossAt=now
 p.losses=(p.losses or 0)+1; p.killedYou=(p.killedYou or 0)+1; p.lastKilledYou=time()
 if SGM.modules.Intelligence then SGM.modules.Intelligence:RecordTimeline(n,"LOSS",detail or "Killed you") end
 if SGM.cfg.autoWatchKillers and p.killedYou>=(tonumber(SGM.cfg.autoWatchThreshold) or 3) then SGM.db.favorites[n]=true end
 SGM:Fire("SGM_LIST_UPDATE")
end

local function record(name,guid,flags,spellId,spellName,subevent)
 name=SGM:SafeValue(name); guid=SGM:SafeValue(guid); flags=SGM:SafeValue(flags)
 spellId=SGM:SafeValue(spellId); spellName=SGM:SafeValue(spellName); subevent=SGM:SafeValue(subevent)
 if not name or not flags or not SGM:IsHostilePlayer(flags) then return end
 local short=SGM:ShortName(name)
 local existing=short and SGM.db.players and SGM.db.players[short] or nil
 local class,race=existing and existing.class,existing and existing.race
 if guid and GetPlayerInfoByGUID and (not class or not race) then local _,englishClass,_,englishRace=SGM:SafeCall(GetPlayerInfoByGUID,guid); class=class or englishClass; race=race or englishRace end
 local isStealth=type(spellId)=="number" and SGM.stealthSpells[spellId]==true
 local p,new=SGM.modules.Roster:Upsert(name,{guid=guid,class=class,race=race,spellId=spellId,spellName=spellName,stealthSpellId=isStealth and spellId or nil,zone=SGM:Zone(),source="combat",targetName=name})
 if p then
  -- Keep the combat-log hot path cheap. New/stealth detections fire instantly;
  -- routine updates signal at most once per second per enemy.
  local now=GetTime and GetTime() or time(); local key=short or name
  if new or isStealth or not M.lastDetectSignal[key] or now-M.lastDetectSignal[key]>=1 then
   M.lastDetectSignal[key]=now; SGM:Fire("SGM_DETECTED",short or name,p,isStealth,new,subevent)
  end
 end
end

-- Classic/TBC still expose the combat log. Midnight does not.
if not SGM.isMidnight and CombatLogGetCurrentEventInfo then
 SGM:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
 SGM:On("COMBAT_LOG_EVENT_UNFILTERED",function()
  if not SGM.cfg or not SGM.cfg.enabled or not SGM:CanDetectHere() then return end
  local ok,_,subevent,_,srcGUID,srcName,srcFlags,_,dstGUID,dstName,dstFlags,_,spellId,spellName=pcall(CombatLogGetCurrentEventInfo)
  if not ok then return end
  record(srcName,srcGUID,srcFlags,spellId,spellName,subevent)
  if dstGUID==SGM.playerGUID and SGM:IsHostilePlayer(srcFlags) and srcName then
   M.lastAttacker=SGM:ShortName(srcName); M.lastAttackerAt=GetTime()
  end
  if subevent=="PARTY_KILL" or subevent=="UNIT_DIED" then record(dstName,dstGUID,dstFlags,spellId,spellName,subevent) end
  if subevent=="PARTY_KILL" and srcGUID==SGM.playerGUID and SGM:IsHostilePlayer(dstFlags) and dstName then addWin(dstName,"You killed this player") end
  -- Exact Classic/TBC/Forever loss signal when the combat log identifies the player killer.
  if subevent=="PARTY_KILL" and dstGUID==SGM.playerGUID and SGM:IsHostilePlayer(srcFlags) and srcName then addLoss(srcName,"Killed you") end
 end)
end

-- Primary PvP win signal on every supported client. Blizzard supplies the killed
-- unit token when the player receives honorable-kill credit. Using this on all
-- clients also covers kills where PARTY_KILL attribution is absent/different.
SGM:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")
SGM:On("PLAYER_PVP_KILLS_CHANGED",function(unitTarget)
 if unitTarget and SGM:IsValidEnemyUnit(unitTarget) then
  local name=SGM:SafeCall(UnitName,unitTarget)
  if name then
   local _,class=SGM:SafeCall(UnitClass,unitTarget); local race=SGM:SafeCall(UnitRace,unitTarget)
   ensurePlayer(name,{class=class,race=race,zone=SGM:Zone(),lastSeen=time()})
   addWin(name,"Honorable PvP kill")
  end
 end
end)

local function midnightLossCandidate()
 local seen={}
 local function check(unit)
  if not unit or not SGM:IsValidEnemyUnit(unit) then return end
  local onMe=SGM:SafeCall(UnitIsUnit,unit.."target","player")==true
  if onMe then local n=SGM:ShortName(SGM:SafeCall(UnitName,unit)); if n then seen[n]=true end end
 end
 check("target"); check("focus")
 for i=1,40 do check("nameplate"..i) end
 local only=nil
 for n in pairs(seen) do if only and only~=n then return nil end; only=n end
 if only then return only end
 if SGM.modules.Intelligence and SGM.modules.Intelligence.GetRecentTargeter then return SGM.modules.Intelligence:GetRecentTargeter(5) end
 return nil
end

SGM:RegisterEvent("PLAYER_DEAD")
SGM:On("PLAYER_DEAD",function()
 local n
 if SGM.isMidnight then n=midnightLossCandidate()
 else
  local now=GetTime and GetTime() or time()
  -- Death can occur several seconds after the killer's last logged hit (DoTs,
  -- travel time, delayed PLAYER_DEAD), so retain the last hostile attacker longer.
  if M.lastAttacker and now-(M.lastAttackerAt or 0)<=15 then n=M.lastAttacker end
 end
 if n then addLoss(n,"Killed you") end
 M.lastAttacker=nil; M.lastAttackerAt=0
end)
