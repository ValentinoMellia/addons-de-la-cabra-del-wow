local __sgmBuild = select(4, GetBuildInfo())
if __sgmBuild ~= 11508 and __sgmBuild ~= 11509 then return end
if not _G.SpyGodModeClientOK then return end
local _,SGM=...
local W={rows={},views={"NEARBY","HOUR","IGNORE","KOS"},labels={NEARBY="Nearby",HOUR="Last Hour",IGNORE="Ignore",KOS="Kill On Sight",STATS="Statistics"}}
SGM:RegisterModule("MainFrame",W)

local TOOLBAR_H=18
local TITLE_H=18
local BODY_TOP=TOOLBAR_H+TITLE_H+2
local BASE_H=BODY_TOP+4

local function combatLocked()
 return InCombatLockdown and InCombatLockdown()
end

local function tip(owner,title,text)
 GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
 GameTooltip:AddLine(title,1,.82,0)
 if text then GameTooltip:AddLine(text,.9,.9,.9,true) end
 GameTooltip:Show()
end

local function iconButton(parent,w,h,normal,highlight)
 local b=CreateFrame("Button",nil,parent)
 b:SetSize(w,h)
 if normal then b:SetNormalTexture(normal) end
 if highlight then b:SetHighlightTexture(highlight,"ADD") end
 return b
end

local function stopMove()
 local f=W.frame
 if not f or combatLocked() then return end
 f:StopMovingOrSizing()
 if C_Timer and C_Timer.After then C_Timer.After(0,function() W:SavePosition() end) else W:SavePosition() end
end

local function makeDragArea(area)
 area:EnableMouse(true)
 area:SetScript("OnMouseDown",function(_,button)
  if button=="LeftButton" and not SGM.cfg.locked and W.frame and not combatLocked() then W.frame:StartMoving() end
 end)
 area:SetScript("OnMouseUp",stopMove)
end


function W:SetVisible(show)
 if not self.frame then return false end
 show=show and true or false
 SGM.cfg.visible=show
 if show then
  -- Explicit show overrides the previous automatic hide and restarts the empty delay.
  self.autoHidden=false
  self.collapsed=false
  self.emptySince=GetTime()
 end
 if combatLocked() then
  self.pendingVisibility=show
  return false
 end
 self.pendingVisibility=nil
 if show then self.frame:Show() else self.frame:Hide() end
 if self.UpdateHUD then self:UpdateHUD() end
 return true
end

function W:ResetPosition()
 SGM.cfg.x,SGM.cfg.y=230,520
 if not self.frame then return true end
 if combatLocked() then
  self.pendingReset=true
  return false
 end
 self.pendingReset=nil
 self.frame:ClearAllPoints()
 self.frame:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",230,520)
 return true
end

function W:UpdateLock()
 if not self.lock then return end
 self.lock:SetText(SGM.cfg.locked and "L" or "U")
 self.lock:SetNormalFontObject(SGM.cfg.locked and "GameFontDisableSmall" or "GameFontNormalSmall")
end

function W:SavePosition()
 local f=self.frame
 if not f or not SGM.cfg then return end
 local point,_,relativePoint,x,y=f:GetPoint(1)
 if point then
  SGM.cfg.positionPoint=point
  SGM.cfg.relativePoint=relativePoint or point
  SGM.cfg.x=math.floor((x or 0)+.5)
  SGM.cfg.y=math.floor((y or 0)+.5)
 end
end

function W:Pulse()
 if not self.frame or not SGM.cfg.animations or combatLocked() then return end
 local start=GetTime(); self.frame:SetScript("OnUpdate",function(f)
  local d=GetTime()-start
  if d>=0.8 then f:SetBackdropBorderColor(.42,.36,.18,1); f:SetScript("OnUpdate",nil); return end
  local v=.35+.65*math.abs(math.sin(d*10)); f:SetBackdropBorderColor(1,.25+.55*v,.05,1)
 end)
