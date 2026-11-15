local __sgmBuild = select(4, GetBuildInfo())
if __sgmBuild ~= 11508 and __sgmBuild ~= 11509 then return end
if not _G.SpyGodModeClientOK then return end
local _,SGM=...
local L=_G.SpyGodMode_L
local O={controls={}}; SGM:RegisterModule("Options",O)

local sections={
 {L["General"],{{L["Enable Spy God Mode"],"enabled"},{L["Show window when an enemy is detected"],"showOnDetection"},{L["Detect non-PvP enemy players"],"detectNonPvp"},{L["Enable detection in enemy cities"],"enemyCityMode"},{L["Show KoS button on target"],"showKosButton"}}},
 {L["Window"],{{L["Auto-hide when no enemies are nearby"],"autoHide"},{L["Collapse instead of hiding"],"autoCollapse"},{L["Show Mini Tracker"],"compactHUD"},{L["Watch for new enemies"],"watchMode"},{L["Lock window"],"locked"},{L["Keep window on screen"],"clamp"}}},
 {L["Visuals"],{{L["Animations and border pulse"],"animations"},{L["Prioritize Rogues and Druids"],"stealthPriority"},{L["Highlight dangerous players"],"threatColors"},{L["Fade players before removal"],"lastSeenFade"},{L["Prioritize Kill On Sight players"],"prioritizeKos"}}},
 {L["Alerts"],{{L["Enable sounds"],"sound"},{L["Only play sounds for KoS"],"soundOnlyKos"},{L["Sound: normal enemy"],"soundNearby"},{L["Sound: stealth enemy"],"soundStealth"},{L["Sound: Kill On Sight"],"soundKos"},{L["Sound: KoS guild"],"soundGuildKos"},{L["Display warning window"],"warnings"},{L["Warn on stealth"],"warnStealth"},{L["Warn on Kill On Sight"],"warnKos"},{L["Warn on KoS guild"],"warnKosGuild"}}},
 {L["Tooltips"],{{L["Show win/loss"],"tooltipWinLoss"},{L["Show KoS reason"],"tooltipReason"},{L["Show last seen"],"tooltipLastSeen"}}},
 {L["Intelligence"],{{L["Smart threat scoring"],"intelligence"},{L["Warn when enemy targets you"],"targetWarnings"},{L["Enemy group / SOS warnings"],"sosWarnings"},{L["Record map sightings"],"mapIntel"},{L["Auto-watch repeated killers"],"autoWatchKillers"},{L["Show threat in tooltips"],"tooltipThreat"},{L["Show history in tooltips"],"tooltipHistory"}}},
 {L["GODMODE Network"],{{L["Share detections"],"share"},{L["Use shared detections"],"useShared"},{L["Share with party / raid"],"networkGroup"},{L["Share with guild"],"networkGuild"},{L["Share my KoS entries"],"shareKos"},{L["Receive shared KoS entries"],"receiveKos"},{L["Show minimap Spy button"],"minimap"},{L["Display detections on world map"],"map"}}},
}

local soundProfiles={
 {id="CLASSIC",label="Classic Spy",help="Uses the standard danger sound for normal enemy detections."},
 {id="STEALTH",label="Stealth Hunter",help="Uses the quieter stealth alert for normal enemy detections."},
 {id="ALARM",label="Danger Alarm",help="Uses the loud KoS alarm for all important detections."},
 {id="SILENT",label="Silent",help="Disables profile sounds. The Enable Sounds option is left unchanged."},
}

local function profileInfo()
 local cur=SGM.cfg and SGM.cfg.soundProfile or "CLASSIC"
 for i,p in ipairs(soundProfiles) do if p.id==cur then return i,p end end
 return 1,soundProfiles[1]
end

local function refresh(key)
 if SGM.modules.MainFrame then
  if key=="locked" then SGM.modules.MainFrame:UpdateLock() end
  SGM.modules.MainFrame:Refresh()
  if SGM.modules.MainFrame.UpdateHUD then SGM.modules.MainFrame:UpdateHUD() end
 end
end

local function checkbox(parent,label,key,x,y)
 local c=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate"); c:SetPoint("TOPLEFT",x,y)
 c.text=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight"); c.text:SetPoint("LEFT",c,"RIGHT",2,0); c.text:SetText(label)
 c:SetScript("OnShow",function() c:SetChecked(SGM.cfg and SGM.cfg[key]) end)
 c:SetScript("OnClick",function() SGM.cfg[key]=c:GetChecked() and true or false; refresh(key) end)
 return c
end

