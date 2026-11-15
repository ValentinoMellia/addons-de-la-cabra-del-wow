local __sgmBuild = select(4, GetBuildInfo())
if __sgmBuild ~= 11508 and __sgmBuild ~= 11509 then return end
if not _G.SpyGodModeClientOK then return end
local _,SGM=...
local S={rows={},filtered={},selected=nil,offset=0,sortKey="LAST",filter="ALL"}
SGM:RegisterModule("Statistics",S)

local ROWS=17
local ROW_H=21
local classes={"ALL","WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","SHAMAN","MAGE","WARLOCK","DRUID"}

local C={bg={.012,.016,.022,.985},panel={.022,.028,.038,.985},panel2={.032,.038,.05,.98},gold={1,.72,.16,1},line={.18,.19,.22,1},muted={.58,.62,.69},red={1,.24,.2},green={.28,.9,.48}}
local function backdrop(frame,bg,border)
 frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=10,insets={left=2,right=2,top=2,bottom=2}})
 frame:SetBackdropColor(unpack(bg or C.bg)); frame:SetBackdropBorderColor(unpack(border or C.line))
end
local function text(parent,font,point,x,y,value)
 local fs=parent:CreateFontString(nil,"OVERLAY",font or "GameFontNormalSmall"); fs:SetPoint(point or "LEFT",x or 0,y or 0); if value then fs:SetText(value) end; return fs
end
local function makeButton(parent,label,w)
 local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate"); b:SetSize(w or 80,22); b:SetText(label); return b
end
local function section(parent,label,y)
 local fs=text(parent,"GameFontNormalSmall","TOPLEFT",14,y,label:upper()); fs:SetTextColor(1,.72,.16)
 local line=parent:CreateTexture(nil,"ARTWORK"); line:SetColorTexture(.22,.19,.10,.9); line:SetPoint("TOPLEFT",14,y-15); line:SetPoint("TOPRIGHT",-14,y-15); line:SetHeight(1)
 return fs
end
local function threatColor(label)
 if label=="EXTREME" then return 1,.18,.18 elseif label=="HIGH" then return 1,.48,.12 elseif label=="MEDIUM" then return 1,.78,.18 else return .35,.9,.5 end
end

