-- Inventory Archivist Forever Account Vault: read-only inventory snapshot browser.
local ADDON = ...
local vault, scroller, content, picker, search, summary
local currentScope = 'ALL'
local categoriesVisible = {Materials=true,Consumables=true,Equipment=true,Other=true,Junk=true}
local hideQuest = false
local auctionStatus='ALL'
local sortMode='Name'
local statusOptions={{'All items','ALL'}}
local sortOptions={'Name','Quantity'}
local filterPanel, filterButton, moneyLabel, moneyHitbox, filterChecks, sortPicker, priceSummary, statusRadios
local scopes, records, tiles, ownerMoney, ownerMoneyStatus = {}, {}, {}, {}, {}
local categoryOrder = {'Materials','Consumables','Equipment','Other','Junk'}
local categoryColors = {Materials={.35,.72,1},Consumables={.4,.9,.48},Equipment={1,.75,.35},Other={.8,.8,.9},Junk={.65,.65,.65}}
local lastQuery = ''
local function infoFor(id)
 local db = InventoryArchivistDB
 local cached = db and db.itemInfo and db.itemInfo[id]
 local name,link,quality,_,_,_,_,_,_,icon,_,classID
 name,link,quality,_,_,_,_,_,_,icon,_,classID=InventoryArchivistAPI.GetItemInfo(id)
 if not name and cached then name=cached.name;link=cached.link;quality=cached.quality;icon=cached.icon;classID=cached.classID end
 if not name then InventoryArchivistAPI.RequestItemInfo(id) end
 return name,link,quality,icon,classID
end
local function parseItem(raw)
 if type(raw)~='string' then return end
 local id=tonumber(raw:match('^(%d+)'))
 if not id or id>10000000 then return end
 local q=tonumber(raw:match('^%d+;(%d+)')) or 1
 return id,math.max(1,q)
end
local function gather()
 records={};scopes={};ownerMoney={};ownerMoneyStatus={}
 if not InventoryArchivistInventory then return end
 records,scopes=InventoryArchivistInventory.Aggregate()
 for _,entry in ipairs(scopes) do
  ownerMoney[entry.key]=InventoryArchivistInventory.Money(entry.key)
  ownerMoneyStatus[entry.key]=InventoryArchivistInventory.MoneyStatus(entry.key)
 end
end
local function categorize(classID,quality)
 if quality==0 then return 'Junk' end
 if classID==7 or classID==5 then return 'Materials' end
 if classID==0 then return 'Consumables' end
 if classID==2 or classID==4 then return 'Equipment' end
 return 'Other'
