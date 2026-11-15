local __sgmBuild = select(4, GetBuildInfo())
if __sgmBuild ~= 50503 and __sgmBuild ~= 50504 then return end
if not _G.SpyGodModeClientOK then return end
local _,SGM=...
local accountDefaults={schema=2,players={},kos={},ignore={},guildKos={},favorites={},timelines={},sightings={},backups={}}
local charDefaults={enabled=true,visible=true,startupVisibilityVersion=1,nearbyTTLVersion=1,quickSettingsDefaultsVersion=1,nonPvpDetectionVersion=1,soundProfileRepairVersion=1,locked=false,clamp=true,invert=false,width=190,rowHeight=15,rowSpacing=1,maxRows=30,alpha=1,bgAlpha=.88,scale=1,showOnDetection=true,detectNonPvp=true,onlyPvp=false,prioritizeKos=true,stealthPriority=true,showKosButton=true,tooltipWinLoss=true,tooltipReason=true,tooltipLastSeen=true,sound=true,soundOnlyKos=false,soundNearby=true,soundKos=true,soundStealth=true,soundGuildKos=true,soundProfile="CLASSIC",warnings=true,warnStealth=true,warnKos=true,warnKosGuild=true,announce="NONE",onlyAnnounceKos=false,removeAfter=60,purgeAfter=2592000,historyRetentionDays=30,share=true,useShared=true,minimap=true,map=false,x=230,y=520,positionPoint="BOTTOMLEFT",relativePoint="BOTTOMLEFT",alertX=0,alertY=-140,currentView="NEARBY",autoHide=false,autoHideDelay=30,autoCollapse=false,enemyCityMode=true,compactHUD=false,animations=true,threatColors=true,lastSeenFade=true,watchMode=true,intelligence=true,targetWarnings=true,sosWarnings=true,sosThreshold=4,mapIntel=true,networkGroup=true,networkGuild=true,shareKos=false,receiveKos=true,tooltipThreat=true,tooltipHistory=true,autoWatchKillers=false,autoWatchThreshold=3,highThreatScore=70,mediumThreatScore=40,historyLimit=30}
local function merge(dst,src) for k,v in pairs(src) do if type(v)=="table" then dst[k]=type(dst[k])=="table" and dst[k] or {}; merge(dst[k],v) elseif dst[k]==nil then dst[k]=v end end end
SGM:On("SGM_DATABASE",function()
 SpyGodModeDB=type(SpyGodModeDB)=="table" and SpyGodModeDB or {}; SpyGodModeCharDB=type(SpyGodModeCharDB)=="table" and SpyGodModeCharDB or {}
 local needsStartupVisibility=SpyGodModeCharDB.startupVisibilityVersion~=1
 local needsNearbyTTL=SpyGodModeCharDB.nearbyTTLVersion~=1
 local needsQuickDefaults=SpyGodModeCharDB.quickSettingsDefaultsVersion~=1
 local needsNonPvpDetection=SpyGodModeCharDB.nonPvpDetectionVersion~=1
 local needsSoundProfileRepair=SpyGodModeCharDB.soundProfileRepairVersion~=1
 merge(SpyGodModeDB,accountDefaults); merge(SpyGodModeCharDB,charDefaults)
 if needsSoundProfileRepair then if SpyGodModeCharDB.soundProfile=="SILENT" then SpyGodModeCharDB.soundProfile="CLASSIC" end; SpyGodModeCharDB.soundProfileRepairVersion=1 end
 if needsStartupVisibility then SpyGodModeCharDB.visible=true; SpyGodModeCharDB.startupVisibilityVersion=1 end
 if needsNearbyTTL then SpyGodModeCharDB.removeAfter=60; SpyGodModeCharDB.nearbyTTLVersion=1 end
 if needsQuickDefaults then SpyGodModeCharDB.autoHide=false; SpyGodModeCharDB.autoCollapse=false; SpyGodModeCharDB.compactHUD=false; SpyGodModeCharDB.quickSettingsDefaultsVersion=1 end
 if needsNonPvpDetection then
  -- Preserve the old "Only PvP" preference while moving to the clearer positive option.
  SpyGodModeCharDB.detectNonPvp=SpyGodModeCharDB.onlyPvp~=true
  SpyGodModeCharDB.nonPvpDetectionVersion=1
 end
 SGM.db=SpyGodModeDB; SGM.cfg=SpyGodModeCharDB
end)
