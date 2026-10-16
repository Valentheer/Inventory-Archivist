-- Experimental Forever markers. Read-only, advisory; no item interactions.
local frame=CreateFrame('Frame')
local active=false
local labels=setmetatable({}, {__mode='k'})
local generation=0
local hooked=setmetatable({}, {__mode='k'})
local function hideAll()
 for _,label in pairs(labels) do label.bg:Hide();label.text:Hide() end
end
local function classify(id)
 if not id then return end
 local name,_,quality,_,_,_,_,_,_,_,_,classID
 if InventoryArchivistAPI and InventoryArchivistAPI.GetItemInfo then
  name,_,quality,_,_,_,_,_,_,_,_,classID=InventoryArchivistAPI.GetItemInfo(id)
 end
 if not name then
  if InventoryArchivistAPI and InventoryArchivistAPI.RequestItemInfo then InventoryArchivistAPI.RequestItemInfo(id) end
  return
 end
 if quality==0 then return 'J',{0.75,0.75,0.75} end
 if classID==7 or classID==5 then return 'M',{0.35,0.75,1} end
 -- Do not label gear as junk or assume expansion-based usefulness in Forever.
end
local function itemFromButton(button,bank)
 if button.GetItemLocation and C_Item and C_Item.GetItemID then
  local ok,loc=pcall(button.GetItemLocation,button)
  if ok and loc then
   local good,id=pcall(C_Item.GetItemID,loc)
   if good and type(id)=='number' then return id end
  end
 end
 local bag=button.GetBagID and button:GetBagID()
 local slot=button.GetID and button:GetID()
 if type(bag)~='number' and not bank and button.GetParent then
  local parent=button:GetParent()
  bag=parent and parent.GetID and parent:GetID()
 end
 if bank then
  -- BankFrameItemN buttons are bank storage, not backpack container slots.
  bag=Enum and Enum.BagIndex and Enum.BagIndex.Bank or BANK_CONTAINER or -1
  local name=button.GetName and button:GetName()
  if name then slot=tonumber(name:match('BankFrameItem(%d+)$')) or slot end
 end
 if type(bag)~='number' or type(slot)~='number' or slot<1 then return end
 local ok,item=pcall(InventoryArchivistAPI.BagItem,bag,slot)
 if ok and item then return item.itemID end
 if bank then
  if GetContainerItemID then
   local success,id=pcall(GetContainerItemID,bag,slot)
   if success and id then return id end
  end
  -- Older-style fixed bank slots are inventory slots, not container slots.
  if BankButtonIDToInvSlotID and GetInventoryItemID then
   local ok,inventorySlot=pcall(BankButtonIDToInvSlotID,slot)
   if ok and inventorySlot then
    local good,id=pcall(GetInventoryItemID,'player',inventorySlot)
    if good and id then return id end
   end
  end
  -- Some clients expose the same fixed bank slots as a contiguous inventory range.
  if GetInventoryItemID and (BANK_SLOT_1 or NUM_BANKGENERIC_SLOTS) then
   local first=BANK_SLOT_1 or 40
   local good,id=pcall(GetInventoryItemID,'player',first+slot-1)
   if good and id then return id end
  end
 end
end
local function mark(button,id)
 local text,color=classify(id)
 local label=labels[button]
 if not text then
  if label then label.bg:Hide();label.text:Hide() end
  return
 end
 if not label then
  local bg=button:CreateTexture(nil,'OVERLAY',nil,7)
  bg:SetSize(16,16);bg:SetPoint('TOPLEFT',button,'TOPLEFT',1,-1)
  bg:SetColorTexture(0,0,0,.85)
  local font=button:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
  font:SetPoint('CENTER',bg,'CENTER',0,0)
  label={bg=bg,text=font};labels[button]=label
 end
 label.text:SetText(text);label.text:SetTextColor(color[1],color[2],color[3]);label.bg:Show();label.text:Show()
end
local queue
local function watch(root)
 if not root or hooked[root] then return end
 hooked[root]=true
 if root.HookScript then
  root:HookScript('OnShow',function()if active and queue then queue() end end)
 end
end
local function scan(root,bank,seen)
 if not root or not root.IsShown then return end
 watch(root)
 if not root:IsShown() then return end
 if root.EnumerateValidItems then
  for _,button in root:EnumerateValidItems() do
   if button and button:IsShown() then
    seen[button]=true;mark(button,itemFromButton(button,bank))
   end
  end
 end
 local name=root.GetName and root:GetName()
 if name then
  for slot=1,160 do
   local button=_G[name..'Item'..slot]
   if button and button:IsShown() then
    seen[button]=true;mark(button,itemFromButton(button,bank))
   end
  end
 end
 -- Bank slots may use their own frame names rather than container buttons.
 if bank then
  for slot=1,160 do
   local button=_G['BankFrameItem'..slot] or _G['BankFrameItemButton'..slot] or _G['BankItem'..slot]
   if button and button:IsShown() then
    seen[button]=true;mark(button,itemFromButton(button,true))
   end
  end
 end