end
local function createUI()
 vault=CreateFrame('Frame','InventoryArchivistVault',UIParent,'BackdropTemplate')
 vault:SetSize(870,625);vault:SetPoint('CENTER');vault:SetFrameStrata('DIALOG');vault:SetClampedToScreen(true)
 vault:SetMovable(true);vault:EnableMouse(true);vault:RegisterForDrag('LeftButton')
 vault:SetScript('OnDragStart',vault.StartMoving);vault:SetScript('OnDragStop',function(self)self:StopMovingOrSizing();InventoryArchivistPositionSave(self) end)
 vault:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=28,insets={left=8,right=8,top=8,bottom=8}})
 local title=vault:CreateFontString(nil,'OVERLAY','GameFontNormalLarge');title:SetPoint('TOPLEFT',24,-19);title:SetText('Inventory Archivist  |  Account Vault')
 local close=CreateFrame('Button',nil,vault,'UIPanelCloseButton');close:SetPoint('TOPRIGHT',-6,-6)
 -- Keep navigation symmetrical with the Vault button in Settings.
 local settingsButton=CreateFrame('Button',nil,vault,'UIPanelButtonTemplate')
 settingsButton:SetSize(88,23)
 settingsButton:SetPoint('TOPRIGHT',close,'TOPLEFT',-8,-3)
 settingsButton:SetText('Settings')
 settingsButton:SetScript('OnClick',function()
  InventoryArchivistPositionSave(vault)
  vault:Hide()
  if InventoryArchivistSettingsToggle then InventoryArchivistSettingsToggle() end
 end)
 local label=vault:CreateFontString(nil,'OVERLAY','GameFontNormal');label:SetPoint('TOPLEFT',24,-58);label:SetText('Inventory:')
 local cleanupButton=CreateFrame('Button',nil,vault,'UIPanelButtonTemplate');cleanupButton:SetSize(112,23);cleanupButton:SetPoint('TOPRIGHT',-47,-13);cleanupButton:SetText('Cleanup')
 cleanupButton:Hide()
 cleanupButton:SetScript('OnClick',function()
  if InventoryArchivistFeatures and InventoryArchivistFeatures.CleanupEnabled() and InventoryArchivistCleanupToggle then
   InventoryArchivistPositionSave(vault);InventoryArchivistCleanupToggle(currentScope)
  end
 end)
 -- Keep the disabled button visible and hoverable for feature discovery.
 cleanupButton:SetScript('OnEnter',function(self)
  if not (InventoryArchivistFeatures and InventoryArchivistFeatures.CleanupEnabled()) then
   GameTooltip:SetOwner(self,'ANCHOR_BOTTOM');GameTooltip:AddLine('Cleanup disabled',1,0.82,0.25)
   GameTooltip:AddLine('Enable in IA Settings.',0.8,0.8,0.8);GameTooltip:Show()
  end
 end)
 cleanupButton:SetScript('OnLeave',function()GameTooltip:Hide() end)
 function InventoryArchivistVaultUpdateCleanupButton()
  local enabled=not InventoryArchivistFeatures or InventoryArchivistFeatures.CleanupEnabled()
  -- Desaturate visually without Disable(), so tooltip still works.
  cleanupButton:SetAlpha(enabled and 1 or 0.4)
 end
 InventoryArchivistVaultUpdateCleanupButton()
 picker=CreateFrame('Frame','InventoryArchivistVaultPicker',vault,'UIDropDownMenuTemplate');picker:SetPoint('LEFT',label,'RIGHT',-5,-2);UIDropDownMenu_SetWidth(picker,215)
 UIDropDownMenu_Initialize(picker,function(_,level)
  local function option(text,key)
   local o=UIDropDownMenu_CreateInfo();o.text=text;o.checked=(currentScope==key);o.func=function()currentScope=key;UIDropDownMenu_SetText(picker,text);InventoryArchivistVaultRebuild() end;UIDropDownMenu_AddButton(o,level)
  end
  option('All Inventories','ALL')
  for _,s in ipairs(scopes) do option(s.label,s.key) end
 end)
 UIDropDownMenu_SetText(picker,'All Inventories')
 local sl=vault:CreateFontString(nil,'OVERLAY','GameFontNormal');sl:SetPoint('TOPLEFT',470,-58);sl:SetText('Search:')
 search=CreateFrame('EditBox',nil,vault,'InputBoxTemplate');search:SetSize(235,28);search:SetPoint('LEFT',sl,'RIGHT',12,0);search:SetAutoFocus(false)
 search:SetScript('OnEscapePressed',function(self)self:ClearFocus() end)
 search:SetScript('OnTextChanged',function(self)lastQuery=self:GetText():lower();InventoryArchivistVaultRebuild() end)
 -- A compact multi-select panel, rather than single-choice category buttons.
 filterButton=CreateFrame('Button',nil,vault,'UIPanelButtonTemplate')
 filterButton:SetSize(136,25);filterButton:SetPoint('TOPRIGHT',-24,-100)
 filterButton:SetText('Filters')
 filterPanel=CreateFrame('Frame',nil,vault,'BackdropTemplate')
 filterPanel:SetSize(255,429);filterPanel:SetPoint('TOPRIGHT',filterButton,'BOTTOMRIGHT',0,-3)
 filterPanel:SetFrameStrata('FULLSCREEN_DIALOG');filterPanel:SetFrameLevel(vault:GetFrameLevel()+20)
 filterPanel:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',tile=true,tileSize=16,edgeSize=14,insets={left=5,right=5,top=5,bottom=5}})
 -- Opaque dark panel prevents bright inventory icons from obscuring filter labels.
 filterPanel:SetBackdropColor(.035,.045,.065,1)
 filterPanel:SetBackdropBorderColor(.65,.65,.65,1)
 -- The Blizzard dialog background texture itself has transparent pixels.
 -- Draw a fully opaque solid rectangle behind it so inventory icons cannot bleed through.
 local solidBackground=filterPanel:CreateTexture(nil,'BACKGROUND',nil,-8)
 solidBackground:SetColorTexture(.025,.03,.045,1)
 solidBackground:SetPoint('TOPLEFT',filterPanel,'TOPLEFT',5,-5)
 solidBackground:SetPoint('BOTTOMRIGHT',filterPanel,'BOTTOMRIGHT',-5,5)
 local panelTitle=filterPanel:CreateFontString(nil,'OVERLAY','GameFontNormal')
 panelTitle:SetPoint('TOPLEFT',14,-14);panelTitle:SetText('Show categories')
 filterChecks={}
 local function addCheck(text,y,initial,onChange)
  local b=CreateFrame('CheckButton',nil,filterPanel,'UICheckButtonTemplate')
  b:SetSize(24,24);b:SetPoint('TOPLEFT',12,y)
  b:SetChecked(initial)
  local label=filterPanel:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
  label:SetPoint('LEFT',b,'RIGHT',3,0);label:SetText(text)
  b:SetScript('OnClick',function(self)onChange(self:GetChecked());InventoryArchivistVaultRebuild() end)
  return b
 end
 for i,cat in ipairs(categoryOrder) do
  filterChecks[cat]=addCheck(cat,-31-(i-1)*28,categoriesVisible[cat],function(v)
   categoriesVisible[cat]=v
   InventoryArchivistDB.vaultFilters=InventoryArchivistDB.vaultFilters or {}
   InventoryArchivistDB.vaultFilters[cat]=v
  end)
 end
 local sep=filterPanel:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
 sep:SetPoint('TOPLEFT',14,-180);sep:SetText('Additional filters')
 filterChecks.Quest=addCheck('Hide quest items',-198,hideQuest,function(v)
  hideQuest=v;InventoryArchivistDB.vaultHideQuest=v
 end)
 local auctionHeading=filterPanel:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
 auctionHeading:SetPoint('TOPLEFT',14,-241);auctionHeading:SetText('Auction status (not available)');auctionHeading:Hide()
 statusRadios={}
 for i,option in ipairs(statusOptions) do
  local radio=CreateFrame('CheckButton',nil,filterPanel,'UICheckButtonTemplate')
  radio:SetSize(22,22);radio:SetPoint('TOPLEFT',12,-258-(i-1)*27)
  local text=filterPanel:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
  text:SetPoint('LEFT',radio,'RIGHT',3,0);text:SetText(option[1])
  radio:SetScript('OnClick',function()
   auctionStatus=option[2]
   InventoryArchivistDB.vaultAuctionStatus=auctionStatus
   for key,button in pairs(statusRadios) do button:SetChecked(key==auctionStatus) end
   InventoryArchivistVaultRebuild()
  end)
  statusRadios[option[2]]=radio
 end
 statusRadios.ALL:SetChecked(true)
 local reset=CreateFrame('Button',nil,filterPanel,'UIPanelButtonTemplate')
 reset:SetSize(105,23);reset:SetPoint('BOTTOMLEFT',12,12);reset:SetText('Show All')
 reset:SetScript('OnClick',function()
  for _,cat in ipairs(categoryOrder) do
   categoriesVisible[cat]=true;filterChecks[cat]:SetChecked(true)
  end
  hideQuest=false;filterChecks.Quest:SetChecked(false)
  auctionStatus='ALL';InventoryArchivistDB.vaultAuctionStatus='ALL'
  for key,button in pairs(statusRadios) do button:SetChecked(key=='ALL') end
  InventoryArchivistDB.vaultFilters={};InventoryArchivistDB.vaultHideQuest=false
  InventoryArchivistVaultRebuild()
 end)
 local done=CreateFrame('Button',nil,filterPanel,'UIPanelButtonTemplate')
 done:SetSize(83,23);done:SetPoint('BOTTOMRIGHT',-12,12);done:SetText('Done')
 done:SetScript('OnClick',function()filterPanel:Hide() end)
 filterPanel:Hide()
 local sortLabel=vault:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
 sortLabel:SetPoint('TOPLEFT',300,-108);sortLabel:SetText('Sort:')
 sortPicker=CreateFrame('Frame','InventoryArchivistVaultSortPicker',vault,'UIDropDownMenuTemplate')
 sortPicker:SetPoint('LEFT',sortLabel,'RIGHT',-9,0)
 UIDropDownMenu_SetWidth(sortPicker,155)
 UIDropDownMenu_Initialize(sortPicker,function(_,level)
  for _,mode in ipairs(sortOptions) do
   local info=UIDropDownMenu_CreateInfo()
   info.text=mode;info.checked=(sortMode==mode)
   info.func=function()
    sortMode=mode;InventoryArchivistDB.vaultSortMode=mode
    UIDropDownMenu_SetText(sortPicker,mode)
    InventoryArchivistVaultRebuild()
   end
   UIDropDownMenu_AddButton(info,level)
  end
 end)
 UIDropDownMenu_SetText(sortPicker,'Name')
 filterPanel:Hide()
 filterButton:SetScript('OnClick',function()filterPanel:SetShown(not filterPanel:IsShown()) end)
 local bg=CreateFrame('Frame',nil,vault,'BackdropTemplate');bg:SetPoint('TOPLEFT',21,-132);bg:SetPoint('BOTTOMRIGHT',-21,45)
 bg:SetBackdrop({bgFile='Interface\\Tooltips\\UI-Tooltip-Background',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',tile=true,tileSize=16,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
 bg:SetBackdropColor(.04,.06,.09,.85)
 scroller=CreateFrame('ScrollFrame',nil,bg,'UIPanelScrollFrameTemplate');scroller:SetPoint('TOPLEFT',10,-10);scroller:SetPoint('BOTTOMRIGHT',-30,10)
 content=CreateFrame('Frame',nil,scroller);content:SetSize(780,1);scroller:SetScrollChild(content)
 priceSummary=vault:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 priceSummary:SetPoint('BOTTOMLEFT',26,36);priceSummary:SetWidth(460);priceSummary:SetJustifyH('LEFT')
 summary=vault:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall');summary:SetPoint('BOTTOMLEFT',26,22)
 moneyLabel=vault:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
 moneyLabel:SetPoint('BOTTOMRIGHT',-25,22);moneyLabel:SetJustifyH('RIGHT')
 moneyHitbox=CreateFrame('Frame',nil,vault);moneyHitbox:SetSize(220,24);moneyHitbox:SetPoint('RIGHT',moneyLabel,'RIGHT',4,0)
 moneyHitbox:EnableMouse(true)
   moneyHitbox:SetScript('OnEnter',function(self)
   GameTooltip:SetOwner(self,'ANCHOR_TOP');GameTooltip:SetText('Saved gold — inventory sources')
   local rows={}
   for _,entry in ipairs(scopes) do
    if currentScope=='ALL' or currentScope==entry.key then
     rows[#rows+1]={label=entry.label,amount=ownerMoney[entry.key],status=ownerMoneyStatus[entry.key]}
    end
   end
   for _,row in ipairs(rows) do
    local st=row.status or {}
    local ia=st.ia and (st.selected=='ia' and '|cff44dd88IA|r' or '|cff888888IA|r') or nil
    local bs=st.bs and (st.selected=='bs' and '|cff44dd88BS|r' or '|cff888888BS|r') or nil
    local source=(ia and bs) and (ia..' : '..bs) or ia or bs or 'Unknown'
    GameTooltip:AddDoubleLine(row.label,row.amount~=nil and GetMoneyString(row.amount,true) or 'Unknown',1,1,1,1,1,1)
    GameTooltip:AddDoubleLine('  Gold source',source,.65,.65,.65,1,1,1)
   end
   GameTooltip:Show()
  end)
moneyHitbox:SetScript('OnLeave',function()GameTooltip:Hide() end)
 local hint=vault:CreateFontString(nil,'OVERLAY','GameFontDisableSmall');hint:SetPoint('BOTTOMRIGHT',-25,38);hint:SetText('Read-only inventory snapshots  •  /ia vault')
 vault:Hide()
end
local function tileFor(index)
 if tiles[index] then return tiles[index] end
 local b=CreateFrame('Button',nil,content)
 b:SetSize(47,47)
 local icon=b:CreateTexture(nil,'ARTWORK');icon:SetAllPoints();b.icon=icon
 -- Four narrow edge textures frame the icon without tinting or covering its art.
 local edges={}
 for _,edge in ipairs({'top','bottom','left','right'}) do
  local t=b:CreateTexture(nil,'OVERLAY');t:SetColorTexture(1,1,1,.85)
  if edge=='top' then t:SetPoint('TOPLEFT',0,0);t:SetPoint('TOPRIGHT',0,0);t:SetHeight(2)
  elseif edge=='bottom' then t:SetPoint('BOTTOMLEFT',0,0);t:SetPoint('BOTTOMRIGHT',0,0);t:SetHeight(2)
  elseif edge=='left' then t:SetPoint('TOPLEFT',0,0);t:SetPoint('BOTTOMLEFT',0,0);t:SetWidth(2)
  else t:SetPoint('TOPRIGHT',0,0);t:SetPoint('BOTTOMRIGHT',0,0);t:SetWidth(2) end
  edges[#edges+1]=t
 end
 b.edges=edges
 local qty=b:CreateFontString(nil,'OVERLAY','NumberFontNormal');qty:SetPoint('BOTTOMRIGHT',-1,2);qty:SetJustifyH('RIGHT');b.qty=qty
 local pending=b:CreateFontString(nil,'OVERLAY','GameFontDisableSmall');pending:SetPoint('CENTER');pending:SetText('?');b.pending=pending
 b:SetScript('OnEnter',function(self)
  if not self.row then return end
  GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
  local id=self.row.id
  local _,link=infoFor(id)
  if link then GameTooltip:SetHyperlink(link) else GameTooltip:SetText(self.displayName or ('Item '..id)) end
  GameTooltip:AddLine(' ')
  GameTooltip:AddLine('Inventory Archivist — saved ownership',.3,.8,1)
  GameTooltip:AddDoubleLine('Total in selected view',tostring(self.displayTotal),1,1,1,1,1,1)
  local owners={}
  for owner,qty in pairs(self.row.owners) do
   if currentScope=='ALL' or currentScope==owner then
    local label=owner=='WARBAND' and 'Warband Bank' or owner:match('/ (.+)$') or owner
    owners[#owners+1]={label=label,qty=qty}
   end
  end
  table.sort(owners,function(a,b)return a.label<b.label end)
  for _,entry in ipairs(owners) do
   GameTooltip:AddDoubleLine(entry.label,tostring(entry.qty),.9,.9,.9,1,1,1)
   local sources=self.row.sources and self.row.sources[entry.label=='Warband Bank' and 'WARBAND' or (function()
    for k in pairs(self.row.owners) do if (k:match('/ (.+)$') or k)==entry.label then return k end end
   end)()]
   if sources then for loc,st in pairs(sources) do
    local ia=st.ia and (st.selected=='ia' and '|cff44dd88IA|r' or '|cff888888IA|r') or nil
    local bs=st.bs and (st.selected=='bs' and '|cff44dd88BS|r' or '|cff888888BS|r') or nil
    GameTooltip:AddDoubleLine('  '..loc,(ia and bs) and (ia..' : '..bs) or ia or bs or 'Unknown',.65,.65,.65,1,1,1)
   end end
  end
  local snapshot=InventoryArchivistPricing and InventoryArchivistPricing.Get(id)
  GameTooltip:AddLine(' ')
  GameTooltip:AddLine('Auction House — saved snapshot',1,.82,.25)
  if snapshot then
   local status=snapshot.status
   if status=='priced' and snapshot.minPrice then
    GameTooltip:AddDoubleLine('Lowest asking price',GetMoneyString(snapshot.minPrice,true),1,1,1,1,1,1)
    GameTooltip:AddDoubleLine('Estimated selected inventory value',GetMoneyString(snapshot.minPrice*self.displayTotal,true),1,1,1,1,1,1)
   elseif status=='no_listings' then GameTooltip:AddLine('No active listings at last scan',1,.65,.35)
   else GameTooltip:AddLine('Last scan status: '..tostring(status or 'Unknown'),1,.65,.35) end
   if snapshot.scannedAt then
    local age=math.max(0,time()-snapshot.scannedAt)
    local ageText=age<3600 and (math.floor(age/60)..' minutes ago') or age<86400 and (math.floor(age/3600)..' hours ago') or (math.floor(age/86400)..' days ago')
    GameTooltip:AddDoubleLine('Last checked',date('%Y-%m-%d %H:%M',snapshot.scannedAt)..' ('..ageText..')',.8,.8,.8,1,1,1)
   end
   if status=='no_listings' and snapshot.lastPricedAt and snapshot.lastMinPrice then
    GameTooltip:AddDoubleLine('Last observed asking price',GetMoneyString(snapshot.lastMinPrice,true),.8,.8,.8,1,1,1)
    GameTooltip:AddDoubleLine('Last observed on',date('%Y-%m-%d',snapshot.lastPricedAt),.8,.8,.8,1,1,1)
   end
  else GameTooltip:AddLine('Not yet scanned',.7,.7,.7) end
  GameTooltip:Show()
 end)
 b:SetScript('OnLeave',function()GameTooltip:Hide() end)
 b:SetScript('OnClick',function(self)
  if self.row and IsShiftKeyDown() then
   local _,link=infoFor(self.row.id)
   if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
  end
 end)
 tiles[index]=b;return b
end
function InventoryArchivistVaultRebuild()
 if not vault or not vault:IsShown() then return end
 local grouped={Materials={},Consumables={},Equipment={},Other={},Junk={}}
 local unique,amount=0,0
 local pricedCount,emptyCount,unresolvedCount,unscannedCount,estimatedValue=0,0,0,0,0
 for id,row in pairs(records) do
  local qty=currentScope=='ALL' and row.total or (row.owners[currentScope] or 0)
  if qty>0 then
   local name,link,quality,icon,classID=infoFor(id)
   local category=categorize(classID,quality)
   local isQuest=(classID==12)
   local text=(name or ('Item '..id)):lower()
   local price=InventoryArchivistPricing and InventoryArchivistPricing.Get(id)
   local priceState=not price and 'unscanned' or (price.status=='priced' and price.minPrice and 'priced' or price.status=='no_listings' and 'no_listings' or 'unresolved')
   if categoriesVisible[category] and (not hideQuest or not isQuest) and (lastQuery=='' or text:find(lastQuery,1,true) or tostring(id):find(lastQuery,1,true)) and (auctionStatus=='ALL' or auctionStatus==priceState or (auctionStatus=='unscanned' and priceState=='unresolved')) then
    grouped[category][#grouped[category]+1]={row=row,qty=qty,name=name or ('Item '..id),icon=icon,quality=quality,unitPrice=priceState=='priced' and price.minPrice or nil}
    unique=unique+1;amount=amount+qty
    if priceState=='priced' then pricedCount=pricedCount+1;estimatedValue=estimatedValue+price.minPrice*qty
    elseif priceState=='no_listings' then emptyCount=emptyCount+1
    elseif priceState=='unresolved' then unresolvedCount=unresolvedCount+1
    else unscannedCount=unscannedCount+1 end
   end
  end
 end
 for _,cat in ipairs(categoryOrder) do table.sort(grouped[cat],function(a,b)
  if sortMode=='Quantity' and a.qty~=b.qty then return a.qty>b.qty end
  if sortMode=='AH unit price' and (a.unitPrice or -1)~=(b.unitPrice or -1) then return (a.unitPrice or -1)>(b.unitPrice or -1) end
  if sortMode=='Estimated total value' and (a.unitPrice and a.unitPrice*a.qty or -1)~=(b.unitPrice and b.unitPrice*b.qty or -1) then return (a.unitPrice and a.unitPrice*a.qty or -1)>(b.unitPrice and b.unitPrice*b.qty or -1) end
  if a.name:lower()==b.name:lower() then return a.row.id<b.row.id end
  return a.name:lower()<b.name:lower()
 end) end
 for _,child in ipairs({content:GetChildren()}) do if child._vaultHeading then child:Hide() end end
 local idx,y=0,-4
 for _,cat in ipairs(categoryOrder) do
  local items=grouped[cat]
  if #items>0 then
   local heading=content:CreateFontString(nil,'OVERLAY','GameFontNormal')
   heading:SetPoint('TOPLEFT',6,y);local color=categoryColors[cat];heading:SetTextColor(color[1],color[2],color[3]);heading:SetText(cat:upper()..'  ('..#items..' unique)')
   -- FontStrings are regions, not children; retained and hidden on rebuild below.
   content._headings=content._headings or {};content._headings[#content._headings+1]=heading
   y=y-25
   for i,item in ipairs(items) do
    idx=idx+1;local b=tileFor(idx)
    local col=(i-1)%13;local row=math.floor((i-1)/13)
    b:ClearAllPoints();b:SetPoint('TOPLEFT',content,'TOPLEFT',7+col*58,y-row*57)
    b.row=item.row;b.displayTotal=item.qty;b.displayName=item.name
    b.icon:SetTexture(item.icon or 134400);b.pending:SetShown(not item.icon)
    b.qty:SetText(item.qty>1 and tostring(item.qty) or '')
    local q=item.quality or 1
    local qualityColor=ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if qualityColor then
     for _,edge in ipairs(b.edges) do edge:SetVertexColor(qualityColor.r or 1,qualityColor.g or 1,qualityColor.b or 1) end
    else
     for _,edge in ipairs(b.edges) do edge:SetVertexColor(1,1,1) end
    end
    b:Show()
   end
   y=y-math.ceil(#items/13)*57-17
  end
 end
 for i=idx+1,#tiles do tiles[i]:Hide() end
 content:SetHeight(math.max(1,-y+8))
 local hidden=0
 for _,cat in ipairs(categoryOrder) do if not categoriesVisible[cat] then hidden=hidden+1 end end
  if hidden>0 or hideQuest then filterButton:SetText('Filters ('..(hidden+(hideQuest and 1 or 0))..' hidden)') else filterButton:SetText('Filters') end
 summary:SetText(unique..' unique items   |   '..amount..' total quantity')
 priceSummary:SetText('')
 priceSummary:SetScript('OnEnter',nil)
 local hiddenCount=hidden+(hideQuest and 1 or 0)+(auctionStatus~='ALL' and 1 or 0)
 filterButton:SetText(hiddenCount>0 and ('Filters ('..hiddenCount..' active)') or 'Filters')
 local money=0
 if currentScope=='ALL' then for _,v in pairs(ownerMoney) do money=money+(v or 0) end else money=ownerMoney[currentScope] or 0 end
 moneyLabel:SetText('Saved Gold: '..(currentScope~='ALL' and ownerMoney[currentScope]==nil and 'Unknown' or GetMoneyString(money,true)))
end
local originalRebuild=InventoryArchivistVaultRebuild
InventoryArchivistVaultRebuild=function(...)
 if content and content._headings then for _,h in ipairs(content._headings) do h:Hide() end;content._headings={} end
 return originalRebuild(...)
end
function InventoryArchivistVaultToggle(requestedScope)
 if not vault then createUI() end
 if vault:IsShown() and not (InventoryArchivistCleanup and InventoryArchivistCleanup:IsShown()) then vault:Hide();return end
  gather()
 local db=InventoryArchivistDB or {}
 for _,cat in ipairs(categoryOrder) do
  local v=db.vaultFilters and db.vaultFilters[cat]
  categoriesVisible[cat]=(v==nil or v==true)
  filterChecks[cat]:SetChecked(categoriesVisible[cat])
 end
 hideQuest=db.vaultHideQuest==true;filterChecks.Quest:SetChecked(hideQuest)
 auctionStatus='ALL'
 for _,option in ipairs(statusOptions) do if option[2]==db.vaultAuctionStatus then auctionStatus=option[2] end end
 -- Migrate saved selection from the removed standalone Unresolved filter.
 if db.vaultAuctionStatus=='unresolved' then auctionStatus='unscanned';db.vaultAuctionStatus='unscanned' end
 for key,button in pairs(statusRadios) do button:SetChecked(key==auctionStatus) end
 sortMode='Name'
 for _,mode in ipairs(sortOptions) do if mode==db.vaultSortMode then sortMode=mode end end
 UIDropDownMenu_SetText(sortPicker,sortMode)
 currentScope='ALL'
 if requestedScope then
  for _,entry in ipairs(scopes) do if entry.key==requestedScope then currentScope=requestedScope;break end end
 end
 local scopeLabel='All Inventories'
 for _,entry in ipairs(scopes) do if entry.key==currentScope then scopeLabel=entry.label;break end end
 UIDropDownMenu_SetText(picker,scopeLabel)
 if InventoryArchivistCleanup then InventoryArchivistCleanup:Hide() end
 InventoryArchivistPositionApply(vault)
 vault:Show();InventoryArchivistVaultRebuild()
end
local listener=CreateFrame('Frame');listener:RegisterEvent('GET_ITEM_INFO_RECEIVED')
listener:SetScript('OnEvent',function()
 if vault and vault:IsShown() then
  if C_Timer and C_Timer.After then
   if not listener.scheduled then listener.scheduled=true;C_Timer.After(.3,function()listener.scheduled=false;InventoryArchivistVaultRebuild() end) end
  end
 end
end)
