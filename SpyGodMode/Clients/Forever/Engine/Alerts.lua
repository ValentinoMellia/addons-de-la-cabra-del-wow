local __sgmBuild = select(4, GetBuildInfo())
if __sgmBuild ~= 16001 then return end
if not _G.SpyGodModeClientOK then return end
local _,SGM=...
local L=_G.SpyGodMode_L
local M={last={}}; SGM:RegisterModule("Alerts",M)
SGM:On("SGM_DETECTED",function(name,p,stealth,isNew)
 local now=GetTime(); if M.last[name] and now-M.last[name]<2 then return end; M.last[name]=now
 local kos=SGM.db.kos[name]~=nil; local guildKos=p.guild and SGM.db.guildKos[p.guild]
 local kind=(kos or guildKos) and L["KOS"] or (stealth and "STEALTH" or "NEARBY")
 -- Alert only when the enemy newly enters Nearby. KoS status chooses the
 -- stronger KoS sound, but mouseover/target refreshes must not retrigger it.
 if isNew or stealth then
  local allow=(kind==L["KOS"] and ((kos and SGM.cfg.soundKos~=false) or (guildKos and SGM.cfg.soundGuildKos~=false)))
   or (kind=="STEALTH" and SGM.cfg.soundStealth~=false)
   or (kind=="NEARBY" and SGM.cfg.soundNearby~=false)
  if allow then SGM:SafeSound(kind) end
 end
 -- Show a visual alert for every newly detected enemy, matching the sound
 -- behaviour. KoS, Guild KoS and stealth warnings remain controlled by their
 -- dedicated options.
 local showNearby=isNew
 local showKos=isNew and kos and SGM.cfg.warnKos
 local showStealth=stealth and SGM.cfg.warnStealth
 local showGuildKos=isNew and guildKos and SGM.cfg.warnKosGuild
 if SGM.cfg.warnings and (showNearby or showKos or showStealth or showGuildKos) then
  SGM:Fire("SGM_ALERT",kind,name,p)
 end
 local channel=SGM.cfg.announce
 if channel and channel~="NONE" and (not SGM.cfg.onlyAnnounceKos or kos) then
  local text=(kos and L["Kill On Sight: "] or stealth and L["Stealth enemy: "] or L["Enemy nearby: "])..name
  if channel=="SELF" then SGM:Print(text) else pcall(SendChatMessage,text,channel) end
 end
end)
