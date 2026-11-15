-- Reversible Cooldowns Only: skip GODMODE-owned visual modules; never rewrite user settings.
if _G.OmniCC_GODMODE_CooldownsOnly == true then return end
-- GODMODE combo display. Isolated from AuraContainer/nameplate/CD governor.
local A = _G.OmniCC_GODMODE or {}
local client = select(4,GetBuildInfo()) or 0
local dbName = client >= 120000 and 'OmniCC_GODMODE_MidnightComboDB' or 'OmniCC_GODMODE_ForeverComboDB'
local defaults={enabled=false,size=32,spacing=5,x=0,y=-120,locked=false,showEmpty=true}
local db
local function D()
 if not db then
  _G[dbName]=_G[dbName] or {}; db=_G[dbName]
  for k,v in pairs(defaults) do if db[k]==nil then db[k]=v end end
 end
 return db
end
local frame=CreateFrame('Frame','OmniCC_GODMODE_ComboPoints',UIParent)
frame:SetSize(200,30); frame:SetFrameStrata('MEDIUM'); frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag('LeftButton')
local balls={}
local glows={}
local halos={}
local dragging=false
for i=1,7 do
 local halo=frame:CreateTexture(nil,'BACKGROUND'); halo:SetTexture('Interface\\COMMON\\Indicator-Yellow'); halo:SetBlendMode('ADD'); halo:SetVertexColor(1,.88,.42,1); halos[i]=halo
 local glow=frame:CreateTexture(nil,'OVERLAY'); glow:SetTexture('Interface\\COMMON\\Indicator-Yellow'); glow:SetBlendMode('ADD'); glow:SetVertexColor(1,1,.82,1); glows[i]=glow
 local t=frame:CreateTexture(nil,'ARTWORK'); t:SetTexture('Interface\\COMMON\\Indicator-Yellow'); balls[i]=t
end
local function points()
 local class=select(2,UnitClass('player'))
 if class~='ROGUE' and class~='DRUID' then return 0,0 end
 local cp=(Enum and Enum.PowerType and Enum.PowerType.ComboPoints) or 4
 local n=0; local max=5
 if UnitPower then local ok,v=pcall(UnitPower,'player',cp); if ok and type(v)=='number' then n=v end end
 if UnitPowerMax then local ok,v=pcall(UnitPowerMax,'player',cp); if ok and type(v)=='number' and v>0 then max=v end end
 -- On clients with player-owned combo power, zero is authoritative after spending.
 -- Falling back to GetComboPoints on zero can resurrect stale target points.
 if not UnitPower and GetComboPoints then local ok,v=pcall(GetComboPoints,'player','target'); if ok and type(v)=='number' then n=v end end
 return math.max(0,math.min(n,7)),math.max(1,math.min(max,7))
end
local function render()
 local d=D(); local class=select(2,UnitClass('player'))
 if not d.enabled or (class~='ROGUE' and class~='DRUID') then frame:Hide(); return end
 local n,max=points(); frame:Show()
 local size=d.size; local gap=d.spacing
 frame:SetSize(max*size+(max-1)*gap,size+8)
 if not dragging then frame:ClearAllPoints(); frame:SetPoint('CENTER',UIParent,'CENTER',d.x,d.y) end
 for i,t in ipairs(balls) do
  t:ClearAllPoints(); t:SetSize(size,size); t:SetPoint('LEFT',frame,'LEFT',(i-1)*(size+gap),0)
  local glow=glows[i]; glow:ClearAllPoints(); glow:SetPoint('CENTER',t,'CENTER'); glow:SetSize(size*.82,size*.82); glow:SetAlpha(i<=n and .90 or .03)
  local halo=halos[i]; halo:ClearAllPoints(); halo:SetPoint('CENTER',t,'CENTER'); halo:SetSize(size*1.65,size*1.65); halo:SetAlpha(i<=n and .85 or .02)
  t:SetVertexColor(1,.91,.35,i<=n and 1 or .23)
  local visible=i<=max and (d.showEmpty or i<=n); t:SetShown(visible); glow:SetShown(visible); halo:SetShown(visible)
 end
 frame:EnableMouse(not d.locked)
end
frame:SetScript('OnDragStart',function(self) if not D().locked and not (InCombatLockdown and InCombatLockdown()) then dragging=true; self:StartMoving() end end)
frame:SetScript('OnDragStop',function(self)
 self:StopMovingOrSizing(); local x,y=self:GetCenter(); local w,h=UIParent:GetCenter(); dragging=false
 if x and w then D().x=math.floor(x-w+.5); D().y=math.floor(y-h+.5) end
 render()
end)
local ev=CreateFrame('Frame'); for _,e in ipairs({'PLAYER_LOGIN','PLAYER_ENTERING_WORLD','PLAYER_TARGET_CHANGED','UNIT_POWER_UPDATE','UNIT_POWER_FREQUENT','UNIT_MAXPOWER','UNIT_POWER_POINT_CHARGE','UNIT_SPELLCAST_SUCCEEDED','UNIT_SPELLCAST_START','UPDATE_SHAPESHIFT_FORM','PLAYER_SPECIALIZATION_CHANGED'}) do pcall(ev.RegisterEvent,ev,e) end
 ev:SetScript('OnEvent',function(_,event,unit) if event~='UNIT_POWER_UPDATE' and event~='UNIT_POWER_FREQUENT' and event~='UNIT_MAXPOWER' and event~='UNIT_POWER_POINT_CHARGE' and event~='UNIT_SPELLCAST_SUCCEEDED' and event~='UNIT_SPELLCAST_START' or unit=='player' then render() end end)
_G.OmniCC_GODMODE_ComboAPI={
 Get=function(_,key) return D()[key] end,
 Set=function(_,key,value) if defaults[key]~=nil then D()[key]=value; render() end end,
 Refresh=render,
 Reset=function() local d=D(); d.x=0;d.y=-120;d.size=32;d.spacing=5;render() end,
}
