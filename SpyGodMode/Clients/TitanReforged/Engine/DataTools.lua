local __sgmBuild = select(4, GetBuildInfo())
if __sgmBuild ~= 38002 then return end
if not _G.SpyGodModeClientOK then return end
local _,SGM=...
local D={}; SGM:RegisterModule("DataTools",D)
local function esc(s) s=tostring(s or ""); return (s:gsub("%%","%%25"):gsub("|","%%7C"):gsub("\n","%%0A")) end
local function unesc(s) return (tostring(s or ""):gsub("%%0A","\n"):gsub("%%7C","|"):gsub("%%25","%%")) end
function D:ExportKoS()
 local entries={}
 for name,e in pairs(SGM.db.kos or {}) do
  local tags=type(e.tags)=="table" and table.concat(e.tags,",") or ""
  entries[#entries+1]=esc(name).."|"..esc(e.reason or "").."|"..esc(tags)
 end
 table.sort(entries); table.insert(entries,1,"SGM-KOS-1")
 return table.concat(entries,"\n")
end
function D:ImportKoS(text)
 if type(text)~="string" or not text:find("SGM%-KOS%-1",1,false) then return 0,0,"Invalid Spy God Mode KoS export." end
 local added,skipped=0,0
 for line in text:gmatch("[^\r\n]+") do
  if line~="SGM-KOS-1" then
   local n,r,t=line:match("^([^|]+)|([^|]*)|(.*)$"); n=unesc(n)
   if n and n~="" then
    n=SGM:ShortName(n)
    if SGM.db.kos[n] then skipped=skipped+1 else
     SGM.modules.Roster:SetKos(n,unesc(r)); local e=SGM.db.kos[n]
     local tags=unesc(t or ""); e.tags={}; for tag in tags:gmatch("[^,]+") do e.tags[#e.tags+1]=tag end
     added=added+1
    end
   end
  end
 end
 return added,skipped
end
function D:CreateBox(title,initial,onAccept)
 local f=CreateFrame("Frame",nil,UIParent,"BackdropTemplate"); f:SetSize(620,360); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12}); f:SetBackdropColor(.02,.025,.03,.98); f:SetBackdropBorderColor(.55,.42,.18,1)
 local h=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); h:SetPoint("TOPLEFT",14,-14); h:SetText(title)
 local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",2,2)
 local eb=CreateFrame("EditBox",nil,f,"InputBoxTemplate"); eb:SetMultiLine(true); eb:SetAutoFocus(true); eb:SetFontObject("ChatFontNormal"); eb:SetPoint("TOPLEFT",16,-48); eb:SetPoint("BOTTOMRIGHT",-16,50); eb:SetText(initial or ""); eb:HighlightText()
 local ok=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); ok:SetSize(100,24); ok:SetPoint("BOTTOMRIGHT",-16,14); ok:SetText(onAccept and "Import" or "Close")
 ok:SetScript("OnClick",function() if onAccept then onAccept(eb:GetText() or "") end; f:Hide() end)
 f:Show(); return f
end
function D:ShowExport() self:CreateBox("Spy God Mode - KoS Export",self:ExportKoS(),nil) end
function D:ShowImport() self:CreateBox("Spy God Mode - Import KoS","",function(text) local a,s,err=self:ImportKoS(text); if err then SGM:Print(err) else SGM:Print("KoS import complete: "..a.." imported, "..s.." already existed.") end end) end
function D:Backup()
 SpyGodModeDB.backups=SpyGodModeDB.backups or {}; local stamp=date("%Y-%m-%d %H:%M")
 SpyGodModeDB.backups[stamp]={kos={},guildKos={},favorites={}}
 local b=SpyGodModeDB.backups[stamp]
 for n,e in pairs(SGM.db.kos or {}) do local tags={}; for i,v in ipairs(type(e.tags)=="table" and e.tags or {}) do tags[i]=v end; b.kos[n]={reason=e.reason,added=e.added,updated=e.updated,tags=tags,sharedBy=e.sharedBy} end
 for n,e in pairs(SGM.db.guildKos or {}) do b.guildKos[n]={reason=e.reason,added=e.added} end
 for n,v in pairs(SGM.db.favorites or {}) do b.favorites[n]=v end
 SGM:Print("Database backup created: "..stamp)
end
function D:RestoreLatest()
 local latest; for stamp in pairs(SGM.db.backups or {}) do if not latest or stamp>latest then latest=stamp end end
 if not latest then SGM:Print("No Spy God Mode backup exists yet."); return end
 local b=SGM.db.backups[latest]; if type(b)~="table" then return end
 SGM.db.kos={}; SGM.db.guildKos={}; SGM.db.favorites={}
 for n,e in pairs(b.kos or {}) do SGM.db.kos[n]=e end; for n,e in pairs(b.guildKos or {}) do SGM.db.guildKos[n]=e end; for n,v in pairs(b.favorites or {}) do SGM.db.favorites[n]=v end
 SGM.modules.Roster:Rebuild(); SGM:Print("Restored lists from backup: "..latest)
end
