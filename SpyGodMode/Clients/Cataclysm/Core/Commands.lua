local __sgmBuild = select(4, GetBuildInfo())
if __sgmBuild ~= 40402 then return end
if not _G.SpyGodModeClientOK then return end
local _,SGM=...

local function showMain()
 local w=SGM.modules.MainFrame
 if w and w.SetVisible then w:SetVisible(true) end
end
local function hideMain()
 local w=SGM.modules.MainFrame
 if w and w.SetVisible then w:SetVisible(false) end
end
local function resetMain()
 local w=SGM.modules.MainFrame
 if w and w.ResetPosition then w:ResetPosition() end
end
local function help()
 SGM:Print("Spy God Mode commands:")
 SGM:Print("/spy show | hide | reset | clear | config | debug")
 SGM:Print("/spy nearby | lasthour | kos | ignore | stats")
 SGM:Print("/spy kos <name> - Opens the required KoS reason box.")
 SGM:Print("/spy kosremove <name> - Removes a player from KoS.")
 SGM:Print("/spy kosreason <name> - Edits the player's KoS reason.")
 SGM:Print("/spy ignore <name> - Adds/removes Ignore.")
 SGM:Print("/spy test danger|stealth|kos|high|target|sos|add|remove")
 SGM:Print("/spy favorite <name> | tag <name> <tag> | timeline <name>")
 SGM:Print("/spy exportkos | importkos | backup | restore")
