-- Optional Forever bag positioning. Does not touch item buttons or inventory data.
local tracked=setmetatable({},{__mode='k'})
local handles=setmetatable({},{__mode='k'})
local lockButton
local busy=false
local draggingFrames=setmetatable({},{__mode='k'})
local function options()
 local db=InventoryArchivistForeverDB
 if not db then return nil end
 db.bagPosition=db.bagPosition or {}
 local o=db.bagPosition
 if o.enabled==nil then o.enabled=true end -- enabled for new installs; preserve existing preferences
 if o.locked==nil then o.locked=true end
 if o.visibility==nil then o.visibility='always' end
 o.combined=o.combined or {}
 o.separate=o.separate or {}
 return o
end
local function visible(f) return f and f.IsShown and f:IsShown() end
local function frames()
 local found,seen={},{}
 local function add(f,combined)
  if not f or seen[f] then return end
  seen[f]=true
  local id=f.GetID and f:GetID() or nil
  local key=combined and 'combined' or (id~=nil and ('bag'..tostring(id)) or (f.GetName and f:GetName()))
  if key then found[#found+1]={f=f,key=key,combined=combined} end
 end
 add(_G.ContainerFrameCombinedBags,true)
 local holder=_G.ContainerFrameContainer
 if holder and type(holder.ContainerFrames)=='table' then
  for _,f in pairs(holder.ContainerFrames) do add(f,false) end
 end
 for i=1,20 do add(_G['ContainerFrame'..i],false) end
 return found
end
-- Keep the selected layout independent of the visibility of the main backpack.
-- Native container frames are reused, so a currently visible combined frame is
-- the strongest signal; otherwise retain the last observed layout selection.
local activeMode
local function layoutMode()
 local o=options()
 if visible(_G.ContainerFrameCombinedBags) then
  activeMode='combined'
 elseif not activeMode then
  activeMode=(o and o.lastLayoutMode) or 'separate'
 end
 return activeMode
end
local function storeFor(f,combined,o)
 if combined or layoutMode()=='combined' then return o.combined end
 return o.separate
end
local function currentKey(f,combined)
 if combined then return 'combined' end
 local id=f.GetID and f:GetID()
 return id~=nil and ('bag'..tostring(id)) or nil
end
local function save(f,key,combined)
 local o=options();if not o or not o.enabled then return end
 key=currentKey(f,combined)
 if not key then return end
 local x,y=f:GetCenter();local px,py=UIParent:GetCenter()
 if not x or not y or not px or not py then return end
 local scale=f:GetEffectiveScale()/UIParent:GetEffectiveScale()
 local store=storeFor(f,combined,o)
 store[key]={x=(x*scale-px),y=(y*scale-py)}
end
-- Snapshot other visible windows when customization begins, preserving existing saves.
local function captureVisibleLayout()
 local o=options();if not o or not o.enabled then return end
 for _,v in ipairs(frames()) do
  if visible(v.f) and not draggingFrames[v.f] then
   local key=currentKey(v.f,v.combined)
   local store=storeFor(v.f,v.combined,o)
   if key and not store[key] then save(v.f,key,v.combined) end
  end
 end
end
local function apply(f,key,combined)
 local o=options();if not o or not o.enabled or draggingFrames[f] then return end
 key=currentKey(f,combined)
 if not key then return end
 local point=storeFor(f,combined,o)[key]
 if not point or not point.x or not point.y then return end
 if InCombatLockdown and InCombatLockdown() then return end
 local scale=f:GetEffectiveScale()/UIParent:GetEffectiveScale()
 if scale==0 then return end
 local x,y=f:GetCenter();local px,py=UIParent:GetCenter()
 if x and y and px and py then
  if math.abs(x*scale-px-point.x)<0.75 and math.abs(y*scale-py-point.y)<0.75 then return end
 end
 busy=true
 f:ClearAllPoints()
 f:SetPoint('CENTER',UIParent,'CENTER',point.x/scale,point.y/scale)
 busy=false
end
-- Restore all visible windows after native container layout changes.
-- A short bounded series handles immediate and deferred Blizzard layout passes.
local restoreGeneration=0
local function restoreVisible()
 local o=options()
 if not o or not o.enabled or (InCombatLockdown and InCombatLockdown()) then return end
 for _,v in ipairs(frames()) do
  if visible(v.f) then apply(v.f,v.key,v.combined) end
 end
end
local function scheduleRestore()
 restoreGeneration=restoreGeneration+1
 local generation=restoreGeneration
 restoreVisible()
 if C_Timer and C_Timer.After then
  for _,delay in ipairs({0,0.03,0.12,0.30}) do
   C_Timer.After(delay,function()
    if generation==restoreGeneration then restoreVisible() end
   end)
  end
 end
end
-- Restore immediately after native container layout calls, when available.
-- Keep the proven periodic correction as a fallback for Forever-specific paths.
local hookedLayouts={}
local function hookNativeLayouts()
 if type(hooksecurefunc)~='function' then return end
 for _,name in ipairs({'UpdateContainerFrameAnchors','ContainerFrame_GenerateFrame'}) do
  if not hookedLayouts[name] and type(_G[name])=='function' then
   hookedLayouts[name]=true
   hooksecurefunc(name,function()
    if not busy then restoreVisible() end
   end)
  end
 end
end
local function buttonTarget()
 if visible(_G.ContainerFrameCombinedBags) then return _G.ContainerFrameCombinedBags end
 local list=frames()
 for _,v in ipairs(list) do if not v.combined and visible(v.f) and v.f.GetID and v.f:GetID()==0 then return v.f end end
 for _,v in ipairs(list) do if not v.combined and visible(v.f) then return v.f end end
end
local function refresh()
 local o=options();if not o then return end
 for f,h in pairs(handles) do
  h:SetShown(o.enabled and not o.locked and visible(f))
 end
 local target=o.enabled and buttonTarget() or nil
 if target then
  if not lockButton then
   -- Native-styled button with a compact lock glyph, left of Vault.
   lockButton=CreateFrame('Button',nil,UIParent,'UIPanelButtonTemplate')
   lockButton:SetSize(24,22);lockButton:SetFrameStrata('DIALOG');lockButton:SetFrameLevel(201)
   lockButton:SetText('')
   local body=lockButton:CreateTexture(nil,'ARTWORK')
   body:SetSize(10,8);body:SetPoint('BOTTOM',0,3);body:SetColorTexture(1,.82,.27,1)
   local shackleTop=lockButton:CreateTexture(nil,'ARTWORK')
   shackleTop:SetSize(8,2);shackleTop:SetColorTexture(1,.82,.27,1)
   local shackleLeft=lockButton:CreateTexture(nil,'ARTWORK')
   shackleLeft:SetSize(2,6);shackleLeft:SetColorTexture(1,.82,.27,1)
   local shackleRight=lockButton:CreateTexture(nil,'ARTWORK')
   shackleRight:SetSize(2,6);shackleRight:SetColorTexture(1,.82,.27,1)
   lockButton._shackle={shackleTop,shackleLeft,shackleRight}
   lockButton:SetScript('OnEnter',function(self)
    if GameTooltip then
     GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
     GameTooltip:SetText(options().locked and 'Unlock bag positions' or 'Lock bag positions')
     GameTooltip:Show()
    end
   end)
   lockButton:SetScript('OnLeave',function()if GameTooltip then GameTooltip:Hide() end end)
   lockButton:SetScript('OnClick',function()
    local opts=options();if opts then opts.locked=not opts.locked end
    refresh()
    if InventoryArchivistBagPositionSettingsRefresh then InventoryArchivistBagPositionSettingsRefresh() end
   end)
  end
  if lockButton._target~=target then
   lockButton:ClearAllPoints()
   -- Match the old L/U control position, to the left of Vault.
   lockButton:SetPoint('TOPRIGHT',target,'TOPRIGHT',-100,1)
   lockButton._target=target
  end
  local top,left,right=unpack(lockButton._shackle)
  top:ClearAllPoints();left:ClearAllPoints();right:ClearAllPoints()
  local dx=o.locked and 0 or 4
  top:SetPoint('BOTTOM',lockButton,'BOTTOM',dx,14)
  left:SetPoint('BOTTOM',lockButton,'BOTTOM',dx-3,9)
  right:SetPoint('BOTTOM',lockButton,'BOTTOM',dx+3,9)
  local hover=o.visibility=='hover'
  local show=not hover or (target.IsMouseOver and target:IsMouseOver()) or (lockButton.IsMouseOver and lockButton:IsMouseOver())
  lockButton:SetShown(show)
 elseif lockButton then lockButton:Hide() end
end
local function attach(f,key,combined)
 if tracked[f] then return end
 tracked[f]=true
 local handle=CreateFrame('Button',nil,UIParent)
 -- Compact drag grip: leave the bag title legible even on small containers.
 handle:SetSize(13,15)
 handle:SetFrameStrata('DIALOG');handle:SetFrameLevel(199)
 handle:SetPoint('TOPLEFT',f,'TOPLEFT',36,-3)
 handle:RegisterForDrag('LeftButton')
 local tex=handle:CreateTexture(nil,'BACKGROUND')
 tex:SetAllPoints();tex:SetColorTexture(.2,.65,1,.16)
 local label=handle:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
 label:SetPoint('CENTER');label:SetText('::')
 handle:SetScript('OnDragStart',function()
  local o=options()
  if not o or not o.enabled or o.locked or (InCombatLockdown and InCombatLockdown()) then return end
  captureVisibleLayout()
  f:SetMovable(true)
  draggingFrames[f]=true
  f:StartMoving()
  handle.dragging=true
 end)
 handle:SetScript('OnDragStop',function()
  if not handle.dragging then return end
  handle.dragging=false
  f:StopMovingOrSizing()
  save(f,currentKey(f,combined),combined)
  draggingFrames[f]=nil
  scheduleRestore()
 end)
 handle:Hide();handles[f]=handle
 if f.HookScript then
  f:HookScript('OnShow',function()
   scheduleRestore()
   refresh()
  end)
  f:HookScript('OnHide',function()handle:Hide();scheduleRestore();refresh() end)
 end
end
local function discover()
 hookNativeLayouts()
 local o=options()
 if visible(_G.ContainerFrameCombinedBags) then
  activeMode='combined'
 elseif activeMode~='separate' then
  -- A separately opened main backpack is an explicit separate-layout signal.
  -- Closing the combined backpack is NOT a signal to switch modes.
  for _,v in ipairs(frames()) do
   if not v.combined and visible(v.f) and v.f.GetID and v.f:GetID()==0 then
    activeMode='separate'
    break
   end
  end
 end
 if o and activeMode then o.lastLayoutMode=activeMode end
 for _,v in ipairs(frames()) do attach(v.f,v.key,v.combined) end
 refresh()
end
function InventoryArchivistBagPositionGet(field)
 local o=options();return o and o[field]
end
function InventoryArchivistBagPositionSet(field,value)
 if field~='enabled' and field~='locked' and field~='visibility' then return end
 local o=options();if not o then return end
 if field=='visibility' then o.visibility=(value=='hover') and 'hover' or 'always'
 else o[field]=not not value end
 discover()
end
function InventoryArchivistBagPositionReset(which)
 local o=options();if not o then return end
 if which=='combined' then o.combined={}
 elseif which=='separate' then o.separate={}
 else o.combined={};o.separate={} end
 -- Recalculate native anchors now if safe, so the reset takes effect on
 -- already-open windows as well as on the next open. No saved coordinates
 -- are reintroduced by this routine.
 if not (InCombatLockdown and InCombatLockdown()) then
  if type(_G.UpdateContainerFrameAnchors)=='function' then
   _G.UpdateContainerFrameAnchors()
  end
 end
 scheduleRestore()
end
function InventoryArchivistBagPositionRefresh()discover() end
SLASH_IABAGLAYOUT1='/iabaglayout'
SlashCmdList.IABAGLAYOUT=function()
 hookNativeLayouts()
 local out={}
 for _,name in ipairs({'UpdateContainerFrameAnchors','ContainerFrame_GenerateFrame'}) do
  out[#out+1]=name..'='..(hookedLayouts[name] and 'hooked' or (type(_G[name])=='function' and 'available' or 'missing'))
 end
 print('IA bag layout: '..table.concat(out,', '))
end
local events=CreateFrame('Frame')
for _,e in ipairs({'PLAYER_LOGIN','BAG_UPDATE_DELAYED','PLAYER_REGEN_ENABLED','BAG_OPEN','BAG_CLOSED'}) do events:RegisterEvent(e) end
events:SetScript('OnEvent',function(_,event)
 discover()
 if event~='BAG_UPDATE_DELAYED' then scheduleRestore() end
end)
local elapsed=0
local lastVisibility=''
events:SetScript('OnUpdate',function(_,dt)
 elapsed=elapsed+dt;if elapsed<.15 then return end;elapsed=0
 discover()
 local parts={}
 for _,v in ipairs(frames()) do
  if visible(v.f) then parts[#parts+1]=tostring(v.f) end
 end
 table.sort(parts)
 local signature=table.concat(parts,'|')
 if signature~=lastVisibility then
  lastVisibility=signature
  scheduleRestore()
 end
 -- Reassert only positions that were explicitly saved by a user drag.
 -- Native container restacking can occur after the scheduled callbacks.
 restoreVisible()
end)
