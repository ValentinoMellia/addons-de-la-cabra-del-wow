local __sgmBuild = select(4, GetBuildInfo())
if __sgmBuild ~= 16001 then return end
if not _G.SpyGodModeClientOK then return end
local _,SGM=...
local L=_G.SpyGodMode_L
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
 if SGM.modules.Intelligence then SGM.modules.Intelligence:RecordTimeline(n,"WIN",detail or L["You killed this player"]) end
 SGM:Fire("SGM_LIST_UPDATE")
end

local function addLoss(name,detail)
 local n,p=ensurePlayer(name); if not n then return end
 local now=GetTime and GetTime() or time()
 -- PARTY_KILL plus PLAYER_DEAD can describe the same death. Never double count it.
 if M.lastLossName==n and now-(M.lastLossAt or 0)<2 then return end
 M.lastLossName=n; M.lastLossAt=now
 p.losses=(p.losses or 0)+1; p.killedYou=(p.killedYou or 0)+1; p.lastKilledYou=time()
 if SGM.modules.Intelligence then SGM.modules.Intelligence:RecordTimeline(n,"LOSS",detail or L["Killed you"]) end
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
if not SGM.isMidnight and not SGM.isForever and CombatLogGetCurrentEventInfo then
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
  if subevent=="PARTY_KILL" and srcGUID==SGM.playerGUID and SGM:IsHostilePlayer(dstFlags) and dstName then addWin(dstName,L["You killed this player"]) end
  -- Exact Classic/TBC/Forever loss signal when the combat log identifies the player killer.
  if subevent=="PARTY_KILL" and dstGUID==SGM.playerGUID and SGM:IsHostilePlayer(srcFlags) and srcName then addLoss(srcName,L["Killed you"]) end
 end)
end

-- Forever may expose hostile stealth casts through the combat log even when
-- the casting enemy disappears from nameplates. This is optional: clients that
-- hide the combat log keep the existing visible-unit scanner unchanged.
-- Filter BEFORE recording to avoid adding a combat-log hot path for all spells.
if SGM.isForever and CombatLogGetCurrentEventInfo then
 SGM:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
 SGM:On("COMBAT_LOG_EVENT_UNFILTERED",function()
  if not SGM.cfg or not SGM.cfg.enabled or not SGM:CanDetectHere() then return end
  local ok,_,subevent,_,srcGUID,srcName,srcFlags,_,_,_,_,_,spellId,spellName=pcall(CombatLogGetCurrentEventInfo)
  if not ok or SGM:IsSecret(subevent) or SGM:IsSecret(spellId) then return end
  if subevent~="SPELL_CAST_SUCCESS" and subevent~="SPELL_AURA_APPLIED" then return end
  if type(spellId)~="number" or not SGM.stealthSpells[spellId] then return end
  record(srcName,srcGUID,srcFlags,spellId,spellName,subevent)
 end)
end

-- Modern-client direct kill signal. On Midnight/Forever, PARTY_KILL GUID
-- payloads can be secret during an active PvP match. Never inspect/compare those
-- GUIDs in Lua. Instead pass them straight to Blizzard's PvP scoreboard resolver;
-- PVPScoreInfo.name is explicitly NeverSecret and can safely identify the player.
local function nameFromEventGUID(guid)
 if guid==nil then return nil end

 -- Critical Midnight/Forever PvP path: the GUID itself may be secret, but Blizzard
 -- permits it to be consumed by this API and the returned player name is NeverSecret.
 if C_PvP and C_PvP.GetScoreInfoByPlayerGuid then
  local ok,info=pcall(C_PvP.GetScoreInfoByPlayerGuid,guid)
  if ok and type(info)=="table" then
   local name=info.name
   if name and not SGM:IsSecret(name) then return SGM:ShortName(name) end
  end
 end

 -- Outside restricted PvP the GUID is ordinary, so the normal resolver is useful.
 if SGM:IsSecret(guid) then return nil end
 if guid==SGM.playerGUID then return SGM.playerName end
 for name,p in pairs((SGM.db and SGM.db.players) or {}) do
  if p and p.guid==guid then return name end
 end
 if GetPlayerInfoByGUID then
  local name=SGM:SafeCall(GetPlayerInfoByGUID,guid)
  if name then return SGM:ShortName(name) end
 end
 local function fromUnit(unit)
  if SGM:IsValidEnemyUnit(unit) and SGM:SafeCall(UnitGUID,unit)==guid then
   return SGM:ShortName(SGM:SafeCall(UnitName,unit))
  end
 end
 local n=fromUnit("target") or fromUnit("focus") or fromUnit("mouseover")
 if n then return n end
 for i=1,40 do n=fromUnit("nameplate"..i); if n then return n end end
 return nil
