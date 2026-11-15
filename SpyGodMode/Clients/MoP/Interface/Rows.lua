local __sgmBuild = select(4, GetBuildInfo())
if __sgmBuild ~= 50503 and __sgmBuild ~= 50504 then return end
if not _G.SpyGodModeClientOK then return end
local _,SGM=...
local R={}; SGM:RegisterModule("Rows",R)

local function hidePopup()
 if R.popup then R.popup:Hide() end
end

function R:ShowMenu(items, anchor)
 hidePopup()
 local popup=R.popup
 if not popup then
  popup=CreateFrame("Frame","SpyGodModeActionPopup",UIParent,"BackdropTemplate")
  popup:SetFrameStrata("TOOLTIP")
  popup:SetClampedToScreen(true)
  popup:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
  popup:SetBackdropColor(.025,.03,.04,.98)
  popup:SetBackdropBorderColor(.55,.45,.18,1)
  popup.buttons={}
  popup:SetScript("OnHide",function(self)
   for _,b in ipairs(self.buttons) do b:Hide() end
  end)
  R.popup=popup
 end
 local width=210
 local y=-7
 local shown=0
 for i,item in ipairs(items or {}) do
  local b=popup.buttons[i]
  if not b then
   b=CreateFrame("Button",nil,popup)
   b:SetHeight(22)
   b.text=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
   b.text:SetPoint("LEFT",8,0); b.text:SetPoint("RIGHT",-8,0); b.text:SetJustifyH("LEFT")
   b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
   popup.buttons[i]=b
  end
  b:ClearAllPoints(); b:SetPoint("TOPLEFT",5,y); b:SetPoint("TOPRIGHT",-5,y)
  b.text:SetText(item.text or "")
  b:SetEnabled(not item.isTitle)
  if item.isTitle then b.text:SetTextColor(1,.76,.25) else b.text:SetTextColor(1,1,1) end
  b:SetScript("OnClick",function() hidePopup(); if item.func then item.func() end end)
  b:Show(); y=y-22; shown=shown+1
  local tw=b.text:GetStringWidth()+28; if tw>width then width=math.min(360,tw) end
 end
 popup:SetSize(width,shown*22+14)
 popup:ClearAllPoints()
 if anchor and anchor.GetCenter then
  popup:SetPoint("TOPLEFT",anchor,"BOTTOMLEFT",0,-2)
 else
  local x,y=GetCursorPosition(); local scale=UIParent:GetEffectiveScale(); x,y=x/scale,y/scale
  popup:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",x,y)
 end
 popup:Show()
end

function R:ResolveUnit(name)
 if not name or name=="" then return nil end
 local short=SGM:ShortName(name)
 local scanner=SGM.modules.Scanner
 local live=scanner and scanner.liveUnits and scanner.liveUnits[short]
 if live and UnitExists and SGM:SafeCall(UnitExists,live) and SGM:ShortName(SGM:SafeCall(UnitName,live))==short then return live end
 local candidates={"target","focus","mouseover","arena1","arena2","arena3","arena4","arena5"}
 for _,unit in ipairs(candidates) do
  if UnitExists and SGM:SafeCall(UnitExists,unit) and SGM:ShortName(SGM:SafeCall(UnitName,unit))==short then
   if scanner and scanner.liveUnits then scanner.liveUnits[short]=unit end
   return unit
  end
 end
 if scanner and scanner.nameplates then
  for unit in pairs(scanner.nameplates) do
   if UnitExists and SGM:SafeCall(UnitExists,unit) and SGM:ShortName(SGM:SafeCall(UnitName,unit))==short then scanner.liveUnits[short]=unit; return unit end
  end
 end
 return nil
end

local function SpyTargetMacro(name)
 local first,second=name:match("^([^%-]+)%-(.+)$")
 if not first then return "/targetexact "..name end
 return table.concat({
  "/cleartarget",
  "/targetexact "..first.." "..second,
  "/targetexact [noexists] "..name,
  "/targetexact [noexists] "..first,
  "/target [noexists] "..first.." "..second,
 },"\n")
