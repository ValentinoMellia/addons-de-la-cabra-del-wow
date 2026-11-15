local __sgmBuild = select(4, GetBuildInfo())
if __sgmBuild ~= 20505 and __sgmBuild ~= 20506 then return end
if not _G.SpyGodModeClientOK then return end
local _,SGM=...
SGM.skin={
 bg={.018,.022,.028,.96},
 title={.035,.043,.052,.98},
 toolbar={.025,.03,.038,.98},
 row1={.055,.062,.07,.94},
 row2={.038,.044,.052,.94},
 gold={1,.72,.18,1},
 border={.40,.36,.22,1},
 muted={.65,.68,.72,1}
}
function SGM:Backdrop(f,border)
 f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
 f:SetBackdropColor(unpack(self.skin.bg))
 f:SetBackdropBorderColor(unpack(border or self.skin.border))
end
function SGM:FlatButton(parent,w,h)
 local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
 b:SetSize(w,h)
 b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
 b:SetBackdropColor(.055,.062,.072,.98)
 b:SetBackdropBorderColor(.38,.34,.20,1)
 b.text=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
 b.text:SetPoint("CENTER")
 b.text:SetTextColor(1,.76,.25)
 b:SetScript("OnEnter",function(self) self:SetBackdropColor(.11,.12,.14,1); self:SetBackdropBorderColor(.72,.58,.22,1) end)
 b:SetScript("OnLeave",function(self) self:SetBackdropColor(.055,.062,.072,.98); self:SetBackdropBorderColor(.38,.34,.20,1) end)
 return b
end