end

if SGM.isMidnight or SGM.addonName=="SpyGodMode_Forever" then
 SGM:RegisterEvent("PARTY_KILL")
 SGM:On("PARTY_KILL",function(attackerGUID,targetGUID)
  -- Do not SafeValue() these payloads: that discarded the exact Midnight PvP
  -- events we need because their GUIDs are secret inside active PvP matches.
  local attackerName=nameFromEventGUID(attackerGUID)
  local targetName=nameFromEventGUID(targetGUID)
  local me=SGM:ShortName(SGM.playerName)
  if attackerName and targetName and me then
   if attackerName==me and targetName~=me then
    addWin(targetName,L["You killed this player"])
   elseif targetName==me and attackerName~=me then
    addLoss(attackerName,L["Killed you"])
   end
  end
 end)

 -- World-PvP/nonrestricted fallback when the dead target remains queryable.
 SGM:RegisterEvent("PLAYER_TARGET_DIED")
 SGM:On("PLAYER_TARGET_DIED",function()
  if SGM:IsValidEnemyUnit("target") then
   local n=SGM:ShortName(SGM:SafeCall(UnitName,"target"))
   if n then addWin(n,L["Your enemy target died"]) end
  end
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
   addWin(name,L["Honorable PvP kill"])
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

-- Midnight/Forever loss attribution. PARTY_KILL is a friendly-kill signal; it is
-- not a reliable notification when an enemy kills the local player. Prefer the
-- client's own Death Recap after PLAYER_DEAD, then fall back to visible-unit
-- attribution. All recap reads are protected because restricted PvP may hide them.
local function deathRecapLossCandidate()
 if not C_DeathRecap or not C_DeathRecap.GetRecapEvents then return nil end
 local ok,events=pcall(C_DeathRecap.GetRecapEvents)
 if not ok or type(events)~="table" then return nil end
 for i=#events,1,-1 do
  local e=events[i]
  if type(e)=="table" then
   local ok2,name,guid=pcall(function() return e.sourceName,e.sourceGUID end)
   if ok2 and name and not SGM:IsSecret(name) then
    local playerSource=false
    if guid and not SGM:IsSecret(guid) and type(guid)=="string" then
     playerSource=guid:match("^Player%-")~=nil
    end
    if playerSource then return SGM:ShortName(name) end
   end
  end
 end
 return nil
end

local function recordModernLoss()
 local n=deathRecapLossCandidate() or midnightLossCandidate()
 if n then addLoss(n,L["Killed you"]) end
 M.lastAttacker=nil; M.lastAttackerAt=0
end

SGM:RegisterEvent("PLAYER_DEAD")
SGM:On("PLAYER_DEAD",function()
 if SGM.isMidnight or SGM.addonName=="SpyGodMode_Forever" then
  -- The recap can populate immediately after PLAYER_DEAD rather than before the
  -- event handler returns, so try now and once more on the next UI tick.
  local before=M.lastLossAt or 0
  recordModernLoss()
  if (M.lastLossAt or 0)==before and C_Timer and C_Timer.After then
   C_Timer.After(0,function()
    if (M.lastLossAt or 0)==before then recordModernLoss() end
   end)
  end
 else
  local now=GetTime and GetTime() or time()
  if M.lastAttacker and now-(M.lastAttackerAt or 0)<=15 then addLoss(M.lastAttacker,L["Killed you"]) end
  M.lastAttacker=nil; M.lastAttackerAt=0
 end
end)