end

function R:ApplyTarget(row,name)
 row.player=name
 row.targetName=name
 if InCombatLockdown and InCombatLockdown() then row.pendingTarget=name; return end
 local macro=name and name~="" and SpyTargetMacro(name) or "/targetexact nil"
 if row.appliedTargetMacro~=macro then
  row:SetAttribute("type1","macro")
  row:SetAttribute("unit",nil); row:SetAttribute("unit1",nil)
  row:SetAttribute("macrotext",macro); row:SetAttribute("macrotext1",macro)
  row.appliedTargetMacro=macro
 end
 row.pendingTarget=nil
end

function R:RefreshSecureTargets()
 for _,row in ipairs((SGM.modules.MainFrame and SGM.modules.MainFrame.rows) or {}) do
  if row and row.pendingTarget then self:ApplyTarget(row,row.pendingTarget) end
 end
end

function R:ToggleKosQuick(name)
 name=SGM:ShortName(name); if not name then return end
 if SGM.db.kos[name] then
  SGM.modules.Roster:RemoveKos(name)
  SGM:SafeSound("REMOVE")
  SGM:Print(name.." removed from Kill On Sight.")
 else
  SGM.modules.Roster:SetKos(name,"Shift-click")
  SGM:SafeSound("ADD")
  SGM:Print(name.." added to Kill On Sight.")
 end
end

function R:ToggleIgnoreQuick(name)
 name=SGM:ShortName(name); if not name then return end
 if SGM.db.ignore[name] then
  SGM.modules.Roster:RemoveIgnore(name)
  SGM:SafeSound("REMOVE")
  SGM:Print(name.." removed from Ignore.")
 else
  SGM.modules.Roster:SetIgnore(name)
  SGM:SafeSound("ADD")
  SGM:Print(name.." added to Ignore.")
 end
end

