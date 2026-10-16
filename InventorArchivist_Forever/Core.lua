-- Inventory Archivist Forever 0.1.2j-alpha
-- Separate SavedVariables from Retail; never modify inventory items.
InventoryArchivistForeverDB=InventoryArchivistForeverDB or {}
InventoryArchivistDB=InventoryArchivistForeverDB -- compatibility for shared Vault
local function realmID()
 local id=GetRealmID and GetRealmID()
 if type(id)=='number' and id>0 then return tostring(id) end
 return nil
end
InventoryArchivistForever={}
function InventoryArchivistForever.RealmID() return realmID() end
function InventoryArchivistForever.RealmName() return GetRealmName and GetRealmName() or 'Unknown' end
function InventoryArchivistForever.Notify(s) print('|cff55ccffIA Forever:|r '..tostring(s)) end
local function savePosition(frame)
 if not frame then return end
 local x,y=frame:GetLeft(),frame:GetTop()
 local scale=frame:GetEffectiveScale();local ps=UIParent:GetEffectiveScale()
 if x and y and ps and ps~=0 then
  InventoryArchivistForeverDB.sharedWindowPosition={x=x*scale/ps,y=y*scale/ps-UIParent:GetHeight()}
 end
end
function InventoryArchivistPositionSave(frame) savePosition(frame) end
function InventoryArchivistPositionApply(frame)
 local p=InventoryArchivistForeverDB.sharedWindowPosition
 if not p then return end
 local w,h=UIParent:GetWidth(),UIParent:GetHeight()
 frame:ClearAllPoints()
 frame:SetPoint('TOPLEFT',UIParent,'TOPLEFT',math.max(0,math.min(p.x,w-frame:GetWidth())),math.min(0,math.max(p.y,frame:GetHeight()-h)))
end
InventoryArchivistPricing={Get=function() return nil end}
-- No Retail-only modules in first Forever build.
InventoryArchivistFeatures={CleanupEnabled=function() return false end}
function InventoryArchivistFeatures.Enabled(key)
 return key=='markers' and InventoryArchivistForeverDB.features and InventoryArchivistForeverDB.features.markers==true or false
end
function InventoryArchivistFeatures.SetEnabled(key,value)
 if key~='markers' then return false end
 local db=InventoryArchivistForeverDB
 db.features=db.features or {}
 db.features.markers=not not value
 if InventoryArchivistMarkersSetEnabled then InventoryArchivistMarkersSetEnabled(db.features.markers) end
 return db.features.markers
end
local f=CreateFrame('Frame')
f:RegisterEvent('PLAYER_LOGIN')
f:SetScript('OnEvent',function()
 InventoryArchivistForeverDB=InventoryArchivistForeverDB or {}
 InventoryArchivistDB=InventoryArchivistForeverDB
 if not realmID() then InventoryArchivistForever.Notify('Realm ID unavailable; snapshots will not be written.') end
 if InventoryArchivistMarkersSetEnabled then InventoryArchivistMarkersSetEnabled(InventoryArchivistFeatures.Enabled('markers')) end
 InventoryArchivistForever.Notify('v0.1.2j-alpha loaded. Type /ia for the Vault, /ia status for diagnostics.')
end)
SLASH_IAFOREVER1='/ia'
SLASH_IAFOREVER2='/iaforever'
SlashCmdList.IAFOREVER=function(raw)
 local cmd=(raw or ''):lower():match('^%s*(.-)%s*$')
 if cmd=='status' then
  local id=realmID();local d=InventoryArchivistForeverDB
  local bucket=id and d.realms and d.realms[id]
  local n=0;for _ in pairs(bucket and bucket.characters or {}) do n=n+1 end
  InventoryArchivistForever.Notify('Realm: '..tostring(InventoryArchivistForever.RealmName())..' ('..tostring(id)..'), stored characters: '..n)
 elseif cmd=='settings' then
  if InventoryArchivistSettingsToggle then InventoryArchivistSettingsToggle() end
 elseif cmd=='markers' then
  InventoryArchivistFeatures.SetEnabled('markers',not InventoryArchivistFeatures.Enabled('markers'))
  InventoryArchivistForever.Notify('Markers '..(InventoryArchivistFeatures.Enabled('markers') and 'enabled' or 'disabled'))
 elseif cmd=='scan' then
  if InventoryArchivistInventory then InventoryArchivistInventory.ScanBags();InventoryArchivistInventory.ScanEquipment();InventoryArchivistInventory.ScanMoney();if InventoryArchivistInventory.bankOpen then InventoryArchivistInventory.ScanBank() end end
  InventoryArchivistForever.Notify('Scanned accessible inventory; bank scans require an open bank.')
 else
  if InventoryArchivistVaultToggle then InventoryArchivistVaultToggle() end
 end
end
