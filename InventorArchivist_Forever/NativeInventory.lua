InventoryArchivistInventory={}
local M=InventoryArchivistInventory
local function realm()
 local id=InventoryArchivistForever.RealmID()
 if not id then return nil end
 local d=InventoryArchivistForeverDB
 d.realms=d.realms or {}
 d.realms[id]=d.realms[id] or {name=InventoryArchivistForever.RealmName(),characters={}}
 return d.realms[id]
end
-- Forever names have two parts. The second UnitName result is a surname
-- on this client, unlike the realm value returned on ordinary Retail.
local function ownerNames()
 local first,last=UnitName('player')
 if type(first)~='string' or first=='' or first==UNKNOWNOBJECT then return nil end
 if first:find(' ',1,true) then return first,first end
 if type(last)=='string' and last~='' then
  -- Guard against clients returning a realm instead of a surname.
  local realmName=GetRealmName and GetRealmName()
  local normalized=GetNormalizedRealmName and GetNormalizedRealmName()
  if last~=realmName and last~=normalized then return first..' '..last,first end
 end
 return first,first
end
local function character()
 local r=realm();local full,first=ownerNames()
 if not r or not full then return nil end
 -- Migrate the current character's original first-name-only snapshot.
 -- Never touch other characters or other realms.
 if full~=first and r.characters[first] then
  local old=r.characters[first]
  local current=r.characters[full]
  if current then
   current.locations=current.locations or {}
   for loc,snapshot in pairs(old.locations or {}) do
    local existing=current.locations[loc]
    if not existing or (snapshot.scannedAt or 0)>(existing.scannedAt or 0) then
     current.locations[loc]=snapshot
    end
   end
   if old.money~=nil and (old.moneyScannedAt or 0)>(current.moneyScannedAt or 0) then
    current.money=old.money;current.moneyScannedAt=old.moneyScannedAt
   end
  else
   r.characters[full]=old
  end
  r.characters[first]=nil
 end
 r.characters[full]=r.characters[full] or {locations={}}
 return r.characters[full]
end
local function add(items,id,count,quality,link)
 local row=items[id] or {quantity=0,quality=quality,link=link}
 row.quantity=row.quantity+(count or 1)
 row.link=row.link or link;row.quality=row.quality or quality
 items[id]=row
end
local function snapshot(bags)
 local items,readable={},false
 for _,bag in ipairs(bags) do
  local ok,n=pcall(InventoryArchivistAPI.BagSize,bag)
  if ok and type(n)=='number' and n>0 then
   readable=true
   for slot=1,n do
    local success,v=pcall(InventoryArchivistAPI.BagItem,bag,slot)
    if success and v and v.itemID then add(items,v.itemID,v.stackCount,v.quality,v.hyperlink) end
   end
  end
 end
 if not readable then return nil end
 return {items=items,scannedAt=time()}
end
function M.ScanBags()
 local c=character();if not c then return end
 local s=snapshot(InventoryArchivistAPI.CharacterBags())
 if s then c.locations.bag=s end
end
function M.ScanEquipment()
 local c=character();if not c then return end
 local items={}
 for slot=1,19 do
  local id=GetInventoryItemID and GetInventoryItemID('player',slot)
  if id then add(items,id,1,nil,GetInventoryItemLink and GetInventoryItemLink('player',slot)) end
 end
 c.locations.equip={items=items,scannedAt=time()}
end
function M.ScanMoney()
 local c=character();if c and GetMoney then c.money=GetMoney();c.moneyScannedAt=time() end
end
function M.ScanBank()
 if not M.bankOpen then return end
 local c=character();if not c then return end
 local s=snapshot(InventoryArchivistAPI.BankBags())
 if s then c.locations.bank=s end
end
function M.Mode() return 'ia' end
function M.SetMode() end
function M.MoneyStatus(owner)
 local r=realm();local c=r and r.characters[owner]
 return {ia=c and c.money~=nil or false,bs=false,selected=c and c.money~=nil and 'ia' or nil,iaTime=c and c.moneyScannedAt}
end
function M.Money(owner)
 local r=realm();local c=r and r.characters[owner]
 return c and c.money or nil,c and c.money~=nil and 'ia' or nil
end
function M.Resolve()
 local r=realm();local resolved,status={},{}
 if not r then return resolved,status end
 for name,c in pairs(r.characters) do
  resolved[name]={};status[name]={}
  for loc,s in pairs(c.locations or {}) do
   resolved[name][loc]=s.items
   status[name][loc]={ia=true,bs=false,selected='ia',iaTime=s.scannedAt}
  end
 end
 return resolved,status
end
function M.Aggregate()
 local resolved,status=M.Resolve();local records,scopes={},{}
 for owner,locs in pairs(resolved) do
  scopes[#scopes+1]={key=owner,label=owner}
  for loc,items in pairs(locs) do
   for id,v in pairs(items) do
    local qty=type(v)=='table' and v.quantity or v
    local row=records[id] or {id=id,total=0,owners={},sources={}}
    row.total=row.total+qty;row.owners[owner]=(row.owners[owner] or 0)+qty
    row.sources[owner]=row.sources[owner] or {};row.sources[owner][loc]=status[owner][loc]
    records[id]=row
   end
  end
 end
 table.sort(scopes,function(a,b)return a.label<b.label end)
 return records,scopes,status
end
local queued=false
local function schedule()
 if queued then return end
 queued=true
 if C_Timer and C_Timer.After then C_Timer.After(.25,function()queued=false;M.ScanBags();if M.bankOpen then M.ScanBank() end end)
 else queued=false;M.ScanBags() end
end
local f=CreateFrame('Frame')
for _,event in ipairs({'PLAYER_ENTERING_WORLD','BAG_UPDATE_DELAYED','PLAYER_EQUIPMENT_CHANGED','PLAYER_MONEY','BANKFRAME_OPENED','BANKFRAME_CLOSED'}) do f:RegisterEvent(event) end
f:SetScript('OnEvent',function(_,event)
 if event=='PLAYER_ENTERING_WORLD' then M.ScanBags();M.ScanEquipment();M.ScanMoney()
 elseif event=='PLAYER_EQUIPMENT_CHANGED' then M.ScanEquipment()
 elseif event=='PLAYER_MONEY' then M.ScanMoney()
 elseif event=='BANKFRAME_OPENED' then M.bankOpen=true;M.ScanBank()
 elseif event=='BANKFRAME_CLOSED' then M.ScanBank();M.bankOpen=false
 else schedule() end
end)
