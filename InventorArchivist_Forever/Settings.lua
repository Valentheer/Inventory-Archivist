-- Forever-specific Settings: no Retail source-mode, auction, or cleanup controls.
local window
local function checkbox(parent,text,y,get,set)
 local b=CreateFrame('CheckButton',nil,parent,'UICheckButtonTemplate')
 b:SetPoint('TOPLEFT',27,y)
 local label=parent:CreateFontString(nil,'OVERLAY','GameFontHighlight')
 label:SetPoint('LEFT',b,'RIGHT',5,0);label:SetText(text)
 b:SetScript('OnClick',function(self) set(self:GetChecked()) end)
 return function()b:SetChecked(get()) end
end
local function build()
 window=CreateFrame('Frame','InventoryArchivistForeverSettings',UIParent,'BackdropTemplate')
 window:SetSize(490,530);window:SetPoint('CENTER');window:SetFrameStrata('DIALOG')
 window:SetClampedToScreen(true);window:SetMovable(true);window:EnableMouse(true)
 window:RegisterForDrag('LeftButton')
 window:SetScript('OnDragStart',window.StartMoving)
 window:SetScript('OnDragStop',function(self)self:StopMovingOrSizing();InventoryArchivistPositionSave(self) end)
 window:SetBackdrop({bgFile=[[Interface\DialogFrame\UI-DialogBox-Background]],edgeFile=[[Interface\DialogFrame\UI-DialogBox-Border]],tile=true,tileSize=32,edgeSize=28,insets={left=8,right=8,top=8,bottom=8}})
 window:SetBackdropColor(.06,.06,.08,.96)
 local title=window:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
 title:SetPoint('TOPLEFT',25,-22);title:SetText('Inventory Archivist  |  Settings')
 local close=CreateFrame('Button',nil,window,'UIPanelCloseButton')
 close:SetPoint('TOPRIGHT',-5,-5)
 local vault=CreateFrame('Button',nil,window,'UIPanelButtonTemplate')
 vault:SetSize(85,22);vault:SetPoint('TOPRIGHT',close,'TOPLEFT',-8,-3)
 vault:SetText('Vault')
 vault:SetScript('OnClick',function()InventoryArchivistPositionSave(window);window:Hide();if InventoryArchivistVaultToggle then InventoryArchivistVaultToggle() end end)
 local section=window:CreateFontString(nil,'OVERLAY','GameFontNormal')
 section:SetPoint('TOPLEFT',27,-70);section:SetText('Optional Features')
 local refreshers={}
 refreshers[#refreshers+1]=checkbox(window,'Inventory Markers (J = gray, M = material)',-90,
  function()return InventoryArchivistFeatures.Enabled('markers') end,
  function(v)InventoryArchivistFeatures.SetEnabled('markers',v) end)
 local hint=window:CreateFontString(nil,'OVERLAY','GameFontDisableSmall')
 hint:SetPoint('TOPLEFT',57,-127);hint:SetText('Experimental. Ordinary equipment is never marked as junk.')
 local shortcuts=window:CreateFontString(nil,'OVERLAY','GameFontNormal')
 shortcuts:SetPoint('TOPLEFT',27,-165);shortcuts:SetText('Vault Shortcuts')
 for _,row in ipairs({{'bags','Show Vault button on bags',-185},{'bank','Show Vault button at banks',-220}}) do
  local key,label,y=row[1],row[2],row[3]
  refreshers[#refreshers+1]=checkbox(window,label,y,
   function()return InventoryArchivistShortcutsGet and InventoryArchivistShortcutsGet(key) end,
   function(v)if InventoryArchivistShortcutsSet then InventoryArchivistShortcutsSet(key,v) end end)
 end
 local posTitle=window:CreateFontString(nil,'OVERLAY','GameFontNormal')
 posTitle:SetPoint('TOPLEFT',27,-263);posTitle:SetText('Bag Positioning')
 refreshers[#refreshers+1]=checkbox(window,'Enable custom bag positions',-282,
  function()return InventoryArchivistBagPositionGet and InventoryArchivistBagPositionGet('enabled') end,
  function(v)InventoryArchivistBagPositionSet('enabled',v) end)
 refreshers[#refreshers+1]=checkbox(window,'Lock bag positions',-313,
  function()return InventoryArchivistBagPositionGet and InventoryArchivistBagPositionGet('locked') end,
  function(v)InventoryArchivistBagPositionSet('locked',v) end)
 refreshers[#refreshers+1]=checkbox(window,'Show lock only on title-bar hover',-344,
  function()return InventoryArchivistBagPositionGet and InventoryArchivistBagPositionGet('visibility')=='hover' end,
  function(v)InventoryArchivistBagPositionSet('visibility',v and 'hover' or 'always') end)
 local resetCombined=CreateFrame('Button',nil,window,'UIPanelButtonTemplate')
 resetCombined:SetSize(180,23);resetCombined:SetPoint('TOPLEFT',27,-391);resetCombined:SetText('Reset Combined Position')
 resetCombined:SetScript('OnClick',function()InventoryArchivistBagPositionReset('combined') end)
 local resetSeparate=CreateFrame('Button',nil,window,'UIPanelButtonTemplate')
 resetSeparate:SetSize(180,23);resetSeparate:SetPoint('LEFT',resetCombined,'RIGHT',10,0);resetSeparate:SetText('Reset Separate Positions')
 resetSeparate:SetScript('OnClick',function()InventoryArchivistBagPositionReset('separate') end)
 function InventoryArchivistBagPositionSettingsRefresh()
  if window and window:IsShown() then for _,fn in ipairs(refreshers) do fn() end end
 end
 local note=window:CreateFontString(nil,'OVERLAY','GameFontDisableSmall')
 note:SetPoint('BOTTOMLEFT',27,32)
 note:SetText('Forever: character inventory is isolated by PvE / PvP realm.')
 window:SetScript('OnShow',function()InventoryArchivistPositionApply(window);for _,fn in ipairs(refreshers) do fn() end end)
 window:Hide()
end
function InventoryArchivistSettingsToggle()
 if not window then build() end
 window:SetShown(not window:IsShown())
end