function O:Create()
 if self.panel then return end
 local f=CreateFrame("Frame","SpyGodMode_OptionsPanel"); self.panel=f; f.name="Spy God Mode"

 local title=f:CreateFontString(nil,"ARTWORK","GameFontNormalLarge"); title:SetPoint("TOPLEFT",16,-16); title:SetText("Spy God Mode 1.2.16")
 local sub=f:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall"); sub:SetPoint("TOPLEFT",title,"BOTTOMLEFT",0,-8); sub:SetText("All options are independent. Auto-hide is OFF by default.")

 local scroll=CreateFrame("ScrollFrame","SpyGodMode_OptionsScroll",f,"UIPanelScrollFrameTemplate")
 scroll:SetPoint("TOPLEFT",8,-58); scroll:SetPoint("BOTTOMRIGHT",-30,12)
 local content=CreateFrame("Frame",nil,scroll); content:SetSize(640,900); scroll:SetScrollChild(content)

 local y=-8
 for _,section in ipairs(sections) do
  local h=content:CreateFontString(nil,"ARTWORK","GameFontNormal"); h:SetPoint("TOPLEFT",8,y); h:SetText(section[1]); y=y-24
  local col=0
  for _,opt in ipairs(section[2]) do checkbox(content,opt[1],opt[2],12+(col%2)*310,y-math.floor(col/2)*28); col=col+1 end
  y=y-math.ceil(col/2)*28-10
 end

 local h=content:CreateFontString(nil,"ARTWORK","GameFontNormal"); h:SetPoint("TOPLEFT",8,y); h:SetText("Auto-hide")
 y=y-28
 local delayLabel=content:CreateFontString(nil,"ARTWORK","GameFontHighlight"); delayLabel:SetPoint("TOPLEFT",12,y); delayLabel:SetText("Delay before hiding: "..tostring(SGM.cfg and SGM.cfg.autoHideDelay or 30).." seconds")
 local minus=CreateFrame("Button",nil,content,"UIPanelButtonTemplate"); minus:SetSize(32,22); minus:SetPoint("LEFT",delayLabel,"RIGHT",12,0); minus:SetText("-")
 local plus=CreateFrame("Button",nil,content,"UIPanelButtonTemplate"); plus:SetSize(32,22); plus:SetPoint("LEFT",minus,"RIGHT",4,0); plus:SetText("+")
 local function delay(d) SGM.cfg.autoHideDelay=math.max(5,math.min(120,(SGM.cfg.autoHideDelay or 30)+d)); delayLabel:SetText("Delay before hiding: "..SGM.cfg.autoHideDelay.." seconds") end
 minus:SetScript("OnClick",function() delay(-5) end); plus:SetScript("OnClick",function() delay(5) end)
 y=y-42

 local rowLimit=content:CreateFontString(nil,"ARTWORK","GameFontHighlight")
 rowLimit:SetPoint("TOPLEFT",12,y)
 local rowLimitButton=CreateFrame("Button",nil,content,"UIPanelButtonTemplate")
 rowLimitButton:SetSize(100,23)
 rowLimitButton:SetPoint("LEFT",rowLimit,"RIGHT",12,0)
 local rowLimits={5,10,15,20,30}
 local function updateRowLimit()
  rowLimit:SetText((L and L["Visible player rows"] or "Visible player rows")..":")
  rowLimitButton:SetText(tostring(SGM.cfg.visibleRows or 10))
 end
 rowLimitButton:SetScript("OnClick",function()
  local current=tonumber(SGM.cfg.visibleRows) or 10
  local index=2
  for i,v in ipairs(rowLimits) do if v==current then index=i; break end end
  SGM.cfg.visibleRows=rowLimits[(index%#rowLimits)+1]
  if SGM.modules.MainFrame then SGM.modules.MainFrame.scrollOffset=0; SGM.modules.MainFrame:Refresh() end
  updateRowLimit()
 end)
 rowLimitButton:SetScript("OnShow",updateRowLimit)
 updateRowLimit()
 y=y-42

 local sh=content:CreateFontString(nil,"ARTWORK","GameFontNormal"); sh:SetPoint("TOPLEFT",8,y); sh:SetText("Alert Sounds")
 y=y-26
 local profile=CreateFrame("Button",nil,content,"UIPanelButtonTemplate"); profile:SetSize(230,24); profile:SetPoint("TOPLEFT",12,y)
 local test=CreateFrame("Button",nil,content,"UIPanelButtonTemplate"); test:SetSize(90,24); test:SetPoint("LEFT",profile,"RIGHT",8,0); test:SetText("Test Sound")
 local help=content:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall"); help:SetPoint("TOPLEFT",12,y-30); help:SetWidth(570); help:SetJustifyH("LEFT")
 local function profileText()
  local _,p=profileInfo(); profile:SetText("Enemy sound: "..p.label); help:SetText(p.help)
 end
 profile:SetScript("OnShow",profileText)
 profile:SetScript("OnClick",function()
  local i=profileInfo(); local nextProfile=soundProfiles[(i%#soundProfiles)+1]; SGM.cfg.soundProfile=nextProfile.id; profileText()
 end)
 test:SetScript("OnClick",function() if SGM.cfg.soundProfile=="SILENT" then SGM:Print("Sound profile is Silent.") else SGM:SafeSound("NEARBY") end end)
 y=y-72

 local rh=content:CreateFontString(nil,"ARTWORK","GameFontNormal"); rh:SetPoint("TOPLEFT",8,y); rh:SetText("History Retention")
 y=y-28
 local retention=CreateFrame("Button",nil,content,"UIPanelButtonTemplate"); retention:SetSize(220,24); retention:SetPoint("TOPLEFT",12,y)
 local retentionHelp=content:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall"); retentionHelp:SetPoint("LEFT",retention,"RIGHT",10,0); retentionHelp:SetWidth(350); retentionHelp:SetJustifyH("LEFT"); retentionHelp:SetText("How long normal enemy history is kept. KoS and KoS-guild records are never auto-purged.")
 local retentionValues={7,30,90,0}
 local function retentionText() local d=tonumber(SGM.cfg.historyRetentionDays) or 30; retention:SetText("Keep history: "..(d==0 and "Forever" or (d.." days"))) end
 retention:SetScript("OnShow",retentionText)
 retention:SetScript("OnClick",function()
  local cur=tonumber(SGM.cfg.historyRetentionDays) or 30; local idx=2
  for i,v in ipairs(retentionValues) do if v==cur then idx=i break end end
  SGM.cfg.historyRetentionDays=retentionValues[(idx%#retentionValues)+1]; retentionText()
  if SGM.PurgeOldHistory then SGM:PurgeOldHistory() end
 end)
 retentionText(); y=y-48

 local ih=content:CreateFontString(nil,"ARTWORK","GameFontNormal"); ih:SetPoint("TOPLEFT",8,y); ih:SetText("Import / Backup")
 y=y-28
 local importSpy=CreateFrame("Button",nil,content,"UIPanelButtonTemplate"); importSpy:SetSize(180,24); importSpy:SetPoint("TOPLEFT",12,y); importSpy:SetText("Import KoS from Spy")
 local importHelp=content:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall"); importHelp:SetPoint("LEFT",importSpy,"RIGHT",10,0); importHelp:SetWidth(370); importHelp:SetJustifyH("LEFT"); importHelp:SetText("Copies KoS entries from the old Spy addon. Existing Spy God Mode KoS entries are kept.")
 importSpy:SetScript("OnClick",function() if SGM.modules.SpyImport then SGM.modules.SpyImport:Import() end end)
 y=y-44
 local export=CreateFrame("Button",nil,content,"UIPanelButtonTemplate"); export:SetSize(150,24); export:SetPoint("TOPLEFT",12,y); export:SetText("Export KoS")
 local import=CreateFrame("Button",nil,content,"UIPanelButtonTemplate"); import:SetSize(150,24); import:SetPoint("LEFT",export,"RIGHT",8,0); import:SetText("Import KoS")
 local backup=CreateFrame("Button",nil,content,"UIPanelButtonTemplate"); backup:SetSize(115,24); backup:SetPoint("LEFT",import,"RIGHT",8,0); backup:SetText("Backup Lists")
 local restore=CreateFrame("Button",nil,content,"UIPanelButtonTemplate"); restore:SetSize(115,24); restore:SetPoint("LEFT",backup,"RIGHT",8,0); restore:SetText("Restore Latest")
 export:SetScript("OnClick",function() if SGM.modules.DataTools then SGM.modules.DataTools:ShowExport() end end)
 import:SetScript("OnClick",function() if SGM.modules.DataTools then SGM.modules.DataTools:ShowImport() end end)
 backup:SetScript("OnClick",function() if SGM.modules.DataTools then SGM.modules.DataTools:Backup() end end)
 restore:SetScript("OnClick",function() if SGM.modules.DataTools then SGM.modules.DataTools:RestoreLatest() end end)
 y=y-38

 local note=content:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall"); note:SetPoint("TOPLEFT",12,y); note:SetWidth(580); note:SetJustifyH("LEFT")
 note:SetText("Sound profile explanation: Classic Spy uses the normal danger sound. Stealth Hunter uses the stealth sound for regular enemies. Danger Alarm uses the loud KoS alarm. Silent disables profile sounds.")
 content:SetHeight(math.max(700,-y+80))

 if Settings and Settings.RegisterCanvasLayoutCategory then local category=Settings.RegisterCanvasLayoutCategory(f,"Spy God Mode"); Settings.RegisterAddOnCategory(category); self.category=category elseif InterfaceOptions_AddCategory then InterfaceOptions_AddCategory(f) end
end

function O:Open()
 if not self.panel then self:Create() end
 if Settings and Settings.OpenToCategory and self.category then Settings.OpenToCategory(self.category:GetID()) elseif InterfaceOptionsFrame_OpenToCategory then InterfaceOptionsFrame_OpenToCategory(self.panel); InterfaceOptionsFrame_OpenToCategory(self.panel) end
end
function O:Toggle() self:Open() end
SGM:On("SGM_READY",function() O:Create() end)