function S:Create()
 if self.frame then return end
 local f=CreateFrame("Frame","SpyGodMode_StatisticsFrame",UIParent,"BackdropTemplate")
 f:SetSize(900,596); f:SetPoint("CENTER"); f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true); f:SetFrameStrata("DIALOG"); backdrop(f,C.bg,{.48,.36,.12,1}); self.frame=f
 -- Statistics has its own drag handle; the Nearby-window lock must not block it.
  local function StopStatisticsDrag()
   f:StopMovingOrSizing()
   local x,y=f:GetCenter()
   local parentX,parentY=UIParent:GetCenter()
   if x and y and parentX and parentY then
    local offsetX,offsetY=x-parentX,y-parentY
    f:ClearAllPoints()
    f:SetPoint("CENTER",UIParent,"CENTER",offsetX,offsetY)
    if SGM.cfg then SGM.cfg.statisticsPosition={x=offsetX,y=offsetY} end
   end
  end
  local function StartStatisticsDrag(_,button)
   if not InCombatLockdown() then f:StartMoving() end
  end
  if SGM.cfg and type(SGM.cfg.statisticsPosition)=="table" then
   local p=SGM.cfg.statisticsPosition
   if type(p.x)=="number" and type(p.y)=="number" then
    f:ClearAllPoints(); f:SetPoint("CENTER",UIParent,"CENTER",p.x,p.y)
   end
  end
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart",StartStatisticsDrag)
  f:SetScript("OnDragStop",StopStatisticsDrag)

 local titlebar=CreateFrame("Frame",nil,f,"BackdropTemplate"); titlebar:SetPoint("TOPLEFT",3,-3); titlebar:SetPoint("TOPRIGHT",-3,-3); titlebar:SetHeight(42); titlebar:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"}); titlebar:SetBackdropColor(.035,.04,.052,1); titlebar:EnableMouse(true)
 titlebar:RegisterForDrag("LeftButton"); titlebar:SetScript("OnDragStart",StartStatisticsDrag); titlebar:SetScript("OnDragStop",StopStatisticsDrag)
 local brand=text(titlebar,"GameFontNormalLarge","LEFT",12,5,"SPY GOD MODE"); brand:SetTextColor(1,.72,.16)
 local sub=text(titlebar,"GameFontDisableSmall","LEFT",13,-10,"PLAYER INTELLIGENCE  -  STATISTICS"); sub:SetTextColor(.56,.6,.68)
 self.counter=text(titlebar,"GameFontNormalSmall","RIGHT",-42,0,"0 PLAYERS"); self.counter:SetTextColor(.78,.81,.87)
 local close=CreateFrame("Button",nil,titlebar,"UIPanelCloseButton"); close:SetPoint("RIGHT",2,0); close:SetScript("OnClick",function() if not InCombatLockdown() then f:Hide() else S.pendingHide=true end end)

 local tabs=CreateFrame("Frame",nil,f); tabs:SetPoint("TOPLEFT",10,-50); tabs:SetSize(880,28); self.tabs={}
 local tabDefs={{"ALL","ALL"},{"KOS","KOS"},{"WATCH","WATCH"},{"GUILDKOS","GUILD KOS"},{"RECENT","RECENT"},{"KILLERS","KILLERS"}}
 local last
 for _,v in ipairs(tabDefs) do
  local b=makeButton(tabs,v[2],88); if last then b:SetPoint("LEFT",last,"RIGHT",4,0) else b:SetPoint("LEFT",0,0) end; last=b; b.key=v[1]
  b:SetScript("OnClick",function(self) S.filter=self.key; S.offset=0; S:Refresh() end); self.tabs[#self.tabs+1]=b
 end

 local toolbar=CreateFrame("Frame",nil,f,"BackdropTemplate"); toolbar:SetPoint("TOPLEFT",10,-82); toolbar:SetPoint("TOPRIGHT",-10,-82); toolbar:SetHeight(38); backdrop(toolbar,C.panel2,{.12,.13,.16,1})
 local search=CreateFrame("EditBox",nil,toolbar,"InputBoxTemplate"); search:SetSize(205,24); search:SetPoint("LEFT",10,0); search:SetAutoFocus(false); self.search=search
 local hint=text(toolbar,"GameFontDisableSmall","LEFT",18,0,"Search player / guild / zone"); hint:SetTextColor(.42,.45,.5); self.searchHint=hint
 search:SetScript("OnEditFocusGained",function() hint:Hide() end); search:SetScript("OnEditFocusLost",function() if search:GetText()=="" then hint:Show() end end); search:SetScript("OnTextChanged",function() hint:SetShown(search:GetText()=="" and not search:HasFocus()); S.searchText=search:GetText() or ""; S.offset=0; S:Refresh() end)

 local filter=makeButton(toolbar,"CLASS: ALL",112); filter:SetPoint("LEFT",search,"RIGHT",10,0); self.filterButton=filter
 filter:SetScript("OnClick",function(self)
  local menu={{text="Class Filter",isTitle=true,notCheckable=true},{text="All classes",notCheckable=true,func=function() S.classFilter=nil; self:SetText("CLASS: ALL"); S:Refresh() end}}
  for _,c in ipairs(classes) do if c~="ALL" then menu[#menu+1]={text=c:sub(1,1)..c:sub(2):lower(),notCheckable=true,func=function() S.classFilter=c; self:SetText("CLASS: "..c); S:Refresh() end} end end
  SGM.modules.Rows:ShowMenu(menu,self)
 end)
 local sort=makeButton(toolbar,"SORT: LAST SEEN",135); sort:SetPoint("LEFT",filter,"RIGHT",6,0); self.sortButton=sort
 sort:SetScript("OnClick",function(self)
  local opts={{"LAST","LAST SEEN"},{"NAME","NAME"},{"LEVEL","LEVEL"},{"SEEN","ENCOUNTERS"},{"WINS","WINS"},{"LOSSES","LOSSES"}}
  local menu={{text="Sort by",isTitle=true,notCheckable=true}}
  for _,v in ipairs(opts) do menu[#menu+1]={text=v[2],notCheckable=true,func=function() S.sortKey=v[1]; self:SetText("SORT: "..v[2]); S:Refresh() end} end
  SGM.modules.Rows:ShowMenu(menu,self)
 end)
 local refresh=makeButton(toolbar,"REFRESH",82); refresh:SetPoint("RIGHT",-8,0); refresh:SetScript("OnClick",function() S:Refresh() end)

 local list=CreateFrame("Frame",nil,f,"BackdropTemplate"); list:SetPoint("TOPLEFT",10,-126); list:SetSize(535,398); backdrop(list,C.panel,{.14,.15,.18,1}); self.list=list
 local headers=CreateFrame("Frame",nil,list,"BackdropTemplate"); headers:SetPoint("TOPLEFT",2,-2); headers:SetPoint("TOPRIGHT",-20,-2); headers:SetHeight(23); headers:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"}); headers:SetBackdropColor(.055,.062,.078,1)
 local h1=text(headers,"GameFontNormalSmall","LEFT",8,0,"PLAYER"); h1:SetTextColor(1,.72,.16); local h2=text(headers,"GameFontNormalSmall","LEFT",278,0,"LVL"); h2:SetTextColor(1,.72,.16); local h3=text(headers,"GameFontNormalSmall","LEFT",320,0,"LAST SEEN"); h3:SetTextColor(1,.72,.16); local h4=text(headers,"GameFontNormalSmall","LEFT",405,0,"W / L"); h4:SetTextColor(1,.72,.16); local h5=text(headers,"GameFontNormalSmall","LEFT",466,0,"DANGER"); h5:SetTextColor(1,.72,.16)
 for i=1,ROWS do
  local r=CreateFrame("Button",nil,list,"SecureActionButtonTemplate,BackdropTemplate"); r:SetPoint("TOPLEFT",3,-27-(i-1)*ROW_H); r:SetPoint("TOPRIGHT",-21,-27-(i-1)*ROW_H); r:SetHeight(ROW_H-1); r:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1}); r:SetBackdropColor(.025,.03,.04,(i%2==0) and .98 or .88)
  r.marker=text(r,"GameFontNormalSmall","LEFT",6,0); r.name=text(r,"GameFontHighlightSmall","LEFT",25,0); r.name:SetPoint("RIGHT",-235,0); r.name:SetJustifyH("LEFT"); r.level=text(r,"GameFontHighlightSmall","LEFT",278,0); r.seen=text(r,"GameFontDisableSmall","LEFT",320,0); r.wl=text(r,"GameFontHighlightSmall","LEFT",405,0); r.threat=text(r,"GameFontNormalSmall","LEFT",466,0)
  r:RegisterForClicks("LeftButtonUp","RightButtonUp"); r:SetScript("OnClick",function(self,button)
   if not self.player then return end
   if button=="RightButton" then
    SGM.modules.Rows:OpenPlayerMenu(self)
   elseif button=="LeftButton" and IsShiftKeyDown and IsShiftKeyDown() then
    SGM.modules.Rows:ToggleKosQuick(self.player); S:Refresh()
   elseif button=="LeftButton" and IsControlKeyDown and IsControlKeyDown() then
    SGM.modules.Rows:ToggleIgnoreQuick(self.player); S:Refresh()
   else
    S:Select(self.player)
   end
  end); r:SetScript("OnEnter",function(self) if self.player then self:SetBackdropColor(.075,.082,.105,1); SGM.modules.Rows:Tooltip(self) end end); r:SetScript("OnLeave",function(self) GameTooltip_Hide(); if self.player~=S.selected then self:SetBackdropColor(.025,.03,.04,(i%2==0) and .98 or .88) end end); self.rows[i]=r
 end
 local scroll=CreateFrame("ScrollFrame","SpyGodModeStatisticsScroll",list,"FauxScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",0,-25); scroll:SetPoint("BOTTOMRIGHT",-2,2); scroll:SetScript("OnVerticalScroll",function(self,offset) FauxScrollFrame_OnVerticalScroll(self,offset,ROW_H,function() S:RenderRows() end) end); self.scroll=scroll

 local details=CreateFrame("Frame",nil,f,"BackdropTemplate"); details:SetPoint("TOPLEFT",553,-126); details:SetPoint("BOTTOMRIGHT",-10,72); backdrop(details,C.panel,{.14,.15,.18,1}); self.details=details
 local identity=CreateFrame("Frame",nil,details,"BackdropTemplate"); identity:SetPoint("TOPLEFT",5,-5); identity:SetPoint("TOPRIGHT",-5,-5); identity:SetHeight(66); identity:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"}); identity:SetBackdropColor(.038,.045,.06,1)
 self.detailTitle=text(identity,"GameFontNormalLarge","TOPLEFT",12,-11,"Select a player"); self.detailSub=text(identity,"GameFontDisableSmall","TOPLEFT",13,-36,"Choose an enemy to view intelligence"); self.detailSub:SetTextColor(.56,.6,.68)
 self.badge=text(identity,"GameFontNormal","TOPRIGHT",-12,-14,""); self.badge:SetJustifyH("RIGHT")
 section(details,"Identity",-82); section(details,"PvP Intelligence",-182); section(details,"Tracking",-302)
 self.detailLines={}
 local ys={-105,-126,-147,-205,-226,-247,-268,-325,-346,-367,-388}
 for i,y in ipairs(ys) do local line=text(details,"GameFontHighlightSmall","TOPLEFT",14,y,""); line:SetPoint("RIGHT",-14,0); line:SetJustifyH("LEFT"); self.detailLines[i]=line end

 local actions=CreateFrame("Frame",nil,f,"BackdropTemplate"); actions:SetPoint("BOTTOMLEFT",553,10); actions:SetPoint("BOTTOMRIGHT",-10,10); actions:SetHeight(56); backdrop(actions,C.panel2,{.12,.13,.16,1})
 -- Two clean action rows: the right panel is intentionally compact, so forcing five
 -- full-width buttons onto one line causes TIMELINE/DELETE to overlap at normal UI scales.
 local kos=makeButton(actions,"ADD TO KOS",96); kos:SetPoint("TOPLEFT",5,-4); kos:SetScript("OnClick",function() if S.selected then local e=SGM.db.kos[S.selected]; SGM.modules.KosDialogs:Prompt(S.selected,e~=nil) end end); self.kosButton=kos
 local watch=makeButton(actions,"WATCH",76); watch:SetPoint("LEFT",kos,"RIGHT",4,0); watch:SetScript("OnClick",function() local n=S.selected; if not n then return end; SGM.db.favorites=SGM.db.favorites or {}; SGM.db.favorites[n]=not SGM.db.favorites[n] or nil; S:Refresh() end); self.watchButton=watch
 local ignore=makeButton(actions,"IGNORE",76); ignore:SetPoint("LEFT",watch,"RIGHT",4,0); ignore:SetScript("OnClick",function() local n=S.selected; if not n then return end; if SGM.db.ignore[n] then SGM.modules.Roster:RemoveIgnore(n) else SGM.modules.Roster:SetIgnore(n) end; S:Refresh() end); self.ignoreButton=ignore
 local timeline=makeButton(actions,"TIMELINE",118); timeline:SetPoint("BOTTOMLEFT",5,4); timeline:SetScript("OnClick",function() if S.selected and SGM.modules.Intelligence then local t=SGM.db.timelines and SGM.db.timelines[S.selected] or {}; SGM:Print("Timeline: "..S.selected.." ("..#t.." events)"); for i=math.max(1,#t-5),#t do local e=t[i]; if e then SGM:Print(date("%m-%d %H:%M",e.time or time()).."  "..tostring(e.kind).."  "..tostring(e.detail or "")) end end end end); self.timelineButton=timeline
 local remove=makeButton(actions,"DELETE",92); remove:SetPoint("BOTTOMRIGHT",-5,4); remove:SetScript("OnClick",function() local n=S.selected; if not n then return end; SGM.db.players[n]=nil; SGM.db.kos[n]=nil; SGM.db.ignore[n]=nil; if SGM.db.favorites then SGM.db.favorites[n]=nil end; S.selected=nil; SGM.modules.Roster:Rebuild(); S:Refresh() end); self.removeButton=remove
 f:Hide()
end

function S:BuildList()
 wipe(self.filtered); local q=(self.searchText or ""):lower(); local now=time()
 for name,p in pairs(SGM.db.players or {}) do
  local ok=(q=="" or name:lower():find(q,1,true) or (p.guild and p.guild:lower():find(q,1,true)) or (p.zone and p.zone:lower():find(q,1,true)))
  if ok and self.classFilter then ok=p.class==self.classFilter end
  if ok then
   if self.filter=="KOS" then ok=SGM.db.kos[name]~=nil
   elseif self.filter=="WATCH" then ok=SGM.db.favorites and SGM.db.favorites[name]
   elseif self.filter=="GUILDKOS" then ok=p.guild and SGM.db.guildKos and SGM.db.guildKos[p.guild]~=nil
   elseif self.filter=="RECENT" then ok=now-(p.lastSeen or 0)<=3600
   elseif self.filter=="KILLERS" then ok=(p.losses or p.killedYou or 0)>0 end
  end
  if ok then self.filtered[#self.filtered+1]=name end
 end
 local key=self.sortKey; table.sort(self.filtered,function(a,b) local pa,pb=SGM.db.players[a] or {},SGM.db.players[b] or {}; if key=="NAME" then return a:lower()<b:lower() elseif key=="LEVEL" then return (pa.level or 0)>(pb.level or 0) elseif key=="SEEN" then return (pa.detections or 0)>(pb.detections or 0) elseif key=="WINS" then return (pa.wins or 0)>(pb.wins or 0) elseif key=="LOSSES" then return (pa.losses or 0)>(pb.losses or 0) else return (pa.lastSeen or 0)>(pb.lastSeen or 0) end end)
end

function S:Select(name) self.selected=name; self:Refresh() end
function S:RefreshDetails()
 local n=self.selected; local p=n and SGM.db.players[n]
 if not p then self.detailTitle:SetText("Select a player"); self.detailTitle:SetTextColor(1,.72,.16); self.detailSub:SetText("Choose an enemy to view intelligence"); self.badge:SetText(""); for _,v in ipairs(self.detailLines) do v:SetText("") end; for _,b in ipairs({self.kosButton,self.watchButton,self.ignoreButton,self.timelineButton,self.removeButton}) do b:Disable() end; return end
 for _,b in ipairs({self.kosButton,self.watchButton,self.ignoreButton,self.timelineButton,self.removeButton}) do b:Enable() end
 local r,g,b=SGM:ClassColor(p.class); self.detailTitle:SetText(n); self.detailTitle:SetTextColor(r,g,b); self.detailSub:SetText((p.guild and p.guild~="" and "<"..p.guild..">  -  " or "")..tostring(p.zone or "Unknown zone"))
 local kos=SGM.db.kos[n]; local label,score="LOW",0; if SGM.modules.Intelligence then label,score=SGM.modules.Intelligence:ThreatLabel(n,p) end; local tr,tg,tb=threatColor(label); self.badge:SetText("PVP THREAT  "..label.."  ["..score.."]"); self.badge:SetTextColor(tr,tg,tb)
 local tags=kos and kos.tags; if type(tags)=="table" then local a={}; for k,v in pairs(tags) do if type(k)=="number" and type(v)=="string" and v~="" then a[#a+1]=v elseif type(k)=="string" and v then a[#a+1]=k end end; table.sort(a); tags=#a>0 and table.concat(a,", ") or "-" else tags="-" end
 local vals={
  "Level  |cffffffff"..tostring(p.level or "??").."|r     Class  |cffffffff"..tostring(p.class or "Unknown").."|r     Race  |cffffffff"..tostring(p.race or "Unknown").."|r",
  "Guild  |cffffffff"..tostring(p.guild or "None").."|r",
  "First seen  |cffffffff"..(p.firstSeen and date("%Y-%m-%d %H:%M",p.firstSeen) or "Unknown").."|r",
  "Wins / Losses  |cff55e67a"..tostring(p.wins or 0).."|r / |cffff5555"..tostring(p.losses or 0).."|r     Encounters  |cffffffff"..tostring(p.detections or 0).."|r",
  "Targeting you  "..((SGM.modules.Intelligence and SGM.modules.Intelligence:IsTargeting(n)) and "|cffff4b45YES|r" or "|cff66dd88NO|r"),
  "Kill On Sight  "..(kos and "|cffff4b45YES|r" or "|cff66dd88NO|r").."     Watch  "..((SGM.db.favorites and SGM.db.favorites[n]) and "|cffffcc33YES|r" or "|cffaaaaaaNO|r"),
  "KoS tags  |cffffffff"..tostring(tags).."|r",
  "Last seen  |cffffffff"..(p.lastSeen and (SGM:Ago(p.lastSeen).." ago") or "Unknown").."|r",
  "Source  |cffffffff"..tostring(p.lastSightingSource or p.source or "local").."|r",
  "Timeline events  |cffffffff"..tostring((SGM.db.timelines and SGM.db.timelines[n] and #SGM.db.timelines[n]) or 0).."|r     Killed you  |cffffffff"..tostring(p.killedYou or p.losses or 0).."|r",
  "KoS reason  |cffffffff"..tostring(kos and kos.reason and kos.reason~="" and kos.reason or "-").."|r",
 }
 for i,line in ipairs(self.detailLines) do line:SetText(vals[i] or "") end
 self.kosButton:SetText(kos and "EDIT KOS" or "ADD TO KOS"); self.watchButton:SetText((SGM.db.favorites and SGM.db.favorites[n]) and "UNWATCH" or "WATCH"); self.ignoreButton:SetText(SGM.db.ignore[n] and "UNIGNORE" or "IGNORE")
end

function S:RenderRows()
 if InCombatLockdown() then self.pendingRefresh=true; return end
 if not self.frame or not self.scroll then return end
 local offset=FauxScrollFrame_GetOffset(self.scroll)
 -- Dragging the scrollbar can fire OnVerticalScroll many times per second.
 -- Keep that path cheap: only repaint the 17 visible rows and never rebuild/sort
 -- the complete player database here.
 for i=1,ROWS do
  local row=self.rows[i]
  local name=self.filtered[offset+i]
  if name then
   local p=SGM.db.players[name] or {}
   local rr,gg,bb=SGM:ClassColor(p.class)
   row.player=name; if SGM.modules.Rows then SGM.modules.Rows:ApplyTarget(row,name) end; row.name:SetText(name); row.name:SetTextColor(rr,gg,bb)
   local marker=""
   if SGM.db.kos[name] then marker="|cffff3838K|r" elseif SGM.db.favorites and SGM.db.favorites[name] then marker="|cffffcc33W|r" elseif SGM.db.ignore[name] then marker="|cff777777I|r" end
   row.marker:SetText(marker); row.level:SetText(tostring(p.level or "??")); row.seen:SetText(p.lastSeen and SGM:Ago(p.lastSeen) or "-"); row.wl:SetText((p.wins or 0).." / "..(p.losses or 0))
   local label="LOW"; if SGM.modules.Intelligence then label=select(1,SGM.modules.Intelligence:ThreatLabel(name,p)) end
   local tr,tg,tb=threatColor(label); row.threat:SetText(label); row.threat:SetTextColor(tr,tg,tb)
   if name==self.selected then row:SetBackdropColor(.09,.075,.035,1); row:SetBackdropBorderColor(1,.72,.16,1) else row:SetBackdropColor(.025,.03,.04,(i%2==0) and .98 or .88); row:SetBackdropBorderColor(.07,.08,.1,.8) end
   row:Show()
  else
   row.player=nil; row:Hide()
  end
 end
end

function S:Refresh()
 if InCombatLockdown() then self.pendingRefresh=true; return end
 if not self.frame then return end
 self:BuildList()
 local total=#self.filtered
 FauxScrollFrame_Update(self.scroll,total,ROWS,ROW_H)
 if FauxScrollFrame_GetOffset(self.scroll)>math.max(0,total-ROWS) then
  FauxScrollFrame_SetOffset(self.scroll,math.max(0,total-ROWS))
 end
 local allCount=0; for _ in pairs(SGM.db.players or {}) do allCount=allCount+1 end
 self.counter:SetText(total.." / "..tostring(allCount).." PLAYERS")
 for _,tab in ipairs(self.tabs or {}) do
  if tab.key==self.filter then tab:LockHighlight(); tab:GetFontString():SetTextColor(1,.72,.16) else tab:UnlockHighlight(); tab:GetFontString():SetTextColor(1,1,1) end
 end
 self:RenderRows()
 self:RefreshDetails()
end
function S:Show() if InCombatLockdown() then self.pendingShow=true; return end; self:Create(); self.frame:Show(); self:Refresh() end
function S:Toggle() if InCombatLockdown() then self.pendingToggle=true; self.restoreAfterCombat=false; return end; self:Create(); if self.frame:IsShown() then self.frame:Hide() else self:Show() end end
SGM:On("SGM_READY",function() S:Create() end); SGM:On("SGM_LIST_UPDATE",function() if S.frame and S.frame:IsShown() then S:Refresh() end end)

-- Secure statistics rows cannot change visibility or action attributes during combat.
local statsCombatDeferred=CreateFrame("Frame")
statsCombatDeferred:RegisterEvent("PLAYER_REGEN_ENABLED")
statsCombatDeferred:RegisterEvent("PLAYER_REGEN_DISABLED")
statsCombatDeferred:SetScript("OnEvent",function(_,event)
 if event=="PLAYER_REGEN_DISABLED" then
  -- Remember visibility; do not restore a window that was already closed.
  S.restoreAfterCombat = S.frame and S.frame:IsShown() or false
  if S.restoreAfterCombat and not InCombatLockdown() then S.frame:Hide() end
  return
 end
 if S.pendingHide then S.pendingHide=nil; S.restoreAfterCombat=false; if S.frame then S.frame:Hide() end end
 if S.restoreAfterCombat then
  S.restoreAfterCombat=false
  S.pendingShow=nil
  S.pendingToggle=nil
  S:Show()
 end
 if S.pendingToggle then S.pendingToggle=nil; S:Toggle()
 elseif S.pendingShow then S.pendingShow=nil; S:Show()
 elseif S.pendingRefresh then S.pendingRefresh=nil; if S.frame and S.frame:IsShown() then S:Refresh() end end
end)