end
local function run(msg)
 local cmd,arg=(msg or ""):match("^(%S*)%s*(.-)$"); cmd=(cmd or ""):lower()
 if cmd=="" or cmd=="help" then help()
 elseif cmd=="show" then showMain()
 elseif cmd=="hide" then hideMain()
 elseif cmd=="reset" then resetMain()
 elseif cmd=="debug" or cmd=="status" then
  local build=select(4,GetBuildInfo())
  local zone=SGM:Zone()
  local sanctuary=SGM:IsSanctuaryZone() and "YES" or "NO"
  local can=SGM:CanDetectHere() and "YES" or "NO"
  local np="n/a"
  if GetCVarBool and (SGM.isMidnight or SGM.isForever) then np=GetCVarBool("nameplateShowEnemies") and "ON" or "OFF" end
  local R=SGM.modules.Roster; local S=SGM.modules.Scanner
  local nearby=R and #R.nearbyOrder or 0
  local tracked=0; if S and S.nameplates then for _ in pairs(S.nameplates) do tracked=tracked+1 end end
  local live=0; if S and S.liveUnits then for _ in pairs(S.liveUnits) do live=live+1 end end
  SGM:Print("Detection diagnostics")
  SGM:Print("Client build: "..tostring(build).." | Zone: "..tostring(zone))
  SGM:Print("Detection allowed: "..can.." | Sanctuary: "..sanctuary.." | Enemy nameplates: "..np)
  SGM:Print("Nearby: "..nearby.." | Tracked nameplates: "..tracked.." | Live enemy units: "..live)
  SGM:Print("Non-PvP enemies: "..((SGM.cfg.detectNonPvp~=false) and "ON" or "OFF").." | Sounds: "..(SGM.cfg.sound and "ON" or "OFF"))
  if (SGM.isMidnight or SGM.isForever) and np=="OFF" then SGM:Print("WARNING: Enemy nameplates are OFF. Visible-player detection may be limited until mouseover/target.") end
 elseif cmd=="clear" then SGM.modules.Roster:ClearNearby()
 elseif cmd=="config" or cmd=="options" then SGM.modules.Options:Open()
 elseif cmd=="nearby" then showMain(); SGM.cfg.currentView="NEARBY"; SGM.modules.MainFrame:Refresh()
 elseif cmd=="lasthour" or cmd=="hour" then showMain(); SGM.cfg.currentView="HOUR"; SGM.modules.MainFrame:Refresh()
 elseif cmd=="kos" and arg=="" then showMain(); SGM.cfg.currentView="KOS"; SGM.modules.MainFrame:Refresh()
 elseif cmd=="kos" then SGM.modules.KosDialogs:Prompt(arg,SGM.db.kos[SGM:ShortName(arg)]~=nil)
 elseif cmd=="kosremove" then SGM.modules.KosDialogs:Remove(arg)
 elseif cmd=="kosreason" then
  arg=SGM:ShortName(arg)
  if SGM.db.kos[arg] then SGM.modules.KosDialogs:Prompt(arg,true) else SGM:Print(arg.." is not on Kill On Sight") end
 elseif cmd=="ignore" and arg=="" then showMain(); SGM.cfg.currentView="IGNORE"; SGM.modules.MainFrame:Refresh()
 elseif cmd=="ignore" then
  arg=SGM:ShortName(arg)
  if SGM.db.ignore[arg] then SGM.modules.Roster:RemoveIgnore(arg); SGM:SafeSound("REMOVE"); SGM:Print(arg.." removed from Ignore")
  else SGM.modules.Roster:SetIgnore(arg); SGM:SafeSound("ADD"); SGM:Print(arg.." added to Ignore") end
 elseif cmd=="favorite" then
  arg=SGM:ShortName(arg); if not arg or arg=="" then SGM:Print("Usage: /spy favorite <name>") return end
  SGM.db.favorites=SGM.db.favorites or {}; if SGM.db.favorites[arg] then SGM.db.favorites[arg]=nil; SGM:Print(arg.." removed from Watch/Favorites") else SGM.db.favorites[arg]=true; SGM:Print(arg.." added to Watch/Favorites") end; SGM.modules.Roster:Rebuild()
 elseif cmd=="tag" then
  local n,tag=arg:match("^(%S+)%s+(.+)$"); n=SGM:ShortName(n); if not n or not tag or not SGM.db.kos[n] then SGM:Print("Usage: /spy tag <KoS player> <tag>") return end
  local e=SGM.db.kos[n]; e.tags=type(e.tags)=="table" and e.tags or {}; local found
  for i,v in ipairs(e.tags) do if v:lower()==tag:lower() then table.remove(e.tags,i); found=true; break end end; if not found then e.tags[#e.tags+1]=tag end; SGM:Print((found and "Removed tag from " or "Added tag to ")..n..": "..tag)
 elseif cmd=="timeline" then
  local n=SGM:ShortName(arg); local t=n and SGM.db.timelines and SGM.db.timelines[n] or {}; if not n or #t==0 then SGM:Print("No timeline stored for "..tostring(n or arg)); return end
  SGM:Print("Timeline for "..n.." ("..#t.." events)"); local first=math.max(1,#t-9); for i=first,#t do local e=t[i]; SGM:Print(date("%m-%d %H:%M",e.time or time()).." - "..tostring(e.kind).." - "..tostring(e.detail or e.zone or "")) end
 elseif cmd=="exportkos" then if SGM.modules.DataTools then SGM.modules.DataTools:ShowExport() end
 elseif cmd=="importkos" then if SGM.modules.DataTools then SGM.modules.DataTools:ShowImport() end
 elseif cmd=="backup" then if SGM.modules.DataTools then SGM.modules.DataTools:Backup() end
 elseif cmd=="restore" then if SGM.modules.DataTools then SGM.modules.DataTools:RestoreLatest() end
 elseif cmd=="stats" then showMain(); SGM.cfg.currentView="STATS"; SGM.modules.MainFrame:Refresh()
 elseif cmd=="test" then
  local test=(arg or ""):lower()
  local kinds={nearby="NEARBY",danger="NEARBY",stealth="STEALTH",kos="KOS",high="HIGH",target="TARGET",sos="SOS",add="ADD",remove="REMOVE"}
  local kind=kinds[test]
  if not kind then SGM:Print("Tests: /spy test danger | stealth | kos | high | target | sos | add | remove"); return end
  SGM:SafeSound(kind)
  if kind=="NEARBY" or kind=="STEALTH" or kind=="KOS" or kind=="HIGH" or kind=="TARGET" or kind=="SOS" then
   SGM:Fire("SGM_ALERT",kind,"Test Enemy",{zone=GetZoneText() or "Test Zone",class=(kind=="STEALTH" and "ROGUE" or "WARRIOR"),level=(UnitLevel("player") or 1)+5})
  end
 else help() end
end
SLASH_SPYGODMODE1="/spy"
SLASH_SPYGODMODE2="/sgm"
SLASH_SPYGODMODE3="/spygodmode"
SlashCmdList.SPYGODMODE=run