end
-- Forever main bank uses 48 unnamed visual buttons. Match the six-by-eight
-- grid by geometry rather than relying on nonexistent BankFrameItemN globals.
-- The Forever bank contains unnamed buttons, including overlapping buttons
-- at identical coordinates. Deduplicate by slot position before validating.
-- Only the BankPanel children form the visible 6x8 main-bank item grid.
-- BankFrame also owns similarly sized buttons on one row; those are NOT bank slots.
local function foreverBankGrid(bank)
 if not bank or not bank.IsShown or not bank:IsShown() then return end
 local panel=_G.BankPanel
 if not panel or not panel.IsShown or not panel:IsShown() then return end
 local candidates,visited={},{}
 local function visit(node,depth)
  if not node or visited[node] or depth>7 then return end
  visited[node]=true
  if node.GetObjectType and node:GetObjectType()=='Button' and node.IsShown and node:IsShown() then
   local w,h=node:GetWidth(),node:GetHeight()
   local x,y=node:GetLeft(),node:GetTop()
   if x and y and w and h and w>=32 and w<=43 and h>=32 and h<=43 then
    candidates[#candidates+1]={button=node,x=x,y=y,depth=depth}
   end
  end
  if node.GetChildren then
   for _,child in ipairs({node:GetChildren()}) do visit(child,depth+1) end
  end
 end
 visit(panel,0)
 local unique={}
 for _,c in ipairs(candidates) do
  local match
  for _,u in ipairs(unique) do
   if math.abs(c.x-u.x)<5 and math.abs(c.y-u.y)<5 then match=u;break end
  end
  if not match then unique[#unique+1]=c
  elseif c.depth>match.depth then match.button=c.button;match.depth=c.depth end
 end
 table.sort(unique,function(a,b)return a.y>b.y end)
 local rows={}
 for _,c in ipairs(unique) do
  local row
  for _,r in ipairs(rows) do if math.abs(r.y-c.y)<7 then row=r;break end end
  if not row then row={y=c.y,items={}};rows[#rows+1]=row end
  row.items[#row.items+1]=c
 end
 table.sort(rows,function(a,b)return a.y>b.y end)
 local grid={}
 for _,row in ipairs(rows) do
  if #row.items==8 then
   table.sort(row.items,function(a,b)return a.x<b.x end)
   local gap=row.items[2].x-row.items[1].x
   local regular=gap>30 and gap<65
   for i=3,8 do if math.abs((row.items[i].x-row.items[i-1].x)-gap)>7 then regular=false end end
   if regular then
    for _,entry in ipairs(row.items) do grid[#grid+1]=entry.button end
   end
  end
 end
 if #grid==48 then return grid end
end
local function bankContainer48()
 local bags=InventoryArchivistAPI and InventoryArchivistAPI.BankBags and InventoryArchivistAPI.BankBags() or {}
 for _,bag in ipairs(bags) do
  local ok,n=pcall(InventoryArchivistAPI.BagSize,bag)
  if ok and n==48 then return bag end
 end
end
local function scanForeverBank(bank,seen)
 local bag=bankContainer48()
 if not bag then return end
 local grid=foreverBankGrid(bank)
 if not grid then return end
 for slot,button in ipairs(grid) do
  seen[button]=true
  local ok,item=pcall(InventoryArchivistAPI.BagItem,bag,slot)
  mark(button,ok and item and item.itemID or nil)
 end
end
local function refresh()
 if not active then return end
 local seen={}
 scan(_G.ContainerFrameCombinedBags,false,seen)
 local holder=_G.ContainerFrameContainer
 if holder and type(holder.ContainerFrames)=='table' then
  for _,f in pairs(holder.ContainerFrames) do scan(f,false,seen) end
 end
 for i=1,20 do scan(_G['ContainerFrame'..i],false,seen) end
 if (InventoryArchivistInventory and InventoryArchivistInventory.bankOpen) or (_G.BankFrame and _G.BankFrame:IsShown()) then
  scan(_G.BankFrame or _G.BankPanel or _G.BankFrameContainer,true,seen)
  scanForeverBank(_G.BankFrame or _G.BankPanel or _G.BankFrameContainer,seen)
 end
 for button,label in pairs(labels) do
  if not seen[button] then label.bg:Hide();label.text:Hide() end
 end
end
queue=function()
 if not active then return end
 -- Immediate first paint. Each open gets its own follow-up instead of sharing
 -- a stale pending timer from a previous open/close cycle.
 generation=generation+1
 local token=generation
 refresh()
 if C_Timer and C_Timer.After then
  for _,delay in ipairs({0.02,0.09}) do
   C_Timer.After(delay,function()
    if active and token==generation then refresh() end
   end)
  end
 end
end
local events={'BAG_UPDATE_DELAYED','BANKFRAME_OPENED','BANKFRAME_CLOSED','GET_ITEM_INFO_RECEIVED','PLAYER_ENTERING_WORLD','BAG_OPEN','BAG_CLOSED'}
function InventoryArchivistMarkersSetEnabled(enabled)
 enabled=not not enabled
 if enabled==active then return end
 active=enabled
 if active then
  for _,event in ipairs(events) do frame:RegisterEvent(event) end
  -- Hook frames even if the player opens them later; their OnShow is the
  -- fastest reliable signal when Forever doesn't fire a bag event.
  watch(_G.ContainerFrameCombinedBags)
  watch(_G.BankFrame);watch(_G.BankPanel)
  local holder=_G.ContainerFrameContainer
  if holder and type(holder.ContainerFrames)=='table' then
   for _,f in pairs(holder.ContainerFrames) do watch(f) end
  end
  for i=1,20 do watch(_G['ContainerFrame'..i]) end
  queue()
 else
  generation=generation+1
  frame:UnregisterAllEvents();hideAll()
 end
end
frame:SetScript('OnEvent',queue)
local elapsed=0
frame:SetScript('OnUpdate',function(_,dt)
 if not active then return end
 elapsed=elapsed+dt
 if elapsed>=0.35 then elapsed=0;refresh() end
end)