end
function W:UpdateHUD()
 if not self.hud then return end
 local names=SGM.modules.Roster and SGM.modules.Roster:Names("NEARBY") or {}
 local stealth,kos=0,0
 for _,n in ipairs(names) do local p=SGM.db.players[n] or {}; if p.class=="ROGUE" or p.class=="DRUID" then stealth=stealth+1 end; if SGM.db.kos[n] then kos=kos+1 end end
 self.hud.text:SetText("Eye "..#names.."   Stealth "..stealth.."   KoS "..kos)
 if self.autoHidden or (self.frame and not self.frame:IsShown()) then
  self.hud:Hide()
 elseif SGM.cfg.compactHUD then
  self.hud:Show()
 else
  self.hud:Hide()
 end
end
function W:HandleEmpty(count)
 if count>0 then self.emptySince=nil; self.wasEmpty=false; self.autoHidden=false; if self.collapsed then self.collapsed=false end; return end
 if not self.emptySince then self.emptySince=GetTime(); self.wasEmpty=true end
 if not SGM.cfg.autoHide then return end
 if GetTime()-self.emptySince < (SGM.cfg.autoHideDelay or 30) then return end
 if SGM.cfg.autoCollapse then
  self.collapsed=true
  self.autoHidden=false
 else
  self.autoHidden=true
  if self.hud then self.hud:Hide() end
  if self.frame then self.frame:Hide(); SGM.cfg.visible=false end
 end
end


local quickOptions={
 {"Auto-hide when empty","autoHide"},
 {"Collapse instead of hide","autoCollapse"},
 {"Detection in enemy cities","enemyCityMode"},
 {"Show Mini Tracker","compactHUD"},
 {"Watch for new enemies","watchMode"},
}
local soundNames={CLASSIC="Classic Spy",STEALTH="Stealth Hunter",ALARM="Danger Alarm",SILENT="Silent"}

function W:UpdateQuickMenu()
 if not self.quickMenu then return end
 for _,entry in ipairs(self.quickMenu.checks or {}) do entry.check:SetChecked(SGM.cfg[entry.key] and true or false) end
 if self.quickMenu.delay then self.quickMenu.delay:SetText("Hide Delay: "..tostring(SGM.cfg.autoHideDelay or 30).." seconds") end
 if self.quickMenu.profile then self.quickMenu.profile:SetText("Enemy Sound: "..(soundNames[SGM.cfg.soundProfile or "CLASSIC"] or "Classic Spy")) end
end

local function saveQuickMenuPosition(q)
 if not q or not SGM.cfg then return end
 local point,_,relativePoint,x,y=q:GetPoint(1)
 if point then
  SGM.cfg.quickMenuPoint=point
  SGM.cfg.quickMenuRelativePoint=relativePoint or point
  SGM.cfg.quickMenuX=math.floor((x or 0)+.5)
  SGM.cfg.quickMenuY=math.floor((y or 0)+.5)
 end
end

function W:PositionQuickMenu()
 local q=self.quickMenu
 if not q or not self.frame then return end
 q:ClearAllPoints()
 if SGM.cfg.quickMenuPoint then
  q:SetPoint(SGM.cfg.quickMenuPoint,UIParent,SGM.cfg.quickMenuRelativePoint or SGM.cfg.quickMenuPoint,tonumber(SGM.cfg.quickMenuX) or 0,tonumber(SGM.cfg.quickMenuY) or 0)
  return
 end
 local frameRight=self.frame:GetRight() or 0
 local availableRight=(UIParent:GetWidth() or 0)-frameRight
 if availableRight >= q:GetWidth()+8 then
  q:SetPoint("TOPLEFT",self.frame,"TOPRIGHT",6,0)
 else
  q:SetPoint("TOPRIGHT",self.frame,"TOPLEFT",-6,0)
 end
end

function W:CreateQuickMenu()
 if self.quickMenu then return end
 local q=CreateFrame("Frame","SpyGodMode_QuickMenu",UIParent,"BackdropTemplate")
 q:SetSize(258,252); q:SetFrameStrata("DIALOG"); q:SetClampedToScreen(true); q:SetMovable(true); q:EnableMouse(true)
 q:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
 q:SetBackdropColor(.018,.022,.028,.98); q:SetBackdropBorderColor(.52,.42,.18,1); q:Hide(); q.checks={}
 local drag=CreateFrame("Frame",nil,q)
 drag:SetPoint("TOPLEFT",6,-5); drag:SetPoint("TOPRIGHT",-28,-5); drag:SetHeight(28); drag:EnableMouse(true)
 drag:SetScript("OnMouseDown",function(_,button) if button=="LeftButton" then q:StartMoving() end end)
 drag:SetScript("OnMouseUp",function() q:StopMovingOrSizing(); saveQuickMenuPosition(q) end)
 local title=q:CreateFontString(nil,"OVERLAY","GameFontNormal"); title:SetPoint("TOPLEFT",12,-11); title:SetText("Spy God Mode - Quick Settings"); title:SetTextColor(1,.78,.25)
 local close=CreateFrame("Button",nil,q,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",3,3)
 local y=-38
 for _,opt in ipairs(quickOptions) do
  local key=opt[2]
  local check=CreateFrame("CheckButton",nil,q,"UICheckButtonTemplate"); check:SetPoint("TOPLEFT",10,y)
  local text=q:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); text:SetPoint("LEFT",check,"RIGHT",1,0); text:SetText(opt[1])
  check:SetScript("OnClick",function(self)
   SGM.cfg[key]=self:GetChecked() and true or false
   if key=="autoHide" and not SGM.cfg.autoHide then W.emptySince=nil end
   W:Refresh(); W:UpdateQuickMenu()
  end)
  q.checks[#q.checks+1]={check=check,key=key}; y=y-24
 end
 local delay=CreateFrame("Button",nil,q,"UIPanelButtonTemplate"); delay:SetSize(222,22); delay:SetPoint("TOPLEFT",18,y-2)
 delay:SetScript("OnClick",function()
  local values={5,10,15,20,30,45,60,90,120}; local cur=SGM.cfg.autoHideDelay or 30; local idx=1
  for i,v in ipairs(values) do if v==cur then idx=i break end end
  SGM.cfg.autoHideDelay=values[(idx%#values)+1]; W:UpdateQuickMenu()
 end); q.delay=delay; y=y-30
 local profile=CreateFrame("Button",nil,q,"UIPanelButtonTemplate"); profile:SetSize(156,22); profile:SetPoint("TOPLEFT",18,y-2)
 profile:SetScript("OnClick",function()
  local values={"CLASSIC","STEALTH","ALARM","SILENT"}; local cur=SGM.cfg.soundProfile or "CLASSIC"; local idx=1
  for i,v in ipairs(values) do if v==cur then idx=i break end end
  SGM.cfg.soundProfile=values[(idx%#values)+1]; W:UpdateQuickMenu()
 end); q.profile=profile
 local test=CreateFrame("Button",nil,q,"UIPanelButtonTemplate"); test:SetSize(62,22); test:SetPoint("LEFT",profile,"RIGHT",4,0); test:SetText("Test")
 test:SetScript("OnClick",function() if SGM.cfg.soundProfile=="SILENT" then SGM:Print("Sound profile is Silent.") else SGM:SafeSound("NEARBY") end end)
 y=y-30
 local full=CreateFrame("Button",nil,q,"UIPanelButtonTemplate"); full:SetSize(222,22); full:SetPoint("TOPLEFT",18,y-2); full:SetText("Open Full Options")
 full:SetScript("OnClick",function() if SGM.modules.Options then SGM.modules.Options:Open() end end)
 self.quickMenu=q
end

function W:ToggleQuickMenu()
 self:CreateQuickMenu()
 if self.quickMenu:IsShown() then self.quickMenu:Hide() else
  self:PositionQuickMenu()
  self:UpdateQuickMenu(); self.quickMenu:Show()
 end
end

function W:Create()
 if self.frame then return end
 if SGM.cfg.compactLayoutVersion ~= 6 then
  SGM.cfg.width=185
  SGM.cfg.rowHeight=15
  SGM.cfg.rowSpacing=1
  SGM.cfg.height=nil
  SGM.cfg.userResized=nil
  SGM.cfg.compactLayoutVersion=6
 end

 local f=CreateFrame("Frame","SpyGodMode_MainFrame",UIParent,"BackdropTemplate")
 f:SetSize(SGM.cfg.width or 185,BASE_H)
 f:SetClampedToScreen(SGM.cfg.clamp)
 f:SetMovable(true)
 f:EnableMouse(true)
 if f.SetResizable then f:SetResizable(true) end
 if f.SetResizeBounds then f:SetResizeBounds(185,BASE_H,420,600) elseif f.SetMinResize then f:SetMinResize(185,BASE_H) end
 f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=10,insets={left=2,right=2,top=2,bottom=2}})
 f:SetBackdropColor(.018,.022,.028,SGM.cfg.bgAlpha or .94)
 f:SetBackdropBorderColor(.42,.36,.18,1)
 self.frame=f
 makeDragArea(f)
 local hud=CreateFrame("Frame","SpyGodMode_CompactHUD",UIParent,"BackdropTemplate")
 hud:SetSize(190,24); hud:SetPoint("TOP",f,"BOTTOM",0,-4); hud:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=10,insets={left=2,right=2,top=2,bottom=2}}); hud:SetBackdropColor(.02,.025,.03,.92); hud:SetBackdropBorderColor(.42,.36,.18,1)
 hud.text=hud:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); hud.text:SetPoint("CENTER"); hud.text:SetTextColor(1,.78,.25); hud:EnableMouse(true); hud:SetMovable(true); hud:SetScript("OnMouseDown",function(self,b) if b=="LeftButton" and not SGM.cfg.locked then self:StartMoving() end end); hud:SetScript("OnMouseUp",function(self) self:StopMovingOrSizing() end); self.hud=hud


 local toolbar=CreateFrame("Frame",nil,f,"BackdropTemplate")
 toolbar:SetPoint("TOPLEFT",2,-2); toolbar:SetPoint("TOPRIGHT",-2,-2); toolbar:SetHeight(TOOLBAR_H)
 toolbar:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
 toolbar:SetBackdropColor(.025,.03,.038,.98)
 toolbar:SetFrameLevel(f:GetFrameLevel()+3)
 self.toolbar=toolbar
 makeDragArea(toolbar)

 local titleBar=CreateFrame("Frame",nil,f,"BackdropTemplate")
 titleBar:SetPoint("TOPLEFT",2,-TOOLBAR_H-2); titleBar:SetPoint("TOPRIGHT",-2,-TOOLBAR_H-2); titleBar:SetHeight(TITLE_H)
 titleBar:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
 titleBar:SetBackdropColor(.04,.046,.055,.98)
 titleBar:SetBackdropBorderColor(.22,.20,.13,1)
 titleBar:SetFrameLevel(f:GetFrameLevel()+2)
 makeDragArea(titleBar)
 self.titleBar=titleBar

 self.title=titleBar:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
 self.title:SetPoint("LEFT",6,0)
 self.title:SetPoint("RIGHT",-6,0)
 self.title:SetJustifyH("LEFT")
 self.title:SetWordWrap(false)
 self.title:SetTextColor(1,.75,.24)

 local close=iconButton(toolbar,16,16,"Interface\\Buttons\\UI-Panel-MinimizeButton-Up","Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
 close:SetFrameLevel(toolbar:GetFrameLevel()+3)
 close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
 close:SetPoint("RIGHT",-1,0)
 close:SetScript("OnClick",function() W:SetVisible(false) end)
 close:SetScript("OnEnter",function(self) tip(self,"Close","Hide the Spy God Mode window.") end)
 close:SetScript("OnLeave",GameTooltip_Hide)
 self.close=close

 self.next=iconButton(toolbar,15,15,"Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up","Interface\\Buttons\\UI-Common-MouseHilight")
 self.next:SetFrameLevel(toolbar:GetFrameLevel()+3)
 self.next:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
 self.next:SetPoint("RIGHT",close,"LEFT",0,0)
 self.next:SetScript("OnClick",function() W:Cycle(1) end)
 self.next:SetScript("OnEnter",function(self) tip(self,"Next list","Go to the next list.") end)
 self.next:SetScript("OnLeave",GameTooltip_Hide)

 self.prev=iconButton(toolbar,15,15,"Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up","Interface\\Buttons\\UI-Common-MouseHilight")
 self.prev:SetFrameLevel(toolbar:GetFrameLevel()+3)
 self.prev:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
 self.prev:SetPoint("RIGHT",self.next,"LEFT",0,0)
 self.prev:SetScript("OnClick",function() W:Cycle(-1) end)
 self.prev:SetScript("OnEnter",function(self) tip(self,"Previous list","Go to the previous list.") end)
 self.prev:SetScript("OnLeave",GameTooltip_Hide)

 self.clear=iconButton(toolbar,15,15,"Interface\\Buttons\\UI-GroupLoot-Pass-Up","Interface\\Buttons\\UI-Common-MouseHilight")
 self.clear:SetFrameLevel(toolbar:GetFrameLevel()+3)
 self.clear:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Down")
 self.clear:SetPoint("RIGHT",self.prev,"LEFT",0,0)
 self.clear:SetScript("OnClick",function() if SGM.cfg.currentView=="NEARBY" then SGM.modules.Roster:ClearNearby() end end)
 self.clear:SetScript("OnEnter",function(self) tip(self,"Clear","Clear the nearby list.") end)
 self.clear:SetScript("OnLeave",GameTooltip_Hide)

 self.lock=CreateFrame("Button",nil,toolbar,"UIPanelButtonTemplate")
 self.lock:SetSize(18,16)
 self.lock:SetFrameLevel(toolbar:GetFrameLevel()+4)
 self.lock:SetPoint("RIGHT",self.clear,"LEFT",-1,0)
 self.lock:SetScript("OnClick",function()
  SGM.cfg.locked=not SGM.cfg.locked
  W:UpdateLock()
 end)
 self.lock:SetScript("OnEnter",function(self) tip(self,SGM.cfg.locked and "Unlock windows" or "Lock windows","Controls movement of the Nearby and Statistics windows.") end)
 self.lock:SetScript("OnLeave",GameTooltip_Hide)

 self.stats=iconButton(toolbar,14,14,"Interface\\Buttons\\UI-GuildButton-PublicNote-Up","Interface\\Buttons\\UI-Common-MouseHilight")
 self.stats:SetFrameLevel(toolbar:GetFrameLevel()+3)
 self.stats:SetPoint("RIGHT",self.lock,"LEFT",-1,0)
 self.stats:SetScript("OnClick",function() if SGM.modules.Statistics then SGM.modules.Statistics:Toggle() end end)
 self.stats:SetScript("OnEnter",function(self) tip(self,"Statistics","Show encounter statistics.") end)
 self.stats:SetScript("OnLeave",GameTooltip_Hide)

 self.settingsButton=iconButton(toolbar,14,14,"Interface\\Buttons\\UI-OptionsButton","Interface\\Buttons\\UI-Common-MouseHilight")
 self.settingsButton:SetFrameLevel(toolbar:GetFrameLevel()+3)
 self.settingsButton:SetPoint("RIGHT",self.stats,"LEFT",-1,0)
 self.settingsButton:SetScript("OnClick",function() W:ToggleQuickMenu() end)
 self.settingsButton:SetScript("OnEnter",function(self) tip(self,"Quick Settings","Turn every new feature on or off without opening the full options panel.") end)
 self.settingsButton:SetScript("OnLeave",GameTooltip_Hide)

 self.title:ClearAllPoints()
 self.title:SetPoint("LEFT",6,0)
 self.title:SetPoint("RIGHT",-6,0)

 self.brand=toolbar:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
 self.brand:SetPoint("LEFT",5,0)
 self.brand:SetText("SGM")
 self.brand:SetTextColor(.82,.68,.26)

 -- Pack every toolbar control from left to right. At minimum width, the frame border ends immediately after Close.
 -- so the smallest window has no empty gap and the count can never slide under SGM.
 self.count=toolbar:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
 self.count:SetPoint("LEFT",self.brand,"RIGHT",3,0)
 self.count:SetWidth(18)
 self.count:SetJustifyH("LEFT")
 self.count:SetWordWrap(false)
 self.count:SetTextColor(.72,.76,.82)

 self.settingsButton:ClearAllPoints()
 self.settingsButton:SetPoint("LEFT",self.count,"RIGHT",1,0)
 self.stats:ClearAllPoints()
 self.stats:SetPoint("LEFT",self.settingsButton,"RIGHT",1,0)
 self.lock:ClearAllPoints()
 self.lock:SetPoint("LEFT",self.stats,"RIGHT",1,0)
 self.clear:ClearAllPoints()
 self.clear:SetPoint("LEFT",self.lock,"RIGHT",1,0)
 self.prev:ClearAllPoints()
 self.prev:SetPoint("LEFT",self.clear,"RIGHT",0,0)
 self.next:ClearAllPoints()
 self.next:SetPoint("LEFT",self.prev,"RIGHT",0,0)
 self.close:ClearAllPoints()
 self.close:SetPoint("LEFT",self.next,"RIGHT",0,0)

 -- The minimum width is calculated from the real packed toolbar width.
 -- This keeps every control inside the frame and makes the right border end directly after X.
 local packedMinWidth=math.ceil(5 + self.brand:GetStringWidth() + 3 + 18 + 1 + 14 + 1 + 14 + 1 + 18 + 1 + 15 + 15 + 15 + 16 + 4)
 self.minWidth=packedMinWidth
 if f.SetResizeBounds then f:SetResizeBounds(packedMinWidth,BASE_H,420,600) elseif f.SetMinResize then f:SetMinResize(packedMinWidth,BASE_H) end
 if f:GetWidth()<packedMinWidth then f:SetWidth(packedMinWidth) end
 if not SGM.cfg.width or SGM.cfg.width<packedMinWidth then SGM.cfg.width=packedMinWidth end

 local body=CreateFrame("Frame",nil,f)
 body:SetFrameLevel(f:GetFrameLevel()+1)
 body:SetPoint("TOPLEFT",3,-BODY_TOP)
 body:SetPoint("BOTTOMRIGHT",-3,3)
 self.body=body
 makeDragArea(body)

 local grip=CreateFrame("Button",nil,f)
 grip:SetFrameLevel(f:GetFrameLevel()+6)
 grip:SetSize(16,16)
 grip:SetPoint("BOTTOMRIGHT",-1,1)
 grip:SetAlpha(.55)
 grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
 grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
 grip:SetScript("OnEnter",function(self) self:SetAlpha(1) end)
 grip:SetScript("OnLeave",function(self) self:SetAlpha(.55) end)
 grip:SetScript("OnMouseDown",function(_,button)
  if button=="LeftButton" and not SGM.cfg.locked and f.StartSizing and not combatLocked() then f:StartSizing("BOTTOMRIGHT") end
 end)
 grip:SetScript("OnMouseUp",function()
  if combatLocked() then return end
  f:StopMovingOrSizing()
  SGM.cfg.width=math.max(145,math.floor(f:GetWidth()+.5))
  W:Refresh()
 end)
 self.grip=grip

 f:ClearAllPoints()
 local point=SGM.cfg.positionPoint or "BOTTOMLEFT"
 local relativePoint=SGM.cfg.relativePoint or point
 f:SetPoint(point,UIParent,relativePoint,tonumber(SGM.cfg.x) or 230,tonumber(SGM.cfg.y) or 520)
 f:SetScript("OnHide",function() W:SavePosition() end)
 for i=1,SGM.cfg.maxRows do self.rows[i]=SGM.modules.Rows:Create(body,i) end
 if SGM.cfg.visible==false then f:Hide() else f:Show() end
 local function scrollRows(_,delta)
  if combatLocked() then return end
  local list=SGM.modules.Roster:Names(SGM.cfg.currentView or "NEARBY")
  local limit=math.max(1,math.min(SGM.cfg.maxRows or 30,tonumber(SGM.cfg.visibleRows) or 10))
  local maxOffset=math.max(0,#list-limit)
  local nextOffset=math.max(0,math.min(maxOffset,(W.scrollOffset or 0)-(delta>0 and 1 or -1)))
  if nextOffset~=(W.scrollOffset or 0) then W.scrollOffset=nextOffset; W:Refresh() end
 end
 f:EnableMouseWheel(true)
 f:SetScript("OnMouseWheel",scrollRows)
 for _,row in ipairs(self.rows) do
  row:EnableMouseWheel(true)
  row:SetScript("OnMouseWheel",scrollRows)
 end
 self:UpdateLock()
 self:Refresh()
end

function W:Cycle(dir)
 local current=SGM.cfg.currentView
 local index=1
 for i,v in ipairs(self.views) do if v==current then index=i break end end
 index=((index-1+dir)%#self.views)+1
 SGM.cfg.currentView=self.views[index]
 self.scrollOffset=0
 self:Refresh()
end

function W:Refresh()
 if not self.frame then return end
 if combatLocked() then
  self.pendingRefresh=true
  self:UpdateHUD()
  return
 end
 self.pendingRefresh=nil
 local view=SGM.cfg.currentView or "NEARBY"
 local names=SGM.modules.Roster:Names(view)
 local limit=math.max(1,math.min(SGM.cfg.maxRows or 30,tonumber(SGM.cfg.visibleRows) or 10))
 local visible=math.min(#names,limit)
 local maxOffset=math.max(0,#names-visible)
 self.scrollOffset=math.max(0,math.min(self.scrollOffset or 0,maxOffset))
 local status=""
 if not SGM:CanDetectHere() then status=" |cffaaaaaa[Detection paused: Sanctuary]|r"
 elseif (SGM.isMidnight or SGM.isForever) and GetCVarBool and not GetCVarBool("nameplateShowEnemies") then status=" |cffffaa00[Enemy nameplates OFF]|r" end
 self.title:SetText("Spy God Mode - "..(self.labels[view] or view)..status)
 self.count:SetText(tostring(#names))
 self:HandleEmpty(#names)
 self:UpdateHUD()
 self.frame:SetWidth(math.max(self.minWidth or 185,SGM.cfg.width or (self.minWidth or 185)))
 -- Height always follows the active list. Manual resizing changes width only.
 self.frame:SetHeight(self.collapsed and BASE_H or (BASE_H + visible*(SGM.cfg.rowHeight+SGM.cfg.rowSpacing)))

 for _,row in ipairs(self.rows) do row:Hide(); SGM.modules.Rows:ApplyTarget(row,nil) end
 for i=1,visible do
  local n=names[i+(self.scrollOffset or 0)]
  local p=SGM.db.players[n] or {}
  local row=self.rows[i]
  local r,g,b=SGM:ClassColor(p.class)
  local level=(p.level and p.level>0) and tostring(p.level) or "??"
  local kosEntry=SGM.db.kos[n]
  local guildEntry=p.guild and SGM.db.guildKos[p.guild]
  local prefix=kosEntry and "|cffff3030[KoS]|r " or (guildEntry and "|cffff8a00[Guild KoS]|r " or "")
  row.left:SetText(prefix.."["..level.."] "..n)
  row.left:SetTextColor(r,g,b)
  row.classColor={r,g,b}
  if SGM.cfg.threatColors then
   if kosEntry then row:SetBackdropColor(.34,.035,.035,.96)
   elseif guildEntry then row:SetBackdropColor(.30,.12,.02,.96)
   elseif p.class=="ROGUE" or p.class=="DRUID" then row:SetBackdropColor(.24,.12,.02,.94)
   else row:SetBackdropColor(.035,.08,.035,.90) end
  end
  local age=math.max(0,time()-(SGM.modules.Roster.nearby[n] or p.lastSeen or time()))
  if view=="NEARBY" then
   row.right:SetText(age<2 and "now" or (math.floor(age).."s"))
   local fade=(SGM.cfg.lastSeenFade and age>30) and math.max(.25,1-((age-30)/30)*.75) or 1
   row:SetAlpha(fade)
  else row.right:SetText(""); row:SetAlpha(1) end
  SGM.modules.Rows:ApplyTarget(row,p.targetName or n)
  row.player=n
  row:Show()
 end
end


function W:CreateMinimapButton()
 if self.minimapButton or not Minimap then return end
 local b=CreateFrame("Button","SpyGodModeMinimapButton",Minimap)
 b:SetSize(30,30); b:SetPoint("TOPLEFT",Minimap,"TOPLEFT",-2,-2); b:SetFrameStrata("MEDIUM")
 local t=b:CreateTexture(nil,"ARTWORK"); t:SetAllPoints(); t:SetTexture("Interface\Icons\Ability_Spy")
 if not t:GetTexture() then t:SetTexture("Interface\Icons\INV_Misc_Eye_01") end
 b.icon=t; self.minimapButton=b
 b:SetScript("OnClick",function(_,button)
  if button=="RightButton" and SGM.modules.Options then SGM.modules.Options:Open()
  elseif W.frame then W:SetVisible(not W.frame:IsShown()) end
 end)
 b:RegisterForClicks("LeftButtonUp","RightButtonUp")
 b:SetScript("OnEnter",function(self)
  GameTooltip:SetOwner(self,"ANCHOR_LEFT"); GameTooltip:AddLine("Spy - God Mode")
  local R=SGM.modules.Roster; local total=R and #R.nearbyOrder or 0; local kos={}
  if R then for _,n in ipairs(R.nearbyOrder) do if SGM.db.kos[n] then kos[#kos+1]=n end end end
  GameTooltip:AddDoubleLine("Nearby enemies",tostring(total),1,1,1,1,.3,.3)
  GameTooltip:AddDoubleLine("Nearby KoS",tostring(#kos),1,1,1,1,.2,.2)
  for i=1,math.min(5,#kos) do GameTooltip:AddLine("KoS: "..kos[i],1,.2,.2) end
  if not SGM:CanDetectHere() then GameTooltip:AddLine("Detection paused: Sanctuary",.7,.7,.7)
  elseif (SGM.isMidnight or SGM.isForever) and GetCVarBool and not GetCVarBool("nameplateShowEnemies") then GameTooltip:AddLine("Warning: Enemy nameplates OFF",1,.65,0) end
  GameTooltip:AddLine("Left-click: Show/Hide",.7,.9,1); GameTooltip:AddLine("Right-click: Options",.7,.9,1); GameTooltip:Show()
 end)
 b:SetScript("OnLeave",function() GameTooltip:Hide() end)
 b:SetShown(SGM.cfg.minimap~=false)
end

SGM:On("SGM_READY",function() W:Create(); W:CreateMinimapButton() end)
SGM:On("SGM_LIST_UPDATE",function() W:Refresh() end)
SGM:On("SGM_DETECTED",function(name,p,stealth,isNew)
 -- Repeated combat-log events for an enemy already in Nearby are hot-path data
 -- updates, not UI events. Refresh/pulse only for a real entry or stealth event.
 if not isNew and not stealth then return end
 local wasEmpty=W.wasEmpty
 if SGM.cfg.showOnDetection and W.frame then W:SetVisible(true) end
 W.autoHidden=false; W.collapsed=false; W.emptySince=nil; W.wasEmpty=false; W:Refresh(); W:Pulse()
 if wasEmpty and SGM.cfg.watchMode and SGM.cfg.warnings then SGM:Fire("SGM_ALERT",stealth and "STEALTH" or "NEARBY",name,p) end
end)

SGM:RegisterEvent("PLAYER_REGEN_ENABLED")
SGM:On("PLAYER_REGEN_ENABLED",function()
 if W.pendingReset then W:ResetPosition() end
 if W.pendingVisibility~=nil then
  local desired=W.pendingVisibility
  W.pendingVisibility=nil
  W:SetVisible(desired)
 end
 if W.pendingRefresh then W:Refresh() end
end)

SGM:RegisterEvent("PLAYER_LOGOUT")
SGM:On("PLAYER_LOGOUT",function() W:SavePosition() end)
SGM:RegisterEvent("ZONE_CHANGED_NEW_AREA")
SGM:RegisterEvent("ZONE_CHANGED")
SGM:RegisterEvent("ZONE_CHANGED_INDOORS")
local function zoneRefresh()
 if SGM:CanDetectHere() then return end
 if SGM.modules.Roster then SGM.modules.Roster:ClearNearby() end
end
SGM:On("ZONE_CHANGED_NEW_AREA",zoneRefresh)
SGM:On("ZONE_CHANGED",zoneRefresh)
SGM:On("ZONE_CHANGED_INDOORS",zoneRefresh)
