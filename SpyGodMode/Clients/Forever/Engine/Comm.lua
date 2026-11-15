local __sgmBuild = select(4, GetBuildInfo())
if __sgmBuild ~= 16001 then return end
if not _G.SpyGodModeClientOK then return end
local _,SGM=...
local L=_G.SpyGodMode_L
local M={prefix="SGMODE2",sent={}}; SGM:RegisterModule("Comm",M); SGM:RegisterEvent("CHAT_MSG_ADDON")
local SEP="\31"
local function send(msg,ch)
 if not C_ChatInfo or not C_ChatInfo.SendAddonMessage or not ch then return end
 pcall(C_ChatInfo.SendAddonMessage,M.prefix,msg,ch)
end
local function channels()
 local out={}
 if SGM.cfg.networkGroup then
  local ch=IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or IsInRaid() and "RAID" or IsInGroup() and "PARTY" or nil
  if ch then out[#out+1]=ch end
 end
 if SGM.cfg.networkGuild and IsInGuild and IsInGuild() then out[#out+1]="GUILD" end
 return out
end
SGM:On("SGM_READY",function() if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix,M.prefix) end end)
SGM:On("SGM_DETECTED",function(name,p,stealth,isNew)
 if not SGM.cfg.share or not isNew then return end
 local now=GetTime(); if M.sent[name] and now-M.sent[name]<15 then return end; M.sent[name]=now
 local msg=table.concat({"S",name,p.level or 0,p.class or "",p.race or "",p.guild or "",p.zone or "",p.lastMapID or "",p.lastMapX or "",p.lastMapY or ""},SEP)
 for _,ch in ipairs(channels()) do send(msg,ch) end
end)
SGM:On("SGM_KOS_CHANGED",function(name)
 if not SGM.cfg.shareKos then return end
 local e=SGM.db.kos[name]; if not e then return end
 local tags=type(e.tags)=="table" and table.concat(e.tags,",") or ""
 local msg=table.concat({"K",name,e.reason or "",tags},SEP); for _,ch in ipairs(channels()) do send(msg,ch) end
end)
SGM:On("CHAT_MSG_ADDON",function(prefix,msg,channel,sender)
 if prefix~=M.prefix or SGM:ShortName(sender)==SGM.playerName then return end
 local typ,a,b,c,d,e,f,g,h,i=strsplit(SEP,msg)
 if typ=="S" and SGM.cfg.useShared then
  local n=SGM:ShortName(a); if not n then return end
  local p,new=SGM.modules.Roster:Upsert(n,{level=tonumber(b),class=c,race=d,guild=e,zone=f,source="network",lastMapID=tonumber(g),lastMapX=tonumber(h),lastMapY=tonumber(i)})
  if p then SGM:Fire("SGM_DETECTED",n,p,false,new) end
 elseif typ=="K" and SGM.cfg.receiveKos then
  local n=SGM:ShortName(a); if not n or SGM.db.kos[n] then return end
  SGM.modules.Roster:SetKos(n,b or L["Shared KoS"]); local entry=SGM.db.kos[n]; entry.sharedBy=SGM:ShortName(sender); entry.tags={}
  for tag in tostring(c or ""):gmatch("[^,]+") do entry.tags[#entry.tags+1]=tag end
  SGM:Print("Received shared KoS: "..n.." from "..SGM:ShortName(sender))
 end
end)