function R:Create(parent,index)
 local row=CreateFrame("Button",nil,parent,"SecureActionButtonTemplate,BackdropTemplate")
 row:EnableMouse(true)
 row:SetFrameLevel(parent:GetFrameLevel()+3)
 row:SetHeight(SGM.cfg.rowHeight)
 row:SetPoint("TOPLEFT",0,-(index-1)*(SGM.cfg.rowHeight+SGM.cfg.rowSpacing))
 row:SetPoint("TOPRIGHT",0,-(index-1)*(SGM.cfg.rowHeight+SGM.cfg.rowSpacing))
 row:RegisterForClicks("AnyDown","AnyUp")
 row:SetAttribute("type2",nil)
 row:SetAttribute("shift-type1","none")
 row:SetAttribute("ctrl-type1","none")
 row:SetAttribute("macrotext2",nil)
 row:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
 row:SetBackdropColor(unpack(index%2==0 and SGM.skin.row2 or SGM.skin.row1))
 row:SetBackdropBorderColor(.12,.13,.15,.75)

 row.left=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
 row.left:SetPoint("LEFT",4,0)
 row.left:SetPoint("RIGHT",-34,0)
 row.left:SetJustifyH("LEFT")
 row.left:SetWordWrap(false)

 row.right=row:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
 row.right:SetPoint("RIGHT",-4,0)

 row:SetScript("OnEnter",function(self)
  local c=self.classColor
  if c then
   self:SetBackdropColor(math.min(.26,c[1]*.20+.06),math.min(.26,c[2]*.20+.06),math.min(.26,c[3]*.20+.06),.98)
   self:SetBackdropBorderColor(c[1]*.6,c[2]*.6,c[3]*.6,.9)
  end
  R:Tooltip(self)
 end)
 row:SetScript("OnLeave",function(self)
  self:SetBackdropColor(unpack(index%2==0 and SGM.skin.row2 or SGM.skin.row1))
  self:SetBackdropBorderColor(.12,.13,.15,.75)
  GameTooltip:Hide()
 end)
 function R:OpenPlayerMenu(self)
  if not self.player then return end
  local name=self.player
  local entry=SGM.db.kos[name]
  local p=SGM.db.players[name] or {}
  local menu={{text=name,isTitle=true,notCheckable=true}}

  if entry then
   menu[#menu+1]={text="Edit Kill On Sight reason...",notCheckable=true,func=function()
    SGM.modules.KosDialogs:Prompt(name,true)
   end}
   menu[#menu+1]={text="Remove from Kill On Sight",notCheckable=true,func=function()
    SGM.modules.KosDialogs:Remove(name)
   end}
  else
   menu[#menu+1]={text="Add to Kill On Sight...",notCheckable=true,func=function()
    SGM.modules.KosDialogs:Prompt(name,false)
   end}
  end

  menu[#menu+1]={text=SGM.db.ignore[name] and "Remove from Ignore" or "Add to Ignore",notCheckable=true,func=function()
   if SGM.db.ignore[name] then
    SGM.modules.Roster:RemoveIgnore(name)
    SGM:SafeSound("REMOVE")
   else
    SGM.modules.Roster:SetIgnore(name)
    SGM:SafeSound("ADD")
   end
  end}

  if p.guild and p.guild~="" then
   local guild=p.guild
   menu[#menu+1]={text=SGM.db.guildKos[guild] and ("Remove guild from KoS: "..guild) or ("Add guild to KoS: "..guild),notCheckable=true,func=function()
    if SGM.db.guildKos[guild] then
     SGM.db.guildKos[guild]=nil
     SGM:SafeSound("REMOVE")
    else
     SGM.db.guildKos[guild]={added=time(),reason="Enemy guild"}
     SGM:SafeSound("ADD")
    end
    SGM.modules.Roster:Rebuild()
   end}
  end


  menu[#menu+1]={text=SGM.db.favorites and SGM.db.favorites[name] and "Remove from Watch/Favorites" or "Add to Watch/Favorites",notCheckable=true,func=function()
   SGM.db.favorites=SGM.db.favorites or {}; if SGM.db.favorites[name] then SGM.db.favorites[name]=nil else SGM.db.favorites[name]=true end; SGM.modules.Roster:Rebuild()
  end}
  local tagChoices={"Camper","Ganker","Dangerous","Healer","Guild Rival"}
  if SGM.db.kos[name] then
   for _,tag in ipairs(tagChoices) do
    menu[#menu+1]={text="Tag: "..tag,notCheckable=true,func=function()
     local e=SGM.db.kos[name]; e.tags=type(e.tags)=="table" and e.tags or {}; local found
     for i,v in ipairs(e.tags) do if v==tag then table.remove(e.tags,i); found=true; break end end
     if not found then e.tags[#e.tags+1]=tag end
    end}
   end
  end
  menu[#menu+1]={text="Show encounter timeline",notCheckable=true,func=function()
   local t=SGM.db.timelines and SGM.db.timelines[name] or {}; SGM:Print("Timeline for "..name.." ("..#t.." events)")
   local first=math.max(1,#t-7); for i=first,#t do local e=t[i]; SGM:Print(date("%m-%d %H:%M",e.time or time()).." - "..tostring(e.kind).." - "..tostring(e.detail or e.zone or "")) end
  end}

  menu[#menu+1]={text="Cancel",notCheckable=true}
  R:ShowMenu(menu,self)
 end

 -- Secure left-click targeting remains on button-down. Right-click is handled
 -- separately on mouse-up so the secure action button never swallows the menu.
 row:SetScript("PreClick",function(self,button,down)
  if button=="LeftButton" and IsShiftKeyDown and IsShiftKeyDown() then
   self._sgmShiftKos=true
   self._sgmCtrlIgnore=nil
  elseif button=="LeftButton" and IsControlKeyDown and IsControlKeyDown() then
   self._sgmShiftKos=nil
   self._sgmCtrlIgnore=true
  else
   self._sgmShiftKos=nil
   self._sgmCtrlIgnore=nil
  end
 end)
 row:SetScript("PostClick",function(self,button,down)
  if down then return end
  if button=="RightButton" then
   R:OpenPlayerMenu(self)
  elseif button=="LeftButton" and self._sgmShiftKos and self.player then
   self._sgmShiftKos=nil
   R:ToggleKosQuick(self.player)
  elseif button=="LeftButton" and self._sgmCtrlIgnore and self.player then
   self._sgmCtrlIgnore=nil
   R:ToggleIgnoreQuick(self.player)
  end
 end)
 return row
end

function R:Tooltip(row)
 local n=row.player
 local p=n and SGM.db.players[n]
 if not p then return end
 local r,g,b=SGM:ClassColor(p.class)
 GameTooltip:SetOwner(row,"ANCHOR_RIGHT")
 GameTooltip:AddLine(n,r,g,b)
 if p.level then GameTooltip:AddDoubleLine("Level",p.level,1,1,1,1,1,1) end
 if p.race or p.class then GameTooltip:AddLine((p.race or "").." "..(p.class or ""),.82,.82,.82) end
 if p.guild then GameTooltip:AddLine("<"..p.guild..">",.45,1,.45) end
 if p.zone then GameTooltip:AddLine(p.zone,.72,.72,.72) end
 if SGM.cfg.tooltipWinLoss then GameTooltip:AddDoubleLine("Wins / Losses",(p.wins or 0).." / "..(p.losses or 0),1,1,1,1,1,1) end
 if SGM.cfg.tooltipReason and SGM.db.kos[n] and SGM.db.kos[n].reason~="" then GameTooltip:AddLine("KoS: "..SGM.db.kos[n].reason,1,.25,.25,true) end
 if SGM.cfg.tooltipThreat and SGM.modules.Intelligence then local l,sc=SGM.modules.Intelligence:ThreatLabel(n,p); GameTooltip:AddDoubleLine("PvP Threat",l.." ("..sc..")",1,1,1,1,.55,.2) end
 if SGM.modules.Intelligence and SGM.modules.Intelligence:IsTargeting(n) then GameTooltip:AddLine("TARGETING YOU",1,.15,.15) end
 if p.lastSightingSource and p.lastSightingSource~="unit" and p.lastSightingSource~="combat" then GameTooltip:AddDoubleLine("Sighting source",p.lastSightingSource,1,1,1,.7,.85,1) end
 if SGM.db.favorites and SGM.db.favorites[n] then GameTooltip:AddLine("Watch/Favorite",1,.82,.2) end
 local ke=SGM.db.kos[n]; if ke and type(ke.tags)=="table" and #ke.tags>0 then GameTooltip:AddLine("Tags: "..table.concat(ke.tags,", "),.9,.7,.3,true) end
 if SGM.cfg.tooltipHistory and SGM.db.timelines and SGM.db.timelines[n] then GameTooltip:AddDoubleLine("Timeline events",#SGM.db.timelines[n],1,1,1,.8,.8,.8) end
 if SGM.cfg.tooltipLastSeen then GameTooltip:AddDoubleLine("Last seen",SGM:Ago(p.lastSeen).." ago",1,1,1,.8,.8,.8) end
  GameTooltip:AddLine("Left-click: Target player",.35,1,.35)
 GameTooltip:AddLine("Shift + Left-click: Add/remove KoS",1,.82,.2)
 GameTooltip:AddLine("Ctrl + Left-click: Add/remove Ignore",.75,.85,1)
 GameTooltip:AddLine("Right-click: Player options",.75,.75,.75)
 GameTooltip:Show()
end

SGM:RegisterEvent("PLAYER_REGEN_ENABLED")
SGM:On("PLAYER_REGEN_ENABLED",function() R:RefreshSecureTargets() end)
