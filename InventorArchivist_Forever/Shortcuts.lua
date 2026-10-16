-- Forever experimental Vault shortcuts. No inventory writes or frame repositioning.
local buttons={}
local bankOpen=false
local hooked=setmetatable({}, {__mode='k'})
local update
local function watch(f)
 if not f or hooked[f] or not f.HookScript then return end
 hooked[f]=true
 f:HookScript('OnShow',function() if update then update() end end)
 f:HookScript('OnHide',function() if update then update() end end)
end
local function watchBags()
 watch(_G.ContainerFrameCombinedBags)
 local holder=_G.ContainerFrameContainer
 if holder and type(holder.ContainerFrames)=='table' then
  for _,f in pairs(holder.ContainerFrames) do watch(f) end
 end
 for i=1,20 do watch(_G['ContainerFrame'..i]) end
 watch(_G.BankFrame);watch(_G.BankPanel);watch(_G.BankFrameContainer)
end
local function setting(key)
 local db=InventoryArchivistForeverDB
 local opts=db and db.shortcuts or {}
 if opts[key]==nil then return true end
 return opts[key]==true
end
function InventoryArchivistShortcutsGet(key) return setting(key) end
function InventoryArchivistShortcutsSet(key,value)
 local db=InventoryArchivistForeverDB
 db.shortcuts=db.shortcuts or {}
 db.shortcuts[key]=not not value
 if InventoryArchivistShortcutsRefresh then InventoryArchivistShortcutsRefresh() end
end
local function blocked()
 return InventoryArchivistVault and InventoryArchivistVault:IsShown()
end
local function isVisible(f)
 return f and f.IsShown and f:IsShown()
end
local function bagTarget()
 if isVisible(_G.ContainerFrameCombinedBags) then return _G.ContainerFrameCombinedBags end
 local container=_G.ContainerFrameContainer
 if container and type(container.ContainerFrames)=='table' then
  for _,f in pairs(container.ContainerFrames) do
   if isVisible(f) and f.GetID and f:GetID()==0 then return f end
  end
 end
 for i=1,20 do
  local f=_G['ContainerFrame'..i]
  if isVisible(f) and f.GetID and f:GetID()==0 then return f end
 end
 -- Some Forever layouts do not use ID 0 for the visible backpack.
 for i=1,20 do
  local f=_G['ContainerFrame'..i]
  if isVisible(f) then return f end
 end
end
local function bankTarget()
 if not bankOpen then return end
 for _,name in ipairs({'BankFrame','BankPanel','BankFrameContainer'}) do
  local f=_G[name]
  if isVisible(f) then return f end
 end
end
local function createButton(kind)
 local b=CreateFrame('Button',nil,UIParent,'UIPanelButtonTemplate')
 b:SetSize(kind=='bank' and 62 or 50,22)
 b:SetText('Vault')
 b:SetFrameStrata('DIALOG')
 b:SetFrameLevel(200)
 b:RegisterForClicks('LeftButtonUp')
 b:SetScript('OnClick',function()
  if InventoryArchivistVaultToggle then InventoryArchivistVaultToggle() end
 end)
 b:SetScript('OnEnter',function(self)
  GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
  GameTooltip:AddLine('Inventory Archivist',1,.82,0)
  GameTooltip:AddLine('Open Account Vault',1,1,1)
  GameTooltip:Show()
 end)
 b:SetScript('OnLeave',function() GameTooltip:Hide() end)
 b:Hide()
 buttons[kind]=b
 return b
end
update=function()
 for _,kind in ipairs({'bags','bank'}) do
  local target=setting(kind) and not blocked() and (kind=='bags' and bagTarget() or bankTarget()) or nil
  local b=buttons[kind]
  if target and not (InCombatLockdown and InCombatLockdown()) then
   b=b or createButton(kind)
   if b._target~=target then
    b:ClearAllPoints()
    -- Offset to avoid the close button; bank title bars may differ from Retail.
    b:SetPoint('TOPRIGHT',target,'TOPRIGHT',-44,kind=='bank' and 1 or 1)
    b._target=target
   end
   b:Show()
  elseif b then b:Hide() end
 end
end
function InventoryArchivistShortcutsRefresh() watchBags();update() end
local frame=CreateFrame('Frame')
for _,event in ipairs({'PLAYER_LOGIN','BANKFRAME_OPENED','BANKFRAME_CLOSED','BAG_UPDATE_DELAYED','PLAYER_REGEN_ENABLED'}) do
 frame:RegisterEvent(event)
end
frame:SetScript('OnEvent',function(_,event)
 if event=='BANKFRAME_OPENED' then bankOpen=true
 elseif event=='BANKFRAME_CLOSED' or event=='PLAYER_LOGIN' then bankOpen=false end
 watchBags()
 update()
end)
-- Some Forever UI transitions don't emit a bag event. Reconcile at low frequency.
local elapsed=0
frame:SetScript('OnUpdate',function(_,dt)
 elapsed=elapsed+dt
 if elapsed<0.25 then return end
 elapsed=0
 watchBags()
 update()
end)
